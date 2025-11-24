import os

def update_file():
    # Yeni fonksiyonu oku
    with open('temp_extract_func.py', 'r') as f:
        new_func_code = f.read()

    # Orijinal dosyayı oku
    with open('telegram_bot.py', 'r') as f:
        lines = f.readlines()

    # İlk kısım: satır 0'dan 685'e kadar (index 685 dahil değil, yani 0-684)
    # Ancak editörde satır 1 -> index 0.
    # 686. satır (index 685) 'def extract_price_from_html...' ile başlıyor.
    # Oraya kadar al.
    part1 = lines[:685]

    # İkinci kısım: 947. satır (index 946) '    async def analyze_deal_with_ai' ile başlıyor.
    # 946. satır boşluk olabilir.
    # 947. satırdan sonrasını al.
    part2 = lines[946:]

    # Birleştir
    new_content = "".join(part1) + "\n" + new_func_code + "\n" + "".join(part2)

    # process_message içindeki çağrıyı da güncelle
    # Eski: price_from_link = self.extract_price_from_html(link_data['html'], final_url)
    #       parsed_deal['price'] = price_from_link
    
    # Yeni: html_data = self.extract_html_data(link_data['html'], final_url)
    #       parsed_deal['price'] = html_data.get('price', 0.0)
    #       parsed_deal['originalPrice'] = html_data.get('original_price', 0.0)

    # Bu replacement'ı regex veya string replace ile yapalım.
    # Ancak indentation önemli.
    
    target_str = "                    price_from_link = self.extract_price_from_html(link_data['html'], final_url)\n                    parsed_deal['price'] = price_from_link"
    
    replacement_str = """                    html_data = self.extract_html_data(link_data['html'], final_url)
                    parsed_deal['price'] = html_data.get('price', 0.0)
                    parsed_deal['originalPrice'] = html_data.get('original_price', 0.0)"""

    # Boşluklar tam tutmayabilir, daha gevşek bir replace yapalım.
    # Dosya içinde arayıp bulalım.
    
    if target_str in new_content:
        print("Target string found directly.")
        new_content = new_content.replace(target_str, replacement_str)
    else:
        print("Target string not found directly, trying line by line scan.")
        # Line by line scan for the call
        updated_lines = new_content.splitlines()
        final_lines = []
        skip_next = False
        for i, line in enumerate(updated_lines):
            if skip_next:
                skip_next = False
                continue
                
            if "self.extract_price_from_html(link_data['html'], final_url)" in line:
                indent = line[:line.find("price_from_link")] # indentation yakala diyeceğim ama değişken adı başta olmayabilir
                # Basitçe replace edelim
                # Muhtemelen şöyle:
                # price_from_link = self.extract_price_from_html(link_data['html'], final_url)
                
                # Indentation'ı satır başından al
                indent = line.split('price_from_link')[0]
                
                final_lines.append(f"{indent}html_data = self.extract_html_data(link_data['html'], final_url)")
                final_lines.append(f"{indent}parsed_deal['price'] = html_data.get('price', 0.0)")
                final_lines.append(f"{indent}parsed_deal['originalPrice'] = html_data.get('original_price', 0.0)")
                
                # Bir sonraki satır muhtemelen "parsed_deal['price'] = price_from_link"
                # Onu atla
                if i+1 < len(updated_lines) and "parsed_deal['price'] = price_from_link" in updated_lines[i+1]:
                    skip_next = True
            else:
                final_lines.append(line)
        
        new_content = "\n".join(final_lines)

    with open('telegram_bot.py', 'w') as f:
        f.write(new_content)

    print("telegram_bot.py updated successfully.")

if __name__ == "__main__":
    update_file()


