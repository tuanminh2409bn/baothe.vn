import os
from bs4 import BeautifulSoup
import json

def parse_tpbank():
    source_path = 'scripts/scraping/tpbank_source.html'
    if not os.path.exists(source_path):
        print(f"File {source_path} not found")
        return

    with open(source_path, 'r', encoding='utf-8') as f:
        html_content = f.read()

    soup = BeautifulSoup(html_content, 'html.parser')
    cards = []

    # Find all cart-item divs
    cart_items = soup.find_all('div', class_='cart-item')
    print(f"Found {len(cart_items)} card items")

    for item in cart_items:
        card = {}
        
        # 1. Get Name
        title_div = item.find('div', class_='cart-title-tpb')
        if title_div and title_div.get('data-title'):
            card['name'] = title_div.get('data-title').strip()
        else:
            # Try finding h4 inside or around?
            # Based on grep, there were h4 tags too
            card['name'] = "Unknown Card"

        # 2. Get Image
        img_tag = item.find('img')
        if img_tag and img_tag.get('src'):
            img_url = img_tag.get('src')
            if not img_url.startswith('http'):
                img_url = 'https://tpb.vn' + img_url
            card['image_url'] = img_url
        
        # 3. Get Highlights (Benefits)
        highlights = []
        cart_left = item.find('div', class_='cart-left')
        if cart_left:
            li_tags = cart_left.find_all('li')
            for li in li_tags:
                text = li.get_text(separator=" ", strip=True)
                if text:
                    highlights.append(text)
        card['highlights'] = highlights

        # 4. Construct Detail URL (Guessing based on data-name)
        data_name = item.get('data-name')
        if data_name:
            # Clean up data_name if needed
            slug = data_name.lower().replace(' ', '-')
            card['url'] = f"https://tpb.vn/khach-hang-ca-nhan/the-tin-dung/{slug}"
        
        card['bank'] = 'TPBank'
        cards.append(card)

    # Clean up duplicates by name
    unique_cards = {}
    for c in cards:
        unique_cards[c['name']] = c
    
    final_cards = list(unique_cards.values())
    print(f"Extracted {len(final_cards)} unique cards")

    # Output to JSON
    with open('scripts/scraping/tpbank_cards.json', 'w', encoding='utf-8') as f:
        json.dump(final_cards, f, ensure_ascii=False, indent=4)
    
    for c in final_cards:
        print(f"- {c['name']}")

if __name__ == "__main__":
    parse_tpbank()
