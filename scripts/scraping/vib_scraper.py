import time
import os
from bs4 import BeautifulSoup
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class VIBScraper(BaseScraper):
    def __init__(self):
        self.url_vib = "https://www.vib.com.vn/vn/the-tin-dung"
        super().__init__("VIB", self.url_vib)
        self.temp_img_dir = "temp_images_vib"
        os.makedirs(self.temp_img_dir, exist_ok=True)

    def scrape_card_detail(self, url):
        """Bóc tách trang chi tiết VIB dựa trên cấu trúc khối (không dùng tab)"""
        if not url.startswith("http"):
            url = "https://www.vib.com.vn" + url
            
        print(f"    -> Đang cào chi tiết VIB: {url}")
        try:
            self.driver.get(url)
            # VIB load cột Lợi ích bên phải bằng AJAX, cần đợi đủ lâu
            time.sleep(8) 

            detail_data = self.driver.execute_script("""
                let results = {
                    name: "",
                    img: "",
                    highlights: [],
                    benefitsDetail: [],
                    conditionsDetail: [],
                    productInfoDetail: [],
                    feeDetail: []
                };

                // 1. Lấy tên từ H1
                results.name = document.querySelector('h1')?.innerText.trim() || "";

                // 2. Lấy ảnh thẻ từ khối img-card1
                let cardImg = document.querySelector('.img-card1 img');
                if (cardImg) results.img = cardImg.src;

                // 3. Bóc tách các khối văn bản chính (.vib-v2-box-txt-card-detail)
                document.querySelectorAll('.vib-v2-box-txt-card-detail').forEach(box => {
                    let title = box.querySelector('h4')?.innerText.trim() || "";
                    // Lấy toàn bộ text trong box, loại bỏ phần tiêu đề h4 để lấy nội dung
                    let content = box.innerText.replace(title, "").replace(/\\s+/g, ' ').trim();
                    
                    if (title && content) {
                        if (title.includes("TÍNH NĂNG")) {
                            results.highlights.push(content);
                            results.benefitsDetail.push({ title: title, content: content });
                        } else if (title.includes("HẠN MỨC") || title.includes("PHÍ")) {
                            results.feeDetail.push({ title: title, content: content });
                            results.productInfoDetail.push({ title: title, content: content });
                        } else {
                            results.benefitsDetail.push({ title: title, content: content });
                        }
                    }
                });

                // 4. Bóc tách cột nội dung bên phải (Lợi ích chi tiết load qua AJAX)
                let rightBox = document.querySelector('.vib-right-content-deatil');
                if (rightBox) {
                    rightBox.querySelectorAll('.vib-v2-box-benefit-card').forEach(item => {
                        let t = item.querySelector('h3, h4, .title')?.innerText.trim();
                        // Làm sạch nội dung, xóa các chữ "Xem thêm / Thu gọn" nếu có
                        let c = item.innerText.replace(t, "").replace(/Xem thêm|Thu gọn/g, "").replace(/\\s+/g, ' ').trim();
                        if (t && c) {
                            results.benefitsDetail.push({ title: t, content: c });
                        }
                    });
                }

                return results;
            """)
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi cào chi tiết: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP VIB (KẾT HỢP LOGIC CŨ & CHI TIẾT) ---")
        self.driver.set_script_timeout(30)
        self.driver.get(self.url)
        
        print("Đang cuộn trang...")
        self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(8)

        # 1. KHÔI PHỤC LOGIC CŨ: Dùng BeautifulSoup để lấy danh sách thẻ ổn định
        soup = BeautifulSoup(self.driver.page_source, 'html.parser')
        card_items = soup.select(".vib-v2-box-card-content")
        print(f"Tìm thấy {len(card_items)} thẻ VIB.")

        cards_data = []
        for idx, item in enumerate(card_items):
            try:
                name_tag = item.select_one("h3 a")
                name = name_tag.get_text().strip() if name_tag else "Thẻ VIB"
                detail_url = name_tag['href'] if name_tag else ""
                
                print(f"  -> Xử lý: {name}")

                # Lấy ảnh từ trang danh sách (Dự phòng)
                img_tag = item.select_one(".img-card1 img")
                img_url = img_tag['src'] if img_tag else ""
                if img_url and not img_url.startswith("http"):
                    img_url = "https://www.vib.com.vn" + img_url

                # 2. Đi sâu vào trang chi tiết (Logic mới cho VIB)
                detail = self.scrape_card_detail(detail_url) if detail_url else None

                # 3. Tải ảnh bằng Browser
                img_to_download = detail['img'] if detail and detail['img'] else img_url
                img_id = name.lower().replace(" ", "_").replace("-", "_").replace(".", "")
                online_url = self.download_image_via_browser(img_to_download, f"vib_{img_id}")

                # 4. Gom dữ liệu nhanh từ bên ngoài (Logic bản cũ)
                features_box = item.select_one(".box-card-row.top-row")
                quick_features = [p.get_text().strip() for p in features_box.find_all("p")] if features_box else []

                card_obj = {
                    "id": f"vib-{img_id}",
                    "name": name,
                    "bankName": "VIB",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=VIB",
                    "applyUrl": detail_url if detail_url.startswith("http") else "https://www.vib.com.vn" + detail_url,
                    "cardType": "Mastercard/Visa",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["PLATINUM", "WORLD", "INFINITE", "ELITE", "SUPERCARD"]) else "Standard",
                    "cashbackHighlight": quick_features[0] if quick_features else "Ưu đãi VIB độc quyền",
                    "details": quick_features[1:] if len(quick_features) > 1 else ["Đặc quyền dành riêng cho chủ thẻ VIB"]
                }

                if detail:
                    card_obj.update({
                        "benefitsDetail": detail['benefitsDetail'],
                        "conditionsDetail": detail['conditionsDetail'],
                        "feeDetail": detail['feeDetail'],
                        "productInfoDetail": detail['productInfoDetail']
                    })
                
                card_obj['benefitsDetail'] = self.clean_garbage_data(card_obj.get('benefitsDetail', []))
                card_obj['conditionsDetail'] = self.clean_garbage_data(card_obj.get('conditionsDetail', []))
                card_obj['feeDetail'] = self.clean_garbage_data(card_obj.get('feeDetail', []))
                card_obj['productInfoDetail'] = self.clean_garbage_data(card_obj.get('productInfoDetail', []))
                
                full_text = card_obj.get('cashbackHighlight', '') + "\n"
                for b in card_obj.get('benefitsDetail', []):
                    full_text += b.get('title', '') + "\n" + b.get('content', '') + "\n"
                for p in card_obj.get('productInfoDetail', []):
                    full_text += p.get('title', '') + "\n" + p.get('content', '') + "\n"
                
                cashback_rates = self.extract_cashback_rates(full_text)
                card_obj.update(cashback_rates)
                
                cards_data.append(card_obj)
            except Exception as e:
                print(f"  ! Lỗi xử lý {name}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = VIBScraper()
    try:
        data = scraper.scrape()
        if data:
            scraper.save_to_firestore(data)
            print("--- HOÀN THÀNH ĐỒNG BỘ VIB CHI TIẾT ---")
    finally:
        scraper.quit()
