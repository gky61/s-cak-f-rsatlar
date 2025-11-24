# 📢 Telegram Kanal Kurulum Rehberi

Bu rehber, Telegram kanallarından (örneğin @donanimhabersicakfirsatlar) fırsat paylaşımlarını otomatik olarak çekmek için gereken adımları açıklar.

## 🎯 Özellikler

- ✅ Telegram kanallarından mesajları otomatik dinleme
- ✅ Kanal mesajlarını parse edip Deal formatına çevirme
- ✅ Fiyat, mağaza, kategori otomatik tespit
- ✅ Resim desteği
- ✅ Firestore'a `isApproved: false` ile kaydetme (admin onayı bekliyor)

## ⚠️ Önemli Notlar

**Telegram kanallarından mesaj çekmek için:**
1. Bot'un kanala **admin** olarak eklenmesi gerekir
2. Bot'un kanal mesajlarını görebilmesi için "Post Messages" yetkisi olmalı
3. Kanal mesajları için webhook kullanılır (bot kanala mesaj gönderemez)

## 🚀 Kurulum Adımları

### 1. Telegram Bot Oluşturma

1. Telegram'da [@BotFather](https://t.me/botfather) ile konuşun
2. `/newbot` komutunu gönderin
3. Bot'unuz için bir isim seçin (örn: "Sıcak Fırsatlar Bot")
4. Bot'unuz için bir kullanıcı adı seçin
5. BotFather size bir **Bot Token** verecek. Bu token'ı saklayın!

### 2. Bot'u Kanala Admin Olarak Ekleme

**ÖNEMLİ:** Bot'un kanal mesajlarını görebilmesi için kanala admin olarak eklenmesi gerekir.

1. Telegram kanalınıza gidin (örn: @donanimhabersicakfirsatlar)
2. Kanal ayarlarına gidin (kanal adına tıklayın)
3. "Yöneticiler" (Administrators) bölümüne gidin
4. "Yönetici Ekle" (Add Administrator) butonuna tıklayın
5. Bot'unuzu arayın ve ekleyin
6. Bot'a şu yetkileri verin:
   - ✅ **Post Messages** (Mesaj Gönderme) - Gerekli değil ama verilebilir
   - ✅ **Read Messages** (Mesaj Okuma) - Otomatik olarak verilir

**Not:** Bot kanala mesaj gönderemez, sadece mesajları okuyabilir.

### 3. Kanal Username'ini Öğrenme

Kanal username'i genellikle kanal URL'sinde görünür:
- URL: `https://web.telegram.org/k/#@donanimhabersicakfirsatlar`
- Username: `@donanimhabersicakfirsatlar` veya `donanimhabersicakfirsatlar`

### 4. Firebase Functions Yapılandırması

#### 4.1. Paketleri Yükleme

```bash
cd functions
npm install
cd ..
```

#### 4.2. Environment Variables Ayarlama

```bash
# Bot token'ı ayarla
firebase functions:config:set telegram.bot_token="YOUR_BOT_TOKEN"

# Kanal username'lerini ayarla (virgülle ayırın)
firebase functions:config:set telegram.allowed_channels="@donanimhabersicakfirsatlar"

# Veya birden fazla kanal:
firebase functions:config:set telegram.allowed_channels="@kanal1,@kanal2,@kanal3"
```

**Notlar:**
- `@` işareti ile veya `@` işareti olmadan yazabilirsiniz
- Boş bırakırsanız tüm kanallar kabul edilir (önerilmez)

#### 4.3. Functions'ı Deploy Etme

```bash
# Proje root klasöründe
firebase deploy --only functions:telegramWebhook
```

### 5. Telegram Webhook Ayarlama

Deploy işlemi tamamlandıktan sonra, Firebase size bir webhook URL'i verecek:

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

## 🧪 Test Etme

### 1. Kanal Mesajı Gönderme

Kanalınıza bir fırsat mesajı gönderin:

```
RTX 4090 Ekran Kartı
Fiyat: 45.000 TL
Mağaza: Trendyol
https://www.trendyol.com/urun/...
```

