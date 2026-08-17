# ⚡ FırsatKolik — Cloud Functions ve Backend Servisleri Rehberi

Bu rehber, FırsatKolik backend sisteminde (`functions/index.js`) yer alan **25 adet Cloud Function'ın** tetiklenme türlerini, çalışma amaçlarını, **projede kullanıldıkları / çağrıldıkları yerleri** ve **somut kullanım senaryolarını** detaylı bir şekilde açıklamaktadır.

---

## 📌 Hızlı Bakış Tablosu

| # | Fonksiyon Adı | Tetikleyici Türü | Çağrıldığı / Kullanıldığı Yer | Durum / Kategori |
|---|---|---|---|---|
| 1 | **`onDealCreated`** | Firestore Trigger | `deals/{dealId}` (Create) | 🟢 Aktif Canlı Sistem |
| 2 | **`onDealUpdated`** | Firestore Trigger | `deals/{dealId}` (Update) | 🟢 Aktif Canlı Sistem |
| 3 | **`onCommentCreated`** | Firestore Trigger | `deals/.../comments/{id}` (Create) | 🟢 Aktif Canlı Sistem |
| 4 | **`onAdminMessageCreated`** | Firestore Trigger | `adminMessages/{id}` (Create) | 🟢 Aktif Canlı Sistem |
| 5 | **`onUserMessageCreated`** | Firestore Trigger | `messages/{id}` (Create) | 🟢 Aktif Canlı Sistem |
| 6 | **`onNotificationCreated`** | Firestore Trigger | `notifications/{id}` (Create) | 🟢 Aktif Canlı Sistem |
| 7 | **`onUserUpdated`** | Firestore Trigger | `users/{userId}` (Update) | 🟢 Aktif Canlı Sistem |
| 8 | **`onUserDeleted`** | Firebase Auth Trigger | `auth.user().onDelete` | 🟢 Aktif Canlı Sistem |
| 9 | **`resolveShortLink`** | HTTPS Request | Flutter App & Web Admin | 🟢 Aktif Canlı Sistem |
| 10 | **`analyzeProductProxy`** | HTTPS Request / Proxy | Flutter App (`ai_service.dart`) | 🟢 Aktif Canlı Sistem |
| 11 | **`sendManualNotification`** | HTTPS Callable | Web Admin Paneli (`app.js`) | 🟢 Aktif Canlı Sistem |
| 12 | **`cleanupInvalidTokens`** | HTTPS Callable | Web Admin Paneli (`app.js`) | 🟢 Aktif Canlı Sistem |
| 13 | **`cleanupExpiredDeals`** | Scheduled (Cron 03:00) | GCP Cloud Scheduler | 🟢 Aktif Canlı Sistem |
| 14 | **`cleanupExpiredDealsManual`** | HTTPS Request | Manuel HTTP Endpoint | 🟡 Bakım & Test Amaçlı |
| 15 | **`purgeOldDeals`** | Scheduled (Cron Pazar 04:00)| GCP Cloud Scheduler | 🟢 Aktif Canlı Sistem |
| 16 | **`purgeOldDealsManual`** | HTTPS Callable | Web Admin Paneli & Scriptler | 🟡 Bakım & Test Amaçlı |
| 17 | **`cleanupOldImages`** | Scheduled (Cron 00:00) | GCP Cloud Scheduler | 🟢 Aktif Canlı Sistem |
| 18 | **`cleanupOldImagesManual`** | HTTPS Request | Manuel HTTP Endpoint | 🟡 Bakım & Test Amaçlı |
| 19 | **`adminDeleteUser`** | HTTPS Callable | Web Admin Paneli (`app.js`) | 🟢 Aktif Canlı Sistem |
| 20 | **`generateTestData`** | HTTPS Callable | Web Admin Paneli (`app.js`) | 🟡 Geliştirme & Test Verisi |
| 21 | **`cleanupTestData`** | HTTPS Callable | Web Admin Paneli (`app.js`) | 🟡 Geliştirme & Test Verisi |
| 22 | **`scrapeCouponsScheduled`** | Scheduled (Cron 6h) | GCP Cloud Scheduler | 🟢 Aktif Canlı Sistem |
| 23 | **`scrapeCouponsManual`** | HTTPS Callable | Web Admin Paneli (`app.js`) | 🟢 Aktif Canlı Sistem |
| 24 | **`scrapeCatalogsScheduled`** | Scheduled (Cron 12h) | GCP Cloud Scheduler | 🟢 Aktif Canlı Sistem |
| 25 | **`scrapeCatalogsManual`** | HTTPS Callable | Web Admin Paneli (`app.js`) | 🟢 Aktif Canlı Sistem |

