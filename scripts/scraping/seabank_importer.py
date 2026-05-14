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
import sys

# Import các hàm làm sạch dùng chung
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from clean_firestore_data import clean_garbage_data, extract_cashback_rates
except ImportError:
    def clean_garbage_data(data): return data
    def extract_cashback_rates(text): return {}

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
    # Không dùng headless để người dùng có thể can thiệp nếu cần
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    return driver

def download_and_upload_image(url, card_id, bucket):
    if not url or not url.startswith('http'): return ""
    print(f"    + Đang nạp ảnh: {card_id}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".jpg"
            if ".png" in url.lower(): ext = ".png"
            elif ".webp" in url.lower(): ext = ".webp"
            
            filename = f"seabank_{card_id}{ext}"
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
    return re.sub(r'\s+', ' ', text).strip()

def process_seabank():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    # 1. Lấy danh sách thẻ từ trang chủ
    list_url = "https://seabank.com.vn/ca-nhan/the/the-tin-dung-quoc-te"
    print(f"🚀 Truy cập SeABank: {list_url}")
    driver.get(list_url)
    time.sleep(5) # Đợi trang load
    
    soup_list = BeautifulSoup(driver.page_source, 'html.parser')
    all_links = soup_list.find_all('a', href=re.compile(r'/ca-nhan/the/the-tin-dung-quoc-te/'))
    
    seen_urls = set()
    cards_to_process = []
    for link in all_links:
        full_url = "https://seabank.com.vn" + link['href'] if link['href'].startswith('/') else link['href']
        if full_url not in seen_urls:
            seen_urls.add(full_url)
            # Lấy tên và ảnh ngay tại trang ngoài để đảm bảo có ảnh trực diện
            name_el = link.find(['h3', 'h4', 'p'], class_=lambda x: x and 'font-semibold' in x)
            name = clean_text(name_el.get_text()) if name_el else "Thẻ tín dụng SeABank"
            
            img_el = link.find('img')
            img_url = img_el.get('src') if img_el else ""
            
            # Lấy ưu đãi tóm tắt
            highlights = []
            highlight_els = link.find_all('p', class_=lambda x: x and 'text-gray-process-text' in x)
            for h in highlight_els:
                t = clean_text(h.get_text())
                if t: highlights.append(f"• {t}")
                
            cards_to_process.append({
                'url': full_url,
                'name': name,
                'img_url': img_url,
                'highlights': highlights
            })

    print(f"✅ Tìm thấy {len(cards_to_process)} thẻ SeABank duy nhất.")

    # 2. Truy cập từng thẻ để lấy chi tiết
    for card in cards_to_process:
        print(f"\n🔍 Đang xử lý chi tiết: {card['name']}")
        driver.get(card['url'])
        time.sleep(5) # Đợi trang chi tiết load
        
        soup_detail = BeautifulSoup(driver.page_source, 'html.parser')
        
        slug = slugify(card['name'])
        card_id = f"seabank_{slug}"
        image_path = download_and_upload_image(card['img_url'], slug, bucket)

        card_doc = {
            'id': card_id,
            'name': card['name'],
            'bankName': 'SeABank',
            'imagePath': image_path,
            'cashbackHighlight': card['highlights'][0] if card['highlights'] else "Ưu đãi thẻ SeABank",
            'details': card['highlights'],
            'applyUrl': card['url'],
            'cardType': "Visa" if "visa" in card['name'].lower() else ("Mastercard" if "master" in card['name'].lower() else "JCB"),
            'cardTier': "Platinum" if any(x in card['name'].lower() for x in ['platinum', 'signature', 'priority', 'elite']) else "Classic",
            'updatedAt': firestore.SERVER_TIMESTAMP
        }

        # Bóc tách nội dung chi tiết (biểu phí, lợi ích, điều kiện)
        content_div = soup_detail.find('div', id='detail-product-content') or \
                     soup_detail.find('div', class_='dangerously-set-inner-html-content')
        
        if content_div:
            benefits_sections = []
            rows = content_div.find_all('tr')
            for row in rows:
                cols = row.find_all('td')
                if len(cols) >= 2:
                    title = clean_text(cols[0].get_text())
                    content = clean_text(cols[1].get_text(separator='\n'))
                    bullet_content = "\n".join([f"• {line.strip()}" for line in content.split('\n') if line.strip()])
                    benefits_sections.append({'title': title, 'content': bullet_content})
            
            if not benefits_sections:
                # Nếu không có bảng, lấy theo div/p
                text_content = clean_text(content_div.get_text(separator='\n'))
                benefits_sections.append({'title': 'Thông tin sản phẩm', 'content': text_content})

            if benefits_sections:
                card_doc['benefitsDetail'] = [b for b in benefits_sections if any(x in b['title'].lower() for x in ['ưu đãi', 'lợi ích', 'đặc điểm', 'tính năng'])]
                card_doc['conditionsDetail'] = [b for b in benefits_sections if any(x in b['title'].lower() for x in ['điều kiện', 'đối tượng', 'thủ tục'])]
                card_doc['feeDetail'] = [b for b in benefits_sections if any(x in b['title'].lower() for x in ['phí', 'lãi suất', 'biểu phí'])]
                
                if not card_doc.get('benefitsDetail'):
                    card_doc['benefitsDetail'] = benefits_sections[:3]

        card_doc['benefitsDetail'] = clean_garbage_data(card_doc.get('benefitsDetail', []))
        card_doc['conditionsDetail'] = clean_garbage_data(card_doc.get('conditionsDetail', []))
        card_doc['feeDetail'] = clean_garbage_data(card_doc.get('feeDetail', []))
        card_doc['productInfoDetail'] = clean_garbage_data(card_doc.get('productInfoDetail', []))
        
        full_text = card_doc.get('cashbackHighlight', '') + "\n"
        for b in card_doc.get('benefitsDetail', []):
            full_text += b.get('title', '') + "\n" + b.get('content', '') + "\n"
        for p in card_doc.get('productInfoDetail', []):
            full_text += p.get('title', '') + "\n" + p.get('content', '') + "\n"
        
        cashback_rates = extract_cashback_rates(full_text)
        card_doc.update(cashback_rates)

        db.collection("cards").document(card_id).set(card_doc, merge=True)
        print(f"  [OK] Đã lưu: {card_id} (Có {len(card_doc.get('benefitsDetail', []))} phần chi tiết)")

    driver.quit()
    print("\n✨ HOÀN THÀNH SEABANK VỚI TRÌNH DUYỆT THẬT!")

if __name__ == "__main__":
    process_seabank()
