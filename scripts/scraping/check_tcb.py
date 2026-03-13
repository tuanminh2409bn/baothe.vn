import time
from scripts.scraping.base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class TCBCheck(BaseScraper):
    def __init__(self):
        super().__init__("Techcombank", "https://techcombank.com/khach-hang-ca-nhan/chi-tieu/the/the-tin-dung")

    def check(self):
        print("--- ĐANG KIỂM TRA TECHCOMBANK ---")
        self.driver.get(self.url)
        time.sleep(10)
        
        # Thử cuộn xuống
        print("Cuộn trang...")
        self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight/2);")
        time.sleep(2)
        self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(2)

        # Lấy toàn bộ link
        links = self.driver.execute_script("""
            let results = [];
            document.querySelectorAll('a').forEach(a => {
                if (a.href.includes('/the/')) {
                    results.push({
                        text: a.innerText.trim(),
                        href: a.href,
                        html: a.outerHTML
                    });
                }
            });
            return results;
        """)
        
        print(f"Tìm thấy {len(links)} link liên quan đến /the/")
        for l in links:
            if len(l['text']) > 0:
                print(f"Text: {l['text']} | Href: {l['href']}")

        # Thử tìm ảnh
        images = self.driver.execute_script("""
            let imgs = [];
            document.querySelectorAll('img').forEach(img => {
                if (img.src.includes('/the/')) {
                    imgs.push(img.src);
                }
            });
            return imgs;
        """)
        print(f"Tìm thấy {len(images)} ảnh liên quan đến /the/")
        for img in images[:5]:
            print(f"Img: {img}")

if __name__ == "__main__":
    checker = TCBCheck()
    try:
        checker.check()
    finally:
        checker.quit()
