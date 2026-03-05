import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import json
import os
import glob

def upload_scraped_data():
    # 1. Khởi tạo Firebase Admin SDK
    # Cần file serviceAccountKey.json từ Firebase Console
    key_path = "scripts/scraping/serviceAccountKey.json"
    
    if not os.path.exists(key_path):
        print(f"LỖI: Không tìm thấy file {key_path}. Hãy tải từ Firebase Console!")
        return

    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    # 2. Tìm tất cả các file JSON đã cào
    json_files = glob.glob("data/scraped/*.json")
    print(f"Tìm thấy {len(json_files)} file dữ liệu.")

    total_uploaded = 0
    for file_path in json_files:
        print(f"Đang xử lý: {file_path}")
        with open(file_path, "r", encoding="utf-8") as f:
            cards = json.load(f)
            
            for card in cards:
                try:
                    # Dùng ID làm document ID để tránh trùng lặp
                    card_id = card.get("id")
                    if not card_id: continue
                    
                    db.collection("cards").document(card_id).set(card, merge=True)
                    print(f"  + Đã đẩy: {card['name']}")
                    total_uploaded += 1
                except Exception as e:
                    print(f"  - Lỗi khi đẩy thẻ {card.get('name')}: {e}")

    print(f"--- HOÀN THÀNH: Đã nạp {total_uploaded} thẻ lên Firestore ---")

if __name__ == "__main__":
    upload_scraped_data()
