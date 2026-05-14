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
import sys
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
            if ".gif" in url.lower(): ext = ".gif"
            filename = f"shinhan_{card_id}{ext}"
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

def get_clean_text(element):
    lines = []
    # Lấy từ li
    lis = element.find_elements(By.TAG_NAME, "li")
    for li in lis:
        t = li.get_attribute("textContent").strip()
        if t and len(t) > 2: lines.append(f"• {t}")
    
    if not lines:
        ps = element.find_elements(By.TAG_NAME, "p")
        for p in ps:
            t = p.get_attribute("textContent").strip()
            if t and len(t) > 10 and not any(t[:20] in l for l in lines):
                lines.append(f"• {t}")
                
    if not lines:
        raw = element.get_attribute("textContent").strip()
        lines = [f"• {l.strip()}" for l in raw.split('\n') if len(l.strip()) > 5]
        
    return "\n".join(lines[:20])

def scrape_shinhan():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    print("--- PHÂN TÍCH DANH SÁCH THẺ TỪ WEB SHINHAN ---")
    url = "https://shinhan.com.vn/vi/shinhan_card_category/the-tin-dung-ca-nhan.html"
    try:
        driver.get(url)
        time.sleep(5)
    except Exception as e:
        print(f"  [!] Lỗi tải trang chủ Shinhan: {e}")
        
    for _ in range(3):
        try:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(2)
        except: break

    soup = BeautifulSoup(driver.page_source, 'html.parser')
    
    # Tìm tất cả div có class chứa 'thumb' và 'card'
    card_items = soup.find_all('div', class_=lambda x: x and 'thumb' in x and 'card' in x)
    if not card_items:
        # Dự phòng tìm thẻ
        card_items = soup.find_all('div', class_=re.compile(r'card-item|product-item'))
        
    print(f"Tìm thấy {len(card_items)} thẻ Shinhan tiềm năng.")

    cards_list = []
    for item in card_items:
        name_tag = item.find(['h3', 'h4', 'strong'])
        if not name_tag:
            name_tag = item.find('a', class_=re.compile(r'title|name'))
        if not name_tag: continue
        
        name = name_tag.get_text().strip()
        if "thẻ" not in name.lower() and "the" not in name.lower(): continue
        
        link_tag = item.find('a', href=True)
        if not link_tag: continue
        url = link_tag['href']
        if not url.startswith('http'): url = 'https://shinhan.com.vn' + url
        
        img_tag = item.find('img')
        img_url = img_tag['src'] if img_tag else ""
        if img_url and not img_url.startswith('http'): img_url = 'https://shinhan.com.vn' + img_url
        
        des_tag = item.find('p', class_=re.compile(r'des|txt|summary'))
        des = des_tag.get_text().strip() if des_tag else ""
        
        cards_list.append({
            'name': name,
            'url': url,
            'img_url': img_url,
            'description': des
        })

    if not cards_list:
        print("❌ Không thu thập được danh sách thẻ từ web.")
        driver.quit()
        return

    for card in cards_list:
        print(f"\n🚀 Đang xử lý: {card['name']}")
        driver.get(card['url'])
        time.sleep(5)
        
        details_map = {'benefits': [], 'conditions': [], 'fees': [], 'product': []}
        
        try:
            # 1. Ưu đãi / Đặc quyền (Mở các accordion nếu có)
            plus_items = driver.find_elements(By.CLASS_NAME, "item.plus")
            for pi in plus_items:
                try: driver.execute_script("arguments[0].classList.add('active');", pi)
                except: pass
            time.sleep(1)

            # Bóc tách các vùng dữ liệu theo ID
            sections = [
                ('uu-dai-diem-thuong', 'benefits'),
                ('dac-quyen', 'benefits'),
                ('dieu-kien-dang-ky', 'conditions'),
                ('ho-so-dang-ky', 'conditions'),
                ('gioi-thieu', 'product')
            ]

            for sid, target in sections:
                try:
                    box = driver.find_element(By.ID, sid)
                    title = box.find_element(By.CLASS_NAME, "ct-left").get_attribute("textContent").strip()
                    content = get_clean_text(box.find_element(By.CLASS_NAME, "ct-right"))
                    if content:
                        details_map[target].append({'title': title, 'content': content})
                except: pass

        except Exception as e:
            print(f"    ! Lỗi bóc tách: {e}")

        # Nạp ảnh
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        card_id = f"shinhan_{slug}"

        # Phân loại
        card_type = "Visa"
        if "mastercard" in card['name'].lower(): card_type = "Mastercard"
        
        card_tier = "Classic"
        if "signature" in card['name'].lower(): card_tier = "Signature"
        elif "platinum" in card['name'].lower() or "bach kim" in card['name'].lower(): card_tier = "Platinum"
        elif "gold" in card['name'].lower() or "vang" in card['name'].lower(): card_tier = "Gold"

        card_doc = {
            'id': card_id,
            'name': card['name'],
            'bankName': 'Shinhan Bank',
            'imagePath': image_path,
            'cashbackHighlight': f"• {card['description']}",
            'details': [card['description']],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': details_map['benefits'],
            'conditionsDetail': details_map['conditions'],
            'productInfoDetail': details_map['product'],
            'feeDetail': [{'title': 'Biểu phí', 'content': "• Vui lòng tham khảo biểu phí tại website Shinhan Bank."}],
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        if not card_doc['benefitsDetail']:
            card_doc['benefitsDetail'] = [{'title': 'Lợi ích nổi bật', 'content': card_doc['cashbackHighlight']}]

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
        print(f"  [OK] Đã nạp Firestore: {card_id}")

    driver.quit()
    print("\n✅ HOÀN THÀNH SHINHAN BANK!")

if __name__ == "__main__":
    scrape_shinhan()
