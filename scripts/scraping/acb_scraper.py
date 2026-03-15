import time
import re
import json
import os
import sys

# Thêm đường dẫn để import BaseScraper
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from base_scraper import BaseScraper
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

class ACBScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ của ACB
        self.url_acb = "https://acb.com.vn/the"
        super().__init__("ACB", self.url_acb)

    def normalize_name(self, name):
        if not name: return ""
        name = name.replace('\n', ' ').replace('\r', ' ').strip()
        name = name.lower()
        patterns = {
            '[àáảãạăằắẳẵặâầấẩẫậ]': 'a', '[èéẻẽẹêềếểễệ]': 'e', '[ìíỉĩị]': 'i', 
            '[òóỏõọôồốổỗộơờớởỡợ]': 'o', '[ùúủũụưừứửữự]': 'u', '[ỳýỷỹỵ]': 'y', 'đ': 'd'
        }
        for pattern, replacement in patterns.items():
            name = re.sub(pattern, replacement, name)
        name = re.sub(r'[^a-z0-9]', '_', name)
        return re.sub(r'_+', '_', name).strip('_')

    def scrape_card_detail(self, url, outer_name, outer_img):
        print(f"    -> Đang cào chi tiết: {outer_name}")
        try:
            self.driver.get(url)
            # Chờ block nội dung quan trọng nhất load
            WebDriverWait(self.driver, 20).until(EC.presence_of_element_located((By.CSS_SELECTOR, ".html-parser, .entry-content")))
            time.sleep(3) 

            detail_data = self.driver.execute_script('''
                function getDeepText(el) {
                    if (!el) return "";
                    return el.innerText.replace(/\\n+/g, '\\n').trim();
                }

                let res = { 
                    description: "",
                    benefitsDetail: [], 
                    conditionsDetail: [], 
                    productInfoDetail: [], 
                    feeDetail: [] 
                };

                // Lấy mô tả header
                let descEl = document.querySelector('.sec-card-detail-1 p.mb-4, .sec-card-detail-1 .desc');
                res.description = getDeepText(descEl);

                // Quét tất cả các section nội dung, ưu tiên các block-id và các thẻ section có tiêu đề h2
                document.querySelectorAll('[id^="block-id-"], section, .block-content').forEach(section => {
                    let titleEl = section.querySelector('h2, h3, .title-block');
                    if (!titleEl) return;
                    
                    let title = titleEl.innerText.trim();
                    let contentEl = section.querySelector('.html-parser, .entry-content, .desc-content');
                    if (!contentEl) return;
                    
                    let content = getDeepText(contentEl);
                    if (!content || content.length < 5) return;

                    let item = { title: title, content: content };
                    let t = title.toLowerCase();

                    if (t.includes('quyền lợi') || t.includes('ưu đãi') || t.includes('đặc quyền')) {
                        res.benefitsDetail.push(item);
                    } else if (t.includes('yêu cầu') || t.includes('điều kiện') || t.includes('đối tượng')) {
                        res.conditionsDetail.push(item);
                    } else if (t.includes('biểu phí') || t.includes('phí')) {
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
            print(f"      ! Lỗi cào chi tiết {outer_name}: {e}")
            return None

    def scrape(self):
        print(f"--- BẮT ĐẦU CÀO DỮ LIỆU ACB ---")
        self.driver.get(self.url)
        all_cards = []
        
        # BƯỚC 1: Chọn tab "Thẻ tín dụng" nếu cần
        try:
            tab_xp = "//div[contains(@class, 'menu-filter')]//span[contains(text(), 'Thẻ tín dụng')]"
            tab_el = WebDriverWait(self.driver, 15).until(EC.element_to_be_clickable((By.XPATH, tab_xp)))
            self.driver.execute_script("arguments[0].click();", tab_el)
            print("  + Đã chọn tab Thẻ tín dụng.")
            time.sleep(4)
        except Exception as e:
            print(f"  ! Không chọn được tab Thẻ tín dụng (có thể đã mặc định): {e}")

        page_num = 1
        while True:
            print(f"--- Đang xử lý Trang {page_num} ---")
            
            # Cuộn trang để kích hoạt lazy load ảnh và đảm bảo pagination xuất hiện
            for _ in range(4):
                self.driver.execute_script("window.scrollBy(0, 800);")
                time.sleep(1)

            try:
                WebDriverWait(self.driver, 15).until(EC.presence_of_element_located((By.CLASS_NAME, "item-card-x")))
            except: 
                print("  ! Không tìm thấy danh sách thẻ trên trang này.")
                break

            # Lấy danh sách thẻ trang hiện tại
            items = self.driver.execute_script('''
                let results = [];
                // Quét trong toàn bộ trang để không bỏ sót thẻ
                document.querySelectorAll('.item-card-x').forEach(el => {
                    let nameEl = el.querySelector('h4.title');
                    let linkEl = el.querySelector('a.wimg, a.btn');
                    let imgEl = el.querySelector('.img-card img');
                    
                    if (nameEl && linkEl) {
                        let name = nameEl.innerText.trim();
                        let n = name.toLowerCase();
                        // Lọc thẻ tín dụng, loại bỏ Lotusmiles nếu cần (như yêu cầu trước đó)
                        if (!n.includes('ghi nợ') && !n.includes('debit') && !n.includes('thanh toán')) {
                            results.push({
                                name: name,
                                link: linkEl.href,
                                img: imgEl ? (imgEl.currentSrc || imgEl.src) : ""
                            });
                        }
                    }
                });
                return results;
            ''')

            print(f"  -> Tìm thấy {len(items)} thẻ tín dụng tại Trang {page_num}.")

            for item in items:
                # Kiểm tra trùng lặp dựa trên link (tránh cào lại thẻ đã có)
                if any(c['applyUrl'] == item['link'] for c in all_cards): continue
                
                detail = self.scrape_card_detail(item['link'], item['name'], item['img'])
                if detail:
                    img_id = self.normalize_name(detail['name'])
                    # Tải ảnh qua browser và đẩy lên Firebase
                    online_url = self.download_image_via_browser(detail['img'], f"acb_{img_id}")

                    all_cards.append({
                        "id": f"acb-{img_id}",
                        "name": detail['name'],
                        "bankName": "ACB",
                        "imagePath": online_url or "https://via.placeholder.com/400x250?text=ACB",
                        "applyUrl": item['link'],
                        "cardType": "Visa/JCB/Mastercard",
                        "cardTier": "Premium" if any(kw in detail['name'].upper() for kw in ["SIGNATURE", "PLATINUM", "INFINITE"]) else "Standard",
                        "cashbackHighlight": detail['description'],
                        "details": [d['title'] for d in detail['benefitsDetail'][:3]] if detail['benefitsDetail'] else ["Ưu đãi đặc quyền"],
                        "benefitsDetail": detail['benefitsDetail'],
                        "conditionsDetail": detail['conditionsDetail'],
                        "productInfoDetail": detail['productInfoDetail'],
                        "feeDetail": detail['feeDetail']
                    })
                    print(f"  [OK] Đã hoàn thành: {detail['name']}")

                # Quay lại trang danh sách để tiếp tục
                self.driver.get(self.url)
                # Đợi tab load lại và chọn lại tab nếu cần
                try:
                    tab_el = WebDriverWait(self.driver, 10).until(EC.element_to_be_clickable((By.XPATH, tab_xp)))
                    self.driver.execute_script("arguments[0].click();", tab_el)
                    time.sleep(3)
                    # Cuộn lại vị trí cũ hoặc cuộn xuống cuối để tìm pagination
                    self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight / 2);")
                except: pass

            # XỬ LÝ PHÂN TRANG (Tìm nút mũi tên cuối cùng trong danh sách pagination)
            try:
                # Tìm tất cả các nút li trong pagination của khối danh sách thẻ
                # Phân trang của ACB thường nằm trong thẻ ul.pagination
                pagination_next_xp = "//ul[contains(@class, 'pagination')]//li[contains(@class, 'li-arrow')][last()]"
                next_btn = self.driver.find_element(By.XPATH, pagination_next_xp)
                
                # Kiểm tra trạng thái disabled (thường qua opacity hoặc class)
                style = next_btn.get_attribute("style") or ""
                class_attr = next_btn.get_attribute("class") or ""
                
                if "opacity: 0.4" in style or "opacity:0.4" in style or "disabled" in class_attr.lower():
                    print("--- ĐÃ ĐẾN TRANG CUỐI CÙNG ---")
                    break
                
                print(f"--- Đang chuyển từ Trang {page_num} sang Trang {page_num + 1} ---")
                self.driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", next_btn)
                time.sleep(1)
                self.driver.execute_script("arguments[0].click();", next_btn)
                page_num += 1
                time.sleep(5) # Chờ trang mới load
            except Exception as e:
                print(f"--- Không tìm thấy nút Next hoặc lỗi phân trang: {e} ---")
                break

        return all_cards

if __name__ == "__main__":
    scraper = ACBScraper()
    try:
        data = scraper.scrape()
        if data:
            root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            output_path = os.path.join(root_dir, "acb_data.json")
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
            scraper.save_to_firestore(data)
            print(f"--- TỔNG CỘNG HOÀN THÀNH: {len(data)} THÈ ---")
        else:
            print("--- THẤT BẠI: KHÔNG CÀO ĐƯỢC DỮ LIỆU ---")
    finally:
        scraper.quit()
