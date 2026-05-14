import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from clean_firestore_data import clean_garbage_data, extract_cashback_rates
except ImportError:
    def clean_garbage_data(data): return data
    def extract_cashback_rates(text): return {}

import json
import firebase_admin
from firebase_admin import credentials, storage, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
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

def fix_encoding(text):
    if not text: return ""
    try:
        if 'Ã' in text or 'áº' in text or 'á' in text:
            return text.encode('latin-1').decode('utf-8')
    except: pass
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
    chrome_options.add_argument("--window-size=1440,1200")
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    return driver

def download_and_upload_image(url, card_id, bucket):
    if not url: return ""
    if "/_next/image" in url:
        match = re.search(r'url=([^&]+)', url)
        if match: url = requests.utils.unquote(match.group(1))
    
    if url.startswith('/'): url = 'https://eximbank.com.vn' + url
    if 'media/' in url and not url.startswith('http'):
        url = 'https://media.eximbank.com.vn/exim/' + url.split('media/')[-1]

    print(f"    + Đang tải ảnh: {url}")
    headers = {'User-Agent': 'Mozilla/5.0'}
    try:
        response = requests.get(url, headers=headers, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"eximbank_{card_id}{ext}"
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

def process_eximbank():
    db, bucket = setup_firebase()
    driver = setup_driver()
    all_cards = []
    
    try:
        list_url = "https://eximbank.com.vn/ca-nhan-the"
        print(f"\n🚀 Truy cập: {list_url}")
        driver.get(list_url)
        time.sleep(5)
        
        # 1. Nhấn nút "Xem thêm"
        for i in range(1, 5):
            try:
                driver.execute_script("window.scrollTo(0, document.body.scrollHeight - 400);")
                time.sleep(2)
                btn = WebDriverWait(driver, 5).until(
                    EC.element_to_be_clickable((By.XPATH, "//button[descendant-or-self::*[contains(text(), 'Xem thêm')]]"))
                )
                print(f"  + Nhấn 'Xem thêm' lần {i}...")
                driver.execute_script("arguments[0].click();", btn)
                time.sleep(5)
            except: break
        
        # 2. Cuộn trang để tải ảnh
        print("  ✅ Cuộn trang kích hoạt ảnh...")
        total_height = driver.execute_script("return document.body.scrollHeight")
        for pos in range(0, total_height, 400):
            driver.execute_script(f"window.scrollTo(0, {pos});")
            time.sleep(0.3)
        
        # 3. Bóc tách
        soup = BeautifulSoup(driver.page_source, 'html.parser')
        
        # Tìm các khối thẻ bằng cách tìm các thẻ <a> chứa tên thẻ
        # Eximbank thường để tên thẻ trong h3 hoặc p.font-bold
        card_blocks = soup.find_all('div', class_=lambda x: x and ('p-6' in x or 'p-4' in x))
        processed_urls = set()
        
        for block in card_blocks:
            # Tìm link chi tiết
            link_tag = block.find('a', href=re.compile(r'/ca-nhan-the/'))
            if not link_tag: continue
            
            href = link_tag['href']
            if href.endswith('/ca-nhan-the') or href.endswith('/the'): continue
            
            full_url = href if href.startswith('http') else "https://eximbank.com.vn" + href
            if full_url in processed_urls: continue
            
            # Tìm tên thẻ (Surgical search)
            name = ""
            name_el = block.find(['h3', 'p'], class_=lambda x: x and 'font-bold' in x)
            if name_el:
                name = fix_encoding(name_el.get_text().strip())
            
            if not name or "Thẻ" not in name: continue
            
            # Lọc thẻ tín dụng
            name_lower = name.lower()
            is_credit = any(x in name_lower for x in ["tín dụng", "credit", "violet", "one world", "signature", "infinite", "ultimate", "platinum", "gold"])
            is_debit = any(x in name_lower for x in ["debit", "ghi nợ", "thanh toán", "young"])
            
            if is_credit and not is_debit:
                # Tìm ảnh thẻ
                img_url = ""
                img_tag = block.find('img')
                if img_tag:
                    img_url = img_tag.get('src') or img_tag.get('data-src') or ""
                
                all_cards.append({
                    'name': name,
                    'url': full_url,
                    'list_image': img_url
                })
                processed_urls.add(full_url)
                print(f"  + Tìm thấy: {name}")

        print(f"\n✅ Tổng cộng tìm thấy {len(all_cards)} thẻ tín dụng thực sự.")

        for card in all_cards:
            print(f"\n🔍 Xử lý chi tiết: {card['name']}")
            driver.get(card['url'])
            time.sleep(5)
            
            detail_soup = BeautifulSoup(driver.page_source, 'html.parser')
            benefits = []
            for el in detail_soup.find_all(['p', 'li', 'span']):
                txt = re.sub(r'\s+', ' ', el.get_text().replace('\xa0', ' ')).strip()
                if 25 < len(txt) < 500 and txt not in benefits:
                    if not any(x in txt.lower() for x in ['đăng ký ngay', 'tải tài liệu', 'hướng dẫn', 'điều kiện', 'chi tiết']):
                        benefits.append(txt)

            name_lower = card['name'].lower()
            card_tier = "Platinum" if any(x in name_lower for x in ['platinum', 'signature', 'infinite', 'world', 'ultimate']) else "Classic"
            slug = slugify(card['name'])
            
            image_path = download_and_upload_image(card['list_image'], slug, bucket)
            
            b_detail = [{'title': 'Đặc quyền & Ưu đãi', 'content': "\n".join([f"• {b}" for b in benefits])}]
            b_detail = clean_garbage_data(b_detail)
            
            full_text = "\n".join(benefits)
            cashback_rates = extract_cashback_rates(full_text)
            
            card_doc = {
                'id': f"eximbank_{slug}",
                'name': card['name'],
                'bankName': 'Eximbank',
                'imagePath': image_path,
                'cashbackHighlight': benefits[0] if benefits else f"Ưu đãi {card['name']}",
                'details': benefits[:5],
                'applyUrl': card['url'],
                'cardType': "JCB" if "jcb" in name_lower else ("Mastercard" if "master" in name_lower else "Visa"),
                'cardTier': card_tier,
                'benefitsDetail': b_detail,
                'updatedAt': firestore.SERVER_TIMESTAMP
            }
            card_doc.update(cashback_rates)
            db.collection("cards").document(card_doc['id']).set(card_doc, merge=True)
            print(f"  [OK] Đã lưu: {card_doc['id']}")

    except Exception as e:
        print(f"❌ Lỗi: {e}")
    finally:
        driver.quit()
        print("\n✨ HOÀN THÀNH!")

if __name__ == "__main__":
    process_eximbank()
