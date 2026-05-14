import os
import re
import firebase_admin
from firebase_admin import credentials, firestore

def extract_cashback_rates(text):
    rates = {}
    if not text: return rates
    
    text_lower = text.lower()
    
    matches = re.finditer(r'(hoàn tiền|hoàn|cashback)\s*(lên đến|đến|tới|tối đa)?\s*(\d+(?:[\.,]\d+)?)\s*%', text_lower)
    
    categories = {
        'siêu thị': 'supermarketCashbackRate',
        'coopmart': 'supermarketCashbackRate',
        'online': 'onlineCashbackRate',
        'trực tuyến': 'onlineCashbackRate',
        'du lịch': 'travelCashbackRate',
        'đặt phòng': 'travelCashbackRate',
        'vé máy bay': 'travelCashbackRate',
        'ẩm thực': 'diningCashbackRate',
        'ăn uống': 'diningCashbackRate',
        'nhà hàng': 'diningCashbackRate',
        'y tế': 'medicalCashbackRate',
        'bệnh viện': 'medicalCashbackRate',
        'giáo dục': 'educationCashbackRate',
        'học phí': 'educationCashbackRate',
        'di chuyển': 'transportCashbackRate',
        'grab': 'transportCashbackRate',
        'be': 'transportCashbackRate',
        'mua sắm': 'shoppingCashbackRate',
        'thời trang': 'shoppingCashbackRate',
        'bảo hiểm': 'insuranceCashbackRate',
        'hóa đơn': 'utilitiesCashbackRate',
        'điện nước': 'utilitiesCashbackRate',
        'giải trí': 'entertainmentCashbackRate',
        'xem phim': 'entertainmentCashbackRate',
        'gym': 'gymCashbackRate',
        'thể thao': 'gymCashbackRate',
        'chi tiêu khác': 'otherCashbackRate',
        'mọi chi tiêu': 'otherCashbackRate'
    }
    
    for match in matches:
        rate_str = match.group(3).replace(',', '.')
        try:
            rate = float(rate_str)
            start_idx = max(0, match.start() - 50)
            end_idx = min(len(text_lower), match.end() + 50)
            context = text_lower[start_idx:end_idx]
            
            matched_category = False
            for kw, field in categories.items():
                if kw in context:
                    if field not in rates or rate > rates[field]:
                        rates[field] = rate
                    matched_category = True
                    
            if not matched_category:
                if 'otherCashbackRate' not in rates or rate > rates['otherCashbackRate']:
                    rates['otherCashbackRate'] = rate
                    
        except ValueError:
            continue
            
    return rates

def clean_garbage_data(data_list):
    if not data_list or not isinstance(data_list, list): return []
    cleaned = []
    garbage_keywords = [
        'tải ứng dụng', 'đăng ký tư vấn', 'đăng ký trực tuyến', 'mở thẻ ngay',
        'liên hệ', 'chi tiết biểu phí', 'điều khoản', 'hướng dẫn', 'xem thêm',
        'đăng ký mở thẻ', 'mở thẻ tín dụng', 'quét mã qr', 'app store', 'google play',
        'đăng ký thẻ'
    ]
    
    seen_titles = set()
    for item in data_list:
        if not isinstance(item, dict): continue
        title = item.get('title', '').strip()
        content = item.get('content', '').strip()
        
        if not content or len(content) < 5:
            continue
            
        title_lower = title.lower()
        content_lower = content.lower()
        
        is_garbage = any(kw in title_lower or kw in content_lower[:40] for kw in garbage_keywords)
        
        if not is_garbage:
            if title:
                if title in seen_titles and len(content) < 30:
                    continue
                seen_titles.add(title)
                
            cleaned.append({
                'title': title,
                'content': content
            })
            
    unique_cleaned = []
    seen_contents = set()
    for item in cleaned:
        if item['content'] not in seen_contents:
            unique_cleaned.append(item)
            seen_contents.add(item['content'])
            
    return unique_cleaned

def main():
    print("🚀 Bắt đầu làm sạch và chuẩn hoá dữ liệu thẻ tín dụng trên Firestore...")
    
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    cred_path = os.path.join(base_dir, 'serviceAccountKey.json')
    
    if not os.path.exists(cred_path):
        print(f"❌ Không tìm thấy file key tại: {cred_path}")
        return
        
    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        
    db = firestore.client()
    cards_ref = db.collection('cards')
    docs = cards_ref.stream()
    
    success_count = 0
    for doc in docs:
        data = doc.to_dict()
        card_id = doc.id
        
        # Làm sạch 4 tab
        b_detail = clean_garbage_data(data.get('benefitsDetail', []))
        c_detail = clean_garbage_data(data.get('conditionsDetail', []))
        p_detail = clean_garbage_data(data.get('productInfoDetail', []))
        f_detail = clean_garbage_data(data.get('feeDetail', []))
        
        # Trích xuất toàn bộ text để tính tỷ lệ hoàn tiền
        full_text = f"{data.get('cashbackHighlight', '')} "
        for item in b_detail + p_detail:
            full_text += f"{item.get('content', '')} "
            
        cashback_rates = extract_cashback_rates(full_text)
        
        # Chuẩn bị dữ liệu cập nhật
        update_data = {
            'benefitsDetail': b_detail,
            'conditionsDetail': c_detail,
            'productInfoDetail': p_detail,
            'feeDetail': f_detail
        }
        
        # Cập nhật tỷ lệ hoàn tiền (chỉ cập nhật nếu có tỷ lệ mới cao hơn hoặc chưa có)
        for field, rate in cashback_rates.items():
            current_rate = data.get(field, 0)
            if current_rate is None or rate > (current_rate or 0):
                update_data[field] = rate
                
        try:
            cards_ref.document(card_id).update(update_data)
            success_count += 1
            print(f"✅ Đã làm sạch & cập nhật: {data.get('name', card_id)} (Hoàn tiền: {cashback_rates})")
        except Exception as e:
            print(f"⚠️ Lỗi cập nhật {card_id}: {e}")

    print(f"\n🎉 HOÀN TẤT! Đã làm sạch thành công {success_count} thẻ.")

if __name__ == '__main__':
    main()
