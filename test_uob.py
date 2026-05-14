from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time

options = Options()
options.add_argument("--window-size=1920,1080")
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
driver.get("https://www.uob.com.vn/personal/cards/index.page")
time.sleep(5)
from bs4 import BeautifulSoup
soup = BeautifulSoup(driver.page_source, "html.parser")
print("Title:", soup.title.string if soup.title else "No title")
with open("uob_source.html", "w") as f:
    f.write(driver.page_source)
driver.quit()
