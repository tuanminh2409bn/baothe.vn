import time
import os
import json
from bs4 import BeautifulSoup
from base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class MSBScraper(BaseScraper):
    def __init__(self):
        # URL trang danh sách thẻ (đã cập nhật từ file source)
        self.url_msb = "https://www.msb.com.vn/vi/ca-nhan/the"
        super().__init__("MSB", self.url_msb)

    def scrape(self):
        print(f"--- TRUY CẬP MSB (PHIÊN BẢN LẤY TRỌN BỘ ƯU ĐÃI) ---")
        self.driver.get(self.url)
        print("Đang chờ trang tải hoàn toàn (20s)...")
        time.sleep(20)

        try:
            # Cuộn trang sâu để kích hoạt toàn bộ widget
            for i in range(5):
                self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                time.sleep(2)

            print("Đang quét danh sách thẻ bằng Python...")
            all_a = self.driver.find_elements(By.TAG_NAME, "a")
            
            urls = []
            cards_outside_info = {}

            for a in all_a:
                try:
                    href = a.get_attribute("href")
                    if not href or "/the-" not in href: continue
                    if any(x in href for x in ["rb-dang-ky", "so-sanh-the", "bieu-phi", "facebook", "youtube"]): continue
                    
                    if href not in urls:
                        urls.append(href)
                        
                        # Dùng JS để lấy thông tin xung quanh link này ngay lập tức
                        info = self.driver.execute_script("""
                            let a = arguments[0];
                            function clean(t) { return t ? t.replace(/\\s+/g, ' ').trim() : ""; }
                            
                            let container = a.closest('.card-item, .item-the, .product-item, section, .masthead, .fragment_1203, div[class*="card"]');
                            if (!container) container = a.parentElement.parentElement; 
                            
                            let name = container.querySelector('h3, h4, .title, .masthead-title')?.innerText.trim() || a.innerText.trim();
                            let img = container.querySelector('img[src*="documents"], img[src*="The"], img[src*="image"]')?.src;
                            
                            let highlightList = [];
                            container.querySelectorAll('.masthead-info, .masthead-description, .desc, .info, p, li').forEach(el => {
                                let text = clean(el.innerText);
                                if (text && text.length > 5 && !text.includes(name) && text.length < 500) {
                                    if (!highlightList.includes(text)) highlightList.push(text);
                                }
                            });
                            
                            let highlights = highlightList.join('\\n• ').trim();
                            if (highlights) highlights = "• " + highlights;

                            return { name: name, img: img, highlights: highlights };
                        """, a)
                        
                        cards_outside_info[href] = info
                        print(f"  [+] Bắt được thẻ: {info['name']}")
                except: continue

            if not urls:
                print("Tìm thấy 0 thẻ. Widget chưa load.")
                return []

            cards_data = []
            cards_data = []
            for url in urls:
                detail = self.scrape_card_detail(url)
                if detail:
                    # ĐẨY DỮ LIỆU TỪ TRANG TRONG RA TRANG NGOÀI (HIGHLIGHT)
                    if detail['benefitsDetail']:
                        # Lấy tối đa 5 dòng lợi ích có dấu • để hiển thị ở trang danh sách
                        all_points = []
                        for b in detail['benefitsDetail']:
                            points = [p.strip() for p in b['content'].split('\n') if '•' in p]
                            all_points.extend(points)

                        if all_points:
                            # Lấy tối đa 4 dòng nổi bật nhất
                            detail['cashbackHighlight'] = "\n".join(all_points[:4])

                    # Gộp ảnh front-facing từ trang ngoài
                    info_out = cards_outside_info.get(url)
                    if info_out:
                        if info_out['img']:
                            print(f"    + Cập nhật ảnh trực diện cho: {detail['name']}")
                            online_img = self.download_image_via_browser(info_out['img'], f"msb_{detail['id']}_front")
                            if online_img: detail['imagePath'] = online_img

                        # Nếu cashbackHighlight vẫn ngắn, gộp thêm tóm tắt từ trang ngoài
                        if len(detail['cashbackHighlight']) < 50 and info_out['highlights']:
                            detail['cashbackHighlight'] = info_out['highlights'] + "\n" + detail['cashbackHighlight']

                    cards_data.append(detail)

            
            return cards_data

        except Exception as e:
            print(f"Lỗi: {e}")
            return []

    def scrape_card_detail(self, url):
        print(f"  -> Đang cào chi tiết: {url}")
        try:
            self.driver.get(url)
            time.sleep(10)

            detail_data = self.driver.execute_script("""
                function clean(t) { return t ? t.replace(/\\s+/g, ' ').trim() : ""; }
                function extractList(parent) {
                    if (!parent) return "";
                    let lis = parent.querySelectorAll('li');
                    if (lis.length > 0) return Array.from(lis).map(li => "• " + clean(li.innerText)).join('\\n');
                    let ps = parent.querySelectorAll('p');
                    if (ps.length > 1) return Array.from(ps).map(p => "• " + clean(p.innerText)).join('\\n');
                    return clean(parent.innerText);
                }

                let data = {
                    name: clean(document.querySelector('h1')?.innerText || document.title.split('|')[0]),
                    highlight: clean(document.querySelector('.masthead-info, .banner-info')?.innerText),
                    img: document.querySelector('img[src*="WorldElite"], .masthead.card-detail img, .banner img, .img-wrap img')?.src,
                    benefits: [],
                    conditions: [],
                    fees: []
                };

                // Lợi ích chi tiết
                document.querySelectorAll('.detail-item, .benefit-item, .msb-benefit-block').forEach(item => {
                    let title = clean(item.querySelector('.headline-item, .title, h4')?.innerText);
                    let content = extractList(item.querySelector('.detail-description, .content, .desc, .item-content'));
                    if (title) data.benefits.push({ title, content });
                });

                // Điều kiện
                document.querySelectorAll('.tab-pane, .detail-card-section').forEach(sec => {
                    let h = clean(sec.querySelector('h3, h4')?.innerText);
                    if (h.includes("Điều kiện") || h.includes("Đối tượng")) {
                        let content = extractList(sec.querySelector('.tab-content-list, ul, .list, .content'));
                        if (content) data.conditions.push({ title: h, content });
                    }
                });

                // Biểu phí
                document.querySelectorAll('.item-table-list .item, .fee-item').forEach(item => {
                    let title = clean(item.querySelector('.item-header, .fee-title')?.innerText);
                    let content = clean(item.querySelector('.item-content, .fee-value')?.innerText);
                    if (title) data.fees.push({ title, content });
                });

                return data;
            """)

            if not detail_data['name'] or len(detail_data['name']) < 5:
                return None

            img_id = detail_data['name'].lower().replace(" ", "_").replace("-", "_").replace(".", "")
            
            # Selector đặc biệt cho World Elite và ảnh banner
            if not detail_data['img']:
                try:
                    img_el = self.driver.find_element(By.CSS_SELECTOR, "img[src*='the-'], img[src*='card'], img[src*='World'], .banner img")
                    detail_data['img'] = img_el.get_attribute("src")
                except: pass

            online_img = self.download_image_via_browser(detail_data['img'], f"msb_{img_id}")

            detail_data['benefits'] = self.clean_garbage_data(detail_data['benefits'])
            detail_data['conditions'] = self.clean_garbage_data(detail_data['conditions'])
            detail_data['fees'] = self.clean_garbage_data(detail_data['fees'])

            full_text = str(detail_data['highlight'] or "") + " " + " ".join([b.get('content', '') for b in detail_data['benefits']])
            cashback_rates = self.extract_cashback_rates(full_text)

            card_doc = {
                "id": f"msb-{img_id}",
                "name": detail_data['name'],
                "bankName": "MSB",
                "imagePath": online_img or "https://via.placeholder.com/400x250?text=MSB",
                "applyUrl": url,
                "cardType": "Visa/Mastercard",
                "cardTier": "Premium" if any(x in detail_data['name'].upper() for x in ["SIGNATURE", "WORLD", "PLATINUM", "ELITE", "DIGI"]) else "Standard",
                "cashbackHighlight": detail_data['highlight'] or "Hoàn tiền & Ưu đãi đặc quyền",
                "benefitsDetail": detail_data['benefits'],
                "conditionsDetail": detail_data['conditions'],
                "feeDetail": detail_data['fees'],
                "productInfoDetail": []
            }
            card_doc.update(cashback_rates)
            return card_doc
        except Exception as e:
            print(f"    ! Lỗi cào chi tiết {url}: {e}")
            return None

if __name__ == "__main__":
    scraper = MSBScraper()
    try:
        data = scraper.scrape()
        if data:
            with open("msb_data.json", "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
            print(f"--- HOÀN THÀNH: Đã cào {len(data)} thẻ vào msb_data.json ---")
            scraper.save_to_firestore(data)
    finally:
        scraper.quit()
