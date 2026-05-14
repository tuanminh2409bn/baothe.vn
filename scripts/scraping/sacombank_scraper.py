import time
import os
import re
import json
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

class SacombankScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng Sacombank chuẩn
        self.url_stb = "https://www.sacombank.com.vn/ca-nhan/the/the-tin-dung.html"
        super().__init__("Sacombank", self.url_stb)

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
        """Truy cập trang chi tiết thẻ Sacombank và trích xuất dữ liệu sâu"""
        print(f"    -> Đang cào chi tiết STB: {url}")
        try:
            self.driver.get(url)
            time.sleep(10) # Đợi content bóc tách từ AEM (Sacombank load khá chậm)
            
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

                // 1. Lấy tên thẻ (h1 trong content-header)
                res.name = document.querySelector('.content-header h1')?.innerText.trim() || 
                           document.querySelector('h1')?.innerText.trim() || "";

                // 2. Lấy ảnh thẻ chính xác từ masthead hoặc hình ảnh đầu tiên có keyword the-tin-dung
                let imgEl = document.querySelector('.content-wrapper__subcontent-header .content-image img') || 
                           document.querySelector('.cmp-card-details-banner__image-wrapper img') ||
                           document.querySelector('img[src*="the-tin-dung"]');
                if (imgEl) res.img = imgEl.src;

                // 3. Lấy Highlights (Đặc tính nổi bật)
                document.querySelectorAll('.cmp-card-details-benefit .data-banner').forEach(item => {
                    let h = item.querySelector('.data-banner__header')?.innerText.trim();
                    let d = item.querySelector('.data-banner__description')?.innerText.trim();
                    if (h && d) res.highlights.push(`${h}: ${d}`);
                    else if (d) res.highlights.push(d);
                });

                // 4. Lấy Tiện ích (Lợi ích chi tiết)
                document.querySelectorAll('.accumulate-points__content-item').forEach(item => {
                    let t = item.querySelector('.accumulate-points__content-item-heading')?.innerText.trim();
                    let c = item.querySelector('.richtext')?.innerText.trim();
                    if (t) res.benefitsDetail.push({ title: t, content: c });
                });

                // 5. Lấy Biểu phí & Điều kiện (Từ các khối cmp-data-enhancement)
                document.querySelectorAll('.cmp-data-enhancement, .newdata').forEach(block => {
                    let title = block.querySelector('.data-enhancement__title-heading, h2')?.innerText.trim() || "";
                    let content = block.querySelector('.data-enhancement__content, .richtext-data')?.innerText.trim() || "";
                    
                    if (title.includes('Biểu phí')) {
                        res.feeDetail.push({ title: title, content: content });
                    } else if (title.includes('Điều kiện')) {
                        res.conditionsDetail.push({ title: title, content: content });
                    } else if (title.includes('Ưu đãi')) {
                        res.benefitsDetail.push({ title: title, content: content });
                    } else if (title.includes('Tích điểm')) {
                        res.productInfoDetail.push({ title: title, content: content });
                    }
                });

                return res;
            ''')
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi cào chi tiết: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP SACOMBANK (BẢN FIX LOGIC) ---")
        self.driver.get(self.url)
        time.sleep(12) 

        # 1. Mở rộng danh sách thẻ bằng nút "Xem Thêm"
        print("Đang mở rộng danh sách thẻ...")
        for i in range(5):
            try:
                # Cuộn xuống cuối trang để trigger load
                self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                time.sleep(3)
                
                show_more_btn = self.driver.find_element(By.CSS_SELECTOR, ".product-list__show-more--sp")
                if show_more_btn.is_displayed():
                    print(f"  + Bấm 'Xem thêm' lần {i+1}...")
                    self.driver.execute_script("arguments[0].click();", show_more_btn)
                    time.sleep(6) # Đợi AJAX tải thêm thẻ
                else:
                    break
            except:
                break

        # 2. Quét link chi tiết (Quét diện rộng tất cả thẻ <a> phù hợp pattern)
        print("Đang quét danh sách liên kết thẻ...")
        card_links = self.driver.execute_script('''
            let links = [];
            document.querySelectorAll('a').forEach(a => {
                let h = a.href;
                // Pattern link thẻ Sacombank chuẩn
                if (h.includes('/ca-nhan/the/the-tin-dung/the-tin-dung-sacombank-') && h.endsWith('.html')) {
                    links.push(h);
                }
            });
            return [...new Set(links)]; // Xóa trùng
        ''')

        print(f"Phát hiện {len(card_links)} thẻ Sacombank. Bắt đầu đi sâu vào chi tiết...")

        cards_data = []
        for link in card_links:
            try:
                detail = self.scrape_card_detail(link)
                if not detail or not detail['name'] or len(detail['name']) < 5: 
                    continue
                
                name = detail['name']
                print(f"  [OK] Đã lấy: {name}")

                # Xử lý ảnh và ID chuẩn
                img_id = self.normalize_name(name)
                online_url = self.download_image_via_browser(detail['img'], f"stb_{img_id}")

                benefits = self.clean_garbage_data(detail['benefitsDetail'])
                conditions = self.clean_garbage_data(detail['conditionsDetail'])
                product_info = self.clean_garbage_data(detail['productInfoDetail'])
                fees = self.clean_garbage_data(detail['feeDetail'])
                
                summary = detail['highlights'][0] if detail['highlights'] else "Ưu đãi thẻ Sacombank"
                full_text = summary + " " + " ".join([b.get('content', '') for b in benefits]) + " " + " ".join([p.get('content', '') for p in product_info])
                cashback_rates = self.extract_cashback_rates(full_text)

                card_data = {
                    "id": f"stb-{img_id}",
                    "name": name,
                    "bankName": "Sacombank",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=STB",
                    "applyUrl": link,
                    "cardType": "Visa/Mastercard/JCB/Amex/Napas",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["INFINITE", "SIGNATURE", "PLATINUM", "WORLD", "ULTIMATE"]) else "Standard",
                    "cashbackHighlight": summary,
                    "details": detail['highlights'][1:5] if len(detail['highlights']) > 1 else ["Đặc quyền chủ thẻ Sacombank"],
                    "benefitsDetail": benefits,
                    "conditionsDetail": conditions,
                    "productInfoDetail": product_info,
                    "feeDetail": fees
                }
                card_data.update(cashback_rates)
                cards_data.append(card_data)
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
