import json

try:
    with open('acb_data.json') as f:
        d = json.load(f)
    
    pageProps = d.get('props', {}).get('pageProps', {})
    print(f"Keys in pageProps: {list(pageProps.keys())}")
    
    data = pageProps.get('data', {})
    if data:
        print(f"Keys in data: {list(data.keys())}")
        components = data.get('components', [])
        print(f"Number of components: {len(components)}")
        
        for i, comp in enumerate(components):
            comp_type = comp.get('type')
            print(f"Component {i}: Type {comp_type}")
            if comp_type == 'ProductCategory':
                # Đây có thể là nơi chứa danh sách thẻ
                products = comp.get('products', [])
                print(f"  Found {len(products)} products in ProductCategory")
                for p in products:
                    print(f"    - {p.get('title')} (slug: {p.get('slug')})")

    # Kiểm tra thêm trong các object khác
    if not data:
        # Đôi khi dữ liệu nằm ở chỗ khác
        print("Data is null, checking queries or fallback...")

except Exception as e:
    print(f"Error: {e}")
