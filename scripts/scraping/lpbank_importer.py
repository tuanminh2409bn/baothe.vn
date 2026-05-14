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
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    driver.set_page_load_timeout(60)
    return driver

def download_and_upload_image(url, card_id, bucket):
    if not url: return ""
    if not url.startswith('http'): url = 'https://lpbank.com.vn/' + url.lstrip('/')
    print(f"    + Đang tải ảnh: {url}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"lpbank_{card_id}{ext}"
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

def parse_lpbank_detail(soup):
    benefits = []
    
    # Bóc tách "Tiện ích"
    ti_noi_bat_els = soup.find_all(string=lambda x: x and 'Tiện ích' in x)
    for el in ti_noi_bat_els:
        section = el.find_parent(['section', 'div', 'app-sec-tien-ich', 'app-sec-kham-pha'])
        if section:
            highlights = []
            for item in section.select('.textBox, p, li'):
                txt = clean_text(item.get_text())
                if 10 < len(txt) < 300 and txt not in highlights:
                    highlights.append(txt)
            
            if highlights:
                benefits.append({
                    'title': 'Tiện ích nổi bật',
                    'content': "\n".join([f"• {h}" for h in highlights])
                })
                break

    # Bóc tách "Chi tiết sản phẩm:"
    ct_sp_el = soup.find(string=lambda x: x and 'Chi tiết sản phẩm' in x)
    if ct_sp_el:
        container = ct_sp_el.find_parent(['div', 'section', 'app-sec-dieu-kien'])
        if container:
            all_p = container.find_all(['p', 'li', 'strong'])
            
            current_section_title = ""
            current_section_content = []
            
            start_collecting = False
            for p in all_p:
                txt = clean_text(p.get_text())
                if not txt: continue
                
                if "Chi tiết sản phẩm" in txt:
                    start_collecting = True
                    continue
                
                if start_collecting:
                    if re.match(r'^\d+\.', txt) or "Hạn mức" in txt or "Lãi suất" in txt:
                        if current_section_title and current_section_content:
                            benefits.append({
                                'title': current_section_title,
                                'content': "\n".join(current_section_content)
                            })
                        current_section_title = txt
                        current_section_content = []
                    elif current_section_title:
                        if len(txt) > 5 and not any(x in txt.lower() for x in ['đăng ký ngay', 'chi tiết', 'tại đây']):
                            if txt not in current_section_content:
                                current_section_content.append(txt)
            
            if current_section_title and current_section_content:
                benefits.append({
                    'title': current_section_title,
                    'content': "\n".join(current_section_content)
                })

    return benefits

def process_lpbank():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    print("--- PHÂN TÍCH DANH SÁCH THẺ LPBANK TỪ WEB ---")
    list_url = "https://lpbank.com.vn/ca-nhan/the"
    driver.get(list_url)
    time.sleep(5)
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    time.sleep(3)
    
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    card_boxes = soup.select('.productBox')
    
    if not card_boxes:
        print("❌ Không tìm thấy danh sách thẻ. Giao diện có thể đã thay đổi.")
        driver.quit()
        return

    # Lấy thông tin cơ bản trước
    cards_info = []
    for box in card_boxes:
        title_el = box.select_one('.productBox__title a') or box.find('h3')
        if not title_el: continue
        name = clean_text(title_el.get_text())
        
        # Chỉ lấy thẻ tín dụng
        if "thẻ tín dụng" not in name.lower() and "credit" not in name.lower(): continue
        
        img_el = box.find('img')
        img_url = img_el['src'] if img_el else ""
        
        package = box.select_one('.productBox__package')
        summary_list = []
        if package:
            items = package.select('.f-item')
            for it in items:
                label = clean_text(it.find('span').get_text()) if it.find('span') else ""
                val = clean_text(it.find('p').get_text()) if it.find('p') else ""
                if label and val:
                    summary_list.append(f"{label}: {val}")
        
        summary = " | ".join(summary_list) if summary_list else f"Trải nghiệm đặc quyền cùng {name}"
        
        if not any(c['name'] == name for c in cards_info):
            cards_info.append({
                'name': name,
                'img_url': img_url,
                'summary': summary,
                'highlights': summary_list
            })
            
    print(f"Tìm thấy {len(cards_info)} thẻ tín dụng LPBank tiềm năng.")

    for i, card in enumerate(cards_info):
        print(f"\n🚀 Đang xử lý: {card['name']}")
        
        # Truy cập lại trang chủ, click thẻ thứ i để vào chi tiết
        driver.get(list_url)
        time.sleep(4)
        driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(2)
        
        boxes = driver.find_elements(By.CSS_SELECTOR, '.productBox')
        target_box = None
        for b in boxes:
            try:
                t = b.find_element(By.CSS_SELECTOR, '.productBox__title').text
                if t.strip().lower() == card['name'].lower():
                    target_box = b
                    break
            except: pass
            
        if target_box:
            try:
                btn = target_box.find_element(By.CSS_SELECTOR, '.productBox__title a')
                driver.execute_script("arguments[0].click();", btn)
                time.sleep(5)
                card['url'] = driver.current_url
                
                # Bóc tách HTML chi tiết
                detail_soup = BeautifulSoup(driver.page_source, 'html.parser')
                benefits_raw = parse_lpbank_detail(detail_soup)
                
            except Exception as e:
                print(f"  [!] Lỗi khi click/lấy chi tiết {card['name']}: {e}")
                card['url'] = list_url
                benefits_raw = []
        else:
            card['url'] = list_url
            benefits_raw = []
            
        # Lưu thẻ
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        
        name_lower = card['name'].lower()
        card_type = "Visa"
        if "jcb" in name_lower: card_type = "JCB"
        elif "mastercard" in name_lower: card_type = "Mastercard"
        
        card_tier = "Classic"
        if any(x in name_lower for x in ['platinum', 'signature', 'ultimate', 'world']):
            card_tier = "Platinum"
        elif "gold" in name_lower:
            card_tier = "Gold"

        cleaned_benefits = clean_garbage_data(benefits_raw)
        if not cleaned_benefits:
            cleaned_benefits = [{'title': 'Tiện ích nổi bật', 'content': card['summary']}]
            
        full_text = card['summary'] + " " + " ".join(card['highlights']) + " " + " ".join([b.get('content', '') for b in cleaned_benefits])
        cashback_rates = extract_cashback_rates(full_text)

        card_doc = {
            'id': f"lpbank_{slug}",
            'name': card['name'],
            'bankName': 'LPBank',
            'imagePath': image_path,
            'cashbackHighlight': card['summary'],
            'details': card['highlights'] if card['highlights'] else [b['title'] for b in cleaned_benefits[:5]],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': cleaned_benefits,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        card_doc.update(cashback_rates)
        
        db.collection("cards").document(card_doc['id']).set(card_doc, merge=True)
        print(f"  [OK] Đã lưu: {card_doc['id']}")

    driver.quit()
    print("\n✨ HOÀN THÀNH LPBANK!")

if __name__ == "__main__":
    process_lpbank()
