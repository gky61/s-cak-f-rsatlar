Sadeleştirilmiş, orta ölçekli bir admin dashboard için daha uygulanabilir hale getirilmiş sürüm:

# FırsatKolik Admin Dashboard Roadmap

## 1. Amaç

Bu admin dashboard’un amacı; uygulamadaki fırsatları yönetmek, kullanıcı etkileşimlerini görmek, Telegram botunun çalışıp çalışmadığını takip etmek ve temel teknik/maliyet durumunu kontrol etmektir.

Panel çok karmaşık olmamalı. İlk aşamada odaklanılması gereken şeyler:

* Fırsatların kolayca onaylanması
* Uygulama kullanımının takip edilmesi
* Telegram botunun sağlıklı çalışıp çalışmadığının görülmesi
* Bildirimlerin gidip gitmediğinin kontrol edilmesi
* Temel maliyet ve hata takibinin yapılması

---

# 2. Önerilen Menü Yapısı

Admin panelde şu ana menüler yeterli olur:

1. **Genel Bakış**
2. **Fırsat Yönetimi**
3. **Kullanıcı ve Etkileşim Analitiği**
4. **Telegram Bot Durumu**
5. **Yapay Zekâ / Gemini Durumu**
6. **Bildirimler**
7. **Teknik Durum ve Maliyet**
8. **Hatalar ve Loglar**
9. **Ayarlar**

Bu yapı hem sade kalır hem de projeyi yönetmek için gerekli temel verileri gösterir.

---

# 3. Genel Bakış

Bu sayfa admin panelin ana ekranı olmalı. Yönetici panele girdiğinde uygulamanın genel durumunu hızlıca görebilmeli.

## Gösterilecek Temel Kartlar

* Toplam kullanıcı sayısı
* Bugünkü aktif kullanıcı sayısı
* Bugün gelen fırsat sayısı
* Onay bekleyen fırsat sayısı
* Bugün onaylanan fırsat sayısı
* Bugün reddedilen fırsat sayısı
* Bugün gönderilen bildirim sayısı
* Telegram bot durumu
* Gemini API durumu
* Bugünkü tahmini maliyet
* Son hata

## Basit Grafikler

* Son 7 gün gelen fırsat sayısı
* Son 7 gün aktif kullanıcı sayısı
* Son 7 gün onaylanan fırsat sayısı
* Kategori bazlı fırsat dağılımı
* Bildirim gönderim grafiği

Bu ekranın amacı detaylı analiz değil, genel tabloyu hızlıca göstermektir.

---

# 4. Fırsat Yönetimi

Bu bölüm admin panelin en önemli kısmıdır. Telegram botundan veya kullanıcıdan gelen fırsatlar burada yönetilir.

## Liste Alanları

* Fırsat başlığı
* Görsel
* Kategori
* Fırsat linki
* Kaynak
* Oluşturulma tarihi
* Durum: bekliyor / onaylandı / reddedildi
* AI tarafından oluşturulan açıklama veya başlık
* Admin işlem durumu

## Filtreler

* Onay bekleyenler
* Onaylananlar
* Reddedilenler
* Bugün gelenler
* Kategoriye göre filtreleme
* Kaynağa göre filtreleme

## Admin Aksiyonları

* Onayla
* Reddet
* Düzenle
* Kategori değiştir
* Linki kontrol et
* Fırsatı pasife al

## Takip Edilecek Metrikler

* Günlük gelen fırsat sayısı
* Günlük onaylanan fırsat sayısı
* Günlük reddedilen fırsat sayısı
* Ortalama onay süresi
* En çok fırsat gelen kategoriler
* En çok fırsat gelen kaynaklar

Bu bölüm karmaşık olmamalı. Adminin hızlı karar verebileceği sade bir onay ekranı yeterlidir.

---

# 5. Kullanıcı ve Etkileşim Analitiği

Bu bölüm uygulamanın gerçekten kullanılıp kullanılmadığını gösterir.

## Kullanıcı Metrikleri

* Toplam kullanıcı sayısı
* Günlük aktif kullanıcı
* Haftalık aktif kullanıcı
* Aylık aktif kullanıcı
* Yeni kullanıcı sayısı
* Bildirim izni veren kullanıcı sayısı

## Etkileşim Metrikleri

