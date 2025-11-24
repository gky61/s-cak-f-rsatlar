# 🔄 Termux Yeniden Başlatma Rehberi

## 📋 Termux'u Kapattıktan Sonra Yapılacaklar

### ADIM 1: Termux'u Aç
Termux uygulamasını aç.

### ADIM 2: Bot Klasörüne Git
```bash
cd /path/to/bot
# Örnek: cd ~/sicak-firsatlar
# veya: cd /data/data/com.termux/files/home/sicak-firsatlar
```

### ADIM 3: Virtual Environment'ı Aktif Et
```bash
source venv/bin/activate
```

Başarılı olursa prompt'ta `(venv)` görünür:
```
(venv) $ 
```

### ADIM 4: Bot'u Başlat
```bash
python telegram_bot.py
```

**VEYA** script ile:
```bash
./run_telegram_bot.sh
```

### ADIM 5: Bot'un Çalıştığını Kontrol Et
Logları kontrol et:
```bash
# Yeni terminal aç (Ctrl+C ile durdurma, başka terminal aç)
tail -f logs/telegram_bot.log
```

Şu mesajları görmelisin:
- ✅ Telegram Client başlatıldı
- 🔄 Kanallardan mesajlar çekiliyor...
- ✅ Deal Firebase'e kaydedildi: ...

## 🚀 Hızlı Başlatma (Tek Komut)

Eğer `run_telegram_bot.sh` script'in varsa:
```bash
cd /path/to/bot
./run_telegram_bot.sh
```

## 📱 Arka Planda Çalıştırma

Bot'u arka planda çalıştırmak için:
```bash
cd /path/to/bot
source venv/bin/activate
nohup python telegram_bot.py > bot.log 2>&1 &
```

Bot'u durdurmak için:
```bash
pkill -f telegram_bot.py
```

## ⚠️ Sorun Giderme

### Bot başlamıyor
```bash
# Virtual environment aktif mi kontrol et
which python
# /path/to/bot/venv/bin/python görünmeli

# Bağımlılıklar yüklü mü?
pip list | grep telethon
```

### Bot çalışıyor ama mesaj çekmiyor
```bash
# Logları kontrol et
tail -f logs/telegram_bot.log

# Telegram session var mı?
ls -la telegram_session.session
```

### Bot sürekli aynı mesajları çekiyor
```bash
# Bot kodunu kontrol et
python3 check_termux_bot.py

# Firebase'de bot_state var mı kontrol et
# (PC'de debug script çalıştır)
```

## ✅ Başarı Kriterleri

1. ✅ Bot başladı ve log yazıyor
2. ✅ Telegram Client bağlandı
3. ✅ Kanallardan mesajlar çekiliyor
4. ✅ Firebase'e deal'ler kaydediliyor

## 📝 Notlar

- Termux'u kapatınca bot durur
- Tekrar açınca bot'u manuel başlatman gerekir
- Arka planda çalıştırmak için `nohup` kullan
- Otomatik başlatma için `termux-boot` kullanılabilir (ileride)


