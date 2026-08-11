# 🔔 FırsatKolik — Bildirim ve Push Bildirim Senaryoları Rehberi (vProduction - Nihai)

Bu doküman, FırsatKolik platformundaki iki temel bildirim alanının ("Profilim -> Bildirimler" menüsü ve "Profilim -> Ayarlar -> Bildirim Ayarları" menüsü) işleyişini, tetikleme kurallarını, kademeli pasifleştirme (parent-child) mantığını, veri akışlarını ve tüm olası senaryoları detaylandırır.

---

## 🗺️ 1. Genel Bakış ve Temel Farklar

Uygulama içerisinde bildirimlerle ilgili iki farklı kavram bulunur:

1. **"Bildirimler" Menüsü (Uygulama İçi Bildirim Kutusu / Notification Center):**
   * Kullanıcının geçmişe dönük aldığı tüm bildirimleri (Fırsat eşleşmeleri, yorum yanıtları, paylaşım durumları vb.) listelediği arayüzdür.
   * Firestore'da `users/{userId}/notifications` koleksiyonunda saklanır.
   * **Kritik Kural:** Bir bildirim tetiklendiğinde, kullanıcının push ayarları veya sessiz saatleri ne olursa olsun, bu doküman veritabanında **HER ZAMAN** oluşturulur. Yani push bildirimi gitmese bile bildirim kutusunda bu bildirim listelenmeye devam eder.

2. **"Bildirim Ayarları" Menüsü (Anlık Push Bildirimleri / FCM Push Notifications):**
   * Kullanıcının telefonuna gelen anlık uyarıların (Push) kanallarını, sessiz saatlerini ve genel izin durumunu yönettiği arayüzdür.
   * Firestore'da `users/{userId}/notificationPreferences/main` belgesinde saklanır.
   * Cloud Functions `onNotificationCreated` tetikleyicisi, bildirim kutusuna yeni bir doküman eklendiğinde devreye girer. Bu tercihlere, sistem limitlerine ve sessiz saatlere bakarak push bildirimini hedefler veya göndermeyi atlar (buna rağmen bildirim kutusında kalır).

---

## 📁 2. "Bildirimler" Menüsü (Uygulama İçi Bildirim Kutusu) Senaryoları

Bu arayüz, `users/{userId}/notifications` koleksiyonunu `createdAt` alanına göre azalan sırada canlı dinler.

### Olası Bildirim Türleri ve Tetiklenme Senaryoları:

| Senaryo ID | Bildirim Türü (`type`) | Tetikleyici Olay | Başlık (`title`) / İçerik (`body`) Şablonu | Koşul / Öncelik |
| :--- | :--- | :--- | :--- | :--- |
| **NOTIF-01** | `deal` (Kategori) | Abone olunan bir kategoriye ait fırsatın onaylanması | **🎯 Yeni Fırsat!**<br>Ürün Adı ve Fiyatı | Kategori aboneliği açık olmalı. Diğer nedenler yoksa en düşük öncelikle tetiklenir. |
| **NOTIF-02** | `deal` (Yazar) | Bildirim zili açılan bir yazarın (avcının) paylaştığı fırsatın onaylanması | **👤 Takip Ettiğiniz Kişi!**<br>Takip ettiğiniz yazar yeni fırsat paylaştı: [Fırsat Başlığı] | Yazar takibi açık olmalı. Orta önceliklidir. |
| **NOTIF-03** | `deal` (Anahtar Kelime)| Abone olunan kelimeyi (Örn: "xiaomi") içeren fırsatın onaylanması | **🎯 İlginizi Çeken Kelime!**<br>"[Kelime]" içeren yeni fırsat: [Fırsat Başlığı] | Kelime aboneliği açık olmalı. En yüksek önceliklidir (Deduplication). |
| **NOTIF-04** | `comment_reply` | Bir kullanıcının yazdığı yoruma başka bir kullanıcının cevap yazması | **[Kullanıcı Adı] yorumunuza cevap verdi**<br>Yorum içeriği (ilk 100 karakter) | Kendine yanıt verilmemiş olmalı. |
| **NOTIF-05** | `submission_status` (Onay) | Kullanıcının paylaştığı fırsatın admin tarafından onaylanması | **🎉 Fırsatınız Onaylandı!**<br>Paylaştığınız "[Fırsat Başlığı]" onaylandı ve yayına alındı. | Fırsat `isUserSubmitted: true` olmalı ve admin tarafından onaylanmalı. **[SESSİZ BİLDİRİM]** Push gönderilmez, sadece Bildirim Merkezinde (uygulama içi bildirim kutusunda) listelenir. |
| **NOTIF-06** | `submission_status` (Red) | Kullanıcının paylaştığı fırsatın admin tarafından reddedilmesi | **❌ Fırsatınız Reddedildi**<br>Paylaştığınız "[Fırsat Başlığı]" kurallarımıza uymadığı için reddedildi. | Fırsat `isUserSubmitted: true` olmalı ve admin tarafından reddedilmeli (`isRejected: true`). **[SESSİZ BİLDİRİM]** Push gönderilmez, sadece Bildirim Merkezinde (uygulama içi bildirim kutusunda) listelenir. |
| **NOTIF-07** | `admin_message` | Admin panelinden kullanıcıya manuel bildirim tetiklenmesi | **[Admin Başlığı]**<br>[Admin Mesajı] | Admin tarafından hedeflenen kullanıcıya özel oluşturulur. |

