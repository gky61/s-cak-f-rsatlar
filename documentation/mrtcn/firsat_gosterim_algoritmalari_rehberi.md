# 🚀 FırsatKolik — Fırsat Gösterim Algoritmaları ve Menü Mimarisi Rehberi

Bu doküman, FırsatKolik mobil uygulamasında yer alan **4 ana menünün (Anasayfa, Kaydedilenlerim, Favori Kategorilerim, Popüler Fırsatlar)** çalışma prensiplerini, arka planda çalışan algoritmalarını, zaman pencerelerini ve kullanıcı deneyimi (UX) esaslarını detaylı bir şekilde açıklamaktadır.

---

## 📌 Genel İlkeler ve Zaman Pencereleri Özeti

FırsatKolik anlık indirim ve kampanya odaklı bir uygulama olduğu için, içeriklerin **tazeliği (freshness)** ve **güncelliği** en kritik parametredir. Stokları hızlı tükenen kampanyalarda kullanıcının güncel kalması amaçlanmıştır.

| Menü Başlığı | Zaman Penceresi | Sıralama Ölçütü | Kullanım Amacı |
|---|---|---|---|
| 🏠 **1. Anasayfa** | Son **48 Saat** | En yeni eklenen en üstte (`createdAt ↓`) | Uygulamadaki tüm taze ve güncel fırsatları akış halinde keşfetmek |
| 📑 **2. Kaydedilenlerim** | **Sınırsız / 30 Gün** | Favoriye eklenme tarihi (`addedAt ↓`) | Kullanıcının daha sonra bakmak üzere kaydettiği kişisel kütüphanesi |
| 🏷️ **3. Favori Kategorilerim** | Son **48 Saat** | En yeni eklenen en üstte (`createdAt ↓`) | Sadece kullanıcının takip ettiği kategori ve alt kategorilerdeki taze fırsatlar |
| 🔥 **4. Popüler Fırsatlar** | Son **48 Saat** | **`popularityScore` ↓** (Wilson + Time Decay + Engagement) | Topluluk tarafından alevlendirilen ve en çok ilgi gören trend indirimler |

---

## 🏠 1. Anasayfa (Home Screen)

### 🎯 Amacı
Kullanıcının uygulamayı açtığında karşılaştığı ana vitrindir. Uygulamaya eklenen onaylı ve taze tüm fırsatlar kronolojik olarak burada listelenir.

### ⚙️ Çalışma Mantığı ve Algoritması
1. **Zaman Sınırı (48 Saat):** Veritabanından yalnızca son 48 saat içerisinde yayınlanmış fırsatlar (`createdAt >= 48h ago`) çekilir. 48 saati doldurmuş indirimler anasayfa akışından otomatik olarak filtrelenir.
2. **Onay ve Durum Filtreleri:** 
   - `isApproved == true` (Yönetim tarafından onaylanmış veya güvenilir kaynaklı olmalı)
   - `isExpired == false` (Fırsatı bitmiş olarak işaretlenmemiş olmalı)
   - `isTest != true` (Test otomasyon verileri filtrelenir)
3. **Sıralama Mantığı:** Tamamen **tazelik odaklıdır (Freshness First)**. En son eklenen fırsat her zaman listenin en başında yer alır.
4. **Pagination (Sayfalama):** İlk açılışta 20 fırsat yüklenir. Kullanıcı aşağı kaydırdıkça ("Infinite Scroll") dinamik olarak 20'şerli gruplar halinde yükleme devam eder.
5. **Dinamik Reklam Yerleşimi:** Kullanıcı deneyimini bozmayacak şekilde 5-6-5-6 kart aralıklarıyla doğal reklam kartları (Ad Cards) akışa entegre edilir.

---

## 📑 2. Kaydedilenlerim (Saved Deals / Favorites Tab 1)

### 🎯 Amacı
Kullanıcıların beğendikleri veya daha sonra satın almak/incelemek üzere yer işaretlerine ("Bookmark") ekledikleri kişisel fırsat arşivdir.

