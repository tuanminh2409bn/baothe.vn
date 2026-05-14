from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time

options = Options()
options.add_argument("--window-size=1920,1080")
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
driver.get("https://www.ocb.com.vn/vi/ca-nhan/the/the-tin-dung")
time.sleep(10)
print(len(driver.page_source))
with open("ocb_source2.html", "w") as f:
    f.write(driver.page_source)
driver.quit()
