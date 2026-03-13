import time
import os
import re
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class SCScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng Standard Chartered
        self.url_sc = "https://www.sc.com/vn/vi/credit-cards/"
        super().__init__("Standard Chartered", self.url_sc)

    def normalize_name(self, name):
        """Loại bỏ dấu tiếng Việt và ký tự đặc biệt"""
        if not name: return ""
        name = name.replace('\n', ' ').replace('\r', ' ').strip()
        name = name.lower()
        patterns = {
            '[àáảãạăằắẳẵặâầấẩẫậ]': 'a',
            '[èéẻẽẹêềếểễệ]': 'e',
            '[ìíỉĩị]': 'i',
            '[òóỏõọôồốổỗộơờớởỡợ]': 'o',
            '[ùúủũụưừứửữự]': 'u',
            '[ỳýỷỹỵ]': 'y',
            'đ': 'd'
        }
        for pattern, replacement in patterns.items():
            name = re.sub(pattern, replacement, name)
        name = re.sub(r'[^a-z0-9]', '_', name)
        name = re.sub(r'_+', '_', name)
        return name.strip('_')

    def scrape_card_detail(self, url):
        """Truy cập trang chi tiết thẻ SC và trích xuất dữ liệu"""
        print(f"    -> Đang cào chi tiết SC: {url}")
        try:
            self.driver.get(url)
            time.sleep(10) 
            
            detail_data = self.driver.execute_script('''
                let res = { 
                    name: "", 
                    img: "", 
                    highlights: [], 
                    benefitsDetail: [], 
                    conditionsDetail: [], 
                    productInfoDetail: [], 
                    feeDetail: [] 
                };

                // 1. Lấy tên thẻ (thường trong h1 hoặc h2 của banner)
                res.name = document.querySelector('h1')?.innerText.trim() || "";
                if (res.name.includes("Đăng ký")) {
                    res.name = res.name.replace("Đăng ký ", "");
                }

                // 2. Lấy ảnh thẻ
                let imgEl = Array.from(document.querySelectorAll('img')).find(img => img.src.includes('/credit-cards/'));
                if (imgEl) res.img = imgEl.src;

                // 3. Lấy Highlights (Các li đầu tiên trong section lợi ích)
                document.querySelectorAll('li').forEach((li, index) => {
                    let text = li.innerText.trim();
                    if (text && text.length > 10 && text.length < 150 && res.highlights.length < 5) {
                        res.highlights.push(text);
                    }
                });

                // 4. Bóc tách chi tiết theo section
                document.querySelectorAll('h2, h3').forEach(header => {
                    let title = header.innerText.trim();
                    let content = "";
                    let next = header.nextElementSibling;
                    if (next) content = next.innerText.trim();

                    if (title.includes('lợi ích') || title.includes('Tính năng')) {
                        res.benefitsDetail.push({ title: title, content: content });
                    } else if (title.includes('Điều kiện')) {
                        res.conditionsDetail.push({ title: title, content: content });
                    } else if (title.includes('Thu nhập') || title.includes('Chứng từ')) {
                        res.conditionsDetail.push({ title: title, content: content });
                    }
                });

                return res;
            ''')
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi JS: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP STANDARD CHARTERED ---")
        self.driver.get(self.url)
        time.sleep(10) 

        # Tìm tất cả link chi tiết thẻ
        card_links = self.driver.execute_script('''
            let results = [];
            document.querySelectorAll('a').forEach(a => {
                if (a.href.includes('/credit-cards/') && a.href.split('/').length > 6) {
                    results.push(a.href.split('?')[0]);
                }
            });
            return [...new Set(results)];
        ''')

        print(f"Phát hiện {len(card_links)} thẻ Standard Chartered. Bắt đầu cào chi tiết...")

        cards_data = []
        for link in card_links:
            # Bỏ qua các link không phải thẻ sản phẩm
            if any(x in link for x in ['privileges', 'instalment', 'promotion']): continue
            
            try:
                detail = self.scrape_card_detail(link)
                if not detail or not detail['name'] or len(detail['name']) < 5: 
                    print(f"  [Bỏ qua] Link không lấy được dữ liệu chuẩn: {link}")
                    continue
                
                name = detail['name'].replace('\n', ' ').strip()
                print(f"  [OK] Đã lấy: {name}")

                # Xử lý ảnh và ID chuẩn
                img_id = self.normalize_name(name)
                online_url = self.download_image_via_browser(detail['img'], f"sc_{img_id}")

                cards_data.append({
                    "id": f"sc-{img_id}",
                    "name": name,
                    "bankName": "Standard Chartered",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=SC",
                    "applyUrl": link,
                    "cardType": "Visa/Mastercard",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["PRIORITY", "PLATINUM", "JOURNEY", "WORLDMILES"]) else "Standard",
                    "cashbackHighlight": detail['highlights'][0] if detail['highlights'] else "Ưu đãi Standard Chartered",
                    "details": detail['highlights'][1:4] if len(detail['highlights']) > 1 else ["Đặc quyền chủ thẻ Standard Chartered"],
                    "benefitsDetail": detail['benefitsDetail'],
                    "conditionsDetail": detail['conditionsDetail'],
                    "productInfoDetail": detail['productInfoDetail'],
                    "feeDetail": detail['feeDetail']
                })
            except Exception as e:
                print(f"  ! Lỗi link {link}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = SCScraper()
    try:
        data = scraper.scrape()
        if data:
            scraper.save_to_firestore(data)
            print(f"--- HOÀN THÀNH: ĐÃ ĐỒNG BỘ {len(data)} THẺ SC ---")
        else:
            print("--- KHÔNG LẤY ĐƯỢC DỮ LIỆU THẺ ---")
    finally:
        scraper.quit()
