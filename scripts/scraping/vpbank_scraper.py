import time
import os
import re
import json
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class VPBankScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng VPBank
        self.url_vpb = "https://www.vpbank.com.vn/ca-nhan/the-tin-dung"
        super().__init__("VPBank", self.url_vpb)

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
        """Truy cập trang chi tiết thẻ VPBank và trích xuất dữ liệu bằng cách nhấn từng Tab"""
        print(f"    -> Đang cào nội dung chi tiết: {url}")
        try:
            self.driver.get(url)
            time.sleep(8) 
            
            detail_data = {
                "benefitsDetail": [],
                "conditionsDetail": [],
                "productInfoDetail": [],
                "feeDetail": []
            }

            # Tìm các Tab thông tin
            tab_buttons = self.driver.find_elements(By.CSS_SELECTOR, "button[role='tab']")
            for btn in tab_buttons:
                tab_name = btn.text.strip()
                if not tab_name: continue
                try:
                    self.driver.execute_script("arguments[0].click();", btn)
                    time.sleep(2) 

                    tab_content = self.driver.execute_script("""
                        let activePanel = document.querySelector('div[role="tabpanel"][data-state="active"]');
                        if (!activePanel) return "";
                        return activePanel.innerText.trim();
                    """)

                    if tab_content:
                        lower_name = tab_name.lower()
                        obj = {"title": tab_name, "content": tab_content}
                        
                        if any(x in lower_name for x in ['lợi ích', 'tính năng', 'ưu đãi']):
                            detail_data['benefitsDetail'].append(obj)
                        elif any(x in lower_name for x in ['điều kiện', 'thủ tục', 'hồ sơ']):
                            detail_data['conditionsDetail'].append(obj)
                        elif any(x in lower_name for x in ['biểu phí', 'lãi suất', 'thông tin cần thiết']):
                            detail_data['feeDetail'].append(obj)
                        else:
                            detail_data['productInfoDetail'].append(obj)
                except: pass

            return detail_data
        except Exception as e:
            print(f"      ! Lỗi cào chi tiết: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP VPBANK (CHỈ LẤY THẺ & LỌC DỊCH VỤ) ---")
        self.driver.get(self.url)
        time.sleep(10) 

        cat_tabs = self.driver.find_elements(By.CSS_SELECTOR, "div[edit-code='product.tabs'] button")
        all_unique_previews = {} 

        for i in range(len(cat_tabs)):
            try:
                tabs = self.driver.find_elements(By.CSS_SELECTOR, "div[edit-code='product.tabs'] button")
                tab_name = tabs[i].text.strip()
                # Bỏ qua các tab dịch vụ rút tiền nếu tên tab thuần dịch vụ
                if any(x in tab_name.lower() for x in ['rút tiền', 'trả góp']):
                    print(f"  [Bỏ qua danh mục dịch vụ]: {tab_name}")
                    # Vẫn click để xem bên trong có thẻ nào không, nhưng sẽ lọc kỹ hơn ở dưới
                
                print(f"  [*] Đang mở danh mục: {tab_name}")
                self.driver.execute_script("arguments[0].click();", tabs[i])
                time.sleep(5)

                while True:
                    try:
                        more_btn = self.driver.find_element(By.CSS_SELECTOR, "button[aria-label='Button More']")
                        if more_btn.is_displayed():
                            self.driver.execute_script("arguments[0].click();", more_btn)
                            time.sleep(3)
                        else: break
                    except: break

                # Trích xuất thẻ và LỌC DỊCH VỤ
                cards_in_tab = self.driver.execute_script("""
                    let results = [];
                    document.querySelectorAll('div.bg-white.flex.flex-col.p-5').forEach(card => {
                        let name = card.querySelector('h4')?.innerText.trim() || "";
                        let detail_link = card.querySelector('a[href*="/ca-nhan/the-tin-dung/"]');
                        let img = card.querySelector('img');
                        
                        // LỌC: Chỉ lấy nếu tên có chữ 'Thẻ' hoặc các loại thẻ
                        let isCard = /thẻ|visa|mastercard|jcb/i.test(name);
                        let isService = /rút tiền|ứng tiền/i.test(name) && !/thẻ/i.test(name);

                        if (name && detail_link && isCard && !isService) {
                            results.push({
                                name: name,
                                detail_url: detail_link.href.split('#')[0].split('?')[0], // Làm sạch URL để lọc trùng
                                img_card: img?.src || "",
                                highlights: Array.from(card.querySelectorAll('.mark-down li')).map(li => li.innerText.trim())
                            });
                        }
                    });
                    return results;
                """)
                
                for c in cards_in_tab:
                    if c['detail_url'] not in all_unique_previews:
                        all_unique_previews[c['detail_url']] = c
                
            except Exception as e:
                print(f"    ! Lỗi danh mục {i}: {e}")

        print(f"--- TỔNG CỘNG: {len(all_unique_previews)} THẺ DUY NHẤT. BẮT ĐẦU CÀO CHI TIẾT ---")

        cards_data = []
        for url, pre in all_unique_previews.items():
            try:
                detail = self.scrape_card_detail(url)
                name = pre['name']
                print(f"  [OK] Xử lý: {name}")

                # Tạo ID từ Slug của URL để không bao giờ bị trùng Diamond World
                card_slug = url.split('/')[-1]
                card_id = f"vpb-{card_slug.lower().replace('-', '_')}"

                # Tải ảnh từ trang ngoài (đã bắt được ở bước trên)
                online_url = self.download_image_via_browser(pre['img_card'], card_id)

                card_obj = {
                    "id": card_id,
                    "name": name,
                    "bankName": "VPBank",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=VPB",
                    "applyUrl": url,
                    "cardType": "Visa/Mastercard/JCB",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["SIGNATURE", "INFINITE", "PLATINUM", "DIAMOND", "WORLD", "STEP UP"]) else "Standard",
                    "cashbackHighlight": pre['highlights'][0] if pre['highlights'] else "Ưu đãi thẻ VPBank",
                    "details": pre['highlights'] if pre['highlights'] else ["Đặc quyền chủ thẻ VPBank"],
                    "benefitsDetail": detail['benefitsDetail'] if detail else [],
                    "conditionsDetail": detail['conditionsDetail'] if detail else [],
                    "productInfoDetail": detail['productInfoDetail'] if detail else [],
                    "feeDetail": detail['feeDetail'] if detail else []
                }
                cards_data.append(card_obj)
            except Exception as e:
                print(f"  ! Lỗi xử lý {pre['name']}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = VPBankScraper()
    try:
        data = scraper.scrape()
        if data:
            scraper.save_to_firestore(data)
            print(f"--- HOÀN THÀNH: ĐÃ ĐỒNG BỘ {len(data)} THẺ VPBANK ---")
    finally:
        scraper.quit()
