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

def cleanup_namabank():
    db, bucket = setup_firebase()
    print("🧹 Bắt đầu dọn dẹp dữ liệu Nam A Bank...")

    # 1. Xóa trong Firestore
    cards_ref = db.collection("cards")
    query = cards_ref.where("bankName", "==", "Nam A Bank").stream()
    count_db = 0
    for doc in query:
        print(f"  - Đang xóa document: {doc.id}")
        cards_ref.document(doc.id).delete()
        count_db += 1
    print(f"✅ Đã xóa {count_db} thẻ Nam A Bank khỏi Firestore.")

    # 2. Xóa ảnh trong Storage
    blobs = bucket.list_blobs(prefix="card_images/namabank_")
    count_img = 0
    for blob in blobs:
        print(f"  - Đang xóa ảnh: {blob.name}")
        blob.delete()
        count_img += 1
    print(f"✅ Đã xóa {count_img} ảnh Nam A Bank khỏi Storage.")
    print("\n✨ HOÀN THÀNH DỌN DẸP!")

if __name__ == "__main__":
    cleanup_namabank()
