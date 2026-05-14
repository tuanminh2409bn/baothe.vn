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
import tempfile
import re
import unicodedata
import requests
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
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    chrome_options.add_argument("--disable-blink-features=AutomationControlled")
    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
    chrome_options.add_experimental_option('useAutomationExtension', False)
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    driver.set_page_load_timeout(60)
    return driver

def download_image(url, card_id, bucket):
    if not url: return ""
    print(f"    + Đang nạp ảnh: {card_id}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"tpbank_{card_id}{ext}"
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

def import_tpbank():
    print("--- BẮT ĐẦU XỬ LÝ TPBANK TỪ WEB ---")
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    url = "https://tpb.vn/khach-hang-ca-nhan/the-tin-dung"
    try:
        driver.get(url)
        time.sleep(10)
    except Exception as e:
        print(f"  [!] Lỗi khi tải trang chủ TPBank: {e}")
        
    for i in range(5):
        try:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(3)
        except:
            break
        
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    
    # Tìm các link chi tiết thẻ
    card_links = soup.find_all('a', href=re.compile(r'/cn-the-tin-dung-.*'))
    
    valid_cards = []
    for link in card_links:
        detail_url = link['href']
        if not detail_url.startswith('http'):
            detail_url = 'https://tpb.vn' + detail_url
            
        # TPB links have duplicate a tags, one with title, one with image. We can just extract the name if it's there
        title_tag = link.find(['h3', 'h4', 'strong', 'span'])
        if not title_tag:
            name = link.get_text().strip()
        else:
            name = title_tag.get_text().strip()
            
        if not name:
            # If a doesn't have text, look at its parent or siblings
            parent = link.find_parent('div')
            if parent:
                sibling_a = parent.find('a', class_='h-title')
                if sibling_a:
                    name = sibling_a.get_text().strip()
                    
        if not name or ("the" not in name.lower() and "thẻ" not in name.lower() and "visa" not in name.lower() and "mastercard" not in name.lower() and "jcb" not in name.lower()): continue
        if len(name) < 5: continue
        
        img_tag = link.find('img')
        if not img_tag:
            parent = link.find_parent('div')
            if parent: img_tag = parent.find('img')
            
        img_url = img_tag.get('src') if img_tag else ""
        if img_url and not img_url.startswith('http'):
            img_url = 'https://tpb.vn' + img_url
            
        summary = ""
        parent = link.find_parent('div')
        if parent:
            desc_tag = parent.find('div', class_=re.compile(r'desc|txt-content'))
            if desc_tag: summary = desc_tag.get_text().strip()
            
        valid_cards.append({
            'name': name,
            'url': detail_url,
            'img_url': img_url,
            'summary': summary
        })
        
    unique_cards = {c['name']: c for c in valid_cards}.values()
    filtered_cards = [c for c in unique_cards][:15]
    if not filtered_cards:
        filtered_cards = list(unique_cards)[:10]

    print(f"Phát hiện {len(filtered_cards)} thẻ TPBank. Bắt đầu xử lý...")

    for card in filtered_cards:
        name = card['name']
        slug = slugify(name)
        card_id = f"tpbank_{slug}"
        
        print(f"\n🚀 Đang xử lý: {name}")
        
        try:
            driver.get(card['url'])
            time.sleep(3)
            d_soup = BeautifulSoup(driver.page_source, 'html.parser')
            
            benefits_detail = []
            conditions_detail = []
            fee_detail = []
            
            content_blocks = d_soup.find_all(['h2', 'h3'])
            for block in content_blocks:
                title = block.get_text().strip()
                next_node = block.find_next_sibling()
                content = ""
                while next_node and next_node.name not in ['h2', 'h3']:
                    if next_node.get_text().strip():
                        content += next_node.get_text(separator=' ', strip=True) + " "
                    next_node = next_node.find_next_sibling()
                
                if not content: continue
                item_data = {'title': title, 'content': content.strip()}
                
                t_lower = title.lower()
                if any(k in t_lower for k in ['ưu đãi', 'tiện ích', 'đặc quyền', 'lợi ích', 'tính năng']):
                    benefits_detail.append(item_data)
                elif any(k in t_lower for k in ['điều kiện', 'hồ sơ', 'đăng ký']):
                    conditions_detail.append(item_data)
                elif any(k in t_lower for k in ['phí', 'lãi suất', 'hạn mức']):
                    fee_detail.append(item_data)
                    
            if not benefits_detail and card['summary']:
                benefits_detail.append({'title': 'Đặc điểm nổi bật', 'content': card['summary']})
                
            card_type = "Visa"
            if "mastercard" in name.lower() or "evo" in name.lower(): card_type = "Mastercard"
            elif "jcb" in name.lower(): card_type = "JCB"
            
            card_tier = "Classic"
            if "signature" in name.lower(): card_tier = "Signature"
            elif "platinum" in name.lower(): card_tier = "Platinum"
            elif "world" in name.lower(): card_tier = "World"
            elif "gold" in name.lower(): card_tier = "Gold"
            elif "fest" in name.lower() or "evo" in name.lower() or "freego" in name.lower(): card_tier = "Special"

            image_path = download_image(card['img_url'], slug, bucket)
            
            # Làm sạch dữ liệu
            benefits_detail = clean_garbage_data(benefits_detail)
            conditions_detail = clean_garbage_data(conditions_detail)
            fee_detail = clean_garbage_data(fee_detail)
            
            full_text = f"{card['summary']} " + " ".join([d['content'] for d in benefits_detail])
            cashback_rates = extract_cashback_rates(full_text)

            card_doc = {
                'id': card_id,
                'name': name,
                'bankName': 'TPBank',
                'imagePath': image_path,
                'cashbackHighlight': card['summary'] if card['summary'] else "Ưu đãi thẻ tín dụng TPBank",
                'details': [card['summary']] if card['summary'] else [],
                'applyUrl': card['url'],
                'cardType': card_type,
                'cardTier': card_tier,
                'benefitsDetail': benefits_detail,
                'conditionsDetail': conditions_detail,
                'productInfoDetail': [],
                'feeDetail': fee_detail,
                'updatedAt': firestore.SERVER_TIMESTAMP
            }
            card_doc.update(cashback_rates)

            db.collection("cards").document(card_id).set(card_doc, merge=True)
            print(f"  [OK] Đã nạp Firestore: {card_id}")
        except Exception as e:
            print(f"  [!] Lỗi khi cào chi tiết thẻ {name}: {e}")

    driver.quit()
    print("\n✅ HOÀN THÀNH TPBANK!")

if __name__ == "__main__":
    import_tpbank()
