import os
import json
import firebase_admin
from firebase_admin import credentials, storage, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from bs4 import BeautifulSoup
import time
import tempfile
import re
import unicodedata
import requests

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
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"shb_{card_id}{ext}"
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

def clean_extracted_text(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    text = soup.get_text(separator='\n')
    lines = []
    for line in text.split('\n'):
        clean_line = line.strip()
        if clean_line and len(clean_line) > 5 and not any(x in clean_line.lower() for x in ['tại đây', 'đăng ký online', 'hotline']):
            if not clean_line.startswith(('•', '-', '+', '*', '1.', '2.')):
                lines.append(f"• {clean_line}")
            else:
                lines.append(clean_line)
    return "\n".join(lines)

def scrape_shb():
    db, bucket = setup_firebase()
    print("--- QUÉT DANH SÁCH THẺ SHB ---")
    with open('scripts/scraping/shb_source.html', 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f.read(), 'html.parser')
    
    card_items = soup.find_all('div', class_='col-md-4 child')
    raw_cards = []
    for item in card_items:
        name_div = item.find('div', style=lambda x: x and 'font-weight:bold' in x)
        if not name_div: continue
        name_tag = name_div.find('a')
        name = name_tag.get_text().strip()
        
        # BỘ LỌC
        if "mastercard world" in name.lower() or "dừng phát hành" in name.lower():
            continue
            
        url = name_tag['href']
        img_tag = item.find('img')
        img_url = img_tag['src'] if img_tag else ""
        des_div = item.find('div', style=lambda x: x and 'font-size:12px' in x)
        summary = des_div.get_text().strip() if des_div else ""
        
        raw_cards.append({
            'name': name,
            'url': url,
            'img_url': img_url,
            'summary': summary
        })

    selected_cards = raw_cards[:4]
    print(f"Sẽ nạp {len(selected_cards)} thẻ: {[c['name'] for c in selected_cards]}")

    driver = setup_driver()
    for card in selected_cards:
        print(f"\n🚀 Đang lấy dữ liệu: {card['name']}")
        driver.get(card['url'])
        time.sleep(5)
        
        benefits_detail = []
        conditions_detail = []
        
        # Bóc tách Accordion
        panels = driver.find_elements(By.CLASS_NAME, "panel.panel-default")
        for p in panels:
            try:
                title = p.find_element(By.CLASS_NAME, "title_item").get_attribute("textContent").strip()
                btn = p.find_element(By.TAG_NAME, "a")
                driver.execute_script("arguments[0].click();", btn)
                time.sleep(2)
                
                body_html = p.find_element(By.CLASS_NAME, "panel-body").get_attribute('innerHTML')
                detailed_text = clean_extracted_text(body_html)
                
                if detailed_text:
                    item_data = {'title': title, 'content': detailed_text}
                    if any(x in title.lower() for x in ['tiện ích', 'ưu đãi', 'đặc quyền']):
                        benefits_detail.append(item_data)
                    else:
                        conditions_detail.append(item_data)
            except: continue

        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        card_id = f"shb_{slug}"

        card_doc = {
            'id': card_id,
            'name': card['name'],
            'bankName': 'SHB',
            'imagePath': image_path,
            'cashbackHighlight': f"• {card['summary']}",
            'details': [card['summary']],
            'applyUrl': card['url'],
            'cardType': "Visa" if "visa" in card['name'].lower() else "Mastercard",
            'cardTier': "Platinum" if any(x in card['name'].lower() for x in ['platinum', 'star']) else "Classic",
            'benefitsDetail': benefits_detail,
            'conditionsDetail': conditions_detail,
            'productInfoDetail': [{'title': 'Giới thiệu', 'content': f"• {card['summary']}"}],
            'feeDetail': [{'title': 'Biểu phí', 'content': "• Xem chi tiết biểu phí trong trang chi tiết của SHB."}],
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection("cards").document(card_id).set(card_doc, merge=True)
        print(f"  [OK] Đã nạp thành công: {card_id}")

    driver.quit()
    print("\n✅ HOÀN THÀNH SHB!")

if __name__ == "__main__":
    scrape_shb()
