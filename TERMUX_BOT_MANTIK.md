# Termux Bot Çalışma Mantığı

## 📋 Genel Bakış

Termux'taki bot, Telegram kanallarından/gruplarından fırsat paylaşımlarını otomatik olarak çeker, işler ve Firebase'e kaydeder.

## 🔄 Çalışma Akışı

### 1. Başlangıç (Initialization)

```python
# Bot başlatıldığında:
1. Telegram API bilgileri yüklenir (.env dosyasından)
   - TELEGRAM_API_ID
   - TELEGRAM_API_HASH
   - TELEGRAM_SESSION_NAME
   - TELEGRAM_CHANNELS (virgülle ayrılmış kanal listesi)

2. Telegram Client başlatılır
   - Telethon kütüphanesi kullanılır
   - Session dosyası ile oturum açılır

3. Firebase bağlantısı kurulur
   - Termux'ta REST API kullanılır (firebase-admin yok)
   - PC'de firebase-admin kullanılır
```

### 2. Kanal Listesi İşleme

```python
# .env dosyasından kanal listesi alınır:
TELEGRAM_CHANNELS=@indirimkaplani,-3371238729

# Her kanal için:
for channel in channels:
    1. Kanal bulunur (username veya ID ile)
    2. Son 5 mesaj çekilir
    3. Her mesaj işlenir
    4. Kanal arası 2 saniye bekleme
```

### 3. Mesaj İşleme (process_message)

Her mesaj için şu adımlar izlenir:

#### A. Mesaj Parse Etme
```python
1. Mesaj metninden bilgiler çıkarılır:
   - Başlık (title)
   - Fiyat (price) - regex ile
   - Link (URL) - mesajdan veya butonlardan
   - Mağaza (store) - link domain'inden
   - Kategori (category) - otomatik belirlenir

2. Butonlardan URL çıkarılır (reply_markup)
   - Telegram mesajlarındaki inline butonlar kontrol edilir
   - Buton URL'leri mesaj linklerine eklenir
```

#### B. Duplicate Kontrolü
```python
# Bu mesaj daha önce işlendi mi?
Firebase'de sorgu:
- telegramMessageId == message_id
- telegramChatUsername == channel_username

# Eğer varsa, mesaj atlanır (duplicate önleme)
```

#### C. Görsel Çekme (Öncelik Sırası)
```python
1. ÖNCELİK 1: Telegram Media'dan
   - Mesajda fotoğraf varsa indirilir
   - Firebase Storage'a yüklenir
   - Public URL alınır

2. ÖNCELİK 2: Link'ten
   - Ürün linkine gidilir
   - HTML çekilir
   - Open Graph veya meta tag'lerden görsel bulunur
   - Görsel URL'i alınır
```

#### D. Fiyat Çekme
```python
# HER ZAMAN linkten çekmeyi dene (öncelikli)

1. Ürün linkine gidilir
2. HTML parse edilir (BeautifulSoup)
3. Site-specific selector'lar denenir:
   - Trendyol: .pr-new-br, .prc-dsc
   - Hepsiburada: .product-price, .price-value
   - N11: .newPrice, .priceContainer
   - Amazon: #priceblock_ourprice, .a-price-whole
   - Genel: .price, .fiyat, [class*="price"]

4. Eğer linkten bulunamazsa:
   - Mesajdan parse edilen fiyat kullanılır
```

#### E. Firebase'e Kaydetme
```python
deal_data = {
    'title': parsed_deal['title'],
    'price': parsed_deal['price'],
    'store': parsed_deal['store'],
    'category': parsed_deal['category'],
    'link': parsed_deal['link'],
    'imageUrl': image_url,
    'description': parsed_deal['description'],
    'hotVotes': 0,
    'coldVotes': 0,
    'commentCount': 0,
    'postedBy': f"telegram_channel_{chat_identifier}",
    'createdAt': datetime.utcnow(),  # Termux'ta string olarak kaydediliyor!
    'isEditorPick': False,
    'isApproved': False,  # Admin onayı bekliyor
    'isExpired': False,
    'hotVoters': [],
    'coldVoters': [],
    'source': 'telegram',
    'telegramMessageId': message_id,
    'telegramChatId': chat_id,
    'telegramChatType': 'channel',
    'telegramChatTitle': channel_username,
    'telegramChatUsername': chat_identifier,
    'rawMessage': message_text,
}

# REST API ile Firebase'e kaydet
firebase_rest_api.firestore_add('deals', deal_data)
```

## 🔍 Önemli Detaylar

### Termux vs PC Farkları

| Özellik | PC (firebase-admin) | Termux (REST API) |
|---------|---------------------|-------------------|
| Firebase SDK | firebase-admin | REST API |
| createdAt | Timestamp | String (datetime.utcnow()) |
| Storage | firebase-admin | REST API |
| Performans | Daha hızlı | Biraz daha yavaş |

### Veri Çekme Mantığı

1. **Kanal Formatları:**
   - `@username` → Username ile kanal bulunur
   - `-123456789` → Negatif ID ile grup bulunur
   - `-100123456789` → Supergroup formatı

2. **Mesaj Limit:**
   - Her kanaldan **son 5 mesaj** çekilir
   - Bu limit performans için ayarlanmış

3. **Rate Limiting:**
   - Mesajlar arası: 1 saniye bekleme
   - Kanallar arası: 2 saniye bekleme
   - Telegram API limitlerini aşmamak için

### Parse Mantığı

1. **Başlık Bulma:**
   - Mesajın ilk satırı veya entity'lerden
   - URL'lerden önceki metin

2. **Fiyat Bulma:**
   - Regex pattern'ler: `\d+[.,]\d+`, `\d+\s*TL`, vb.
   - Linkten çekme öncelikli
   - Minimum 10 TL kontrolü

3. **Link Bulma:**
   - Mesaj içindeki URL'ler
   - Butonlardaki URL'ler
   - Entity'lerden (MessageEntityUrl)

4. **Kategori Belirleme:**
   - Link domain'ine göre
   - Veya varsayılan kategori

## ⚠️ Bilinen Sorunlar

1. **createdAt Formatı:**
   - Termux'ta string olarak kaydediliyor
   - Flutter uygulaması parse ederken sorun yaşayabilir
   - **Çözüm:** Bot kodunu güncelle (datetime → timestampValue)

2. **Duplicate Kontrolü:**
   - REST API sorgusu bazen çalışmayabilir
   - Aynı mesaj birden fazla kez kaydedilebilir

3. **Görsel Çekme:**
   - Bazı siteler görseli engelleyebilir
   - Blob URL'ler desteklenmiyor

## 🚀 Kullanım

```bash
# Termux'ta bot çalıştırma
cd /path/to/bot
source venv/bin/activate
python telegram_bot.py

# Veya script ile
./run_telegram_bot.sh
```

## 📝 Loglar

Bot çalışırken loglar `logs/telegram_bot.log` dosyasına yazılır:
- ✅ Başarılı işlemler
- ⚠️ Uyarılar
- ❌ Hatalar

## 🔧 Yapılandırma

`.env` dosyasında:
```env
TELEGRAM_API_ID=your_api_id
TELEGRAM_API_HASH=your_api_hash
TELEGRAM_SESSION_NAME=telegram_session
TELEGRAM_CHANNELS=@kanal1,-123456789
FIREBASE_CREDENTIALS_PATH=firebase_key.json
```


