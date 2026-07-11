# FırsatKolik Bildirim Sistemi — Sade Firebase Roadmap

## 1. Amaç

Bu dokümanın amacı, FırsatKolik uygulamasındaki bildirim sistemini sade, anlaşılır ve Firebase ile uyumlu şekilde yeniden kurmaktır.

Hedef:

- Kullanıcı hangi bildirimi neden aldığını anlayabilmelidir.
- Aynı fırsat için birden fazla bildirim gönderilmemelidir.
- Push bildirimleri kapalı olsa bile uygulama içindeki Bildirim Merkezi çalışmaya devam etmelidir.
- Anahtar kelime bildirimleri hızlı ve öncelikli çalışmalıdır.
- Kategori bildirimleri kullanıcıyı rahatsız edecek sıklığa ulaşmamalıdır.
- Sistem orta ölçekli bir proje için kolay geliştirilebilir ve kolay yönetilebilir olmalıdır.

---

## 2. Mevcut Yapının Kısa Özeti

Mevcut sistemde:

- Ayarlar ekranında **Bildirim Ayarları** satırı ve bir switch bulunuyor.
- Bildirim Ayarları ekranında ayrıca **Tüm Bildirimler** switch’i var.
- Alt ayarlar:
  - Yorum Bildirimleri
  - Kategori Bildirimleri
  - Anahtar Kelime Bildirimleri
- Kategoriler ayrı bir ekranda seçiliyor.
- Anahtar kelimeler tek tek ekleniyor.

### Mevcut yapının temel sorunları

- İki farklı ana switch aynı işi yapıyor gibi görünüyor.
- Telefonun bildirim izni ile uygulama içindeki bildirim tercihi birbirine karışıyor.
- Kategori bildirimi ve kategori seçimi ayrı ayarlar gibi duruyor.
- Aynı fırsat hem anahtar kelimeye hem kategoriye uyarsa çift bildirim oluşabilir.
- Bildirimlerin uygulama içi kaydı ile telefona push gönderimi birbirinden net ayrılmıyor.

---

## 3. Yeni Yapının Temel Mantığı

Bildirim sistemi iki parçadan oluşur:

### 3.1 Uygulama içi Bildirim Merkezi

Oluşan tüm kullanıcı bildirimleri uygulama içindeki Bildirim Merkezi’ne kaydedilir.

Örnek:

- Takip edilen kelimeyle eşleşen fırsat
- Yoruma gelen yanıt
- Paylaşılan fırsatın yayınlanması

Kullanıcı telefon bildirimlerini kapatsa bile bu kayıtları uygulamayı açtığında görebilir.

### 3.2 Telefon push bildirimi

Bildirim Merkezi’ne yazılan kayıt, kullanıcının ayarları uygunsa ayrıca telefona push olarak gönderilir.

Push gönderimi için:

```text
Telefonun sistem izni açık
VE
Uygulamadaki Telefon Bildirimleri açık
VE
İlgili bildirim grubu açık
VE
Bildirim gönderim kurallarına uygun
```

Bu ayrım sistemin en temel kuralıdır.

---

## 4. Bildirim Ayarları Ekranı

Ayarlar ana ekranında ikinci bir switch bulunmamalıdır.

Yeni görünüm:

```text
Bildirimler
Bu cihazda açık / Kapalı / Telefon izni kapalı
>
```

Satıra dokunulduğunda Bildirim Ayarları ekranı açılır.

### Bildirim Ayarları

#### Telefon Bildirimleri

Tüm push bildirimlerini açıp kapatır.

- Kapatıldığında anahtar kelimeler ve kategori seçimleri silinmez.
- Tekrar açıldığında eski tercihler devam eder.
- Telefonun sistem izni kapalıysa kullanıcı telefon ayarlarına yönlendirilir.

#### Fırsat Bildirimleri

Bu bölümde:

- Anahtar Kelimeler
- Kategoriler
- Takip Edilen Fırsat Avcıları

yönetilir.

#### Topluluk Bildirimleri

Bu bölümde:

- Yorumlar
- Yanıtlar
- Etiketlemeler

