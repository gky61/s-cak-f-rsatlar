# 🚀 Kurulum Adımları - Yönetici Olmadan Kanal Mesajları

## ✅ Adım 1: Paketler Yüklendi

Paketler başarıyla yüklendi! ✅

## 📋 Adım 2: Telegram API Bilgilerini Alın

### 2.1. my.telegram.org'a Gidin

1. Tarayıcınızda https://my.telegram.org/apps adresine gidin
2. Telegram hesabınızla giriş yapın (telefon numaranız ve kod)

### 2.2. API Uygulaması Oluşturun

1. "API development tools" bölümüne gidin
2. "Create new application" butonuna tıklayın
3. Formu doldurun:
   - **App title**: `Sıcak Fırsatlar` (veya istediğiniz isim)
   - **Short name**: `sicakfirsatlar` (veya istediğiniz kısa isim)
   - **Platform**: `Web`
   - **Description**: `Fırsat paylaşım uygulaması` (opsiyonel)
   - **Website URL**: `https://example.com` (opsiyonel, geçerli bir URL olmalı)
4. "Create application" butonuna tıklayın

### 2.3. API Bilgilerini Kopyalayın

Sayfada şunları göreceksiniz:
- **api_id**: Bir sayı (örn: `12345678`)
- **api_hash**: Bir string (örn: `abcdef1234567890abcdef1234567890`)

Bu değerleri kopyalayın ve bir yere kaydedin!

## 🔐 Adım 3: Session String Oluşturun

### 3.1. Session Script'ini Güncelleyin

`functions/setup_telegram_session.js` dosyasını açın ve şu satırları güncelleyin:

```javascript
const API_ID = '12345678'; // my.telegram.org'dan aldığınız API ID
const API_HASH = 'abcdef1234567890abcdef1234567890'; // my.telegram.org'dan aldığınız API Hash
```

### 3.2. Session Script'ini Çalıştırın

```bash
cd functions
node setup_telegram_session.js
```

### 3.3. Giriş Yapın

Script size soracak:
1. **Telefon numaranızı girin**: `+905551234567` formatında
2. **Telegram'dan gelen kodu girin**: Telegram uygulamanıza gelen 5 haneli kodu girin
3. **2FA şifreniz varsa girin**: Eğer Telegram hesabınızda 2FA açıksa şifrenizi girin (yoksa Enter'a basın)

### 3.4. Session String'i Kopyalayın

Giriş başarılı olduktan sonra, terminal'de bir session string göreceksiniz. Bu string'i kopyalayın!

**Örnek çıktı:**
```
📋 Session String (Bunu kopyalayın):
==================================================
1BVtsOHwBu7Rkz0-...
==================================================
```

## ⚙️ Adım 4: Firebase Config Ayarlayın

Terminal'de şu komutları çalıştırın (değerleri kendi bilgilerinizle değiştirin):

```bash
# Proje root klasöründe
firebase functions:config:set telegram.api_id="12345678"
firebase functions:config:set telegram.api_hash="abcdef1234567890abcdef1234567890"
firebase functions:config:set telegram.session_string="1BVtsOHwBu7Rkz0-..."
firebase functions:config:set telegram.channel_username="@donanimhabersicakfirsatlar"
```

**Önemli:** 
- `api_id` sayı olarak (tırnak içinde)
- `api_hash` string olarak (tırnak içinde)
- `session_string` kopyaladığınız tüm string (tırnak içinde)
- `channel_username` kanal username'i (@ işareti ile)

## 🚀 Adım 5: Deploy Edin

```bash
firebase deploy --only functions:fetchChannelMessages
```

## ✅ Adım 6: Test Edin

### 6.1. Logları İzleyin

```bash
firebase functions:log --only fetchChannelMessages
```

### 6.2. Firestore'u Kontrol Edin

1. Firebase Console > Firestore
2. `deals` koleksiyonuna gidin
3. Yeni deal'leri kontrol edin:
   - `source: "telegram"`
   - `telegramChatType: "channel"`
   - `telegramChatUsername: "donanimhabersicakfirsatlar"`

## 🔄 Function Çalışma Sıklığı

Function varsayılan olarak **her 5 dakikada bir** çalışır.

Değiştirmek için `functions/index.js` dosyasında:
```javascript
exports.fetchChannelMessages = functions.pubsub
  .schedule('every 5 minutes') // Burayı değiştirin
```

**Örnek zamanlama:**
- `'every 1 minutes'` - Her 1 dakika
- `'every 5 minutes'` - Her 5 dakika (varsayılan)
- `'every 15 minutes'` - Her 15 dakika
- `'every 1 hours'` - Her 1 saat

## 🐛 Sorun Giderme

### "Telegram API bilgileri eksik" hatası
- Firebase config'in doğru ayarlandığından emin olun
- `firebase functions:config:get` ile kontrol edin

### "Session expired" hatası
- Session string'i yeniden oluşturun (Adım 3)

### "Kanal bulunamadı" hatası
- Kanal username'inin doğru olduğundan emin olun
- Kanalın public olduğundan emin olun
- Telegram'da kanalı takip ettiğinizden emin olun

## 📝 Özet

1. ✅ Paketler yüklendi
2. ⏳ API bilgilerini alın (my.telegram.org)
3. ⏳ Session string oluşturun
4. ⏳ Firebase config ayarlayın
5. ⏳ Deploy edin
6. ⏳ Test edin

**Şimdi Adım 2'ye geçin: Telegram API bilgilerini alın!**





