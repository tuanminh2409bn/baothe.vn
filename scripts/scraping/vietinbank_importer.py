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

def get_actual_image_url(src):
    if src and "url=" in src:
        match = re.search(r'url=(.*?)&', src)
        if match:
            return requests.utils.unquote(match.group(1))
    return src

def download_and_upload_image(url, card_id, bucket):
    if not url: return ""
    print(f"    + Đang nạp ảnh: {card_id}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"vietinbank_{card_id}{ext}"
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

def get_tab_content_vietin(driver, panel):
    lines = []
    # Lấy từ li
    lis = panel.find_elements(By.TAG_NAME, "li")
    for li in lis:
        t = li.get_attribute("textContent").strip()
        if t and len(t) > 2:
            lines.append(f"• {t}")
    
    # Nếu không có li, tìm p hoặc div
    if not lines:
        ps = panel.find_elements(By.CSS_SELECTOR, "p, div")
        for p in ps:
            t = p.get_attribute("textContent").strip()
            # Tránh lấy text quá ngắn hoặc bị lặp
            if t and len(t) > 10 and not any(t[:20] in l for l in lines):
                lines.append(f"• {t}")
                
    if not lines:
        raw = panel.get_attribute("textContent").strip()
        lines = [f"• {l.strip()}" for l in raw.split('\n') if len(l.strip()) > 5]
        
    return "\n".join(lines[:20])

def scrape_vietinbank():
    db, bucket = setup_firebase()
    driver = setup_driver()
    
    list_url = "https://www.vietinbank.vn/ca-nhan/san-pham-dich-vu/danh-sach-the?the=the_tin_dung"
    print(f"--- TRUY CẬP VIETINBANK ---")
    driver.get(list_url)
    time.sleep(5)

    cards_dict = {}
    try:
        dots = driver.find_elements(By.CLASS_NAME, "swiper-pagination-bullet")
        print(f"Đang quét {len(dots)} slide...")
        for dot in dots:
            driver.execute_script("arguments[0].click();", dot)
            time.sleep(2)
            slides = driver.find_elements(By.CLASS_NAME, "swiper-slide")
            for s in slides:
                try:
                    name = s.find_element(By.CSS_SELECTOR, "div.truncate.font-semibold").get_attribute("textContent").strip()
                    if not name or "Tạm dừng" in name or name in cards_dict: continue
                    url = s.find_element(By.TAG_NAME, "a").get_attribute("href")
                    img_url = get_actual_image_url(s.find_element(By.TAG_NAME, "img").get_attribute("src"))
                    
                    highlights = []
                    try: highlights.append(s.find_element(By.CLASS_NAME, "badge-success").get_attribute("textContent").strip())
                    except: pass
                    try:
                        km = s.find_element(By.XPATH, ".//h2[contains(text(), 'Khuyến mãi')]/following-sibling::div")
                        highlights.extend([l.strip() for l in km.get_attribute("textContent").split('\n') if l.strip()])
                    except: pass

                    cards_dict[name] = {'url': url, 'img_url': img_url, 'highlights': highlights}
                    print(f"  [+] Tìm thấy: {name}")
                except: continue
    except: pass

    print(f"Tổng cộng: {len(cards_dict)} thẻ. Đang lấy chi tiết...")

    for name, card in cards_dict.items():
        print(f"\n🔍 Chi tiết: {name}")
        driver.get(card['url'])
        time.sleep(5)
        
        details_map = {'benefits': [], 'conditions': [], 'fees': [], 'product': []}
        
        try:
            tabs = driver.find_elements(By.CSS_SELECTOR, "[role='tab']")
            for tab in tabs:
                tab_name = tab.get_attribute("textContent").strip()
                tab_id = tab.get_attribute("id")
                
                driver.execute_script("arguments[0].click();", tab)
                time.sleep(2.5)
                
                try:
                    # Tìm panel theo aria-labelledby hoặc panel đang visible
                    panel = None
                    try:
                        panel = driver.find_element(By.CSS_SELECTOR, f"[aria-labelledby='{tab_id}']")
                    except:
                        panels = driver.find_elements(By.CSS_SELECTOR, "[role='tabpanel']")
                        for p in panels:
                            if p.is_displayed():
                                panel = p
                                break
                    
                    if panel:
                        content = get_tab_content_vietin(driver, panel)
                        if content:
                            item = {'title': tab_name, 'content': content}
                            t_low = tab_name.lower()
                            print(f"      -> Tab '{tab_name}': {len(content)} ký tự")
                            
                            if any(x in t_low for x in ['uu dai', 'loi ich']): details_map['benefits'].append(item)
                            elif any(x in t_low for x in ['dieu kien', 'doi tuong', 'ho so']): details_map['conditions'].append(item)
                            elif any(x in t_low for x in ['bieu phi', 'lai suat', 'han muc']): details_map['fees'].append(item)
                            elif any(x in t_low for x in ['dac diem', 'thong tin', 'san pham', 'tien ich']): details_map['product'].append(item)
                except: continue
        except Exception as e:
            print(f"    ! Lỗi Tab: {e}")

        slug = slugify(name)
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        card_id = f"vietinbank_{slug}"
        if card_id.startswith("vietinbank_vietinbank_"): card_id = card_id.replace("vietinbank_vietinbank_", "vietinbank_")

        # Phân loại
        card_type = "Visa"
        if "mastercard" in name.lower(): card_type = "Mastercard"
        elif "jcb" in name.lower(): card_type = "JCB"
        elif "unionpay" in name.lower(): card_type = "UnionPay"

        card_tier = "Classic"
        if "signature" in name.lower(): card_tier = "Signature"
        elif "ultimate" in name.lower(): card_tier = "Ultimate"
        elif "platinum" in name.lower() or "premium" in name.lower(): card_tier = "Platinum"

        card_doc = {
            'id': card_id,
            'name': name,
            'bankName': 'VietinBank',
            'imagePath': image_path,
            'cashbackHighlight': "\n".join([f"• {h}" for h in card['highlights']]),
            'details': card['highlights'],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': details_map['benefits'],
            'conditionsDetail': details_map['conditions'],
            'productInfoDetail': details_map['product'],
            'feeDetail': details_map['fees'],
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        if not card_doc['benefitsDetail']: 
            card_doc['benefitsDetail'] = [{'title': 'Lợi ích', 'content': card_doc['cashbackHighlight']}]
        
        db.collection("cards").document(card_id).set(card_doc, merge=True)
        print(f"  [OK] Đã nạp: {card_id}")

    driver.quit()
    print("\n✅ HOÀN THÀNH VIETINBANK!")

if __name__ == "__main__":
    scrape_vietinbank()
