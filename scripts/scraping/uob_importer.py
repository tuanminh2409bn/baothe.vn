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
        if url.startswith('/'):
            url = 'https://www.uob.com.vn' + url
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"uob_{card_id}{ext}"
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
    # Ưu tiên lấy li
    lis = element.find_elements(By.TAG_NAME, "li")
    for li in lis:
        t = li.get_attribute("textContent").strip()
        if t and len(t) > 2: lines.append(f"• {t}")
    
    if not lines:
        # Lấy từ p hoặc text thô nếu không có li
        raw = element.get_attribute("textContent").strip()
        lines = [f"• {l.strip()}" for l in raw.split('\n') if len(l.strip()) > 5]
        
    return "\n".join(lines[:20])

def scrape_uob():
    db, bucket = setup_firebase()
    
    print("--- PHÂN TÍCH DANH SÁCH THẺ UOB ---")
    with open('scripts/scraping/uob_source.html', 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f.read(), 'html.parser')
    
    items = soup.find_all('div', class_='category-item')
    print(f"Tìm thấy {len(items)} thẻ UOB tiềm năng.")

    cards_list = []
    for item in items:
        name_tag = item.find('h4', class_='card-title')
        if not name_tag: continue
        name = name_tag.get_text().strip()
        
        # Subtitle usually tells category (Rewards, Cashback, etc.)
        sub_tag = item.find('h6', class_='card-subtitle')
        subtitle = sub_tag.get_text().strip() if sub_tag else ""
        
        link_tag = item.find('a', href=True)
        url = link_tag['href']
        if url and not url.startswith('http'): url = 'https://www.uob.com.vn' + url
        
        img_tag = item.find('img', class_='card-img-top')
        img_url = img_tag['src'] if img_tag else ""
        
        # Simple highlight from card body
        body = item.find('div', class_='card-body')
        highlights = []
        if body:
            lis = body.find_all('li')
            for li in lis:
                highlights.append(li.get_text().strip())
        
        cards_list.append({
            'name': name,
            'url': url,
            'img_url': img_url,
            'subtitle': subtitle,
            'highlights': highlights
        })

    if not cards_list:
        print("❌ Không thu thập được danh sách thẻ. Vui lòng kiểm tra lại file HTML.")
        return

    driver = setup_driver()
    for card in cards_list:
        print(f"\n🚀 Đang xử lý: {card['name']}")
        
        # Skip cards with no URL
        if not card['url']:
            print("    ! Bỏ qua do không có link chi tiết.")
            continue

        driver.get(card['url'])
        time.sleep(5)
        
        details_map = {'benefits': [], 'conditions': [], 'fees': [], 'product': []}
        
        try:
            # 1. Lợi ích từ section #benefits
            try:
                benefits_sec = driver.find_element(By.ID, "benefits")
                # UOB benefits often in content-block
                blocks = benefits_sec.find_elements(By.CLASS_NAME, "content-block")
                benefit_lines = []
                for b in blocks:
                    txt = b.get_attribute("textContent").strip()
                    if txt: benefit_lines.append(f"• {txt}")
                if benefit_lines:
                    details_map['benefits'].append({'title': 'Lợi ích thẻ', 'content': "\n".join(benefit_lines)})
            except: pass

            # 2. Điều kiện & Biểu phí từ Accordion
            try:
                acc_sec = driver.find_element(By.ID, "eligibility-and-fees")
                # Mở tất cả accordion
                headers = acc_sec.find_elements(By.CLASS_NAME, "card-header")
                for h in headers:
                    try:
                        driver.execute_script("arguments[0].click();", h)
                        time.sleep(1)
                        title = h.get_attribute("textContent").strip()
                        # Panel is the next sibling or parent's child
                        panel = h.find_element(By.XPATH, "./following-sibling::div")
                        content = get_clean_text(panel)
                        
                        t_low = title.lower()
                        if any(x in t_low for x in ['bieu phi', 'dieu kien', 'eligibility', 'fee']):
                            details_map['conditions'].append({'title': title, 'content': content})
                        else:
                            details_map['product'].append({'title': title, 'content': content})
                    except: pass
            except: pass

            # 3. Tổng quan / Ưu đãi mở thẻ
            try:
                ov_sec = driver.find_element(By.ID, "overview")
                content = get_clean_text(ov_sec)
                details_map['benefits'].append({'title': 'Ưu đãi mở thẻ', 'content': content})
            except: pass

        except Exception as e:
            print(f"    ! Lỗi bóc tách chi tiết: {e}")

        # Nạp ảnh
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        card_id = f"uob_{slug}"

        # Phân loại
        card_type = "Visa"
        if "mastercard" in card['name'].lower() or "mc" in card['name'].lower(): 
            card_type = "Mastercard"
        
        card_tier = "Classic"
        if "signature" in card['name'].lower(): card_tier = "Signature"
        elif "platinum" in card['name'].lower() or "bach kim" in card['name'].lower(): card_tier = "Platinum"
        elif "world" in card['name'].lower(): card_tier = "World"
        elif "zenith" in card['name'].lower() or "infinite" in card['name'].lower(): card_tier = "Infinite"
        elif "privimiles" in card['name'].lower(): card_tier = "Platinum"

        # Check if Debit
        is_debit = "ghi no" in card['name'].lower() or "debit" in card['name'].lower()

        card_doc = {
            'id': card_id,
            'name': card['name'],
            'bankName': 'UOB',
            'imagePath': image_path,
            'cashbackHighlight': "\n".join([f"• {h}" for h in card['highlights']]),
            'details': card['highlights'],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': details_map['benefits'],
            'conditionsDetail': details_map['conditions'],
            'productInfoDetail': details_map['product'],
            'feeDetail': [{'title': 'Biểu phí', 'content': "• Vui lòng tham khảo biểu phí chi tiết tại website UOB."}],
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        # Fallback for benefits
        if not card_doc['benefitsDetail']:
            card_doc['benefitsDetail'] = [{'title': 'Lợi ích nổi bật', 'content': card_doc['cashbackHighlight']}]

        db.collection("cards").document(card_id).set(card_doc, merge=True)
        print(f"  [OK] Đã nạp Firestore: {card_id}")

    driver.quit()
    print("\n✅ HOÀN THÀNH UOB!")

if __name__ == "__main__":
    scrape_uob()
