# ✅ Bot Durum Kontrol Rehberi

## 🔍 Bot Çalışıyor mu?

### Kontrol Komutları:

```bash
# Bot process kontrolü
ps aux | grep "python telegram_bot.py" | grep -v grep

# Log dosyası kontrolü
tail -f logs/telegram_bot.log

# Son çalışma zamanı
ls -lh logs/telegram_bot.log
```

## 📊 Son Deal Kayıtları

```bash
# Son kaydedilen deal'ler
tail -n 500 logs/telegram_bot.log | grep "Deal Firebase'e kaydedildi"

# Detaylı bilgiler
tail -n 500 logs/telegram_bot.log | grep -E "📊 Başlık|💰 Fiyat|🖼️ Görsel|🔗 Link"
```

## 🧪 Test Etmek İçin

1. **Telegram'da yeni bir fırsat paylaşın:**
   - `@indirimkaplani` kanalına veya
   - `-3371238729` grubuna

2. **Botu çalıştırın:**
   ```bash
   source venv/bin/activate
   python telegram_bot.py
   ```

3. **Admin ekranında kontrol edin:**
   - Flutter uygulamasını açın
   - Admin Panel'e gidin
   - "Onay Bekleyenler" sekmesinde yeni deal görünmeli

## 🚀 Botu Sürekli Çalıştırma

### Screen ile:
```bash
screen -S telegram_bot
source venv/bin/activate
python telegram_bot.py
# Ctrl+A, sonra D ile çık
```

### Script ile:
```bash
nohup ./start_bot.sh > logs/bot_loop.log 2>&1 &
```

## ⚠️ Sorun Giderme

### Bot çalışmıyor:
- Virtual environment aktif mi? `source venv/bin/activate`
- Oturum dosyası var mı? `ls -la telegram_session.session`
- Log dosyasına bakın: `tail -f logs/telegram_bot.log`

### Deal'ler görünmüyor:
- Bot çalışıyor mu? `ps aux | grep python`
- Yeni mesaj paylaşıldı mı?
- Firebase'e kaydedildi mi? Logları kontrol edin
- Admin ekranında "Onay Bekleyenler" sekmesine bakın

### Görseller/fiyatlar görünmüyor:
- Logları kontrol edin: `grep -E "Görsel|Fiyat" logs/telegram_bot.log`
- Firebase'de deal verilerini kontrol edin
- Flutter uygulamasını yeniden başlatın





