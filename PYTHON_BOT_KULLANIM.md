# 🐍 Python Telegram Bot Kullanım Rehberi

## 🚀 Botu Çalıştırma

### İlk Çalıştırma (Telegram Oturumu Oluşturma)

Terminal'de şu komutu çalıştırın:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
source venv/bin/activate
python telegram_bot.py
```

**İlk çalıştırmada şunlar istenecek:**

1. **Telefon Numarası:** 
   - Format: `+905551234567` (ülke kodu ile birlikte)
   - Örnek: `+905464751819`

2. **Telegram Kodu:**
   - Telegram uygulamanıza gelen 5 haneli kodu girin
   - Örnek: `12345`

3. **İki Faktörlü Doğrulama (Varsa):**
   - Eğer Telegram hesabınızda 2FA aktifse, şifrenizi girin

**✅ Başarılı giriş sonrası:**
- `telegram_session.session` dosyası oluşturulacak
- Bir sonraki çalıştırmada otomatik giriş yapılacak

### Sonraki Çalıştırmalar

Oturum dosyası oluşturulduktan sonra, bot otomatik olarak giriş yapacak:

```bash
source venv/bin/activate
python telegram_bot.py
```

veya script ile:

```bash
./run_telegram_bot.sh
```

## 📋 Bot Ne Yapar?

1. **Telegram Kanallarından Mesajları Çeker:**
   - `@indirimkaplani`
   - `-3371238729` (grup ID)

2. **Her Mesaj İçin:**
   - ✅ Başlık, fiyat, mağaza, kategori, link çıkarır
   - ✅ Görseli Telegram media'dan veya linkten çeker
   - ✅ Fiyatı linkten çeker (Trendyol, Hepsiburada, N11 özel)
   - ✅ Firebase Storage'a görsel yükler
   - ✅ Firebase Firestore'a deal kaydeder

3. **Duplicate Kontrolü:**
   - Aynı mesaj daha önce işlenmişse atlar

4. **Loglama:**
   - Tüm işlemler `logs/telegram_bot.log` dosyasına kaydedilir
   - Konsola da anlık loglar yazdırılır

## 🔍 Logları İzleme

### Canlı Log İzleme:

```bash
tail -f logs/telegram_bot.log
```

### Son 50 Satır:

```bash
tail -n 50 logs/telegram_bot.log
```

## ⚙️ Yapılandırma

### `.env` Dosyası:

```env
TELEGRAM_API_ID=37462587
TELEGRAM_API_HASH=35c8bc7cd010dd61eb5a123e2722be41
TELEGRAM_SESSION_NAME=telegram_session
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729
FIREBASE_CREDENTIALS_PATH=firebase_key.json
```

### Kanal/Grup Ekleme:

`.env` dosyasındaki `TELEGRAM_CHANNELS` değerini düzenleyin:

```env
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729,@yeni_kanal
```

**Format:**
- Kanal: `@kanal_adi`
- Grup: `-1234567890` (negatif ID)

## 🛠️ Sorun Giderme

### "Session file not found" Hatası:

Oturum dosyası silinmişse, botu tekrar çalıştırın ve telefon numarası/kod girin.

### "Phone number invalid" Hatası:

Telefon numaranızı `+905551234567` formatında girin (ülke kodu ile).

### "Code expired" Hatası:

Telegram kodları 5 dakika geçerlidir. Yeni bir kod isteyin.

### "Storage bucket not found" Hatası:

Firebase Storage'ın aktif olduğundan emin olun:
- Firebase Console > Storage > Get Started

### "Permission denied" Hatası:

Firebase key dosyasının (`firebase_key.json`) doğru izinlere sahip olduğundan emin olun.

## 📊 Bot Çıktısı Örneği

```
2025-11-16 18:30:49 - __main__ - INFO - ✅ Firebase başlatıldı
2025-11-16 18:30:50 - __main__ - INFO - ✅ Telegram Client başlatıldı
2025-11-16 18:30:51 - __main__ - INFO - 🔄 Kanallardan mesajlar çekiliyor...
2025-11-16 18:30:52 - __main__ - INFO - 📨 Mesaj 12345 işleniyor...
2025-11-16 18:30:53 - __main__ - INFO - 📷 Telegram media'dan görsel çekiliyor...
2025-11-16 18:30:55 - __main__ - INFO - ✅ Telegram media'dan görsel başarıyla çekildi
2025-11-16 18:30:56 - __main__ - INFO - 💰 Linkten fiyat çekiliyor...
2025-11-16 18:30:58 - __main__ - INFO - ✅ Fiyat bulundu: 1299.99 TL
2025-11-16 18:30:59 - __main__ - INFO - ✅ Deal Firebase'e kaydedildi: abc123xyz
```

## 🔄 Otomatik Çalıştırma (Opsiyonel)

### Cron Job ile Periyodik Çalıştırma:

```bash
crontab -e
```

Her 5 dakikada bir çalıştırmak için:

```cron
*/5 * * * * cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR" && source venv/bin/activate && python telegram_bot.py >> logs/cron.log 2>&1
```

## 📝 Notlar

- Bot çalışırken terminal penceresini kapatmayın
- İlk çalıştırmada oturum oluşturulması 1-2 dakika sürebilir
- Her mesaj işleme işlemi 5-10 saniye sürebilir (görsel/fiyat çekme)
- Bot, Firebase Functions'daki `fetchChannelMessages` ile aynı işlevi görür
- Python bot, Node.js Firebase Function'a alternatif olarak kullanılabilir





