import time
from scripts.scraping.base_scraper import BaseScraper
from selenium.webdriver.common.by import By

class TCBDetailCheck(BaseScraper):
    def __init__(self, url):
        super().__init__("TechcombankDetail", url)

    def check(self):
        print(f"--- ĐANG KIỂM TRA CHI TIẾT: {self.url} ---")
        self.driver.get(self.url)
        time.sleep(10)
        
        # Cuộn trang từng đoạn để trigger lazy load
        for i in range(1, 6):
            self.driver.execute_script(f"window.scrollTo(0, {i} * 1000);")
            time.sleep(1)

        data = self.driver.execute_script("""
            let results = {
                h1: document.querySelector('h1')?.innerText,
                h2s: Array.from(document.querySelectorAll('h2')).map(h => h.innerText),
                all_images: Array.from(document.querySelectorAll('img')).map(img => ({src: img.src, alt: img.alt, class: img.className})),
                sections: Array.from(document.querySelectorAll('section')).map(s => ({id: s.id, class: s.className, h2: s.querySelector('h2')?.innerText})),
                divs_with_id: Array.from(document.querySelectorAll('div[id]')).map(d => d.id)
            };
            return results;
        """)
        
        print(f"H1: {data['h1']}")
        print(f"H2s: {data['h2s']}")
        print(f"Sections: {data['sections']}")
        print(f"Divs with ID: {data['divs_with_id']}")
        
        print("\n--- PHÂN TÍCH ẢNH ---")
        for img in data['all_images']:
            if "the" in img['src'].lower() or "card" in img['src'].lower() or img['class']:
                print(f"Src: {img['src']} | Alt: {img['alt']} | Class: {img['class']}")

if __name__ == "__main__":
    url = "https://techcombank.com/khach-hang-ca-nhan/chi-tieu/the/the-tin-dung/techcombank-visa-signature"
    checker = TCBDetailCheck(url)
    try:
        checker.check()
    finally:
        checker.quit()
