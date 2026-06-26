# 🚀 Oracle Bot Detaylı Çalışma Rehberi

## 📋 İçindekiler

1. [Bot Nasıl Çalışır?](#bot-nasıl-çalışır)
2. [Kanal Dinleme Mekanizması](#kanal-dinleme-mekanizması)
3. [Kanal Ekleme İşlemi](#kanal-ekleme-işlemi)
4. [Bot Kontrol Komutları](#bot-kontrol-komutları)
5. [Sorun Giderme](#sorun-giderme)

---

## 🤖 Bot Nasıl Çalışır?

### Genel Bakış

Oracle sunucuda çalışan bot, Telegram kanallarını dinleyerek fırsat mesajlarını otomatik olarak yakalar, analiz eder ve Firebase'e kaydeder.

### Çalışma Akışı

```
1. Bot Başlatma
   ↓
2. Telegram Client Bağlantısı
   ↓
3. Kanal Listesi Okuma (.env dosyasından)
   ↓
4. Event Handler Kurulumu (NewMessage)
   ↓
5. Sürekli Dinleme (7/24)
   ↓
6. Yeni Mesaj Geldiğinde:
   ├─ Link kontrolü
   ├─ Kanal ID/Username kontrolü
   ├─ Rate limiting kontrolü
   ├─ Mesaj işleme
   │  ├─ Görsel indirme (varsa)
   │  ├─ HTML scraping (görsel için)
   │  ├─ AI analizi (Gemini)
   │  └─ Veri çıkarma
   └─ Firebase'e kaydetme
```

### Teknik Detaylar

#### 1. **Telethon Kütüphanesi**
Bot, Telegram'ın resmi API'si yerine **Telethon** kütüphanesini kullanır. Bu sayede:
- Kullanıcı hesabıyla bağlanır (bot token gerekmez)
- Tüm kanalları dinleyebilir (yönetici olması gerekmez)
- Gerçek zamanlı mesaj dinleme yapabilir

#### 2. **Session Dosyası**
Bot, Telegram oturumunu `telegram_session.session` dosyasında saklar:
- İlk çalıştırmada telefon numarası ve kod ister
- Sonraki çalıştırmalarda otomatik giriş yapar
- Bu dosya sunucuda `~/sicak-firsatlar/` klasöründe bulunur

#### 3. **Event-Driven Mimari**
Bot, Telethon'un `events.NewMessage()` event handler'ını kullanır:
- Her yeni mesaj geldiğinde otomatik tetiklenir
- Asenkron (async) çalışır, diğer mesajları bekletmez
- Rate limiting ile Telegram'ın spam algılamasından kaçınır

---

## 📡 Kanal Dinleme Mekanizması

### Kanal Tanımlama Yöntemleri

Bot, kanalları 3 farklı yöntemle tanıyabilir:

#### 1. **Kanal ID (Pozitif)**
```
TELEGRAM_CHANNELS=123456789
```
- Kanalın sayısal ID'si
- Genelde özel kanallar için kullanılır

#### 2. **Kanal ID (Negatif)**
```
TELEGRAM_CHANNELS=-123456789
```
- Grup kanalları için negatif ID
- Çoğu durumda bu format kullanılır

#### 3. **Kanal Username**
```
TELEGRAM_CHANNELS=@indirimkaplani
```
- Kanalın @ ile başlayan kullanıcı adı
- En kolay ve okunabilir yöntem

### Kanal Filtreleme Mantığı

Bot, her mesaj geldiğinde şu kontrolleri yapar:

```python
# 1. Chat ID kontrolü (pozitif ve negatif)
if chat_id_str in channels or chat_id_neg in channels:
    is_target = True

# 2. Username kontrolü (@ ile ve @ olmadan)
if "@" + username in channels or username in channels:
    is_target = True

# 3. Sadece hedef kanallardan gelen mesajlar işlenir
if is_target:
    process_message()
```

### Çoklu Kanal Desteği

Birden fazla kanal eklemek için virgülle ayırın:

```bash
TELEGRAM_CHANNELS=@indirimkaplani,@firsatkanali,-123456789
```

### Mesaj Filtreleme

Bot, sadece **link içeren mesajları** işler:
- Link yoksa mesaj atlanır
- HTTP/HTTPS linkleri desteklenir
- İlk bulunan link kullanılır

### Rate Limiting

Bot, Telegram'ın spam algılamasından kaçınmak için:
- Aynı kanaldan gelen mesajlar arasında minimum 3 saniye bekler
- Rastgele 1-3 saniye arası gecikme ekler
- Her kanal için son mesaj zamanını takip eder

---

## ➕ Kanal Ekleme İşlemi

### Yöntem 1: Manuel Ekleme (SSH ile)

#### Adım 1: Oracle Sunucuya Bağlan

```bash
# SSH key dosyasını hazırla
chmod 400 ~/Downloads/ssh-key-2025-11-20.key

# Sunucuya bağlan
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145
```

**Not:** IP adresini ve kullanıcı adını kendi bilgilerinizle değiştirin.

#### Adım 2: Bot Dizinine Git

```bash
cd ~/sicak-firsatlar
# veya
cd ~/sicak_firsatlar_bot
```

#### Adım 3: .env Dosyasını Düzenle

```bash
nano .env
```

#### Adım 4: Kanal Ekle

`.env` dosyasında `TELEGRAM_CHANNELS` veya `SOURCE_CHANNELS` satırını bulun:

**Mevcut kanal varsa:**
```bash
TELEGRAM_CHANNELS=@mevcut_kanal,@yeni_kanal
```

**Kanal yoksa yeni satır ekleyin:**
```bash
TELEGRAM_CHANNELS=@yeni_kanal
```

**Kaydet:** `Ctrl+O`, `Enter`, `Ctrl+X`

#### Adım 5: Botu Yeniden Başlat

```bash
# Bot'u durdur
pkill -f telegram_bot.py

# Virtual environment'ı aktif et
source venv/bin/activate

# Bot'u başlat
nohup python telegram_bot.py > logs/bot.log 2>&1 &
```

#### Adım 6: Kontrol Et

```bash
# Bot çalışıyor mu?
ps aux | grep telegram_bot.py

# Logları izle
tail -f logs/bot.log
```

Loglarda şunu görmelisiniz:
```
📡 Dinlenen Kanallar: ['@mevcut_kanal', '@yeni_kanal']
```

### Yöntem 2: Otomatik Script ile Ekleme

Proje klasöründe `add_telegram_channel.sh` script'i var:

```bash
# Mac Terminal'inde
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"

# Script'i çalıştır
./add_telegram_channel.sh @yeni_kanal
```

Script otomatik olarak:
1. Sunucuya bağlanır
2. Mevcut kanalları okur
3. Yeni kanalı ekler
4. Botu yeniden başlatır

### Kanal ID'sini Bulma

Eğer kanalın username'i yoksa, ID'sini bulmanız gerekir:

#### Yöntem 1: Bot Loglarından

1. Botu çalıştırın
2. Kanalda bir mesaj gönderin
3. Logları kontrol edin:

```bash
tail -f logs/bot.log
```

Loglarda şunu göreceksiniz:
```
📩 MESAJ ALINDI: [Kanal ID: -123456789] - ...
🔍 Kanal kontrolü: ID=-123456789 | Username=@kanal | Title=Kanal Adı
```

#### Yöntem 2: Telegram Web'den

1. Telegram Web'e git: https://web.telegram.org
2. Kanalı aç
3. URL'deki ID'yi kopyala (geliştirici araçlarından)

### Kanal Ekleme Örnekleri

#### Örnek 1: Username ile
```bash
TELEGRAM_CHANNELS=@indirimkaplani
```

#### Örnek 2: ID ile
```bash
TELEGRAM_CHANNELS=-123456789
```

#### Örnek 3: Çoklu Kanal
```bash
TELEGRAM_CHANNELS=@indirimkaplani,@firsatkanali,-123456789
```

#### Örnek 4: Karışık Format
```bash
TELEGRAM_CHANNELS=@kanal1,-123456789,@kanal2,987654321
```

---

## 🔍 Bot Kontrol Komutları

### Bot Durumu Kontrol

```bash
# Bot çalışıyor mu?
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "ps aux | grep telegram_bot.py | grep -v grep"
```

### Logları Görüntüle

```bash
# Son 50 satır
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd ~/sicak-firsatlar && tail -50 logs/bot.log"

# Canlı log takibi
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd ~/sicak-firsatlar && tail -f logs/bot.log"
```

### Botu Durdur

```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "pkill -f telegram_bot.py"
```

### Botu Başlat

```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd ~/sicak-firsatlar && source venv/bin/activate && \
   nohup python telegram_bot.py > logs/bot.log 2>&1 &"
```

### Botu Yeniden Başlat

```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd ~/sicak-firsatlar && pkill -f telegram_bot.py && sleep 2 && \
   source venv/bin/activate && \
   nohup python telegram_bot.py > logs/bot.log 2>&1 &"
```

### Mevcut Kanalları Görüntüle

```bash
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd ~/sicak-firsatlar && cat .env | grep -E 'TELEGRAM_CHANNELS|SOURCE_CHANNELS'"
```

### Bot Kodunu Güncelle

```bash
# Mac Terminal'inde
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"

# Dosyayı gönder
scp -i ~/Downloads/ssh-key-2025-11-20.key telegram_bot.py \
  ubuntu@89.168.102.145:~/sicak-firsatlar/

# Botu yeniden başlat
ssh -i ~/Downloads/ssh-key-2025-11-20.key ubuntu@89.168.102.145 \
  "cd ~/sicak-firsatlar && pkill -f telegram_bot.py && sleep 2 && \
   source venv/bin/activate && \
   nohup python telegram_bot.py > logs/bot.log 2>&1 &"
```

---

## 🔧 Sorun Giderme

### Problem 1: Bot Kanalları Dinlemiyor

**Kontrol Listesi:**
1. ✅ `.env` dosyasında `TELEGRAM_CHANNELS` var mı?
2. ✅ Kanal formatı doğru mu? (ID veya @username)
3. ✅ Bot çalışıyor mu? (`ps aux | grep telegram_bot.py`)
4. ✅ Loglarda hata var mı? (`tail -f logs/bot.log`)

**Çözüm:**
```bash
# Logları kontrol et
tail -f logs/bot.log

# Kanal listesini kontrol et
cat .env | grep TELEGRAM_CHANNELS

# Botu yeniden başlat
pkill -f telegram_bot.py
source venv/bin/activate
nohup python telegram_bot.py > logs/bot.log 2>&1 &
```

### Problem 2: Mesajlar İşlenmiyor

**Olası Nedenler:**
- Mesajda link yok (bot sadece link içeren mesajları işler)
- Kanal ID/username yanlış
- Rate limiting aktif (çok hızlı mesaj geliyor)

**Çözüm:**
```bash
# Logları kontrol et - hangi mesajlar atlanıyor?
tail -f logs/bot.log | grep -E "MESAJ|Link|Hedef kanal"

# Kanal ID'sini doğrula
# Loglarda "📩 MESAJ ALINDI: [Kanal ID: ...]" satırını bul
```

### Problem 3: Session Dosyası Hatası

**Hata:**
```
❌ Session dosyası bulunamadı veya geçersiz
```

**Çözüm:**
```bash
# Session dosyasını sil ve yeniden oluştur
rm telegram_session.session

# Botu başlat (telefon numarası ve kod isteyecek)
python telegram_bot.py
```

### Problem 4: Firebase Bağlantı Hatası

**Hata:**
```
❌ Firebase bağlantısı kurulamadı
```

**Çözüm:**
```bash
# Firebase key dosyasını kontrol et
ls -la firebase_key.json

# Dosya yoksa Mac'ten gönder
scp -i ~/Downloads/ssh-key-2025-11-20.key firebase_key.json \
  ubuntu@89.168.102.145:~/sicak-firsatlar/
```

### Problem 5: Bot Sürekli Düşüyor

**Çözüm:**
```bash
# Systemd service oluştur (otomatik başlatma için)
sudo nano /etc/systemd/system/telegram-bot.service
```

Service dosyası içeriği:
```ini
[Unit]
Description=Telegram Deal Bot
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/sicak-firsatlar
Environment="PATH=/home/ubuntu/sicak-firsatlar/venv/bin"
ExecStart=/home/ubuntu/sicak-firsatlar/venv/bin/python telegram_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Service'i aktif et:
```bash
sudo systemctl enable telegram-bot
sudo systemctl start telegram-bot
sudo systemctl status telegram-bot
```

---

## 📊 Bot İşlem Akışı Detayı

### Mesaj İşleme Süreci

```
1. Yeni Mesaj Geldi
   ↓
2. Link Kontrolü
   ├─ Link yok → Atlanır
   └─ Link var → Devam
   ↓
3. Kanal Kontrolü
   ├─ ID kontrolü (pozitif/negatif)
   ├─ Username kontrolü (@ ile/@ olmadan)
   └─ Hedef kanal değilse → Atlanır
   ↓
4. Rate Limiting
   ├─ Son mesajdan 3 saniye geçti mi?
   └─ Bekle (1-3 saniye rastgele)
   ↓
5. Görsel İndirme
   ├─ Telegram'dan fotoğraf var mı?
   ├─ Varsa → imgbb'ye yükle
   └─ Yoksa → HTML scraping (opsiyonel)
   ↓
6. AI Analizi (Gemini)
   ├─ Görsel varsa → OCR ile fiyat okuma
   ├─ Metin analizi
   ├─ Kategori tespiti
   └─ Mağaza tespiti
   ↓
7. Veri Birleştirme
   ├─ Görsel: Telegram > HTML > Boş
   ├─ Başlık: AI > Mesaj
   ├─ Fiyat: Mesaj (regex) > AI > 0.0
   ├─ Kategori: AI (zorunlu)
   └─ Mağaza: Link domain > AI > Bilinmeyen
   ↓
8. Firebase'e Kaydetme
   ├─ isApproved: false (admin onayı bekliyor)
   ├─ isExpired: false
   └─ postedBy: 'telegram_bot'
   ↓
9. Tamamlandı ✅
```

### Veri Çıkarma Öncelikleri

#### Görsel
1. Telegram mesajındaki fotoğraf (imgbb'ye yüklenir)
2. HTML scraping (og:image, twitter:image, JSON-LD)
3. Boş (görsel yok)

#### Başlık
1. AI analizi (Gemini)
2. Mesaj metni (ilk 100 karakter)

#### Fiyat
1. Mesajdan regex ile çıkarma (en güvenilir)
2. AI analizi (görsel OCR veya metin)
3. HTML scraping (JSON-LD)
4. 0.0 (bulunamadı)

#### Kategori
1. AI analizi (zorunlu, geçersizse 'diğer')
2. Geçerli kategoriler: elektronik, moda, ev_yasam, anne_bebek, kozmetik, spor_outdoor, supermarket, yapi_oto, kitap_hobi, diğer

#### Mağaza
1. Link'ten domain çıkarma
2. AI analizi
3. 'Bilinmeyen'

---

## 🎯 Önemli Notlar

### Güvenlik
- ✅ `.env` dosyasını asla commit etmeyin
- ✅ `firebase_key.json` dosyasını güvenli tutun
- ✅ SSH key dosyasının izinlerini kontrol edin (`chmod 400`)

### Performans
- ✅ Rate limiting sayesinde Telegram spam algılamasından kaçınır
- ✅ Asenkron işlemler sayesinde hızlı çalışır
- ✅ Duplicate kontrolü yapılmaz (Firebase'de yapılabilir)

### Limitler
- ⚠️ Telegram API limitleri: Çok hızlı mesaj gönderimi spam algılanabilir
- ⚠️ Gemini API limitleri: Çok fazla istek ücretli olabilir
- ⚠️ Firebase limitleri: Çok fazla kayıt ücretli olabilir

### Bakım
- 🔄 Bot kodunu düzenli güncelleyin
- 🔄 Logları düzenli kontrol edin
- 🔄 Firebase kullanımını izleyin
- 🔄 Sunucu kaynaklarını (CPU, RAM) izleyin

---

## 📞 Yardım ve Destek

Sorun yaşarsanız:
1. Logları kontrol edin: `tail -f logs/bot.log`
2. Bot durumunu kontrol edin: `ps aux | grep telegram_bot.py`
3. `.env` dosyasını kontrol edin: `cat .env | grep TELEGRAM_CHANNELS`
4. Hata mesajlarını kaydedin ve paylaşın

---

**Son Güncelleme:** 2025-01-XX
**Versiyon:** 1.0



