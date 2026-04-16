import pandas as pd
import json
import os

def export_cashback_to_json():
    excel_path = 'cards_cashback_data.xlsx'
    if not os.path.exists(excel_path):
        print(f"Error: {excel_path} not found.")
        return

    df = pd.read_excel(excel_path)
    
    # Mapping Excel columns to Firestore field names
    mapping = {
        'ID Thẻ (KHÔNG SỬA)': 'id',
        'Ngân hàng': 'bankName',
        'Tên thẻ': 'name',
        'Hoàn tiền Y tế (%)': 'medicalCashbackRate',
        'Hoàn tiền Gym/Thể thao (%)': 'gymCashbackRate',
        'Hoàn tiền Mua sắm (%)': 'shoppingCashbackRate',
        'Hoàn tiền Siêu thị (%)': 'supermarketCashbackRate',
        'Hoàn tiền Mua sắm Online/Shopee/Tiki (%)': 'onlineCashbackRate',
        'Hoàn tiền Du lịch/Khách sạn/Máy bay (%)': 'travelCashbackRate',
        'Hoàn tiền Ăn uống/Ẩm thực (%)': 'diningCashbackRate',
        'Hoàn tiền Di chuyển/Grab/Be/Xanh SM (%)': 'transportCashbackRate',
        'Hoàn tiền Giáo dục (%)': 'educationCashbackRate',
        'Hoàn tiền Điện/Nước/Hóa đơn (%)': 'utilitiesCashbackRate',
        'Hoàn tiền Giải trí (%)': 'entertainmentCashbackRate',
        'Hoàn tiền Bảo hiểm (%)': 'insuranceCashbackRate',
        'Hoàn tiền Chi tiêu (%)': 'otherCashbackRate',
        'Max Hoàn tiền / Tháng (VNĐ)': 'maxCashbackPerMonth'
    }

    cards_data = []
    for _, row in df.iterrows():
        card = {}
        for excel_col, firestore_field in mapping.items():
            val = row.get(excel_col)
            # Convert NaN to None
            if pd.isna(val):
                val = None
            # Ensure rates are floats
            if firestore_field.endswith('Rate') or firestore_field == 'maxCashbackPerMonth':
                if val is not None:
                    try:
                        val = float(val)
                    except:
                        val = None
            card[firestore_field] = val
        
        # Add basic info that might be missing in Excel but needed for CreditCard model
        # Note: In a real sync, we should merge this with existing data in Firestore
        cards_data.append(card)

    output_path = 'cards_cashback_update.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(cards_data, f, ensure_ascii=False, indent=2)
    
    print(f"Successfully exported {len(cards_data)} cards to {output_path}")

if __name__ == "__main__":
    export_cashback_to_json()
