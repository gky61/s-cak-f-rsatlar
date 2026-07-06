# 🖥️ FırsatKolik — Yönetici Paneli Mevcut Durum Analizi (Admin Panel Features)

Bu doküman, FırsatKolik projesinin web tabanlı Yönetici (Admin) Paneli'nin (`web/admin`) mevcuttaki tüm menülerini, özelliklerini, veri akışlarını ve bunların teknik çalışırlık durumlarını (aktif/pasif) analiz etmek amacıyla oluşturulmuştur.

---

## 🔐 1. Giriş Kontrolü ve Yetkilendirme (Auth & ACL)
*   **Giriş Mekanizması:** Google ile Giriş (`signInWithPopup` fallback: `signInWithRedirect`) aktiftir.
*   **Yetki Kontrolü:** Giriş yapan kullanıcının UID'si ile Firestore'daki `users`, `userProfiles` veya `profiles` koleksiyonundaki dokümanı sorgulanır.
*   **Kontrol Koşulu:** İlgili dokümandaki `isAdmin` veya `isadmin` alanı `true` veya `1` olmalıdır. Yetkisi olmayan kullanıcılar `auth.signOut()` ile sistemden otomatik çıkartılır ve hata mesajı gösterilir.

---

## 📊 2. Menüler ve İşlevsel Özellik Analizi

### 🔹 A. Dashboard & Fırsatlar Görünümü (Deals View) — ✅ %100 ÇALIŞIYOR
Yönetim panelinin ana sayfasıdır. Fırsatların durumunu izleme ve onaylama süreçlerini barındırır.

#### 📈 İstatistik Kartları (Real-time):
*   **Onay Bekleyen:** `isApproved == false` olan fırsatların sayısı.
*   **Toplam Aktif:** `isApproved == true` olan fırsatların sayısı.
*   **Bot Tarafından:** `isUserSubmitted == false` veya tanımsız olan fırsatlar.
*   **Kullanıcı Tarafından:** `isUserSubmitted == true` olan fırsatlar.

#### 🔍 Arama ve Filtreleme:
*   Fırsat başlığı, ID veya marka araması (`searchInput` - Client-side filtreleme ile).
*   **Filtreler:** "Onay Bekleyen", "Onaylanmış" ve "Tümü" durum butonları.
*   **Sıralama (Select):** "En Yeni", "En Eski", "Fiyat: Artan", "Fiyat: Azalan" seçenekleri.

#### 📝 Fırsat Yönetim Tablosu:
*   **Fırsat Ekleme (Add Deal Modal):** Yeni fırsat başlığı, açıklama, piyasa fiyatı, indirimli fiyat, ürün linki, kupon kodu, kargo durumu, kategori ve alt kategori bilgileri girilerek sıfırdan fırsat oluşturulabilir.
*   **Görsel Yükleme (Firebase Storage):** Fırsat detay modalı üzerinden bilgisayardan yeni görsel yüklenebilir. Yüklenen görsel `deals/{dealId}/{timestamp}_{name}` olarak Storage'a aktarılır.
*   **Görsel Değiştirme (Swap):** Birden fazla görsel varsa, ana görsel ile ikinci görselin sırası tek tuşla değiştirilip Firestore'a anında kaydedilir (`window.swapMainImage`).
*   **Detay Modalı & Düzenleme (Edit):** Başlık, açıklama (Markdown destekli), fiyatlar, kupon, kargo, kategori ve "Sıcak Fırsat" (isHot) durumu güncellenebilir.
*   **Onaylama (Approve):** Fırsatı yayına alır (`isApproved: true`). 
*   **Silme / Reddetme (Delete):** Fırsatı Firestore'dan kalıcı olarak siler.

---

### 🔹 B. Kullanıcılar Görünümü (Users View) — ✅ %100 ÇALIŞIYOR
Sistemde kayıtlı kullanıcıların listelendiği ve cezalandırma/ödüllendirme işlemlerinin yapıldığı bölümdür.

#### 📊 Kullanıcı İstatistik Kartları:
*   **Toplam Kullanıcı:** Kayıtlı toplam üye sayısı.
*   **Toplam Fırsat:** Kullanıcılar tarafından eklenen toplam fırsat adedi.
*   **Toplam Puan:** Tüm kullanıcıların kazandığı toplam puan.

