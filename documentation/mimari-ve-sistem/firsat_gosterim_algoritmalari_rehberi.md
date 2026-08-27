# 🚀 FırsatKolik — Fırsat Gösterim Algoritmaları ve Menü Mimarisi Rehberi

> [!NOTE]
> Bu doküman 4 ana menünün detaylı gösterim formülleri ve Wilson algoritması kılavuzudur. Sistemin uçtan uca mimarisi, gamification, mesajlaşma, moderasyon ve Web Admin entegrasyonu için lütfen **[Sistem Mimarisi, Yaşam Döngüsü ve Sosyal Etkileşim Master Rehberi](file:///d:/firsatkolik/documentation/mimari-ve-sistem/mimari_ve_sistem_rehberi.md)** dokümanını inceleyiniz.

Bu doküman, FırsatKolik mobil uygulamasında yer alan **4 ana menünün (Anasayfa, Kaydedilenlerim, Favori Kategorilerim, Popüler Fırsatlar)** çalışma prensiplerini, arka planda çalışan algoritmalarını, süresi dolan/stoğu biten fırsatların gösterim esaslarını, zaman pencerelerini ve kullanıcı deneyimi (UX) esaslarını detaylı bir şekilde açıklamaktadır.

---

## 📌 Genel İlkeler ve Zaman Pencereleri Özeti

FırsatKolik anlık indirim ve kampanya odaklı bir uygulama olduğu için, içeriklerin **tazeliği (freshness)** ve **güncelliği** en kritik parametredir. Stokları hızlı tükenen kampanyalarda kullanıcının güncel kalması amaçlanmıştır.

| Menü Başlığı | Zaman Penceresi | Sıralama Ölçütü | Biten Fırsat Gösterimi (`isExpired`) | Kullanım Amacı |
|---|---|---|---|---|
| 🏠 **1. Anasayfa** | Son **48 Saat** | **`homeFeedScore` ↓** (Tazelik + Trending - TrollCeza - FOMO) | **Gösterilir** (`-25.0` FOMO Kırılması + `Opacity: 0.8` + "KAÇTI" Rozeti) | %85 Kronoloji + FOMO odaklı canlı haber akışında taze indirimleri keşfetmek |
| 📑 **2. Kaydedilenlerim** | **Sınırsız / 30 Gün** | Favoriye eklenme tarihi (`savedAt ↓`) | **Gösterilir** (Silinmez, `savedAt` sırasını korur + `Opacity: 0.8` + "KAÇTI" Rozeti) | "Benim Özel Dijital Depom" — Kaydedilen taze/süresi dolan tüm fırsatların kronolojik arşiv kütüphanesi |
| 🏷️ **3. Favori Kategorilerim** | Son **48 Saat** | **`homeFeedScore` ↓** (Tazelik + Trending - TrollCeza - FOMO) | **Gösterilir** (`-25.0` FOMO Kırılması + `Opacity: 0.8` + "KAÇTI" Rozeti) | "Kişiselleştirilmiş Özel Fırsat Akışım" — Sadece takip edilen kategorilere filtrelenmiş Ana Sayfa akışı |
| 🔥 **4. Popüler Fırsatlar** | Son **48 Saat** | **`popularityScore` ↓** (Wilson + Time Decay + Engagement) | **GÖSTERİLMEZ (%100 Elenir)** | Topluluk tarafından alevlendirilen ve en çok ilgi gören trend indirimler |

---

## ⌛ 0. Süresi Biten / Stok Biten Fırsatların Görsel ve Algoritmik Standardı

FırsatKolik uygulamasında bir fırsatın süresi dolduğunda veya stoğu tükendiğinde (`isExpired == true` veya `expiredVotes >= dynamicLimit`) izlenen temel tasarım ve tespit esasları şunlardır:

### 1. Görsel Sunum Esasları (Visual Standards)
* **Orijinal Ürün Görseli Korunur:** Fırsat bittiğinde ürünün orijinal görseli (`CachedNetworkImage`) **kesinlikle silinmez veya varsayılan mağaza logosu ile değiştirilmez**. Mağaza logosu yalnızca ürün görsel URL'si veritabanında gerçekten yoksa veya boşsa fallback olarak kullanılır.
* **Karartma ve Matlık (`Opacity: 0.8`):** Kartın tamamı (görsel dahil) hafifçe karartılarak (`opacity: 0.8` / `0.75`) pasif durumu hissettirilir.
* **Kırmızı Gradyanlı Rozet ("⌛ KAÇTI"):** Kartın ve ürün görselinin sağ üst köşesine kırmızı gradyanlı, dikkat çekici **"⌛ KAÇTI"** / **"SÜRESİ DOLDU"** rozeti yerleştirilir.
* **Aksiyon Butonu Değişimi:** Buton metni `"İncele ↗"` yerine **`"Şansını Dene ↗"`** ifadesine dönüşür (Stokların yenilenmiş olma ihtimaline karşı).

### 2. Bitiş Tespit Mekanizmaları
* **Topluluk Oylaması (`expiredVotes`):** Kullanıcıların detay sayfasındaki "Bitti/Stok Yok" oyları dinamik eşiği ($\operatorname{clamp}(5 + \lfloor\text{hotVotes}/5\rfloor, 5, 20)$) aştığında sistem otomatik olarak `isExpired = true` işaretler.
* **Yönetici Müdahalesi / Scraper Botlar:** Admin panelinden "Fırsatı Kaldır" yapıldığında veya botlar mağaza sayfasında `Stok Yok` / `404` algıladığında `isExpired = true` güncellenir.
* **48 Saatlik Zamansal Sınır:** 48 saati dolduran tüm fırsatlar kronolojik olarak bitti kabul edilerek ana akışlardan kademeli olarak kaldırılır.

---

## 🏠 1. Anasayfa (Home Screen - Timeline / Newsfeed)

### 🎯 Amacı
Kullanıcının uygulamayı açtığında karşılaştığı canlı haber akışıdır ("Timeline"). %85 oranında **Tazelik (Kronoloji)** ve **Kullanıcıda FOMO (Kaçırma Korkusu)** yaratma odaklı dinamik bir algoritma ile çalışır.

### ⚙️ Çalışma Mantığı ve Algoritması
1. **Zaman Sınırı (48 Saat):** Yalnızca son 48 saat içerisinde yayınlanmış fırsatlar (`createdAt >= 48h ago`) akışa dahil edilir.
2. **Akış Skorlama Formülü (`homeFeedScore`):**
   $$\text{homeFeedScore} = \text{FreshnessScore} + \text{TrendingBonus} - \text{SoftTrollPenalty} - \text{ExpiredFOMODemotion}$$
   - **Tazelik Taban Puanı ($\text{FreshnessScore}$):** Yeni eklenen ürünler en yüksek taban puanı alır.
   - **İlk 45 Dakika Dokunulmazlık (Immunity Period):** İlk 45 dakika boyunca olumsuz oylar ürünü düşüremez.
   - **Alevlenme Bonusu ($\text{TrendingBonus}$):** 1 saat içinde hızlı oy alan fırsatlar kendinden önceki oylanmamış 1-2 ürünün üzerine tırmanır.
   - **Yumuşak Pas Cezası ($\text{SoftTrollPenalty}$):** 45 dakikadan sonra olumsuz oyları %65'i geçen fırsatların puanı hafifçe düşürülerek akışta %20-30 geriye kaydırılır.
   - **FOMO Bitiş Düzeltmesi ($\text{ExpiredFOMODemotion}$):** Süresi batan/tükenen taze fırsatlar **akıştan anında silinmez**. `-25.0` puan kırılması ile en üstteki 3-5 aktif taze ürünün hemen altına düşer. Orijinal ürün görseli korunarak `Opacity: 0.8` ve kırmızı **"⌛ KAÇTI"** rozeti ile sergilenir. Böylece kullanıcıda *"İndirimi kaçırdım, uygulamaya daha sık girmeliyim"* hissi (FOMO) uyandırılır. 48 saati doldurduğunda ise akıştan tamamen kalkar.
3. **Pagination & Reklam:** 20'şerli sonsuz kaydırma ("Infinite Scroll") ve 5-6 kart aralıklarıyla doğal reklam kartları.

---

## 📑 2. Kaydedilenlerim (Saved Deals / Favorites Tab 1)

### 🎯 Kullanıcı Hissiyatı & Amacı
Kullanıcı bu sayfaya girdiğinde **"Benim Özel Dijital Depom"** hissini yaşamalıdır (*"Buraya attığım hiçbir fırsat kaybolmaz, kontrol tamamen bende ve hepsi elimin altında."*).

### ⚙️ Algoritma ve Gösterim Stratejisi
1. **Saf Kronoloji (Son Kaydedilen En Üstte - `savedAt DESC`):**
   - Buradaki ana sıralama metriği ürünün paylaşılma tarihi değil, **kullanıcının o fırsatı favoriye eklediği tarihtir (`savedAt` DESC)**.
   - Kullanıcı 2 dakika önce 3 günlük bir fırsatı kaydettiyse, o fırsat en üstte görünür.
2. **Canlı Durum Güncellemesi (Stok/Fiyat Değişimi & Bitiş Yönetimi):**
   - Kullanıcının kaydettiği bir fırsatın stoğu tükenirse veya indirim biterse (`isExpired == true`), bu fırsat **LİSTEDEN ASLA SİLİNMEZ VEYA EN ALTA ATILMAZ.**
   - Kaydedildiği kronolojik sıradaki (`savedAt`) yerini milisaniyesi milisaniyesine korur.
   - Orijinal ürün görseli korunarak kart üzerinde `opacity: 0.8` matlaşma ve belirgin bir **"⌛ KAÇTI"** rozeti görüntülenir.
3. **Performans Mimarisi (Parallel Fetching):** Kaydedilen tüm fırsatlar `Future.wait` ile eşzamanlı (paralel) çekilir. Böylece favori fırsatlar milisaniyeler içinde ekrana gelir.
4. **Kullanıcı Kontrolü:** Ekranın üst kısmında yer alan **"Süresi Dolanları Temizle"** butonu sayesinde kullanıcı istediği zaman süresi bitmiş kayıtları tek tıkla topluca temizleyebilir.

---

## 🏷️ 3. Favori Kategorilerim (Followed Categories / Favorites Tab 2)

### 🎯 Kullanıcı Hissiyatı & Amacı
Kullanıcı bu sayfaya girdiğinde **"Kişiselleştirilmiş Özel Fırsat Akışım"** hissini yaşamalıdır (*"Tüm uygulamanın gürültüsünden uzaklaştım, sadece ilgilendiğim ürün gruplarını (Örn: Teknoloji, Moda) görüyorum."*).

### ⚙️ Algoritma ve Gösterim Stratejisi
1. **Ana Sayfa Algoritmasının Kategori Filtreli Versiyonu:**
   - Burada Ana Sayfa’daki skorlama ve sıralama algoritmasının (`homeFeedScore`) **sadece kullanıcının seçtiği/takip ettiği kategorilere filtrelenmiş hali** çalışır.
   - $$\text{homeFeedScore} = \text{FreshnessScore} + \text{TrendingBonus} - \text{SoftTrollPenalty} - \text{ExpiredFOMODemotion}$$
2. **Abonelik Dinleme & Filtreleme:**
   - Kullanıcının takip ettiği ana kategoriler (`elektronik`) ve alt kategoriler (`elektronik:bilgisayar`) `notificationSubscriptions` koleksiyonundan canlı dinlenir ve eşleşen fırsatlar çekilir.
3. **Birebir Ana Sayfa Deneyimi & Biten Fırsat Yönetimi:**
   - Eşleşen kategorilerdeki taze ürünler %85 tazelik + kuluçka dönemi dokunulmazlığı + alevlenme desteği ile üst sıralara yerleşir.
   - Süresi biten fırsatlar `-25.0` FOMO puan kırma kuralı ile takip edilen aktif taze fırsatların hemen altında, orijinal ürün resmi korunarak `Opacity: 0.8` ve kırmızı **"⌛ KAÇTI"** rozetiyle gösterilir.

---

## 🔥 4. Popüler Fırsatlar (Popular Deals)

### 🎯 Amacı
Topluluk tarafından yüksek oranda alevlendirilen ("AL! / Sıcak Oy"), yorumlarla etkileşimi artan ve fırsat değeri en yüksek olan trend indirimlerin sergilendiği vitrindir.

### ⚙️ Çalışma Mantığı ve Algoritması
1. **Sert Eşik ve Filtre Şartları (Biten Fırsatlar Kesin Elenir):**
   - `hotVotes >= 3` (En az 3 sıcak oy almış olmalı)
   - `netScore > 0` (Net oy sayısı pozitif olmalı, soğuk oylarla ekside kalan sorunlu ürünler elenir)
   - **`isExpired == false` & `expiredVotes < 15` (Süresi bitmiş veya stoğu tükenmiş ürünler Popüler vitrininden %100 ELENİR, anında kaldırılır)**
   - `createdAt >= 48h ago` (Son 48 saat içerisinde paylaşılmış olmalı)
2. **Geliştirilmiş Popülerlik Skoru Akıllı Formülü (`popularityScore`):**
   Anlık fırsat dinamiklerine uygun olarak 4 bileşenden oluşur:
   $$\text{popularityScore} = (\text{effectiveScore} + \text{engagementBonus} + \text{freshnessBoost}) \times 2^{-\left(\frac{\text{ageInHours}}{12.0}\right)}$$
   
   - **Kalite Skoru (`effectiveScore`):** Wilson Score (%60) + Ham Sıcak Oy Oranı (%40) harmanı ile küçük oy sayısındaki taze fırsatların istatistiksel baskılanması engellenir.
   - **Agresif Üstel Zaman Çürümesi (Time Decay - 12 Saat Yarı Ömür):** 
     $$\text{timeDecay} = 0.5^{\left(\frac{\text{ageInHours}}{12.0}\right)}$$
     Bir fırsat 24 saatini doldurduğunda zamansal çarpanı 0.25'e (çeyreğe) düşer. Dünün yüksek oylu fırsatları hızla alt sıralara iner.
   - **Tazelik Bonusu (`freshnessBoost`):** 
     - **0 - 6 Saat**: `+0.40` ekstra puan (Bugün alevlenen yeni fırsatlar derhal zirveye fırlar).
     - **6 - 12 Saat**: `+0.20` ekstra puan.
   - **Engagement Bonusu (Etkileşim):** 
     $$\text{engagementBonus} = \log_2(1 + \text{commentCount}) \times 0.05$$
     Kullanıcıların yorum yazıp tartıştığı sıcak konular ek görünürlük kazanır.

---

## 🧹 5. Veri Temizlik ve Otomatik Retansiyon Politikası

Veritabanı şişkinliğini önlemek, sunucu maliyetlerini optimize etmek ve kullanıcı favorilerinde kalıcı çöp veri birikmesini engellemek için **3 kademeli retansiyon** uygulanır:

```
[Yeni Fırsat Paylaşıldı]
       │
       ├─► 0 - 48 Saat ────► Anasayfa, Favori Kategorilerim ve Popüler'de Canlı
       │
       ├─► 48 Saat Sonrası ────► cleanupExpiredDeals (Her gün 03:00)
       │                         • Fırsat veritabanından SİLİNMEZ!
       │                         • Sadece `isExpired: true` olarak etiketlenir (Soft-Expire).
       │                         • Anasayfa ve Popüler akışlarından düşer.
       │                         • Favorilerde orijinal görseli, fiyatı ve "⌛ KAÇTI" rozetiyle 30 gün kalır.
       │
       └─► 30 Gün Sonrası ─────► purgeOldDeals (Her Pazar 04:00 veya Web Admin "30+ Günlük Temizlik")
                                 • Fırsat dokümanı, oylar, yorumlar, Storage görselleri ve 
                                   tüm kullanıcı favorileri KALICI OLARAK SİLİNİR (Hard-Purge) 🗑️
```

### Kalıcı Silme (Purge) Kapsamı (`purgeOldDeals` & `purgeOldDealsWeb`):
1. `deals/{dealId}` (Ana Fırsat Dokümanı)
2. `deals/{dealId}/votes/*` (Tüm Oy Kayıtları)
3. `deals/{dealId}/comments/*` (Tüm Yorumlar)
4. `users/{userId}/favorites/{dealId}` (Tüm Kullanıcıların Favori Referansları)
5. Firebase Storage Görselleri (`cleanupOldImages` ile 30 gün korumalı)

### Favori Snapshot Garantisi (`UserService.addToFavorites`):
Kullanıcı bir fırsatı kaydettiği anda ürünün `title`, `price`, `store`, `link` ve `imageUrl` alanları favoriler alt dokümanına snapshot olarak yazılır. Böylece olası ağ gecikmelerinde veya 30 gün içinde ana dokümanda güncelleme olsa dahi kullanıcının favorilerinde ürünün gerçek görseli ve bilgileri asla kaybolmaz.

---

## 💡 Özet

Bu mimari sayesinde FırsatKolik;
- **Anasayfasında** taze indirimleri sunarken, süresi bitenleri `-25.0` FOMO puanı, orijinal görselleri ve **"⌛ KAÇTI"** rozetiyle sergileyip kullanıcıda dinamik haber akışı algısı yaratır,
- **Kaydedilenlerim** menüsünde kullanıcının kişisel arşivini korur, süresi bitse dahi ürün görseli ve `savedAt` kronolojik sırasını bozmaz,
- **Favori Kategorilerim** sekmesinde ilgi alanına özel anlık akış sağlar,
- **Popüler Fırsatlar** ekranında ise süresi bitenleri %100 eleyerek sadece canlı ve topluluğun alevlendirdiği trendleri sergiler.
