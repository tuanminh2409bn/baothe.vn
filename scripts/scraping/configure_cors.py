import firebase_admin
from firebase_admin import credentials, storage
import os

def configure_cors():
    # 1. Đường dẫn tới file khóa của bạn
    key_path = "scripts/scraping/serviceAccountKey.json"
    bucket_name = "baothevn-790c6.firebasestorage.app"

    if not os.path.exists(key_path):
        print(f"LỖI: Không tìm thấy file {key_path}")
        return

    # 2. Khởi tạo Firebase Admin
    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': bucket_name
        })

    # 3. Thiết lập cấu hình CORS
    # Cho phép tất cả các domain (*) có thể thực hiện lệnh GET (đọc ảnh)
    bucket = storage.bucket()
    bucket.cors = [
        {
            "origin": ["*"],
            "method": ["GET"],
            "responseHeader": ["Content-Type"],
            "maxAgeSeconds": 3600
        }
    ]
    
    # Đẩy cấu hình lên server
    bucket.patch()

    print("--- THÀNH CÔNG: Đã cấu hình CORS cho Firebase Storage! ---")
    print(f"Bây giờ hình ảnh sẽ hiển thị được trên localhost và {bucket_name}")

if __name__ == "__main__":
    configure_cors()
