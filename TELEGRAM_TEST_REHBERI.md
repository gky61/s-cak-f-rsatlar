# 🧪 Telegram Bot Test Rehberi

Telegram bot'unuzu test etmek için 3 farklı yöntem:

## Yöntem 1: Web Test Sayfası (En Kolay) 🌐

1. `test_telegram_webhook.html` dosyasını tarayıcıda açın
2. Bot token'ınızı girin
3. Webhook URL'inizi girin
4. Test mesajınızı yazın
5. "Test Et" butonuna tıklayın

**Avantajlar:**
- ✅ Görsel arayüz
- ✅ Kolay kullanım
- ✅ Anında sonuç

## Yöntem 2: Node.js Test Script'i 💻

```bash
node test_telegram_message.js "WEBHOOK_URL" "MESAJ_METNİ"
```

**Örnek:**
```bash
node test_telegram_message.js \
  "https://us-central1-sicak-firsatlar-e6eae.cloudfunctions.net/telegramWebhook" \
  "RTX 4090 Ekran Kartı
Fiyat: 45.000 TL
Mağaza: Trendyol
https://www.trendyol.com/urun/..."
```

## Yöntem 3: Gerçek Telegram Grubu (En Gerçekçi) 📱

1. Bot'unuzu Telegram grubunuza ekleyin
2. Gruba bir fırsat mesajı gönderin:
   ```
   RTX 4090 Ekran Kartı
   Fiyat: 45.000 TL
   Mağaza: Trendyol
   https://www.trendyol.com/urun/...
   ```
3. Bot size "✅ Fırsat alındı!" mesajı gönderecek
4. Firebase Console > Firestore > `deals` koleksiyonunda kontrol edin

## 📋 Test Adımları

### 1. Kurulum Kontrolü

```bash
# Firebase config kontrolü
firebase functions:config:get

# Telegram config olmalı:
# telegram.bot_token: "YOUR_TOKEN"
# telegram.allowed_group_ids: "-123456789" (opsiyonel)
```

### 2. Function Deploy Kontrolü

```bash
# Function'ı deploy edin
firebase deploy --only functions:telegramWebhook

# Deploy sonrası webhook URL'i gösterilecek
```

### 3. Webhook Ayarlama

```bash
# Webhook'u ayarlayın
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "YOUR_WEBHOOK_URL"}'

# Webhook durumunu kontrol edin
curl "https://api.telegram.org/bot<BOT_TOKEN>/getWebhookInfo"
```

### 4. Test Mesajı Gönderme

**Web Test Sayfası ile:**
- `test_telegram_webhook.html` dosyasını açın
- Bilgileri doldurun ve test edin

**Node.js Script ile:**
```bash
node test_telegram_message.js "WEBHOOK_URL" "MESAJ"
```

**Gerçek Telegram ile:**
- Gruba mesaj gönderin

### 5. Sonuçları Kontrol Etme

**Firebase Console:**
1. Firebase Console > Firestore
2. `deals` koleksiyonuna gidin
3. Yeni deal'i kontrol edin:
   - `source: "telegram"`
   - `isApproved: false`
   - `telegramMessageId`, `telegramChatId` dolu olmalı

**Logları Kontrol:**
```bash
firebase functions:log --only telegramWebhook
```

## 🔍 Beklenen Sonuçlar

### Başarılı Test:
- ✅ Webhook 200 OK yanıtı verir
- ✅ Firestore'da yeni deal oluşur
- ✅ Deal'in `source: "telegram"` olması
- ✅ Deal'in `isApproved: false` olması
- ✅ Bot Telegram'da onay mesajı gönderir (gerçek grup testinde)

### Hata Durumları:

**"Bot token yapılandırılmamış"**
```bash
firebase functions:config:set telegram.bot_token="YOUR_TOKEN"
firebase deploy --only functions:telegramWebhook
```

**"Webhook ayarlanamadı"**
- Bot token'ını kontrol edin
- Webhook URL'inin doğru olduğundan emin olun
- Function'ın deploy edildiğinden emin olun

**"Mesaj parse edilemedi"**
- Mesajda mutlaka URL olmalı
- Mesajda başlık olmalı
- Logları kontrol edin: `firebase functions:log`

## 📝 Test Mesajı Örnekleri

### Örnek 1: Basit Format
```
RTX 4090 Ekran Kartı
45.000 TL
https://www.trendyol.com/urun/...
```

### Örnek 2: Detaylı Format
```
RTX 4090 Ekran Kartı
Fiyat: 45.000 TL
Mağaza: Trendyol
Kategori: Bilgisayar - Ekran Kartı (GPU)
https://www.trendyol.com/urun/...
```

### Örnek 3: Mobil Cihaz
```
iPhone 15 Pro Max
Fiyat: 55.000 TL
Mağaza: Apple Store
https://www.apple.com/tr/...
```

### Örnek 4: Konsol
```
PlayStation 5
Fiyat: 25.000 TL
Mağaza: MediaMarkt
https://www.mediamarkt.com.tr/...
```

## 🐛 Sorun Giderme

### Webhook çalışmıyor
1. Function deploy edildi mi?
2. Webhook URL doğru mu?
3. Bot token doğru mu?
4. Firebase config ayarlandı mı?

### Mesajlar parse edilmiyor
1. Mesajda URL var mı?
2. Mesajda başlık var mı?
3. Logları kontrol edin

### Firestore'a kaydedilmiyor
1. Firebase yetkilerini kontrol edin
2. Firestore kurallarını kontrol edin
3. Logları kontrol edin

## ✅ Test Checklist

- [ ] Bot token ayarlandı
- [ ] Webhook URL alındı
- [ ] Webhook Telegram'a kaydedildi
- [ ] Test mesajı gönderildi
- [ ] Firestore'da deal oluştu
- [ ] Deal'in `source: "telegram"` olduğu doğrulandı
- [ ] Deal'in `isApproved: false` olduğu doğrulandı
- [ ] Admin ekranında görünüyor

## 🎯 Sonraki Adımlar

1. ✅ Test başarılı oldu
2. ✅ Bot'u gerçek gruba ekleyin
3. ✅ Gerçek mesajlar gönderin
4. ✅ Admin ekranından onaylayın
5. ✅ Bildirimlerin geldiğini kontrol edin





