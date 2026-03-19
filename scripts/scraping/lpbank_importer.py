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
    if not url.startswith('http'): url = 'https://lpbank.com.vn/' + url.lstrip('/')
    print(f"    + Đang tải ảnh: {url}")
    try:
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, stream=True, timeout=20)
        if response.status_code == 200:
            ext = ".png" if ".png" in url.lower() else ".jpg"
            filename = f"lpbank_{card_id}{ext}"
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

def parse_lpbank_detail(soup):
    benefits = []
    
    # 1. Bóc tách "Tiện ích nổi bật" (thường là các highlights dạng slide hoặc list)
    ti_noi_bat_el = soup.find(string=lambda x: x and 'Tiện ích nổi bật' in x)
    if ti_noi_bat_el:
        section = ti_noi_bat_el.find_parent(['section', 'div', 'app-sec-tien-ich'])
        if section:
            # Tìm các câu tóm tắt (thường nằm trong textBox hoặc p)
            highlights = []
            for item in section.select('.textBox, p'):
                txt = clean_text(item.get_text())
                # Lọc các câu có độ dài vừa phải và không phải là tiêu đề chính
                if 20 < len(txt) < 200 and "Tiện ích nổi bật" not in txt:
                    if txt not in highlights:
                        highlights.append(txt)
            
            if highlights:
                benefits.append({
                    'title': 'Tiện ích nổi bật',
                    'content': "\n".join([f"• {h}" for h in highlights])
                })

    # 2. Bóc tách "Chi tiết sản phẩm:" (Chứa các mục 1, 2, 3, 4, 5)
    ct_sp_el = soup.find(string=lambda x: x and 'Chi tiết sản phẩm:' in x)
    if ct_sp_el:
        container = ct_sp_el.find_parent(['div', 'section'])
        if container:
            # Tìm tất cả các đoạn văn bản sau "Chi tiết sản phẩm:"
            all_p = container.find_all(['p', 'li', 'strong'])
            
            current_section_title = ""
            current_section_content = []
            
            # Bắt đầu lấy dữ liệu sau khi gặp "Chi tiết sản phẩm:"
            start_collecting = False
            for p in all_p:
                txt = clean_text(p.get_text())
                if not txt: continue
                
                if "Chi tiết sản phẩm:" in txt:
                    start_collecting = True
                    continue
                
                if start_collecting:
                    # Nhận diện các mục đánh số (1., 2., 3...)
                    if re.match(r'^\d+\.', txt):
                        # Lưu mục cũ trước khi sang mục mới
                        if current_section_title and current_section_content:
                            benefits.append({
                                'title': current_section_title,
                                'content': "\n".join(current_section_content)
                            })
                        current_section_title = txt
                        current_section_content = []
                    elif current_section_title:
                        # Tránh lấy lại các text của mục "Tiện ích nổi bật" hoặc nút bấm
                        if len(txt) > 5 and not any(x in txt.lower() for x in ['đăng ký ngay', 'chi tiết', 'tại đây']):
                            if txt not in current_section_content:
                                current_section_content.append(txt)
            
            # Thêm mục cuối cùng của phần Chi tiết sản phẩm
            if current_section_title and current_section_content:
                benefits.append({
                    'title': current_section_title,
                    'content': "\n".join(current_section_content)
                })

    return benefits

