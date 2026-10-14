# ⚡ Firebase Cloud Functions — FırsatKolik Backend

Bu klasör, FırsatKolik platformunun reaktif veritabanı trigger'larını, zamanlanmış bakım cron görevlerini ve güvenli API proxy'lerini barındıran **27 adet Cloud Function**'ı içerir (25 Temel + 2 DEV Test Aracı; `index.js`).

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

## 🔔 27 Cloud Function Özeti (25 Temel + 2 DEV Test Aracı)

1. **Fırsat, Kupon & Yorum (5):** `onDealCreated`, `onDealUpdated`, `onCommentCreated`, `onCouponCreated`, `onCouponUpdated`
2. **Mesajlaşma & Bildirim (3):** `onNotificationCreated` (Merkezi FCM V1 push motoru), `onUserMessageCreated`, `onAdminMessageCreated`
3. **Kullanıcı & Profil (4):** `onUserUpdated` (Denormalize avatar/isim sync), `onUserDeleted`, `adminDeleteUser`, `revokeAppleToken`
4. **API & Güvenli Endpoint'ler (3):** `resolveShortLink`, `sendManualNotification`, `getObservabilityMetrics`
5. **Temizlik & Arşiv Cron (6):** `cleanupExpiredDeals` (02:30 TSİ 48h soft-expire), `purgeOldDeals` (03:30 TSİ 30 gün hard-purge: fırsatlar + eski bildirimler + sistem logları), `purgeOldDealsManual`, `purgeOldNotificationsManual`, `cleanupOldImages` (00:00 TSİ Storage çöp toplayıcı), `cleanupInvalidTokens`
6. **Kupon & Katalog Kazıyıcılar (4):** `scrapeCouponsScheduled` (04:00 TSİ) / `scrapeCouponsManual`, `scrapeCatalogsScheduled` (03:00 TSİ) / `scrapeCatalogsManual`
7. **Test & Geliştirici (2 - Yalnızca DEV, PROD korumalı):** `generateTestData`, `cleanupTestData`

---

## 📚 Detaylı Dokümantasyon
Her bir fonksiyonun kaynak kodu, tetiklenme şartları, yetki modeli ve kullanım senaryoları için ana rehberi inceleyiniz:
👉 [Cloud Functions ve Backend Servisleri Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/cloud_functions_rehberi.md)
