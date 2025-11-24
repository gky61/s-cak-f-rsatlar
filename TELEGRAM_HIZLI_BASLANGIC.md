# 🚀 Telegram Bot Hızlı Başlangıç

Telegram'dan mesajları çekmek için **5 basit adım**:

## ⚡ Hızlı Kurulum (Otomatik)

### Adım 1: Bot Oluştur
1. Telegram'da [@BotFather](https://t.me/botfather) ile konuş
2. `/newbot` yaz
3. Bot ismi ve kullanıcı adı seç
4. **Bot Token'ını kopyala** (örn: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Adım 2: Grup ID Öğren (Opsiyonel)
```bash
./get_telegram_group_id.sh
```
Script'i çalıştır, bot'u gruba ekle, gruba mesaj gönder, script grup ID'yi gösterecek.

### Adım 3: Otomatik Kurulum
```bash
./setup_telegram_bot.sh
```
Script size soracak:
- Bot Token'ınızı girin
- Grup ID'lerinizi girin (boş bırakabilirsiniz)

Script otomatik olarak:
- ✅ Firebase config'i ayarlar
- ✅ Paketleri yükler
- ✅ Function'ı deploy eder
- ✅ Webhook'u Telegram'a kaydeder

### Adım 4: Bot'u Gruba Ekle
1. Telegram grubunuza gidin
2. Grubun ayarları > Üyeler Ekle
3. Bot'unuzu arayın ve ekleyin

### Adım 5: Test Et!
Gruba bir fırsat mesajı gönderin:
```
RTX 4090 Ekran Kartı
Fiyat: 45.000 TL
Mağaza: Trendyol
https://www.trendyol.com/urun/...
```

Bot size "✅ Fırsat alındı!" mesajı gönderecek.

---

## 📋 Manuel Kurulum (Script Kullanmak İstemiyorsanız)

### 1. Bot Token'ı Firebase'e Ekle
```bash
firebase functions:config:set telegram.bot_token="BOT_TOKEN_BURAYA"
```

### 2. Grup ID'leri Ekle (Opsiyonel)
```bash
firebase functions:config:set telegram.allowed_group_ids="-123456789,-987654321"
```

### 3. Paketleri Yükle
```bash
cd functions
npm install
cd ..
```

### 4. Deploy Et
```bash
firebase deploy --only functions:telegramWebhook
```

### 5. Webhook URL'ini Al ve Ayarla

Deploy sonrası şu URL'yi göreceksiniz:
```
https://us-central1-sicak-firsatlar-e6eae.cloudfunctions.net/telegramWebhook
```

Bu URL'yi Telegram'a kaydetmek için tarayıcıda açın:
```
https://api.telegram.org/bot<BOT_TOKEN>/setWebhook?url=https://us-central1-sicak-firsatlar-e6eae.cloudfunctions.net/telegramWebhook
```

`<BOT_TOKEN>` yerine bot token'ınızı yazın.

---

## ✅ Nasıl Çalıştığını Kontrol Et

### 1. Logları İzle
```bash
firebase functions:log --only telegramWebhook
```

### 2. Firestore'u Kontrol Et
- Firebase Console > Firestore > `deals` koleksiyonu
- `source: "telegram"` olan yeni deal'leri göreceksiniz
- `isApproved: false` - Admin onayı bekliyor

### 3. Admin Ekranında Görüntüle
- Flutter uygulamanızda Admin ekranına gidin
- "Onay Bekleyen Fırsatlar" bölümünde Telegram'dan gelen fırsatları göreceksiniz

---

## 🔧 Sorun Giderme

### Bot mesajları almıyor
```bash
# Webhook durumunu kontrol et
curl "https://api.telegram.org/bot<BOT_TOKEN>/getWebhookInfo"
```

### Mesajlar parse edilmiyor
- Mesajda mutlaka **URL** olmalı
- Mesajda **başlık** olmalı (ilk satır)
- Logları kontrol edin: `firebase functions:log --only telegramWebhook`

### Grup ID bulunamıyor
```bash
./get_telegram_group_id.sh
```

---

## 📱 Mesaj Formatı Örnekleri

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

### Örnek 3: Resimli
```
[Fotoğraf ile birlikte]
iPhone 15 Pro Max
Fiyat: 55.000 TL
https://www.apple.com/tr/...
```

Bot otomatik olarak:
- ✅ Başlığı bulur
- ✅ Fiyatı bulur
- ✅ Mağazayı bulur (URL'den veya metinden)
- ✅ Kategoriyi tespit eder
- ✅ Resmi alır

---

## 🎯 Sonraki Adımlar

1. ✅ Bot'u gruba ekleyin
2. ✅ Test mesajı gönderin
3. ✅ Firestore'da deal'i kontrol edin
4. ✅ Admin ekranından onaylayın
5. ✅ Bildirimlerin geldiğini kontrol edin

**Detaylı bilgi için:** `TELEGRAM_BOT_SETUP.md` dosyasına bakın.





