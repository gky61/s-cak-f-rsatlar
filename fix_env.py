
import os

env_path = '.env'

try:
    with open(env_path, 'r') as f:
        content = f.read()
    
    if '-3371238729' in content:
        new_content = content.replace('-3371238729', '-1003371238729')
        with open(env_path, 'w') as f:
            f.write(new_content)
        print("✅ .env dosyası güncellendi: ID düzeltildi (-100 eklendi).")
    else:
        if '-1003371238729' in content:
            print("ℹ️ .env dosyası zaten güncel.")
        else:
            print("⚠️ Hedef ID (-3371238729) dosyada bulunamadı.")
            
except Exception as e:
    print(f"❌ Hata: {e}")

