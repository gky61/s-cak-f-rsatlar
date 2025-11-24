# -*- coding: utf-8 -*-
import re

def parse_price(price_str):
    if not price_str: return 0.0
    price_str = str(price_str).strip()
    price_str = re.sub(r'(?:₺|TL|lira|TRY)', '', price_str, flags=re.I).strip()
    price_str = re.sub(r'[^\d.,]', '', price_str)
    if not price_str: return 0.0
    
    # Türk formatı: 1.234,56
    if ',' in price_str and '.' in price_str:
        parts = price_str.rsplit(',', 1)
        if len(parts) == 2 and len(parts[1]) <= 2:
            price_str = price_str.replace('.', '').replace(',', '.')
        else:
            price_str = price_str.replace(',', '').replace('.', '')
    elif ',' in price_str:
        parts = price_str.rsplit(',', 1)
        if len(parts) == 2 and len(parts[1]) <= 2:
            price_str = price_str.replace(',', '.')
        else:
            price_str = price_str.replace(',', '')
    elif '.' in price_str:
        parts = price_str.rsplit('.', 1)
        if len(parts) == 2 and len(parts[1]) <= 2:
            pass
        else:
            price_str = price_str.replace('.', '')
            
    try:
        return float(price_str)
    except:
        return 0.0

test_messages = [
    "🔥 Apple iPhone 15 Pro 128GB 64.999 TL!",
    "Samsung Galaxy S24 sadece 39,999.90₺",
    "Sepette ek indirimle 1.250 TL",
    "Fiyat: 1250 TL (Piyasa: 1500)",
    "Ürün 99 TL yerine 49,90 TL",
    "Bedava kargo fırsatıyla 500TL",
    "💥 Şok Fiyat: 12.499,00 TL",
    "₺150 indirim koduyla!", # Bu tuzak, fiyat değil indirim
    "Sadece 9.99₺",
    "Amazon'da 19,900 TL"
]

regex_list = [
    # 1. "Sadece X TL" / "Fiyat: X TL" (Güçlü niyet)
    r'(?:sadece|fiyat|fiyatı|tutar|tutarı)\s*[:\s]\s*(\d+(?:[.,]\d+)*)\s*(?:TL|₺|TRY)',
    
    # 2. "X TL yerine Y TL" (İndirimli fiyatı al, Y)
    r'(?:yerine|düşen)\s*(\d+(?:[.,]\d+)*)\s*(?:TL|₺|TRY)',
    
    # 3. Satır sonundaki fiyat (Genelde başlık + fiyat formatı)
    r'(\d+(?:[.,]\d+)*)\s*(?:TL|₺|TRY)\s*$',
    
    # 4. Genel fiyat (X TL) - En riskli, sona sakla
    r'(\d+(?:[.,]\d+)*)\s*(?:TL|₺|TRY)'
]

print("--- Test Başlıyor ---")
for msg in test_messages:
    found = False
    print(f"\nMesaj: {msg}")
    
    # Önceki mantığı simüle et
    # ...
    
    # Yeni mantık
    for i, pattern in enumerate(regex_list):
        matches = re.findall(pattern, msg, re.I | re.MULTILINE)
        if matches:
            # En son eşleşmeyi al (genelde "yerine" kalıbında sonuncusu indirimli fiyattır)
            # Ama "yerine" regex'i zaten spesifik.
            val = matches[-1] # Birden fazla varsa sonuncusu genelde asıl fiyattır (örn: 100 TL yerine 50 TL)
            price = parse_price(val)
            if price > 0:
                print(f"  ✅ Bulundu (Regex #{i+1}): {price} TL")
                found = True
                break
    
    if not found:
        print("  ❌ Bulunamadı")

