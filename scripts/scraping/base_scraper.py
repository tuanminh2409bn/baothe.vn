import json
import os
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
        key_path = "scripts/scraping/serviceAccountKey.json"
        if not firebase_admin._apps:
            if os.path.exists(key_path):
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred, {
                    'storageBucket': 'baothevn-790c6.firebasestorage.app'
                })

    def _setup_driver(self):
        chrome_options = Options()
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--window-size=1920,1080")
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        return webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)

    def download_image_via_browser(self, url, card_id):
        """Kỹ thuật tối thượng: Dùng chính trình duyệt Chrome để tải ảnh dưới dạng Base64"""
        if not url: return None
        print(f"    + Đang tải ảnh qua Browser: {card_id}")
        
        try:
            # Lệnh JS để ép trình duyệt tải ảnh và trả về chuỗi Base64
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
                print(f"    ! Browser không tải được ảnh: {url}")
                return None

            # Xử lý chuỗi Base64
            header, encoded = base64_data.split(",", 1)
            data = base64.b64decode(encoded)
            
            # Xác định định dạng
            ext = ".webp" if "webp" in header else ".png"
            filename = f"{card_id}{ext}"
            local_path = f"temp_{filename}"

            # Lưu tạm ra file
            with open(local_path, "wb") as f:
                f.write(data)

            # Đẩy lên Firebase Storage
            bucket = storage.bucket()
            blob = bucket.blob(f"card_images/{filename}")
            blob.upload_from_filename(local_path, content_type=header.split(":")[1].split(";")[0])
            blob.make_public()

            if os.path.exists(local_path):
                os.remove(local_path)

            return blob.public_url

        except Exception as e:
            print(f"    ! Lỗi kỹ thuật Browser Download: {e}")
            return None

    def save_to_firestore(self, data):
        db = firestore.client()
        for card in data:
            db.collection("cards").document(card['id']).set(card, merge=True)
            print(f"  + Thành công: {card['name']}")

    def quit(self):
        self.driver.quit()
