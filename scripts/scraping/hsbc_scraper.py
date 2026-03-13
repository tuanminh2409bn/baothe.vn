import time
import os
import re
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class HSBCScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng HSBC
        self.url_hsbc = "https://www.hsbc.com.vn/credit-cards/"
        super().__init__("HSBC", self.url_hsbc)

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
        """Truy cập trang chi tiết thẻ HSBC và trích xuất dữ liệu"""
        print(f"    -> Đang cào chi tiết HSBC: {url}")
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

                // 1. Lấy tên thẻ (h1)
                res.name = document.querySelector('h1')?.innerText.trim() || "";

                // 2. Lấy ảnh thẻ
                let imgEl = Array.from(document.querySelectorAll('img')).find(img => img.src.includes('/credit-cards/'));
                if (imgEl) res.img = imgEl.src;

                // 3. Lấy Highlights (Thường là các khối text lớn ở đầu)
                document.querySelectorAll('h2').forEach((h, index) => {
                    let text = h.innerText.trim();
                    if (text && index < 3 && text.length > 10) res.highlights.push(text);
                });

                // 4. Bóc tách chi tiết
                document.querySelectorAll('h2, h3').forEach(header => {
                    let title = header.innerText.trim();
                    let content = "";
                    let next = header.nextElementSibling;
                    if (next) content = next.innerText.trim();

                    if (title.includes('Ưu đãi') || title.includes('Đặc quyền') || title.includes('Hoàn tiền')) {
                        res.benefitsDetail.push({ title: title, content: content });
                    } else if (title.includes('Điều kiện')) {
                        res.conditionsDetail.push({ title: title, content: content });
                    } else if (title.includes('Phí') || title.includes('Lãi suất')) {
                        res.feeDetail.push({ title: title, content: content });
                    } else if (title.includes('Thông tin') || title.includes('Tiện ích')) {
                        res.productInfoDetail.push({ title: title, content: content });
                    }
                });

                // Nếu benefits trống, quét thêm các li dài
                if (res.benefitsDetail.length === 0) {
                    document.querySelectorAll('li').forEach(li => {
                        let text = li.innerText.trim();
                        if (text.length > 50) {
                             res.benefitsDetail.push({ title: "Ưu đãi", content: text });
                        }
                    });
                }

                return res;
            ''')
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi JS: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP HSBC ---")
        self.driver.get(self.url)
        time.sleep(10) 

        # Tìm tất cả link chi tiết thẻ
        card_links = self.driver.execute_script('''
            let results = [];
            document.querySelectorAll('a').forEach(a => {
                if (a.href.includes('/credit-cards/products/') && a.href.split('/').length > 6) {
                    results.push(a.href.split('?')[0]);
                }
            });
            return [...new Set(results)];
        ''')

        print(f"Phát hiện {len(card_links)} thẻ HSBC. Bắt đầu cào chi tiết...")

        cards_data = []
        for link in card_links:
            if link.endswith('/products/'): continue
            
            try:
                detail = self.scrape_card_detail(link)
                if not detail or not detail['name'] or len(detail['name']) < 5: 
                    print(f"  [Bỏ qua] Link không lấy được dữ liệu chuẩn: {link}")
                    continue
                
                name = detail['name'].replace('\n', ' ').strip()
                print(f"  [OK] Đã lấy: {name}")

                # Xử lý ảnh và ID chuẩn
                img_id = self.normalize_name(name)
                online_url = self.download_image_via_browser(detail['img'], f"hsbc_{img_id}")

                cards_data.append({
                    "id": f"hsbc-{img_id}",
                    "name": name,
                    "bankName": "HSBC",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=HSBC",
                    "applyUrl": link,
                    "cardType": "Visa/Mastercard",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["PREMIER", "PLATINUM", "SIGNATURE"]) else "Standard",
                    "cashbackHighlight": detail['highlights'][0] if detail['highlights'] else "Ưu đãi thẻ HSBC",
                    "details": detail['highlights'][1:4] if len(detail['highlights']) > 1 else ["Đặc quyền chủ thẻ HSBC"],
                    "benefitsDetail": detail['benefitsDetail'],
                    "conditionsDetail": detail['conditionsDetail'],
                    "productInfoDetail": detail['productInfoDetail'],
                    "feeDetail": detail['feeDetail']
                })
            except Exception as e:
                print(f"  ! Lỗi link {link}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = HSBCScraper()
    try:
        data = scraper.scrape()
        if data:
            scraper.save_to_firestore(data)
            print(f"--- HOÀN THÀNH: ĐÃ ĐỒNG BỘ {len(data)} THẺ HSBC ---")
        else:
            print("--- KHÔNG LẤY ĐƯỢC DỮ LIỆU THẺ ---")
    finally:
        scraper.quit()
