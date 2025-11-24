# 🛑 Firebase Function'ı Durdurma Rehberi

## Yöntem 1: Cloud Scheduler'dan Schedule'ı Pause Et (Önerilen)

`fetchChannelMessages` bir scheduled function olduğu için, Cloud Scheduler'dan schedule'ı pause etmek en temiz yöntemdir.

### Adımlar:

1. **Google Cloud Console'a gidin:**
   - https://console.cloud.google.com/cloudscheduler?project=sicak-firsatlar-e6eae
   - Veya Firebase Console'dan: **Functions** → **fetchChannelMessages** → **View in Cloud Console**

2. **Schedule'ı bulun:**
   - `fetchChannelMessages` veya `firebase-schedule-fetchChannelMessages` adlı schedule'ı bulun

3. **Pause edin:**
   - Schedule'a tıklayın
   - Üstteki **"PAUSE"** butonuna tıklayın
   - Onaylayın

4. **Kontrol edin:**
   - Schedule durumu "Paused" olarak görünmeli
   - Function artık otomatik çalışmayacak

## Yöntem 2: Firebase Console'dan Function'ı Sil

⚠️ **Dikkat:** Bu yöntem function'ı tamamen siler. Tekrar kullanmak için yeniden deploy etmeniz gerekir.

### Adımlar:

1. **Firebase Console'da Functions sayfasına gidin:**
   - https://console.firebase.google.com/project/sicak-firsatlar-e6eae/functions

2. **Function'ı bulun:**
   - `fetchChannelMessages` function'ını bulun

3. **Silin:**
   - Function satırının sağındaki **üç nokta (⋮)** menüsüne tıklayın
   - **"Delete"** seçeneğini seçin
   - Onaylayın

## Yöntem 3: Cloud Console'dan Function'ı Pause Et

1. **Google Cloud Console'a gidin:**
   - https://console.cloud.google.com/functions?project=sicak-firsatlar-e6eae

2. **Function'ı bulun:**
   - `fetchChannelMessages` function'ını bulun

3. **Pause edin:**
   - Function'a tıklayın
   - Üstteki **"PAUSE"** butonuna tıklayın
   - Onaylayın

## ✅ Kontrol

Function durdurulduktan sonra:

1. **Firebase Console'da kontrol:**
   - Functions sayfasında function durumu değişmeli
   - 24 saat içinde yeni request'ler gelmemeli

2. **Logları kontrol:**
   ```bash
   firebase functions:log --only fetchChannelMessages
   ```
   - Yeni log girişleri olmamalı

## 🔄 Tekrar Aktif Etme

Function'ı tekrar aktif etmek için:

### Eğer Pause ettiniz:
- Cloud Scheduler veya Cloud Console'dan **"RESUME"** butonuna tıklayın

### Eğer Sildiniz:
- `functions/index.js` dosyasındaki yorum satırlarını kaldırın
- Deploy edin: `firebase deploy --only functions:fetchChannelMessages`

## 📊 Mevcut Durum

Ekran görüntüsüne göre:
- `fetchChannelMessages`: **Aktif** (24 saatte 288 request)
- Trigger: Scheduled (her 5 dakikada bir)
- Timeout: 9 dakika

Bu function'ı durdurmak için **Yöntem 1 (Cloud Scheduler'dan Pause)** en önerilen yöntemdir.





