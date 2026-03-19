import os
import firebase_admin
from firebase_admin import credentials, storage, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
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
    print(f"    + Đang tải ảnh: {url}")
    headers = {'User-Agent': 'Mozilla/5.0'}
    try:
        response = requests.get(url, headers=headers, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"bvbank_{card_id}{ext}"
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

def parse_bvbank_detail(soup):
    # 1. Highlight (thường là đoạn text dưới H1)
    highlight = ""
    banner = soup.select_one('section.module-banner-card-detail')
    if banner:
        h_el = banner.find('p')
        if h_el: highlight = h_el.get_text().strip()

    # 2. Chi tiết ưu đãi & đặc quyền
    benefits_detail = []
    items = soup.select('section.module-convenience .co-list .item')
    for item in items:
        title_el = item.find('strong')
        content_el = item.find('div', class_='content-wrap')
        
        if title_el and content_el:
            title = title_el.get_text().strip()
            # Loại bỏ title khỏi content_el để lấy phần còn lại
            title_el.extract()
            content = content_el.get_text(separator="\n").strip()
            # Làm sạch content
            content = "\n".join([line.strip() for line in content.split("\n") if line.strip()])
            
            if title and content:
                benefits_detail.append({
                    'title': title,
                    'content': content
                })
    
    return highlight, benefits_detail

def process_bvbank():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    list_url = "https://bvbank.net.vn/ca-nhan/the/tat-ca-cac-the/"
    
    try:
        print(f"\n🚀 Truy cập danh sách thẻ BVBank: {list_url}")
        driver.get(list_url)
        time.sleep(5)
        
        soup = BeautifulSoup(driver.page_source, 'html.parser')
        card_items = soup.select('.module-card-item')
        
        all_cards = []
        for item in card_items:
            name = item.get('data-name', '').strip()
            # Chỉ lấy thẻ tín dụng
            if "tín dụng" not in name.lower(): continue
            
            link_el = item.find('a', href=True)
            url = link_el['href'] if link_el else ""
            img_url = item.get('data-image', '')
            
            if name and url:
                all_cards.append({
                    'name': name,
                    'url': url,
                    'img_url': img_url
                })
                print(f"  + Tìm thấy: {name}")

        print(f"\n✅ Tổng cộng tìm thấy {len(all_cards)} thẻ tín dụng.")

        for card in all_cards:
            print(f"\n🔍 Xử lý: {card['name']}")
            driver.get(card['url'])
            time.sleep(5)
            
            detail_soup = BeautifulSoup(driver.page_source, 'html.parser')
            highlight, benefits = parse_bvbank_detail(detail_soup)
            
            slug = slugify(card['name'])
            card_id = f"bvbank_{slug}"
            
            # Xử lý ảnh
            image_path = download_and_upload_image(card['img_url'], slug, bucket)
            
            # Xác định loại thẻ
            name_lower = card['name'].lower()
            card_type = "Visa"
            if "jcb" in name_lower: card_type = "JCB"
            elif "mastercard" in name_lower: card_type = "Mastercard"
            
            card_tier = "Classic"
            if any(x in name_lower for x in ['platinum', 'signature', 'infinite', 'ultimate']):
                card_tier = "Platinum"

            card_doc = {
                'id': card_id,
                'name': card['name'],
                'bankName': 'BVBank',
                'imagePath': image_path,
                'cashbackHighlight': highlight if highlight else f"Ưu đãi {card['name']}",
                'details': [b['title'] for b in benefits[:5]],
                'applyUrl': card['url'],
                'cardType': card_type,
                'cardTier': card_tier,
                'benefitsDetail': benefits,
                'updatedAt': firestore.SERVER_TIMESTAMP
            }

            db.collection("cards").document(card_id).set(card_doc, merge=True)
            print(f"  [OK] Đã lưu vào Firestore: {card_id}")

    except Exception as e:
        print(f"❌ Lỗi: {e}")
    finally:
        driver.quit()
        print("\n✨ HOÀN THÀNH BVBANK!")

if __name__ == "__main__":
    process_bvbank()
