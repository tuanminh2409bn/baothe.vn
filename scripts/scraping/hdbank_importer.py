import os
import json
import firebase_admin
from firebase_admin import credentials, storage, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
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
    if url.startswith('//'): url = 'https:' + url
    elif not url.startswith('http'): url = 'https://hdbank.com.vn' + url
    
    print(f"    + Đang nạp ảnh: {card_id}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"hdbank_{card_id}{ext}"
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

def clean_html_to_bullet(html_content):
    """Chuyển đổi HTML thành danh sách gạch đầu dòng sạch sẽ"""
    if not html_content: return ""
    soup = BeautifulSoup(html_content, 'html.parser')
    lines = []
    
    # Ưu tiên lấy li
    list_items = soup.find_all('li')
    if list_items:
        for li in list_items:
            t = li.get_text().strip()
            if t: lines.append(f"• {t}")
    else:
        # Nếu không có li, lấy text theo từng block
        text = soup.get_text(separator='\n')
        for line in text.split('\n'):
            t = line.strip()
            if t and len(t) > 5:
                lines.append(f"• {t}")
                
    return "\n".join(lines).strip()

def scrape_hdbank():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    list_url = "https://hdbank.com.vn/personal/product/the/the-tin-dung"
    print(f"🚀 Truy cập HDBank: {list_url}")
    driver.get(list_url)
    time.sleep(5)

    # 1. Bấm nút "Xem thêm"
    for i in range(4):
        try:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight - 500);")
            time.sleep(2)
            btn = WebDriverWait(driver, 5).until(
                EC.element_to_be_clickable((By.XPATH, "//*[contains(text(), 'Xem thêm')]"))
            )
            print(f"  + Bấm 'Xem thêm' lần {i+1}...")
            driver.execute_script("arguments[0].click();", btn)
            time.sleep(3)
        except:
            break

    # 2. Lấy danh sách URL
    soup_list = BeautifulSoup(driver.page_source, 'html.parser')
    card_links = soup_list.find_all('a', href=re.compile(r'/personal/product/detail/the/the-tin-dung/'))
    
    urls_to_process = []
    seen_urls = set()
    for link in card_links:
        full_url = "https://hdbank.com.vn" + link['href'] if link['href'].startswith('/') else link['href']
        if full_url in seen_urls: continue
        seen_urls.add(full_url)
        urls_to_process.append(full_url)

    print(f"✅ Tìm thấy {len(urls_to_process)} thẻ HDBank duy nhất.")

    # 3. Duyệt từng thẻ - KHAI THÁC JSON TRONG TRANG CHI TIẾT
    for url in urls_to_process:
        print(f"\n🔍 Đang xử lý: {url}")
        driver.get(url)
        time.sleep(5)
        
        try:
            # Tìm thẻ script chứa dữ liệu ngầm
            data_script = driver.find_element(By.ID, "__NEXT_DATA__").get_attribute('textContent')
            data_json = json.loads(data_script)
            
            # Đào sâu vào JSON để lấy đúng card info
            card_info = data_json['props']['pageProps']['seoParam']['bannerProduct']
            all_details = data_json['props']['pageProps']['seoParam']
            
            name = card_info.get('name', 'Thẻ HDBank')
            summary = all_details.get('usp', '') # Thông tin slogan trang ngoài
            img_url = card_info.get('img', '') # Ảnh thẻ
            
            benefits_html = all_details.get('benefit', '')
            feature_html = all_details.get('feature', '')
            proviso_html = all_details.get('proviso', '')
            fees_html = all_details.get('tariffsInterestRate', '')
            
            benefits_text = clean_html_to_bullet(benefits_html)
            feature_text = clean_html_to_bullet(feature_html)
            conditions_text = clean_html_to_bullet(proviso_html)
            fees_text = clean_html_to_bullet(fees_html)

            slug = slugify(name)
            image_path = download_and_upload_image(img_url, slug, bucket)
            card_id = f"hdbank_{slug}"

            card_doc = {
                'id': card_id,
                'name': name,
                'bankName': 'HDBank',
                'imagePath': image_path,
                'cashbackHighlight': f"• {summary}" if summary else "Ưu đãi thẻ HDBank",
                'details': [summary] if summary else [],
                'applyUrl': url,
                'cardType': "Visa" if "visa" in name.lower() else "Mastercard",
                'cardTier': "Platinum" if any(x in name.lower() for x in ['platinum', 'ultimate', 'star']) else "Classic",
                'benefitsDetail': [
                    {'title': 'Đặc quyền & Ưu đãi', 'content': benefits_text},
                    {'title': 'Tiện ích thẻ', 'content': feature_text}
                ],
                'conditionsDetail': [{'title': 'Điều kiện phát hành', 'content': conditions_text}],
                'feeDetail': [{'title': 'Biểu phí & Lãi suất', 'content': fees_text}],
                'updatedAt': firestore.SERVER_TIMESTAMP
            }

            db.collection("cards").document(card_id).set(card_doc, merge=True)
            print(f"  [OK] Đã nạp thành công: {card_id}")

        except Exception as e:
            print(f"  ! Lỗi xử lý thẻ: {e}")

    driver.quit()
    print("\n✨ HOÀN THÀNH HDBANK VỚI DỮ LIỆU JSON CHUẨN!")

if __name__ == "__main__":
    scrape_hdbank()
