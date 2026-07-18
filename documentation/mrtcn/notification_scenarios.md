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
* **Senaryo PUSH-MASTER-OFF:** `pushMasterEnabled: false` yapıldığında:
  * Tüm alt bildirim ayarları otomatik olarak kapalı konuma getirilir (`false` olarak Firestore'a yazılır).
  * Kullanıcıların eski tercihleri `lastStates` adında bir harita (Map) içerisinde yedeklenir.
  * Master switch kapalı olsa bile kullanıcı alt ayarları tek tek elle manuel olarak açabilir (açılanlar Firestore'da `true` olarak güncellenir ve `lastStates` haritasına da yansıtılır).
  * *Karar Mekanizması:* Alt ayarı kapalı olan tüm bildirimler `pushEligible: false`, `pushStatus: 'disabled_by_user_master_switch'` olarak engellenir. Manuel olarak açılan alt kanallar ise Master kapalı olsa dahi push uyarısı almaya devam eder (`pushEligible: true`).
* **Senaryo PUSH-MASTER-ON:** `pushMasterEnabled: true` yapıldığında:
  * Tüm alt bildirim kanalları, kullanıcının en son seçtiği veya kaydettiği durumlarına (yani `lastStates` haritasındaki yedek değerlerine) otomatik olarak geri döndürülür.
  * *Karar Mekanizması:* Diğer alt kanal, limit ve sessiz saat kuralları olağan şekilde denetlenmeye başlar.

#### B. Kanal Bazlı Filtreler (`groupEnabled` Kontrolleri)
Master Switch açık olduğunda veya Master Switch kapalıyken ilgili alt ayar manuel olarak açıldığında, bildirim türüne göre alt kanal ayarı kontrol edilir:
* **Takip Edilen Yazar Bildirimleri (`dealNotificationsEnabled`):**
  * Gelen bildirim nedeni `author` iken ilgili ayar `false` ise: Push engellenir (Master açıkken `pushStatus: 'disabled_by_user_group_deal'`, Master kapalıyken `pushStatus: 'disabled_by_user_master_switch'`).
* **Topluluk Bildirimleri (`communityNotificationsEnabled`):**
  * Gelen bildirim tipi `comment_reply` iken ilgili ayar `false` ise: Push engellenir (Master açıkken `pushStatus: 'disabled_by_user_group_comment_reply'`, Master kapalıyken `pushStatus: 'disabled_by_user_master_switch'`).
* **Paylaşım Durumu Bildirimleri (`submission_status`):**
  * Bu bildirim grubu için push gönderimi sistem tarafından kalıcı olarak kapatılmıştır (Sessiz Bildirim kuralı). `pushStatus` değeri her zaman `disabled_permanently_for_submission_status` olarak güncellenir ve telefona push uyarısı gitmeden doğrudan uygulama içi Bildirim Kutusu'nda saklanır.
* **Kampanya Bildirimleri (`marketingNotificationsEnabled`):**
  * Gelen bildirim tipi `marketing` iken ilgili ayar `false` ise: Push engellenir (Master açıkken `pushStatus: 'disabled_by_user_group_marketing'`, Master kapalıyken `pushStatus: 'disabled_by_user_master_switch'`).
* **Kategori Bildirimleri (`categoryNotificationsEnabled`):**
  * Gelen bildirim nedeni `category` iken ilgili ayar `false` ise: Push engellenir (Master açıkken `pushStatus: 'disabled_by_user_group_category'`, Master kapalıyken `pushStatus: 'disabled_by_user_master_switch'`).
* **Anahtar Kelime Bildirimleri (`keywordNotificationsEnabled`):**
  * Gelen bildirim nedeni `keyword` iken ilgili ayar `false` ise: Push engellenir (Master açıkken `pushStatus: 'disabled_by_user_group_keyword'`, Master kapalıyken `pushStatus: 'disabled_by_user_master_switch'`).

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
* **Master Switch Kapalı Durumları (Alt senaryo 1.1 - 1.3):**
  * `pushMasterEnabled: false` olduğunda; kategori, yazar veya topluluk alt switchleri açık olsa dahi push bildiriminin `disabled_by_user_master_switch` ile engellendiğini doğrular.
* **Alt Switch Kapalı Durumları (Alt senaryo 1.4 - 1.9):**
  * Master switch açık, ancak ilgili alt switch `false` olduğunda push bildiriminin hedeflenen kanal bazında engellendiğini (`disabled_by_user_group_{groupName}`) doğrular:
    * `categoryNotificationsEnabled: false` -> `disabled_by_user_group_category`
    * `keywordNotificationsEnabled: false` -> `disabled_by_user_group_keyword`
    * `dealNotificationsEnabled: false` -> `disabled_by_user_group_deal`
    * `communityNotificationsEnabled: false` -> `disabled_by_user_group_comment_reply`
    * `submissionStatusNotificationsEnabled: false` -> `disabled_by_user_group_submission_status`
    * `marketingNotificationsEnabled: false` -> `disabled_by_user_group_marketing`
* **Alt Switch Açık Durumları (Alt senaryo 1.10 - 1.15):**
  * Master switch açık ve ilgili alt switch `true` olduğunda push bildiriminin filtreleri başarıyla aştığını (`pushEligible: true`) ve gönderime ulaştığını (`pushStatus: failed` - sahte test token'ı nedeniyle) doğrular.

#### B. Zaman ve Limit Filtreleri (TEST 2 - 5)
* **TEST 2 (Sessiz Saatler Filtresi):** Sessiz saatler aktifken standart indirim fırsatı push'larının `skipped_quiet_hours` ile engellendiğini doğrular.
* **TEST 3 (Sessiz Saatlerde Yorum Yanıtı Muafiyeti):** Bireysel yorum yanıtlarının sessiz saatler filtresinden muaf tutularak gönderime ulaştığını doğrular.
* **TEST 4 (Kategori Hız Limitleri):** Sistem saatlik limiti 1 iken, ardışık gelen 2. kategori bildiriminin `skipped_category_limit` ile engellendiğini doğrular.
* **TEST 5 (Aktif Cihaz Bulunmama):** Kullanıcının aktif bir cihaz kaydı bulunmadığında push gönderiminin `no_active_devices` ile atlandığını doğrular.

Bu testler, Google Cloud Service Account anahtarı (`dev_firebase_key.json`) kullanılarak Firebase DEV ortamında doğrudan çalıştırılabilir.

