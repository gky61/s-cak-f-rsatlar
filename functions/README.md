# ⚡ Firebase Cloud Functions — FırsatKolik Backend

Bu klasör, FırsatKolik platformunun reaktif veritabanı trigger'larını, zamanlanmış bakım cron görevlerini ve güvenli API proxy'lerini barındıran **25 adet Cloud Function**'ı içerir (`index.js`).

---

## 📋 Kurulum ve Çalıştırma

### 1. Gereksinimler
- **Node.js:** v20 veya v22
- **Firebase CLI:** `firebase-tools` güncel sürüm

```bash
cd functions
npm install
```

### 2. Dağıtım (Deploy)

```bash
# DEV Ortamına Dağıtım
firebase use dev
firebase deploy --only functions

# PROD (Canlı) Ortamına Dağıtım
firebase use prod
firebase deploy --only functions --force
```

---

## 🔔 25 Cloud Function Özeti

1. **Fırsat & Yorum:** `onDealCreated`, `onDealUpdated`, `onCommentCreated`
2. **Mesajlaşma & Bildirim:** `onNotificationCreated` (Merkezi FCM V1 push motoru), `onUserMessageCreated`, `onAdminMessageCreated`
3. **Kullanıcı & Profil:** `onUserUpdated` (Denormalize avatar/isim sync), `onUserDeleted`, `adminDeleteUser`
4. **API & Güvenli Proxy:** `resolveShortLink`, `analyzeProductProxy` (App Check & Secret Manager korumalı Gemini AI proxy), `sendManualNotification`
5. **Temizlik & Arşiv Cron:** `cleanupExpiredDeals` (48h soft-expire), `purgeOldDeals` (30 gün hard-purge), `cleanupOldImages` (Storage garbage collector), `cleanupInvalidTokens`
6. **Kupon & Katalog Kazıyıcılar:** `scrapeCouponsScheduled` / `scrapeCouponsManual`, `scrapeCatalogsScheduled` / `scrapeCatalogsManual`
7. **Test & Geliştirici:** `generateTestData`, `cleanupTestData`

---

## 📚 Detaylı Dokümantasyon
Her bir fonksiyonun kaynak kodu, tetiklenme şartları, yetki modeli ve kullanım senaryoları için ana rehberi inceleyiniz:
👉 [Cloud Functions ve Backend Servisleri Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/cloud_functions_rehberi.md)
