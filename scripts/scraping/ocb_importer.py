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
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    chrome_options.add_argument("--disable-blink-features=AutomationControlled")
    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
    chrome_options.add_experimental_option('useAutomationExtension', False)
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    driver.set_page_load_timeout(60)
    return driver

def download_and_upload_image(url, card_id, bucket):
    if not url: return ""
    print(f"    + Đang tải ảnh: {url}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"ocb_{card_id}{ext}"
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

def parse_ocb_detail(html):
    soup = BeautifulSoup(html, 'html.parser')
    benefits = []
    
    target_headers = [
        'MIỄN PHÍ SỬ DỤNG DỊCH VỤ PHÒNG CHỜ SÂN BAY',
        'DỊCH VỤ HỖ TRỢ THỦ TỤC TẠI SÂN BAY',
        'Đặc điểm sản phẩm',
        'Ưu đãi cho chủ thẻ mở mới',
        'Ưu đãi hoàn tiền',
        'Ưu đãi nổi bật khác',
        'Tiện ích vượt trội',
        'Tiện ích',
        'Quyền lợi',
        'Ưu đãi'
    ]
    
    all_content = soup.find_all(['h2', 'h3', 'h4', 'p', 'li', 'strong', 'span'])
    
    current_title = ""
    current_content = []
    
    for el in all_content:
        txt = clean_text(el.get_text())
        if not txt: continue
        
        found_header = False
        for th in target_headers:
            if th.lower() in txt.lower() and len(txt) < 100:
                if current_title and current_content:
                    benefits.append({'title': current_title, 'content': "\n".join(current_content)})
                
                current_title = txt
                current_content = []
                found_header = True
                break
        
        if not found_header and current_title:
            if len(txt) > 5 and not any(x in txt.lower() for x in ['đăng ký ngay', 'chi tiết', 'tại đây', 'điều kiện', 'thời kỳ']):
                if txt not in current_content:
                    current_content.append(txt)
            
    if current_title and current_content:
        benefits.append({'title': current_title, 'content': "\n".join(current_content)})

    return benefits

def process_ocb():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    url = "https://www.ocb.com.vn/vi/ca-nhan/the/the-tin-dung"
    print(f"--- BẮT ĐẦU XỬ LÝ OCB TỪ WEB: {url} ---")
    try:
        driver.get(url)
        time.sleep(5)
    except Exception as e:
        print(f"  [!] Lỗi tải trang OCB: {e}")

    soup = BeautifulSoup(driver.page_source, 'html.parser')
    script_tag = soup.find('script', id='serverApp-state')
    
    all_cards = []
    
    if script_tag:
        import json
        try:
            state_data = json.loads(script_tag.string)
            def find_cards(obj):
                if isinstance(obj, dict):
                    if (obj.get("categoryName") == "Thẻ tín dụng" or obj.get("categoryCode") == "20211008200035851") and obj.get("templateCode") == "LayoutThe":
                        name = obj.get("name", "").strip()
                        if "THẺ" not in name.upper() and "OCB" not in name.upper():
                            name = f"OCB {name}"
                        elif "OCB" not in name.upper():
                            name = name.replace("Thẻ", "Thẻ OCB").replace("THẺ", "THẺ OCB")
                            
                        linkUrl = obj.get("linkUrl", "")
                        full_url = f"https://www.ocb.com.vn/vi/ca-nhan/the/the-tin-dung/{linkUrl}" if not linkUrl.startswith('http') else linkUrl
                        
                        img_url = obj.get("thumbnailImage", "")
                        if img_url:
                            img_url = f"https://www.ocb.com.vn/Uploads/{img_url}"
                            
                        # Lấy mô tả (nếu có)
                        summary = clean_text(obj.get("description", ""))
                        if not summary:
                            summary = f"Mở thẻ {name} để tận hưởng đặc quyền."
                            
                        if not any(c['url'] == full_url for c in all_cards):
                            all_cards.append({
                                'name': name,
                                'url': full_url,
                                'img_url': img_url,
                                'summary': summary,
                                'highlights': [summary]
                            })
                            print(f"  + Tìm thấy thẻ (JSON): {name}")
                    for k, v in obj.items():
                        find_cards(v)
                elif isinstance(obj, list):
                    for item in obj:
                        find_cards(item)
            
            find_cards(state_data)
        except Exception as e:
            print(f"  [!] Lỗi parse JSON state OCB: {e}")

    # Fallback to DOM parsing if JSON fails or is empty
    if not all_cards:
        print("  [*] Thử parse thẻ qua giao diện DOM...")
        card_items = soup.select('app-product-card-category-item')
        if not card_items:
            card_items = soup.find_all('div', class_=re.compile(r'card|item|product'))
            
        for item in card_items:
            img_el = item.select_one('.product-card-image img')
            if not img_el:
                img_el = item.find('img')
            if not img_el: continue
            
            name = clean_text(img_el.get('alt', ''))
            if not name:
                title_tag = item.find(['h3', 'h4', 'strong'])
                if title_tag: name = title_tag.get_text()
                
            if not name or "thẻ" not in name.lower() and "the" not in name.lower(): continue
                
            name = name.replace('THẺ ', '').replace('OCB ', '').strip()
            name = f"OCB {name}"

            img_url = img_el.get('src', '')
            if img_url and not img_url.startswith('http'):
                img_url = "https://www.ocb.com.vn" + img_url if img_url.startswith('/') else img_url
                
            link = "https://www.ocb.com.vn/vi/ca-nhan/the/the-tin-dung"
            link_el = item.find('a', href=True)
            if link_el:
                href = link_el['href']
                link = "https://www.ocb.com.vn" + href if href.startswith('/') else href
            
            highlights = []
            card_body = item.select_one('.product-card-category-item') or item
            all_text = [clean_text(t.get_text()) for t in card_body.find_all(['span', 'p', 'div']) if len(t.get_text(strip=True)) > 5]
            
            for i, txt in enumerate(all_text):
                if ("sản phẩm thẻ" in txt.lower() or "hoàn tiền" in txt.lower() or len(txt) > 80) and txt not in highlights:
                    highlights.append(txt)
                if "phí thường niên" in txt.lower():
                    highlights.append(txt)
                    if i + 1 < len(all_text):
                        highlights.append(all_text[i+1])
                        
            summary = " | ".join(highlights[:3]) if highlights else f"Mở thẻ {name} để tận hưởng đặc quyền"

            if name and not any(c['url'] == link for c in all_cards):
                all_cards.append({
                    'name': name,
                    'url': link,
                    'img_url': img_url,
                    'summary': summary,
                    'highlights': highlights
                })
                print(f"  + Tìm thấy thẻ (DOM): {name}")

    print(f"\n🚀 Tổng cộng: {len(all_cards)} thẻ OCB. Bắt đầu xử lý chi tiết...")

    for card in all_cards:
        try:
            driver.get(card['url'])
            time.sleep(3)
            
            benefits_raw = parse_ocb_detail(driver.page_source)
        except Exception as e:
            print(f"  [!] Lỗi khi vào trang chi tiết thẻ {card['name']}: {e}")
            benefits_raw = []
            
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        
        name_lower = card['name'].lower()
        card_type = "Visa"
        if "mastercard" in name_lower: card_type = "Mastercard"
        elif "jcb" in name_lower: card_type = "JCB"
        
        card_tier = "Classic"
        if any(x in name_lower for x in ['platinum', 'world', 'signature', 'infinite', 'priority']):
            card_tier = "Platinum"

        cleaned_benefits = clean_garbage_data(benefits_raw)
        if not cleaned_benefits:
            cleaned_benefits = [{'title': 'Đặc điểm thẻ', 'content': card['summary']}]
            
        full_text = card['summary'] + " " + " ".join([b.get('content', '') for b in cleaned_benefits])
        cashback_rates = extract_cashback_rates(full_text)

        card_doc = {
            'id': f"ocb_{slug}",
            'name': card['name'],
            'bankName': 'OCB',
            'imagePath': image_path,
            'cashbackHighlight': card['summary'],
            'details': card['highlights'] if card['highlights'] else [b.get('title', '') for b in cleaned_benefits[:3]],
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
    print("\n✨ HOÀN THÀNH OCB!")

if __name__ == "__main__":
    process_ocb()
