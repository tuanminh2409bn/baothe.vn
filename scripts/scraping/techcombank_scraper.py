import time
import os
import re
import json
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class TechcombankScraper(BaseScraper):
    def __init__(self):
        # URL danh sách thẻ tín dụng Techcombank
        self.url_tcb = "https://techcombank.com/khach-hang-ca-nhan/chi-tieu/the/the-tin-dung"
        super().__init__("Techcombank", self.url_tcb)

    def scrape_card_detail(self, url):
        """Truy cập trang chi tiết thẻ Techcombank và trích xuất dữ liệu sâu theo cấu trúc HTML mới"""
        print(f"    -> Đang cào chi tiết TCB (Cấu trúc sâu): {url}")
        try:
            self.driver.get(url)
            # Chờ trang tải nội dung (React/Next.js)
            time.sleep(12) 
            
            # Cuộn trang để kích hoạt lazy load và các modal
            for i in range(10):
                self.driver.execute_script(f"window.scrollTo(0, {i*600});")
                time.sleep(1)

            detail_data = self.driver.execute_script("""
                let res = { 
                    img_internal: "", 
                    benefitsDetail: [], 
                    conditionsDetail: [], 
                    productInfoDetail: [], 
                    feeDetail: [] 
                };

                // 1. Ảnh thẻ chính (Ưu tiên ảnh Desktop Masthead)
                let mastheadImg = document.querySelector('.hero-product__wrapper-image img');
                if (mastheadImg) res.img_internal = mastheadImg.src;

                // 2. Quyền lợi thẻ (Từ các khối list-tile và Modals đi kèm)
                document.querySelectorAll('.list-tile__tile-item').forEach(item => {
                    let title = item.querySelector('h3')?.innerText.trim();
                    let desc = item.querySelector('.list-tile__card-description')?.innerText.trim();
                    if (title) {
                        res.benefitsDetail.push({ title: title, content: desc || "" });
                    }
                });

                // 3. Tính năng thẻ (Từ Accordion "Tính năng thẻ")
                document.querySelectorAll('.card-product-feature__item').forEach(item => {
                    let title = item.querySelector('.card-product-feature__item__content__title')?.innerText.trim();
                    let desc = item.querySelector('.card-product-feature__item__description')?.innerText.trim();
                    if (title) {
                        res.productInfoDetail.push({ title: title, content: desc || "" });
                    }
                });

                // 4. Biểu phí thẻ (Bóc tách từ bảng table.alternate)
                let feeTable = document.querySelector('table.alternate');
                if (feeTable) {
                    let rows = Array.from(feeTable.querySelectorAll('tr'));
                    let headers = Array.from(rows[0].querySelectorAll('th')).map(th => th.innerText.trim());
                    
                    for (let i = 1; i < rows.length; i++) {
                        let cols = Array.from(rows[i].querySelectorAll('td'));
                        if (cols.length >= 2) {
                            let feeName = cols[0].innerText.trim();
                            // Kết hợp thông tin phí của các đối tượng khách hàng
                            let feeValue = "";
                            for (let j = 1; j < cols.length; j++) {
                                let label = headers[j] || "Phí";
                                feeValue += label + ": " + cols[j].innerText.trim() + " | ";
                            }
                            res.feeDetail.push({ 
                                title: feeName.replace(/\\n/g, ' '), 
                                content: feeValue.replace(/ \\| $/, '') 
                            });
                        }
                    }
                }

                // 5. Điều kiện (Tìm các đoạn văn có từ khóa Điều kiện hoặc Đối tượng)
                document.querySelectorAll('.cmp-text').forEach(block => {
                    let text = block.innerText;
                    if (text.includes('Điều kiện') || text.includes('Đối tượng') || text.includes('Hồ sơ')) {
                        let title = block.querySelector('h2, h3')?.innerText.trim() || "Điều kiện phát hành";
                        if (!res.conditionsDetail.some(c => c.title === title)) {
                            res.conditionsDetail.push({ title: title, content: text.replace(title, '').trim() });
                        }
                    }
                });

                return res;
            """)
            return detail_data
        except Exception as e:
            print(f"      ! Lỗi cào chi tiết: {e}")
            return None

    def scrape(self):
        print(f"--- TRUY CẬP TECHCOMBANK (NGƯỜI THẬT DUYỆT WEB) ---")
        self.driver.get(self.url)
        time.sleep(10) 

        # Cuộn trang để hiển thị hết các nhóm thẻ (Phổ biến, Ưu tiên, Dặm bay...)
        print("Đang quét danh sách thẻ từ các khối pick-card-container...")
        for _ in range(6):
            self.driver.execute_script("window.scrollBy(0, 1000);")
            time.sleep(2)

        # Trích xuất thông tin thẻ từ cấu trúc HTML danh sách
        cards_preview = self.driver.execute_script("""
            let results = [];
            document.querySelectorAll('.pick-card-container').forEach(card => {
                let name = card.querySelector('.pick-card-top .label')?.innerText.trim();
                let img_preview = card.querySelector('.pick-card-top-image')?.src;
                let detail_url = card.querySelector('a.button-link')?.href;
                
                let highlights = [];
                card.querySelectorAll('.content-item-text p').forEach(p => {
                    highlights.push(p.innerText.trim());
                });

                if (name && detail_url) {
                    results.push({ name, img_preview, detail_url, highlights });
                }
            });
            return results;
        """)

        print(f"Phát hiện {len(cards_preview)} thẻ Techcombank. Bắt đầu xử lý chi tiết từng thẻ...")

        cards_data = []
        for pre in cards_preview:
            # Chỉ lấy thẻ tín dụng (loại bỏ thẻ thanh toán/ghi nợ nếu có)
            if "the-thanh-toan" in pre['detail_url'] or "the-ghi-no" in pre['detail_url']: continue
            
            try:
                # Đi sâu vào trang chi tiết
                detail = self.scrape_card_detail(pre['detail_url'])
                
                # Làm sạch dữ liệu
                b_detail = self.clean_garbage_data(detail['benefitsDetail']) if detail else []
                c_detail = self.clean_garbage_data(detail['conditionsDetail']) if detail else []
                p_detail = self.clean_garbage_data(detail['productInfoDetail']) if detail else []
                f_detail = self.clean_garbage_data(detail['feeDetail']) if detail else []
                
                name = pre['name']
                print(f"  [OK] Đã lấy: {name}")

                # Xử lý ảnh: Ưu tiên ảnh Masthead bên trong, nếu không có lấy ảnh preview
                final_img_url = (detail['img_internal'] if detail and detail['img_internal'] else pre['img_preview'])
                
                # Tải ảnh lên Firebase Storage qua Browser Base64
                img_id = name.lower().replace(" ", "_").replace("-", "_").replace(".", "").replace("/", "_")
                img_id = re.sub(r'[^a-z0-9_]', '', img_id)
                online_url = self.download_image_via_browser(final_img_url, f"tcb_{img_id}")
                
                # Trích xuất hoàn tiền
                full_text = " ".join(pre.get('highlights', [])) + " " + " ".join([d['content'] for d in b_detail + p_detail])
                cashback_rates = self.extract_cashback_rates(full_text)

                card_obj = {
                    "id": f"tcb-{img_id}",
                    "name": name,
                    "bankName": "Techcombank",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=TCB",
                    "applyUrl": pre['detail_url'],
                    "cardType": "Visa/Mastercard",
                    "cardTier": "Premium" if any(kw in name.upper() for kw in ["SIGNATURE", "INFINITE", "PLATINUM", "PRIORITY"]) else "Standard",
                    "cashbackHighlight": pre['highlights'][0] if pre['highlights'] else "Đặc quyền chủ thẻ Techcombank",
                    "details": pre['highlights'] if pre['highlights'] else ["Ưu đãi thẻ Techcombank"],
                    "benefitsDetail": b_detail,
                    "conditionsDetail": c_detail,
                    "productInfoDetail": p_detail,
                    "feeDetail": f_detail
                }
                
                card_obj.update(cashback_rates)
                cards_data.append(card_obj)
            except Exception as e:
                print(f"  ! Lỗi xử lý {pre['name']}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = TechcombankScraper()
    try:
        data = scraper.scrape()
        if data:
            scraper.save_to_firestore(data)
            print(f"--- HOÀN THÀNH: ĐÃ ĐỒNG BỘ {len(data)} THẺ TECHCOMBANK CHI TIẾT ---")
        else:
            print("--- KHÔNG LẤY ĐƯỢC DỮ LIỆU THẺ ---")
    finally:
        scraper.quit()
