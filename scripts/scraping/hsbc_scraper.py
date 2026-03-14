import time
import os
import re
import json
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

class HSBCScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng HSBC chuẩn
        self.url_hsbc = "https://www.hsbc.com.vn/credit-cards/products/"
        super().__init__("HSBC", self.url_hsbc)

    def normalize_name(self, name):
        """Loại bỏ dấu tiếng Việt và ký tự đặc biệt để tạo ID"""
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
        """Truy cập trang chi tiết thẻ HSBC và trích xuất dữ liệu sâu"""
        print(f"    -> Đang cào chi tiết HSBC: {url}")
        try:
            self.driver.get(url)
            time.sleep(10) # Đợi trang tải hoàn toàn
            
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

                // 1. Lấy tên thẻ
                res.name = document.querySelector('h1.crh-hero-banner__main-header')?.innerText.trim() || "";

                // 2. Lấy ảnh thẻ từ masthead
                let heroImg = document.querySelector('.crh-hero-banner__main-image-wrapper img');
                if (heroImg) res.img = heroImg.src;

                // 3. Lấy Highlights (Các khối pictogram: Ẩm thực, Mua sắm...)
                document.querySelectorAll('.M-MASTERCARD').forEach(card => {
                    let title = card.querySelector('h3')?.innerText.trim();
                    let desc = card.querySelector('.master-card__text')?.innerText.trim();
                    if (title && desc) res.highlights.push(`${title}: ${desc}`);
                });

                // 4. Lấy Chi tiết Lợi ích (Từ các Advanced List)
                document.querySelectorAll('.cc-column').forEach(col => {
                    let title = col.querySelector('h3.heading')?.innerText.trim();
                    if (title && (title.includes('Ẩm thực') || title.includes('Mua sắm') || title.includes('Giải trí') || title.includes('Đặc quyền'))) {
                        let items = [];
                        col.querySelectorAll('.advanced-list li').forEach(li => {
                            items.push(li.innerText.trim());
                        });
                        if (items.length > 0) {
                            res.benefitsDetail.push({ title: title, content: items.join('\\n') });
                        }
                    }
                });

                // 5. Lấy Điều kiện đăng ký
                let condHeader = Array.from(document.querySelectorAll('h3.heading')).find(h => h.innerText.includes('Điều kiện đăng ký'));
                if (condHeader) {
                    let content = condHeader.closest('.M-CONTMAST-RW-RBWM')?.nextElementSibling?.innerText.trim();
                    if (content) res.conditionsDetail.push({ title: "Điều kiện đăng ký", content: content });
                }

                // 6. Lấy Biểu phí & Hạn mức (Từ các table.desktop)
                let tables = document.querySelectorAll('table.desktop');
                tables.forEach(table => {
                    let header = table.querySelector('thead th')?.innerText.trim() || "";
                    let rows = [];
                    table.querySelectorAll('tbody tr').forEach(tr => {
                        let th = tr.querySelector('th')?.innerText.trim();
                        let td = tr.querySelector('td')?.innerText.trim();
                        if (th && td) rows.push(`${th}: ${td}`);
                    });
                    
                    if (header.includes('phí') || table.innerText.includes('Lãi suất')) {
                        res.feeDetail.push({ title: "Phí và lãi suất", content: rows.join('\\n') });
                    } else if (header.includes('Hạn mức')) {
                        res.productInfoDetail.push({ title: "Thông tin hạn mức", content: rows.join('\\n') });
                    }
                });

                return res;
            ''')
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi cào chi tiết: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP HSBC (LOGIC BÓC TÁCH MỚI) ---")
        self.driver.get(self.url)
        time.sleep(10) 

        # 1. Quét danh sách link thẻ từ trang ngoài
        print("Đang quét danh sách liên kết thẻ...")
        card_previews = self.driver.execute_script('''
            let results = [];
            document.querySelectorAll('.M-CNT-ITEM-ART-DEV').forEach(item => {
                let name = item.querySelector('h3.link-header a')?.innerText.trim();
                let link = item.querySelector('h3.link-header a')?.href;
                let img = item.querySelector('.item-image img')?.src;
                
                if (link && name && !link.includes('compare')) {
                    results.push({ name, link, img });
                }
            });
            return results;
        ''')

        print(f"Phát hiện {len(card_previews)} thẻ HSBC. Bắt đầu đi sâu vào chi tiết...")

        cards_data = []
        seen_links = set()

        for pre in card_previews:
            link = pre['link']
            if link in seen_links: continue
            seen_links.add(link)
            
            try:
                detail = self.scrape_card_detail(link)
                if not detail or not detail['name'] or len(detail['name']) < 5: 
                    # Dự phòng nếu bóc tách trang trong lỗi
                    name = pre['name']
                    img_to_download = pre['img']
                    detail = {
                        "name": name,
                        "img": img_to_download,
                        "highlights": ["Ưu đãi thẻ tín dụng HSBC"],
                        "benefitsDetail": [],
                        "conditionsDetail": [],
                        "productInfoDetail": [],
                        "feeDetail": []
                    }
                else:
                    name = detail['name']
                    img_to_download = detail['img'] or pre['img']

                print(f"  [OK] Đã lấy: {name}")

                # Xử lý ảnh và ID chuẩn
                img_id = self.normalize_name(name)
                online_url = self.download_image_via_browser(img_to_download, f"hsbc_{img_id}")

                cards_data.append({
                    "id": f"hsbc-{img_id}",
                    "name": name,
                    "bankName": "HSBC",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=HSBC",
                    "applyUrl": link,
                    "cardType": "Visa/Mastercard",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["PREMIER", "PLATINUM", "SIGNATURE", "WORLD"]) else "Standard",
                    "cashbackHighlight": detail['highlights'][0] if detail['highlights'] else "Hoàn tiền & Ưu đãi",
                    "details": detail['highlights'] if detail['highlights'] else ["Đặc quyền chủ thẻ HSBC"],
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
