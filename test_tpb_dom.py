from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time

options = Options()
# options.add_argument("--headless") # Run visibly to avoid bot detection
options.add_argument("--window-size=1920,1080")
options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
driver.get("https://tpb.vn/khach-hang-ca-nhan/the-tin-dung")
time.sleep(10)
print(len(driver.page_source))
with open("tpb_source3.html", "w") as f:
    f.write(driver.page_source)
driver.quit()
