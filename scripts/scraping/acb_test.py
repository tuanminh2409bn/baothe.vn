import undetected_chromedriver as uc
import time

def test_acb():
    options = uc.ChromeOptions()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    
    print("--- ĐANG THỬ TRUY CẬP ACB VỚI UNDETECTED CHROMEDRIVER ---")
    driver = uc.Chrome(options=options)
    try:
        url = "https://acb.com.vn/the-tin-dung"
        driver.get(url)
        time.sleep(10)
        print(f"Tiêu đề trang: {driver.title}")
        if "404" in driver.page_source or "Access Denied" in driver.page_source:
            print("Lỗi truy cập (404/Access Denied)")
        else:
            print("Truy cập thành công!")
            # In thử một đoạn HTML để kiểm tra các link thẻ
            print(driver.page_source[:1000])
    except Exception as e:
        print(f"Lỗi: {e}")
    finally:
        driver.quit()

if __name__ == "__main__":
    test_acb()
