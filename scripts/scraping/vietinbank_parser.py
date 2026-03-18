import os
from bs4 import BeautifulSoup
import json
import re

def clean_text(text):
    return re.sub(r'\s+', ' ', text).strip()

def parse_vietinbank():
    source_path = 'scripts/scraping/vietinbank_source.html'
    if not os.path.exists(source_path):
        print(f"File {source_path} not found")
        return

    with open(source_path, 'r', encoding='utf-8') as f:
        html_content = f.read()

    soup = BeautifulSoup(html_content, 'html.parser')
    cards = []

    # VietinBank uses 'swiper-slide' for card items
    card_items = soup.find_all('div', class_='swiper-slide')
    print(f"Found {len(card_items)} potential card items")

    for item in card_items:
        # Each card has a name in a specific div
        name_div = item.find('div', class_=re.compile(r'truncate.*font-semibold'))
        if not name_div: continue
        
        card = {}
        card['name'] = clean_text(name_div.get_text())
        
        # Detail URL
        link_tag = item.find('a', href=True)
        if link_tag:
            url = link_tag['href']
            if not url.startswith('http'):
                url = 'https://vietinbank.vn' + url
            card['url'] = url
            
        # Image
        img_tag = item.find('img')
        if img_tag and img_tag.get('src'):
            img_url = img_tag.get('src')
            # VietinBank uses Next.js Image Optimization
            # We want the actual asset URL if possible
            match = re.search(r'url=(.*?)&', img_url)
            if match:
                img_url = requests.utils.unquote(match.group(1))
            
            if not img_url.startswith('http'):
                img_url = 'https://vietinbank.vn' + img_url
            card['image_url'] = img_url
            
        # Highlights
        highlights = []
        # Find ul with li tags
        ul_tag = item.find('ul')
        if ul_tag:
            li_tags = ul_tag.find_all('li')
            for li in li_tags:
                text = clean_text(li.get_text())
                if text:
                    highlights.append(text)
        card['highlights'] = highlights
        
        # Second highlight (usually the success badge)
        badge = item.find('div', class_=re.compile(r'badge-success'))
        if badge:
            badge_text = clean_text(badge.get_text())
            if badge_text and badge_text not in highlights:
                highlights.insert(0, badge_text)

        card['bank'] = 'VietinBank'
        cards.append(card)

    # De-duplicate by name
    unique_cards = {}
    for c in cards:
        unique_cards[c['name']] = c
    
    final_cards = list(unique_cards.values())
    print(f"Extracted {len(final_cards)} unique VietinBank cards")

    # Now handle detail sample for Conditions/Fees
    detail_path = 'scripts/scraping/vietinbank_detail_source.html'
    default_info = {
        'conditions': "• Công dân Việt Nam hoặc người nước ngoài đang sinh sống tại Việt Nam\n• Độ tuổi từ 18 tuổi trở lên\n• Có nguồn thu nhập ổn định và đảm bảo khả năng trả nợ\n• Các điều kiện khác theo quy định của VietinBank từng thời kỳ",
        'fees': "• Miễn phí phát hành thẻ\n• Phí thường niên: Theo biểu phí hiện hành của VietinBank\n• Lãi suất: Theo quy định của ngân hàng\n• Miễn lãi lên đến 45-55 ngày"
    }
    
    # Try to find better info in detail source if available
    if os.path.exists(detail_path):
        with open(detail_path, 'r', encoding='utf-8') as f:
            d_soup = BeautifulSoup(f.read(), 'html.parser')
            # The structure for tabs is complex in static HTML of Next.js
            # We'll use the default for now or look for specific strings if they exist
            
    for c in final_cards:
        c['default_conditions'] = default_info['conditions']
        c['default_fees'] = default_info['fees']

    # Output to JSON
    with open('scripts/scraping/vietinbank_cards.json', 'w', encoding='utf-8') as f:
        json.dump(final_cards, f, ensure_ascii=False, indent=4)
    
    for c in final_cards:
        print(f"- {c['name']}")

if __name__ == "__main__":
    import requests
    parse_vietinbank()
