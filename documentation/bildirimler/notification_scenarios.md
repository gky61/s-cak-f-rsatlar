# 🔔 FırsatKolik — Bildirim ve Push Bildirim Senaryoları Rehberi (vProduction - Kapsamlı & Güncel)

Bu doküman, FırsatKolik platformundaki iki temel bildirim alanının (**"Profilim -> Bildirimler"** menüsü ve **"Profilim -> Bildirim Ayarları"** menüsü) işleyişini, tetikleme kurallarını, kademeli pasifleştirme (parent-child) mantığını, veri akışlarını, bağlamsal izin isteme matrisini, önceliklendirme ve tekilleştirme mekanizmalarını ve tüm olası senaryoları detaylandırır.

---

## 🗺️ 1. Genel Bakış ve Temel Mimari

Uygulama içerisinde bildirimlerle ilgili iki temel kavram bulunur:

1. **"Bildirimler" Menüsü (Uygulama İçi Bildirim Kutusu / Notification Center):**
   * Kullanıcının geçmişe dönük aldığı tüm bildirimleri (Fırsat eşleşmeleri, yorum yanıtları, paylaşım onay/red durumları, yönetici duyuruları vb.) listelediği arayüzdür.
   * Firestore'da `users/{userId}/notifications` koleksiyonunda saklanır.
   * **Kritik Kural:** Bir bildirim tetiklendiğinde, kullanıcının push ayarları veya sessiz saatleri ne olursa olsun, bu doküman veritabanında **HER ZAMAN** oluşturulur. Push bildirimi gitmese bile bildirim kutusunda bu bildirim listelenmeye devam eder.

2. **"Bildirim Ayarları" Menüsü (Anlık Push Bildirimleri / FCM Push Notifications):**
   * Kullanıcının telefonuna gelen anlık uyarıların (Push) kanallarını, sessiz saatlerini ve genel izin durumunu yönettiği arayüzdür.
   * Firestore'da `users/{userId}/notificationPreferences/main` belgesinde saklanır.
   * Cloud Functions `onNotificationCreated` tetikleyicisi, bildirim kutusuna yeni bir doküman eklendiğinde devreye girer. Bu tercihlere, sistem limitlerine ve sessiz saatlere bakarak push bildirimini hedefler veya göndermeyi atlar.

---

## 📁 2. Tüm Bildirim Türleri ve Tetiklenme Senaryoları (Tam Matris)