* Fırsat görüntüleme sayısı
* Fırsat detayına girme sayısı
* Dış linke tıklama sayısı
* Yorum sayısı
* Favoriye ekleme sayısı
* Paylaşım sayısı

## Fırsat Performansı

* En çok görüntülenen fırsatlar
* En çok tıklanan fırsatlar
* En çok yorum alan fırsatlar
* En çok favorilenen fırsatlar
* En çok ilgi gören kategoriler

Bu sayfa Google Analytics gibi çok detaylı olmak zorunda değil. Temel amaç, kullanıcıların uygulamada gerçekten ne yaptığını görebilmektir.

---

# 6. Telegram Bot Durumu

Bu bölüm Telegram botunun gerçekten çalışıp çalışmadığını kontrol etmek için olmalı.

## Gösterilecek Bilgiler

* Bot aktif mi?
* Dev bot durumu
* Prod bot durumu
* Son mesaj yakalama zamanı
* Son başarılı fırsat kaydı
* Bugün yakalanan mesaj sayısı
* Bugün fırsata dönüştürülen mesaj sayısı
* Hata alan mesaj sayısı
* Duplicate olduğu için atlanan mesaj sayısı
* Botun çalışma süresi
* Son hata mesajı

## Basit Grafikler

* Saatlik yakalanan Telegram mesajları
* Günlük kaydedilen fırsatlar
* Bot hata sayısı

## Önerilen Teknik Ekleme

Bot belirli aralıklarla Firestore’a sağlık bilgisi yazmalı.

Örnek alanlar:

* `status`
* `lastHeartbeatAt`
* `lastMessageAt`
* `lastProcessedMessageId`
* `lastError`
* `environment`

Dashboard bu veriden botun canlı olup olmadığını anlayabilir.

---

# 7. Yapay Zekâ / Gemini Durumu

Bu bölüm Gemini’nin sağlıklı çalışıp çalışmadığını ve fırsat analizlerinde ne kadar başarılı olduğunu göstermeli.

## Gösterilecek Bilgiler

* Gemini API çalışıyor mu?
* Son başarılı analiz zamanı
* Son başarısız analiz zamanı
* Bugün yapılan analiz sayısı
* Başarılı analiz sayısı
* Başarısız analiz sayısı
* Ortalama yanıt süresi
* JSON format hatası sayısı
* Kategori eşleştirme hatası sayısı
* Günlük tahmini Gemini maliyeti

## Takip Edilecek Basit Metrikler

* AI başarı oranı
* AI hata oranı
* Ortalama analiz süresi
* Fırsat başına ortalama token/maliyet
* En çok hata alan analiz türleri

Bu bölümde çok teknik detaya girmeye gerek yok. Asıl amaç Gemini cevap veriyor mu, hata oranı yükseldi mi, maliyet kontrolden çıkıyor mu gibi soruları cevaplamaktır.

---

# 8. Bildirimler

Bu bölüm FCM push bildirimlerinin durumunu göstermeli.

## Gösterilecek Bilgiler

* Bugün gönderilen toplam bildirim sayısı
* Genel fırsat bildirimi sayısı
* Keyword bazlı bildirim sayısı
* Başarılı gönderim sayısı
* Başarısız gönderim sayısı
* Geçersiz token sayısı
* Bildirimden gelen kullanıcı sayısı

## Takip Edilecek Metrikler

* Bildirim gönderim başarı oranı
* Bildirim açılma oranı
* En çok tıklama alan bildirimler
* En çok bildirim tetikleyen keyword’ler

## Admin Aksiyonları

* Test bildirimi gönder
* Belirli kullanıcıya test bildirimi gönder
* Bildirim geçmişini gör
* Hatalı token’ları temizle

Bu bölüm sade tutulmalı. Bildirim gidiyor mu, açılıyor mu, hata var mı sorularına cevap vermesi yeterlidir.

---

# 9. Teknik Durum ve Maliyet

Bu bölüm teknik altyapının genel sağlığını göstermek için olmalı.

## Cloud Run

* Telegram bot servisi aktif mi?
* Dev/prod servis durumu
* Son deploy zamanı
* Çalışma süresi
* Restart sayısı
* CPU kullanımı
* Memory kullanımı
* Hata sayısı

## Cloud Functions

* Bugün tetiklenme sayısı
* Başarılı çalışma sayısı
* Hata sayısı
* Ortalama çalışma süresi
* Son hata

## Firestore

