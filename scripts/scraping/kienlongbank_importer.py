import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from clean_firestore_data import clean_garbage_data, extract_cashback_rates
except ImportError:
    def clean_garbage_data(data): return data
    def extract_cashback_rates(text): return {}

import firebase_admin
from firebase_admin import credentials, storage, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from bs4 import BeautifulSoup
import time
import re
import unicodedata
import requests
import tempfile
from webdriver_manager.chrome import ChromeDriverManager

def slugify(text):
    text = unicodedata.normalize('NFD', text)
    text = ''.join([c for c in text if unicodedata.category(c) != 'Mn'])
    text = text.replace('đ', 'd').replace('Đ', 'D')
    text = text.lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_-]+', '_', text)
    return text.strip('_')

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
    chrome_options.add_argument("--window-size=1440,1000")
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    # chrome_options.add_argument("--headless")
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    return driver

def download_and_upload_image(url, card_id, bucket):
    if not url: return ""
    if url.startswith('/'): url = 'https://kienlongbank.com' + url
    
    print(f"    + Đang tải ảnh: {url}")
    headers = {'User-Agent': 'Mozilla/5.0'}
    try:
        response = requests.get(url, headers=headers, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"kienlongbank_{card_id}{ext}"
            local_path = os.path.join(tempfile.gettempdir(), filename)
            with open(local_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192): f.write(chunk)
            blob = bucket.blob(f"card_images/{filename}")
            blob.upload_from_filename(local_path)
            blob.make_public()
            os.remove(local_path)
            return blob.public_url
    except Exception as e:
        print(f"    ! Lỗi tải ảnh: {e}")
    return ""

def parse_kienlong_detail(soup):
    # 1. Tìm tên thẻ
    name = ""
    name_tag = soup.find('h1') or soup.find('h2', class_='title') or soup.find('h2')
    if name_tag:
        name = name_tag.get_text().strip()
    
    # 2. Tìm ảnh thẻ (Ưu tiên ảnh trong khối card-list hoặc ảnh có đuôi .png vì thường là ảnh thẻ cắt nền)
    img_url = ""
    # Tìm tất cả ảnh và lọc ảnh có tên chứa 'the' hoặc định dạng .png trong khối nội dung
    imgs = soup.find_all('img')
    for img in imgs:
        src = img.get('src') or ""
        # Lọc các ảnh rác
        if any(x in src.lower() for x in ['logo', 'icon', 'banner', 'phone', 'zalo', 'flags']): continue
        if '.png' in src.lower() or 'media/the' in src.lower() or 'news/' in src.lower():
            img_url = src
            # Nếu thấy ảnh .png trong khối news/ hoặc media/the thì khả năng cao là ảnh thẻ
            if '.png' in src.lower() and ('news' in src.lower() or 'the' in src.lower()):
                break
    
    # 3. Bóc tách đặc quyền
    benefits = []
    # Tìm trong các thẻ li hoặc các đoạn p có dấu +
    for el in soup.find_all(['li', 'p']):
        txt = el.get_text().strip()
        if len(txt) > 30 and (txt.startswith('+') or el.name == 'li'):
            if not any(x in txt.lower() for x in ['kienlongbank', 'đăng ký', 'liên hệ', 'biểu phí']):
                # Làm sạch text
                txt = re.sub(r'\s+', ' ', txt).strip('+ ')
                if txt not in benefits:
                    benefits.append(txt)
    
    return name, img_url, benefits

def process_kienlongbank():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    urls = [
        "https://kienlongbank.com/the-tin-dung-quoc-te-kienlongbank-visa-elite",
        "https://kienlongbank.com/the-tin-dung-quoc-te-kienlongbank-visa-contactless",
        "https://kienlongbank.com/the-tin-dung-quoc-te-kienlongbank-jcb"
    ]
    
    try:
        for url in urls:
            print(f"\n🚀 Đang xử lý: {url}")
            driver.get(url)
            time.sleep(5) # Đợi render
            
            soup = BeautifulSoup(driver.page_source, 'html.parser')
            name, raw_img_url, benefits = parse_kienlong_detail(soup)
            
            if not name:
                name = url.split('/')[-1].replace('-', ' ').title()
            
            print(f"  + Tên thẻ: {name}")
            print(f"  + Số lượng ưu đãi: {len(benefits)}")
            
            slug = slugify(name)
            card_id = f"kienlongbank_{slug}"
            
            # Xử lý ảnh
            image_path = download_and_upload_image(raw_img_url, slug, bucket)
            
            # Xác định loại thẻ
            card_type = "Visa"
            if "jcb" in name.lower(): card_type = "JCB"
            
            card_tier = "Classic"
            if any(x in name.lower() for x in ['platinum', 'elite', 'ultimate', 'infinite']):
                card_tier = "Platinum"

            benefits_detail = [
                {
                    'title': 'Đặc quyền & Ưu đãi',
                    'content': "\n".join([f"• {b}" for b in benefits])
                }
            ]
            benefits_detail = clean_garbage_data(benefits_detail)
            full_text = " ".join(benefits) + " " + " ".join([b.get('content', '') for b in benefits_detail])
            cashback_rates = extract_cashback_rates(full_text)

            card_doc = {
                'id': card_id,
                'name': name,
                'bankName': 'Kienlongbank',
                'imagePath': image_path,
                'cashbackHighlight': benefits[0] if benefits else f"Ưu đãi thẻ {name}",
                'details': benefits[:5],
                'applyUrl': url,
                'cardType': card_type,
                'cardTier': card_tier,
                'benefitsDetail': benefits_detail,
                'updatedAt': firestore.SERVER_TIMESTAMP
            }
            card_doc.update(cashback_rates)

            db.collection("cards").document(card_id).set(card_doc, merge=True)
            print(f"  [OK] Đã lưu vào Firestore: {card_id}")

    except Exception as e:
        print(f"❌ Lỗi: {e}")
    finally:
        driver.quit()
        print("\n✨ HOÀN THÀNH KIENLONGBANK!")

if __name__ == "__main__":
    process_kienlongbank()
