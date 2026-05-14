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

def clean_text(text):
    if not text: return ""
    text = re.sub(r'\s+', ' ', text.replace('\xa0', ' ')).strip()
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
    chrome_options.add_argument("--window-size=1440,1000")
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    chrome_options.add_argument("--disable-blink-features=AutomationControlled")
    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
    chrome_options.add_experimental_option('useAutomationExtension', False)
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    driver.set_page_load_timeout(60)
    return driver

def download_and_upload_image(url, card_id, bucket):
    if not url: return ""
    if not url.startswith('http'): url = 'https://www.namabank.com.vn/' + url.lstrip('/')
    print(f"    + Đang tải ảnh: {url}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"namabank_{card_id}{ext}"
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

def parse_namabank_detail(soup):
    benefits = []
    
    # 1. Bóc tách "Lý do chọn" (section-2)
    s2 = soup.find(id='section-2')
    if s2:
        # Tìm tất cả các đoạn text quan trọng trong section 2
        items = s2.select('ul li, p, .item-text')
        for item in items:
            txt = clean_text(item.get_text())
            if 15 < len(txt) < 300 and "Lý do chọn" not in txt:
                if txt not in [b['content'] for b in benefits]:
                    benefits.append({'title': 'Lý do chọn', 'content': txt})

    # 2. Bóc tách "Tính năng nổi bật" (section-3)
    s3 = soup.find(id='section-3')
    if s3:
        # Tìm tất cả các đoạn text quan trọng trong section 3
        items = s3.select('ul li, p, .item-text')
        for item in items:
            txt = clean_text(item.get_text())
            if 15 < len(txt) < 400 and "Tính năng nổi bật" not in txt:
                # Tránh trùng lặp với section 2
                if txt not in [b['content'] for b in benefits]:
                    benefits.append({'title': 'Tính năng nổi bật', 'content': txt})
            
    return benefits

def process_namabank():
    db, bucket = setup_firebase()
    
    print("--- PHÂN TÍCH DANH SÁCH THẺ NAM A BANK TỪ WEB ---")
    driver = setup_driver()
    url = "https://www.namabank.com.vn/the-tin-dung"
    
    try:
        driver.get(url)
        time.sleep(5)
        for _ in range(3):
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(2)
        soup = BeautifulSoup(driver.page_source, 'html.parser')
    except Exception as e:
        print(f"  [!] Lỗi tải trang Nam A Bank: {e}")
        driver.quit()
        return

    all_cards = []
    # Nam A Bank dùng div.item cho mỗi thẻ
    card_items = soup.find_all('div', class_='item')
    
    for item in card_items:
        title_el = item.find('h5')
        if not title_el: continue
        name = clean_text(title_el.get_text())
        
        # Chỉ lấy thẻ tín dụng (thường là in hoa, chứa từ khóa "THẺ TÍN DỤNG" hoặc "HAPPY")
        if "THẺ TÍN DỤNG" not in name.upper() and "HAPPY" not in name.upper(): continue
        
        link_el = item.find('a', href=True)
        link = link_el['href'] if link_el else ""
        if link and not link.startswith('http'): link = "https://www.namabank.com.vn" + link
        
        img_el = item.find('img')
        img_url = img_el.get('data-src') or img_el.get('src') if img_el else ""
        if img_url and not img_url.startswith('http'): img_url = "https://www.namabank.com.vn" + img_url
        
        # Lấy thông tin tóm tắt từ figcaption
        highlights = []
        fig = item.find('figcaption')
        if fig:
            for li in fig.select('ul li'):
                txt = clean_text(li.get_text())
                if txt: highlights.append(txt)
        
        summary = " | ".join(highlights) if highlights else f"Tận hưởng ưu đãi cùng {name}"

        if name and not any(c['name'] == name for c in all_cards):
            all_cards.append({
                'name': name,
                'url': link,
                'img_url': img_url,
                'summary': summary,
                'highlights': highlights
            })
            print(f"  + Tìm thấy: {name} ({summary})")

    print(f"\n🚀 Tổng cộng: {len(all_cards)} thẻ Nam A Bank.")

    for card in all_cards:
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        
        print(f"\n🔍 Đang xử lý chi tiết: {card['name']}")
        try:
            driver.get(card['url'])
            time.sleep(3)
            detail_soup = BeautifulSoup(driver.page_source, 'html.parser')
            card_benefits = parse_namabank_detail(detail_soup)
        except Exception as e:
            print(f"  [!] Lỗi lấy chi tiết thẻ {card['name']}: {e}")
            card_benefits = []
        
        name_lower = card['name'].lower()
        card_type = "Visa"
        if "jcb" in name_lower: card_type = "JCB"
        elif "mastercard" in name_lower: card_type = "Mastercard"
        
        card_tier = "Classic"
        if any(x in name_lower for x in ['platinum', 'infinite', 'signature', 'gold']):
            card_tier = "Platinum" if "platinum" in name_lower or "signature" in name_lower else "Gold"

        # Nếu không có chi tiết, tự tạo một mục từ tóm tắt
        if not card_benefits:
            card_benefits = [{'title': 'Tiện ích thẻ', 'content': "\n".join([f"• {h}" for h in card['highlights']])}]

        card_benefits = clean_garbage_data(card_benefits)
        full_text = card['summary'] + " " + " ".join([b.get('content', '') for b in card_benefits])
        cashback_rates = extract_cashback_rates(full_text)

        card_doc = {
            'id': f"namabank_{slug}",
            'name': card['name'],
            'bankName': 'Nam A Bank',
            'imagePath': image_path,
            'cashbackHighlight': card['summary'],
            'details': card['highlights'] if card['highlights'] else [b.get('content', '') for b in card_benefits[:3]],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': card_benefits,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        card_doc.update(cashback_rates)
        
        db.collection("cards").document(card_doc['id']).set(card_doc, merge=True)
        print(f"  [OK] Đã lưu: {card_doc['id']}")

    print("\n✨ HOÀN THÀNH NAM A BANK!")

if __name__ == "__main__":
    process_namabank()
