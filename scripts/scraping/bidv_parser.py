import os
from bs4 import BeautifulSoup
import json
import re

def clean_text(text):
    return re.sub(r'\s+', ' ', text).strip()

def parse_bidv():
    source_path = 'scripts/scraping/bidv_source.html'
    if not os.path.exists(source_path):
        print(f"File {source_path} not found")
        return

    with open(source_path, 'r', encoding='utf-8') as f:
        html_content = f.read()

    soup = BeautifulSoup(html_content, 'html.parser')
    cards = []

    # Find the container for active cards
    # Looking at the HTML, active cards are in nwp-block-cards divs
    card_items = soup.find_all('div', class_='nwp-block-cards')
    
    # User said only 9 active cards at the top
    count = 0
    for item in card_items:
        if count >= 9: break
        
        card = {}
        
        # 1. Get Name and Detail URL
        title_tag = item.find('h4')
        if not title_tag: continue
        
        card['name'] = clean_text(title_tag.get_text())
        
        link_tag = item.find('a', href=True)
        if link_tag:
            url = link_tag['href']
            if not url.startswith('http'):
                url = 'https://bidv.com.vn' + url
            card['url'] = url
            
        # 2. Get Image
        img_tag = item.find('img')
        if img_tag and img_tag.get('src'):
            img_url = img_tag.get('src')
            if not img_url.startswith('http'):
                img_url = 'https://bidv.com.vn' + img_url
            card['image_url'] = img_url
            
        # 3. Get Highlights
        highlights = []
        card_list = item.find('div', class_='card-list')
        if card_list:
            li_tags = card_list.find_all('li')
            for li in li_tags:
                h_text = clean_text(li.get_text())
                if h_text:
                    highlights.append(h_text)
        card['highlights'] = highlights
        
        card['bank'] = 'BIDV'
        cards.append(card)
        count += 1

    print(f"Found {len(cards)} active BIDV cards")

    # Now parse detail for extra info (using the sample detail file)
    detail_path = 'scripts/scraping/bidv_detail_source.html'
    detail_info = {
        'benefits': [],
        'conditions': "",
        'fees': ""
    }
    
    if os.path.exists(detail_path):
        with open(detail_path, 'r', encoding='utf-8') as f:
            d_soup = BeautifulSoup(f.read(), 'html.parser')
            
            # This is a bit tricky as BIDV uses a tab system
            # We'll try to find specific headers we found earlier
            
            # Find Benefit/Details
            # Usually the first tab or around specific icons
            
            # For BIDV, let's look for "Điều kiện phát hành"
            cond_tag = d_soup.find(string=re.compile("Điều kiện phát hành"))
            if cond_tag:
                parent = cond_tag.find_parent('div')
                if parent:
                    # Get the list following it
                    ul = parent.find_next('ul')
                    if ul:
                        detail_info['conditions'] = clean_text(ul.get_text(separator="\n"))
            
            # Find Fees
            fee_tag = d_soup.find(string=re.compile("Biểu phí"))
            if fee_tag:
                parent = fee_tag.find_parent('div')
                if parent:
                    ul = parent.find_next('ul')
                    if ul:
                        detail_info['fees'] = clean_text(ul.get_text(separator="\n"))

    # Assign detail info to all cards (as a fallback/default for BIDV)
    for c in cards:
        c['default_conditions'] = detail_info['conditions']
        c['default_fees'] = detail_info['fees']

    # Output to JSON
    with open('scripts/scraping/bidv_cards.json', 'w', encoding='utf-8') as f:
        json.dump(cards, f, ensure_ascii=False, indent=4)
    
    for c in cards:
        print(f"- {c['name']}")

if __name__ == "__main__":
    parse_bidv()