---

## 🔍 25 Cloud Function Detaylı İncelemesi

---

### 1. `onDealCreated`
* **Tetikleyici Türü:** Firestore Trigger (`deals/{dealId}` - Create)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `lib/screens/add_deal_screen.dart` (Mobil Fırsat Paylaşımı)
  - `lib/services/deal_service.dart` (`createDeal` metodu)
  - `cloud-run-bot/telegram_bot.js` & `fetch_history.js` (Otonom bot paylaşımları)
  - `web/admin/app.js` (Admin panelinden fırsat ekleme)
* **Kullanım Amacı:** `deals/{dealId}` koleksiyonuna yeni bir doküman eklendiğinde tetiklenir. Fırsatın kategorisini, mağazasını ve anahtar kelimelerini analiz eder. İlgili kullanıcılara push bildirim kuyruğu hazırlar, Telegram bot kanalına anons geçer ve kullanıcının toplam paylaşım sayacını artırır.
* **Somut Senaryo:** 
  > Bir kullanıcı uygulamadan *"Sony WH-1000XM5 Kulaklık 9.999 TL"* başlıklı bir fırsat paylaştı. Bu fonksiyon anında tetiklenir. "Elektronik" kategorisini takip eden 1.200 kullanıcıya ve "Sony" kelimesine alarm kurmuş 45 kişiye push bildirim hazırlar; ardından Telegram kanalına mesajı iletir.

---

### 2. `onDealUpdated`
* **Tetikleyici Türü:** Firestore Trigger (`deals/{dealId}` - Update)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `lib/screens/deal_detail_screen.dart` (Sıcak/Soğuk oylaması, "Bitti" oylaması)
  - `lib/screens/deal_detail/deal_admin_dialogs.dart` (Mobil admin onaylama/reddetme/düzenleme)
  - `web/admin/app.js` (Admin onaylama, fiyat düzeltme, kategori değiştirme)
* **Kullanım Amacı:** Bir fırsat güncellendiğinde tetiklenir. `isExpired` durumu değiştiğinde, admin onayladığında (`isApproved: true`) veya indirim oranı/fiyatı güncellendiğinde devreye girer.
* **Somut Senaryo:**
  > Bir fırsatın oylamasında kullanıcılar *"Bitti/Stok Yok"* butonuna bastı ve `isExpired: true` oldu. Fonksiyon bunu yakalar; fırsatı anasayfa canlı sıralamasından FOMO ceza puanıyla aşağı çeker.

---

### 3. `onCommentCreated`
* **Tetikleyici Türü:** Firestore Trigger (`deals/{dealId}/comments/{commentId}` - Create)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `lib/screens/deal_detail_screen.dart` (Mobil yorum gönderme alanı)
  - `lib/services/comment_service.dart` (`addComment` metodu)
* **Kullanım Amacı:** Bir fırsatın altına yeni bir yorum yazıldığında ilanın `commentCount` sayacını atomik olarak 1 artırır ve ilanı paylaşan kullanıcıya bildirim gönderir.
* **Somut Senaryo:**
  > Ahmet, Mehmet'in paylaştığı laptop fırsatına *"Bu fiyata kaçmaz, hemen aldım!"* diye yorum yaptı. Fonksiyon ilanın yorum sayısını 12'den 13'e çıkarır ve Mehmet'in telefonuna *"Ahmet fırsatına yorum yaptı"* bildirimi düşer.

---

### 4. `onAdminMessageCreated`
* **Tetikleyici Türü:** Firestore Trigger (`adminMessages/{messageId}` - Create)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `web/admin/app.js` (Duyuru & Sistem Mesajları Yönetimi)
* **Kullanım Amacı:** Admin panelinden sisteme genel bir duyuru veya mesaj girildiğinde hedef kitledeki tüm aktif kullanıcılara bildirim dağıtır.
* **Somut Senaryo:**
  > Yönetici admin panelinden *"Bayram indirimleri başladı! Tüm kuponlar güncellendi"* duyurusu girdiğinde, fonksiyon tüm kullanıcılara bildirim kuyruğu oluşturur.

