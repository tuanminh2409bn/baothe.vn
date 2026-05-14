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
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    driver.set_page_load_timeout(60) # Thêm timeout 60s
    return driver

def download_image(url, card_id, bucket):
    if not url: return ""
    print(f"    + Đang nạp ảnh: {card_id}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"bidv_{card_id}{ext}"
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

def process_bidv():
    print("--- BẮT ĐẦU XỬ LÝ BIDV TỪ WEB ---")
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    url = "https://bidv.com.vn/vn/ca-nhan/san-pham-dich-vu/dich-vu-the/the-tin-dung-quoc-te"
    try:
        driver.get(url)
        time.sleep(5)
    except Exception as e:
        print(f"  [!] Lỗi khi tải trang chủ BIDV (có thể do timeout mạng): {e}")
        # Vẫn tiếp tục xử lý với những gì đã load được
        
    # Cuộn trang để tải thêm thẻ
    for i in range(5):
        try:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(2)
        except:
            break
        
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    
    # Tìm tất cả các thẻ a chứa class card hoặc wrapper
    card_links = soup.find_all('a', href=re.compile(r'/the-tin-dung-quoc-te/.*'))
    
    valid_cards = []
    for link in card_links:
        detail_url = link['href']
        if not detail_url.startswith('http'):
            detail_url = 'https://bidv.com.vn' + detail_url
            
        # Tìm tiêu đề thẻ (thường nằm trong thẻ h3, h4 hoặc strong bên trong a)
        title_tag = link.find(['h3', 'h4', 'strong', 'span'])
        if not title_tag:
            # Có thể thẻ a chính là tên thẻ
            name = link.get_text().strip()
        else:
            name = title_tag.get_text().strip()
            
        # Lọc tên
        if not name or "the" not in name.lower() and "thẻ" not in name.lower(): continue
        
        # Tìm ảnh (thường nằm trong a hoặc block cha của a)
        parent = link.find_parent()
        img_tag = None
        if parent: img_tag = parent.find('img')
        if not img_tag: img_tag = link.find('img')
        
        img_url = img_tag.get('src') if img_tag else ""
        if img_url and not img_url.startswith('http'):
            img_url = 'https://bidv.com.vn' + img_url
            
        summary = ""
        # Thử tìm mô tả
        if parent:
            desc_tag = parent.find('div', class_=re.compile(r'desc|summary|text'))
            if desc_tag: summary = desc_tag.get_text().strip()
            
        valid_cards.append({
            'name': name,
            'url': detail_url,
            'img_url': img_url,
            'summary': summary
        })
        
    # Xóa trùng lặp
    unique_cards = {c['name']: c for c in valid_cards}.values()
    # Nếu danh sách quá dài, lấy giới hạn
    filtered_cards = [c for c in unique_cards if "tín dụng" in c['name'].lower() or "credit" in c['name'].lower()][:15]
    if not filtered_cards:
        filtered_cards = list(unique_cards)[:10]

    print(f"Phát hiện {len(filtered_cards)} thẻ BIDV. Bắt đầu xử lý...")

    for card in filtered_cards:
        print(f"\n🚀 Đang xử lý: {card['name']}")
        try:
            driver.get(card['url'])
            time.sleep(4)
            d_soup = BeautifulSoup(driver.page_source, 'html.parser')
            
            benefits_detail = []
            conditions_detail = []
            fee_detail = []
            
            # Cố gắng bóc tách các đoạn text dựa trên thẻ h2, h3
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
                if any(k in t_lower for k in ['ưu đãi', 'tiện ích', 'đặc quyền', 'lợi ích']):
                    benefits_detail.append(item_data)
                elif any(k in t_lower for k in ['điều kiện', 'hồ sơ', 'đối tượng']):
                    conditions_detail.append(item_data)
                elif any(k in t_lower for k in ['phí', 'lãi suất', 'hạn mức']):
                    fee_detail.append(item_data)
                    
            if not benefits_detail and card['summary']:
                benefits_detail.append({'title': 'Đặc điểm nổi bật', 'content': card['summary']})
                
            # Chuẩn bị dữ liệu
            slug = slugify(card['name'])
            card_id = f"bidv_{slug}"
            image_path = download_image(card['img_url'], slug, bucket)
            
            # Làm sạch dữ liệu
            benefits_detail = clean_garbage_data(benefits_detail)
            conditions_detail = clean_garbage_data(conditions_detail)
            fee_detail = clean_garbage_data(fee_detail)
            
            full_text = f"{card['summary']} " + " ".join([d['content'] for d in benefits_detail])
            cashback_rates = extract_cashback_rates(full_text)
            
            card_type = "Visa"
            if "mastercard" in card['name'].lower(): card_type = "Mastercard"
            elif "jcb" in card['name'].lower(): card_type = "JCB"
            
            card_tier = "Classic"
            if "infinite" in card['name'].lower(): card_tier = "Signature"
            elif "ultimate" in card['name'].lower(): card_tier = "Ultimate"
            elif "world" in card['name'].lower(): card_tier = "World"
            elif "platinum" in card['name'].lower(): card_tier = "Platinum"

            card_doc = {
                'id': card_id,
                'name': card['name'],
                'bankName': 'BIDV',
                'imagePath': image_path,
                'cashbackHighlight': card['summary'] if card['summary'] else "Ưu đãi thẻ tín dụng BIDV",
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
            print(f"  [!] Lỗi khi cào chi tiết thẻ {card['name']}: {e}")

    driver.quit()
    print("\n✅ HOÀN THÀNH BIDV!")

if __name__ == "__main__":
    process_bidv()