### Uygulama İçi Etkileşimler:
* **Okundu İşaretleme:** Kullanıcı bildirime tıkladığında `read` alanı `true` yapılır ve kalın/vurgulu stil kaldırılır.
* **Tekil Silme:** Bildirim satırındaki silme butonu dokümanı koleksiyondan siler.
* **Tümünü Silme:** Bildirimler ekranındaki çöp kutusu butonu kullanıcının tüm bildirim belgelerini siler.

---

## ⚙️ 3. "Bildirim Ayarları" Menüsü (Push Bildirimleri) Kusursuz UX & Mimari Şartnamesi (vProduction - Nihai)

Push bildirimlerinin telefona ulaşma karar ağacı Cloud Functions `onNotificationCreated` tetikleyicisi ve mobil uygulama tarafındaki 3 katmanlı parent-child mimarisi tarafından yönetilir.

### 📐 Kademeli Pasifleştirme ve Hiyerarşi Şeması:

```text
[ Katman 1: Master Switch - TELEFON BİLDİRİMLERİ ]
│
├── AÇIK ──► Katman 2 (Kanal Switch'leri) Aktif & Canlı Renklerde
│                 │
│                 ├── "Kategori Bildirimleri" AÇIK  ──► Katman 3 ("Kategori Tercihleri >") Tıklanabilir
│                 └── "Kategori Bildirimleri" KAPALI ──► Katman 3 ("Kategori Tercihleri >") GRİ & KİLİTLİ
│
└── KAPALI ─► TÜM ALT KANALLAR VE DETAY SATIRLARI GRİ & KİLİTLİ (%50 Opaklık / Tıklanamaz)
```

---

### Tercihler ve Eşleşen Karar Senaryoları:

