import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
import os

def sync_cashback_data():
    print("🚀 Bắt đầu đồng bộ dữ liệu hoàn tiền CHÍNH XÁC từ Excel...")
    
    # 1. Khởi tạo Firebase
    # Tự động tìm file serviceAccountKey.json ở thư mục gốc của dự án
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    cred_path = os.path.join(base_dir, 'serviceAccountKey.json')
    
    if os.path.exists(cred_path):
        print(f"🔑 Đã tìm thấy file bản quyền: {cred_path}")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    else:
        print(f"❌ Lỗi: Không tìm thấy file {cred_path}")
        print("💡 Hướng dẫn: Bạn hãy đảm bảo file serviceAccountKey.json nằm ở thư mục gốc (baothe_vn/).")
        return

    db = firestore.client()
    
    # 2. Đọc file Excel
    excel_path = 'cards_cashback_data.xlsx'
    if not os.path.exists(excel_path):
        print(f"❌ Lỗi: Không tìm thấy file {excel_path}")
        return
        
    try:
        # Đọc file Excel, đảm bảo ID được đọc dưới dạng chuỗi
        df = pd.read_excel(excel_path)
    except Exception as e:
        print(f"❌ Lỗi khi đọc file Excel: {e}")
        return

    # 3. Ánh xạ CHÍNH XÁC các cột Excel của bạn vào Firestore Fields
    column_mapping = {
        'Hoàn tiền Siêu thị (%)': 'supermarketCashbackRate',
        'Hoàn tiền Mua sắm Online/Shopee/Tiki (%)': 'onlineCashbackRate',
        'Hoàn tiền Du lịch/Khách sạn/Máy bay (%)': 'travelCashbackRate',
        'Hoàn tiền Ăn uống/Ẩm thực (%)': 'diningCashbackRate',
        'Hoàn tiền Y tế (%)': 'medicalCashbackRate',
        'Hoàn tiền Giáo dục (%)': 'educationCashbackRate',
        'Hoàn tiền Di chuyển/Grab/Be/Xanh SM (%)': 'transportCashbackRate',
        'Hoàn tiền Mua sắm (%)': 'shoppingCashbackRate',
        'Hoàn tiền Bảo hiểm (%)': 'insuranceCashbackRate',
        'Hoàn tiền Điện/Nước/Hóa đơn (%)': 'utilitiesCashbackRate',
        'Hoàn tiền Giải trí (%)': 'entertainmentCashbackRate',
        'Hoàn tiền Gym/Thể thao (%)': 'gymCashbackRate',
        'Hoàn tiền Chi tiêu (%)': 'otherCashbackRate',
        'Max Hoàn tiền / Tháng (VNĐ)': 'maxCashbackPerMonth',
        'Link Đăng ký / Chi tiết': 'applyUrl',
        'Quyền lợi nổi bật (Tham khảo)': 'cashbackHighlight'
    }

    print(f"📊 Tìm thấy {len(df)} dòng dữ liệu trong Excel.")
    
    success_count = 0
    for index, row in df.iterrows():
        # Lấy ID thẻ để tìm trong Firestore
        card_id = str(row.get('ID Thẻ (KHÔNG SỬA)', ''))
        card_name = str(row.get('Tên thẻ', ''))
        
        if not card_id or card_id == 'nan':
            continue
            
        # 4. Tìm và cập nhật trong bộ sưu tập 'cards'
        card_ref = db.collection('cards').document(card_id)
        
        update_data = {}
        for excel_col, firestore_field in column_mapping.items():
            if excel_col in df.columns:
                val = row[excel_col]
                if pd.isna(val):
                    continue
                
                # Làm sạch dữ liệu số
                if isinstance(val, (int, float)):
                    update_data[firestore_field] = float(val)
                elif isinstance(val, str):
                    clean_val = val.replace('%', '').replace(',', '').strip()
                    try:
                        update_data[firestore_field] = float(clean_val)
                    except:
                        update_data[firestore_field] = val # Giữ nguyên nếu là text (như link)

        if update_data:
            try:
                # Cập nhật thông tin gốc của thẻ
                card_ref.update(update_data)
                
                # 5. ĐỒNG BỘ SANG USER_CARDS (Ví của người dùng)
                # Tìm tất cả các ví của người dùng đang sử dụng loại thẻ này để cập nhật theo
                user_cards_query = db.collection('user_cards').where('cardId', '==', card_id).stream()
                for user_card_doc in user_cards_query:
                    db.collection('user_cards').document(user_card_doc.id).update(update_data)
                
                success_count += 1
                print(f"✅ Đã đồng bộ: {card_name} (ID: {card_id})")
            except Exception as e:
                print(f"⚠️ Lỗi khi cập nhật thẻ {card_id}: {e}")

    print(f"\n🎉 HOÀN TẤT! Đã đồng bộ chính xác {success_count} thẻ.")
    print("💡 Bây giờ bạn hãy mở App để tận hưởng dữ liệu mới nhất!")

if __name__ == "__main__":
    sync_cashback_data()
