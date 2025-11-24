#!/usr/bin/env python3
"""
Bot kodunu kontrol etme scripti
Termux'ta çalıştırılmalı
"""

import os
import sys

def check_bot_code():
    """Bot kodunu kontrol et"""
    bot_file = 'telegram_bot.py'
    
    if not os.path.exists(bot_file):
        print(f"❌ {bot_file} dosyası bulunamadı!")
        print(f"   Mevcut dizin: {os.getcwd()}")
        return False
    
    print(f"✅ {bot_file} dosyası bulundu\n")
    
    # Dosyayı oku
    with open(bot_file, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')
    
    # Kontroller
    checks = {
        'datetime_import': False,
        'datetime_check': False,
        'timestamp_format': False,
        'firestore_add_call': False,
    }
    
    # 1. datetime import kontrolü
    if 'from datetime import datetime' in content or 'import datetime' in content:
        checks['datetime_import'] = True
        print("✅ datetime import edilmiş")
    else:
        print("❌ datetime import edilmemiş!")
    
    # 2. datetime isinstance kontrolü
    for i, line in enumerate(lines, 1):
        if 'isinstance(value, datetime)' in line:
            checks['datetime_check'] = True
            print(f"✅ datetime kontrolü bulundu (satır {i})")
            # Sonraki 2 satırı göster
            if i < len(lines):
                print(f"   {lines[i-1]}")
                if i < len(lines) - 1:
                    print(f"   {lines[i]}")
                if i < len(lines) - 2:
                    print(f"   {lines[i+1]}")
            break
    
    if not checks['datetime_check']:
        print("❌ datetime kontrolü bulunamadı!")
        print("   Şu satır olmalı: elif isinstance(value, datetime):")
    
    # 3. timestampValue format kontrolü
    if "timestampValue" in content and "isoformat()" in content:
        checks['timestamp_format'] = True
        print("✅ timestampValue formatı doğru")
    else:
        print("❌ timestampValue formatı bulunamadı!")
    
    # 4. firestore_add çağrısı kontrolü
    if 'firebase_rest_api.firestore_add' in content:
        checks['firestore_add_call'] = True
        print("✅ firestore_add çağrısı bulundu")
    else:
        print("❌ firestore_add çağrısı bulunamadı!")
    
    print("\n" + "="*50)
    
    # Özet
    all_ok = all(checks.values())
    if all_ok:
        print("✅ Bot kodu güncel görünüyor!")
        print("\n📝 Sonraki adım: Bot'u yeniden başlat")
        return True
    else:
        print("❌ Bot kodu güncel değil!")
        print("\n📝 Yapılacaklar:")
        print("   1. PC'deki telegram_bot.py dosyasını Termux'a kopyala")
        print("   2. Bu script'i tekrar çalıştır")
        return False

if __name__ == '__main__':
    success = check_bot_code()
    sys.exit(0 if success else 1)


