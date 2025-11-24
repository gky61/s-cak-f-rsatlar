# Telegram Bot Kurulum Rehberi

Bu rehber, Telegram gruplarından fırsat paylaşımlarını otomatik olarak alıp Firestore'a kaydeden ve admin onayına sunan Telegram Bot'unun kurulumunu açıklar.

## 📋 Özellikler

- ✅ Telegram gruplarından mesajları otomatik dinleme
- ✅ Mesajları akıllıca parse edip Deal formatına çevirme
- ✅ Fiyat, mağaza, kategori otomatik tespit
- ✅ Resim desteği
- ✅ Firestore'a `isApproved: false` ile kaydetme (admin onayı bekliyor)
- ✅ Admin onayından sonra otomatik bildirim gönderme

## 🚀 Kurulum Adımları

### 1. Telegram Bot Oluşturma

1. Telegram'da [@BotFather](https://t.me/botfather) ile konuşun
2. `/newbot` komutunu gönderin
3. Bot'unuz için bir isim seçin (örn: "Sıcak Fırsatlar Bot")
4. Bot'unuz için bir kullanıcı adı seçin (örn: "sicak_firsatlar_bot")
5. BotFather size bir **Bot Token** verecek. Bu token'ı saklayın!

**Örnek Token:** `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

### 2. Bot'u Gruba Ekleme

1. Telegram grubunuza gidin
2. Grubun ayarlarına gidin
3. "Üyeler Ekle" > Bot'unuzu arayın ve ekleyin
4. Bot'a **"Mesajları Silme"** yetkisi verin (opsiyonel ama önerilir)

### 3. Grup ID'sini Öğrenme

Grup ID'sini öğrenmek için:

1. Bot'unuzu gruba ekleyin
2. Gruba bir mesaj gönderin (örn: "test")
3. Tarayıcınızda şu URL'yi açın:
   ```
   https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
   ```
   `<BOT_TOKEN>` yerine bot token'ınızı yazın.

4. JSON yanıtında `"chat":{"id":-123456789}` şeklinde bir değer göreceksiniz. Bu grup ID'nizdir.

**Not:** Negatif sayılar grup ID'sidir. Pozitif sayılar kullanıcı ID'sidir.

### 4. Firebase Functions Yapılandırması

#### 4.1. Paketleri Yükleme

```bash
cd functions
npm install
```

#### 4.2. Environment Variables Ayarlama

Firebase Functions'a bot token'ınızı ve grup ID'lerinizi ekleyin:

```bash
firebase functions:config:set telegram.bot_token="YOUR_BOT_TOKEN"
firebase functions:config:set telegram.allowed_group_ids="-123456789,-987654321"
```

**Notlar:**
- `YOUR_BOT_TOKEN`: BotFather'dan aldığınız token
- `allowed_group_ids`: İzin verilen grup ID'leri (virgülle ayrılmış). Boş bırakırsanız tüm gruplar kabul edilir.

#### 4.3. Functions'ı Deploy Etme

```bash
# Proje root klasöründe
firebase deploy --only functions:telegramWebhook
```

### 5. Telegram Webhook Ayarlama

Deploy işlemi tamamlandıktan sonra, Firebase size bir webhook URL'i verecek. Bu URL şuna benzer olacak:

```
https://us-central1-sicak-firsatlar-e6eae.cloudfunctions.net/telegramWebhook
```

Bu URL'yi Telegram'a kaydetmek için:

```bash
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://us-central1-sicak-firsatlar-e6eae.cloudfunctions.net/telegramWebhook"}'
```

**Veya tarayıcıda:**
```
https://api.telegram.org/bot<BOT_TOKEN>/setWebhook?url=https://us-central1-sicak-firsatlar-e6eae.cloudfunctions.net/telegramWebhook
```

Webhook'un başarıyla ayarlandığını kontrol etmek için:

```bash
curl "https://api.telegram.org/bot<BOT_TOKEN>/getWebhookInfo"
```

## 📝 Mesaj Formatı

Bot, Telegram mesajlarını otomatik olarak parse eder. İdeal mesaj formatı:

```
RTX 4090 Ekran Kartı
Fiyat: 45.000 TL
Mağaza: Trendyol
https://www.trendyol.com/urun/...
```

**Bot şunları otomatik tespit eder:**
- ✅ **Başlık**: İlk satır veya mesajın başı
- ✅ **Fiyat**: "TL", "₺", "lira", "fiyat" kelimeleriyle
- ✅ **Mağaza**: "mağaza", "store", "satıcı" kelimeleriyle veya URL'den domain adı
- ✅ **Link**: Mesajdaki URL'ler
- ✅ **Kategori**: Mesaj içeriğinden otomatik tespit
- ✅ **Resim**: Mesajla birlikte gönderilen fotoğraflar

## 🔍 Test Etme

1. Telegram grubunuza bir fırsat mesajı gönderin
2. Bot size bir onay mesajı göndermeli: "✅ Fırsat alındı! Admin onayından sonra yayınlanacak."
3. Firebase Console > Firestore > `deals` koleksiyonuna gidin
4. Yeni bir deal görmelisiniz:
   - `isApproved: false`
   - `source: "telegram"`
   - `telegramMessageId`, `telegramChatId`, `telegramUserId` alanları dolu olmalı

## 👨‍💼 Admin Onayı

1. Flutter uygulamanızda Admin ekranına gidin
2. "Onay Bekleyen Fırsatlar" bölümünde Telegram'dan gelen fırsatları göreceksiniz
3. Fırsatı düzenleyip onaylayabilirsiniz
4. Onaylandıktan sonra, mevcut bildirim sistemi devreye girer ve kullanıcılara bildirim gönderilir

## 🛠️ Sorun Giderme

### Bot mesajları almıyor

1. Webhook'un doğru ayarlandığından emin olun:
   ```bash
   curl "https://api.telegram.org/bot<BOT_TOKEN>/getWebhookInfo"
   ```

2. Bot'un gruba eklendiğinden emin olun

3. Firebase Functions loglarını kontrol edin:
   ```bash
   firebase functions:log --only telegramWebhook
   ```

### Mesajlar parse edilmiyor

1. Mesajda mutlaka bir URL olmalı
2. Mesajda başlık olmalı (ilk satır)
3. Firebase Functions loglarını kontrol edin

### Grup ID bulunamıyor

1. Bot'u gruba ekleyin
2. Gruba bir mesaj gönderin
3. `getUpdates` API'sini kullanın:
   ```bash
   curl "https://api.telegram.org/bot<BOT_TOKEN>/getUpdates"
   ```

### Environment variables çalışmıyor

1. Deploy sonrası environment variables'ları kontrol edin:
   ```bash
   firebase functions:config:get
   ```

2. Eğer görünmüyorsa, tekrar set edin ve redeploy edin

## 🔐 Güvenlik

- ✅ Bot token'ınızı asla public repository'lere commit etmeyin
- ✅ Environment variables kullanın
- ✅ İzin verilen grup ID'lerini belirtin (tüm grupları kabul etmeyin)
- ✅ Firebase Functions'ın güvenlik kurallarını kontrol edin

## 📊 Firestore Yapısı

Telegram'dan gelen deal'ler şu ekstra alanlara sahiptir:

```javascript
{
  // ... normal deal alanları ...
  source: "telegram",
  telegramMessageId: 12345,
  telegramChatId: -123456789,
  telegramUserId: 987654321,
  telegramUsername: "kullanici_adi",
  rawMessage: "Orijinal mesaj metni"
}
```

## 🔄 Webhook'u Kaldırma

Webhook'u kaldırmak için:

```bash
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/deleteWebhook"
```

## 📚 Kaynaklar

- [Telegram Bot API Dokümantasyonu](https://core.telegram.org/bots/api)
- [Firebase Cloud Functions Dokümantasyonu](https://firebase.google.com/docs/functions)
- [node-telegram-bot-api GitHub](https://github.com/yagop/node-telegram-bot-api)

## 🆘 Destek

Sorun yaşarsanız:
1. Firebase Functions loglarını kontrol edin
2. Telegram Bot API loglarını kontrol edin
3. Firestore'da deal'lerin doğru kaydedildiğini kontrol edin





