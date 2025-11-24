# 🐍 Python Bot'u Sürekli Çalıştırma Rehberi

Firebase Function durduruldu, şimdi Python bot'u sürekli çalıştırmalısınız.

## 🚀 Seçenek 1: Screen ile (Önerilen)

Screen, terminal oturumunu arka planda çalıştırmanızı sağlar.

### Adımlar:

1. **Screen oturumu başlat:**
```bash
screen -S telegram_bot
```

2. **Bot'u çalıştır:**
```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
source venv/bin/activate
python telegram_bot.py
```

3. **Screen'den çık (bot çalışmaya devam eder):**
   - `Ctrl+A` tuşlarına basın
   - Sonra `D` tuşuna basın (Detach)

4. **Tekrar girmek için:**
```bash
screen -r telegram_bot
```

5. **Bot'u durdurmak için:**
   - Screen'e girin: `screen -r telegram_bot`
   - `Ctrl+C` ile bot'u durdurun
   - `exit` ile screen'den çıkın

## 🔄 Seçenek 2: While Loop Script ile

Hazır script'i kullanarak:

1. **Arka planda başlat:**
```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
nohup ./start_bot.sh > logs/bot_loop.log 2>&1 &
```

2. **Çalışıp çalışmadığını kontrol:**
```bash
ps aux | grep "python telegram_bot.py"
tail -f logs/bot_loop.log
```

3. **Durdurmak için:**
```bash
pkill -f "python telegram_bot.py"
```

## ⏰ Seçenek 3: Cron Job ile (Her 5 Dakikada Bir)

1. **Crontab düzenle:**
```bash
crontab -e
```

2. **Şu satırı ekle:**
```cron
*/5 * * * * cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR" && source venv/bin/activate && python telegram_bot.py >> logs/cron.log 2>&1
```

3. **Cron job'ları kontrol:**
```bash
crontab -l
```

4. **Cron loglarını kontrol:**
```bash
tail -f logs/cron.log
```

## 📊 Logları İzleme

### Bot logları:
```bash
tail -f logs/telegram_bot.log
```

### Son 50 satır:
```bash
tail -n 50 logs/telegram_bot.log
```

### Hata arama:
```bash
grep -i error logs/telegram_bot.log | tail -n 20
```

## ✅ Kontrol Komutları

### Bot çalışıyor mu?
```bash
ps aux | grep "python telegram_bot.py" | grep -v grep
```

### Son çalışma zamanı:
```bash
ls -lh logs/telegram_bot.log
```

### Son deal kaydı:
```bash
tail -n 100 logs/telegram_bot.log | grep "Deal Firebase'e kaydedildi"
```

## 🛑 Bot'u Durdurma

### Screen ile başlattıysanız:
```bash
screen -r telegram_bot
# Ctrl+C ile durdur
```

### Script ile başlattıysanız:
```bash
pkill -f "python telegram_bot.py"
```

### Cron job ile başlattıysanız:
```bash
crontab -e
# İlgili satırı sil veya yorum satırı yap
```

## 💡 Öneri

**Screen yöntemi en pratik ve kontrol edilebilir yöntemdir.** 

- Bot'u görebilirsiniz
- Logları canlı izleyebilirsiniz
- Kolayca durdurabilirsiniz
- Bilgisayar kapanırsa bot durur (güvenlik)

## 🔄 Otomatik Yeniden Başlatma

Eğer bot hata verirse otomatik yeniden başlatmak için `start_bot.sh` script'ini kullanın. Bu script bot durduğunda 5 dakika bekleyip tekrar başlatır.





