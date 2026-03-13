import time
import os
import re
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class SacombankScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng Sacombank
        self.url_stb = "https://www.sacombank.com.vn/ca-nhan/the/the-tin-dung.html"
        super().__init__("Sacombank", self.url_stb)

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
        """Truy cập trang chi tiết thẻ Sacombank và trích xuất dữ liệu"""
        print(f"    -> Đang cào chi tiết STB: {url}")
        try:
            self.driver.get(url)
            time.sleep(8) 
            
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
                let imgEl = document.querySelector('.card-image img') || 
                           document.querySelector('img[src*="/the/"]') || 
                           document.querySelector('.banner img');
                if (imgEl) res.img = imgEl.src;

                // 3. Lấy Highlights (Các đặc tính nổi bật)
                let highlightsHeader = Array.from(document.querySelectorAll('h2, h3')).find(h => h.innerText.includes('Đặc tính'));
                if (highlightsHeader) {
                    let nextEl = highlightsHeader.nextElementSibling;
                    if (nextEl) {
                        nextEl.querySelectorAll('li, p').forEach(li => {
                            if (li.innerText.trim()) res.highlights.push(li.innerText.trim());
                        });
                    }
                }

                // 4. Bóc tách chi tiết (Sacombank dùng các section với tiêu đề)
                document.querySelectorAll('h2, h3, .section-title').forEach(header => {
                    let title = header.innerText.trim();
                    let content = "";
                    let next = header.nextElementSibling;
                    
                    // Lấy nội dung của section (thường là div tiếp theo hoặc các p, li)
                    if (next) content = next.innerText.trim();

                    if (title.includes('Tiện ích') || title.includes('Quyền lợi') || title.includes('Đặc quyền')) {
                        res.benefitsDetail.push({ title: title, content: content });
                    } else if (title.includes('Điều kiện')) {
                        res.conditionsDetail.push({ title: title, content: content });
                    } else if (title.includes('Biểu phí')) {
                        res.feeDetail.push({ title: title, content: content });
                    } else if (title.includes('Đặc tính') || title.includes('Thông tin')) {
                        res.productInfoDetail.push({ title: title, content: content });
                    }
                });

                return res;
            ''')
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi JS: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP SACOMBANK ---")
        self.driver.get(self.url)
        time.sleep(10) 

        # Cuộn trang để tải hết (nếu có lazy load)
        print("Đang quét danh sách thẻ...")
        self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight/2);")
        time.sleep(3)
        self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(3)

        # Tìm tất cả link chi tiết thẻ
        card_links = self.driver.execute_script('''
            let results = [];
            document.querySelectorAll('a').forEach(a => {
                let h = a.href;
                if (h.includes('/the-tin-dung-') && h.endsWith('.html')) {
                    results.push(h);
                }
            });
            return [...new Set(results)];
        ''')

        # Thêm các link tiềm năng khác nếu chưa có
        potential_slugs = [
            "the-tin-dung-sacombank-visa-platinum-cashback",
            "the-tin-dung-sacombank-visa-platinum",
            "the-tin-dung-sacombank-visa-platinum-o2",
            "the-tin-dung-sacombank-visa",
            "the-tin-dung-sacombank-mastercard",
            "the-tin-dung-sacombank-jcb",
            "the-tin-dung-sacombank-unionpay",
            "the-tin-dung-sacombank-napas-easy-card",
            "the-tin-dung-sacombank-napas-family"
        ]
        
        for slug in potential_slugs:
            full_url = f"https://www.sacombank.com.vn/ca-nhan/the/the-tin-dung/{slug}.html"
            if full_url not in card_links:
                card_links.append(full_url)

        print(f"Phát hiện/Dự đoán {len(card_links)} thẻ Sacombank. Bắt đầu cào chi tiết...")

        cards_data = []
        for link in card_links:
            try:
                detail = self.scrape_card_detail(link)
                if not detail or not detail['name'] or len(detail['name']) < 5: 
                    print(f"  [Bỏ qua] Link không lấy được dữ liệu chuẩn: {link}")
                    continue
                
                raw_name = detail['name'].replace('\n', ' ').strip()
                name = re.sub(r'\s+', ' ', raw_name)
                print(f"  [OK] Đã lấy: {name}")

                # Xử lý ảnh và ID chuẩn
                img_id = self.normalize_name(name)
                online_url = self.download_image_via_browser(detail['img'], f"stb_{img_id}")

                cards_data.append({
                    "id": f"stb-{img_id}",
                    "name": name,
                    "bankName": "Sacombank",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=STB",
                    "applyUrl": link,
                    "cardType": "Visa/Mastercard/JCB/Amex",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["INFINITE", "SIGNATURE", "ULTIMATE", "WORLD", "PLATINUM"]) else "Standard",
                    "cashbackHighlight": detail['highlights'][0] if detail['highlights'] else "Ưu đãi thẻ Sacombank",
                    "details": detail['highlights'][1:4] if len(detail['highlights']) > 1 else ["Đặc quyền chủ thẻ Sacombank"],
                    "benefitsDetail": detail['benefitsDetail'],
                    "conditionsDetail": detail['conditionsDetail'],
                    "productInfoDetail": detail['productInfoDetail'],
                    "feeDetail": detail['feeDetail']
                })
            except Exception as e:
                print(f"  ! Lỗi link {link}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = SacombankScraper()
    try:
        data = scraper.scrape()
        if data:
            scraper.save_to_firestore(data)
            print(f"--- HOÀN THÀNH: ĐÃ ĐỒNG BỘ {len(data)} THẺ SACOMBANK ---")
        else:
            print("--- KHÔNG LẤY ĐƯỢC DỮ LIỆU THẺ ---")
    finally:
        scraper.quit()