---

### 5. `onUserMessageCreated`
* **Tetikleyici Türü:** Firestore Trigger (`messages/{messageId}` - Create)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `lib/screens/chat_screen.dart` (Kullanıcılar arası sohbet ekranı)
  - `lib/services/chat_service.dart` (`sendMessage` metodu)
* **Kullanım Amacı:** Bir kullanıcı başka bir kullanıcıya mesaj attığında alıcının telefonuna anlık sohbet bildirimi gönderir.
* **Somut Senaryo:**
  > Ayşe, Murat'a *"Kupon kodunu nasıl kullandın?"* diye mesaj attığında Murat'ın ekranına anlık push bildirim düşer.

---

### 6. `onNotificationCreated`
* **Tetikleyici Türü:** Firestore Trigger (`notifications/{notificationId}` - Create)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `functions/index.js` içerisindeki tüm bildirim üreten triggerlar
  - `lib/services/notification_service.dart`
* **Kullanım Amacı:** `notifications` koleksiyonuna düşen her yeni bildirim belgesini Firebase Cloud Messaging (FCM) servisine ileterek fiziksel cihaz ekranında banner olarak gösterilmesini sağlar.
* **Somut Senaryo:**
  > Sistem içinde herhangi bir bildirim kaydı oluştuğunda bu fonksiyon kullanıcının cihaz token'ını bulur ve FCM HTTP v1 API üzerinden cihazına iletir.

---

### 7. `onUserUpdated`
* **Tetikleyici Türü:** Firestore Trigger (`users/{userId}` - Update)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `lib/screens/profile_screen.dart` & `edit_profile_screen.dart` (Profil düzenleme)
  - `lib/services/user_service.dart` (`updateUserProfile` metodu)
* **Kullanım Amacı:** Kullanıcı profil adını (`nickname`) veya avatarını (`photoUrl`) değiştirdiğinde eski yorum ve mesajlardaki kullanıcı verilerini senkronize eder.
* **Somut Senaryo:**
  > Kullanıcı profil fotoğrafını değiştirdiğinde, geçmişte attığı yorumlardaki avatar görseli de otomatik güncellenir.

---

### 8. `onUserDeleted`
* **Tetikleyici Türü:** Firebase Auth Trigger (`auth.user().onDelete`)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `lib/screens/settings_screen.dart` ("Hesabımı Kalıcı Olarak Sil" işlemi)
  - Firebase Konsol & `adminDeleteUser` servisi
* **Kullanım Amacı:** Kullanıcı hesabı silindiğinde Firestore'daki profil, favoriler (`favorites`), oy geçmişi ve cihaz token kayıtlarını temizler.
* **Somut Senaryo:**
  > Kullanıcı hesabını sildiği anda arka planda devreye girerek tüm kişisel kayıtları ve favori referanslarını temizler.

---

### 9. `resolveShortLink`
* **Tetikleyici Türü:** HTTPS Request (HTTP GET/POST)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `lib/screens/deal_detail/deal_link_utils.dart` (`resolveShortLink` metodu)
  - `lib/screens/admin_screen.dart` (`_resolveShortLink` metodu)
  - `web/admin/app.js` (Fırsat onaylama ve link doğrulama adımı)
* **Kullanım Amacı:** `ty.gl`, `amzn.to`, `app.hb.biz` gibi kısa yönlendirme linklerini takip ederek nihai temiz ürün URL'sini çözer.
* **Somut Senaryo:**
  > Kullanıcı `https://ty.gl/abc123xyz` linkini girdiğinde fonksiyon linki yönlendirip `https://www.trendyol.com/urun-p-12345` haline getirir.

---

### 10. `analyzeProductProxy`
* **Tetikleyici Türü:** HTTPS Request / Proxy
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `lib/services/ai_service.dart` (`analyzeProductProxy` metodu)
  - `lib/screens/add_deal_screen.dart` (Link yapıştırıldığında otomatik bilgi getirme)
