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

def parse_ocb_detail(soup):
    benefits = []
    
    # Danh sách các tiêu đề cần bóc tách
    target_headers = [
        'MIỄN PHÍ SỬ DỤNG DỊCH VỤ PHÒNG CHỜ SÂN BAY',
        'DỊCH VỤ HỖ TRỢ THỦ TỤC TẠI SÂN BAY',
        'Đặc điểm sản phẩm',
        'Ưu đãi cho chủ thẻ mở mới',
        'Ưu đãi hoàn tiền',
        'Ưu đãi nổi bật khác',
        'Tiện ích vượt trội'
    ]
    
    # Lấy toàn bộ text để bóc tách theo cụm
    all_content = soup.find_all(['h2', 'h3', 'h4', 'p', 'li', 'strong', 'span'])
    
    current_title = ""
    current_content = []
    
    for el in all_content:
        txt = clean_text(el.get_text())
        if not txt: continue
        
        # Kiểm tra xem dòng này có phải là tiêu đề mục tiêu không
        found_header = False
        for th in target_headers:
            if th.lower() in txt.lower() and len(txt) < 100:
                # Lưu mục cũ trước khi sang mục mới
                if current_title and current_content:
                    benefits.append({'title': current_title, 'content': "\n".join(current_content)})
                
                current_title = txt
                current_content = []
                found_header = True
                break
        
        if not found_header and current_title:
            # Lọc bỏ text rác
            if len(txt) > 5 and not any(x in txt.lower() for x in ['đăng ký ngay', 'chi tiết', 'tại đây', 'điều kiện', 'thời kỳ']):
                if txt not in current_content:
                    current_content.append(txt)
            
    # Thêm mục cuối cùng
    if current_title and current_content:
        benefits.append({'title': current_title, 'content': "\n".join(current_content)})

    return benefits

def process_ocb():
    db, bucket = setup_firebase()
    
    source_path = os.path.join(os.path.dirname(__file__), "ocb_source.html")
    detail_path = os.path.join(os.path.dirname(__file__), "ocb_detail_source.html")
    
    with open(source_path, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f.read(), 'html.parser')
    
    with open(detail_path, 'r', encoding='utf-8') as f:
        detail_soup = BeautifulSoup(f.read(), 'html.parser')
        
    sample_benefits = parse_ocb_detail(detail_soup)
    print(f"🔍 Tìm thấy {len(sample_benefits)} mục thông tin chi tiết (Phòng chờ, Hoàn tiền, Biểu phí...)")

    all_cards = []
    # OCB dùng app-product-card-category-item cho mỗi thẻ
    card_items = soup.select('app-product-card-category-item')
    
    for item in card_items:
        img_el = item.select_one('.product-card-image img')
        if not img_el: continue
        
        name = clean_text(img_el.get('alt', ''))
        name = name.replace('THẺ ', '').replace('OCB ', '').strip()
        name = f"OCB {name}"

        img_url = img_el.get('src', '')
        
        # Link
        link = "https://www.ocb.com.vn/vi/ca-nhan/the/the-tin-dung"
        link_el = item.find('a', href=True)
        if link_el:
            link = "https://www.ocb.com.vn" + link_el['href'] if not link_el['href'].startswith('http') else link_el['href']
        
        # Bóc tách thông tin trang ngoài: Mô tả và Phí thường niên
        highlights = []
        # Toàn bộ text trong card body
        card_body = item.select_one('.product-card-category-item')
        if card_body:
            all_text = [clean_text(t.get_text()) for t in card_body.find_all(['span', 'p']) if len(t.get_text(strip=True)) > 5]
            
            # Tìm mô tả và phí
            found_fee = False
            for i, txt in enumerate(all_text):
                if "Sản phẩm thẻ" in txt or len(txt) > 80:
                    if txt not in highlights: highlights.append(txt)
                if "Phí thường niên" in txt:
                    found_fee = True
                    highlights.append(txt)
                    # Lấy text tiếp theo làm giá trị phí
                    if i + 1 < len(all_text):
                        highlights.append(all_text[i+1])
        
        summary = " | ".join(highlights) if highlights else f"Mở thẻ {name} để tận hưởng đặc quyền thượng đỉnh"

        if name and not any(c['name'] == name for c in all_cards):
            all_cards.append({
                'name': name,
                'url': link,
                'img_url': img_url,
                'summary': summary,
                'highlights': highlights
            })
            print(f"  + Tìm thấy: {name}")

    print(f"\n🚀 Tổng cộng: {len(all_cards)} thẻ OCB.")

    for card in all_cards:
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        
        name_lower = card['name'].lower()
        card_type = "Visa"
        if "mastercard" in name_lower: card_type = "Mastercard"
        elif "jcb" in name_lower: card_type = "JCB"
        
        card_tier = "Classic"
        if any(x in name_lower for x in ['platinum', 'world', 'signature', 'infinite', 'priority']):
            card_tier = "Platinum"

        # Tùy biến đặc quyền cho từng loại thẻ dựa trên mẫu
        card_doc = {
            'id': f"ocb_{slug}",
            'name': card['name'],
            'bankName': 'OCB',
            'imagePath': image_path,
            'cashbackHighlight': card['summary'],
            'details': card['highlights'] if card['highlights'] else [b['title'] for b in sample_benefits[:3]],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': sample_benefits,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection("cards").document(card_doc['id']).set(card_doc, merge=True)
        print(f"  [OK] Đã lưu: {card_doc['id']}")

    print("\n✨ HOÀN THÀNH OCB!")

if __name__ == "__main__":
    process_ocb()