yönetilir.

#### Paylaşım Durumu Bildirimleri

Bu bölümde kullanıcının paylaştığı fırsatın yayın ve moderasyon durumu yönetilir.

#### Kampanya Bildirimleri

Genel kampanya ve uygulama duyuruları için kullanılır.

Varsayılan olarak kapalı olmalıdır.

---

## 5. Bildirim Türleri

### 5.1 Anahtar Kelime Bildirimleri

Kullanıcının takip ettiği kelimeyle eşleşen yeni fırsatlar için gönderilir.

Örnek:

```text
“Dyson” için yeni fırsat
Dyson V15 Detect %32 indirimde.
```

Anahtar kelime eşleşmesi:

- Başlık
- Marka
- Model
- Ürün etiketi
- Gerekirse açıklama

alanlarında kontrol edilir.

Basit `contains` kullanılmamalıdır.

Örnek:

- `RAM` → “Kingston 16 GB RAM” ile eşleşir.
- `RAM` → “Program lisansı” ile eşleşmez.

İlk sürümde şu kontroller yeterlidir:

- Türkçe küçük harf dönüşümü
- Boşluk temizliği
- Noktalama temizliği
- Kelime sınırı
- Tam ifade eşleşmesi
- Aynı kelimenin tekrar eklenmesini engelleme

Gelişmiş eş anlamlı sistemi ilk sürümde zorunlu değildir.

---

### 5.2 Kategori Bildirimleri

Kullanıcı yalnızca ilgilendiği kategorileri seçer.

Örnek:

```text
Elektronik
Süpermarket
Kozmetik
```

Kategori bildirimleri her yeni fırsat için gönderilmez.

Sistem yalnızca:

- Yayında olan
- Süresi dolmamış
- Spam veya sahte görünmeyen
- Yeterli kalite seviyesine ulaşan

fırsatları değerlendirir.

Kullanıcıya “tüm fırsatlar” veya “sadece sıcak fırsatlar” gibi ek bir seçim gösterilmez.

Kategori seçiminde:

- Ana kategori seçilirse alt kategoriler de kapsanır.
- Bazı alt kategoriler seçilirse ana kategori kısmi seçili görünür.
- Aynı kategori için tekrar abonelik oluşturulmaz.

---

### 5.3 Takip Edilen Fırsat Avcıları

Bir kullanıcıyı takip etmek otomatik olarak push bildirimi açmaz.

Kullanıcı profilinde ayrı bir zil bulunur.

Örnek:

```text
Takip Et
Bildirim Zili
```

Zil açıksa, o kullanıcı yeni fırsat paylaştığında bildirim oluşur.

Örnek:

```text
Takip ettiğiniz kullanıcı yeni fırsat paylaştı
Mert, Amazon’da yeni bir kahve fırsatı paylaştı.
```

---

### 5.4 Topluluk Bildirimleri

Şu olayları kapsar:

- Kullanıcının fırsatına yorum gelmesi
- Kullanıcının yorumuna yanıt verilmesi
- Kullanıcının etiketlenmesi

Örnek:

```text
Yorumunuza yanıt geldi
Ayşe: “Bu fiyat hâlâ geçerli mi?”
```

Şunlar tek tek push göndermez:

- Her sıcak oy
- Her soğuk oy
- Her beğeni
- Kullanıcının kendi yaptığı işlem

---

### 5.5 Paylaşım Durumu Bildirimleri

Bu bölüm, kullanıcının kendi paylaştığı fırsatın yayın ve moderasyon sürecindeki önemli durum değişikliklerini kapsar.

#### Tetiklenebilecek senaryolar

- Fırsat incelemeye alındı
- Fırsat yayınlandı
- Düzenleme istendi
- Fırsat reddedildi
- Fırsat başka bir kayıtla birleştirildi
- Fırsat sona erdi
- Fırsat yayından kaldırıldı

Örnek:

```text
Fırsatınız yayınlandı
Dyson V15 fırsatınız yayına alındı.
```

Bu bildirimler yalnızca ilgili kullanıcıya gönderilir.

