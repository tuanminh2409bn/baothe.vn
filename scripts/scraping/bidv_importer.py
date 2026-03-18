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
import base64

def slugify(text):
    text = unicodedata.normalize('NFD', text)
    text = ''.join([c for c in text if unicodedata.category(c) != 'Mn'])
    text = text.replace('đ', 'd').replace('Đ', 'D')
    text = text.lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_-]+', '_', text)
    text = text.strip('_')
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
    chrome_options.add_argument("--window-size=1200,800")
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    return driver

def download_image_via_selenium(driver, url, filename, bucket):
    if not url: return ""
    print(f"  [+] Tải ảnh qua Chrome: {url}")
    try:
        driver.get(url)
        time.sleep(2)
        js_script = """
        var url = arguments[0];
        var callback = arguments[1];
        fetch(url).then(response => response.blob()).then(blob => {
            var reader = new FileReader();
            reader.onloadend = function() { callback(reader.result); };
            reader.readAsDataURL(blob);
        }).catch(err => callback("error"));
        """
        base64_data = driver.execute_async_script(js_script, url)
        if base64_data == "error" or not base64_data: return ""
        header, encoded = base64_data.split(",", 1)
        data = base64.b64decode(encoded)
        local_path = os.path.join(tempfile.gettempdir(), filename)
        with open(local_path, "wb") as f:
            f.write(data)
        blob = bucket.blob(f"card_images/{filename}")
        blob.upload_from_filename(local_path)
        blob.make_public()
        os.remove(local_path)
        return blob.public_url
    except Exception as e:
        print(f"  [!] Lỗi tải ảnh: {e}")
        return ""

def process_bidv():
    print("--- BẮT ĐẦU XỬ LÝ BIDV ---")
    db, bucket = setup_firebase()
    
    # 1. Parse Danh sách từ file HTML
    with open('scripts/scraping/bidv_source.html', 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f.read(), 'html.parser')
    
    # 2. Parse Chi tiết (lấy mẫu)
    with open('scripts/scraping/bidv_detail_source.html', 'r', encoding='utf-8') as f:
        d_soup = BeautifulSoup(f.read(), 'html.parser')
        
    def get_tab_content(keyword):
        tag = d_soup.find(string=re.compile(keyword))
        if tag:
            parent = tag.find_parent('div')
            if parent:
                ul = parent.find_next('ul')
                if ul:
                    lines = [l.strip() for l in ul.get_text(separator="\n").split('\n') if l.strip()]
                    return "\n".join([f"• {l}" if not l.startswith('•') else l for l in lines])
        return ""

    default_cond = get_tab_content("Điều kiện phát hành")
    default_fees = get_tab_content("Biểu phí")

    card_items = soup.find_all('div', class_='nwp-block-cards')
    driver = setup_driver()
    
    count = 0
    for item in card_items:
        if count >= 9: break
        title_tag = item.find('h4')
        if not title_tag: continue
        
        name = title_tag.get_text().strip()
        slug = slugify(name)
        card_id = f"bidv_{slug}"
        print(f"\n🚀 Đang xử lý: {name}")

        link_tag = item.find('a', href=True)
        url = link_tag['href'] if link_tag else ""
        if url and not url.startswith('http'): url = 'https://bidv.com.vn' + url
        
        img_tag = item.find('img')
        img_url = img_tag.get('src') if img_tag else ""
        if img_url and not img_url.startswith('http'): img_url = 'https://bidv.com.vn' + img_url

        # Tải ảnh
        ext = ".png" if ".png" in img_url.lower() else ".jpg"
        image_path = download_image_via_selenium(driver, img_url, f"{card_id}{ext}", bucket)

        # Lợi ích
        highlights = []
        card_list = item.find('div', class_='card-list')
        if card_list:
            highlights = [li.get_text().strip() for li in card_list.find_all('li') if li.get_text().strip()]
        cashback_highlight = "\n".join([f"• {h}" for h in highlights])

        # Phân loại
        card_type = "Visa"
        if "mastercard" in name.lower(): card_type = "Mastercard"
        elif "jcb" in name.lower(): card_type = "JCB"
        
        card_tier = "Classic"
        if "infinite" in name.lower(): card_tier = "Signature"
        elif "ultimate" in name.lower(): card_tier = "Ultimate"
        elif "world" in name.lower(): card_tier = "World"
        elif "sao vang" in name.lower() or "platinum" in name.lower(): card_tier = "Platinum"

        card_doc = {
            'id': card_id,
            'name': name,
            'bankName': 'BIDV',
            'imagePath': image_path,
            'cashbackHighlight': cashback_highlight,
            'details': highlights,
            'applyUrl': url,
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': [{'title': 'Lợi ích nổi bật', 'content': cashback_highlight}],
            'conditionsDetail': [{'title': 'Điều kiện phát hành', 'content': default_cond or "• Theo quy định của BIDV"}],
            'feeDetail': [{'title': 'Hạn mức & Biểu phí', 'content': default_fees or "• Theo biểu phí hiện hành của BIDV"}],
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection("cards").document(card_id).set(card_doc, merge=True)
        print(f"  [OK] Đã nạp Firestore: {card_id}")
        count += 1

    driver.quit()
    print("\n✅ HOÀN THÀNH BIDV!")

if __name__ == "__main__":
    process_bidv()
