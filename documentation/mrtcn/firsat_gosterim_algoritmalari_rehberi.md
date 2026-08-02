# 🚀 FırsatKolik — Fırsat Gösterim Algoritmaları ve Menü Mimarisi Rehberi

Bu doküman, FırsatKolik mobil uygulamasında yer alan **4 ana menünün (Anasayfa, Kaydedilenlerim, Favori Kategorilerim, Popüler Fırsatlar)** çalışma prensiplerini, arka planda çalışan algoritmalarını, zaman pencerelerini ve kullanıcı deneyimi (UX) esaslarını detaylı bir şekilde açıklamaktadır.

---

## 📌 Genel İlkeler ve Zaman Pencereleri Özeti

FırsatKolik anlık indirim ve kampanya odaklı bir uygulama olduğu için, içeriklerin **tazeliği (freshness)** ve **güncelliği** en kritik parametredir. Stokları hızlı tükenen kampanyalarda kullanıcının güncel kalması amaçlanmıştır.

| Menü Başlığı | Zaman Penceresi | Sıralama Ölçütü | Kullanım Amacı |
|---|---|---|---|
| 🏠 **1. Anasayfa** | Son **48 Saat** | **`homeFeedScore` ↓** (Tazelik + Trending - TrollCeza - FOMO) | %85 Kronoloji + FOMO odaklı canlı haber akışında taze indirimleri keşfetmek |
| 📑 **2. Kaydedilenlerim** | **Sınırsız / 30 Gün** | Favoriye eklenme tarihi (`savedAt ↓`) | "Benim Özel Dijital Depom" — Kaydedilen taze/süresi dolan tüm fırsatların kronolojik arşiv kütüphanesi |
| 🏷️ **3. Favori Kategorilerim** | Son **48 Saat** | **`homeFeedScore` ↓** (Tazelik + Trending - TrollCeza - FOMO) | "Kişiselleştirilmiş Özel Fırsat Akışım" — Sadece takip edilen kategorilere filtrelenmiş Ana Sayfa akışı |
| 🔥 **4. Popüler Fırsatlar** | Son **48 Saat** | **`popularityScore` ↓** (Wilson + Time Decay + Engagement) | Topluluk tarafından alevlendirilen ve en çok ilgi gören trend indirimler |

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
   - **FOMO Bitiş Düzeltmesi ($\text{ExpiredFOMODemotion}$):** Süresi batan/tükenen fırsatlar **gizlenmez**. `-25.0` küçük puan kırılması ile en üstteki 3-5 aktif taze ürünün hemen altına düşer. Kırmızı **"⌛ FIRSAT KAÇTI"** rozeti ile sergilenerek kullanıcıda tatlı bir FOMO hissi uyandırır.
3. **Pagination & Reklam:** 20'şerli sonsuz kaydırma ("Infinite Scroll") ve 5-6 kart aralıklarıyla doğal reklam kartları.

---

## 📑 2. Kaydedilenlerim (Saved Deals / Favorites Tab 1)

### 🎯 Kullanıcı Hissiyatı & Amacı
Kullanıcı bu sayfaya girdiğinde **"Benim Özel Dijital Depom"** hissini yaşamalıdır (*"Buraya attığım hiçbir fırsat kaybolmaz, kontrol tamamen bende ve hepsi elimin altında."*).

### ⚙️ Algoritma ve Gösterim Stratejisi
1. **Saf Kronoloji (Son Kaydedilen En Üstte - `savedAt DESC`):**
   - Buradaki ana sıralama metriği ürünün paylaşılma tarihi değil, **kullanıcının o fırsatı favoriye eklediği tarihtir (`savedAt` / `addedAt` DESC)**.
   - Kullanıcı 2 dakika önce 3 günlük bir fırsatı kaydettiyse, o fırsat en üstte görünür.
2. **Canlı Durum Güncellemesi (Stok/Fiyat Değişimi):**
   - Kullanıcının kaydettiği bir fırsatın stoğu tükenirse veya indirim biterse (`isExpired == true`), bu fırsat listeden silinmez veya en alta atılmaz.
   - Kronolojik sıralamadaki yerini tam olarak korur.
   - Kartın üzerinde belirgin bir **"⌛ Süresi Doldu"** / **"🔥 FIRSAT KAÇTI"** rozeti görüntülenir ve kart hafifçe grileşir (`opacity: 0.8`).
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
3. **Birebir Ana Sayfa Deneyimi:**
   - Eşleşen kategorilerdeki taze ürünler %85 tazelik + kuluçka dönemi dokunulmazlığı + alevlenme desteği ile üst sıralara yerleşir.
   - Süresi biten fırsatlar `-25.0` FOMO puan kırma kuralı ile aktif taze fırsatların hemen altında yer alır.

---

## 🔥 4. Popüler Fırsatlar (Popular Deals)

### 🎯 Amacı
Topluluk tarafından yüksek oranda alevlendirilen ("AL! / Sıcak Oy"), yorumlarla etkileşimi artan ve fırsat değeri en yüksek olan trend indirimlerin sergilendiği vitrindir.

### ⚙️ Çalışma Mantığı ve Algoritması
1. **Eşik ve Filtre Şartları:**
   - `hotVotes >= 3` (En az 3 sıcak oy almış olmalı)
   - `netScore > 0` (Net oy sayısı pozitif olmalı, soğuk oylarla ekside kalan sorunlu ürünler elenir)
   - `isExpired == false` (Süresi bitmiş ürünler gösterilmez)
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
       ├─► 0 - 48 Saat ───► Anasayfa, Favori Kategorilerim ve Popüler'de Canlı
       │
       ├─► 48 Saat Sonrası ─► Anasayfadan kalkar. Favorilerde "Süresi Doldu" rozeti alır.
       │
       └─► 30 Gün Sonrası ──► Purge Job (Haftalık Otomatik Cloud Function veya Web Admin)
                              └─► Fırsat dokümanı, oylar, yorumlar, görseller ve 
                                  tüm kullanıcı favorileri KALICI OLARAK SİLİNİR 🗑️
```

### Kalıcı Silme (Purge) Kapsamı:
1. `deals/{dealId}` (Ana Fırsat Dokümanı)
2. `deals/{dealId}/votes/*` (Tüm Oy Kayıtları)
3. `deals/{dealId}/comments/*` (Tüm Yorumlar)
4. `users/{userId}/favorites/{dealId}` (Tüm Kullanıcıların Favori Referansları)
5. Firebase Storage Görselleri

---

## 💡 Özet

Bu mimari sayesinde FırsatKolik;
- **Anasayfasında** her zaman taze ve anlık indirimleri sunar,
- **Favorilerim** menüsünde kullanıcının kişisel arşivini korur,
- **Favori Kategorilerim** sekmesinde ilgi alanına özel anlık akış sağlar,
- **Popüler Fırsatlar** ekranında ise topluluğun alevlendirdiği en kaliteli trendleri matematiksel bir skorlama algoritması ile öne çıkarır.
