# ✅ Oracle Sunucuda Bot Kurulumu Tamamlandı!

## 🎉 Başarıyla Tamamlandı

Bot Oracle Cloud sunucusunda başarıyla kuruldu ve çalışıyor!

## 📋 Sunucu Bilgileri

- **IP Adresi:** `89.168.102.145`
- **Kullanıcı:** `ubuntu`
- **SSH Key:** `~/Downloads/ssh-key-2025-11-20.key`
- **Proje Klasörü:** `~/sicak-firsatlar`
- **Hostname:** `frsat-bot`

## 🚀 Bot Durumu

✅ Bot çalışıyor ve arka planda sürekli çalışmaya devam ediyor.

## 📝 Yapılan İşlemler

1. ✅ SSH ile sunucuya bağlanıldı
2. ✅ Python ve gerekli paketler kuruldu
3. ✅ Virtual environment oluşturuldu
4. ✅ Bot dosyaları sunucuya kopyalandı:
   - `telegram_bot.py`
   - `requirements.txt`
   - `.env`
   - `firebase_key.json`
   - `telegram_session.session`
5. ✅ Bağımlılıklar yüklendi
6. ✅ Bot başlatıldı ve çalışıyor

## 🔍 Bot Kontrol Komutları

### Bot'un çalışıp çalışmadığını kontrol et:
```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "ps aux | grep telegram_bot.py | grep -v grep"
```

### Logları görüntüle:
```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "cd ~/sicak-firsatlar && tail -f bot.log"
```

### Bot'u durdur:
```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "pkill -f telegram_bot.py"
```

### Bot'u yeniden başlat:
```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 "cd ~/sicak-firsatlar && source venv/bin/activate && nohup python telegram_bot.py > bot.log 2>&1 &"
```

## 📊 Bot Özellikleri

- ✅ Sadece yeni mesajları çekiyor (son mesaj ID takibi)
- ✅ Firebase'e deal'leri kaydediyor
- ✅ Görselleri Firebase Storage'a yüklüyor
- ✅ 7/24 arka planda çalışıyor

## ⚠️ Önemli Notlar

1. **Sunucu yeniden başlatılırsa:** Bot otomatik başlamaz, manuel başlatman gerekir
2. **Bot kodunu güncellemek için:** Mac'ten `scp` ile dosyaları gönder, sonra botu yeniden başlat
3. **Logları kontrol et:** Sorun olursa logları kontrol et

## 🎯 Sonraki Adımlar

Bot artık Oracle sunucuda çalışıyor. Flutter uygulaman admin sayfasından bot'un çektiği deal'leri görebilirsin!


