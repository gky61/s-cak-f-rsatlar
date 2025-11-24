#!/usr/bin/env python3
"""
Termux bot kodunu kontrol etme scripti
Termux'ta çalıştırılmalı
"""

import os
import sys

def check_termux_bot():
    """Termux bot kodunu kontrol et"""
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
        'get_last_processed_message_id': False,
        'save_last_processed_message_id': False,
        'firestore_update': False,
        'min_id_usage': False,
        'bot_state_collection': False,
    }
    
    # 1. get_last_processed_message_id fonksiyonu
    if 'def get_last_processed_message_id' in content:
        checks['get_last_processed_message_id'] = True
        print("✅ get_last_processed_message_id fonksiyonu var")
    else:
        print("❌ get_last_processed_message_id fonksiyonu bulunamadı!")
    
    # 2. save_last_processed_message_id fonksiyonu
    if 'def save_last_processed_message_id' in content:
        checks['save_last_processed_message_id'] = True
        print("✅ save_last_processed_message_id fonksiyonu var")
    else:
        print("❌ save_last_processed_message_id fonksiyonu bulunamadı!")
    
    # 3. firestore_update fonksiyonu
    if 'def firestore_update' in content:
        checks['firestore_update'] = True
        print("✅ firestore_update fonksiyonu var")
    else:
        print("❌ firestore_update fonksiyonu bulunamadı!")
    
    # 4. min_id kullanımı
    if 'min_id=' in content:
        checks['min_id_usage'] = True
        print("✅ min_id parametresi kullanılıyor")
    else:
        print("❌ min_id parametresi bulunamadı!")
    
    # 5. bot_state koleksiyonu
    if "'bot_state'" in content or '"bot_state"' in content:
        checks['bot_state_collection'] = True
        print("✅ bot_state koleksiyonu kullanılıyor")
    else:
        print("❌ bot_state koleksiyonu bulunamadı!")
    
    print("\n" + "="*50)
    
    # Özet
    all_ok = all(checks.values())
    if all_ok:
        print("✅ Bot kodu güncel görünüyor!")
        print("\n📝 Özellikler:")
        print("   ✅ Son mesaj ID takibi aktif")
        print("   ✅ Sadece yeni mesajlar çekiliyor")
        print("   ✅ Firebase update desteği var")
        print("\n🚀 Bot'u çalıştırabilirsin!")
        return True
    else:
        print("❌ Bot kodu güncel değil!")
        print("\n📝 Eksik özellikler:")
        for check, status in checks.items():
            if not status:
                print(f"   ❌ {check}")
        print("\n📝 Yapılacaklar:")
        print("   1. PC'deki telegram_bot.py dosyasını Termux'a kopyala")
        print("   2. Bu script'i tekrar çalıştır")
        return False

if __name__ == '__main__':
    success = check_termux_bot()
    sys.exit(0 if success else 1)


