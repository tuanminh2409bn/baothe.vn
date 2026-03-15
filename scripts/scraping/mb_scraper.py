import time
import os
import re
import json
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

class MBBankScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng MB Bank
        self.url_mb = "https://www.mbbank.com.vn/26/46/213/san-pham-all/the-tin-dung"
        # Đặt tên ngân hàng là "MB" để khớp với code Flutter
        super().__init__("MB", self.url_mb)

    def normalize_name(self, name):
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

    def scrape_card_detail(self, url, outer_name, outer_img):
        print(f"    -> Đang cào chi tiết MB: {outer_name}")
        try:
            self.driver.get(url)
            WebDriverWait(self.driver, 30).until(
                EC.presence_of_element_located((By.CLASS_NAME, "pd-card-info-tit"))
            )
            time.sleep(3)

            detail_data = self.driver.execute_script('''
                function extractContent(element) {
                    if (!element) return "";
                    let clone = element.cloneNode(true);
                    clone.querySelectorAll('script, style, .icon-product-level-4, input').forEach(el => el.remove());
                    return clone.innerText.trim();
                }

                let res = { 
                    description: "",
                    benefitsDetail: [], 
                    conditionsDetail: [], 
                    productInfoDetail: [], 
                    feeDetail: [] 
                };

                res.description = document.querySelector('.detail-cate-sub-tit')?.innerText.trim() || "";

                document.querySelectorAll('.panel.panel-default').forEach(panel => {
                    let titleEl = panel.querySelector('.pd-card-info-tit a');
                    let title = titleEl ? titleEl.innerText.trim() : "";
                    let contentEl = panel.querySelector('.pd-card-info-body');
                    let content = extractContent(contentEl);
                    
                    if (!title || !content) return;

                    let item = { title: title, content: content };
                    let t = title.toLowerCase();

                    if (t.includes('ưu đãi') || t.includes('đặc điểm') || t.includes('tiện ích') || t.includes('giới thiệu')) {
                        res.benefitsDetail.push(item);
                    } else if (t.includes('điều kiện') || t.includes('đối tượng')) {
                        res.conditionsDetail.push(item);
                    } else if (t.includes('hồ sơ') || t.includes('thủ tục')) {
                        res.productInfoDetail.push(item);
                    } else if (t.includes('phí') || t.includes('lãi suất')) {
                        res.feeDetail.push(item);
                    } else {
                        res.productInfoDetail.push(item);
                    }
                });

                return res;
            ''')
            
            detail_data['name'] = outer_name
            detail_data['img'] = outer_img
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi bóc tách detail: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP MB BANK (VISUAL MODE) ---")
        self.driver.get(self.url)
        
        # Kiểm tra Access Denied
        if "Access Denied" in self.driver.page_source:
            print("  [CẢNH BÁO] Bị chặn. Hãy tương tác với trình duyệt...")
            time.sleep(10)

        # Cuộn trang load Angular
        self.driver.execute_script("window.scrollTo(0, 1000);")
        time.sleep(3)
        self.driver.execute_script("window.scrollTo(0, 0);")

        try:
            WebDriverWait(self.driver, 30).until(
                EC.presence_of_element_located((By.CLASS_NAME, "products-list"))
            )
            time.sleep(5)
        except:
            print("  ! Không tìm thấy danh sách thẻ.")
            return []

        card_items = self.driver.execute_script('''
            let list = [];
            document.querySelectorAll('.products-list-option-v1, .products-list-option').forEach(item => {
                let imgEl = item.querySelector('.products-card-img img');
                let nameEl = item.querySelector('.products-card-v1-name, .products-card-name');
                let linkEl = item.querySelector('a[href*="/Chi-tiet/"]');
                
                if (nameEl && linkEl) {
                    list.push({
                        name: nameEl.innerText.trim(),
                        link: linkEl.href,
                        img: imgEl ? imgEl.src : ""
                    });
                }
            });
            return list;
        ''')

        print(f"Phát hiện {len(card_items)} thẻ. Bắt đầu xử lý chi tiết...")

        cards_data = []
        for item in card_items:
            if not item['link'] or "mbbank.com.vn" not in item['link']: continue
            name_up = item['name'].upper()
            if any(x in name_up for x in ["GHI NỢ", "THANH TOÁN", "DEBIT"]): continue
            
            try:
                detail = self.scrape_card_detail(item['link'], item['name'], item['img'])
                if not detail: continue
                
                print(f"  [OK] Đã cào: {detail['name']}")

                img_id = self.normalize_name(detail['name'])
                online_url = self.download_image_via_browser(detail['img'], f"mb_{img_id}")

                cards_data.append({
                    "id": f"mb-{img_id}",
                    "name": detail['name'],
                    "bankName": "MB", # ĐỔI THÀNH "MB" ĐỂ KHỚP VỚI FRONTEND
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=MB",
                    "applyUrl": item['link'],
                    "cardType": "Visa/JCB/Mastercard",
                    "cardTier": "Premium" if any(kw in detail['name'].upper() for kw in ["PRIORITY", "PLATINUM", "INFINITE", "SIGNATURE", "WORLD ELITE"]) else "Standard",
                    "cashbackHighlight": detail['description'] or "Ưu đãi thẻ tín dụng MB",
                    "details": [d['title'] for d in detail['benefitsDetail'][:3]] if detail['benefitsDetail'] else ["Đặc quyền chủ thẻ MB"],
                    "benefitsDetail": detail['benefitsDetail'],
                    "conditionsDetail": detail['conditionsDetail'],
                    "productInfoDetail": detail['productInfoDetail'],
                    "feeDetail": detail['feeDetail']
                })
            except Exception as e:
                print(f"  ! Lỗi thẻ {item['name']}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = MBBankScraper()
    try:
        data = scraper.scrape()
        if data:
            with open("mb_data.json", "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
            scraper.save_to_firestore(data)
            print(f"--- HOÀN THÀNH: ĐÃ ĐỒNG BỘ {len(data)} THẺ MB VỚI BANKNAME='MB' ---")
        else:
            print("--- KHÔNG LẤY ĐƯỢC DỮ LIỆU THẺ MB ---")
    finally:
        scraper.quit()