---

### 5.6 Kampanya Bildirimleri

Genel kampanya ve uygulama duyuruları için kullanılır.

Örnek:

```text
Hafta sonuna özel kampanya
Seçili kategorilerde yeni fırsatlar yayında.
```

Varsayılan olarak kapalı olmalıdır.

---

## 6. Aynı Fırsat İçin Tek Bildirim Kuralı

Bir fırsat aynı kullanıcı için birden fazla kuralla eşleşebilir.

Örnek:

- Kullanıcı `Dyson` kelimesini takip ediyor.
- Elektronik kategorisini takip ediyor.
- Fırsatı paylaşan kullanıcı için zil açık.

Bu durumda üç bildirim gönderilmez.

Tek bildirim oluşturulur.

Örnek:

```text
“Dyson” için yeni fırsat
Takip ettiğiniz kullanıcı yeni bir Dyson V15 fırsatı paylaştı.
```

Bildirim içinde eşleşme nedenleri saklanır:

```text
keyword: dyson
category: electronics
author: user_123
```

Ana bildirim nedeni şu sırayla seçilir:

1. Anahtar kelime
2. Takip edilen kullanıcı
3. Kategori

---

## 7. Bildirim Önceliği

Sistem iki seviyeli çalışır.

### Anlık Bildirimler

Mümkün olduğunca hemen gönderilir:

- Anahtar kelime eşleşmesi
- Takip edilen kullanıcının yeni fırsatı
- Yanıt ve etiketleme
- Kullanıcının paylaştığı fırsatın durumu

### Kontrollü Bildirimler

Sıklık sınırına tabidir:

- Kategori bildirimleri
- Kampanya bildirimleri

Başlangıç kuralı:

```text
Kategori bildirimleri:
- Saatte en fazla 3
- Günde en fazla 8
```

Bu limitler Firestore içindeki bir sistem ayar belgesinden yönetilebilir.

---

## 8. Sessiz Saatler

İlk sürümde basit bir sessiz saat sistemi yeterlidir.

Örnek:

```text
Sessiz Saatler
23.00 – 08.00
```

Bu saatlerde:

- Fırsat push bildirimleri gönderilmez.
- Bildirim yine uygulama içi Bildirim Merkezi’ne kaydedilir.
- Sabah eski fırsatlar tekrar push olarak gönderilmez.

İlk sürümde bekletilmiş bildirim kuyruğu veya sabah toplu gönderim yapılmaz.

---

## 9. Bildirim Merkezi

İlk sürümde tek kronolojik liste yeterlidir.

Örnek:

```text
Bildirimler

Bugün
- “Dyson” için yeni fırsat
- Yorumunuza yanıt geldi
- Fırsatınız yayınlandı

Dün
- Fırsatınız reddedildi
```

Gerekli temel özellikler:

- Okundu / okunmadı durumu
- Tümünü okundu işaretle
- Bildirim ayarlarına git
- Bildirime dokununca ilgili ekrana git
- Bildirim nedenini gösterebilme

İlk sürümde ayrı sekmeler zorunlu değildir.

---

## 10. Firebase Altyapısı

Kullanılacak temel servisler:

- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- Cloud Functions for Firebase
- Cloud Scheduler
- Firebase Analytics
- Firebase Crashlytics
- Firebase App Check
- Firebase Emulator Suite

### Basit Firestore Yapısı

```text
users/{uid}/notificationPreferences/main
users/{uid}/notifications/{notificationId}

notificationSubscriptions/{subscriptionId}

userDevices/{uid_deviceId}

systemConfig/notifications
```

### `notificationPreferences`

```text
pushMasterEnabled
dealNotificationsEnabled
communityNotificationsEnabled
submissionStatusNotificationsEnabled
marketingNotificationsEnabled
quietHoursEnabled
quietHoursStart
quietHoursEnd
timezone
updatedAt
schemaVersion
```

### `notificationSubscriptions`

```text
uid
type: keyword | category | author
key
displayValue
normalizedValue
includeDescendants
enabled
createdAt
updatedAt
```