| Senaryo ID | Bildirim Türü (`type`) | Tetikleyici Olay | Kanal ID & Renk | Başlık (`title`) / İçerik (`body`) Şablonu | Koşul, Öncelik & Davranış |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **NOTIF-01** | `deal` (Kategori) | Abone olunan bir kategori veya alt kategoriye ait yeni fırsatın onaylanması / yayınlanması | `sicak_firsatlar_general_v2`<br>(#FF6B35) | **🎯 Yeni Fırsat!**<br>[Fırsat Başlığı]<br>💰 [Fiyat] TL | Kategori aboneliği açık olmalı. En düşük önceliklidir (3. seviye). Saatlik/günlük kategori hız limitlerine ve sessiz saatlere tabidir. |
| **NOTIF-02** | `deal` (Yazar) | Bildirim zili açılan bir avcının (yazarın) paylaştığı fırsatın onaylanması | `sicak_firsatlar_general_v2`<br>(#FF6B35) | **👤 Takip Ettiğiniz Kişi!**<br>Takip ettiğiniz yazar yeni fırsat paylaştı: [Fırsat Başlığı] | Yazar takibi açık olmalı. Orta önceliklidir (2. seviye). Kategori hız limitlerine tabi değildir; sessiz saatlere tabidir. |
| **NOTIF-03** | `deal` (Anahtar Kelime)| Abone olunan anahtar kelimeyi (Örn: "iphone 15", "dyson") içeren fırsatın onaylanması | `keyword_alerts_channel`<br>(#FF9800) | **🎯 İlginizi Çeken Kelime!**<br>"[Kelime]" içeren yeni fırsat: [Fırsat Başlığı] | Kelime aboneliği açık olmalı. En yüksek önceliklidir (Deduplication). Eğer kullanıcı kelime bildirimlerini kapatmış ama kategori açık ise otomatik olarak kategori başlığına dinamik dönüşüm yapılır. |
| **NOTIF-04** | `comment_reply` | Bir kullanıcının yazdığı yoruma başka bir kullanıcının cevap yazması | `comment_replies_channel`<br>(#2196F3) | **[Kullanıcı Adı] yorumunuza cevap verdi**<br>[Cevap Metni (ilk 100 karakter)] | Kendine yanıt verilmemiş olmalı. **Sessiz saatlerden muaftır** (24 saat anlık iletilir). |
| **NOTIF-05** | `submission_status` (Onay) | Kullanıcının paylaştığı fırsatın admin tarafından onaylanması | N/A (Push Yok) | **🎉 Fırsatınız Onaylandı!**<br>Paylaştığınız "[Fırsat Başlığı]" onaylandı ve yayına alındı. | **[SESSİZ BİLDİRİM]** Telefona push gitmez (`disabled_permanently_for_submission_status`), sadece Bildirim Merkezi'nde saklanır. |
| **NOTIF-06** | `submission_status` (Red) | Kullanıcının paylaştığı fırsatın admin tarafından reddedilmesi | N/A (Push Yok) | **❌ Fırsatınız Reddedildi**<br>Paylaştığınız "[Fırsat Başlığı]" kurallarımıza uymadığı için reddedildi. | **[SESSİZ BİLDİRİM]** Telefona push gitmez (`disabled_permanently_for_submission_status`), sadece Bildirim Merkezi'nde saklanır. |
| **NOTIF-07** | `admin_message` | Admin panelinden veya sistemden kullanıcıya resmi bildirim gönderilmesi | `admin_messages_channel_v3`<br>(#FF5722) | **🛡️ [Admin Başlığı]**<br>[Admin Mesajı] | **Sessiz saatlerden ve grup tercihlerinden muaftır.** Yalnızca Master Switch kapalıysa engellenir. Ön planda `InAppMessageBanner` ile gösterilir. |
| **NOTIF-08** | `message` (Sohbet) | Kullanıcılar arası birebir mesajlaşmada yeni mesaj gelmesi | `messages_channel_v3`<br>(#2196F3) | **💬 [Gönderen Adı]**<br>[Mesaj Metni] | **Data-only payload.** Alıcı o an o kullanıcıyla aktif sohbet odasındaysa bildirim bastırılır. Uygulama içinde başka yerdeyse `InAppMessageBanner`, arka plandaysa sistem bildirimi gösterilir. |
| **NOTIF-09** | `admin_deal` | Onay bekleyen yeni bir fırsat (kullanıcı veya bot) paylaşıldığında adminlere giden bildirim | `admin_channel`<br>(#2196F3) | **👮‍♂️ Yeni Onay Bekleyen Fırsat ([Kaynak])**<br>[Fırsat Başlığı]<br>💰 [Fiyat] TL | `admin_deals` FCM konusuna (topic) gönderilir. Sadece admin yetkisi olan kullanıcılara iletilir. Deterministik `tag: 'admin_deal_${dealId}'` ile mükerrerlik önlenir. |
| **NOTIF-10** | `marketing` | Özel kampanyalar, hediye çekleri ve pazarlama duyuruları | `sicak_firsatlar_general_v2`<br>(#FF6B35) | **[Kampanya Başlığı]**<br>[Kampanya Detayı] | Kampanya switch'i açık olmalı. Sessiz saatlere ve master switch'e tabidir. |

---

## ⚙️ 3. "Bildirim Ayarları" 3 Katmanlı UX & Karar Mimarisi

```text
[ Katman 1: Master Switch - TELEFON BİLDİRİMLERİ ]
│
├── AÇIK (true) ──► Katman 2 (Kanal Switch'leri) Aktif & Canlı Renklerde
│                        │
│                        ├── "Kategori Bildirimleri" AÇIK  ──► Katman 3 ("Kategoriler >") Tıklanabilir
│                        ├── "Kategori Bildirimleri" KAPALI ──► Katman 3 ("Kategoriler >") GRİ & KİLİTLİ
│                        ├── "Kelime Bildirimleri" AÇIK    ──► Katman 3 ("Anahtar Kelimeler >") Tıklanabilir
│                        └── "Kelime Bildirimleri" KAPALI   ──► Katman 3 ("Anahtar Kelimeler >") GRİ & KİLİTLİ
│
└── KAPALI (false) ─► TÜM ALT KANALLAR VE DETAY SATIRLARI GRİ & KİLİTLİ (%50 Opaklık / Tıklanamaz)
```

### Tercih Kuralları:

1. **Master Switch (`pushMasterEnabled`):**
   - **KAPALI:** Altındaki tüm kanal switch'leri ve detay kartları %50 opaklık ile grileşir ve kilitlenir. Tıklandığında dinamik Snackbar uyarısı gösterilir: *"Bu ayarı değiştirmek için önce yukarıdan Telefon Bildirimleri'ni açmalısınız."*. Alt kanalların veritabanındaki değerleri **korunur (State Preservation)**. Cloud Functions tüm push'ları `disabled_by_user_master_switch` ile durdurur.
   - **AÇIK:** Tüm alt kanallar eski durumları korunmuş şekilde canlı renklerine döner ve etkileşime açılır. Kullanıcı bu şalteri ilk açtığında işletim sisteminden bildirim izni istenir (`requestPermission`).

2. **Kanal Bazlı Switch'ler:**
   - `dealNotificationsEnabled`: Yazar bildirimlerini kontrol eder (`disabled_by_user_group_deal`).
   - `communityNotificationsEnabled`: Yorum yanıt bildirimlerini kontrol eder (`disabled_by_user_group_comment_reply`).
   - `marketingNotificationsEnabled`: Kampanya bildirimlerini kontrol eder (`disabled_by_user_group_marketing`).
   - `categoryNotificationsEnabled`: Kategori bildirimlerini kontrol eder (`disabled_by_user_group_category`).
   - `keywordNotificationsEnabled`: Anahtar kelime bildirimlerini kontrol eder (`disabled_by_user_group_keyword`).

3. **Detay Tercih Kartları (Chevron `>`):**
   - `Takip Edilen Kategoriler >`: Master Switch AÇIK VE `categoryNotificationsEnabled == true` ise açılır. Kapalıysa dinamik uyarı: *"Bu ayarı değiştirmek için önce Kategori Bildirimleri'ni açmalısınız."*.
   - `Anahtar Kelimeler >`: Master Switch AÇIK VE `keywordNotificationsEnabled == true` ise açılır. Kapalıysa dinamik uyarı: *"Bu ayarı değiştirmek için önce Anahtar Kelime Takibi Bildirimleri'ni açmalısınız."*.

4. **Sessiz Saatler (`quietHoursEnabled`, `quietHoursStart`, `quietHoursEnd`, `timezone`):**
   - Belirlenen saat aralığında (Varsayılan: 23:00 - 08:00, `Europe/Istanbul`) `deal`, `keyword` ve `marketing` push'ları `skipped_quiet_hours` ile atlanır.
   - `comment_reply` ve `admin_message` sessiz saatlerden etkilenmeden iletilir.

5. **Kategori Hız Limitleri (Rate Limiting):**
   - `reason == 'category'` olan bildirimler için saatte en fazla 3 (`categoryHourlyLimit`), günde en fazla 8 (`categoryDailyLimit`) push gönderilir. Limit aşılırsa `skipped_category_limit` ile push atlanır.

6. **Mükerrer Cihaz ve Token Yönetimi (Multi-Device Deduplication):**
   - `saveFCMToken` her çağrıldığında kullanıcının aynı hesaba ait eski aktif cihaz kayıtlarını `active: false` yapar.
   - `getUserDeviceTokens` en güncel cihaz token'ını seçer ve aynı kullanıcıya mükerrer push gönderilmesini engeller.

---

## 🎯 4. Bağlamsal İzin İsteme Matrisi (Contextual Permission Matrix)

Açılışta körü körüne izin sormak yerine, kullanıcının niyet gösterdiği anlarda izin isteme akışı:

| Tetikleyici Ekran / Bileşen | Kullanıcı Eylemi | İzin İsteme Mantığı | Kabul Olasılığı |
| :--- | :--- | :--- | :---: |
| **Arama Çubuğu Radarı** (`HomeScreen`) | Bir arama kelimesini radar simgesine basarak takibe ekleme | `_addKeywordFromSearch` ➔ `requestPermission()` | **%90+** |
| **Anahtar Kelime Takibi** (`KeywordTrackingScreen`) | Yeni kelime ekleme veya önerilerden seçme | `_addKeyword` ➔ `requestPermission()` | **%92+** |
| **Kategori Tercihleri** (`CategoryPreferencesScreen`) | Bir kategoriyi veya tümünü takibe alma | `_toggleCategory` / `_selectAllCategories` ➔ `requestPermission()` | **%85+** |
| **Yazar / Avcı Profili** (`ProfileScreen` & `BotkolikProfileScreen`) | Başka bir kullanıcıyı takip etme veya bildirim zilini açma | `_toggleFollow` / `_toggleFollowNotification` ➔ `requestPermission()` | **%88+** |
| **Bildirim Ayarları** (`NotificationSettingsScreen`) | "Telefon Bildirimleri" master anahtarını AÇIK konuma getirme | `SwitchListTile.onChanged(true)` ➔ `requestPermission()` | **%95+** |

---

## 🧪 5. Otomatik Test Süitleri ve Doğrulama

Tüm bildirim sistemi ve senaryoları 3 ayrı test paketiyle tam kapsamlı (%100) doğrulanmaktadır:

| Test Dosyası | Kapsam | Komut |
| :--- | :--- | :--- |
| **`test/notification_logic_test.dart`** | Flutter birim testleri, serileştirme (toMap/fromFirestore), Master Switch State Preservation | `flutter test test/notification_logic_test.dart` |
| **`functions/tests/test_notification_settings.js`** | 5 Test Paketi & 18 Alt Senaryo: Master Switch OFF/ON, Alt kanal engelleri, Sessiz saatler, Yorum muafiyeti, Kategori limitleri, Cihaz kontrolü | `node functions/tests/test_notification_settings.js` |
| **`functions/tests/test_notifications_menu.js`** | Bildirim Merkezi testleri: Fırsat Onay, Fırsat Red, Deduplication (Kelime > Yazar > Kategori) önceliklendirme ve dinamik içerik dönüşümü, Yorum Yanıt | `node functions/tests/test_notifications_menu.js` |
| **`functions/tests/test_all_notification_scenarios.js`** | Çaprazlama Uçtan Uca Bütünleşik Test Süiti: 10 Senaryonun tamamını canlı veritabanı üzerinde çapraz kontrol eder | `node functions/tests/test_all_notification_scenarios.js` |
