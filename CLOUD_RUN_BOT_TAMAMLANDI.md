# 🎉 Cloud Run Real-Time Telegram Bot - Başarıyla Kuruldu!

## ✅ Bot Durumu: AKTIF ve ÇALIŞIYOR

**Service URL:** https://telegram-bot-560592268193.us-central1.run.app  
**Deploy Tarihi:** 2026-01-31  
**Çalışma Modu:** 7/24 Real-Time  

---

## 🤖 Bot Özellikleri

### ✅ Aktif Özellikler:
- **Real-time mesaj dinleme** - Yeni mesaj gelir gelmez yakalar
- **Link filtreleme** - Sadece link içeren mesajları işler
- **Otomatik Firebase kaydı** - Mesajları direkt Firestore'a kaydeder
- **Admin onay sistemi** - Fırsatlar `isApproved: false` ile kaydedilir
- **Otomatik yeniden bağlanma** - Bağlantı koparsa otomatik düzeltir
- **Health monitoring** - Servis sağlığı takip edilebilir

### 📡 Dinlenen Kanallar:
1. **@indirimkaplani** ✅

---

## 🎯 Bot Nasıl Çalışıyor?

```
Telegram Kanalı (@indirimkaplani)
           ↓
    🤖 Cloud Run Bot (7/24 dinliyor)
           ↓
    Link var mı kontrol et
           ↓
    Fiyat, başlık çıkar
           ↓
    Firebase Firestore'a kaydet
    (isApproved: false)
           ↓
    Flutter App - Admin Panel
    "Onay Bekleyenler" sekmesi
           ↓
    Admin Onaylar
           ↓
    Kullanıcılara bildirim gider
```

---

## 📊 Kontrol ve İzleme

### Cloud Console'dan:
- **Service:** https://console.cloud.google.com/run/detail/us-central1/telegram-bot?project=sicak-firsatlar-e6eae
- **Logs:** https://console.cloud.google.com/logs/query?project=sicak-firsatlar-e6eae
- **Metrics:** https://console.cloud.google.com/monitoring?project=sicak-firsatlar-e6eae

### Terminal'den:
```bash
# Logları izle
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=telegram-bot" --project sicak-firsatlar-e6eae

# Servis durumu
gcloud run services describe telegram-bot --region us-central1 --project sicak-firsatlar-e6eae

# Son 50 log
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=telegram-bot" --limit 50 --project sicak-firsatlar-e6eae
```

---

## 🔧 Yönetim

### Botu Durdurma:
```bash
gcloud run services update telegram-bot \
  --region us-central1 \
  --project sicak-firsatlar-e6eae \
  --min-instances 0
```

### Botu Tekrar Başlatma:
```bash
gcloud run services update telegram-bot \
  --region us-central1 \
  --project sicak-firsatlar-e6eae \
  --min-instances 1
```

### Yeni Kanal Ekleme:
1. `cloud-run-bot/env.yaml` dosyasını düzenle
2. `TELEGRAM_CHANNELS: "@kanal1,@kanal2"` şeklinde ekle
3. Deploy et:
```bash
cd cloud-run-bot
gcloud run services update telegram-bot \
  --region us-central1 \
  --project sicak-firsatlar-e6eae \
  --env-vars-file env.yaml
```

---

## 💰 Maliyet

**Cloud Run Pricing:**
- CPU: $0.00002400/vCPU-second
- Memory: $0.00000250/GiB-second
- Minimum instance (her zaman çalışır): 1

**Tahmini Aylık Maliyet:** $5-10
- 512MB RAM
- 1 vCPU
- 7/24 aktif

**Ücretsiz Kota:**
- İlk 2 milyon request: Ücretsiz
- İlk 360,000 vCPU-seconds: Ücretsiz
- İlk 180,000 GiB-seconds: Ücretsiz

Bot düşük trafikle çalıştığı için **muhtemelen ücretsiz kotada kalacak!**

---

## 🔐 Güvenlik

### Environment Variables:
- ✅ TELEGRAM_API_ID
- ✅ TELEGRAM_API_HASH
- ✅ TELEGRAM_SESSION_STRING
- ✅ TELEGRAM_CHANNELS

**Güvenlik Notları:**
- Session string Cloud Run environment'da saklanıyor
- Dışarıdan erişilemiyor (sadece bot kullanıyor)
- Firebase Authentication otomatik (service account)

---

## 📝 Firebase Functions ile Farklar

### ❌ Eski (Firebase Functions):
- Her 5 dakikada bir kontrol eder
- Son mesajları çeker
- Gecikmeli çalışır
- Bazı mesajları kaçırabilir

### ✅ Yeni (Cloud Run):
- **7/24 sürekli dinler**
- Yeni mesaj gelir gelmez yakalar
- **Anında** Firebase'e gönderir
- Hiçbir mesaj kaçmaz
- Link olan mesajları filtreler

---

## 🎯 Test

### Bot Çalışıyor mu Test Et:

1. **@indirimkaplani** kanalına bir link içeren mesaj gönderin
2. **10 saniye bekleyin**
3. **Flutter uygulamanızda Admin Panel'e gidin**
4. **"Onay Bekleyenler"** sekmesine bakın
5. Yeni fırsat orada görünmeli! ✅

---

## 🛑 Sorun Giderme

### Bot mesaj yakalamıyor:
```bash
# Logları kontrol et
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=telegram-bot" --project sicak-firsatlar-e6eae

# Servis çalışıyor mu?
gcloud run services describe telegram-bot --region us-central1 --project sicak-firsatlar-e6eae
```

### Session expired hatası:
1. `cd cloud-run-bot`
2. `node create_session.js` çalıştır
3. Yeni session string al
4. `env.yaml` dosyasını güncelle
5. Deploy et

### Kanal bulunamıyor:
- Kanal username doğru mu? (@username)
- Kanal public mi?
- Bot kanalda üye mi?

---

## 🎊 BAŞARILI!

**Telegram botunuz artık Google Cloud Run'da 7/24 çalışıyor!** 🚀

- ✅ Real-time mesaj yakalama
- ✅ Otomatik Firebase kaydı
- ✅ Link filtreleme
- ✅ Admin onay sistemi
- ✅ Düşük maliyet (~$5/ay veya ücretsiz)

**Son Güncelleme:** 2026-01-31  
**Status:** AKTIF ✅