### 2. Firestore'da Kontrol

1. Firebase Console > Firestore > `deals` koleksiyonuna gidin
2. Yeni bir deal görmelisiniz:
   - `source: "telegram"`
   - `telegramChatType: "channel"`
   - `telegramChatUsername: "donanimhabersicakfirsatlar"`
   - `isApproved: false`

### 3. Logları Kontrol

```bash
firebase functions:log --only telegramWebhook
```

Loglarda şunu görmelisiniz:
```
Kanal mesajı alındı: Donanım Haber Sıcak Fırsatlar
Deal Firestore'a kaydedildi: <deal_id>
```

## 📋 Otomatik Kurulum (Script ile)

```bash
./setup_telegram_bot.sh
```

Script size soracak:
1. Bot Token'ınız
2. Grup ID'leriniz (opsiyonel)
3. **Kanal username'leriniz** (örn: `@donanimhabersicakfirsatlar`)

## 🔍 Sorun Giderme

### Bot kanal mesajlarını görmüyor

**Çözüm:**
1. Bot'un kanala admin olarak eklendiğinden emin olun
2. Bot'un "Read Messages" yetkisine sahip olduğundan emin olun
3. Webhook'un doğru ayarlandığını kontrol edin

### "İzin verilmeyen kanal" hatası

**Çözüm:**
1. Kanal username'inin doğru yazıldığından emin olun
2. `@` işareti ile veya `@` işareti olmadan deneyin
3. Firebase config'i kontrol edin:
   ```bash
   firebase functions:config:get
   ```

### Mesajlar parse edilmiyor

**Kontrol edin:**
1. Mesajda mutlaka bir URL olmalı
2. Mesajda başlık olmalı (ilk satır)
3. Logları kontrol edin: `firebase functions:log --only telegramWebhook`

### Webhook çalışmıyor

**Kontrol edin:**
1. Webhook URL'inin doğru olduğundan emin olun
2. Function'ın deploy edildiğinden emin olun
3. Bot token'ının doğru olduğundan emin olun

## 📊 Firestore Yapısı

Kanal mesajlarından gelen deal'ler şu ekstra alanlara sahiptir:

```javascript
{
  // ... normal deal alanları ...
  source: "telegram",
  telegramChatType: "channel",
  telegramChatUsername: "donanimhabersicakfirsatlar",
  telegramChatTitle: "Donanım Haber Sıcak Fırsatlar",
  telegramMessageId: 12345,
  telegramChatId: -1001234567890,
  postedBy: "telegram_channel_donanimhabersicakfirsatlar",
  rawMessage: "Orijinal mesaj metni"
}
```

## 🎯 Örnek: @donanimhabersicakfirsatlar Kanalı

### Kurulum

```bash
# 1. Bot token'ı ayarla
firebase functions:config:set telegram.bot_token="YOUR_BOT_TOKEN"

# 2. Kanal username'ini ayarla
firebase functions:config:set telegram.allowed_channels="@donanimhabersicakfirsatlar"

# 3. Deploy et
firebase deploy --only functions:telegramWebhook

# 4. Webhook'u ayarla
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "YOUR_WEBHOOK_URL"}'
```

### Bot'u Kanala Ekleme

1. @donanimhabersicakfirsatlar kanalına gidin
2. Kanal ayarları > Yöneticiler > Yönetici Ekle
3. Bot'unuzu ekleyin

### Test

Kanalınıza bir mesaj gönderin ve Firestore'da kontrol edin!

## 📚 Kaynaklar

- [Telegram Bot API - Channels](https://core.telegram.org/bots/api#channel)
- [Telegram Bot API - Webhook](https://core.telegram.org/bots/api#setwebhook)
- [Firebase Cloud Functions Dokümantasyonu](https://firebase.google.com/docs/functions)

## 🆘 Destek

Sorun yaşarsanız:
1. Firebase Functions loglarını kontrol edin
2. Telegram Bot API loglarını kontrol edin
3. Firestore'da deal'lerin doğru kaydedildiğini kontrol edin
4. Bot'un kanala admin olarak eklendiğinden emin olun





