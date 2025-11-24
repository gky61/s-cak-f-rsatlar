# 🤖 Python Telegram Bot Kurulum Rehberi

Bu bot, Telegram kanallarından/gruplarından fırsat paylaşımlarını çeker, görselleri ve fiyatları işler, Firebase'e kaydeder.

## 📋 Gereksinimler

- Python 3.8 veya üzeri
- Firebase service account key (`firebase_key.json`)
- Telegram API ID ve API Hash

## 🚀 Kurulum

### 1. Virtual Environment Oluşturun

```bash
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

### 2. Bağımlılıkları Yükleyin

```bash
pip install -r requirements.txt
```

### 3. Ortam Değişkenlerini Ayarlayın

`.env.example` dosyasını kopyalayın:

```bash
cp .env.example .env
```

`.env` dosyasını düzenleyin:

```env
# Telegram API Bilgileri
TELEGRAM_API_ID=your_api_id_here
TELEGRAM_API_HASH=your_api_hash_here
TELEGRAM_SESSION_NAME=telegram_session

# Telegram Kanalları (virgülle ayrılmış)
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729

# Firebase
FIREBASE_CREDENTIALS_PATH=firebase_key.json
```

### 4. Firebase Service Account Key

Firebase Console'dan service account key indirip `firebase_key.json` olarak kaydedin.

### 5. Telegram API Bilgilerini Alın

1. https://my.telegram.org/apps adresine gidin
2. API ID ve API Hash'i alın
3. `.env` dosyasına ekleyin

## 🎯 Kullanım

### Otomatik Çalıştırma (Script ile)

```bash
./run_telegram_bot.sh
```

### Manuel Çalıştırma

```bash
source venv/bin/activate
python telegram_bot.py
```

## 🔄 İlk Çalıştırma

İlk çalıştırmada Telegram oturumu oluşturulacak:

1. Telefon numaranızı girin (örn: +905551234567)
2. Telegram'dan gelen kodu girin
3. İki faktörlü doğrulama varsa şifrenizi girin

Oturum dosyası (`telegram_session.session`) oluşturulacak ve bir sonraki çalıştırmada otomatik giriş yapılacak.

## 📊 Özellikler

### ✅ Görsel Çekme

- **Öncelik 1:** Telegram media'dan görsel çekme (Firebase Storage'a yükleme)
- **Öncelik 2:** Linkten görsel çekme (7 farklı yöntem)
  - JSON-LD Schema
  - Open Graph
  - Twitter Card
  - Trendyol özel
  - Itemprop image
  - Product image class'ları
  - İlk büyük img tag

### ✅ Fiyat Çekme

- **Öncelik 1:** JSON-LD Schema
- **Öncelik 2:** Meta tags
- **Öncelik 3:** Data attributes
- **Öncelik 4:** Site-özel selector'lar
  - Trendyol: `.prc-dsc`, script tag'leri
  - Hepsiburada: `.price-value`
  - N11: `.newPrice`
- **Öncelik 5:** Genel price class'ları
- **Öncelik 6:** Regex ile HTML'de arama

### ✅ Veri İşleme

- Mesaj parse etme (başlık, fiyat, mağaza, kategori)
- URL çıkarma (mesaj metni, entities, butonlar)
- Blob URL tespiti ve işleme
- Duplicate kontrolü (aynı mesaj tekrar işlenmez)

## 📁 Dosya Yapısı

```
.
├── telegram_bot.py          # Ana bot dosyası
├── requirements.txt         # Python bağımlılıkları
├── .env                     # Ortam değişkenleri (oluşturulmalı)
├── .env.example            # Örnek ortam değişkenleri
├── firebase_key.json       # Firebase service account key (oluşturulmalı)
├── telegram_session.session # Telegram oturum dosyası (otomatik oluşturulur)
├── run_telegram_bot.sh     # Çalıştırma scripti
└── logs/                   # Log dosyaları (otomatik oluşturulur)
    └── telegram_bot.log
```

## 🔄 Scheduled Çalıştırma (Cron)

Her 5 dakikada bir çalıştırmak için:

```bash
crontab -e
```

Şunu ekleyin:

```cron
*/5 * * * * cd /path/to/project && /path/to/venv/bin/python telegram_bot.py >> logs/cron.log 2>&1
```

## 🐛 Sorun Giderme

### "Module not found" hatası

```bash
source venv/bin/activate
pip install -r requirements.txt
```

### ".env file not found" hatası

`.env` dosyasını oluşturun:

```bash
cp .env.example .env
# .env dosyasını düzenleyin
```

### "Firebase key not found" hatası

`firebase_key.json` dosyasını Firebase Console'dan indirip proje klasörüne koyun.

### "Telegram session expired" hatası

`telegram_session.session` dosyasını silin ve botu yeniden çalıştırın.

### Bot çalışmıyor

Log dosyasına bakın:

```bash
tail -50 logs/telegram_bot.log
```

## 📝 Notlar

- Bot, son 20 mesajı işler
- Aynı mesaj tekrar işlenmez (duplicate kontrolü)
- Görseller Firebase Storage'a yüklenir
- Veriler Firestore'a kaydedilir
- Blob URL'ler otomatik tespit edilir ve Telegram media'dan çekilir

## 🔐 Güvenlik

**ÖNEMLİ:** Şu dosyaları Git'e yüklemeyin:

- `.env`
- `firebase_key.json`
- `telegram_session.session`

Bu dosyalar `.gitignore` içinde listelenmiştir.