#### 👤 Kullanıcı Arama & Detay Modalı:
*   Kullanıcı adı, e-posta veya UID ile anlık arama.
*   **Kullanıcı Detayları (Modal):** Kullanıcının puanı, eklediği fırsat sayısı, aldığı beğeni sayısı, takipçi ve takip edilen bilgileri gösterilir.
*   **Rozet Yönetimi (Badges):** Kullanıcıya yeni rozet (Örn: "Editör", "Kral Paylaşımcı") atanabilir veya var olan rozet silinebilir (`badges` array'i güncellenir).
*   **Yorumları Listeleme & Silme:** Kullanıcının yaptığı tüm yorumlar modal üzerinden listelenir. Gerektiğinde tek tıkla silinebilir ve ilgili fırsatın `commentCount` değeri otomatik düşürülür.
*   **Kullanıcı Engelleme (Block):** Kullanıcının UID'si `blockedUsers` koleksiyonuna eklenerek uygulamaya girişi engellenir.
*   **Yorum Engeli (Comment Ban):** Kullanıcının UID'si `commentBannedUsers` koleksiyonuna eklenerek uygulamada yorum yazması engellenir.
*   **Paylaşım Engeli (Deal Ban):** Kullanıcının UID'si `dealBannedUsers` koleksiyonuna eklenerek fırsat paylaşması engellenir.

---

### 🔹 C. Moderasyon Mesajları Görünümü (Messages View) — ✅ %100 ÇALIŞIYOR
Uygunsuz içerik (fırsat veya yorum) paylaştığı için sistem tarafından moderasyona düşürülen durumları veya kullanıcılara atılan uyarı bildirimlerini yönetir.

*   **Mesaj Listesi:** Moderasyon olayları tarih, kullanıcı, içerik tipi (fırsat/yorum) ve detay bilgisiyle listelenir.
*   **Hızlı İşlemler:**
    *   **İncele:** İlgili fırsatın detay modalını anında açar.
    *   **Okundu İşaretle:** Mesajın durumunu günceller.
    *   **Sil:** Olay kaydını temizler.
    *   **Tümünü Sil:** `adminMessages` koleksiyonundaki tüm verileri batch işlemiyle siler.
*   **Kullanıcıya Özel Uyarı Mesajı Gönderme (Admin Message):** Kullanıcı detay ekranından tetiklenen `sendAdminMessage` fonksiyonu ile `adminToUserMessages` koleksiyonuna veri yazılır. Bu mesajlar mobil uygulamada kullanıcıya tek yönlü bildirim/uyarı olarak gösterilir.

---

### 🔹 D. Raporlar Görünümü (Reports View) — ❌ ARAYÜZDE VAR, ARKAPLANI EKSİK (PASİF)
*   **Durum:** Sidebar menüsünde "Raporlar" seçeneği mevcuttur ancak tıklandığında herhangi bir görünüm (`#reportsView`) tetiklenmemektedir. `app.js` içerisinde raporlama veya analiz grafiklerine dair hiçbir kod bulunmamaktadır. Sadece boş bir navigasyon linkidir.

---

### 🔹 E. Ayarlar Görünümü (Settings View) — ❌ ARAYÜZDE VAR, ARKAPLANI EKSİK (PASİF)
*   **Durum:** Sidebar menüsünde "Ayarlar" butonu yer almasına rağmen tıklandığında bir görünüm açmaz. Ancak, global ayarlar olan "Paylaşımı Engelle" ve "Yorumları Durdur" butonları bu menüden bağımsız olarak doğrudan **Fırsatlar** sayfasındaki toolbar üzerinde yer almaktadır (bkz. Bölüm 3).

---

## ⚙️ 3. Kritik Sistem Kontrolleri (Global Settings)
Yönetim panelinin en üstünde yer alan ve Firestore'daki `settings/app` dokümanını güncelleyen iki adet acil durum freni bulunur:

1.  **Paylaşımı Engelle (`toggleDealSharing`):**
    *   Firestore'daki `settings/app` dokümanının `dealSharingEnabled` alanını `true`/`false` olarak değiştirir.
    *   Bu ayar kapatıldığında, mobil uygulamada kullanıcıların yeni fırsat paylaşma fonksiyonu tamamen durdurulur.
2.  **Yorumları Durdur (`toggleCommentSharing`):**
    *   Firestore'daki `settings/app` dokümanının `commentSharingEnabled` alanını `true`/`false` olarak değiştirir.
    *   Bu ayar kapatıldığında, mobil uygulamadaki yorum yapma alanları kapatılır.

---

## 🔗 4. Otomatik Entegrasyonlar ve Akıllı Link Dönüştürme

Fırsat listesindeki onay butonuna basıldığında arka planda iki kritik süreç tetiklenir:

### 1️⃣ Otomatik Kısa Link Çözümleme (Short Link Resolution)
*   Eğer onaylanan fırsatın URL'i **Hepsiburada kısa linki** (`hb.biz` veya `app.hb.biz`) ise admin paneli onaylamadan önce Firebase Cloud Functions üzerindeki `resolveShortLink` endpoint'ine bir HTTP isteği gönderir.
*   Bu fonksiyon kısa linkin yönlendiği **gerçek ve uzun ürün linkini** bulur ve admin paneline geri döner. Böylece link veritabanına orijinal haliyle kaydedilir.

### 2️⃣ Otomatik Affiliate Link Dönüştürme (Affiliate Link Conversion)
Çözümlenen uzun link, `web/admin/config.js` dosyasında yer alan affiliate yapılandırmalarına göre otomatik olarak dönüştürülür:

*   **Trendyol:** Linkteki `boutiqueId` parametresini siler, `config.js` içindeki boutiqueId değerini ekler.
*   **Hepsiburada:** Linkteki eski affiliate parametrelerini (`utm_source`, `utm_medium` vb.) siler. Kendi `utm_source=...` ve `utm_medium=referral` parametrelerimizi ekler.
*   **N11:** `ref` parametresini siler ve kendi `ref` ID'mizi ekler.
*   **Amazon (amazon.com.tr / amazon.com):** `tag` parametresini silip kendi associate tag'imizi yerleştirir.
*   **GittiGidiyor:** `affiliateId` parametresini günceller.
