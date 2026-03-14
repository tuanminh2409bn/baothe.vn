import time
import os
import re
import json
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

class SCScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng Standard Chartered
        self.url_sc = "https://www.sc.com/vn/credit-cards/"
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

    def scrape_card_detail(self, url, outer_img):
        """Truy cập trang chi tiết thẻ SC và trích xuất dữ liệu sâu"""
        print(f"    -> Đang cào chi tiết SC: {url}")
        try:
            self.driver.get(url)
            # Đợi trang load và các thành phần accordion xuất hiện
            WebDriverWait(self.driver, 15).until(
                EC.presence_of_element_located((By.CLASS_NAME, "sc-bnr__heading"))
            )
            time.sleep(3) # Cho phép script/animations chạy
            
            # Cuộn trang để kích hoạt lazy load nếu có
            self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight/2);")
            time.sleep(1)
            self.driver.execute_script("window.scrollTo(0, 0);")

            detail_data = self.driver.execute_script('''
                function extractContent(element) {
                    if (!element) return "";
                    let clone = element.cloneNode(true);
                    clone.querySelectorAll('input, .visuallyhidden').forEach(el => el.remove());
                    return clone.innerText.trim();
                }

                let res = { 
                    name: "", 
                    description: "",
                    highlights: [], 
                    benefitsDetail: [], 
                    conditionsDetail: [], 
                    productInfoDetail: [], 
                    feeDetail: [] 
                };

                // 1. Lấy tên thẻ từ Heading
                let h1 = document.querySelector('.sc-bnr__heading');
                res.name = h1 ? h1.innerText.trim() : "";
                if (res.name.toLowerCase().startsWith("dang ky ")) {
                    res.name = res.name.substring(8);
                }

                // Description
                let descEl = document.querySelector('.sc-bnr__content .sc-text--large');
                res.description = descEl ? descEl.innerText.trim() : "";

                // 3. Lấy Lợi ích tóm tắt (Summary Benefits)
                document.querySelectorAll('.sc-cvps__item').forEach(item => {
                    let title = item.querySelector('.sc-cvps__title')?.innerText.trim() || "";
                    let value = item.querySelector('.sc-cvps__value')?.innerText.trim() || "";
                    let desc = item.querySelector('.sc-cvps__desc')?.innerText.trim() || "";
                    res.highlights.push(`${title} ${value}: ${desc}`.trim());
                });

                // 4. Bóc tách Tính năng (Features)
                document.querySelectorAll('.sc-feature-dropdown__item').forEach(item => {
                    let title = item.querySelector('.sc-accordion__label')?.innerText.trim() || "";
                    let content = extractContent(item.querySelector('.sc-accordion__content'));
                    if (title) {
                        res.benefitsDetail.push({ title: title, content: content });
                    }
                });

                // 5. Bóc tách Accordions (Điều kiện, FAQ, Phí...)
                document.querySelectorAll('.sc-accordion-group > .sc-accordion').forEach(acc => {
                    let label = acc.querySelector('.sc-accordion__label')?.innerText.trim() || "";
                    let contentEl = acc.querySelector('.sc-accordion__content');
                    
                    if (label.includes('Điều kiện')) {
                        let tabs = acc.querySelectorAll('.sc-eligibility-doc__panel');
                        if (tabs.length > 0) {
                            tabs.forEach((panel, idx) => {
                                let tabLabel = acc.querySelectorAll('.sc-eligibility-doc__label')[idx]?.innerText.trim() || "Điều kiện";
                                res.conditionsDetail.push({ 
                                    title: tabLabel, 
                                    content: extractContent(panel) 
                                });
                            });
                        } else {
                            res.conditionsDetail.push({ title: label, content: extractContent(contentEl) });
                        }
                    } else if (label.includes('Câu hỏi') || label.includes('thông tin')) {
                        res.productInfoDetail.push({ title: label, content: extractContent(contentEl) });
                    } else if (label.includes('Phí') || label.includes('Điều khoản')) {
                        let links = [];
                        contentEl.querySelectorAll('a').forEach(a => {
                            links.push(`${a.innerText.trim()}: ${a.href}`);
                        });
                        res.feeDetail.push({ title: label, content: extractContent(contentEl), links: links });
                    }
                });

                return res;
            ''')
            
            # Gán ảnh từ trang ngoài đã lấy được
            detail_data['img'] = outer_img
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi cào chi tiết: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP STANDARD CHARTERED (VISUAL MODE) ---")
        self.driver.get(self.url)
        time.sleep(5) 

        # Lấy cặp Link và Ảnh từ trang danh sách (Outer Page)
        card_items = self.driver.execute_script('''
            let list = [];
            // Tìm các khối sản phẩm chính trên trang danh sách
            document.querySelectorAll('.sc-product-action-cvp').forEach(block => {
                let imgEl = block.querySelector('.sc-product-action-cvp__image img');
                let linkEl = block.querySelector('a[href*="/credit-cards/"]');
                
                if (linkEl && imgEl) {
                    list.push({
                        link: linkEl.href.split('?')[0],
                        img: imgEl.src
                    });
                }
            });
            return list;
        ''')

        print(f"Phát hiện {len(card_items)} thẻ tiềm năng từ trang danh sách.")

        cards_data = []
        for item in card_items:
            link = item['link']
            outer_img = item['img']
            
            # Bỏ qua các link không phải thẻ
            if any(x in link.lower() for x in ['privileges', 'instalment', 'promotion']): continue
            
            try:
                detail = self.scrape_card_detail(link, outer_img)
                if not detail or not detail['name'] or len(detail['name']) < 3: 
                    continue
                
                name = detail['name'].replace('\n', ' ').strip()
                print(f"  [OK] Đã lấy: {name}")

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
                    "cashbackHighlight": detail['description'] or (detail['highlights'][0] if detail['highlights'] else "Ưu đãi đặc quyền xứng tầm"),
                    "details": detail['highlights'] if detail['highlights'] else ["Đặc quyền chủ thẻ Standard Chartered"],
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
            with open("sc_data.json", "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
            scraper.save_to_firestore(data)
            print(f"--- HOÀN THÀNH: ĐÃ ĐỒNG BỘ {len(data)} THẺ SC ---")
        else:
            print("--- KHÔNG LẤY ĐƯỢC DỮ LIỆU THẺ ---")
    finally:
        scraper.quit()
