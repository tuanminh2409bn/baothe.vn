from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time

options = Options()
options.add_argument("--headless")
options.add_argument("--window-size=1920,1080")
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
driver.get("https://tpb.vn/khach-hang-ca-nhan/the-tin-dung")
time.sleep(5)
html = driver.page_source
with open("tpb_source.html", "w") as f:
    f.write(html)
driver.quit()
print("Done")
