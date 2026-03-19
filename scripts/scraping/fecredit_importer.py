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
    print(f"    + Đang tải ảnh: {url}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"fecredit_{card_id}{ext}"
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

def parse_fecredit_detail(soup):
    benefits = []
    
    # 1. Bóc tách Lãi suất
    interest_el = soup.find(string=lambda x: x and 'Lãi suất' in x and len(x) < 20)
    if interest_el:
        parent = interest_el.find_parent(['div', 'section'])
        if parent:
            # Tìm các mục lãi suất tiếp theo
            interest_info = []
            # Thường lãi suất nằm trong các div tiếp theo hoặc cùng cấp
            # Trong FE Credit, nó nằm trong các block có title và value
            items = parent.find_all(['div', 'p', 'strong'], recursive=True)
            for item in items:
                txt = clean_text(item.get_text())
                if "Lãi suất áp dụng" in txt or "Từ 4.58%" in txt or "Miễn lãi" in txt:
                    if txt not in interest_info:
                        interest_info.append(txt)
            
            if interest_info:
                benefits.append({
                    'title': 'Thông tin Lãi suất',
                    'content': "\n".join(interest_info[:6])
                })

    # 2. Bóc tách Phí
    fee_el = soup.find(string=lambda x: x and 'Phí' in x and len(x) < 10)
    if fee_el:
        parent = fee_el.find_parent(['div', 'section'])
        if parent:
            fees = []
            # Lấy các dòng phí quan trọng (thường là Thường niên, Rút tiền...)
            for item in parent.find_all('div', class_='field-item'):
                t = clean_text(item.select_one('.field-title').get_text()) if item.select_one('.field-title') else ""
                v = clean_text(item.select_one('.field-value').get_text()) if item.select_one('.field-value') else ""
                if t and v:
                    fees.append(f"{t}: {v}")
            
            if not fees:
                # Fallback nếu không có class field-item
                for div in parent.find_all('div'):
                    txt = clean_text(div.get_text())
                    if "Phí thường niên" in txt or "Phí rút tiền" in txt:
                        if txt not in fees: fees.append(txt)

            if fees:
                benefits.append({
                    'title': 'Biểu phí cơ bản',
                    'content': "\n".join(fees[:8])
                })

    # 3. Bóc tách Điều kiện & Hồ sơ
    cond_el = soup.find(string=lambda x: x and 'Điều kiện mở thẻ' in x)
    if cond_el:
        parent = cond_el.find_parent(['div', 'section'])
        if parent:
            conds = [clean_text(li.get_text()) for li in parent.select('li')]
            if not conds: conds = [clean_text(p.get_text()) for p in parent.find_all('p') if len(p.get_text()) > 10]
            if conds:
                benefits.append({
                    'title': 'Điều kiện mở thẻ',
                    'content': "\n".join(conds[:5])
                })

    return benefits

def process_fecredit():
    db, bucket = setup_firebase()
    
    source_path = os.path.join(os.path.dirname(__file__), "fecredit_source.html")
    detail_path = os.path.join(os.path.dirname(__file__), "fecredit_detail_source.html")
    
    with open(source_path, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f.read(), 'html.parser')
    
    with open(detail_path, 'r', encoding='utf-8') as f:
        detail_soup = BeautifulSoup(f.read(), 'html.parser')
        
    sample_benefits = parse_fecredit_detail(detail_soup)
    print(f"🔍 Tìm thấy {len(sample_benefits)} mục thông tin chi tiết (Lãi suất, Phí...)")

    all_cards = []
    # FE Credit dùng div.issued-card-item cho mỗi thẻ
    card_items = soup.select('div.issued-card-item')
    
    for item in card_items:
        title_el = item.select_one('h4.heading')
        if not title_el: continue
        name = clean_text(title_el.get_text())
        
        # Lấy link và ảnh từ card-compare
        compare_box = item.select_one('.card-compare')
        img_url = compare_box.get('data-img') if compare_box else ""
        
        # Link thường nằm trong nút "Chi tiết thẻ" hoặc tương đương
        # Nếu không thấy link cụ thể trong card-item, chúng ta sẽ tạo slug
        link = "https://fecredit.com.vn/the-tin-dung/" # Mặc định
        
        # Lấy highlights từ card-detail
        highlights = []
        detail_items = item.select('.card-detail-item')
        for di in detail_items:
            t = clean_text(di.select_one('.detail-title').get_text()) if di.select_one('.detail-title') else ""
            v = clean_text(di.select_one('.detail-value').get_text()) if di.select_one('.detail-value') else ""
            if t and v:
                highlights.append(f"{t}: {v}")
        
        summary = " | ".join(highlights) if highlights else f"Ưu đãi thẻ FE Credit {name}"

        if name and not any(c['name'] == name for c in all_cards):
            all_cards.append({
                'name': name,
                'url': link,
                'img_url': img_url,
                'summary': summary,
                'highlights': highlights
            })
            print(f"  + Tìm thấy: {name}")

    print(f"\n🚀 Tổng cộng: {len(all_cards)} thẻ FE Credit.")

    for card in all_cards:
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        
        name_lower = card['name'].lower()
        card_type = "Mastercard"
        if "jcb" in name_lower: card_type = "JCB"
        elif "visa" in name_lower: card_type = "Visa"
        
        card_tier = "Classic"
        if any(x in name_lower for x in ['platinum', 'gold', 'plus']):
            card_tier = "Gold" if "gold" in name_lower else "Platinum"

        card_doc = {
            'id': f"fecredit_{slug}",
            'name': card['name'],
            'bankName': 'FE Credit',
            'imagePath': image_path,
            'cashbackHighlight': card['summary'],
            'details': card['highlights'] if card['highlights'] else ["Thẻ tín dụng FE Credit"],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': sample_benefits,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection("cards").document(card_doc['id']).set(card_doc, merge=True)
        print(f"  [OK] Đã lưu: {card_doc['id']}")

    print("\n✨ HOÀN THÀNH FE CREDIT!")

if __name__ == "__main__":
    process_fecredit()
