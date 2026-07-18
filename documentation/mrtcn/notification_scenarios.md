# 🔔 FırsatKolik — Bildirim ve Push Bildirim Senaryoları Rehberi (Notification Scenarios Guide)

Bu doküman, FırsatKolik platformundaki iki temel bildirim alanının ("Profilim -> Bildirimler" menüsü ve "Profilim -> Ayarlar -> Bildirim Ayarları" menüsü) işleyişini, tetikleme kurallarını, veri akışlarını ve tüm olası senaryoları detaylandırır.

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
   * Cloud Functions `onNotificationCreated` tetikleyicisi, bildirim kutusuna yeni bir doküman eklendiğinde devreye girer. Bu tercihlere, sistem limitlerine ve sessiz saatlere bakarak push bildirimini hedefler veya göndermeyi atlar (buna rağmen bildirim kutusunda kalır).

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

## ⚙️ 3. "Bildirim Ayarları" Menüsü (Push Bildirimleri) Senaryoları

Push bildirimlerinin telefona ulaşma karar ağacı Cloud Functions `onNotificationCreated` tetikleyicisi tarafından yönetilir.

### Tercihler ve Eşleşen Karar Senaryoları:

#### A. Telefon Bildirimleri (Master Switch - `pushMasterEnabled`)
* **Senaryo PUSH-MASTER-OFF:** `pushMasterEnabled: false` ise, bildirim türü ne olursa olsun push engellenir.
  * *Sonuç:* Firestore dokümanında `pushEligible: false`, `pushStatus: 'disabled_by_user_master_switch'` güncellenir. Bildirim telefona gitmez, sadece uygulama içi bildirim kutusunda görünür.
* **Senaryo PUSH-MASTER-ON:** `pushMasterEnabled: true` ise, diğer alt kanal ve zaman kuralları denetlenmeye başlar.

#### B. Kanal Bazlı Filtreler (`groupEnabled` Kontrolleri)
Master Switch açık olduğunda, bildirim türüne göre alt kanal ayarı kontrol edilir:
* **Takip Edilen Yazar Bildirimleri (`dealNotificationsEnabled`):**
  * `false` ve gelen bildirim nedeni `author` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_deal'`).
* **Topluluk Bildirimleri (`communityNotificationsEnabled`):**
  * `false` ve gelen bildirim tipi `comment_reply` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_comment_reply'`).
* **Paylaşım Durumu Bildirimleri (`submission_status`):**
  * Bu bildirim grubu için push gönderimi sistem tarafından kalıcı olarak kapatılmıştır (Sessiz Bildirim kuralı). `pushStatus` değeri her zaman `disabled_permanently_for_submission_status` olarak güncellenir ve telefona push uyarısı gitmeden doğrudan uygulama içi Bildirim Kutusu'nda saklanır.
* **Kampanya Bildirimleri (`marketingNotificationsEnabled`):**
  * `false` ve gelen bildirim tipi `marketing` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_marketing'`).
* **Kategori Bildirimleri (`categoryNotificationsEnabled`):**
  * `false` ve gelen bildirim nedeni `category` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_category'`).
* **Anahtar Kelime Bildirimleri (`keywordNotificationsEnabled`):**
  * `false` ve gelen bildirim nedeni `keyword` ise: Push engellenir (`pushStatus: 'disabled_by_user_group_keyword'`).

#### C. Zaman ve Saat Kısıtları (Sessiz Saatler - `quietHoursEnabled`)
* **Quiet Hours Aktif (`true`):** Kullanıcı local saat dilimine (`timezone`, Örn: `Europe/Istanbul`) göre şu anki saati hesaplar. Eğer saat `quietHoursStart` ile `quietHoursEnd` aralığındaysa (Örn: 23:00 - 08:00):
  * **İstisna:** Sadece `deal`, `keyword` ve `marketing` bildirim tipleri sessiz saatlerde engellenir. Mesaj (`message`) veya paylaşım durumu (`submission_status`) gibi acil/bireysel bildirimler sessiz saatlerden etkilenmeden push olarak gönderilmeye devam eder.
  * *Sonuç:* Engellenen bildirimler için `pushStatus: 'skipped_quiet_hours'` yazılır.
* **Quiet Hours Pasif (`false`):** Zaman filtresine takılmadan devam eder.

#### D. Kategori Limitleri (Hız Sınırları - Rate Limiting)
* Sadece `reason == 'category'` olan genel indirim bildirimleri için uygulanır.
* `systemConfig/notifications` içerisindeki `categoryHourlyLimit` (varsayılan: 3) ve `categoryDailyLimit` (varsayılan: 8) limitleri denetlenir.
* Kullanıcının son 1 saatte veya son 24 saatte aldığı başarılı (`pushStatus == 'sent'`) kategori bildirimleri sayılır.
* Limit aşılmışsa push engellenir ve dokümanda `pushStatus: 'skipped_category_limit'` yazılır.

#### E. Cihaz Durumları ve Token Geçerliliği
* **Cihaz Kontrolü:** Kullanıcının `userDevices` koleksiyonunda `active == true` olan en az bir cihaz kaydı bulunmalıdır. Yoksa `pushStatus: 'no_active_devices'` olarak işaretlenir.
* **Token Hatası:** FCM gönderimi sırasında API `messaging/registration-token-not-registered` (Geçersiz/Süresi geçmiş token) hatası dönerse:
  * İlgili cihazın `userDevices` belgesindeki `active` bayrağı `false` yapılır.
  * Push durumu `failed` olarak güncellenir.
