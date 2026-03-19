import os
import firebase_admin
from firebase_admin import credentials, storage, firestore

def setup_firebase():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    key_path = os.path.join(current_dir, "serviceAccountKey.json")
    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'baothevn-790c6.firebasestorage.app'
        })
    return firestore.client(), storage.bucket()

def cleanup_wooribank():
    db, bucket = setup_firebase()
    
    print("🧹 Đang dọn dẹp dữ liệu Woori Bank...")

    # 1. Xóa trong Firestore (Xóa cả 'Woori Bank' và 'Wooribank' cho chắc chắn)
    try:
        cards_ref = db.collection("cards")
        
        # Xóa các bản ghi có bankName là Woori Bank hoặc Wooribank
        count_db = 0
        for name in ["Woori Bank", "Wooribank"]:
            query = cards_ref.where("bankName", "==", name).stream()
            for doc in query:
                print(f"  - Xóa Firestore: {doc.id} ({name})")
                doc.reference.delete()
                count_db += 1
        
        print(f"✅ Đã xóa {count_db} thẻ Woori Bank trên Firestore.")
    except Exception as e:
        print(f"  ! Lỗi Firestore: {e}")

    # 2. Xóa trong Storage
    try:
        blobs = bucket.list_blobs(prefix="card_images/wooribank_")
        
        count_st = 0
        for blob in blobs:
            print(f"  - Xóa Storage: {blob.name}")
            blob.delete()
            count_st += 1
            
        print(f"✅ Đã xóa {count_st} ảnh Woori Bank trên Storage.")
    except Exception as e:
        print(f"  ! Lỗi Storage: {e}")

    print("\n✨ HOÀN THÀNH DỌN DẸP WOORI BANK!")

if __name__ == "__main__":
    cleanup_wooribank()
