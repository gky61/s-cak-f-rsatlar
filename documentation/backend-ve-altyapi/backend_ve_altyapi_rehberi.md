# ⚡ FırsatKolik — Backend ve Bulut Altyapısı Master Mimari Rehberi

> [!IMPORTANT]
> **Base Doküman & Altyapı Kontratı:** Bu doküman, FırsatKolik platformunun backend, bulut fonksiyonları, veritabanı kuralları, ortam yönetimi ve sunucu altyapısını yöneten **ana orkestratör (Base Contract)** dokümandır.
> Sistemin tüm katmanlarındaki kritik risk ve felaket senaryoları analizi için lütfen **[Felaket Senaryoları ve Sistem Güvenlik Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/felaket_senaryolari_ve_sistem_guvenlik_rehberi.md)** dokümanını inceleyiniz.

Bu doküman; **FırsatKolik** platformunun sunucu (Firebase Cloud Functions v1/v2), veritabanı (Cloud Firestore), dosya depolama (Firebase Storage), kimlik doğrulama (Firebase Auth), anlık bildirim (FCM v1), güvenlik katmanı (Firestore & Storage Security Rules, App Check), ortam yönetimi (DEV vs PROD Flavors), Compute Engine VM bot sunucusu ve sıfır maliyet mimarisini tanımlayan **resmi mimari sözleşmedir (Documentation Contract)**.

---