* **Kullanım Amacı:** Ürün linkinden HTML meta verilerini ve Gemini yapay zeka analizini çekerek başlık/fiyat/görseli otomatik doldurur.
* **Somut Senaryo:**
  > Fırsat ekleme kutusuna Hepsiburada linki yapıştırıldığında sayfa başlığı, indirimli fiyatı ve ürün görseli otomatik forma doldurulur.

---

### 11. `sendManualNotification`
* **Tetikleyici Türü:** HTTPS Callable
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `web/admin/app.js` (Admin Paneli > "Bildirim Gönder" Butonu)
* **Kullanım Amacı:** Admin panelinden seçilen kitleye/kategoriye anlık özel push bildirim gönderir.
* **Somut Senaryo:**
  > Admin panelinden *"Gece Fırsatları Başladı"* başlığıyla tüm kullanıcılara kampanya bildirimi gönderilir.

---

### 12. `cleanupInvalidTokens`
* **Tetikleyici Türü:** HTTPS Callable
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `web/admin/app.js` (Admin Paneli > "Geçersiz Bildirim Tokenlarını Temizle" Butonu)
* **Kullanım Amacı:** Uygulamayı silmiş cihazların geçersizleşmiş FCM token'larını temizleyerek bildirim maliyetini ve log kirliliğini engeller.
* **Somut Senaryo:**
  > Admin panelinden tek tıkla `UNREGISTERED` dönen eski cihaz kayıtları veritabanından temizlenir.

---

### 13. `cleanupExpiredDeals` (48 Saatlik Soft-Expire)
* **Tetikleyici Türü:** Scheduled Cron (Her gün gece 03:00)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - GCP Cloud Scheduler (Otomatik Cron)
* **Kullanım Amacı:** 48 saati dolduran fırsatları bulur; dokümanı **SİLMEZ**, sadece `isExpired: true` olarak işaretler (Böylece anasayfadan düşer, kullanıcının favorilerinde 30 gün arşiv olarak kalır).
* **Somut Senaryo:**
  > 2 gün önce eklenen fırsat 48 saati doldurunca `isExpired: true` yapılarak anasayfadan düşürülür, favorilerde ise görseliyle yaşamaya devam eder.

---

### 14. `cleanupExpiredDealsManual`
* **Tetikleyici Türü:** HTTPS Request
* **Kullanıldığı / Tetiklendiği Yerler:**
  - Manuel HTTP Endpoint (Geliştirici & Test amaçlı)
* **Kullanım Amacı:** 13 numaralı 48 saatlik soft-expire işlemini cron saatini beklemeden manuel test etmek için kullanılır.

---

### 15. `purgeOldDeals` (30 Günlük Derin Temizlik / Hard-Purge)
* **Tetikleyici Türü:** Scheduled Cron (Her Pazar gece 04:00)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - GCP Cloud Scheduler (Otomatik Cron)
* **Kullanım Amacı:** 30 günden eski fırsatları, oyları, yorumları, Storage görsellerini ve kullanıcı favorilerini kalıcı olarak siler.
* **Somut Senaryo:**
  > 35 gün önceki eski bir fırsat Pazar gecesi tüm alt koleksiyonları ve favori referanslarıyla birlikte veritabanından kalıcı olarak silinir.

---

### 16. `purgeOldDealsManual`
* **Tetikleyici Türü:** HTTPS Callable
* **Kullanıldığı / Tetiklendiği Yerler:**
  - Backend Admin API (Geliştirici & Admin Scriptleri)
  - Not: Web Admin Paneli arayüzünde ayrıca doğrudan Firestore batch kullanan `purgeOldDealsWeb()` alternatifi de mevcuttur.
* **Kullanım Amacı:** 30 günlük derin temizliği admin yetkisiyle manuel tetikler.

---

### 17. `cleanupOldImages` (Storage Çöp Toplayıcı)
* **Tetikleyici Türü:** Scheduled Cron (Her gün gece 00:00)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - GCP Cloud Scheduler (Otomatik Cron)
* **Kullanım Amacı:** Firebase Storage `deals/` dizinindeki 30 günden eski sahipsiz/çöp dosyaları temizler.
* **Somut Senaryo:**
  > Kullanıcı fırsat paylaşırken resim yükleyip vazgeçtiğinde Storage'da kalan sahipsiz dosya 30 gün sonra silinir.

