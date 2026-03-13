import firebase_admin
from firebase_admin import credentials, firestore
import os

def cleanup():
    # 1. Khởi tạo Firebase
    current_dir = os.path.dirname(os.path.abspath(__file__))
    key_path = os.path.join(current_dir, "serviceAccountKey.json")
    
    if not os.path.exists(key_path):
        print(f"! Không tìm thấy file key tại: {key_path}")
        return

    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)

    db = firestore.client()
    cards_ref = db.collection("cards")

    # 2. Lấy tất cả các thẻ của VPBank
    print("--- ĐANG QUÉT DỮ LIỆU VPBANK TRÊN FIRESTORE ---")
    docs = cards_ref.where("bankName", "==", "VPBank").stream()
    
    count = 0
    for doc in docs:
        data = doc.to_dict()
        doc_id = doc.id
        name = data.get("name", "Không rõ tên")
        
        # Xoá bản ghi
        print(f"  [Xoá] ID: {doc_id} | Tên: {name}")
        doc.reference.delete()
        count += 1

    print(f"--- HOÀN THÀNH: ĐÃ XOÁ {count} BẢN GHI VPBANK ---")
    print("Bây giờ bạn có thể chạy lại vpbank_scraper.py để cập nhật dữ liệu mới sạch sẽ.")

if __name__ == "__main__":
    cleanup()