#### A. Telefon Bildirimleri (Master Switch - `pushMasterEnabled`)
* **Görevi:** Telefona anlık Push Bildirim gönderilip gönderilmeyeceğini belirleyen ana vanadır.
* **Senaryo PUSH-MASTER-OFF:** `pushMasterEnabled: false` yapıldığında:
  * Altındaki tüm Katman 2 (Kanal Switch'leri) ve Katman 3 (Detay Yönlendirme Kartları) elemanları **%50 Opaklaşır (%50 Opacity / Gri)** ve tıklamalara kilitlenir.
  * **Durum Koruma (State Preservation):** Alt kanalların veritabanındaki `true/false` tercih değerleri **KESİNLİKLE EZİLMEZ VEYA SİLİNMEZ**.
  * **Cloud Functions Karar Mekanizması:** Cloud Functions push meşruiyetini kontrol ederken `pushMasterEnabled === false` tespit ettiği an, alt tercihler ne olursa olsun bildirimi `pushEligible: false`, `pushStatus: 'disabled_by_user_master_switch'` statüsü ile engeller.
* **Senaryo PUSH-MASTER-ON:** `pushMasterEnabled: true` yapıldığında:
  * Tüm alt elemanlar canlı renklerine döner ve etkileşime açılır.
  * Kullanıcının daha önce seçtiği özel tercihler (`State Preservation`) aynen geri yüklenir.

---

#### B. Kanal Bazlı Filtreler (`groupEnabled` Kontrolleri)
Master Switch `AÇIK` olduğu sürece kanallar bağımsız olarak açılıp kapatılabilir. Bir bildirim geldiğinde hedeflenen kanala göre kontrol yapılır:

* **Takip Edilen Yazar Bildirimleri (`dealNotificationsEnabled`):**
  * Gelen bildirim nedeni `author` iken ilgili ayar `false` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_author'`).
* **Topluluk Bildirimleri (`communityNotificationsEnabled`):**
  * Gelen bildirim tipi `comment_reply` iken ilgili ayar `false` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_comment_reply'`).
* **Paylaşım Durumu Bildirimleri (`submission_status`):**
  * Bu bildirim grubu için push gönderimi sistem tarafından kalıcı olarak kapatılmıştır (Sessiz Bildirim kuralı). `pushStatus` değeri her zaman `disabled_permanently_for_submission_status` olarak kalır.
* **Kampanya Bildirimleri (`marketingNotificationsEnabled`):**
  * Gelen bildirim tipi `marketing` iken ilgili ayar `false` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_marketing'`).
* **Kategori Bildirimleri (`categoryNotificationsEnabled`):**
  * Gelen bildirim nedeni `category` iken ilgili ayar `false` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_category'`).
* **Anahtar Kelime Bildirimleri (`keywordNotificationsEnabled`):**
  * Gelen bildirim nedeni `keyword` iken ilgili ayar `false` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_keyword'`).

---

#### C. Detay Tercih Satırları (`>` Chevron İçeren Kartlar) ve Mikro Kilitlenme
* **Detay Kartları:** `Kategoriler >` ve `Anahtar Kelimeler >` yönlendirme satırlarıdır.
* **Mikro Kilitlenme Kuralı:** 
  * Bir detay kartının tıklanabilir olması için hem **Master Switch** `AÇIK` olmalı HEM DE ilgili **Kanal Switch'i** `AÇIK` olmalıdır.
  * Kanal switch'i kapalıysa (örn: *"Kategori Bildirimleri = KAPALI"*), ilgili detay kartı (*"Kategoriler >"*) %50 grileşir ve kilitlenir.

---

#### D. Gri / Pasif Elemana Tıklanması (Dinamik Snackbar Uyarısı)
Kullanıcı grileşmiş ve kilitlenmiş bir alt elemana tıkladığında aksiyon gerçekleşmez; ekranın altında kilitlenme nedenine uygun **dinamik bir Snackbar uyarısı** belirir:
* **Master Switch KAPALI olduğu için kilitlendiyse:** 
  > *"Bu ayarı değiştirmek için önce yukarıdan Telefon Bildirimleri'ni açmalısınız."*
* **Kanal Switch'i KAPALI olduğu için detay kartı kilitlendiyse:** 
  > *"Bu ayarı değiştirmek için önce [İlgili Kanal Adı] Bildirimleri'ni açmalısınız."* *(Örn: "Bu ayarı değiştirmek için önce Kategori Bildirimleri'ni açmalısınız." veya "Bu ayarı değiştirmek için önce Anahtar Kelime Takibi Bildirimleri'ni açmalısınız.")*

---

#### E. Geri Bildirim ve Veri Kayıt Standartları (Silent Optimistic UI)
* **Sessiz Kayıt (Optimistic UI):** Kullanıcı switch'e bastığı an UI anında tepki verir, veri arka planda sessizce kaydedilir. Intrusive "Başarıyla Kaydedildi" popup/toast mesajı bulunmaz.
* **Hata Durumu:** İnternet kopması veya sunucu hatasında switch eski konumuna geri çekilir ve kırmızı bir uyarı gösterilir: *"Ayarlarınız güncellenemedi, lütfen bağlantınızı kontrol edin."*

---

#### F. Zaman ve Saat Kısıtları (Sessiz Saatler - `quietHoursEnabled`)
* **Quiet Hours Aktif (`true`):** Kullanıcı local saat dilimine (`timezone`, Örn: `Europe/Istanbul`) göre şu anki saati hesaplar. Eğer saat `quietHoursStart` ile `quietHoursEnd` aralığındaysa (Örn: 23:00 - 08:00):
  * **İstisna:** Sadece `deal`, `keyword` ve `marketing` bildirim tipleri sessiz saatlerde engellenir (`pushStatus: 'skipped_quiet_hours'`).
  * Yorum yanıtları (`comment_reply`) veya acil mesajlar sessiz saatlerden etkilenmeden push olarak gönderilmeye devam eder.
* **Quiet Hours Pasif (`false`):** Zaman filtresine takılmadan devam eder.

---

#### G. Kategori Limitleri (Hız Sınırları - Rate Limiting)
* Sadece `reason == 'category'` olan genel indirim bildirimleri için uygulanır.
* `systemConfig/notifications` içerisindeki `categoryHourlyLimit` (varsayılan: 3) ve `categoryDailyLimit` (varsayılan: 8) limitleri denetlenir.
* Kullanıcının son 1 saatte veya son 24 saatte aldığı başarılı (`pushStatus == 'sent'`) kategori bildirimleri sayılır.
* Limit aşılmışsa push engellenir ve dokümanda `pushStatus: 'skipped_category_limit'` yazılır.

---

#### H. Cihaz Durumları ve Token Geçerliliği
* **Cihaz Kontrolü:** Kullanıcının `userDevices` koleksiyonunda `active == true` olan en az bir cihaz kaydı bulunmalıdır. Yoksa `pushStatus: 'no_active_devices'` olarak işaretlenir.
* **Token Hatası:** FCM gönderimi sırasında API `messaging/registration-token-not-registered` hatası dönerse ilgili cihazın `active` bayrağı `false` yapılır.
* **Çıkış Yapma (`signOut`):** Kullanıcı uygulamadan çıkış yaptığında, cihaza ait `userDevices` kaydı `active: false` yapılarak eski kullanıcının bildirimlerinin yeni oturumda görünmesi önlenir.

---

## 🧪 4. Ekran Elemanları Durum Matrisi

| Arayüz Elemanı | Master AÇIK + Kanal AÇIK | Master AÇIK + Kanal KAPALI | Master KAPALI (Kanal Fark Etmez) |
| :--- | :--- | :--- | :--- |
| **Master Switch** | 🟢 Canlı / AÇIK | 🟢 Canlı / AÇIK | 🔴 Canlı / KAPALI |
| **Kanal Switch'leri** | 🟢 Canlı / Tıklanabilir | 🟢 Canlı / Tıklanabilir | 🔘 **Gri (%50 Opak) / Kilitli** (Seçim Saklanır) |
| **Detay Kartları (`>`)**| 🟢 Canlı / Sayfaya Gider | 🔘 **Gri (%50 Opak) / Kilitli** | 🔘 **Gri (%50 Opak) / Kilitli** |

---

## 🛠️ 5. Test Otomasyonu ve Doğrulama Yapısı

Mimariyi ve tüm senaryoları izole bir şekilde doğrulamak üzere hazırlanan test dosyaları ve koşum yöntemleri aşağıdadır:

### 1. Flutter Unit & State Preservation Testleri (`test/notification_logic_test.dart`)
* **Komut:** `flutter test test/notification_logic_test.dart`
* **Test 1:** Varsayılan bildirim tercihlerinin doğru geldiğini doğrular.
* **Test 2:** Serialization (toMap / fromFirestore) işlemlerinin doğruluğunu kontrol eder.
* **Test 3 (State Preservation):** Master Switch kapatıldığında alt tercihler ezilmeden saklandığını, Master Switch tekrar açıldığında kullanıcının eski tercihlerinin aynen korunduğunu test eder.

### 2. Push Bildirim Karar Matrisi Testleri (`functions/tests/test_notification_settings.js`)
* **Komut:** `node functions/tests/test_notification_settings.js`
* **TEST 1 (Parametrik Karar Matrisi):**
  * **Master Switch Kapalı Durumları:** Master switch `false` iken alt tercihler açık veya kapalı olsun, tüm bildirimlerin `pushStatus: 'disabled_by_user_master_switch'` ve `pushEligible: false` ile engellendiğini doğrular.
  * **Master Switch Açık, Alt Switch Kapalı Durumları:** Hedeflenen kanal bazında (`disabled_by_user_group_{groupName}`) engellendiğini doğrular.
  * **Master Switch Açık, Alt Switch Açık Durumları:** Filtrelerin başarıyla aşıldığını ve FCM push boru hattına ulaştığını doğrular.
* **TEST 2 (Sessiz Saatler Filtresi):** Sessiz saatlerde standart fırsat push'larının `skipped_quiet_hours` ile engellendiğini doğrular.
* **TEST 3 (Sessiz Saatlerde Yorum Yanıtı Muafiyeti):** Bireysel yorum yanıtlarının sessiz saatler filtresinden muaf tutulduğunu doğrular.
* **TEST 4 (Kategori Hız Limitleri):** Saatlik limit aşıldığında bildirimin `skipped_category_limit` ile engellendiğini doğrular.
* **TEST 5 (Aktif Cihaz Bulunmama):** Aktif cihaz bulunmadığında `no_active_devices` uyarısı ile atlandığını doğrular.

### 3. Uygulama İçi Bildirim Kutusu Testleri (`functions/tests/test_notifications_menu.js`)
* **Komut:** `node functions/tests/test_notifications_menu.js`
* Paylaşılan fırsat onay/red durumlarını, deduplication (önceliklendirme: keyword > author > category) ve yorum yanıt bildirimi oluşumlarını test eder.