Belge kimliği deterministik olmalıdır:

```text
{uid}_{type}_{keyHash}
```

Bu yapı aynı aboneliğin ikinci kez oluşmasını engeller.

### `userDevices`

```text
uid
deviceId
platform
fcmToken
permissionStatus
active
lastSeenAt
updatedAt
```

### `users/{uid}/notifications`

```text
type
entityType
entityId
title
body
reason
reasons
deepLink
pushEligible
pushStatus
createdAt
sentAt
readAt
```

Bildirim belge kimliği deterministik olmalıdır:

```text
{type}_{entityId}_{uid}
```

Bu sayede aynı bildirim ikinci kez oluşturulamaz.

### `systemConfig/notifications`

```text
categoryHourlyLimit
categoryDailyLimit
minimumDealQualityScore
enabled
updatedAt
```

---

## 11. Yeni Fırsat Yayınlandığında Çalışacak Akış

```text
1. Fırsat oluşturulur.
2. İçerik ve moderasyon kontrolleri tamamlanır.
3. Fırsat published durumuna geçer.
4. Cloud Function uygun kullanıcıları bulur.
5. Anahtar kelime, kategori ve takip edilen kullanıcı eşleşmeleri hesaplanır.
6. Aynı kullanıcıya ait eşleşmeler birleştirilir.
7. Kullanıcı için tek notification belgesi oluşturulur.
8. Bildirim Merkezi kaydı tamamlanır.
9. Push ayarları uygunsa FCM bildirimi gönderilir.
10. Gönderim sonucu notification belgesine yazılır.
```

Gönderimden hemen önce fırsat yeniden kontrol edilir:

- Hâlâ yayında mı?
- Süresi dolmuş mu?
- Kaldırılmış mı?
- Kullanıcı bildirimi kapatmış mı?

Geçersiz fırsat için push gönderilmez.

---

## 12. FCM Token Yönetimi

- Uygulama açıldığında cihaz token’ı güncellenir.
- Token değiştiğinde Firestore kaydı güncellenir.
- Kullanıcı çıkış yaptığında cihaz eski hesaptan ayrılır.
- FCM tarafından geçersiz olduğu bildirilen token pasif yapılır.
- Aynı cihaz için gereksiz tekrar kayıt oluşturulmaz.

---

## 13. Güvenlik Kuralları

- Kullanıcı yalnızca kendi tercihlerini değiştirebilir.
- Kullanıcı yalnızca kendi aboneliklerini yönetebilir.
- Kullanıcı yalnızca kendi bildirimlerini okuyabilir.
- Kullanıcı bildirim kaydının gönderim sonucunu değiştiremez.
- Push gönderimi yalnızca Cloud Functions üzerinden yapılır.
- Mobil uygulamanın çağırdığı callable veya HTTP Functions, Authentication ve App Check doğrulaması yapar.
- Firestore trigger ve zamanlanmış Functions Admin SDK ile çalışır.
- Firestore Rules Emulator ile test edilir.

---

# 14. Roadmap

## Aşama 1 — Bildirim modelini sabitle

Yapılacaklar:

- Bildirim türlerini tanımla.
- Ayar gruplarını tanımla.
- Deep-link formatını belirle.
- Bildirim belge kimliği formatını belirle.
- Ortak notification modelini oluştur.

Tamamlanma kriteri:

- Mobil uygulama ve Cloud Functions aynı bildirim modelini kullanıyor.
- Aynı bildirim ikinci kez oluşturulamıyor.

---

## Aşama 2 — Firestore yapısını kur

Yapılacaklar:

- Preferences koleksiyonunu oluştur.
- Subscription koleksiyonunu oluştur.
- Device token yapısını oluştur.
- Notification koleksiyonunu oluştur.
- Sistem limit belgesini oluştur.
- Security Rules ve index’leri ekle.

Tamamlanma kriteri:

- Kullanıcı yalnızca kendi verisini yönetebiliyor.
- Aynı abonelik iki kez oluşmuyor.
- Aynı bildirim iki kez oluşmuyor.

---

