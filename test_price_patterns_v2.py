# -*- coding: utf-8 -*-
import re

def parse_price(price_str):
    if not price_str: return 0.0
    # Temizlik
    price_str = str(price_str).strip()
    # Sayı ve noktalama dışındakileri at
    price_str = re.sub(r'[^\d.,]', '', price_str)
    if not price_str: return 0.0
    
    # Noktalama analizi
    # 1.234,56 -> TR
    # 1,234.56 -> US
    # 1.234 -> TR (binlik)
    # 1234 -> Düz
    
    if ',' in price_str and '.' in price_str:
        last_comma = price_str.rfind(',')
        last_dot = price_str.rfind('.')
        if last_comma > last_dot: # 1.234,56
            price_str = price_str.replace('.', '').replace(',', '.')
        else: # 1,234.56
            price_str = price_str.replace(',', '')
    elif ',' in price_str:
        # 12,50 veya 12,500
        parts = price_str.rsplit(',', 1)
        if len(parts[1]) == 2: # Kuruş (12,50)
            price_str = price_str.replace(',', '.')
        elif len(parts[1]) == 3: # Binlik (12,500 -> 12500) - Riskli ama genelde binliktir
            price_str = price_str.replace(',', '')
        else: # 12,5 -> 12.5
            price_str = price_str.replace(',', '.')
    elif '.' in price_str:
        # 12.50 veya 12.500
        parts = price_str.rsplit('.', 1)
        if len(parts[1]) == 2: # Kuruş (12.50) - TR'de nadir ama olur
            pass # zaten float formatı
        elif len(parts[1]) == 3: # Binlik (1.500)
            price_str = price_str.replace('.', '')
    
    try:
        return float(price_str)
    except:
        return 0.0

test_messages = [
    ("🔥 Apple iPhone 15 Pro 128GB 64.999 TL!", 64999.0),
    ("Samsung Galaxy S24 sadece 39,999.90₺", 39999.90),
    ("Sepette ek indirimle 1.250 TL", 1250.0),
    ("Fiyat: 1250 TL (Piyasa: 1500)", 1250.0),
    ("Ürün 99 TL yerine 49,90 TL", 49.90),
    ("Bedava kargo fırsatıyla 500TL", 500.0),
    ("💥 Şok Fiyat: 12.499,00 TL", 12499.0),
    ("₺150 indirim koduyla!", 0.0), 
    ("Sadece 9.99₺", 9.99),
    ("Amazon'da 19,900 TL", 19900.0),
    ("1.500 TL", 1500.0),
    ("1,500 TL", 1500.0),
    ("1500,00 TL", 1500.0)
]

regex_list = [
    # 1. Öncelik: "yerine" kalıbı (indirimli fiyatı yakalar)
    r'(?:yerine|düşen)\s*(\d+(?:[.,]\d+)*)\s*(?:TL|₺|TRY)',
    
    # 2. Öncelik: "sadece/fiyat" gibi belirteçler
    r'(?:sadece|fiyatı|fiyat|tutar|tutarı)[:\s]+\s*(\d+(?:[.,]\d+)*)\s*(?:TL|₺|TRY)',
    
    # 3. Öncelik: Satır sonundaki fiyat (Başlık + Fiyat)
    r'(\d+(?:[.,]\d+)*)\s*(?:TL|₺|TRY)[!.]*\s*$',
    
    # 4. Öncelik: Genel fiyat (en son eşleşmeyi al)
    r'(\d+(?:[.,]\d+)*)\s*(?:TL|₺|TRY)'
]

print("--- Test V2 Başlıyor ---")
for msg, expected in test_messages:
    found_price = 0.0
    found_via = ""
    
    for i, pattern in enumerate(regex_list):
        matches = re.findall(pattern, msg, re.I | re.MULTILINE)
        if matches:
            # Regex grubuna göre işlem
            raw_val = matches[-1] # Sonuncuyu al
            p = parse_price(raw_val)
            if p > 0:
                # Mantık kontrolü: Çok küçük veya çok büyük fiyatları ele (örn. tarih)
                if 5 <= p <= 1000000:
                    found_price = p
                    found_via = f"Regex #{i+1}"
                    break # Bulduğumuz an çıkıyoruz (öncelik sırası)
    
    status = "✅" if abs(found_price - expected) < 0.1 else "❌"
    if expected == 0 and found_price == 0: status = "✅"
    
    print(f"{status} Hedef: {expected:<10} Bulunan: {found_price:<10} ({found_via}) | Msg: {msg[:30]}...")

