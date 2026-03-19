import os
import json
import firebase_admin
from firebase_admin import credentials, storage, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
import time
import re
import unicodedata
import requests
import tempfile

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
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    return driver

def download_and_upload_image(url, card_id, bucket):
    if not url: return ""
    if url.startswith('/'): url = 'https://www.vietbank.com.vn' + url
    
    print(f"    + Đang nạp ảnh: {card_id}")
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://www.vietbank.com.vn/',
    }
    
    try:
        response = requests.get(url, headers=headers, stream=True, timeout=30)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"vietbank_{card_id}{ext}"
            local_path = os.path.join(tempfile.gettempdir(), filename)
            with open(local_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            blob = bucket.blob(f"card_images/{filename}")
            blob.upload_from_filename(local_path)
            blob.make_public()
            os.remove(local_path)
            return blob.public_url
    except Exception as e:
        print(f"    ! Lỗi ảnh: {e}")
    return ""

def clean_text(text):
    if not text: return ""
    t = text.replace('\xa0', ' ').replace('&nbsp;', ' ')
    t = re.sub(r'\s+', ' ', t).strip()
    return t

def process_vietbank():
    db, bucket = setup_firebase()
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    source_path = os.path.join(current_dir, "vietbank_source.html")
    with open(source_path, 'r', encoding='utf-8') as f:
        soup_list = BeautifulSoup(f.read(), 'html.parser')

    card_items = soup_list.select('.card-slick .item')
    seen_urls = set()
    cards_to_process = []
    
    for item in card_items:
        link_el = item.find('a', class_='card-item')
        if link_el:
            href = link_el['href'].split('?')[0]
            full_url = href if href.startswith('http') else "https://www.vietbank.com.vn" + href
            
            name_el = item.find('div', class_='card-name')
            name = clean_text(name_el.get_text()) if name_el else ""
            
            # Lấy ảnh từ trang ngoài (vì ảnh này đã hiển thị tốt trên app)
            img_el = item.find('div', class_='card-img').find('img') if item.find('div', class_='card-img') else None
            img_url = img_el.get('data-src') or img_el.get('src') if img_el else ""
            
            if any(x in full_url.lower() for x in ['tin-dung', 'credit']):
                if full_url not in seen_urls:
                    seen_urls.add(full_url)
                    cards_to_process.append({
                        'url': full_url,
                        'name': name,
                        'img_url': img_url
                    })

    print(f"✅ Tìm thấy {len(cards_to_process)} thẻ VietBank.")

    if cards_to_process:
        driver = setup_driver()
        for card in cards_to_process:
            print(f"\n🔍 Đang xử lý: {card['name']}")
            try:
                driver.get(card['url'])
                time.sleep(6) # Đợi trang load kỹ
                soup_detail = BeautifulSoup(driver.page_source, 'html.parser')
                
                # Ưu đãi & Tính năng
                benefits = []
                # Bóc tách mọi khối nội dung có thể chứa ưu đãi
                content_blocks = soup_detail.select('.feature-content, .product-feature .content, .product-limit .content, .promotion-des')
                for block in content_blocks:
                    # Lấy từng dòng (nếu có li) hoặc tách theo dấu chấm
                    for p in block.find_all(['p', 'li', 'div', 'strong']):
                        txt = clean_text(p.get_text())
                        if txt and len(txt) > 10 and txt not in benefits:
                            if "chi tiết xem tại" not in txt.lower():
                                benefits.append(txt)
                
                # Tiện ích bổ sung
                promotions = []
                promo_items = soup_detail.select('.product-promotion .promotion')
                for p in promo_items:
                    name_p = clean_text(p.find('div', class_='promotion-name').get_text()) if p.find('div', class_='promotion-name') else ""
                    des_p = clean_text(p.find('div', class_='promotion-des').get_text()) if p.find('div', class_='promotion-des') else ""
                    if name_p and des_p:
                        promotions.append({'title': name_p, 'content': des_p})

                slug = slugify(card['name'])
                card_id = f"vietbank_{slug}"
                
                # Tải ảnh từ URL đã lấy từ trang ngoài
                image_path = download_and_upload_image(card['img_url'], slug, bucket)

                card_doc = {
                    'id': card_id,
                    'name': card['name'],
                    'bankName': 'VietBank',
                    'imagePath': image_path,
                    'cashbackHighlight': benefits[0] if benefits else "Ưu đãi thẻ VietBank",
                    'details': benefits[:5], # Chỉ lấy 5 ưu đãi chính cho phần tóm tắt
                    'applyUrl': card['url'],
                    'cardType': "Mastercard" if "master" in card['name'].lower() else "Visa",
                    'cardTier': "Platinum" if any(x in card['name'].lower() for x in ['platinum', 'luxury']) else "Classic",
                    'benefitsDetail': [
                        {'title': 'Ưu đãi & Tính năng', 'content': "\n".join([f"• {b}" for b in benefits])}
                    ] + promotions,
                    'updatedAt': firestore.SERVER_TIMESTAMP
                }

                db.collection("cards").document(card_id).set(card_doc, merge=True)
                print(f"  [OK] Đã lưu: {card_id} (Có {len(benefits)} phần ưu đãi)")
            except Exception as e:
                print(f"  ! Lỗi xử lý thẻ {card['url']}: {e}")
        
        driver.quit()
    
    print("\n✨ HOÀN THÀNH VIETBANK - ĐÃ SỬA LỖI ẢNH VÀ ƯU ĐÃI!")

if __name__ == "__main__":
    process_vietbank()
