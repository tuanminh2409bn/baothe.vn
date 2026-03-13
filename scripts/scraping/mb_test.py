import undetected_chromedriver as uc
import time

def test_mb():
    options = uc.ChromeOptions()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    
    print("--- ĐANG THỬ TRUY CẬP MB BANK VỚI UNDETECTED CHROMEDRIVER ---")
    driver = uc.Chrome(options=options)
    try:
        url = "https://www.mbbank.com.vn/ca-nhan/dich-vu-the"
        driver.get(url)
        time.sleep(10)
        print(f"Tiêu đề trang: {driver.title}")
        if "Access Denied" in driver.page_source or "403" in driver.page_source:
            print("Vẫn bị chặn (Access Denied)")
        else:
            print("Truy cập thành công!")
            # In thử một đoạn HTML để kiểm tra
            print(driver.page_source[:500])
    except Exception as e:
        print(f"Lỗi: {e}")
    finally:
        driver.quit()

if __name__ == "__main__":
    test_mb()
