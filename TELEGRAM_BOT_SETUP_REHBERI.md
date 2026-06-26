# 🤖 Telegram Bot Setup Rehberi

## ✅ Bot Deploy Edildi!

`fetchChannelMessages` fonksiyonu başarıyla Google Cloud'a deploy edildi ve her 5 dakikada bir otomatik çalışacak şekilde ayarlandı.

## 🔑 Son Adım: Telegram Credentials Ayarla

Bot çalışmak için Telegram API bilgilerine ihtiyaç duyuyor.

### Adım 1: Telegram API Bilgilerini Al

1. https://my.telegram.org/apps adresine gidin
2. Telegram hesabınızla giriş yapın
3. "Create Application" tıklayın
4. **API ID** ve **API Hash** değerlerini kopyalayın

### Adım 2: Telegram Session Oluştur

Session string oluşturmak için:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR/functions"
node setup_telegram_session.js
```

Bu script size bir session string verecek.

### Adım 3: Firebase'e Credentials Ekle

Terminal'de şu komutları çalıştırın:

```bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
source ~/.nvm/nvm.sh
nvm use 22

# Telegram API bilgilerini ayarla
firebase functions:config:set \
  telegram.api_id="YOUR_API_ID" \
  telegram.api_hash="YOUR_API_HASH" \
  telegram.session_string="YOUR_SESSION_STRING" \
  telegram.channels="@indirimkaplani,@diger_kanal"

# Örnek:
# firebase functions:config:set \
#   telegram.api_id="12345678" \
#   telegram.api_hash="abcdef1234567890abcdef1234567890" \
#   telegram.session_string="1AgAOMTQ5Li..." \
#   telegram.channels="@indirimkaplani"
```

### Adım 4: Function'ı Yeniden Deploy Et

Credentials ayarlandıktan sonra:

```bash
firebase deploy --only functions:fetchChannelMessages
```

### Adım 5: Test Et

Function'ın çalışıp çalışmadığını kontrol et:

```bash
# Logları izle
firebase functions:log --only fetchChannelMessages

# Function'ı manuel çalıştır (test için)
# Google Cloud Console'dan:
# https://console.cloud.google.com/functions/details/us-central1/fetchChannelMessages?project=sicak-firsatlar-e6eae
```

## 📊 Bot Nasıl Çalışıyor?

1. **Her 5 dakikada bir** Cloud Scheduler tarafından tetikleniyor
2. **Telegram kanallarına** bağlanıyor
3. **Son mesajları** çekiyor
4. **Firebase Firestore'a** kaydediyor (isApproved: false)
5. **Admin panelinde** görünüyor

## 🔍 Kontrol ve Takip

### Firebase Console'dan Kontrol:
- **Functions:** https://console.firebase.google.com/project/sicak-firsatlar-e6eae/functions
- **Scheduler:** https://console.cloud.google.com/cloudscheduler?project=sicak-firsatlar-e6eae
- **Logs:** https://console.cloud.google.com/logs/query?project=sicak-firsatlar-e6eae

### Terminal'den Kontrol:
```bash
# Function listesini görüntüle
firebase functions:list

# Logları izle
firebase functions:log --only fetchChannelMessages

# Config'i görüntüle
firebase functions:config:get
```

## 🛑 Botu Durdurma

Botu durdurmak için:

### Yöntem 1: Cloud Scheduler'dan Pause Et (Önerilen)
1. https://console.cloud.google.com/cloudscheduler?project=sicak-firsatlar-e6eae
2. `firebase-schedule-fetchChannelMessages` job'unu bulun
3. **PAUSE** butonuna tıklayın

### Yöntem 2: Function'ı Sil
```bash
firebase functions:delete fetchChannelMessages
```

## 📝 Sorun Giderme

### Bot çalışmıyor:
1. Credentials doğru mu? → `firebase functions:config:get`
2. Function deploy edildi mi? → `firebase functions:list`
3. Scheduler aktif mi? → Cloud Console'dan kontrol
4. Logları kontrol et → `firebase functions:log`

### "Credentials eksik" hatası:
- Adım 3'teki komutu tekrar çalıştırın
- Deploy edin: `firebase deploy --only functions:fetchChannelMessages`

### Session expired hatası:
- Yeni session string oluşturun (Adım 2)
- Config'i güncelleyin (Adım 3)
- Deploy edin

## 💰 Maliyet

Firebase Cloud Functions:
- **İlk 2 milyon çağrı:** Ücretsiz
- **Her 5 dakika = 12 çağrı/saat = 288 çağrı/gün**
- **Ayda ~8,640 çağrı** (Ücretsiz kotanın çok altında)

## ✅ Tamamlandı!

Bot başarıyla kuruldu ve Google Cloud'da çalışıyor! 🎉
