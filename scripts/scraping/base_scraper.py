import json
import os
import re
import firebase_admin
from firebase_admin import credentials, storage, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import requests
import datetime
import base64

class BaseScraper:
    def __init__(self, bank_name, url):
        self.bank_name = bank_name
        self.url = url
        self._setup_firebase()
        self.driver = self._setup_driver()

    def _setup_firebase(self):
        # Tự động tìm file serviceAccountKey.json trong cùng thư mục với file này
        current_dir = os.path.dirname(os.path.abspath(__file__))
        key_path = os.path.join(current_dir, "serviceAccountKey.json")
        
        if not firebase_admin._apps:
            if os.path.exists(key_path):
                print(f"  [Firebase] Đang khởi tạo với key: {key_path}")
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred, {
                    'storageBucket': 'baothevn-790c6.firebasestorage.app'
                })
            else:
                print(f"  [CẢNH BÁO] Không tìm thấy file key tại: {key_path}")

    def _setup_driver(self):
        chrome_options = Options()
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--window-size=1920,1080")
        # chrome_options.add_argument("--headless") # Tắt chế độ chạy ẩn để chạy như người thật
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
        
        driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
        driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
        return driver

    def extract_cashback_rates(self, text):
        rates = {}
        if not text: return rates
        
        text_lower = text.lower()
        
        # Tìm các mẫu như "hoàn 10%", "hoàn tiền 5%", "cashback 6%"
        matches = re.finditer(r'(hoàn tiền|hoàn|cashback)\s*(lên đến|đến|tới|tối đa)?\s*(\d+(?:[\.,]\d+)?)\s*%', text_lower)
        
        # Dictionary map các từ khóa với loại hoàn tiền
        categories = {
            'siêu thị': 'supermarketCashbackRate',
            'coopmart': 'supermarketCashbackRate',
            'online': 'onlineCashbackRate',
            'trực tuyến': 'onlineCashbackRate',
            'du lịch': 'travelCashbackRate',
            'đặt phòng': 'travelCashbackRate',
            'vé máy bay': 'travelCashbackRate',
            'ẩm thực': 'diningCashbackRate',
            'ăn uống': 'diningCashbackRate',
            'nhà hàng': 'diningCashbackRate',
            'y tế': 'medicalCashbackRate',
            'bệnh viện': 'medicalCashbackRate',
            'giáo dục': 'educationCashbackRate',
            'học phí': 'educationCashbackRate',
            'di chuyển': 'transportCashbackRate',
            'grab': 'transportCashbackRate',
            'be': 'transportCashbackRate',
            'mua sắm': 'shoppingCashbackRate',
            'thời trang': 'shoppingCashbackRate',
            'bảo hiểm': 'insuranceCashbackRate',
            'hóa đơn': 'utilitiesCashbackRate',
            'điện nước': 'utilitiesCashbackRate',
            'giải trí': 'entertainmentCashbackRate',
            'xem phim': 'entertainmentCashbackRate',
            'gym': 'gymCashbackRate',
            'thể thao': 'gymCashbackRate',
            'chi tiêu khác': 'otherCashbackRate',
            'mọi chi tiêu': 'otherCashbackRate'
        }
        
        for match in matches:
            rate_str = match.group(3).replace(',', '.')
            try:
                rate = float(rate_str)
                # Tìm ngữ cảnh xung quanh % (trước và sau đó khoảng 50 ký tự)
                start_idx = max(0, match.start() - 50)
                end_idx = min(len(text_lower), match.end() + 50)
                context = text_lower[start_idx:end_idx]
                
                matched_category = False
                for kw, field in categories.items():
                    if kw in context:
                        if field not in rates or rate > rates[field]:
                            rates[field] = rate
                        matched_category = True
                        
                # Nếu không tìm thấy ngữ cảnh cụ thể, cho vào chi tiêu chung
                if not matched_category:
                    if 'otherCashbackRate' not in rates or rate > rates['otherCashbackRate']:
                        rates['otherCashbackRate'] = rate
                        
            except ValueError:
                continue
                
        return rates

    def clean_garbage_data(self, data_list):
        if not data_list: return []
        cleaned = []
        garbage_keywords = [
            'tải ứng dụng', 'đăng ký tư vấn', 'đăng ký trực tuyến', 'mở thẻ ngay',
            'liên hệ', 'chi tiết biểu phí', 'điều khoản', 'hướng dẫn', 'xem thêm',
            'đăng ký mở thẻ', 'mở thẻ tín dụng', 'quét mã qr', 'app store', 'google play'
        ]
        
        seen_titles = set()
        for item in data_list:
            title = item.get('title', '').strip()
            content = item.get('content', '').strip()
            
            # Loại bỏ mục không có nội dung hoặc quá ngắn
            if not content or len(content) < 5:
                continue
                
            # Loại bỏ nếu chứa từ khóa rác
            title_lower = title.lower()
            content_lower = content.lower()
            
            is_garbage = any(kw in title_lower or kw in content_lower[:40] for kw in garbage_keywords)
            
            # Xử lý các mục bị trùng lặp tiêu đề
            if not is_garbage:
                if title:
                    if title in seen_titles and len(content) < 30:
                        # Bỏ qua nếu title đã có và nội dung quá ngắn (khả năng cao là nút bấm bị lấy nhầm)
                        continue
                    seen_titles.add(title)
                    
                cleaned.append({
                    'title': title,
                    'content': content
                })
                
        # Loại bỏ các item trùng lặp hoàn toàn nội dung
        unique_cleaned = []
        seen_contents = set()
        for item in cleaned:
            if item['content'] not in seen_contents:
                unique_cleaned.append(item)
                seen_contents.add(item['content'])
                
        return unique_cleaned

    def download_image_via_browser(self, url, card_id):
        if not url: return None
        print(f"    + Đang tải ảnh qua Browser: {card_id}")
        
        try:
            js_script = """
            var url = arguments[0];
            var callback = arguments[1];
            fetch(url).then(response => response.blob()).then(blob => {
                var reader = new FileReader();
                reader.onloadend = function() {
                    callback(reader.result);
                };
                reader.readAsDataURL(blob);
            }).catch(err => callback("error"));
            """
            
            base64_data = self.driver.execute_async_script(js_script, url)
            
            if base64_data == "error" or not base64_data:
                return None

            header, encoded = base64_data.split(",", 1)
            data = base64.b64decode(encoded)
            
            ext = ".webp" if "webp" in header else ".png"
            filename = f"{card_id}{ext}"
            
            # Lưu tạm vào thư mục temp của hệ thống thay vì thư mục hiện tại
            import tempfile
            local_path = os.path.join(tempfile.gettempdir(), filename)

            with open(local_path, "wb") as f:
                f.write(data)

            bucket = storage.bucket()
            blob = bucket.blob(f"card_images/{filename}")
            blob.upload_from_filename(local_path, content_type=header.split(":")[1].split(";")[0])
            blob.make_public()

            if os.path.exists(local_path):
                os.remove(local_path)

            return blob.public_url

        except Exception as e:
            print(f"    ! Lỗi Firebase/Storage: {e}")
            return None

    def save_to_firestore(self, data):
        try:
            db = firestore.client()
            for card in data:
                db.collection("cards").document(card['id']).set(card, merge=True)
                print(f"  + Firestore: Đã lưu {card['name']}")
        except Exception as e:
            print(f"  ! Lỗi Firestore: {e}")

    def quit(self):
        if hasattr(self, 'driver'):
            self.driver.quit()
