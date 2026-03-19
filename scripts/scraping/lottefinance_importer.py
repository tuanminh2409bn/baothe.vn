import os
import firebase_admin
from firebase_admin import credentials, storage, firestore
from bs4 import BeautifulSoup
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

def download_and_upload_image(url, card_id, bucket):
    if not url: return ""
    if not url.startswith('http'): url = 'https://www.lottefinance.vn' + url
    print(f"    + Đang tải ảnh: {url}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"lotte_{card_id}{ext}"
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

def parse_lotte_detail(soup):
    benefits = []
    
    # Tìm theo tiêu đề "Lợi ích đặc biệt"
    benefit_header = soup.find(string=lambda x: x and 'Lợi ích đặc biệt' in x)
    if benefit_header:
        parent = benefit_header.find_parent(['div', 'section'])
        if parent:
            # Tìm các mục lợi ích bên dưới
            items = parent.find_all(['p', 'li', 'div'], recursive=True)
            for item in items:
                txt = clean_text(item.get_text())
                if 10 < len(txt) < 300 and "Lợi ích đặc biệt" not in txt:
                    # Lọc bỏ các tiêu đề trùng lặp
                    if not any(x in txt.lower() for x in ['biểu phí', 'tài liệu', 'tóm tắt']):
                        if txt not in [b['content'] for b in benefits]:
                            benefits.append({
                                'title': 'Lợi ích đặc biệt',
                                'content': txt
                            })
    
    # Nếu không thấy, lấy các đoạn text dài làm mô tả
    if not benefits:
        all_texts = soup.find_all(['p', 'div'])
        for t in all_texts:
            txt = clean_text(t.get_text())
            if 50 < len(txt) < 500:
                if "LOTTE" in txt:
                    benefits.append({'title': 'Giới thiệu', 'content': txt})
                    break

    return benefits

def process_lottefinance():
    db, bucket = setup_firebase()
    
    source_path = os.path.join(os.path.dirname(__file__), "lottefinance_source.html")
    detail_path = os.path.join(os.path.dirname(__file__), "lottefinance_detail_source.html")
    
    with open(source_path, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f.read(), 'html.parser')
    
    with open(detail_path, 'r', encoding='utf-8') as f:
        detail_soup = BeautifulSoup(f.read(), 'html.parser')
        
    sample_benefits = parse_lotte_detail(detail_soup)
    print(f"🔍 Tìm thấy {len(sample_benefits)} mục thông tin chi tiết mẫu.")

    all_cards = []
    # Lotte Finance dùng recom-card-cont cho mỗi thẻ trong danh sách
    card_items = soup.select('.recom-card-cont')
    
    for item in card_items:
        title_el = item.select_one('.tit')
        if not title_el: continue
        name = clean_text(title_el.get_text())
        
        # Link chi tiết
        link = "https://www.lottefinance.vn/web/card/cardList"
        link_el = item.select_one('a.btn-text')
        if link_el:
            link = "https://www.lottefinance.vn" + link_el['href'] if not link_el['href'].startswith('http') else link_el['href']
        
        # Ảnh thẻ nằm trong span style background-image
        img_url = ""
        parent_card = item.find_parent('div', class_='recom-card')
        if parent_card:
            img_span = parent_card.select_one('.recom-card-img span')
            if img_span and 'background-image' in img_span.get('style', ''):
                style = img_span.get('style', '')
                match = re.search(r"url\(['\"]?(.*?)['\"]?\)", style)
                if match:
                    img_url = match.group(1)
        
        # Lấy mô tả ngắn từ subtit
        subtit_el = item.select_one('.subtit')
        summary = clean_text(subtit_el.get_text()) if subtit_el else f"Trải nghiệm thẻ {name}"
        
        # Lấy thêm highlights từ div.cont
        highlights = []
        cont = item.select_one('.cont')
        if cont:
            for li in cont.select('ul.subtit-list li'):
                txt = clean_text(li.get_text())
                if txt: highlights.append(txt)
        
        if name and not any(c['name'] == name for c in all_cards):
            all_cards.append({
                'name': name,
                'url': link,
                'img_url': img_url,
                'summary': summary,
                'highlights': highlights
            })
            print(f"  + Tìm thấy: {name}")

    print(f"\n🚀 Tổng cộng: {len(all_cards)} thẻ Lotte Finance.")

    for card in all_cards:
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        
        name_lower = card['name'].lower()
        card_type = "Visa"
        if "mastercard" in name_lower: card_type = "Mastercard"
        elif "jcb" in name_lower: card_type = "JCB"
        
        card_tier = "Classic"
        if any(x in name_lower for x in ['platinum', 'premium', 'signature']):
            card_tier = "Platinum"

        card_doc = {
            'id': f"lotte_{slug}",
            'name': card['name'],
            'bankName': 'Lotte Finance',
            'imagePath': image_path,
            'cashbackHighlight': card['summary'],
            'details': card['highlights'] if card['highlights'] else ["Đặc quyền thẻ Lotte Finance"],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': sample_benefits,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection("cards").document(card_doc['id']).set(card_doc, merge=True)
        print(f"  [OK] Đã lưu: {card_doc['id']}")

    print("\n✨ HOÀN THÀNH LOTTE FINANCE!")

if __name__ == "__main__":
    process_lottefinance()