def process_lpbank():
    db, bucket = setup_firebase()
    
    source_path = os.path.join(os.path.dirname(__file__), "lpbank_source.html")
    detail_path = os.path.join(os.path.dirname(__file__), "lpbank_detail_source.html")
    
    with open(source_path, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f.read(), 'html.parser')
    
    with open(detail_path, 'r', encoding='utf-8') as f:
        detail_soup = BeautifulSoup(f.read(), 'html.parser')
        
    # Lấy mẫu đặc quyền từ trang chi tiết
    sample_benefits = parse_lpbank_detail(detail_soup)
    print(f"🔍 Tìm thấy {len(sample_benefits)} đặc quyền mẫu từ file chi tiết.")

    # Tìm danh sách thẻ từ trang ngoài
    all_cards = []
    # LPBank dùng cấu trúc .productBox__body cho thông tin thẻ
    card_bodies = soup.select('.productBox__body')
    
    for body in card_bodies:
        title_el = body.select_one('.productBox__title a') or body.find('h3')
        if not title_el: continue
        name = clean_text(title_el.get_text())
        
        # Chỉ lấy thẻ tín dụng
        if "thẻ tín dụng" not in name.lower(): continue
        
        # Tìm link và ảnh từ phần tử cha hoặc anh em
        parent = body.find_parent('div', class_='productBox')
        link = ""
        img_url = ""
        if parent:
            link_el = parent.find('a', href=True)
            link = link_el['href'] if link_el else ""
            img_el = parent.find('img')
            img_url = img_el['src'] if img_el else ""
        
        if not link.startswith('http') and link: link = "https://lpbank.com.vn" + link
        
        # Lấy thông tin highlight từ productBox__package
        package = body.select_one('.productBox__package')
        summary_list = []
        if package:
            items = package.select('.f-item')
            for it in items:
                label = clean_text(it.find('span').get_text()) if it.find('span') else ""
                val = clean_text(it.find('p').get_text()) if it.find('p') else ""
                if label and val:
                    summary_list.append(f"{label}: {val}")
        
        summary = " | ".join(summary_list) if summary_list else f"Trải nghiệm đặc quyền cùng {name}"

        if name and not any(c['name'] == name for c in all_cards):
            all_cards.append({
                'name': name,
                'url': link,
                'img_url': img_url,
                'summary': summary,
                'highlights': summary_list
            })
            print(f"  + Tìm thấy: {name} ({summary})")

    if not all_cards:
        # Fallback: Nếu không tìm thấy bằng class, tìm tất cả <a> có chứa "Thẻ tín dụng"
        print("⚠️ Không tìm thấy bằng selector class, thử fallback...")
        for a in soup.find_all('a', href=True):
            txt = clean_text(a.get_text())
            if "thẻ tín dụng quốc tế" in txt.lower():
                parent = a.find_parent('div')
                img = parent.find('img')['src'] if parent and parent.find('img') else ""
                if txt and not any(c['name'] == txt for c in all_cards):
                    all_cards.append({
                        'name': txt,
                        'url': "https://lpbank.com.vn" + a['href'] if not a['href'].startswith('http') else a['href'],
                        'img_url': img,
                        'summary': f"Trải nghiệm đặc quyền cùng {txt}"
                    })
                    print(f"  + Tìm thấy (fallback): {txt}")

    print(f"\n🚀 Tổng cộng: {len(all_cards)} thẻ LPBank.")

    for card in all_cards:
        slug = slugify(card['name'])
        image_path = download_and_upload_image(card['img_url'], slug, bucket)
        
        # Xác định loại & hạng thẻ
        name_lower = card['name'].lower()
        card_type = "Visa"
        if "jcb" in name_lower: card_type = "JCB"
        elif "mastercard" in name_lower: card_type = "Mastercard"
        
        card_tier = "Classic"
        if any(x in name_lower for x in ['platinum', 'signature', 'ultimate', 'world']):
            card_tier = "Platinum"
        elif "gold" in name_lower:
            card_tier = "Gold"

        # Vì chúng ta chỉ có 1 trang chi tiết mẫu, chúng ta sẽ gán đặc quyền cho các thẻ tương ứng
        # Nếu thẻ là Signature thì lấy từ mẫu, nếu không thì lấy các tiện ích chung
        card_benefits = sample_benefits if "signature" in name_lower or "ultimate" in name_lower else sample_benefits[:3]

        card_doc = {
            'id': f"lpbank_{slug}",
            'name': card['name'],
            'bankName': 'LPBank',
            'imagePath': image_path,
            'cashbackHighlight': card['summary'],
            'details': card['highlights'] if card['highlights'] else [b['title'] for b in card_benefits[:5]],
            'applyUrl': card['url'],
            'cardType': card_type,
            'cardTier': card_tier,
            'benefitsDetail': card_benefits,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection("cards").document(card_doc['id']).set(card_doc, merge=True)
        print(f"  [OK] Đã lưu: {card_doc['id']}")

    print("\n✨ HOÀN THÀNH LPBANK!")

if __name__ == "__main__":
    process_lpbank()
