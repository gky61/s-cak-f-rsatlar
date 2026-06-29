# 📢 Telegram Kanal - Yönetici Olmadan Mesaj Çekme

Kanal yöneticisi olmadan Telegram kanallarından mesaj çekmek için **Telegram Client API (MTProto)** kullanıyoruz.

## 🎯 Nasıl Çalışıyor?

1. **Telegram Client API** ile kendi Telegram hesabınızla giriş yapıyoruz
2. Public kanallardan mesajları okuyoruz (yönetici olmaya gerek yok)
3. Belirli aralıklarla (her 5 dakika) kanal mesajlarını kontrol ediyoruz
4. Yeni mesajları Firestore'a kaydediyoruz

## 📋 Gereksinimler

### 1. Telegram API Bilgileri

Telegram API bilgilerini almak için:

1. https://my.telegram.org/apps adresine gidin
2. Telegram hesabınızla giriş yapın
3. "API development tools" bölümüne gidin
4. Bir uygulama oluşturun:
   - **App title**: Sıcak Fırsatlar (veya istediğiniz isim)
   - **Short name**: sicakfirsatlar (veya istediğiniz kısa isim)
   - **Platform**: Web
   - **Description**: Fırsat paylaşım uygulaması
5. **API ID** ve **API Hash** değerlerini kopyalayın

### 2. Session String Oluşturma

Session string oluşturmak için bir kez giriş yapmanız gerekiyor. Bunun için:

#### Yöntem 1: Local Script ile (Önerilen)

```bash
cd functions
npm install telegram
```

Sonra `setup_telegram_session.js` dosyasını oluşturun:

```javascript
const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const input = require('input'); // npm install input

const apiId = YOUR_API_ID; // my.telegram.org'dan aldığınız
const apiHash = 'YOUR_API_HASH'; // my.telegram.org'dan aldığınız
const stringSession = new StringSession(''); // Boş string

(async () => {
  const client = new TelegramClient(stringSession, apiId, apiHash, {
    connectionRetries: 5,
  });

  await client.start({
    phoneNumber: async () => await input.text('Telefon numaranızı girin (örn: +905551234567): '),
    password: async () => await input.text('2FA şifreniz varsa girin (yoksa Enter): '),
    phoneCode: async () => await input.text('Telegram\'dan gelen kodu girin: '),
    onError: (err) => console.log(err),
  });

  console.log('✅ Giriş başarılı!');
  console.log('Session String:');
  console.log(client.session.save());
  await client.disconnect();
})();
```

Çalıştırın:
```bash
node setup_telegram_session.js
```

Telefon numaranızı ve Telegram'dan gelen kodu girin. Session string'i kopyalayın.

#### Yöntem 2: Firebase Functions ile (Daha Karmaşık)

Firebase Functions'da interactive giriş yapmak zor olduğu için, önce local'de session oluşturup sonra Firebase'e eklemeniz önerilir.

### 3. Firebase Config Ayarlama

```bash
firebase functions:config:set telegram.api_id="YOUR_API_ID"
firebase functions:config:set telegram.api_hash="YOUR_API_HASH"
firebase functions:config:set telegram.session_string="YOUR_SESSION_STRING"
firebase functions:config:set telegram.channel_username="@donanimhabersicakfirsatlar"
```

### 4. Paketleri Yükleme

```bash
cd functions
npm install
cd ..
```

### 5. Deploy Etme

```bash
firebase deploy --only functions:fetchChannelMessages
```

## ⚙️ Çalışma Sıklığı

Function varsayılan olarak **her 5 dakikada bir** çalışır. Değiştirmek için `functions/index.js` dosyasında:

```javascript
exports.fetchChannelMessages = functions.pubsub
  .schedule('every 5 minutes') // Burayı değiştirin
  .onRun(async (context) => {
    // ...
  });
```

**Örnek zamanlama:**
- `'every 1 minutes'` - Her 1 dakika
- `'every 5 minutes'` - Her 5 dakika (varsayılan)
- `'every 15 minutes'` - Her 15 dakika
- `'every 1 hours'` - Her 1 saat

## 🧪 Test Etme

### Manuel Test

Function'ı manuel olarak tetiklemek için:

```bash
firebase functions:shell
```

Sonra:
```javascript
fetchChannelMessages()
```

### Logları İzleme

```bash
firebase functions:log --only fetchChannelMessages
```

## 📊 Firestore Yapısı

Kanal mesajlarından gelen deal'ler şu alanlara sahiptir:

```javascript
{
  // ... normal deal alanları ...
  source: "telegram",
  telegramChatType: "channel",
  telegramChatUsername: "donanimhabersicakfirsatlar",
  telegramChatTitle: "Donanım Haber Sıcak Fırsatlar",
  telegramMessageId: 12345,
  telegramChatId: "-1001234567890",
  postedBy: "telegram_channel_donanimhabersicakfirsatlar",
  rawMessage: "Orijinal mesaj metni"
}
```

## 🔍 Sorun Giderme

### "Telegram API bilgileri eksik" hatası

**Çözüm:**
```bash
firebase functions:config:set telegram.api_id="YOUR_API_ID"
firebase functions:config:set telegram.api_hash="YOUR_API_HASH"
firebase functions:config:set telegram.session_string="YOUR_SESSION_STRING"
```

### "Session expired" hatası

**Çözüm:**
Session string'i yeniden oluşturun (Yöntem 1'e bakın).

### "Kanal bulunamadı" hatası

**Çözüm:**
- Kanal username'inin doğru olduğundan emin olun
- Kanalın public olduğundan emin olun
- Kanalı Telegram'da takip ettiğinizden emin olun

### Mesajlar çekilmiyor

**Kontrol edin:**
1. Function'ın çalıştığını loglardan kontrol edin
2. Kanal username'inin doğru olduğundan emin olun
3. Session string'in geçerli olduğundan emin olun

## ⚠️ Önemli Notlar

1. **Session Güvenliği**: Session string'inizi asla paylaşmayın! Bu, Telegram hesabınıza erişim sağlar.

2. **Rate Limiting**: Telegram API rate limit'leri vardır. Çok sık istek göndermeyin.

3. **2FA**: Eğer Telegram hesabınızda 2FA açıksa, session oluştururken şifrenizi girmeniz gerekir.

4. **Maliyet**: Scheduled function'lar Firebase'de ücretlidir. Çok sık çalıştırmayın.

## 🎯 Avantajlar

- ✅ Yönetici olmaya gerek yok
- ✅ Public kanallardan mesaj çekebilir
- ✅ Otomatik çalışır (scheduled)
- ✅ Firestore'a otomatik kaydeder

## 📚 Kaynaklar

- [Telegram API Dokümantasyonu](https://core.telegram.org/api)
- [Telegram Node.js Library](https://github.com/gram-js/gramjs)
- [Firebase Scheduled Functions](https://firebase.google.com/docs/functions/schedule-functions)

## 🆘 Destek

Sorun yaşarsanız:
1. Firebase Functions loglarını kontrol edin
2. Session string'in geçerli olduğundan emin olun
3. API bilgilerinin doğru olduğundan emin olun