### ⚙️ Çalışma Mantığı ve Algoritması
1. **Kişisel Veri Saklama:** Kullanıcı bir fırsatı kaydettiğinde `users/{userId}/favorites/{dealId}` altına kayıt oluşturulur.
2. **Süreksiz Erişim (Süresi Doldu Etiketi):** Fırsat 48 saati doldurduğunda veya fırsatın süresi bittiğinde, bu menüden **silinmez**. Bunun yerine kartın üzerinde belirgin bir **"Süresi Doldu"** rozeti görüntülenir.
3. **Çift Katmanlı Koruma (Fallback Mechanism):**
   - **Fırsat Veritabanında Duruyorsa:** Oluşturulma tarihi veya favori eklenme tarihi 48 saati geçtiyse nesne `isExpired = true` olarak işaretlenip gösterilir.
   - **Fırsat Veritabanından Silinmişse:** Kullanıcının favoriler dokümanında saklanan yedek bilgiler (başlık, fiyat, mağaza adı) okunur ve yine "Süresi Doldu" etiketiyle listelenir.
4. **Performans Mimarisi (Parallel Fetching):** Kaydedilen tüm fırsatlar `Future.wait` ile eşzamanlı (paralel) çekilir. Böylece 20 favori fırsat 100ms gibi çok kısa bir sürede ekrana gelir.
5. **Kullanıcı Kontrolü:** Ekranın üst kısmında yer alan **"Süresi Dolanları Temizle"** butonu sayesinde kullanıcı istediği zaman süresi bitmiş kayıtları tek tıkla topluca kaldırabilir.

---

## 🏷️ 3. Favori Kategorilerim (Followed Categories / Favorites Tab 2)

### 🎯 Amacı
Kullanıcının sadece ilgi duyduğu alışveriş kategorilerini (örn: Elektronik, Moda, Ev & Yaşam, Bilgisayar) takip ederek, bu kategorilere özel kişiselleştirilmiş bir akış oluşturmasını sağlar.

### ⚙️ Çalışma Mantığı ve Algoritması
1. **Abonelik Dinleme:** Kullanıcının takip ettiği ana kategoriler (`elektronik`) ve alt kategoriler (`elektronik:bilgisayar`) `notificationSubscriptions` koleksiyonundan canlı olarak dinlenir.
2. **Kategori ve Alt Kategori Eşleşmesi:**
   - Eşleşmeler **case-insensitive (`toLowerCase()`)** olarak yapılır.
   - Kullanıcı ana kategoriyi takip ediyorsa o kategorideki tüm ürünler görünür.
   - Kullanıcı sadece spesifik bir alt kategoriyi takip ediyorsa (`Laptop`), yalnızca o alt kategorideki ürünler süzülür.
3. **Zaman Sınırı (48 Saat):** Anasayfa ile %100 tutarlı olarak sadece son **48 saatlik** taze fırsatlar gösterilir.
4. **Sıralama:** En yeni eklenen fırsatlar en üstte listelenir.

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
2. **Popülerlik Skoru Akıllı Formülü (`popularityScore`):**
   Fırsatlar basit oy sayısına göre değil, aşağıdaki 3 bileşenden oluşan matematiksel formüle göre sıralanır:
   $$\text{popularityScore} = (\text{wilsonScore} + \text{engagementBonus}) \times \text{timeDecay}$$
   
   - **Wilson Score (Kalite):** Oy hacmi ve oy oranını dengeler (10/12 oy alan bir fırsat, 2/2 oy alandan daha yüksek puan alır).
   - **Zaman Çürümesi (Time Decay - 24 Saat Yarı Ömür):** 
     $$\text{timeDecay} = \frac{1}{1 + \frac{\text{ageInHours}}{24}}$$
     Bir fırsat 24 saati geride bıraktığında zamansal puan çarpanı yarıya düşer. Böylece yeni alevlenen taze fırsatlar öne geçer.
   - **Engagement Bonusu (Etkileşim):** 
     $$\text{engagementBonus} = \log_2(1 + \text{commentCount}) \times 0.05$$
     Kullanıcıların yorum yazıp tartıştığı fırsatlar ekstra popülerlik puanı kazanır.

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
