import time
import requests
import os
import re
from bs4 import BeautifulSoup
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.action_chains import ActionChains

class VietcombankScraper(BaseScraper):
    def __init__(self):
        self.url_vcb = "https://www.vietcombank.com.vn/KHCN/SPDV/the#card-list_type=Th%E1%BA%BB%20t%C3%ADn%20d%E1%BB%A5ng"
        super().__init__("Vietcombank", self.url_vcb)
        self.temp_img_dir = "temp_images"
        os.makedirs(self.temp_img_dir, exist_ok=True)

    def download_temp_image(self, url, filename):
        if not url or "base64" in url or "placeholder" in url: return None
        try:
            if url.startswith("//"): url = "https:" + url
            headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}
            response = requests.get(url, stream=True, timeout=20, headers=headers)
            if response.status_code == 200:
                path = os.path.join(self.temp_img_dir, filename)
                with open(path, 'wb') as f:
                    for chunk in response.iter_content(1024): f.write(chunk)
                return path
        except Exception as e:
            print(f"Lỗi tải ảnh: {e}")
        return None

    def scrape(self):
        print(f"--- TRUY CẬP VIETCOMBANK (CHẾ ĐỘ ÉP TẢI DỮ LIỆU) ---")
        self.driver.get(self.url)
        
        # Đợi trang tải danh sách 6 thẻ đầu tiên
        time.sleep(15) 

        # 1. Logic bấm nút "Xem thêm" mạnh mẽ hơn
        print("Đang mở rộng danh sách thẻ...")
        for i in range(5):
            try:
                # Cuộn xuống cuối trang để nút lộ ra
                self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                time.sleep(3)
                
                # Tìm nút bằng ID (load-more-label) từ mã nguồn bạn gửi
                wait = WebDriverWait(self.driver, 10)
                btn = wait.until(EC.presence_of_element_located((By.ID, "load-more-label")))
                
                if btn and btn.is_displayed():
                    print(f"  + Phát hiện nút 'Xem thêm'. Đang kích hoạt lần {i+1}...")
                    
                    # Phương pháp 1: Cuộn tới giữa màn hình
                    self.driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", btn)
                    time.sleep(2)
                    
                    # Phương pháp 2: Click bằng ActionChains (Giả lập chuột thật)
                    try:
                        actions = ActionChains(self.driver)
                        actions.move_to_element(btn).click().perform()
                    except:
                        # Phương pháp 3: Click bằng JavaScript (Ép buộc)
                        self.driver.execute_script("arguments[0].click();", btn)
                    
                    print(f"  + Đã bấm. Đợi 10 giây để tải thêm thẻ...")
                    time.sleep(10) # Vietcombank cần rất nhiều thời gian để render thẻ mới
                else:
                    break
            except:
                print("  - Không tìm thấy nút 'Xem thêm' nữa. Đã tải hết.")
                break

        # 2. Trích xuất dữ liệu bằng JavaScript (Quét toàn bộ vùng chứa thẻ)
        print("Đang bóc tách dữ liệu của TOÀN BỘ thẻ...")
        raw_cards = self.driver.execute_script("""
            let results = [];
            // Nhắm thẳng vào container chứa danh sách (từ view-source của bạn)
            let container = document.querySelector('.cards-list') || document;
            let items = container.querySelectorAll('.item, .card-item, [class*="col-"]');
            
            let seenNames = new Set();

            items.forEach(box => {
                // Chỉ xử lý nếu trong box có nút 'Mở thẻ ngay'
                if (!box.innerText.includes('Mở thẻ ngay')) return;

                // Tìm tên thẻ: Ưu tiên h3, h4 hoặc dòng text chứa 'Vietcombank'
                let name = "";
                let titleEl = box.querySelector('h3, h4, .card-title, .title');
                if (titleEl) {
                    name = titleEl.innerText.trim();
                } else {
                    let texts = box.innerText.split('\\n').map(t => t.trim());
                    name = texts.find(t => t.startsWith('Vietcombank')) || "";
                }

                if (name && name.length > 10 && !seenNames.has(name)) {
                    let img = box.querySelector('img')?.src;
                    let allLines = box.innerText.split('\\n').map(t => t.trim()).filter(t => t.length > 5);
                    let nameIdx = allLines.indexOf(name);
                    let benefits = allLines.slice(nameIdx + 1).filter(l => !l.includes('Mở thẻ') && !l.includes('So sánh'));

                    results.push({
                        name: name,
                        img: img,
                        url: box.querySelector('a')?.href || window.location.href,
                        benefits: benefits.slice(0, 3)
                    });
                    seenNames.add(name);
                }
            });
            return results;
        """)

        print(f"Tổng cộng tìm thấy {len(raw_cards)} thẻ tín dụng.")

        cards_data = []
        for idx, rc in enumerate(raw_cards):
            try:
                name = rc['name']
                print(f"  OK: {name}")
                # Tải và Upload ảnh ONLINE
                online_url = ""
                if rc['img']:
                    img_id = name.lower().replace(" ", "_").replace("-", "_").replace(".", "").replace("/", "_")
                    online_url = self.download_and_upload_image(rc['img'], f"vcb_{img_id}")


                cards_data.append({
                    "id": f"vcb-{img_id}",
                    "name": name,
                    "bankName": "Vietcombank",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=VCB",
                    "cashbackHighlight": rc['benefits'][0] if len(rc['benefits']) > 0 else "Hoàn tiền & Tích điểm",
                    "details": rc['benefits'][1:4] if len(rc['benefits']) > 1 else ["Ưu đãi dành riêng cho chủ thẻ"],
                    "applyUrl": rc['url'],
                    "cardType": "Visa/Mastercard/Amex",
                    "cardTier": "Premium"
                })

            except Exception as e:
                print(f"  ! Lỗi xử lý {rc['name']}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = VietcombankScraper()
    try:
        data = scraper.scrape()
        if data:
            print(f"Nạp {len(data)} thẻ lên Firebase Cloud...")
            scraper.save_to_firestore(data)
            print("--- HOÀN THÀNH TỰ ĐỘNG HÓA 100% ---")
        else:
            print("Không lấy được dữ liệu. Hãy đảm bảo màn hình Chrome không bị che.")
    finally:
        scraper.quit()
