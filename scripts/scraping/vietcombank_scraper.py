import time
import os
import re
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.action_chains import ActionChains

class VietcombankScraper(BaseScraper):
    def __init__(self):
        # Sử dụng URL chuẩn
        self.url_vcb = "https://www.vietcombank.com.vn/KHCN/SPDV/the#card-list_type=Th%E1%BA%BB%20t%C3%ADn%20d%E1%BB%A5ng"
        super().__init__("Vietcombank", self.url_vcb)

    def scrape_card_detail(self, url):
        """Truy cập trang chi tiết thẻ và trích xuất 4 tab dữ liệu"""
        print(f"    -> Đang cào chi tiết: {url}")
        try:
            self.driver.get(url)
            time.sleep(7) 
            detail_data = self.driver.execute_script("""
                let res = { name: "", img: "", highlights: [], benefitsDetail: [], conditionsDetail: [], productInfoDetail: [], feeDetail: [] };
                res.name = document.querySelector('h1')?.innerText.trim() || "";
                let heroImg = document.querySelector('.hero-image img');
                if (heroImg) res.img = heroImg.src;

                document.querySelectorAll('.hero-infor-item').forEach(item => {
                    let t = item.querySelector('.hero-infor-title')?.innerText.trim();
                    let c = item.querySelector('.hero-infor-content')?.innerText.trim();
                    if (t) res.highlights.push(`${t}: ${c}`);
                });

                function getTab(idx) {
                    let items = [];
                    let w = document.querySelector(`.content-wrapper[data-index="${idx}"]`);
                    if (w) {
                        w.querySelectorAll('.content-item').forEach(i => {
                            let n = i.querySelector('.name')?.innerText.trim();
                            let c = i.querySelector('.label')?.innerText.replace(/\\s+/g, ' ').trim();
                            if (n) items.push({ title: n, content: c });
                        });
                    }
                    return items;
                }
                res.benefitsDetail = getTab("0");
                res.conditionsDetail = getTab("1");
                res.productInfoDetail = getTab("2");
                res.feeDetail = getTab("3");
                return res;
            """)
            return detail_data
        except: return None

    def scrape(self):
        print(f"--- TRUY CẬP VIETCOMBANK (LOGIC CLICK CHUẨN 100%) ---")
        self.driver.get(self.url)
        time.sleep(15) 

        # 1. KHÔI PHỤC NGUYÊN VẸN LOGIC BẤM NÚT "XEM THÊM" CỦA BẠN
        print("Đang mở rộng danh sách thẻ...")
        for i in range(5):
            try:
                self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                time.sleep(3)
                
                wait = WebDriverWait(self.driver, 10)
                btn = wait.until(EC.presence_of_element_located((By.ID, "load-more-label")))
                
                if btn and btn.is_displayed():
                    print(f"  + Phát hiện nút 'Xem thêm'. Đang kích hoạt lần {i+1}...")
                    self.driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", btn)
                    time.sleep(2)
                    
                    try:
                        actions = ActionChains(self.driver)
                        actions.move_to_element(btn).click().perform()
                    except:
                        self.driver.execute_script("arguments[0].click();", btn)
                    
                    print(f"  + Đã bấm. Đợi 10 giây để tải thêm thẻ...")
                    time.sleep(10)
                else:
                    break
            except:
                print("  - Không tìm thấy nút 'Xem thêm' nữa. Đã tải hết.")
                break

        # 2. KHÔI PHỤC LOGIC QUÉT KHỐI THẺ ĐỂ LẤY LINK
        print("Đang lấy danh sách liên kết thẻ...")
        card_links = self.driver.execute_script("""
            let results = [];
            let container = document.querySelector('.cards-list') || document;
            let items = container.querySelectorAll('.item, .card-item, [class*="col-"]');
            let seenLinks = new Set();

            items.forEach(box => {
                if (!box.innerText.includes('Mở thẻ ngay')) return;
                let link = box.querySelector('a')?.href;
                if (link && !seenLinks.has(link) && !link.includes('So-sanh-the')) {
                    results.push(link);
                    seenLinks.add(link);
                }
            });
            return results;
        """)

        print(f"Phát hiện tổng cộng {len(card_links)} thẻ. Bắt đầu đi sâu vào chi tiết...")

        cards_data = []
        for link in card_links:
            try:
                detail = self.scrape_card_detail(link)
                if not detail or not detail['name'] or len(detail['name']) < 5: continue
                
                # Làm sạch dữ liệu
                detail['benefitsDetail'] = self.clean_garbage_data(detail.get('benefitsDetail', []))
                detail['conditionsDetail'] = self.clean_garbage_data(detail.get('conditionsDetail', []))
                detail['productInfoDetail'] = self.clean_garbage_data(detail.get('productInfoDetail', []))
                detail['feeDetail'] = self.clean_garbage_data(detail.get('feeDetail', []))
                
                name = detail['name']
                print(f"  [OK] Đã lấy: {name}")

                img_id = name.lower().replace(" ", "_").replace("-", "_").replace(".", "").replace("/", "_")
                online_url = self.download_image_via_browser(detail['img'], f"vcb_{img_id}")
                
                # Trích xuất hoàn tiền
                full_text = " ".join(detail.get('highlights', [])) + " " + " ".join([d['content'] for d in detail['benefitsDetail'] + detail['productInfoDetail']])
                cashback_rates = self.extract_cashback_rates(full_text)

                card_data = {
                    "id": f"vcb-{img_id}",
                    "name": name,
                    "bankName": "Vietcombank",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=VCB",
                    "applyUrl": link,
                    "cardType": "Visa/Mastercard/JCB/Amex",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["PLATINUM", "WORLD", "INFINITE", "SIGNATURE"]) else "Standard",
                    "cashbackHighlight": detail['highlights'][0] if detail['highlights'] else "Tích điểm & Ưu đãi",
                    "details": detail['highlights'][1:] if len(detail['highlights']) > 1 else ["Đặc quyền chủ thẻ Vietcombank"],
                    "benefitsDetail": detail['benefitsDetail'],
                    "conditionsDetail": detail['conditionsDetail'],
                    "productInfoDetail": detail['productInfoDetail'],
                    "feeDetail": detail['feeDetail']
                }
                
                card_data.update(cashback_rates)
                cards_data.append(card_data)
                
            except Exception as e:
                print(f"  ! Lỗi link {link}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = VietcombankScraper()
    try:
        data = scraper.scrape()
        if data:
            scraper.save_to_firestore(data)
            print(f"--- HOÀN THÀNH: ĐÃ ĐỒNG BỘ {len(data)} THẺ ---")
    finally:
        scraper.quit()
