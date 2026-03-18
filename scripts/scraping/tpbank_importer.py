import os
import json
import firebase_admin
from firebase_admin import credentials, storage, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time
import tempfile
import re
import unicodedata
import base64

def slugify(text):
    text = unicodedata.normalize('NFD', text)
    text = ''.join([c for c in text if unicodedata.category(c) != 'Mn'])
    text = text.replace('đ', 'd').replace('Đ', 'D')
    text = text.lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_-]+', '_', text)
    text = text.strip('_')
    return text

def setup_firebase():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    key_path = os.path.join(current_dir, "serviceAccountKey.json")
    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'baothevn-790c6.firebasestorage.app'
        })
    return firestore.client(), storage.bucket()

def setup_driver():
    chrome_options = Options()
    chrome_options.add_argument("--window-size=1200,800")
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    return driver

def download_image_via_selenium(driver, url, filename, bucket):
    if not url: return ""
    print(f"  [+] Tải ảnh qua Chrome: {url}")
    try:
        driver.get(url)
        time.sleep(2)
        
        # Dùng JS để lấy base64 của ảnh (tránh bị chặn lần nữa)
        js_script = """
        var url = arguments[0];
        var callback = arguments[1];
        fetch(url).then(response => response.blob()).then(blob => {
            var reader = new FileReader();
            reader.onloadend = function() { callback(reader.result); };
            reader.readAsDataURL(blob);
        }).catch(err => callback("error"));
        """
        base64_data = driver.execute_async_script(js_script, url)
        if base64_data == "error" or not base64_data: return ""

        header, encoded = base64_data.split(",", 1)
        data = base64.b64decode(encoded)
        
        local_path = os.path.join(tempfile.gettempdir(), filename)
        with open(local_path, "wb") as f:
            f.write(data)

        blob = bucket.blob(f"card_images/{filename}")
        blob.upload_from_filename(local_path)
        blob.make_public()
        os.remove(local_path)
        return blob.public_url
    except Exception as e:
        print(f"  [!] Lỗi tải ảnh: {e}")
        return ""

def import_tpbank():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    with open('scripts/scraping/tpbank_cards.json', 'r', encoding='utf-8') as f:
        cards = json.load(f)
    
    for card_data in cards:
        name = card_data['name']
        slug = slugify(name)
        card_id = f"tpbank_{slug}"
        
        print(f"\n🚀 Đang xử lý: {name}")
        
        card_type = "Visa"
        if "mastercard" in name.lower(): card_type = "Mastercard"
        elif "jcb" in name.lower(): card_type = "JCB"
        
        card_tier = "Classic"
        if "signature" in name.lower(): card_tier = "Signature"
        elif "platinum" in name.lower(): card_tier = "Platinum"
        elif "world" in name.lower(): card_tier = "World"
        elif "gold" in name.lower(): card_tier = "Gold"
        elif "fest" in name.lower() or "evo" in name.lower() or "freego" in name.lower(): card_tier = "Special"

        ext = ".png" if ".png" in card_data['image_url'].lower() else ".jpg"
        image_path = download_image_via_selenium(driver, card_data['image_url'], f"{card_id}{ext}", bucket)
        
        cashback_highlight = "\n".join([f"• {h}" for h in card_data['highlights']])
        
        card_doc = {
            'id': card_id,
            'name': name,
            'bankName': 'TPBank',
            'imagePath': image_path,
            'cashbackHighlight': cashback_highlight,
            'details': card_data['highlights'],
            'applyUrl': card_data['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': [{'title': 'Lợi ích nổi bật', 'content': cashback_highlight}],
            'conditionsDetail': [{'title': 'Điều kiện đăng ký', 'content': "• Công dân Việt Nam từ 18-60 tuổi\n• Thu nhập ổn định hàng tháng\n• Các điều kiện khác theo quy định của TPBank"}],
            'feeDetail': [{'title': 'Biểu phí & Lãi suất', 'content': "• Chi tiết biểu phí áp dụng theo quy định hiện hành của TPBank."}],
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection("cards").document(card_id).set(card_doc, merge=True)
        print(f"  [OK] Đã nạp Firestore: {card_id}")

    driver.quit()
    print("\n✅ HOÀN THÀNH TPBANK!")

if __name__ == "__main__":
    import_tpbank()
