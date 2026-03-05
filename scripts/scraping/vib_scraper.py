import time
from bs4 import BeautifulSoup
from base_scraper import BaseScraper

class VIBScraper(BaseScraper):
    def __init__(self):
        self.url_vib = "https://www.vib.com.vn/vn/the-tin-dung"
        super().__init__("VIB", self.url_vib)

    def scrape(self):
        print(f"--- CÀO VIB (KỸ THUẬT TẢI ẢNH QUA TRÌNH DUYỆT) ---")
        self.driver.set_script_timeout(30) # Tăng thời gian chờ JS tải ảnh
        self.driver.get(self.url)
        
        print("Đang cuộn trang...")
        self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(8)

        soup = BeautifulSoup(self.driver.page_source, 'html.parser')
        card_items = soup.select(".vib-v2-box-card-content")
        print(f"Tìm thấy {len(card_items)} thẻ.")

        cards_data = []
        for idx, item in enumerate(card_items):
            try:
                name_tag = item.select_one("h3 a")
                name = name_tag.get_text().strip() if name_tag else "Thẻ VIB"
                
                print(f"  -> Xử lý: {name}")

                img_tag = item.select_one(".img-card1 img")
                img_url = img_tag['src'] if img_tag else ""
                
                # Fix link ảnh trước khi tải
                if img_url and not img_url.startswith("http"):
                    img_url = "https://www.vib.com.vn" + img_url

                # TẢI ẢNH BẰNG CHÍNH TRÌNH DUYỆT (Đảm bảo không bị chặn)
                img_id = name.lower().replace(" ", "_").replace("-", "_")
                online_url = self.download_image_via_browser(img_url, f"vib_{img_id}")

                features_box = item.select_one(".box-card-row.top-row")
                features = [p.get_text().strip() for p in features_box.find_all("p")] if features_box else []
                fees_box = item.select(".box-card-row")[1] if len(item.select(".box-card-row")) > 1 else None
                fees = [p.get_text().strip() for p in fees_box.find_all("p")] if fees_box else []

                cards_data.append({
                    "id": f"vib-{img_id}",
                    "name": name,
                    "bankName": "VIB",
                    "imagePath": online_url or "https://via.placeholder.com/400x250?text=VIB",
                    "cashbackHighlight": features[0] if features else "Ưu đãi VIB",
                    "details": features[1:] + fees,
                    "applyUrl": "https://www.vib.com.vn/vn/the-tin-dung",
                    "cardType": "Mastercard/Visa",
                    "cardTier": "Platinum"
                })
            except Exception as e:
                print(f"  ! Lỗi thẻ {idx}: {e}")

        return cards_data

if __name__ == "__main__":
    scraper = VIBScraper()
    try:
        data = scraper.scrape()
        if data:
            scraper.save_to_firestore(data)
            print("--- HOÀN THÀNH VIB (ẢNH CHUẨN) ---")
    finally:
        scraper.quit()
