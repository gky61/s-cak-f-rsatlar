# 🚀 Oracle Bot Kontrol ve Yönetim

## ✅ Bot Durumu

Bot Oracle sunucuda çalışıyor:
- **IP:** `89.168.102.145`
- **Kullanıcı:** `ubuntu`
- **Klasör:** `~/sicak-firsatlar`

## 📋 Hızlı Komutlar

### Bot'un Çalışıp Çalışmadığını Kontrol Et
```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "ps aux | grep telegram_bot.py | grep -v grep"
```

### Logları Görüntüle
```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "cd ~/sicak-firsatlar && tail -f bot.log"
```

### Bot'u Yeniden Başlat
```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "cd ~/sicak-firsatlar && pkill -f telegram_bot.py && sleep 2 && source venv/bin/activate && nohup python telegram_bot.py > bot.log 2>&1 &"
```

### Bot'u Durdur
```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "pkill -f telegram_bot.py"
```

### Bot Kodunu Güncelle
```bash
# Mac'ten sunucuya gönder
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
scp -i ~/Downloads/ssh-key-2025-11-20.key telegram_bot.py ubuntu@89.168.102.145:~/sicak-firsatlar/

# Sunucuda yeniden başlat
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "cd ~/sicak-firsatlar && pkill -f telegram_bot.py && sleep 2 && source venv/bin/activate && nohup python telegram_bot.py > bot.log 2>&1 &"
```

## 🔄 Bot Çalışma Mantığı

1. **Her 5 dakikada bir çalışır** (300 saniye)
2. **Her kanal için:**
   - Son 3 mesajı çeker (ilk çalıştırmada 5)
   - Son mesaj ID'sinden büyük olanları filtreler
   - Her mesaj için duplicate kontrolü yapar
   - Yeni mesajları işler ve Firebase'e kaydeder
   - En büyük mesaj ID'sini kaydeder

## 📊 Bot Özellikleri

- ✅ Sadece yeni mesajları çekiyor
- ✅ Duplicate kontrolü yapıyor (aynı mesaj 2 kez kaydedilmiyor)
- ✅ Son 3 mesaja bakıyor (hızlı ve verimli)
- ✅ Firebase'e kaydediyor (`isApproved: false`)
- ✅ 7/24 arka planda çalışıyor

## ⚠️ Önemli Notlar

1. **Sunucu yeniden başlatılırsa:** Bot otomatik başlamaz, manuel başlatman gerekir
2. **Bot kodunu güncellemek için:** Mac'ten `scp` ile gönder, sonra yeniden başlat
3. **Logları kontrol et:** Sorun olursa logları kontrol et

## 🎯 Sonraki Adımlar

Bot artık Oracle'da çalışıyor. Flutter uygulamanın admin sayfasından bot'un çektiği deal'leri görebilirsin!


