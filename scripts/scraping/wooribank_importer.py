import os
import sys
import json

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
    print(f"    + Đang nạp ảnh: {card_id}")
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://woori.com.vn/',
    }
    try:
        response = requests.get(url, headers=headers, stream=True, timeout=30)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"wooribank_{card_id}{ext}"
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

def process_wooribank():
    db, bucket = setup_firebase()
    print("--- PHÂN TÍCH DANH SÁCH THẺ WOORI BANK TỪ WEB ---")
    
    driver = setup_driver()
    url = "https://woori.com.vn/the-ca-nhan/the-tin-dung/"
    try:
        driver.get(url)
        time.sleep(5)
    except Exception as e:
        print(f"  [!] Lỗi khi tải trang chủ Woori Bank: {e}")
        
    for _ in range(3):
        try:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(2)
        except:
            break
            
    soup_list = BeautifulSoup(driver.page_source, 'html.parser')

    # Tìm danh sách thẻ tín dụng
    card_elements = soup_list.select('.list-all--item')
    if not card_elements:
        card_elements = soup_list.find_all('div', class_=re.compile(r'item|card'))
        
    print(f"✅ Tìm thấy {len(card_elements)} thẻ Woori Bank tiềm năng.")

    cards_to_process = []
    for el in card_elements:
        name_el = el.find(['h3', 'h4'])
        
        # Tìm link chi tiết (bỏ qua link đăng ký)
        links = el.find_all('a', href=True)
        link_el = None
        for a in links:
            if "dang-ky-mo-the" not in a['href']:
                link_el = a
                break
                
        img_el = el.find('img', attrs={'data-src': True})
        if not img_el: img_el = el.find('img')
        
        if name_el and link_el:
            name = clean_text(name_el.get_text())
            
            if "thẻ" not in name.lower() and "the" not in name.lower(): continue
            # Bỏ lọc "tín dụng" vì một số thẻ không ghi chữ tín dụng trong tên
            
            url = link_el['href']
            if not url.startswith('http'): url = 'https://woori.com.vn' + url
            
            img_url = img_el.get('data-src') or img_el.get('src') if img_el else ""
            if img_url and not img_url.startswith('http'): img_url = 'https://woori.com.vn' + img_url
            
            highlights = []
            excerpt_el = el.find('div', class_=re.compile(r'excerpt|desc|summary'))
            if excerpt_el:
                for li in excerpt_el.find_all('li'):
                    txt = clean_text(li.get_text())
                    if txt: highlights.append(txt)
            if not highlights and excerpt_el:
                highlights.append(clean_text(excerpt_el.get_text()))
            
            cards_to_process.append({
                'name': name,
                'url': url,
                'img_url': img_url,
                'highlights': highlights
            })

    unique_cards = {c['url']: c for c in cards_to_process}.values()
    cards_to_process = list(unique_cards)
    
    if not cards_to_process:
        print("❌ Không thu thập được danh sách thẻ Woori Bank.")
        driver.quit()
        return

    if cards_to_process:
        for card in cards_to_process:
            print(f"\n🔍 Đang xử lý: {card['name']}")
            try:
                driver.get(card['url'])
                time.sleep(5)
                soup_detail = BeautifulSoup(driver.page_source, 'html.parser')
                
                benefits_detail = []
                accordion_items = soup_detail.select('.drop-down-item')
                for item in accordion_items:
                    title_el = item.find('div', class_='wrap-heading')
                    content_el = item.find('div', class_='drop-down-content')
                    if title_el:
                        title = clean_text(title_el.get_text())
                        content = clean_text(content_el.get_text(separator='\n')) if content_el else ""
                        if title:
                            benefits_detail.append({'title': title, 'content': content})

                conditions_detail = []
                content_items = soup_detail.select('.content-main--item')
                for item in content_items:
                    title_el = item.find('div', class_='content-main--item__title')
                    content_el = item.find('div', class_='content-main--item__right')
                    if title_el and content_el:
                        title = clean_text(title_el.get_text())
                        if any(x in title.lower() for x in ['điều kiện', 'hồ sơ', 'đối tượng']):
                            content = clean_text(content_el.get_text(separator='\n'))
                            conditions_detail.append({'title': title, 'content': content})

                slug = slugify(card['name'])
                card_id = f"wooribank_{slug}"
                image_path = download_and_upload_image(card['img_url'], slug, bucket)

                benefits_clean = clean_garbage_data(benefits_detail)
                conditions_clean = clean_garbage_data(conditions_detail)
                
                highlight_text = card['highlights'][0] if card['highlights'] else "Ưu đãi thẻ Woori Bank"
                full_text = highlight_text + "\n" + "\n".join([item.get('content', '') for item in benefits_clean])
                cashback_rates = extract_cashback_rates(full_text)

                card_doc = {
                    'id': card_id,
                    'name': card['name'],
                    'bankName': 'Woori Bank', # Tên chuẩn theo app Flutter
                    'imagePath': image_path,
                    'cashbackHighlight': highlight_text,
                    'details': card['highlights'],
                    'applyUrl': card['url'],
                    'cardType': "Visa" if "visa" in card['name'].lower() else "Napas",
                    'cardTier': "Platinum" if any(x in card['name'].lower() for x in ['platinum', 'premium', 'gold']) else "Classic",
                    'benefitsDetail': benefits_clean,
                    'conditionsDetail': conditions_clean,
                    'updatedAt': firestore.SERVER_TIMESTAMP
                }
                card_doc.update(cashback_rates)

                db.collection("cards").document(card_id).set(card_doc, merge=True)
                print(f"  [OK] Đã lưu: {card_id} với tên bank 'Woori Bank'")
            except Exception as e:
                print(f"  ! Lỗi xử lý thẻ {card['url']}: {e}")
        
        driver.quit()
    
    print("\n✨ HOÀN THÀNH WOORI BANK!")

if __name__ == "__main__":
    process_wooribank()
