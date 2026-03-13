import time
import json
from scripts.scraping.base_scraper import BaseScraper

class TCBSurgicalCheck(BaseScraper):
    def __init__(self, url):
        super().__init__("TechcombankSurgical", url)

    def check(self):
        self.driver.get(self.url)
        time.sleep(10)
        
        # Cuộn trang nhiều lần
        for i in range(5):
            self.driver.execute_script(f"window.scrollTo(0, {i*1000});")
            time.sleep(1)

        data = self.driver.execute_script("""
            let res = {
                name: document.querySelector('h1')?.innerText.trim(),
                img: "",
                benefits: [],
                conditions: [],
                fees: [],
                productInfo: [],
                tables: []
            };

            // Image
            let imgCandidates = Array.from(document.querySelectorAll('img')).filter(img => 
                img.src.includes('masthead') || img.src.includes('card') || (img.alt && img.alt.toLowerCase().includes('thẻ'))
            );
            if (imgCandidates.length > 0) {
                let desktopImg = imgCandidates.find(img => img.src.includes('desktop'));
                res.img = desktopImg ? desktopImg.src : imgCandidates[0].src;
            }

            // Tables
            document.querySelectorAll('table').forEach(table => {
                let rows = [];
                table.querySelectorAll('tr').forEach(tr => {
                    let cols = Array.from(tr.querySelectorAll('td, th')).map(c => c.innerText.trim());
                    if (cols.length > 0) rows.push(cols);
                });
                if (rows.length > 0) res.tables.push(rows);
            });

            // Accordion - More general
            document.querySelectorAll('[class*="accordion"]').forEach(acc => {
                // Thử tìm các header và panel theo class pattern của TCB
                let items = acc.querySelectorAll('[class*="item"]');
                items.forEach(item => {
                    let title = item.querySelector('[class*="header"], [class*="title"], button')?.innerText.trim();
                    let content = item.querySelector('[class*="panel"], [class*="content"], [role="region"]')?.innerText.trim();
                    if (title && title.length < 200) {
                        let obj = {title, content: content || ""};
                        if (title.toLowerCase().includes('phí')) res.fees.append ? res.fees.push(obj) : res.fees.push(obj);
                        else if (title.toLowerCase().includes('điều kiện')) res.conditions.push(obj);
                        else res.productInfo.push(obj);
                    }
                });
            });

            // Nếu vẫn ít dữ liệu, quét các H2 và các div/p sau đó
            if (res.benefits.length < 2) {
                document.querySelectorAll('h2').forEach(h2 => {
                    let title = h2.innerText.trim();
                    if (title.length > 3 && title.length < 100) {
                        let next = h2.nextElementSibling;
                        let content = "";
                        if (next) content = next.innerText.trim();
                        res.benefits.push({title, content});
                    }
                });
            }

            return res;
        """)
        
        print(json.dumps(data, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    url = "https://techcombank.com/khach-hang-ca-nhan/chi-tieu/the/the-tin-dung/techcombank-visa-signature"
    checker = TCBSurgicalCheck(url)
    try:
        checker.check()
    finally:
        checker.quit()
