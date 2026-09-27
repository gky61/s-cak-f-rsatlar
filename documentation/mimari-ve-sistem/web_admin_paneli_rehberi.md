# 💻 FırsatKolik — Web Admin Paneli Kapsamlı Mimari ve Operasyon Rehberi

> [!NOTE]
> Bu doküman 10 modüllü Web Admin Paneli mimari ve operasyonel kılavuzudur. Sistemin uçtan uca mimarisi, gösterim algoritmaları, gamification, mesajlaşma ve moderasyon entegrasyonu için lütfen **[Sistem Mimarisi, Yaşam Döngüsü ve Sosyal Etkileşim Master Rehberi](file:///d:/firsatkolik/documentation/mimari-ve-sistem/mimari_ve_sistem_rehberi.md)** dokümanını inceleyiniz.

Bu doküman, FırsatKolik platformunun yönetim merkezi olan **Web Admin Paneli**'nin (`web/admin/` dizini altındaki `index.html`, `app.js`, `config.js` ve `styles.css`) mimarisini, yetkilendirme modellerini, gerçek zamanlı veri akışlarını, 10 temel yönetim görünümünü ve tüm operasyonel fonksiyonlarını detaylı bir şekilde açıklamaktadır.

---

## 🏗️ 1. Genel Mimari ve Barındırma Modeli

Web Admin Paneli, harici ağır frontend framework'lerine (React, Vue, Angular vb.) bağımlı olmadan saf **Vanilla HTML5, CSS3 ve Modern JavaScript (ES6+)** ile geliştirilmiş, ultra hafif ve yüksek performanslı bir tek sayfa uygulamasıdır (SPA).

```mermaid
graph TD
    User[👨‍💼 Yönetici Tarayıcısı] -->|HTTPS| Hosting[🌐 Firebase Hosting: *.web.app / firsatkolik.app]
    Hosting --> Config[⚙️ config.js: Dinamik Hostname Analizi]
    Config -->|localhost / 127.0.0.1 / dev.web.app| DevFB[(🔥 DEV Firebase: sicak-firsatlar-e6eae)]
    Config -->|firsatkolik-prod-e6eae.web.app / firsatkolik.app| ProdFB[(🔥 PROD Firebase: firsatkolik-prod-e6eae)]
    
    DevFB --> AppJS[⚡ app.js: 10 Ana Yönetim Görünümü & Realtime Listeners]
    ProdFB --> AppJS
    
    AppJS -->|Callable HTTPs / REST| Functions[⚡ Cloud Functions: 26 Adet Bağımsız Servis]
    AppJS -->|Bot Dinamik Ayarları| BotSettings[⚙️ settings/telegramBot]
```

### Temel Özellikler:
* **Sıfır Derleme (Zero Build):** Web klasöründeki kodlar herhangi bir derleme (`npm run build` vb.) işlemine ihtiyaç duymaz. Doğrudan tarayıcıda çalışır.
* **Dinamik Çevre Seçimi (`config.js`):** Tarayıcının çalıştığı `window.location.hostname` değerine bakarak hangi Firebase projesine bağlanacağını (`sicak-firsatlar-e6eae` vs `firsatkolik-prod-e6eae`) çalışma anında (runtime) otomatik tayin eder.
* **Sıfır Sızıntı (Zero-Leakage) İzolasyonu:** Tüm 10 yönetim modülü tek bir merkezi `firebase.firestore()` örneği (`db`) üzerinden sorgulama yapar. Panelde hiçbir statik/hardcoded proje ID bulunmaz; böylece DEV test verileri asla PROD canlı veritabanına karışmaz.
* **Gerçek Zamanlı (Realtime) Senkronizasyon:** Fırsatlar, mesajlar, raporlar ve sistem logları Firestore'un `onSnapshot` stream dinleyicileriyle sayfayı yenilemeden (F5 gerekmeden) canlı güncellenir.
* **Kapsamlı Rol Doğrulaması:** Firebase Auth ile giriş yapan kullanıcının `users/{uid}` belgesindeki `isAdmin: true` yetkisi doğrulanmadan panel arayüzü render edilmez.

---

## 🔐 2. Kimlik Doğrulama ve Admin Güvenlik Katmanı

Yönetici panele erişmek istediğinde süreç şu güvenlik kontrollerinden geçer:

1. **`initAuth()` & `checkAdminAndLoad()`:**
   - Firebase Auth durumunu dinler (`auth.onAuthStateChanged`).
   - Kullanıcı giriş yapmamışsa şık giriş modalı (`#loginScreen`) gösterilir.
2. **Admin Yetki Kontrolü (`checkAdmin(user)`):**
   - Kullanıcının Firestore `users/{uid}` belgesi çekilir.
   - `isAdmin === true || isadmin === true || isAdmin === 'true'` kontrolleri yapılır.
   - Yetkisiz bir kullanıcı giriş yaparsa oturum otomatik kapatılır ve yetkisiz erişim uyarısı verilir.
3. **Çevre Rozeti & Yerel Ortam Değiştirici (`initEnvironmentBadge()`):**
   - Uzak sunucularda sol menünün üstünde çalışılan ortamı belirten dinamik bir rozet gösterilir (`🟢 DEV ORTAMI` veya `🔴 PROD (CANLI)`).
   - Yerel testte (`localhost` / `127.0.0.1`), rozet otomatik olarak bir `<select id="envSwitcher">` açılır listesine dönüşür. Yönetici tek tıkla `DEV ⚙️` veya `PROD 🚀` projeleri arasında geçiş yapabilir; tercih `localStorage.getItem('firebase_env')` anahtarında saklanır.

---

## 📊 3. Web Admin Panelinin Temel Görünümleri

Panel, sol navigasyon menüsü üzerinden bağımsız modüllere ayrılmıştır:

```
Web Admin Paneli
├── 1. 📊 Dashboard Görünümü (Genel İstatistikler & Sistem Sağlığı)
├── 2. 🏷️ Fırsatlar Görünümü (Onay, Red, Düzenleme & Affiliate)
├── 3. 👥 Kullanıcılar Görünümü (Profil İnceleme, Ceza & Mesaj)
├── 4. 💬 Mesajlar & Simülatör (Canlı Sohbet & Test Motoru)
├── 5. 🚩 Şikayetler & Raporlar (İçerik Moderasyon Kuyruğu)
├── 6. ⚙️ Sistem & Bot Ayarları (Bot Kanalları, Şalterler & Temizlik)
├── 7. 🔔 Bildirimler Merkezi (Cihaz İstatistikleri & Manuel Push)
├── 8. 📜 Sistem Logları (Hata Kayıtları & systemErrors)
├── 9. 🎟️ Kuponlar Yönetimi (Manuel Ekleme & Otomatik Kazıma)
├── 10. 📰 Aktüel Kataloglar (Broşür İnceleme & Kazıma)
├── 11. 💰 AdMob Monetizasyon & Gelir Merkezi (Faz 3.3 Gelişmiş Native Ads Mimarisi)
└── 12. 👁️‍🗨️ Telemetri & Observability HUB (GA4 Trafik, Sadakat, Kotalar & Bot Sağlığı)
```

---

### 1. 📊 Dashboard Görünümü (`showDashboardView` / `loadDashboardData`)
* **6 Temel Sütunlu Bento Grid Mimarisi:**
  - **1. Fırsat Havuzu:** Toplam fırsat sayısı, bugün eklenenler, onay bekleyenler rozeti ve ortalama onay süresi.
  - **2. İndirim Kuponları:** Toplam kupon sayısı, aktif kuponlar ve bugün eklenen kuponlar (Topluluk vs Botkolik Radarı).
  - **3. Aktüel Afiş ve Kataloglar:** Toplam katalog sayısı, aktif/geçerli kataloglar ve 36 mağaza taksonomisi.
  - **4. Topluluk & Avcılar:** Toplam kayıtlı üye, bugün katılanlar, bugün yapılan yorumlar ve 16+ Avcı Rozeti & gamification.
  - **5. Bildirim & Cihazlar:** Aktif FCM cihaz sayısı, Android/iOS dağılımı ve bugün iletilen push sayısı.
  - **6. Moderasyon & Sistem Radarı:** İncelenmeyi bekleyen kullanıcı şikayetleri (`reports`) ve açık sistem hataları (`systemErrors`).
* **3 Katmanlı Operasyonel Sistem Sağlık Merkezi:**
  - **Telegram Scraping Bot:** Son kalp atışı (`lastHeartbeatAt`), bot çevrimiçi durumu, fırsat, mükerrer, hata ve mesaj istatistikleri.
  - **Otonom Kazıma & Ayrıştırma:** 21 mağaza kazıma kapsamı, WAF/TLS bypass motoru, 11 kategori taksonomisi ve $0.00 sıfır maliyet mimarisi.
  - **Push Engine & Hız Limitleri:** Canlı durum rozeti, kategori saatlik/günlük hız sınırları ve son 7 günlük gönderim hacmi.
* **Grafiksel ve Aksiyon Odaklı Analiz:**
  - **7 Günlük Fırsat Dağılımı Çubuk Grafiği (`dealsTrendChart`)** ve **13 Kategori Dağılımı Halka Grafiği (`categoriesDistributionChart`)**.
  - **Hızlı Onay Bekleyen Fırsatlar Kuyruğu (`dashPendingDealsBody`):** Doğrudan panel üzerinden "İncele" butonuyla düzenleme/onaylama modalı açma.
  - **Avcı Liderlik Tablosu (`dashLeaderboardBody`):** Madalyalar (🥇, 🥈, 🥉), avatarlar ve puanlarla en aktif avcılar.
  - **En Sıcak Fırsatlar (`dashTopLikesBody`):** Sıcaklık derecesiyle (°C) öne çıkan fırsatlar.
* **Ortam Uyumluluğu:** Dinamik `#dashEnvBadge` göstergesi (DEV: `sicak-firsatlar-e6eae` vs PROD: `firsatkolik-prod-e6eae`).

---

### 2. 🏷️ Fırsatlar Görünümü (`showDealsView`)
* **Filtreleme & Arama:** Onay Durumu (`Tümü`, `Onay Bekleyenler`, `Onaylananlar`, `Süresi Dolanlar`), Kategori seçicisi ve Anlık Arama.
* **Fırsat Satırı (`createDealRow`):**
  - **Detay & Görsel:** Ürün görseli, başlık, mağaza, marka, Amazon Depo rozeti, değerlendirme puanı (`ratingValue` & `ratingCount`).
  - **Kaynak Rozeti:** Bot paylaşımı (`smart_toy` + bot/kanal adı) veya kullanıcı paylaşımı (`person` + kullanıcı rumuzu/adı).
  - **Fiyat & İndirim:** İndirimli fiyat, liste fiyatı (`originalPrice`), % indirim oranı veya "Fiyat Gizli" rozeti.
  - **Tarih & Zaman Damgası:** Çift katmanlı zaman damgası (Üstte: `schedule` ikonu ile `15 Dakika Önce` / `2 Saat Önce` gibi göreceli süre; Altta: `24.08.2026 22:15` gibi tam tarih/saat damgası).
  - **Durum:** Aktif, Bekliyor, Reddedildi veya Süresi Doldu rozeti.
* **Aksiyonlar:**
  - **Onaylama (`approveDeal`):** Fırsatın `isApproved` alanını `true`, `isRejected` alanını `false`, `isExpired` alanını `false` ve `status` alanını `'active'` yapar; `approvedAt` zaman damgasını günceller. Mobil istemci feed akışları ve Cloud Functions `onDealUpdated` ile %100 senkronize çalışır.
  - **Reddetme / İptal (`rejectDeal` / `handleCancelDeal`):** Fırsatın `isRejected: true`, `isApproved: false`, `isExpired: true`, `status: 'rejected'` yapar; feed ve arama akışlarından derhal kaldırır.
  - **Düzenleme Modalı (`showDealModal` / `saveDealChanges`):** Fiyat, başlık, açıklama, kategori, alt kategori, orijinal fiyat, marka, rating puanı, görseller ve oluşturulma/güncellenme zaman damgalarını (`formatFullDateTime` + `getTimeAgo`) tarayıcıdan düzenleyip kaydeder.
  - **Görsel Büyütme Lightbox (`openImageLightbox`):** Fırsat görsellerini tam çözünürlükte modal içinde inceler.
  - **Manuel Fırsat Ekleme (`showAddDealModal`):** Yöneticinin doğrudan panelden yeni fırsat yayınlamasını sağlar.

---

### 3. 👥 Kullanıcılar Görünümü (`showUsersView`)
* **Kullanıcı Listeleme (`loadUsers` / `renderUsers`):** Kayıtlı kullanıcıların avatarı, kullanıcı adı, e-postası, toplam paylaştığı fırsat sayısı, toplam beğenisi, sahip olduğu rozetler (`Rozetler` sütunu + vitrin rozeti hapı), takip ve kategori istatistikleri.
* **Rozet Bazlı Arama:** Arama kutusu kullanıcı adı/e-posta haricinde rozet ID ve Türkçe isimlerini (`verified`, `Usta Avcı`, `first_spark` vb.) de filtreler.
* **Kullanıcı Detay Modalı (`showUserDetail`):**
  - **Rozet Yönetimi (`BADGE_CATALOG`):**
    - Kullanıcının sahip olduğu tüm rozetleri ikon, Türkçe isim, kademe etiketi (`[Bronz]`, `[Gümüş]`, `[Altın]`, `[Elmas]`, `[Özel]`) ve vitrin durumuyla (`⭐ Vitrin`) listeleme.
    - **Vitrinde Göster / Kaldır (`togglePinBadge`):** Kullanıcının profil ve yorumlarda öne çıkacak unvan rozetini tek tıkla sabitleme/kaldırma.
    - **Rozeti Kaldır (`removeBadge`):** Kullanıcıdan rozeti onay kutusuyla güvenli silme.
    - **Katalogdan Rozet Ekle (`addBadgeFromCatalog`):** 16+ resmi katalog rozetini (Fırsat Avcılığı, Sıcaklık, Topluluk, Sadakat) kategorize açılır menüden seçip anında atama.
    - **Özel Rozet Ekle (`addBadge`):** Özel promosyon veya manuel rozet kimliğini girip atama.
    - **Otomatik Rozet Eşitleme (`autoAwardBadgesForUser`):** Kullanıcının mevcut puan, fırsat ve beğeni istatistiklerini hesaplayarak hak ettiği tüm rozetleri tek tıkla topluca verme.
  - **Özel Admin Mesajı Gönderme:** Kullanıcıya doğrudan `adminToUserMessages` koleksiyonu üzerinden resmi sistem mesajı gönderme.
  - **Yetki ve Engelleme:** Admin yetkisi verme/kaldırma, genel engelleme (`blockUser`), paylaşım engeli (`toggleDealBan`) ve yorum engeli (`toggleCommentBan`).

---

### 4. 💬 Mesajlar & Simülatör Görünümü (`showMessagesView`)
* **Mesajlaşma Simülatörü (`initMessagingSimulator`):**
  - Geliştiricinin veya yöneticinin seçilen herhangi iki kullanıcı arasında sanal sohbet başlatmasını ve mesajlaşma akışını test etmesini sağlar.
* **Canlı Sohbet Akışı (`startLiveChatStream` / `renderLiveChatMessages`):**
  - Firestore `messages` koleksiyonunu gerçek zamanlı dinler ve kullanıcılar arasındaki mesaj trafiğini denetler.
* **Botkolik Sohbet Akışı (`startBotkolikChatStream`):**
  - Kullanıcıların yapay zeka asistanı Botkolik ile olan mesajlaşma kayıtlarını görüntüler.
* **Moderasyon Mesajları (`loadModerationMessages`):**
  - Küfür veya uygunsuz içerik tespit edildiğinde Cloud Functions tarafından üretilen sistem alarmlarını listeler.

---

### 5. 🚩 Şikayetler & Raporlar Görünümü (`showReportsView`)
* **Şikayet Havuzu (`loadReports` / `renderReports`):**
  - Kullanıcıların mobil uygulama içinden oluşturduğu (`ReportService`) fırsat, yorum ve kullanıcı şikayetlerini listeler.
* **Rapor Detayları:** Şikayet eden kullanıcı, şikayet edilen içerik, şikayet nedeni (`Spam`, `Yanıltıcı Fiyat`, `Uygunsuz İçerik`, `Stok Bitti`, `Diğer`), açıklama ve oluşturulma tarihi.
* **Moderasyon Aksiyonları:**
  - İlgili fırsat/yorum içeriğini tek tıkla silme.
  - Şikayeti `reviewed` (incelendi) veya `dismissed` (reddedildi) olarak işaretleme.

---

### 6. ⚙️ Sistem & Bot Ayarları Görünümü (`showSettingsView`)
* **Telegram Botu Yapılandırması (`loadBotConfig` / `saveBotConfig`):**
  - **Dinamik Kanal Yönetimi (`monitoredChannels`):** Botun dinlediği Telegram kanallarını (örn: `@indirimkaplani`, `@firsatkolik_canli`) sunucuyu yeniden başlatmadan (zero-restart) canlı ekleme ve çıkarma.
  - **Bot Durum Şalteri (`toggleBotStatus`):** Botun yeni fırsat kaydetmesini tek tıkla durdurma veya başlatma.
* **Global Sistem Şalterleri:**
  - **Fırsat Paylaşımı Şalteri (`toggleDealSharing`):** Mobil uygulamadaki "Fırsat Paylaş" formunu tüm kullanıcılara kapatma/açma (`systemConfig/dealSharing`).
  - **Yorum Paylaşımı Şalteri (`toggleCommentSharing`):** Yorum yazma özelliğini anlık durdurma (`systemConfig/commentSharing`).
  - **Kuponlar Modülü Şalteri (`toggleCouponsEnabled`):** Mobil kuponlar sekmesini kapatma/açma.
  - **Botkolik Sohbet Şalteri (`toggleBotkolikChat`):** Yapay zeka sohbet modülünü kapatma/açma.
  - **Global Bildirim Şalteri (`toggleGlobalNotifications`):** Tüm push bildirim iletimini tek şalterle durdurma (`systemConfig/notifications.enabled`).
* **Veritabanı Bakım ve Toplu Temizlik:**
  - **30+ Günlük Fırsat ve Bildirim Temizliği (`purgeOldDealsWeb`):** 30 günden eski fırsatları, oyları, yorumları, Storage görsellerini ve **tüm kullanıcılardaki 30+ günlük eski bildirimleri (`collectionGroup('notifications')`)** kalıcı olarak temizler. İlk olarak sunucu tarafındaki `purgeOldDealsManual` Cloud Function'ını çağırarak Admin SDK yetkisiyle anında siler; olası bağlantı sorununda doğrudan Firestore istemcisi üzerinden yedek silme mekanizmasını çalıştırır.

---

### 7. 🔔 Bildirimler Merkezi Görünümü (`showNotificationsView`)
* **Cihaz ve İzin İstatistikleri (`loadDeviceStats`):** Toplam kayıtlı cihaz sayısı, aktif cihazlar, Android/iOS dağılımı.
* **Genişletilmiş Bildirim Hız Limitleri & Anti-Spam Yönetimi (`loadNotificationConfig` / `saveNotificationLimits`):**
  - **Kategori Bildirim Limitleri:** Saatlik (`categoryHourlyLimit` - varsayılan: 3) ve Günlük (`categoryDailyLimit` - varsayılan: 8) kotalar.
  - **Yazar Bildirim Limitleri:** Takip edilen yazar/avcı paylaşımları için Saatlik (`authorHourlyLimit` - varsayılan: 4) ve Günlük (`authorDailyLimit` - varsayılan: 12) limitler.
  - **Anahtar Kelime Radar Limitleri:** Takip edilen anahtar kelime bildirimleri için Saatlik (`keywordHourlyLimit` - varsayılan: 6) ve Günlük (`keywordDailyLimit` - varsayılan: 18) limitler.
  - **Fırsat Burst Koruması & Tavanı:** Art arda fırlatılan fırsat bildirimleri arasına zorunlu bekleme süresi (Burst Cooldown - `dealMinIntervalSeconds` - varsayılan: 30sn) ve bir saatte tek bir cihaza gidebilecek maksimum fırsat sayısı (`dealMaxHourlyTotal` - varsayılan: 8).
  - **Viral Yorum & Spam Koruması:** Tek bir fırsatta 10 dakikada fırlatılabilecek maksimum yorum bildirimi (`commentDealTenMinLimit` - varsayılan: 5) ve bir kullanıcının saatte alabileceği toplam yorum bildirimi (`commentHourlyLimit` - varsayılan: 10).
  - **Pazarlama / Kampanya Limiti:** Kullanıcılara bir günde iletilebilecek maksimum pazarlama bildirimi (`marketingDailyLimit` - varsayılan: 2).
  - **Acil Durum Bildirim Şalteri (`toggleGlobalNotifications`):** Tüm sistemi tek tıkla durduran acil durum güvenlik kilidi (`systemConfig/notifications.enabled`).
* **Manuel Push Gönderimi (`sendManualNotification`):**
  - Hedef Kitle (`Tüm Kullanıcılar`, `Belirli Kategori`, `Belirli Kullanıcı UID`).
  - Bildirim Tipi (`Yönetici Duyurusu / Destek` ➔ `admin_message`, `Pazarlama / Kampanya` ➔ `marketing`).
  - Bildirim Başlığı, İçeriği, Yönlendirme Linki (Deep Link) girilerek güvenli ve sessiz saat kurallarına uyumlu manuel push gönderimi.
* **Geçersiz Token Temizliği (`cleanupInvalidTokens`):**
  - Uygulamayı silmiş veya token'ı düşmüş cihazların FCM token'larını tek tıkla temizler ve kota tasarrufu sağlar.
* **Canlı Bildirim Akışı ve Çift Yönlü Filtreleme:**
  - `collectionGroup('notifications')` üzerinden canlı akış; Durum Filtresi (`sent`, `skipped_*`, `disabled_*`, `failed`) ve Kanal/Tür Filtresi (`Yönetici`, `Kampanya`, `Topluluk`, `Yazar`, `Kategori`, `Anahtar Kelime`) ile kombine filtreleme.
* **Hibrit 7 Günlük Trend Grafiği:**
  - `notificationStats` dokümanları ile `collectionGroup('notifications')` canlı kayıtlarını birleştiren hibrit agregasyon motoruyla sıfır kayıp garantili trend çizimi.

---

### 8. 📜 Sistem Kontrol & Hata Logları Görünümü (`showLogsView` - Kibana / Datadog APM)
* **Uçtan Uca Hata Takip Havuzu (`loadSystemLogs` / `renderSystemLogs`):**
  - Firestore `systemErrors` koleksiyonunu dinleyen, platformun tüm bileşenlerinden (Flutter Mobil, Cloud Functions, Telegram Bot, Akakçe/Katalog kazıyıcıları, Kupon kazıyıcıları, AI servisleri ve Web Admin) gelen hataları tek merkezde toplayan modern yönetim arayüzü.
* **4 Bento Özet Metrik Kartı:**
  - **Bekleyen Hatalar (`logsStatUnresolved`):** Henüz çözülmemiş açık hataların sayısı.
  - **Kritik / Fatal Hatalar (`logsStatFatal`):** Acil müdahale gerektiren fatal seviyesindeki hatalar.
  - **Son 24 Saat (`logsStatToday`):** Son 24 saat içinde kaydedilen yeni hataların sayısı.
  - **En Sık Hata Veren (`logsStatTopCategory`):** En yüksek frekansa sahip sorunlu servis/kategori.
* **8 Yatay Segment Sekmeli Kategori Filtresi (`switchLogCategoryTab`):**
  - `Tümü`, `📱 Mobil Uygulama`, `🤖 Bot & Telegram`, `🛒 Mağaza / Kazıyıcılar`, `📰 Katalog & Kupon`, `🧠 Yapay Zeka / AI`, `🔔 Bildirimler`, `☁️ Cloud & Backend`, `💻 Web Admin`.
  - Her sekme üzerinde canlı hata sayacı badge'i yer alır.
* **Kibana / Datadog Referanslı Gelişmiş APM Araç Çubuğu:**
  - **👤 Kullanıcı Bazlı Hata Arama & Seçici (`logsUserDropdownBtn` / `logsUserDropdownPopover`):**
    - Açılır arama menüsü üzerinden kullanıcının adı, rumuzu, e-postası veya UID'si ile anlık arama (`logsUserSearchInput`).
    - Bir kullanıcı seçildiğinde tüm sistem hataları o kullanıcıya filtrelenir ve üstte **Aktif Kullanıcı Banner'ı** (`logsActiveUserBanner`) belirir.
    - Banner üzerinde kullanıcının avatarı, adı, UID'si ve toplam hata frekansı gösterilir.
    - **Tüm Geçmişte Ara (`deepSearchUserLogs`):** Eğer son 200 log arasında kullanıcının hatası bulunamazsa, Firestore üzerinde tek seferlik kota dostu `where('userId', '==', uid).limit(50)` hedefli geçmiş sorgusu çalıştırılır.
    - **Filtreyi Kaldır (`clearUserLogFilter`):** Tek tıkla kullanıcı filtresini kaldırır.
  - **⏱️ Zaman Aralığı Filtresi (`logsTimeRangeFilter`):** Kibana standartlarında `Tüm Zamanlar`, `Son 15 Dakika (Canlı)`, `Son 1 Saat`, `Son 24 Saat (Bugün)`, `Son 7 Gün`, `Son 30 Gün`.
  - **🌐 Platform / Cihaz Filtresi (`logsPlatformFilter`):** `Tüm Platformlar`, `🤖 Android`, `🍎 iOS`, `💻 Web İstemci / Admin`, `☁️ Cloud Functions`, `🤖 Telegram VM Bot`.
  - **Canlı Metin Arama (`logsSearchInput`):** Hata türü, mesaj, stack trace, mağaza adı veya UID'ye göre anlık metin filtreleme.
  - **Servis Seçici (`logsServiceFilter`):** Spesifik servis filtreleme.
  - **Önem Derecesi (`logsSeverityFilter`):** `Tümü`, `Bilgi (Info)`, `Uyarı (Warning)`, `Hata (Error)`, `Kritik (Fatal)`.
  - **Durum Seçici (`logsStatusFilter`):** `Bekleyenler (Unresolved)`, `Çözülenler (Resolved)`, `Tümü`.
  - **Ortam Seçici (`logsEnvironmentFilter`):** `Geçerli Ortam (DEV/PROD)`, `DEV Ortamı`, `PROD Ortamı`, `Tüm Ortamlar`.
  - **↺ Filtreleri Sıfırla (`resetAllLogFilters`):** Tek tıkla tüm arama, kullanıcı, platform ve zaman filtrelerini varsayılan ayarlara sıfırlar.
* **Kapsamlı Hata Detay Modalı (`logDetailModal` / `openLogDetailModal`):**
  - **Etkilenen Kullanıcı Kartı:** Hata bir kullanıcıya aitse kullanıcının UID'sini gösterir ve tek tıkla *"👤 Bu Kullanıcının Hatalarını Filtrele"* aksiyonu sunar.
  - Hata başlığı, önem derecesi ve ortam rozetleri, servis/kategori bilgileri.
  - İlk ve son oluşma zamanı, toplam tekrarlanma sayısı (`occurrenceCount`).
  - Hata mesajı ve metadata çipleri (Mağaza, kullanıcı ID, platform, URL vb.).
  - **Sözdizimi Renklendirmeli Stack Trace:** Koyu arka planlı terminal kutusu ve tek tıkla panoya kopyalama butonu (`logModalCopyStackBtn`).
  - **GCP Logging Derin Bağlantısı:** Google Cloud Logs Console üzerinde aynı zaman dilimi ve hata izini doğrudan sorgulama linki.
  - **Durum Değiştirme:** Modal içinden tek tıkla "Çözüldü İşaretle" veya "Yeniden Aç".
* **Toplu Aksiyonlar & Veri Bakımı:**
  - **Tümünü Çözüldü İşaretle (`resolveAllErrors`):** Listelenen tüm açık hataları tek tıkla çözüldü statüsüne geçirir.
  - **Eski Logları Temizle (`purgeOldSystemLogs`):** 30 günden eski veya çözülmüş logları 500'lük chunk batch ile temizler.
* **Kota Güvenliği & Sıfır Maliyet Güvencesi:**
  - Mobil istemcide 5 dakikalık bellek içi parmak izi tekilleştirmesi (de-duplication) ve cihaz başına saatte en fazla 5 hata yazma limiti.
  - Ağ kesintisi / offline hatalarının Firestore'a yazılması engellenmiştir.
  - Backend ve botlarda fingerprint bazlı tekrarlanma sayacı (`occurrenceCount`) ile gereksiz yazma operasyonları bloke edilir.

---

### 9. 🎟️ Kuponlar Yönetimi Görünümü (`showCouponsView`)
* **Hızlı Özet İstatistikleri:** Toplam Kupon, Topluluk Kuponları (`kaynakTipi == 'topluluk'`), Botkolik Radarı (`kaynakTipi == 'web'`), Aktif Kuponlar ve Geçersiz/Süresi Dolanlar.
* **Topluluk vs Botkolik Radarı Kaynak Ayrımı (`switchCouponSourceTab`):**
  - Üst çubukta 3 segmented sekme: `Tüm Kuponlar`, `👤 Topluluk Kuponları` ve `🤖 Botkolik Radarı`.
  - Tablo satırında kaynak rozeti (`👤 Topluluk` + `@paylasanRumuz` veya `🤖 Botkolik Radarı`).
* **Akıllı Filtreleme & Arama:**
  - Canlı Arama Çubuğu (Mağaza, başlık, kod, açıklama veya kullanıcı ara).
  - Mağaza Filtresi (Dinamik açılır menü).
  - Durum Filtresi (`Tümü`, `Aktifler`, `Geçersizler`, `Süresi Dolanlar`).
  - Sıralama Seçici (`En Yeni`, `En Yüksek Net Skor/Sıcaklık`, `Bitiş Tarihi`).
* **Satır İçi Aksiyonlar & Etkileşim:**
  - **Kodu Kopyala (`copyCouponCode`):** Tek tıkla kupon kodunu panoya kopyalama.
  - **Durum Değiştir (`toggleCouponStatus`):** Tek tıkla kuponu `aktif` veya `gecersiz` yapma.
  - **Kupon Ekleme & Düzenleme Modalı (`couponModal`):** `kaynakTipi`, `magazaAdi`, `baslik`, `aciklama`, `kuponKodu`, `bitisTarihi`, `durum` ve `paylasanKullaniciAdi` alanlarını eksiksiz yönetme.
  - **Tekil Kupon Silme (`deleteCoupon`):** Onay kutusuyla tekil silme.
  - **Radarı Tetikle (`scrapeCouponsManual`):** Otonom kazıma motorunu canlı tetikleme (Topluluk kuponlarına dokunmaz).
  - **Tüm Kuponları Temizleme (`deleteAllCoupons`):** 500'lük chunk batch ile veritabanını temizleme.

---

### 10. 📰 Aktüel Kataloglar Görünümü (`showCatalogsView`)
* **Hızlı Özet İstatistikleri:** Toplam Broşür, Şu An Yayında Olanlar, Gelecek Kampanyalar, Toplam Broşür Sayfası ve Aktif Mağaza Sayısı.
* **Filtreleme & Arama:**
  - Arama Çubuğu (Mağaza kodu veya katalog başlığı arama).
  - Mağaza Filtresi (Veritabanındaki aktif 33+ mağazayı dinamik listeleyen açılır menü).
  - Kampanya Durum Filtresi (`Tümü`, `Şu An Yayında`, `Yakında Başlayacak`, `Süresi Bitenler`).
* **Broşür Sayfalarını İnceleme Modalı (Lightbox Gallery - `catalogDetailModal`):**
  - Tablodan veya kapak görselinden tıklandığında tüm broşür sayfalarını (`sayfaResimleri`) tam ekran inceleme imkanı sunan galeri modalı.
  - Sayfa numaralandırması (`Sayfa 1 / 8`) ve yüksek çözünürlüklü "Tam Boyut" bağlantıları.
* **Tekil Katalog Yönetimi & Düzenleme:**
  - **Katalog Düzenle (`openEditCatalogModal` / `catalogEditModal`):** Mağaza kodu, başlık, başlangıç/bitiş tarihleri ve kapak URL'sini doğrudan Firestore üzerinde güncelleme.
  - **Manuel Katalog Ekle (`openAddCatalogModal`):** Yeni broşür oluşturma.
  - **Tekil Katalog Silme (`deleteSingleCatalog`):** Hatalı veya süresi geçmiş tekil bir kataloğu onay kutusuyla silme.
  - **Akakçe'den Kazı (`scrapeCatalogsManual`):** 36 mağazanın aktüel broşürlerini Akakçe'den 5 aşamalı WAF bypass hattıyla çekme.
  - **Tüm Katalogları Temizleme (`deleteAllCatalogs`):** 500'lük chunk batch ile tüm katalogları sıfırlama.

---

### 11. 💰 AdMob Monetizasyon & Gelir Merkezi Görünümü (Faz 3.3 Gelişmiş Native Ads Mimarisi — `admob_manager.js`)
* **Modüler Mimari (`window.AdMobManager`):**
  - Ağır kütüphanelere ihtiyaç duymayan saf Vanilla JavaScript (ES6+) mimarisi.
  - `app.js` dosyasını şişirmeden kendi durumunu (state), 6 bağımsız sekmesini, interaktif bilgi kutularını (tooltips) ve Firestore gerçek zamanlı veri akışını izole yönetir.
  - `settings/admob` Firestore dokümanı ile çift yönlü anlık senkronizasyon: Web Admin'de yapılan herhangi bir şalter veya parametre değişikliği mobilde uygulama güncellemesi gerektirmeden saliseler içinde devreye girer.
* **6 Temel Operasyonel Sekme:**
  - **1. 📊 Gelir & eCPM Dashboard'u (`overview`):**
    - **Çift Veri Kaynağı Modu (Dual Data Mode):**
      - `🟢 Canlı Üretim Verisi (Varsayılan - Şu An: ₺0.00 / 0 Gösterim)`: Uygulama henüz mağazalardan genel kitleye dağıtılmadığı için dürüst sıfır veri modu. Kullanıcılar mobilde kupon açtıkça ve reklam gördükçe `onPaidEvent` telemetrisiyle anlık artar.
      - `🟡 Sektör Benchmark Simülasyonu`: 10.000 aktif kullanıcı pazar projeksiyonunu (Bugün: ₺1,284.50, Son 7 Gün: ₺8,980.00, Son 30 Gün: ₺38,500.00, Ortalama eCPM: ₺112.50, CTR: %3.40, Doluluk: %95.8, Rewarded Tamamlama: %96.8) simüle eden projeksiyon modu.
    - **Platform Karnesi Dağılımı:**
      - `🤖 Android (%65 Trafik Payı)`: 7.4K gösterim, ₺94.20 ortalama eCPM, %95.4 doluluk oranı, ₺698.96 tahmini ciro.
      - `🍎 iOS (%35 Trafik Payı)`: 4.0K gösterim, ₺146.50 ortalama eCPM (+%55 premium getiri), %96.5 doluluk oranı, ₺586.00 tahmini ciro.
    - **Faz 3.3 Format Bazlı Gelir ve eCPM Sıralaması:**
      - `Akış İçi Native Reklam (Small Template - Faz 3.3)`: Anasayfa Grid (her 6 üründe bir tam satır) ve Liste (5-6-5 akış) yerleşimi, ₺108.50 eCPM, 10.2K gösterim, %95.8 doluluk, ₺1,111.04 ciro (Birincil Akış Formatı).
      - `Akış İçi Native Reklam (Kuponlar Sayfası)`: Kupon akışı (her 4 kuponda 1 satır), ₺115.00 eCPM, 2.4K gösterim, %96.2 doluluk, ₺276.00 ciro.
      - `Akış İçi Native Reklam (Aktüel Sayfası)`: Katalog akışı (her 6 broşürde 1 tam genişlik), ₺112.00 eCPM, 1.8K gösterim, %95.5 doluluk, ₺201.60 ciro.
      - `Ödüllü Video (Rewarded)`: Kuponlar sayfası (+2 hak), ₺285.00 eCPM, 380 gösterim, %97.4 doluluk, ₺108.30 ciro.
      - `Yatay Banner (320x50 - Emekli / Arşiv)`: Faz 3.3 mimarisiyle anasayfa akışından tamamen emekliye ayrılmış, arşivlenmiş pasif format (₺0.00 ciro / 0 gösterim).
      - *(Not: Kullanıcı deneyimini ve affiliate gelirlerini korumak için Interstitial ve App Open formatları sistemden arındırılmıştır.)*
  - **2. ⚙️ Şalterler & Parametreler (`control`):**
    - **Acil Durum Şalteri (Master Kill-Switch):** Ani AdMob incelemelerinde veya anomali durumlarında tek tıkla ve iki adımlı güvenlik penceresiyle (`window.confirm`) tüm mobil uygulamadaki reklamları anında durdurma imkanı.
    - **Bağımsız Format Şalterleri (5 Format):**
      - `Akış İçi Native Reklam (Faz 3.3 Anasayfa)`: Anasayfa ızgara ve liste akış içi native reklamları anında açıp kapatır.
      - `Akış İçi Native (Kuponlar Sayfası)`: Kuponlar listesinde her 4 kupondan sonra (5., 10., 15... sıralarda) gösterilen 124dp yatay native reklamı yönetir.
      - `Akış İçi Native (Aktüel Sayfası)`: Aktüel broşür listesinde 2 sütunlu grid akışında her 6 broşürden sonra gösterilen tam genişlik native reklamı yönetir.
      - `Ödüllü Video (Rewarded)`: Kupon sayfasındaki video ile kupon açma hakkını yönetir.
      - `Yatay Banner (Arşiv / Emekli)`: Faz 3.3 ile emekliye ayrılan eski banner birimlerini temsil eder (Varsayılan: Pasif/Arşiv).
    - **6 Temel Operasyonel Parametre (NaN ve Sınır Korumalı):**
      - `Günlük Ücretsiz Kupon Açma Hakkı`: Varsayılan 2 (1-20 arası).
      - `Video Başına Kupon Açma Hakkı`: Varsayılan +2 (1-10 arası).
      - `Izgara Akışı Reklam Sıklığı (nativeGridInterval)`: Varsayılan 6 ürün (4-20 arası). Anasayfa ızgara (Grid) görünümünde kaç üründe bir tam genişlik yatay native reklam yerleştirileceğini belirler.
      - `Kuponlar Akışı Reklam Sıklığı (nativeCouponsInterval)`: Varsayılan 5 (3-15 arası). Her 4 kuponda 1 (5. sırada) reklam enjeksiyonu.
      - `Aktüel Akışı Reklam Sıklığı (nativeAktuelInterval)`: Varsayılan 6 (4-20 arası). 2 sütunlu broşür gridinde her 6 broşürden sonra tam genişlik reklam enjeksiyonu.
      - `Hata Soğuma Süresi (Cooldown)`: Varsayılan 25 saniye (5-300 sn arası, Google kısıtlamalarını engeller).
  - **3. 📦 Reklam Birimleri Envanteri (`units`):**
    - **Master Ad Unit Kayıtları:** Android ve iOS platformları için hem Canlı PROD (`ca-app-pub-6853997017739651/...`) hem de Google resmi DEV test birim kimlikleri (`ca-app-pub-3940256099942544/...`).
    - **Dinamik Filtreleme Hapları:** `Tümü`, `Android`, `iOS`, `Canlı PROD`, `Test DEV`.
    - **Çift Katmanlı Kopyalama Güvenliği:** Modern `navigator.clipboard.writeText` API'ı ve HTTP/iframe fallback `document.execCommand('copy')` desteği.
  - **4. 🛡️ Kod & Politika Denetçisi (`inspection`):**
    - **8-Nokta Statik Kod Denetimi:**
      1. `android/app/build.gradle`: Dev test ID (`3347511713`) ve Prod gerçek ID (`8861215767`) ayrımı.
      2. `android/app/src/main/AndroidManifest.xml`: Dinamik `${admob_app_id}` gradle manifest placeholder enjeksiyonu.
      3. `ios/Runner/Info.plist`: iOS Prod App ID (`ca-app-pub-6853997017739651~7339420575`) ve 27 SKAdNetwork ağı.
      4. `lib/firebase_options.dart`: Faz 3.3 Native Ad matrisi ve fallback test kimlikleri.
      5. `lib/screens/home_screen.dart`: Faz 3.3 Akış Mimarisi (`CustomScrollView`, `SliverGrid`, `_buildGridWithHorizontalAdsSlivers` ve `AdDealCard` tam genişlik yatay reklam şeritleri).
      6. `lib/screens/kuponlar_page.dart`: Kuponlar akış içi Native Ad (Her 4 kuponda 1 reklam) entegrasyonu.
      7. `lib/screens/katalog_listesi_page.dart`: Aktüel 2 sütunlu grid akış içi Native Ad (Her 6 broşürde 1 tam genişlik şerit) entegrasyonu.
      8. `lib/services/ad_manager_service.dart`: Singleton mimari, 25s Cooldown, `onPaidEvent` telemetrisi ve Firestore Kill-Switch.
    - **7-Nokta Google AdMob Politika Uyumu Doğrulaması:**
      1. `ad_deal_card.dart`: Faz 3.3 Native Ads Advanced entegrasyonu (Eski FittedBox banner ihlalleri tamamen temizlendi).
      2. `ad_native_widget.dart`: `TemplateType.small` & Zero-Overflow kuralı (124dp sabit yükseklik, sıfır piksel taşması, AdMob Native Ad Validator 0 issue).
      3. `ad_native_widget.dart`: `onPaidEvent` telemetri ve mikro-gelir takibi (Firebase Analytics & tROAS bağlantısı).
      4. `kuponlar_page.dart`: Rewarded Ad Opt-in kullanıcı açık rızası (Otomatik video oynatma yasağına tam uyum).
      5. `kuponlar_page.dart`: Fair-Play kupon açma iade garantisi.
      6. `katalog_listesi_page.dart`: Aktüel 2 Sütunlu Grid Native Ad yerleşimi (3 satırda bir tam genişlik 124dp yatay reklam, sıfır-taşma).
      7. `ad_manager_service.dart`: Anti-Spam 25s cooldown ve uzaktan acil durum kill-switch kalkanı.
  - **5. 📈 Net Kâr & ROI Arbitraj Hesaplayıcı (`profit`):**
    - Pazarlama maliyetleri ile reklam gelirlerini karşılaştırarak gerçek zamanlı büyüme arbitrajını hesaplayan finansal motor:
      $$\text{Net Kâr} = (\text{AdMob Geliri} + \text{Affiliate Geliri}) - \text{Pazarlama Harcaması}$$
      $$\text{ROI} = \left(\frac{\text{Net Kâr}}{\text{Pazarlama Harcaması}}\right) \times 100$$
    - 3 Hazır Senaryo Butonu: `🌱 Başlangıç` (₺2.5K harcama / ₺2.25K net kâr / +%90 ROI), `🚀 Büyüme` (₺7.5K harcama / ₺8.0K net kâr / +%106.7 ROI), `⚡ Scale / Lansman` (₺20K harcama / ₺23.1K net kâr / +%115.5 ROI).
  - **6. 🤖 AdMob Agent Komuta Konsolu (`agent`):**
    - AdMob Ajanı ile canlı iletişim kurulan interaktif terminal arayüzü.
    - Hızlı Komutlar: `Sağlık Durumu`, `eCPM Optimizasyonu İste`, `Politika Denetim Raporu`, `iOS eCPM Kırılımı`, `Önbellek Temizle`.
    - Serbest Metin Girişi: Özel komut ve sorguları canlı işleyip terminale döken zeki yanıt motoru.
* **💡 İnfo Tooltip Bileşeni:**
  - Tüm kart ve tablolarda `(i)` bilgi ikonu üzerinden acemi dostu tanımlar, formüller ve endüstri standartları içeren interaktif mikro-pencereler sunulur.

---

### 12. 👁️‍🗨️ Telemetri & Observability HUB (`window.ObservabilityManager`)

> [!IMPORTANT]
> **Tüm Metriklerin Tek Ekranda Birleşimi (All-in-One Observability Hub):** FırsatKolik Web Admin Paneline entegre edilen **Modül 12 (Observability HUB)**, yöneticilerin 15'ten fazla harici Google Cloud, Firebase ve sunucu konsolu arasında kaybolmasını önleyen merkezi telemetri ve operasyonel kontrol odasıdır. `web/admin/observability_manager.js` üzerinden izole, modüler ve sıfır maliyetli olarak çalışır.

* **4 Ana Sekmeli Kapsamlı Gözlem Mimarisi:**
  1. **📊 Canlı Trafik & Gelir Analitiği (17 Metrik):**
     - **Anlık Aktif Kullanıcı (Son 30 Dk):** GA4 Realtime API ile son 30 dakikadaki tekil kullanıcı akışı (0-5 sn canlı).
     - **Mağazaya Git Tıklaması (Son 24s):** `deal_outbound_click` affiliate yönlendirme adedi (Ana gelir motoru).
     - **Kupon Kopyalama (Son 24s):** `coupon_copied` adedi (Kupon talebini ölçer).
     - **Katalog Görüntüleme (Son 24s):** `catalog_view` adedi (Broşür okunma trafiği).
     - **Mağaza Dağılım Çubukları:** Veritabanındaki aktif fırsat ve mağaza dağılımı (Saniyelik tam canlı).
     - **Fırsat Dönüşüm Hunisi:** `deal_view` ➔ `deal_outbound_click` dönüşüm yüzdesi (%15-%25 hedefi).
     - **Arama & Talep Radarı:** `search_performed` olayları ve arayıp bulunamayan kelime radarı.
     - **DAU / WAU / MAU:** Günlük (today), haftalık (7 gün) ve aylık (28 gün) tekil aktif kullanıcı kohortları.
     - **Bağlılık (Stickiness Skoru %):** `(DAU / MAU) * 100` formülüyle hesaplanan sadakat skoru (Sektör standardı %20+).
     - **Yeni Kullanıcı Edinimi:** Son 28 gündeki ilk açılışlar (`newUsers` / `first_open`, ASO başarısı).
     - **Ortalama Odak Süresi:** Oturum başına aktif etkileşim süresi (`userEngagementDuration / sessions`).
     - **Bildirim Dönüşü (FCM):** Push bildirimlerine dokunma adedi (`notification_interaction`).
     - **Viral Paylaşım & Oylar:** WhatsApp/Telegram paylaşımları (`deal_shared`) ve sıcak/soğuk oyları (`deal_voted`).
     - **En Çok Gezilen Ekranlar (Screen Views):** Son 7 günün en popüler ekranları (`unifiedScreenName`).
     - **AdMob Reklam Monetizasyonu (CTR & Gösterim):** `ad_impression`, `ad_click` ve `% CTR` oranları; `onPaidEvent` mikro-gelir takibi.
  2. **⚡ Altyapı & Kota Sağlığı (6 Metrik - Free Tier Güvencesi):**
     - **Firestore Günlük Okuma Kotası (Bugün):** 50.000 sınırına karşı aktif doküman hacmi (Saniyelik server-side count).
     - **Firestore Günlük Yazma Kotası (Bugün):** 20.000 sınırına karşı bot ve oylama yazma projeksiyonu (< %2).
     - **Storage Bant Genişliği & İndirme (Bugün):** 1 GB sınırına karşı WebP katalog görsel adedi ve indirme kotası.
     - **Cloud Functions Çağrı Kotası (Bu Ay):** 2.000.000 limitine karşı 26 fonksiyonun aylık çağrı sağlığı.
     - **GCP Harcama & Bütçe Koruması (Bu Ay):** 0.00 TL Free Tier koruması ve bütçe alarmları.
     - **App Check İstek Doğrulama (Canlı):** Play Integrity & App Attest ile sahte istek engelleme (Hedef >= %95).
  3. **🤖 Botlar & Servis Durumu (6 Metrik - Otonom Altyapı):**
     - **Otonom Telegram Botu Kalp Atışı:** `settings/telegramBot` dokümanı `lastHeartbeatAt` canlılık sinyali (<1 Dk).
     - **HTTP /health Canlılık Probu:** GCP VM bot konteynerine canlı ping (50-200ms milisaniyelik test).
     - **Oturum Sayaçları:** Yakalanan ham mesaj (`msgCount`), paylaşılan fırsat (`dealCount`), elenen spam (`dupCount`) ve hata sayısı (`errCount`).
     - **SSH Hızlı Müdahale Rehberi:** VM'e bağlanıp 3 hazır komutla botu yeniden başlatma rehberi.
  4. **🚨 Kararlılık, Hatalar & Konsol Köprüleri (7 Metrik - Sıfır Kör Nokta):**
     - **Sistem Hataları (Canlı):** `systemErrors` koleksiyonundaki açık ve toplam teknik hatalar.
     - **Son Sistem Hataları Tablosu:** Kaynak, mesaj, zaman ve çözülme durumuyla son 5 hata akışı.
     - **Firebase Crashlytics Köprüsü:** Hedef >= %99.5 Crash-Free Users; DEV ve PROD doğrudan bağlantıları.
     - **Firebase Performance Köprüsü:** Hedef < 2.0s Cold Start, donan kareler ve ağ gecikmeleri.
     - **GCP Cloud Logging Köprüsü:** 26 Cloud Function'ın saniyelik ham sunucu logları.
     - **GCP Bütçe Alarmı:** 250 TL (%50), 400 TL (%80) ve 500 TL (%100) acil uyarı eşikleri.
     - **Firebase App Check Güvenlik Köprüsü:** Kriptografik doğrulama konsolu.

---

## 🚀 4. Dağıtım ve Yayınlama Yönergeleri

Web Admin Panelinde yapılan değişiklikleri canlıya almak için:

```bash
# DEV Hosting Ortamına Dağıtım
firebase use dev
firebase deploy --only hosting

# PROD (Canlı) Hosting Ortamına Dağıtım
firebase use prod
firebase deploy --only hosting
```

Yayınlanan admin adresleri:
* **DEV Admin:** `https://sicak-firsatlar-e6eae.web.app/admin/` (veya `http://localhost:5000/admin/`)
* **PROD Admin:** `https://firsatkolik-prod-e6eae.web.app/admin/` ve `https://firsatkolik.app/admin/`

---
*FırsatKolik Web Admin Paneli Mimari Kılavuzu — 2026*