## Aşama 3 — Mobil bildirim ayarlarını yenile

Yapılacaklar:

- Ayarlar ana ekranındaki mükerrer switch’i kaldır.
- Tek Telefon Bildirimleri switch’i oluştur.
- Fırsat, Topluluk, Hesap ve Kampanya gruplarını ekle.
- Telefon izin durumunu göster.
- Telefon ayarlarına yönlendirme ekle.
- Tercihleri Firestore ile senkronize et.

Tamamlanma kriteri:

- Kullanıcı hangi ayarın ne yaptığını anlayabiliyor.
- Genel push kapatıldığında abonelikler silinmiyor.
- Telefon izni kapalıysa doğru durum gösteriliyor.

---

## Aşama 4 — Abonelik ekranlarını tamamla

Yapılacaklar:

- Anahtar kelime ekleme ve silme
- Tekrar eden kelimeleri engelleme
- Kategori seçimi
- Hiyerarşik kategori davranışı
- Kullanıcı profilinde bildirim zili

Tamamlanma kriteri:

- Anahtar kelimeler doğru normalize ediliyor.
- Aynı kategori veya kelime tekrar eklenmiyor.
- Kullanıcı takibi ile bildirim zili birbirinden ayrı çalışıyor.

---

## Aşama 5 — Bildirim üretimini kur

Yapılacaklar:

- Fırsat `published` olduğunda Function çalıştır.
- Anahtar kelime eşleştirmesini uygula.
- Kategori eşleştirmesini uygula.
- Takip edilen kullanıcı eşleştirmesini uygula.
- Aynı kullanıcı için eşleşmeleri birleştir.
- Tek notification belgesi oluştur.

Tamamlanma kriteri:

- Aynı fırsat için kullanıcıya tek bildirim oluşuyor.
- Bildirimin nedeni doğru kaydediliyor.
- Taslak veya reddedilen fırsat bildirim üretmiyor.

---

## Aşama 6 — Topluluk ve hesap bildirimlerini ekle

Yapılacaklar:

- Yorum
- Yanıt
- Etiketleme
- Fırsat yayın durumu

olaylarını ilgili sunucu işlemlerine bağla.

Tamamlanma kriteri:

- Kullanıcı kendi işleminden bildirim almıyor.
- Hesap bildirimleri yalnızca ilgili kullanıcıya gidiyor.
- Push kapalı olsa bile Bildirim Merkezi kaydı oluşuyor.

---

## Aşama 7 — FCM gönderimini tamamla

Yapılacaklar:

- Aktif token’lara push gönder.
- Push ayarlarını gönderim anında kontrol et.
- Geçersiz token’ları pasif yap.
- Kategori limitlerini uygula.
- Sessiz saatlerde fırsat push’larını atla.
- Gönderim sonucunu notification belgesine yaz.

Tamamlanma kriteri:

- Push kapalı kullanıcıya push gitmiyor.
- Bildirim Merkezi çalışmaya devam ediyor.
- Geçersiz token tekrar tekrar denenmiyor.
- Kategori bildirimleri limite uyuyor.

---

## Aşama 8 — Bildirim Merkezi ve deep link

Yapılacaklar:

- Tek kronolojik bildirim listesi oluştur.
- Okundu / okunmadı durumu ekle.
- Tümünü okundu işaretle aksiyonu ekle.
- Bildirimlere deep link bağla.
- Silinmiş içerik için güvenli boş durum ekle.

Tamamlanma kriteri:

- Bildirim doğru ekrana açılıyor.
- Silinmiş içerik uygulamayı hata ekranına düşürmüyor.
- Kullanıcı bildirim nedenini görebiliyor.

---

## Aşama 9 — Mevcut veriyi taşı

Yapılacaklar:

- Eski genel bildirim tercihini yeni yapıya taşı.
- Yorum tercihini Topluluk Bildirimleri’ne taşı.
- Kategori seçimlerini subscription yapısına taşı.
- Anahtar kelimeleri normalize ederek taşı.
- Tekrar eden kayıtları temizle.
- Migration işlemini tek seferlik ve tekrar çalıştırılabilir yap.