## 📑 İçindekiler
1. [🌟 Genel Backend Mimarisi ve Altyapı Bileşenleri](#1--genel-backend-mimarisi-ve-altyapı-bileşenleri)
2. [⚡ 27 Cloud Function Tam Envanteri ve Tetikleme Sözleşmesi](#2--27-cloud-function-tam-envanteri-ve-tetikleme-sözleşmesi)
3. [⚙️ Ortam Yönetimi ve Flavor Mimarisi (DEV vs PROD)](#3-️-ortam-yönetimi-ve-flavor-mimarisi-dev-vs-prod)
4. [🔒 Firestore ve Storage Güvenlik Mimarisi (Security Rules & RBAC)](#4-️-firestore-ve-storage-güvenlik-mimarisi-security-rules--rbac)
5. [💰 Google Cloud Sıfır Maliyet Mimarisi ve Free Tier VM](#5--google-cloud-sıfır-maliyet-mimarisi-ve-free-tier-vm)
6. [🔑 Gizli Bilgiler, API Anahtarları ve Keystore Envanteri](#6--gizli-bilgiler-api-anahtarları-ve-keystore-envanteri)
7. [🧹 30 Günlük Veri Saklama ve Otomatik Temizlik (Purge/Cron)](#7--30-günlük-veri-saklama-ve-otomatik-temizlik-purgecron)
8. [🛡️ Firebase App Check ve Play Integrity Güvenliği](#8-️-firebase-app-check-ve-play-integrity-güvenliği)
9. [💻 Web Admin Paneli Backend Entegrasyonu (Hosting & Callable)](#9--web-admin-paneli-backend-entegrasyonu-hosting--callable)
10. [🧪 Backend Test Süitleri ve Doğrulama](#10--backend-test-süitleri-ve-doğrulama)
11. [🔧 Sorun Giderme ve Hata Ayıklama (Troubleshooting)](#11--sorun-giderme-ve-hata-ayıklama-troubleshooting)
12. [📂 İlgili Kaynak Kod Dosyaları ve Referanslar](#12--ilgili-kaynak-kod-dosyaları-ve-referanslar)

---

## 1. 🌟 Genel Backend Mimarisi ve Altyapı Bileşenleri

FırsatKolik backend altyapısı, yüksek performans, sıfır sunucu bakım yükü (serverless) ve minimum maliyet hedefleriyle tasarlanmış hibrit bir bulut ekosistemidir:

```mermaid
graph TD
    %% İstemci Katmanı
    Client[Mobil İstemci: Flutter Android / iOS] --> Auth[Firebase Authentication]
    Client --> DB[(Cloud Firestore)]
    Client --> Storage[Firebase Storage: deals/]
    Client --> AppCheck[Firebase App Check: Play Integrity / Debug]
    
    %% Web Admin Katmanı
    WebAdmin[Web Admin Paneli: Vanilla JS Hosting] --> DB
    WebAdmin --> Auth
    WebAdmin --> CallableFunctions[HTTPS Callable Cloud Functions]
    
    %% Backend & Sunucusuz Fonksiyonlar
    DB -->|onCreate / onUpdate| Triggers[Firestore Trigger Cloud Functions]
    Auth -->|onDelete| AuthTrigger[Auth Trigger: onUserDeleted]
    Scheduler[GCP Cloud Scheduler] -->|Cron Job| ScheduledFunctions[Zamanlanmış Cloud Functions]
    
    %% Otonom Bot VM Katmanı
    VM[Google Compute Engine Free Tier VM: e2-micro] -->|7/24 Telegram Dinleyici| Bot[Docker: telegram-bot.js]
    Bot -->|Admin SDK| DB
    Bot -->|Admin SDK| Storage
    
    %% Bildirim Dağıtımı
    Triggers -->|onNotificationCreated| FCM[Firebase Cloud Messaging: FCM HTTP v1]
    FCM --> Client
```

### Temel Mimari Bileşenler:
1. **Cloud Firestore:** NoSQL doküman tabanlı veritabanı. Fırsatlar, yorumlar, kullanıcılar, kuponlar, aktüel kataloglar ve bildirim kutularını yönetir.
2. **Firebase Cloud Functions (Node.js):** 27 adet sunucusuz fonksiyon (`functions/index.js`). Firestore tetikleyicileri, callable admin API'leri, zamanlanmış cron görevleri, HTTPS proxy servisleri ve Observability telemetri köprüsünü barındırır.
3. **Google Compute Engine VM (`telegram-bot-server`):** Free Tier `e2-micro` makinede çalışan Docker container'ları ile Telegram indirim kanallarını 7/24 dinler.
4. **Firebase Cloud Messaging (FCM HTTP v1):** 7 Android bildirim kanalı ve iOS APNs entegrasyonu ile akıllı push dağıtımı sağlar.
5. **Firebase Storage:** Fırsat görsellerini ve aktüel broşürlerini barındırır.

---

## 2. ⚡ 27 Cloud Function Tam Envanteri ve Tetikleme Sözleşmesi

> 🔗 **Detaylı Referans Dokümanı:**
> - [Cloud Functions ve Backend Servisleri Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/cloud_functions_rehberi.md) — 27 fonksiyonun tetiklenme türleri, parametreleri ve somut kullanım senaryoları.

Tüm backend fonksiyonları [functions/index.js](file:///d:/firsatkolik/functions/index.js) içerisinde modüler olarak tanımlanmıştır:

| # | Fonksiyon Adı | Tetikleyici Türü | Çağrıldığı / Tetiklendiği Yer | Sorumluluk ve Çalışma Mantığı |
|---|---|---|---|---|
| 1 | **`onDealCreated`** | Firestore `deals/{dealId}` (onCreate) | Mobil Paylaşım, Bot, Web Admin | Küfür/profanity moderasyonu yapar. Fırsat onaysız ise `admin_deals` FCM konusuna admin bildirimi gönderir. Onaylıysa bildirimleri üretir (`matchAndCreateDealNotifications`). |
| 2 | **`onDealUpdated`** | Firestore `deals/{dealId}` (onUpdate) | Admin Onay/Düzenleme, Oylama | `!wasApproved && isNowApproved` geçişinde herkese bildirim üretir. Kullanıcı paylaşımı onaylandığında/reddedildiğinde `submission_status` yazar. Bot fırsatı oylarında gereksiz kullanıcı profili yazmasını engelleyerek kota korur. |
| 3 | **`onCommentCreated`** | Firestore `deals/{id}/comments/{id}` (onCreate) | Detay Ekranı Yorum Alanı | Yorum moderasyonu yapar. İlanın `commentCount` sayacını atomik artırır. Yanıt ise alıcıya `comment_reply` bildirimi oluşturur. |
| 4 | **`onAdminMessageCreated`** | Firestore `adminToUserMessages/{id}` (onCreate) | Web Admin Paneli Duyuruları | Admin panelinden kullanıcıya bireysel mesaj atıldığında `users/{uid}/notifications` dokümanı yazar (Çift kalkan deduplication ve içerik fallback korumalı). |
| 5 | **`onUserMessageCreated`** | Firestore `messages/{id}` (onCreate) | Birebir Sohbet Ekranı | Birebir sohbette yeni mesaj geldiğinde alıcının cihazlarına **Data-Only Payload** iletir (Aktif sohbette bildirimi bastırır). |
| 6 | **`onNotificationCreated`** | Firestore `users/{uid}/notifications/{id}` (onCreate) | Merkezi Push Motoru | Sistem şalteri, sessiz saatler, kategori limitleri, kullanıcı tercihleri ve cihaz token kontrollerini yaparak FCM push gönderir. |
| 7 | **`onUserUpdated`** | Firestore `users/{userId}` (onUpdate) | Profil Düzenleme | Profil resmi veya kullanıcı adı değiştiğinde yorumlar, mesajlar ve fırsatlardaki denormalize verileri senkronize eder (Limit 300, no-op eleme ve izole batching korumalı). |
| 8 | **`onUserDeleted`** | Auth `user().onDelete` | Kullanıcı Hesabı Silme | KVKK/GDPR tam uyumlu: Kullanıcı silindiğinde cihazlar, abonelikler, fırsatlar (alt yorumlar ve Storage görselleri dahil), yorumlar, mesajlar, raporlar ve profil alt koleksiyonlarını 400'lük döngüsel batch'lerle kalıcı temizler (500 batch limit korumalı). |
| 9 | **`resolveShortLink`** | HTTPS Request (`onRequest`) | Flutter App & Web Admin | Kısa linkleri ve yönlendirmeleri (redirect) takip ederek gerçek son URL'yi çözer (Kurumsal düzey SSRF engelleme, döngüsel redirect tespiti, RFC 3986 göreli URL ve HEAD->GET otomatik fallback korumalı). |
| 10 | **`onCouponCreated`** | Firestore `kuponlar/{kuponId}` (onCreate) | Kupon Paylaşımı & Bot | Yeni indirim kuponu oluşturulduğunda küfür/argo moderasyonu yapar, mağaza/yazar aboneliği ve 300 aktif kullanıcı tavanıyla (120s timeout / 512MB RAM) kaskat çökme ve zaman aşımını önler. |
| 11 | **`sendManualNotification`** | HTTPS Callable (`onCall`) | Web Admin Paneli (`app.js`) | Admin panelinden tüm kullanıcılara Topic yayını (`sicak_firsatlar_general_v2`) ile anlık teslimat sağlar, bildirim kutusu yazımını 500 aktif kullanıcı ile sınırlar (300s timeout / 512MB RAM, APNs alert ve header tam uyumlu). |
| 12 | **`cleanupInvalidTokens`** | HTTPS Callable (`onCall`) | Web Admin Paneli (`app.js`) | `userDevices` içerisindeki aktif FCM token'ları `dryRun: true` ile test ederek geçersiz olanları pasife alır (20'li eşzamanlılık havuzlama, FCM hata kodları ve 400'lük atomik batch güncelleme korumalı). |
| 13 | **`cleanupExpiredDeals`** | Scheduled Cron (`0 3 * * *` - Gece 03:00) | GCP Cloud Scheduler | 48 saati dolduran fırsatları bulur; dokümanı **SİLMEZ**, sadece `isExpired: true` olarak işaretler (Bileşik indeksli ve 7 günlük bounded fallback korumalı). |
| 14 | **`cleanupExpiredDealsManual`** | HTTPS Request (`onRequest`) | Manuel HTTP Endpoint | 48 saatlik soft-expire işlemini manuel test eder; yönetici kimlik doğrulaması (`_verifyAdminOrInternalSecret`) ve 60 saniyelik debounce DoS kalkanı içerir. |
| 15 | **`purgeOldDeals`** | Scheduled Cron (`0 4 * * 0` - Pazar 04:00) | GCP Cloud Scheduler | **30 Günlük Derin Temizlik:** 30 günden eski fırsatları, yorumları, oyları, Storage görsellerini ve **tüm kullanıcılardaki (`collectionGroup('notifications')`) bildirimleri** 400'lük batch parçalarıyla kalıcı siler (Kullanıcı favorileri lazy self-healing olarak temizlenir). |
| 16 | **`purgeOldDealsManual`** | HTTPS Callable (`onCall`) | Web Admin Paneli & Scriptler | 30 günlük derin temizliği (fırsatlar + eski bildirimler) admin yetkisiyle manuel tetikler (Opsiyonel `days` parametresi). |
| 17 | **`purgeOldNotificationsManual`** | HTTPS Callable (`onCall`) | Web Admin & Scriptler | Fırsatlara dokunmadan, yalnızca `collectionGroup('notifications')` koleksiyonundaki 30+ günlük bildirim dokümanlarını 10.000 tavanlı devre kesici ile toplu siler. |
| 18 | **`cleanupOldImages`** | Scheduled Cron (`0 0 * * *` - Gece 00:00) | GCP Cloud Scheduler | Firebase Storage `deals/` dizinindeki 40 günden eski sahipsiz/çöp görselleri 10'arlı paralel chunk'lar halinde temizler (Kırık görsel koruması). |
| 19 | **`cleanupOldImagesManual`** | HTTPS Request (`onRequest`) | Manuel HTTP Endpoint | Storage görsel temizliğini manuel test eder; yönetici kimlik doğrulaması, 35 gün katı alt sınır güvenlik mandalı (`Math.max(35, days)`) ile canlı görsel koruması ve 1000 dosya tavanı sunar. |
| 20 | **`adminDeleteUser`** | HTTPS Callable (`onCall`) | Web Admin Paneli (`app.js`) | Admin yetkisiyle kullanıcı siler; kendi hesabını ve diğer yöneticileri silme koruması, Auth desenkronizasyonunda sahipsiz Firestore verilerini 400'lük batch'lerle kaskat temizleme güvencesi sunar. |
| 21 | **`generateTestData`** | HTTPS Callable (`onCall`) | Web Admin Paneli (`app.js`) | Test ortamı için sahte veri üretir; sıkı `dealsCount: [1, 10]` kotası, `@test.firsatkolik.com` e-posta zorunluluğu ve `isTest: true` izolasyonu barındırır. |
| 22 | **`cleanupTestData`** | HTTPS Callable (`onCall`) | Web Admin Paneli (`app.js`) | Sahte test kullanıcılarını ve fırsatlarını temizler; indeksli kullanıcı sorgusu, döngüsel sahipsiz test fırsatları temizliği (%100 yok etme) ve 5'li eşzamanlılık havuzu içerir. |
| 23 | **`scrapeCouponsScheduled`** | Scheduled Cron (`0 4 * * *` - Gece 04:00) | GCP Cloud Scheduler | Kupon kaynaklarını (DH, Kuponla, Kuponburada) otonom tarar; dağıtık mutex kilidi, yaz-sonra-sil güvencesi ve 400'lük batch parçalarıyla kaydeder. |
| 24 | **`scrapeCouponsManual`** | HTTPS Callable (`onCall`) | Web Admin Paneli (`app.js`) | Kupon kazıma botunu admin yetkisiyle anlık tetikler (Dağıtık mutex kilidi ile gece cron'u çakışması ve 429 WAF engeli önlenir). |
| 25 | **`scrapeCatalogsScheduled`** | Scheduled Cron (`0 3 * * *` - Gece 03:00) | GCP Cloud Scheduler | 36 market afişini otonom tarar; atomic merge upsert ile sıfır kesinti sunar, yalnızca yayından kalkan eskimiş broşürleri 400 batch parçalarıyla temizler. |
| 26 | **`scrapeCatalogsManual`** | HTTPS Callable (`onCall`) | Web Admin Paneli (`app.js`) | Broşür kazıma botunu admin yetkisiyle anlık tetikler (Dağıtık kilit korumalı ve 400 batch uyumlu). |
| 27 | **`getObservabilityMetrics`** | HTTPS Callable (`onCall`) | Web Admin (`observability_manager.js`) | Web Admin Modül 11 için GA4 Data API ve telemetri verilerini güvenle çeker; çoklu admin alan doğrulaması, `.select()` hafif fırsat projeksiyonu ve GA4 graceful degradation içerir. |

---

## 3. ⚙️ Ortam Yönetimi ve Flavor Mimarisi (DEV vs PROD)

> 🔗 **Detaylı Referans Dokümanları:**
> - [Ortam Yönetimi ve Canlıya Geçiş Kılavuzu](file:///d:/firsatkolik/documentation/backend-ve-altyapi/environment_management_guide.md) — DEV/PROD build komutları, Play Store AAB derleme ve Shorebird live code push stratejileri.
> - [DEV vs PROD Eşitleme ve Senkronizasyon Kılavuzu](file:///d:/firsatkolik/documentation/backend-ve-altyapi/dev_prod_synchronization_and_audit_guide.md) — 18 noktalı denetim matrisi, eşitleme komutları ve pre-flight kontrol listesi.

FırsatKolik, **Geliştirme (DEV)** ve **Canlı (PROD)** olmak üzere iki tamamen izole Firebase projesi ve derleme ortamı üzerinde çalışır:

| Parametre | DEV (Geliştirme / Test) | PROD (Canlı / Production) |
| :--- | :--- | :--- |
| **Firebase Proje ID** | `sicak-firsatlar-e6eae` | `firsatkolik-prod-e6eae` |
| **Android Paket Adı** | `com.sicakfirsatlar.sicak_firsatlar` | `com.firsatkolik.app` |
| **Uygulama Görünen Adı** | **FırsatKolik Dev** | **FırsatKolik** |
| **Target SDK / Java** | Android SDK 36 / Java 17 | Android SDK 36 / Java 17 |
| **Flavor Tanımı** | `--flavor dev --dart-define=FLAVOR=dev` | `--flavor prod --dart-define=FLAVOR=prod` |
| **AdMob Reklamları** | Google Test Native ID (`ca-app-pub-3940...`) | Gerçek Native ID (`ca-app-pub-6853...`) (Faz 3.3) |
| **App Check Sağlayıcısı**| Debug Provider (Debug Token) | Play Integrity API (Google Play Store) |
| **Android Keystore** | Varsayılan Debug Keystore | `android/app/upload-keystore.jks` (Alias: upload) |
| **Cloud Functions** | 27 Bağımsız Fonksiyon (İzole Trigger & Cron) | 27 Bağımsız Fonksiyon (İzole Trigger & Cron) |
| **Web Admin URL** | `localhost:5000` / `sicak-firsatlar-e6eae.web.app` | `https://firsatkolik-prod-e6eae.web.app` ve `firsatkolik.app` |
| **Telegram Bot Portu** | Port `8081` (`dev-bot` Container) | Port `8082` (`prod-bot` Container) |
| **Cihazda Yan Yana Kurulum** | Desteklenir (Paket ID: `com.sicakfirsatlar...`) | Desteklenir (Paket ID: `com.firsatkolik.app`) |

### Hızlı Operasyon Komutları:
```bash
# 1. Mobil Uygulamayı Başlatma
flutter run -d <cihaz> --flavor dev --dart-define=FLAVOR=dev
flutter run -d <cihaz> --flavor prod --dart-define=FLAVOR=prod

# 2. Google Play Store AAB Derlemesi
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release

# 3. Cloud Functions Dağıtımı
firebase deploy --only functions --project dev
firebase deploy --only functions --project prod

# 4. Güvenlik Kuralları Dağıtımı
firebase deploy --only firestore:rules,storage --project dev
firebase deploy --only firestore:rules,storage --project prod

# 5. Web Admin Panelini Yayınlama
firebase deploy --only hosting --project dev
firebase deploy --only hosting --project prod
```

---

## 4. 🔒 Firestore ve Storage Güvenlik Mimarisi (Security Rules & RBAC)

> 🔗 **Detaylı Referans Dokümanı:**
> - [Firestore ve Storage Güvenlik Kuralları Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/firestore_ve_storage_guvenlik_kurallari_rehberi.md) — RBAC, `isAdmin()`, `isBlocked()`, field-level diffing ve collectionGroup kuralları.

Güvenlik kuralları ([firestore.rules](file:///d:/firsatkolik/firestore.rules) ve [storage.rules](file:///d:/firsatkolik/storage.rules)) 4 temel prensip üzerine kuruludur:

1. **Rol Tabanlı Erişim Denetimi (RBAC):** `isAdmin()` fonksiyonu ile `users/{uid}.isAdmin == true` alanı doğrulanır.
2. **Kullanıcı Engelleme Denetimi (`isBlocked()`):** `blockedUsers/{uid}` koleksiyonunda kaydı bulunan kullanıcıların veri yazması engellenir (`canWrite()`).
3. **Alan Düzeyinde Fark Doğrulaması (Field-Level Diffing):** Normal kullanıcıların fırsatların başlık/fiyat gibi kritik alanlarını değiştirmesi engellenir; yalnızca oy ve sayaç alanlarını (`hotVotes`, `coldVotes`, `expiredVotes`, `commentCount`, `updatedAt`) güncellemelerine izin verilir:
   ```rules
   allow update: if canWrite() && (
     resource.data.postedBy == userId() || 
     isAdmin() ||
     request.resource.data.diff(resource.data).affectedKeys()
       .hasOnly(['hotVotes', 'coldVotes', 'expiredVotes', 'isExpired', 'commentCount', 'updatedAt'])
   );
   ```
4. **Collection Group Yetkilendirmesi:** 30+ günlük bildirim temizliği için `collectionGroup('notifications')` sorguları yalnızca yöneticilere açıktır:
   ```rules
   match /{path=**}/notifications/{notificationId} {
     allow read, write: if isAdmin();
   }
   ```

---

## 5. 💰 Google Cloud Sıfır Maliyet Mimarisi ve Free Tier VM

> 🔗 **Detaylı Referans Dokümanı:**
> - [Google Cloud Maliyet Analizi ve Optimizasyon Raporu](file:///d:/firsatkolik/documentation/backend-ve-altyapi/google_cloud_cost_analysis.md) — Cloud Run maliyet analizi, Compute Engine e2-micro geçişi ve PM2/Docker optimizasyonları.

Projenin başlangıcında Cloud Run üzerinde çalışan botların 7/24 açık kalması sebebiyle aylık ~130$ (4.400 TL) faturalandırma oluştuğu tespit edilmiş; ardından **Google Cloud Free Tier VM** mimarisine geçilmiştir:

### Uygulanan Tasarruf Mimarisi:
1. **Google Compute Engine e2-micro:** `firsatkolik-prod-e6eae` projesinde `us-central1-a` bölgesinde yer alan ücretsiz `e2-micro` (2 vCPU, 1 GB RAM, 10 GB disk) sanal makinesi tahsis edildi (`telegram-bot-server`).
2. **Docker Container İzolasyonu:**
   - **DEV Bot:** Port `8081` üzerinde `dev-bot` container'ı olarak çalışır ve `dev_firebase_key.json` ile DEV veritabanını besler.
   - **PROD Bot:** Port `8082` üzerinde `prod-bot` container'ı olarak çalışır ve `prod_firebase_key.json` ile PROD veritabanını besler.
3. **Otomasyon (`deploy_to_vm.py`):** Google Cloud Build üzerinden build edilen imaj VM üzerinde tek komutla güncellenir ve eski Docker imajları otomatik prune edilir.
4. **Maliyet Etkisi:** Aylık bot ve sunucu giderleri **130$'dan 0$'a düşürülerek sıfır maliyet hedefine ulaşılmıştır.**

---

## 6. 🔑 Gizli Bilgiler, API Anahtarları ve Keystore Envanteri

> 🔗 **Detaylı Referans Dokümanı:**
> - [Güncellenmiş Özel ve Gizli Bilgiler Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/project_secrets_and_credentials_updated.md) — DEV/PROD API anahtarları, Telegram bot string sessions, AdMob IDs, Keystore ve App Check tokenları.

| Ortam / Servis | Parametre | Değer / Açıklama |
| :--- | :--- | :--- |
| **DEV Firebase** | Proje ID / No | `sicak-firsatlar-e6eae` / `560592268193` |
| **DEV Web App ID** | Web App ID | `1:560592268193:web:64b68da3637d1e10d6f9e0` |
| **DEV Android App ID**| Android App ID | `1:560592268193:android:282d3a1048e2dec2d6f9e0` |
| **PROD Firebase** | Proje ID / No | `firsatkolik-prod-e6eae` / `228657473310` |
| **PROD Web App ID** | Web App ID | `1:228657473310:web:dc7c29279871906a380b0f` |
| **PROD Android App ID**| Android App ID | `1:228657473310:android:f735a18f5c730ced380b0f` |
| **PROD Keystore** | Keystore Yolu | `android/app/upload-keystore.jks` (Alias: `upload`) |
| **PROD AdMob (Android)**| App ID / Native ID | `ca-app-pub-6853997017739651~8861215767` / `ca-app-pub-6853997017739651/4004866134` (Faz 3.3 Native) |
| **PROD AdMob (iOS)**    | App ID / Native ID | `ca-app-pub-6853997017739651~7339420575` / `ca-app-pub-6853997017739651/9437070495` (Faz 3.3 Native) |

---

## 7. 🧹 30 Günlük Veri Saklama ve Otomatik Temizlik (Purge/Cron)

Veritabanı şişmesini ve maliyet artışını engellemek amacıyla 3 aşamalı yaşam döngüsü politikası uygulanır:

1. **48 Saatlik Soft-Expire (`cleanupExpiredDeals`):** Her gece 03:00'da çalışır; 48 saatlik fırsatları `isExpired: true` yapar (doküman silinmez). Firestore bileşik indeksi (`isExpired == false` ve `createdAt < 48h`) ve 7 günlük bounded fallback korumasıyla kotayı %99 korur.
2. **30 Günlük Hard-Purge (`purgeOldDeals`):** Her Pazar 04:00'da çalışır; 30 günden eski fırsatları, yorumları, oyları, Storage görsellerini ve **tüm kullanıcılardaki (`collectionGroup('notifications')`) 30+ günlük bildirimleri** 400'lük batch parçalarıyla kalıcı siler. $O(\text{Deals} \times \text{Users})$ favori tarama döngüsü kaldırılmıştır; favoriler mobil istemcide lazy self-healing olarak temizlenir.
3. **Storage Çöp & Yetim Dosya Toplayıcı (`cleanupOldImages`):** Her gece 00:00'da Firebase Storage `deals/` dizinindeki 40 günden eski sahipsiz dosyaları 10'arlı eşzamanlı chunk'lar ile temizler (Haftalık fırsat silme periyoduyla senkron, 40 günlük güvenlik payı ile kırık görsel/404 hatasını önler).

---

## 8. 🛡️ Firebase App Check ve Play Integrity Güvenliği

Backend API'lerinin (özellikle Cloud Functions ve HTTPS Endpoint'leri) yetkisiz üçüncü şahıslar tarafından suistimal edilmesini engellemek için **Firebase App Check** zorunludur:
- **Geliştirme Ortamı (DEV):** Debug token'lar (`DebugAppCheckProvider`) kullanılarak emülatör ve test cihazlarına izin verilir.
- **Canlı Ortam (PROD):** Google Play Console üzerinden **Play Integrity API** aktif edilerek yalnızca resmi Google Play Store'dan yüklenmiş orijinal uygulamalara geçiş izni verilir.

---

## 9. 💻 Web Admin Paneli Backend Entegrasyonu (Hosting & Callable)

Web Admin paneli ([web/admin/app.js](file:///d:/firsatkolik/web/admin/app.js)); Firebase Hosting üzerinde çalışır ve tarayıcının çalıştığı hostname'e göre DEV/PROD projelerini otomatik seçer:
- **Manuel Push Gönderimi (`sendManualNotification`):** Tüm kullanıcılar, tekil UID veya belirli token hedeflenerek push atılır.
- **Geçersiz Token Temizliği (`cleanupInvalidTokens`):** Veritabanındaki aktif cihazların FCM geçerliliğini test edip bayat olanları pasife alır.
- **30+ Günlük Fırsat ve Bildirim Temizliği:** `purgeOldDealsManual` veya `purgeOldNotificationsManual` fonksiyonlarını çağırarak sunucuda derin temizlik yapar.
- **Kupon ve Katalog Kazıma:** `scrapeCouponsManual` ve `scrapeCatalogsManual` callable fonksiyonlarıyla botları tetikler.

---

## 10. 🧪 Backend Test Süitleri ve Doğrulama

Backend sisteminin ve Cloud Functions fonksiyonlarının doğruluğu bağımsız test süitleriyle %100 test edilmektedir:

| Test Dosyası | Kapsam | Komut |
| :--- | :--- | :--- |
| **`functions/tests/test_core_event_pipeline_contracts.js`** | Çekirdek Olay & Bildirim Pipeline Sözleşmeleri (ReDoS, APNs, Güvenli commentCount, Banlı kullanıcı engeli, ISO-8601) | `node functions/tests/test_core_event_pipeline_contracts.js` |
| **`functions/tests/test_production_batch2_contracts.js`** | SSRF, RFC 3986 Redirect, Concurrency Pool, 400 Batch & No-Op Eleme Sözleşmeleri | `node functions/tests/test_production_batch2_contracts.js` |
| **`functions/tests/test_lifecycle_cleanup_contracts.js`** | Yaşam döngüsü, temizlik cronları, 40 gün Storage GC ve bileşik indeks sözleşmeleri | `node functions/tests/test_lifecycle_cleanup_contracts.js` |
| **`functions/tests/test_all_notification_scenarios.js`** | 10 senaryoluk uçtan uca push ve Cloud Functions dağıtım testi | `node functions/tests/test_all_notification_scenarios.js` |
| **`functions/tests/test_notification_settings.js`** | Bildirim tercihleri, hız limitleri ve sessiz saatler entegrasyonu | `node functions/tests/test_notification_settings.js` |
| **`functions/tests/test_notifications_menu.js`** | Bildirim merkezi onay/red ve deduplication testleri | `node functions/tests/test_notifications_menu.js` |

---

## 11. 🔧 Sorun Giderme ve Hata Ayıklama (Troubleshooting)

### 1. Cloud Function Loglarını İzleme:
```bash
firebase functions:log --project prod --only onNotificationCreated
```

### 2. VM Üzerindeki Bot Durumunu Kontrol Etme:
```bash
# SSH ile VM'e bağlan
gcloud compute ssh telegram-bot-server --zone=us-central1-a --project=firsatkolik-prod-e6eae

# Docker konteyner durumunu gör
docker ps

# Canlı bot loglarını akıt
docker logs -f prod-bot
```

### 3. App Check İzin Reddi (403 Permission Denied):
- DEV ortamında Logcat'ten güncel debug token'ı alıp Firebase Console > App Check > Apps > Debug Tokens altına ekleyin.
- PROD ortamında Google Play Console App Signing SHA-256 değerini Firebase App Check Play Integrity yapılandırmasına ekleyin.

---

## 12. 📂 İlgili Kaynak Kod Dosyaları ve Referanslar

| Rol / Katman | Dosya Yolu | Açıklama |
| :--- | :--- | :--- |
| **Cloud Functions Merkezi** | [functions/index.js](file:///d:/firsatkolik/functions/index.js) | 27 adet backend fonksiyonunun kaynak kodu. |
| **Firestore Güvenlik Kuralları**| [firestore.rules](file:///d:/firsatkolik/firestore.rules) | Veritabanı RBAC ve alan bazlı güvenlik kuralları. |
| **Storage Güvenlik Kuralları** | [storage.rules](file:///d:/firsatkolik/storage.rules) | Dosya depolama erişim kuralları. |
| **Firestore İndeksleri** | [firestore.indexes.json](file:///d:/firsatkolik/firestore.indexes.json) | Bileşik sorgular ve collectionGroup indeksleri. |
| **Firebase Yapılandırması** | [firebase.json](file:///d:/firsatkolik/firebase.json) | Hosting, functions ve emülatör ayarları. |
| **Flutter Ortam Seçici** | [firebase_options.dart](file:///d:/firsatkolik/lib/firebase_options.dart) | Flavor bazlı dinamik FirebaseOptions seçimi. |
| **Android Flavor Yapılandırması**| [build.gradle](file:///d:/firsatkolik/android/app/build.gradle) | DEV/PROD paket adı, app_name ve keystore ayarları. |
| **Web Admin Paneli Backend API** | [app.js](file:///d:/firsatkolik/web/admin/app.js) | Callable Cloud Functions çağıran admin paneli motoru. |
| **VM Deploy Otomasyonu** | [deploy_to_vm.py](file:///d:/firsatkolik/cloud-run-bot/deploy_to_vm.py) | Cloud Build ve VM Docker container deploy scripti. |
