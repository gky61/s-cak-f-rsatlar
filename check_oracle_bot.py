#!/usr/bin/env python3
"""
Oracle Cloud'daki Telegram Bot'unun durumunu kontrol eder
"""

import subprocess
import sys
from datetime import datetime

def check_bot_status(host, user, key_path=None):
    """Oracle Cloud'daki botun durumunu kontrol eder"""
    
    print("🔍 Oracle Cloud'daki bot durumu kontrol ediliyor...\n")
    
    # SSH komutu oluştur
    if key_path:
        ssh_cmd = f"ssh -i {key_path} {user}@{host}"
    else:
        ssh_cmd = f"ssh {user}@{host}"
    
    commands = [
        ("Bot Process Kontrolü", f"{ssh_cmd} 'ps aux | grep telegram_bot | grep -v grep'"),
        ("Son Log Satırları", f"{ssh_cmd} 'tail -20 logs/telegram_bot.log 2>/dev/null || echo Log dosyası bulunamadı'"),
        ("Bot Dizini Kontrolü", f"{ssh_cmd} 'pwd && ls -la telegram_bot.py 2>/dev/null || echo Bot dosyası bulunamadı'"),
        ("Git Durumu", f"{ssh_cmd} 'cd $(dirname $(find . -name telegram_bot.py 2>/dev/null | head -1)) 2>/dev/null && git status 2>/dev/null || echo Git durumu kontrol edilemedi'"),
    ]
    
    results = {}
    
    for name, cmd in commands:
        print(f"📋 {name}...")
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=10
            )
            output = result.stdout.strip()
            error = result.stderr.strip()
            
            if output:
                print(f"✅ {output}\n")
                results[name] = output
            elif error:
                print(f"⚠️ {error}\n")
                results[name] = error
            else:
                print(f"❌ Çıktı yok\n")
                results[name] = "Çıktı yok"
                
        except subprocess.TimeoutExpired:
            print(f"⏱️ Zaman aşımı (10 saniye)\n")
            results[name] = "Zaman aşımı"
        except Exception as e:
            print(f"❌ Hata: {e}\n")
            results[name] = str(e)
    
    # Özet
    print("\n" + "="*50)
    print("📊 ÖZET")
    print("="*50)
    
    if "Bot Process Kontrolü" in results:
        process_output = results["Bot Process Kontrolü"]
        if "telegram_bot" in process_output and "grep" not in process_output:
            print("✅ Bot çalışıyor!")
        else:
            print("❌ Bot çalışmıyor!")
    
    if "Son Log Satırları" in results:
        log_output = results["Son Log Satırları"]
        if "Log dosyası bulunamadı" not in log_output:
            # Son log satırından tarih çıkar
            lines = log_output.split('\n')
            if lines:
                last_line = lines[-1]
                print(f"📝 Son log: {last_line[:100]}...")
    
    return results

if __name__ == "__main__":
    print("="*50)
    print("🤖 Oracle Cloud Bot Durum Kontrolü")
    print("="*50)
    print()
    
    # Kullanıcıdan bilgileri al
    print("Oracle Cloud bağlantı bilgilerini girin:")
    host = input("Host/IP adresi: ").strip()
    user = input("Kullanıcı adı: ").strip()
    key_path = input("SSH key yolu (boş bırakabilirsiniz): ").strip()
    
    if not host or not user:
        print("❌ Host ve kullanıcı adı gereklidir!")
        sys.exit(1)
    
    check_bot_status(host, user, key_path if key_path else None)





