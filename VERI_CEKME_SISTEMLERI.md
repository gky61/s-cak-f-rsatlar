# 📊 Veri Çekme Sistemleri

Projede **iki farklı sistem** var ve ikisi de aynı işi yapıyor:

## 1. 🔥 Firebase Functions (Node.js) - Otomatik

**Durum:** Aktif (Her 5 dakikada bir otomatik çalışıyor)

**Özellikler:**
- ✅ Her 5 dakikada bir otomatik çalışır
- ✅ Firebase Cloud'da çalışır (sunucu gerekmez)
- ✅ `functions/telegram_client.js` kullanır
- ✅ `functions/index.js` içinde `fetchChannelMessages` scheduled function

**Kanal/Grup Listesi:**
- Firebase config'den alınır: `functions.config().telegram?.channels`
- Şu anda: `@indirimkaplani,-3371238729`

**Manuel Tetikleme:**
```bash
# HTTP endpoint ile
curl https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/triggerFetchChannelMessages
```

## 2. 🐍 Python Bot - Manuel

**Durum:** Manuel çalıştırma gerekiyor

**Özellikler:**
- ✅ Yerel bilgisayarda çalışır
- ✅ `telegram_bot.py` kullanır
- ✅ Daha detaylı loglama
- ✅ Daha iyi görsel/fiyat çekme (son güncellemelerle)

**Kanal/Grup Listesi:**
- `.env` dosyasından alınır: `TELEGRAM_CHANNELS`
- Şu anda: `@indirimkaplani,-3371238729`

**Çalıştırma:**
```bash
source venv/bin/activate
python telegram_bot.py
```

## 🤔 Hangisini Kullanmalıyım?

### Firebase Functions Kullan (Önerilen):
- ✅ Otomatik çalışır (sunucu gerekmez)
- ✅ 7/24 çalışabilir
- ✅ Manuel müdahale gerektirmez
- ⚠️ Firebase maliyeti olabilir (Blaze plan gerekli)

### Python Bot Kullan:
- ✅ Daha detaylı loglama
- ✅ Yerel kontrol
- ✅ Ücretsiz (kendi bilgisayarınızda)
- ❌ Manuel çalıştırma gerekiyor
- ❌ Bilgisayarınız açık olmalı

## 🔄 İki Sistem Birlikte Çalışabilir mi?

**Evet, ama dikkat:**
- İki sistem de aynı mesajları işleyecek
- Duplicate kontrolü var, aynı mesaj iki kez kaydedilmez
- Ancak gereksiz işlem yükü oluşur

## 💡 Öneri

**Şu anda Firebase Functions aktif ve otomatik çalışıyor.** 

Eğer Python bot'u kullanmak istiyorsanız:
1. Firebase Functions'ı durdurun (veya devre dışı bırakın)
2. Python bot'u sürekli çalıştırın (cron job veya screen/tmux ile)

Veya:
- **Firebase Functions'ı otomatik çalıştırın** (7/24)
- **Python bot'u sadece test/debug için kullanın**

## 📝 Durum Kontrolü

### Firebase Functions Durumu:
```bash
firebase functions:log --only fetchChannelMessages
```

### Python Bot Durumu:
```bash
tail -f logs/telegram_bot.log
```

## 🔧 Firebase Functions'ı Devre Dışı Bırakma

Eğer sadece Python bot kullanmak istiyorsanız:

```javascript
// functions/index.js içinde
exports.fetchChannelMessages = functions
    .pubsub
    .schedule('every 5 minutes')
    .onRun(async (context) => {
      // Geçici olarak devre dışı
      console.log('Function devre dışı bırakıldı');
      return null;
    });
```

Sonra deploy edin:
```bash
firebase deploy --only functions:fetchChannelMessages
```