* **Çıkış Yapma (`signOut`):** Kullanıcı uygulamadan çıkış yaptığında, o cihaza ait `userDevices` kaydı `active: false` yapılarak eski kullanıcının bildirimlerinin yeni oturumda görünmesi önlenir.

---

## 🛠️ 4. Test Otomasyonu ve Doğrulama Yapısı

Yukarıdaki tüm senaryoları izole ve kararlı bir şekilde test etmek için projedeki mevcut Firebase altyapısını kullanan iki adet test dosyası hazırlanmıştır:

### 1. Uygulama İçi Bildirim Kutusu Testleri (`test_notifications_menu.js`)
* **TEST 1 (Paylaşılan Fırsatın Onaylanma Senaryosu):** Yüklenen bir fırsat admin tarafından onaylandığında paylaşılan yazar için `deal_status_approved_{dealId}` dokümanının oluşturulduğunu test eder.
* **TEST 2 (Paylaşılan Fırsatın Reddedilme Senaryosu):** Yüklenen bir fırsat admin tarafından reddedildiğinde paylaşılan yazar için `deal_status_rejected_{dealId}` dokümanının oluşturulduğunu test eder.
* **TEST 3 (Çoklu Eşleşme ve Tekilleştirme):** Bir kullanıcı hem yazarı, hem kategoriyi hem de kelimeyi takip ediyorsa, tek bir bildirim belgesi oluşturulduğunu ve en yüksek önceliğe sahip neden olan `keyword` (anahtar kelime) şablonunun seçildiğini doğrular.
* **TEST 4 (Yorum Yanıt Senaryosu):** Bir yoruma yanıt yazıldığında, yazar için `reply_{commentId}_{userId}` formatında yorum yanıt bildirimi oluşturulduğunu doğrular.

### 2. Push Bildirim Ayarları Testleri (`test_notification_settings.js`)
Bu test dosyası, tüm push bildirim senaryolarını parametrik bir test matrisi (`testMatrix`) ile ve zaman/limit kısıtlarını izole test durumlarıyla denetler:

#### A. Parametrik Karar Matrisi Testleri (TEST 1)
* **Master Switch Kapalı Çapraz Kombinasyon Durumları (Alt senaryo 1.1 - 1.6):**
  * Kullanıcı arayüzünde Master Switch (`pushMasterEnabled: false`) kapalıyken bile tüm alt kanal ayarları (kategori, yazar, topluluk vb.) bağımsız olarak açılıp kapatılabilir.
  * Bu durumda veritabanında alt kanalların son seçili değerleri tutulur. Ancak gönderim esnasında Master Switch kapalı olduğu sürece, alt kanallar açık (`true`) ya da kapalı (`false`) olsun fark etmeksizin push bildirimi hedeflenen kanal bazında `disabled_by_user_master_switch` nedeni ile engellenir.
* **Alt Switch Kapalı Durumları (Alt senaryo 1.7 - 1.12):**
  * Master switch açık (`pushMasterEnabled: true`), ancak ilgili alt switch `false` olduğunda push bildiriminin hedeflenen kanal bazında engellendiğini (`disabled_by_user_group_{groupName}`) doğrular:
    * `categoryNotificationsEnabled: false` -> `disabled_by_user_group_category`
    * `keywordNotificationsEnabled: false` -> `disabled_by_user_group_keyword`
    * `dealNotificationsEnabled: false` -> `disabled_by_user_group_deal`
    * `communityNotificationsEnabled: false` -> `disabled_by_user_group_comment_reply`
    * `submissionStatusNotificationsEnabled: false` -> `disabled_by_user_group_submission_status`
    * `marketingNotificationsEnabled: false` -> `disabled_by_user_group_marketing`
* **Alt Switch Açık Durumları (Alt senaryo 1.13 - 1.18):**
  * Master switch açık (`pushMasterEnabled: true`) ve ilgili alt switch `true` olduğunda push bildiriminin filtreleri başarıyla aştığını (`pushEligible: true`) ve gönderime ulaştığını (`pushStatus: failed` - sahte test token'ı nedeniyle) doğrular.

#### B. Zaman ve Limit Filtreleri (TEST 2 - 5)
* **TEST 2 (Sessiz Saatler Filtresi):** Sessiz saatler aktifken standart indirim fırsatı push'larının `skipped_quiet_hours` ile engellendiğini doğrular.
* **TEST 3 (Sessiz Saatlerde Yorum Yanıtı Muafiyeti):** Bireysel yorum yanıtlarının sessiz saatler filtresinden muaf tutularak gönderime ulaştığını doğrular.
* **TEST 4 (Kategori Hız Limitleri):** Sistem saatlik limiti 1 iken, ardışık gelen 2. kategori bildiriminin `skipped_category_limit` ile engellendiğini doğrular.
* **TEST 5 (Aktif Cihaz Bulunmama):** Kullanıcının aktif bir cihaz kaydı bulunmadığında push gönderiminin `no_active_devices` ile atlandığını doğrular.

Bu testler, Google Cloud Service Account anahtarı (`dev_firebase_key.json`) kullanılarak Firebase DEV ortamında doğrudan çalıştırılabilir.