Tamamlanma kriteri:

- Kullanıcı tercihleri kaybolmuyor.
- Eski ve yeni sistem aynı anda çift push göndermiyor.
- Migration yeniden çalıştırılırsa veri bozulmuyor.

---

## Aşama 10 — Test ve yayın

Yapılacaklar:

- Anahtar kelime eşleşme testleri
- Dedupe testleri
- Kategori limit testleri
- Sessiz saat testleri
- Security Rules testleri
- Android ve iOS izin testleri
- Arka plan ve kapalı uygulama testleri
- Deep-link testleri
- Analytics olayları
- Kontrollü kullanıcı grubunda yayın

Önerilen Analytics olayları:

```text
notification_created
notification_sent
notification_opened
notification_read
notification_muted
notification_permission_denied
notification_deep_link_failed
```

Tamamlanma kriteri:

- Kritik akışlar test edilmiş.
- Çift bildirim oluşmuyor.
- Bildirim açılma oranı ölçülüyor.
- Deep-link hataları izlenebiliyor.
- Eski sistem güvenle kapatılmış.

---

## 15. Kesin İş Kuralları

1. Uygulama içi bildirim ile telefon push bildirimi ayrı kavramlardır.
2. Tüm bildirimler Bildirim Merkezi’ne kaydedilir.
3. Telefon Bildirimleri kapalıysa push gönderilmez.
4. Genel push kapatıldığında abonelikler silinmez.
5. Ayarlarda yalnızca tek ana push switch’i bulunur.
6. Aynı fırsat için aynı kullanıcıya tek bildirim oluşturulur.
7. Anahtar kelime eşleşmesi basit substring ile yapılmaz.
8. Kategori bildirimleri yalnızca uygun fırsatlar için oluşturulur.
9. Kullanıcı takibi ile bildirim zili ayrı çalışır.
10. Her oy ve beğeni için push gönderilmez.
11. Kampanya bildirimleri varsayılan kapalıdır.
12. Push yalnızca Cloud Functions üzerinden gönderilir.
13. Sessiz saatlerde fırsat push’ları atlanır, sabah tekrar gönderilmez.
14. Bildirim belge kimlikleri deterministik olur.
15. Gönderimden önce içerik geçerliliği tekrar kontrol edilir.
16. Kullanıcı çıkış yaptığında cihaz eski hesaptan ayrılır.
17. Silinmiş içerik için güvenli boş durum gösterilir.
18. Mevcut kullanıcı tercihleri migration sırasında korunur.

---

## 16. İlk Sürümde Kapsam Dışı

Aşağıdaki özellikler ilk sürümde zorunlu değildir:

- Günlük fırsat özeti
- Gelişmiş öneri sistemi
- Makine öğrenmesiyle bildirim zamanı
- Mağaza takibi
- Fiyat düşüşü bildirimi
- Stok geldi bildirimi
- Gelişmiş alias ve eş anlamlı motoru
- Çoklu Bildirim Merkezi sekmeleri
- Gelişmiş toplu bildirim sistemi

Temel yapı bu özelliklerin ileride eklenmesine engel olmamalıdır.

---

## 17. Definition of Done

Sistem şu koşullarda tamamlanmış kabul edilir:

- Tek ve anlaşılır bildirim ayar ekranı vardır.
- Telefon izni doğru yönetilir.
- Anahtar kelime, kategori ve kullanıcı abonelikleri çalışır.
- Aynı fırsat için çift bildirim oluşmaz.
- Tüm bildirimler uygulama içi merkeze kaydedilir.
- Uygun bildirimler ayrıca push olarak gönderilir.
- Kategori bildirimlerine sıklık limiti uygulanır.
- Bildirim Merkezi ve deep link’ler çalışır.
- FCM token yaşam döngüsü yönetilir.
- Güvenlik kuralları test edilmiştir.
- Analytics ve hata takibi aktiftir.
- Eski kullanıcı tercihleri kayıpsız taşınmıştır.
- Eski bildirim sistemi tamamen kapatılmıştır.
