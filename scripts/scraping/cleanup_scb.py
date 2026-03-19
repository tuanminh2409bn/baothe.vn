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

def cleanup_scb():
    db, bucket = setup_firebase()
    print("🧹 Đang dọn dẹp dữ liệu SCB...")

    # 1. Xóa trong Firestore
    cards_ref = db.collection("cards")
    docs = cards_ref.where("bankName", "==", "SCB").stream()
    count_fs = 0
    for doc in docs:
        print(f"  - Xóa Firestore: {doc.id}")
        doc.reference.delete()
        count_fs += 1
    print(f"✅ Đã xóa {count_fs} thẻ SCB trên Firestore.")

    # 2. Xóa trong Storage
    blobs = bucket.list_blobs(prefix="card_images/scb_")
    count_st = 0
    for blob in blobs:
        print(f"  - Xóa Storage: {blob.name}")
        blob.delete()
        count_st += 1
    print(f"✅ Đã xóa {count_st} ảnh SCB trên Storage.")

    print("\n✨ HOÀN THÀNH DỌN DẸP SCB!")

if __name__ == "__main__":
    cleanup_scb()
