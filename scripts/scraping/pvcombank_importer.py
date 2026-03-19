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

def clean_text(text):
    if not text: return ""
    # Xóa khoảng trắng thừa
    t = re.sub(r'\s+', ' ', text).strip()
    return t

def is_duplicate(text, seen_set):
    """Kiểm tra trùng lặp dựa trên nội dung đã chuẩn hóa"""
    if not text: return True
    # Chuẩn hóa: chữ thường, bỏ dấu, bỏ khoảng trắng, bỏ dấu câu
    norm = unicodedata.normalize('NFD', text).encode('ascii', 'ignore').decode('utf-8').lower()
    norm = re.sub(r'[^\w]', '', norm)
    if not norm or len(norm) < 5: return True # Bỏ qua text quá ngắn/vụn
    if norm in seen_set: return True
    seen_set.add(norm)
    return False

def process_pvcombank():
    db, bucket = setup_firebase()
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    source_path = os.path.join(current_dir, "pvcombank_source.html")
    with open(source_path, 'r', encoding='utf-8') as f:
        soup_list = BeautifulSoup(f.read(), 'html.parser')

    seen_urls = set()
    urls_to_process = []
    all_links = soup_list.find_all('a', href=re.compile(r'/san-pham/ca-nhan/dich-vu-the/'))
    for link in all_links:
        href = link['href'].split('#')[0].split('?')[0]
        if not href.startswith('http'): href = "https://www.pvcombank.com.vn" + href
        if "/the-tin-dung" in href or any(x in href.lower() for x in ['shopping', 'cashback', 'travel']):
            if href not in seen_urls:
                seen_urls.add(href)
                urls_to_process.append(href)

    print(f"✅ Tìm thấy {len(urls_to_process)} thẻ PVcomBank.")
    if not urls_to_process: return

    driver = setup_driver()
    for url in urls_to_process:
        print(f"\n🔍 Đang xử lý: {url}")
        try:
            driver.get(url)
            time.sleep(4)
            soup = BeautifulSoup(driver.page_source, 'html.parser')
            
            # --- CHỐNG LẶP DỮ LIỆU ---
            seen_content = set()

            # 1. Tên thẻ
            name_el = soup.find('h3', class_='h1--tab') or soup.find('h1')
            name = clean_text(name_el.get_text()) if name_el else soup.title.get_text().split('|')[0].strip()

            # 2. Ảnh thẻ (Lấy từ khối Desktop)
            img_container = soup.find('div', class_='card-sticky-block')
            img_el = img_container.find('img') if img_container else soup.find('img', src=re.compile(r'/upload/images/products/.*thumb'))
            img_url = img_el['src'] if img_el else ""
            if img_url.startswith('/'): img_url = "https://www.pvcombank.com.vn" + img_url

            # 3. Tóm tắt (Sticky Block)
            highlights = []
            # Chỉ lấy các phần tử hiển thị trên desktop (không có class d-lg-none)
            summary_container = soup.find('div', class_='card-sticky-block')
            if summary_container:
                # Lấy các giá trị (h8) tương ứng với nhãn (h9)
                items = summary_container.select('.cell__body > div')
                current_label = ""
                for item in items:
                    classes = item.get('class', [])
                    txt = clean_text(item.get_text())
                    if 'h9' in classes: 
                        current_label = txt.capitalize()
                    elif 'h8' in classes and txt:
                        combined = f"{current_label}: {txt}" if current_label else txt
                        if not is_duplicate(combined, seen_content):
                            highlights.append(combined)

            # 4. Đặc điểm nổi bật (Main content)
            features = []
            feat_section = soup.find('div', class_='outstanding-characteristics')
            if feat_section:
                # Chỉ lấy h8 bên trong feat_section mà KHÔNG thuộc các khối mobile ẩn
                feat_items = feat_section.select('.h8')
                for f in feat_items:
                    # Kiểm tra xem cha của f có bị ẩn không
                    is_hidden = any('d-none' in str(p.get('class', [])) or 'd-lg-none' in str(p.get('class', [])) for p in f.parents if p.name == 'div')
                    if is_hidden: continue
                    
                    txt = clean_text(f.get_text())
                    if not is_duplicate(txt, seen_content):
                        features.append(txt)

            # 5. Điều kiện & Thủ tục
            conditions_sections = []
            cond_container = soup.find('div', class_='open-card-conditions')
            if cond_container:
                # Tìm các block h5 chính (thường chỉ có 2-3 block thực sự trên desktop)
                blocks = cond_container.find_all('div', class_=lambda x: x and 'col-lg-12' in x)
                for block in blocks:
                    # Bỏ qua nếu block nằm trong phần ẩn mobile
                    if 'd-lg-none' in block.get('class', []): continue
                    
                    h5 = block.find('h5')
                    if h5:
                        title = clean_text(h5.get_text())
                        if is_duplicate(title, seen_content): continue
                        
                        items = block.select('.h8')
                        content_lines = []
                        for i in items:
                            it_txt = clean_text(i.get_text())
                            if it_txt and not it_txt.startswith('http') and not is_duplicate(it_txt, seen_content):
                                content_lines.append(f"• {it_txt}")
                        
                        if content_lines:
                            conditions_sections.append({'title': title, 'content': "\n".join(content_lines)})

            slug = slugify(name)
            card_id = f"pvcombank_{slug}"

            # Tải ảnh
            image_path = ""
            if img_url:
                print(f"    + Đang tải ảnh: {card_id}")
                try:
                    res = requests.get(img_url, headers={'User-Agent': 'Mozilla/5.0'}, timeout=20)
                    if res.status_code == 200:
                        ext = ".png" if ".png" in img_url.lower() else ".jpg"
                        filename = f"pvcombank_{card_id}{ext}"
                        local_path = os.path.join(tempfile.gettempdir(), filename)
                        with open(local_path, 'wb') as f: f.write(res.content)
                        blob = bucket.blob(f"card_images/{filename}")
                        blob.upload_from_filename(local_path)
                        blob.make_public()
                        image_path = blob.public_url
                        os.remove(local_path)
                except Exception as e: print(f"    ! Lỗi ảnh: {e}")

            card_doc = {
                'id': card_id,
                'name': name,
                'bankName': 'PVcomBank',
                'imagePath': image_path,
                'cashbackHighlight': features[0] if features else (highlights[1] if len(highlights)>1 else "Ưu đãi thẻ PVcomBank"),
                'details': highlights,
                'applyUrl': url,
                'cardType': "Mastercard" if "master" in name.lower() else "Visa",
                'cardTier': "Platinum" if any(x in name.lower() for x in ['platinum', 'world', 'premier', 'infinite']) else "Classic",
                'benefitsDetail': [{'title': 'Đặc điểm & Ưu đãi', 'content': "\n".join([f"• {f}" for f in features])}],
                'conditionsDetail': conditions_sections,
                'updatedAt': firestore.SERVER_TIMESTAMP
            }

            db.collection("cards").document(card_id).set(card_doc, merge=True)
            print(f"  [OK] Đã lưu: {card_id} (Dữ liệu đã lọc trùng)")
        except Exception as e:
            print(f"  ! Lỗi xử lý thẻ {url}: {e}")
    
    driver.quit()
    print("\n✨ HOÀN THÀNH PVCOMBANK - DỮ LIỆU CỰC SẠCH!")

if __name__ == "__main__":
    process_pvcombank()