* Günlük okuma sayısı
* Günlük yazma sayısı
* En çok kullanılan koleksiyonlar
* Hata sayısı

## Storage

* Toplam kullanılan alan
* Bugün yüklenen görsel sayısı
* Ortalama görsel boyutu

## Maliyet

* Bugünkü tahmini maliyet
* Son 7 gün maliyeti
* Son 30 gün maliyeti
* Cloud Run maliyeti
* Firestore maliyeti
* Storage maliyeti
* Gemini maliyeti

Bu bölümde çok derin fatura analizi şart değil. İlk aşamada temel maliyet takibi ve anormal artışları görmek yeterli olur.

---

# 10. Hatalar ve Loglar

Bu bölüm teknik sorunları hızlıca görmek için olmalı.

## Gösterilecek Hatalar

* Telegram bot hataları
* Gemini API hataları
* Firestore hataları
* Storage hataları
* Bildirim hataları
* Cloud Functions hataları
* Admin panel hataları

## Log Alanları

* Tarih
* Ortam: dev / prod
* Servis adı
* Hata tipi
* Hata mesajı
* İlgili fırsat ID
* Çözülme durumu

## Basit Kartlar

* Bugünkü toplam hata sayısı
* Kritik hata sayısı
* Son hata
* En çok hata veren servis
* Çözülmemiş hata sayısı

Bu bölüm geliştirici için karmaşık olmayan, hızlı okunabilir bir hata merkezi gibi çalışmalı.

---

# 11. Ayarlar

Bu bölüm temel admin ayarlarını içermeli.

## Yönetilecek Ayarlar

* Admin kullanıcıları
* Admin rolleri
* Telegram kanal listesi
* Dev/prod ortam seçimi
* Bildirim ayarları
* Kategori listesi
* AI kategori eşleştirme ayarları
* Maksimum günlük bildirim limiti
* Bot aktif/pasif durumu

## Admin Rolleri

* Super Admin
* Moderatör
* Sadece görüntüleme yetkisi

İlk aşamada çok detaylı rol sistemi gerekmez. Bu üç rol yeterlidir.

---

# 12. İlk Sürümde Mutlaka Olması Gerekenler

İlk sürüm için en önemli özellikler şunlardır:

1. Genel bakış ekranı
2. Onay bekleyen fırsatlar
3. Fırsat onaylama / reddetme / düzenleme
4. Günlük gelen ve onaylanan fırsat sayısı
5. Telegram bot canlılık durumu
6. Son yakalanan Telegram mesajı
7. Gemini başarı/hata durumu
8. Bildirim gönderim durumu
9. Temel kullanıcı ve etkileşim verileri
10. Son hatalar
11. Günlük tahmini maliyet
12. Dev/prod ortam ayrımı

Bu 12 madde yapılırsa ilk admin dashboard kullanışlı ve yeterli olur.

---

# 13. Geliştirme Sırası

## Aşama 1 — Temel Admin Panel

* Genel Bakış
* Fırsat Yönetimi
* Telegram bot durumu
* Son hatalar

## Aşama 2 — Analitik

* Kullanıcı sayıları
* Fırsat görüntüleme/tıklama verileri
* Kategori performansı
* Bildirim performansı

## Aşama 3 — Teknik Takip

* Cloud Run durumu
* Cloud Functions durumu
* Firestore kullanım verileri
* Gemini kullanım verileri
* Maliyet takibi

## Aşama 4 — Ayarlar ve Yetkiler

* Admin rolleri
* Telegram kanal yönetimi
* Bildirim ayarları
* Kategori yönetimi
* AI kategori eşleştirme ayarları

---

# 14. Sonuç

FırsatKolik için admin dashboard’un ilk sürümünde aşırı detaydan kaçınmak daha doğru olur.

Panelin ilk hedefi şu olmalı:

* Fırsatlar kolay yönetilsin
* Botun çalışıp çalışmadığı görülsün
* Uygulama kullanımı takip edilsin
* Gemini ve bildirim sistemi kontrol edilsin
* Hatalar ve maliyet temel seviyede izlensin

Bu yapı orta ölçekli bir uygulama için yeterli, sade ve yönetilebilir bir admin dashboard oluşturur.

Bu sürüm önceki rapora göre daha uygulanabilir. Gereksiz teknik derinliği azalttım, ama proje yönetimi için gerçekten lazım olan metrikleri tuttum.