---

### 18. `cleanupOldImagesManual`
* **Tetikleyici Türü:** HTTPS Request
* **Kullanıldığı / Tetiklendiği Yerler:**
  - Manuel HTTP Endpoint (Geliştirici & Test amaçlı)
* **Kullanım Amacı:** Storage görsel temizliğini anlık olarak test etmek için kullanılır.

---

### 19. `adminDeleteUser`
* **Tetikleyici Türü:** HTTPS Callable
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `web/admin/app.js` (Kullanıcı Yönetimi > "Kullanıcıyı Sil" Butonu)
* **Kullanım Amacı:** Admin panelinden seçilen kullanıcının hem Firebase Auth hem de Firestore verilerini siler.
* **Somut Senaryo:**
  > Kural ihlali yapan bir kullanıcı admin panelinden silindiğinde Auth hesabı ve verileri anında kaldırılır.

---

### 20. `generateTestData`
* **Tetikleyici Türü:** HTTPS Callable
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `web/admin/app.js` (Geliştirici Araçları > "Test Verisi Üret" Butonu)
* **Kullanım Amacı:** Test ve geliştirme ortamı için `isTest: true` bayraklı sahte fırsatlar ve kategoriler üretir.

---

### 21. `cleanupTestData`
* **Tetikleyici Türü:** HTTPS Callable
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `web/admin/app.js` (Geliştirici Araçları > "Test Verilerini Temizle" Butonu)
  - `functions/tests/` (Backend entegrasyon test scriptleri)
* **Kullanım Amacı:** `isTest: true` bayraklı sahte verileri tek işlemle temizler.

---

### 22. `scrapeCouponsScheduled`
* **Tetikleyici Türü:** Scheduled Cron (Her 6 saatte bir)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - GCP Cloud Scheduler (Otomatik Cron)
* **Kullanım Amacı:** Kupon kaynaklarını (KuponBurada vb.) otonom tarayarak güncel indirim kodlarını veritabanına ekler.

---

### 23. `scrapeCouponsManual`
* **Tetikleyici Türü:** HTTPS Callable
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `web/admin/app.js` (Kupon Yönetimi > "Kuponları Şimdi Tara" Butonu)
* **Kullanım Amacı:** Kupon kazıma botunu admin panelinden elle çalıştırmaya yarar.

---

### 24. `scrapeCatalogsScheduled`
* **Tetikleyici Türü:** Scheduled Cron (Her 12 saatte bir)
* **Kullanıldığı / Tetiklendiği Yerler:**
  - GCP Cloud Scheduler (Otomatik Cron)
* **Kullanım Amacı:** Market aktüel afiş ve kataloglarını otonom tarar.

---

### 25. `scrapeCatalogsManual`
* **Tetikleyici Türü:** HTTPS Callable
* **Kullanıldığı / Tetiklendiği Yerler:**
  - `web/admin/app.js` (Katalog Yönetimi > "Katalogları Şimdi Tara" Butonu)
* **Kullanım Amacı:** Broşür kazıma botunu admin panelinden elle çalıştırmaya yarar.

---

## 💡 3. Atıl / Eski / Silinmesi Gereken Fonksiyonlar Değerlendirmesi

Yapılan detaylı kod taramasında:
1. **Canlıda Aktif Kullanılanlar (21 Adet):** Trigger'lar, bildirim mekanizmaları, admin paneli butonları, cron görevleri ve botlar eksiksiz bir şekilde doğrudan projede çağrılmakta ve çalışmaktadır.
2. **Manuel Test & Bakım Amaçlı Fonksiyonlar (4 Adet):**
   * `cleanupExpiredDealsManual` & `cleanupOldImagesManual` (HTTP Request test uçları)
   * `generateTestData` & `cleanupTestData` (Geliştirici test araçları)
   * `purgeOldDealsManual` (Admin callable test ucu)
3. **Sonuç:** Kod tabanında **tamamen unutulmuş veya ölü/zararlı hiçbir fonksiyon bulunmamaktadır**. Tüm fonksiyonlar ya canlı akışın bir parçasıdır ya da geliştirme/bakım aracı olarak görev yapmaktadır.
