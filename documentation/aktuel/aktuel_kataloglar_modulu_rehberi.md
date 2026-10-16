# 📰 Aktüel Kataloglar ve Broşürler Modülü — Kapsamlı Mimari, Veri ve Sistem Kontratı Rehberi

> [!IMPORTANT]
> **Base Doküman & Aktüel Kontratı:** Bu doküman, FırsatKolik platformunun süpermarket, kozmetik, ev-yaşam ve teknoloji mağazalarına ait dönemsel indirim kataloglarının (aktüel afiş ve broşürlerinin) kazınması, işlenmesi, Firestore üzerinde saklanması, mobil istemcide 3 seviyeli doğrusal kullanıcı deneyimiyle (Linear UX) sunulması, sosyal paylaşımı ve Web Admin paneli üzerinden yönetilmesine dair tüm uçtan uca mimariyi yöneten **ana orkestratör (Base Contract)** dokümandır. Her bir alt mimarinin ayrıntılı teknik referansları ilgili bölümlerde doğrudan bağlantılanmıştır.

Bu doküman; **FırsatKolik** platformunda süpermarket, kozmetik, ev-yaşam ve teknoloji mağazalarına ait dönemsel indirim kataloglarının (aktüel afiş ve broşürlerinin) taranması, işlenmesi, Firestore üzerinde saklanması, mobil istemcide 3 seviyeli doğrusal kullanıcı deneyimiyle (Linear UX) sunulması, sosyal paylaşımı ve Web Admin paneli üzerinden yönetilmesine dair tüm uçtan uca mimariyi, veri modellerini, güvenlik kurallarını ve teknik operasyonel iş kurallarını tanımlayan **resmi mimari sözleşmedir (Documentation Contract)**.

---

## 📑 İçindekiler
1. [🌟 Modüle Genel Bakış ve Mimari Tasarım İlkeleri](#1--modüle-genel-bakış-ve-mimari-tasarım-ilkeleri)
2. [📱 Mobil İstemci ve 3 Seviyeli Doğrusal Kullanıcı Deneyimi (Linear UX)](#2--mobil-istemci-ve-3-seviyeli-doğrusal-kullanıcı-deneyimi-linear-ux)
3. [🏪 Desteklenen 36 Mağaza ve Taksonomi Matrisi](#3--desteklenen-36-mağaza-ve-taksonomi-matrisi)
4. [🔥 Firestore Veri Modeli ve Şema Kontratı](#4--firestore-veri-modeli-ve-şema-kontratı)
5. [🛡️ Güvenlik Kuralları ve İzin Matrisi (Security Rules)](#5-️-güvenlik-kuralları-ve-izin-matrisi-security-rules)
6. [⚡ Firebase Cloud Functions ve Backend Mimarisi](#6-️-firebase-cloud-functions-ve-backend-mimarisi)
7. [🤖 Otonom Akakçe Kazıma Motoru ve WAF Bypass Hattı](#7--otonom-akakçe-kazıma-motoru-ve-waf-bypass-hattı)
8. [📤 Sosyal Paylaşım Motoru (KatalogShareService)](#8--sosyal-paylaşım-motoru-katalogshareservice)
9. [💻 Web Admin Paneli Entegrasyonu](#9--web-admin-paneli-entegrasyonu)
10. [🧪 Test, Doğrulama ve Operasyonel İzleme](#10--test-doğrulama-ve-operasyonel-izleme)
11. [📂 İlgili Kaynak Kod Dosyaları ve Referanslar](#11--ilgili-kaynak-kod-dosyaları-ve-referanslar)

---

## 1. 🌟 Modüle Genel Bakış ve Mimari Tasarım İlkeleri

Aktüel Kataloglar Modülü, kullanıcıların Türkiye'nin en popüler zincir market ve mağazalarının haftalık ve dönemsel indirim broşürlerini tek bir merkezden, yüksek çözünürlüklü ve akıcı bir arayüzle takip etmelerini sağlar.

```mermaid
graph TD
    %% 1. Veri Toplama Katmanı
    Akakce[🌐 Akakçe Broşür Kaynağı] -->|Çok Stratejili Fetch (A1/A2/B/C/D/E)| Scraper[🤖 Catalog Scraper Engine]
    
    %% 2. Backend & Bulut Katmanı
    Scraper -->|Zamanlanmış: 03:00 Cron / Manuel: Callable| CloudFunctions[⚡ Cloud Functions: Node.js 22]
    AdminWeb[💻 Web Admin Paneli] -->|scrapeCatalogsManual / deleteAllCatalogs| CloudFunctions
    CloudFunctions -->|400'lük Batch Yazma/Silme| Firestore[(🔥 Firestore: 'kataloglar' Koleksiyonu)]
    
    %% 3. Mobil İstemci Katmanı
    Firestore -->|SWR Cache-First + bitisTarihi Filtreli Sorgu| Level1[📱 Seviye 1: AktuelMagazalarPage]
    Level1 -->|Mağaza Seçimi| Level2[📄 Seviye 2: KatalogListesiPage]
    Level2 -->|Broşür Seçimi| Level3[🖼️ Seviye 3: KatalogDetayPage]
    Level3 -->|Görsel İndirme + XFile + Weserv Fallback| NativeShare[📤 KatalogShareService: Natif Paylaşım Menüsü]
```

### Temel Mimari Prensipler:
* **Sıfır İstisna ile 3 Seviyeli Doğrusal Akış:** Mağazada tek bir katalog olsa dahi akış her zaman `Mağaza Seçimi ➔ Katalog Listesi ➔ Katalog Detay` sırasını takip eder. Hiçbir mağaza için doğrudan detay sayfasına atlama yapılmaz.
* **20 Milyon Okuma Patlaması Kalkanı & SWR (FS-AKT-01 & P0-AKT-01):** 100k kullanıcıda tüm mağazaların kataloglarını tek tek çekmek (20M okuma fırtınası) yerine, gece kazıyıcısının ürettiği `settings/aktuel_meta` tekil özet dokümanı üzerinden **tek okumayla (100k okuma)** tüm mağaza sayaçları anında yüklenir. Cache-First (0ms) + arka planda Server Revalidation (SWR) ve her iki ekranda (`AktuelMagazalarPage` ve `KatalogListesiPage`) `RefreshIndicator` çek-bırak desteği aktiftir.
* **Dayanıklı Akakçe Görsel Kalkanı (ResilientCatalogImage - FS-AKT-02):** Akakçe CDN'in çıplak mobil istemci isteklerine 403 Forbidden dönmesini engellemek için tüm kapak ve detay resimleri özel User-Agent/Referer başlıkları ve otomatik `images.weserv.nl` proxy CDN fallback'i ile donatılmıştır.
* **Sıfır Precondition Hatası & Tekil İndeks Dayanıklılığı (Zero FAILED_PRECONDITION Kalkanı):** `KatalogListesiPage` doğrudan Firestore'un otomatik ve yerleşik tekil alan indeksi üzerinden `.where('magazaKodu', isEqualTo: cleanCode).limit(50)` sorgusu yapar. Mağaza başına zaten en fazla 2-5 adet katalog bulunduğu için, tarih filtrelemesi (`bitisTarihi >= today`) istemci tarafında <0.1ms sürede in-memory yapılarak buluttaki bileşik indeks dağıtım gecikmelerinden (`FAILED_PRECONDITION: The query requires an index`) kaynaklanan prod çökme riski sıfırlanmıştır. Geriye dönük uyumluluk ve karmaşık sorgu optimizasyonları için `firestore.indexes.json` içerisinde `[magazaKodu ASC, bitisTarihi ASC]` indeksleri de tanımlı tutulur.
* **Dinamik Mağaza Listeleme (Dynamic Visibility):** Sadece yayında **aktif en az 1 kataloğu bulunan** mağazalar ana listede gösterilir. Aktif kataloğu olmayan mağazalar arayüzde otomatik olarak gizlenir.
* **Akıllı Süre Yönetimi (Client-Side Expiry):** Süresi geçmiş kataloglar mobil istemci sorgularında ve listeleme anında elenir, kullanıcılara asla süresi dolmuş katalog sunulmaz.
* **Taşma Korumalı Katalog İnceleme (FS-AKT-03):** 12+ sayfadan uzun kataloglarda `RenderFlex overflow` çökmesini önlemek için nokta çubuğu gizlenir, kompakt hap sayaç korunur.
* **Yüksek Çözünürlük ve Hızlı Önyükleme (Progressive Image Scaling):** Listeleme ekranlarında optimize edilmiş küçük kapak resimleri (`/_bro/l/`), detay ekranında ise ultra yüksek kaliteli sayfalar (`/_bro/u/`) sunulur.
* **Kapsamlı Uzlaşma (Scoped Reconciliation):** Gece 03:00'te kazıma sırasında herhangi bir mağaza Cloudflare WAF/ağ zaman aşımına uğrarsa o mağazanın mevcut katalogları silinmez (`successfullyScrapedStores` takibi); yalnızca başarıyla taranan mağazalarda siteden kalkan kataloglar temizlenir.
* **Yetim Depolama Temizliği (onCatalogDeleted):** Bir katalog silindiğinde ilişkili `catalogs/${catalogId}_cover.webp` Cloud Storage kapak görseli tetikleyici ile otomatik olarak imha edilir.

---

## 2. 📱 Mobil İstemci ve 3 Seviyeli Doğrusal Kullanıcı Deneyimi (Linear UX)

> 🔗 **Detaylı Referans Dokümanı:**
> - [Aktüel Modülü Ürün ve UX Yol Haritası](file:///d:/firsatkolik/documentation/_arsiv/aktuel/aktuel-new-feature.md) — 3 seviyeli doğrusal UX vizyonu, ekran hiyerarşisi ve arayüz gereksinimleri.

Mobil uygulama tarafında modül, [AppTheme](file:///d:/firsatkolik/lib/theme/app_theme.dart) tasarım sistemine tam uyumlu 3 ana ekrandan ve bir paylaşım servisinden oluşur.

### 2.1. Seviye 1: Mağaza Seçim Ekranı ([AktuelMagazalarPage](file:///d:/firsatkolik/lib/screens/aktuel_magazalar_page.dart))
* **Giriş Noktası:** [HomeScreen](file:///d:/firsatkolik/lib/screens/home_screen.dart) üst çubuğunda (App Bar) Kuponlar butonunun hemen yanında yer alan `Aktüel` navigasyon çipi (`Icons.auto_stories_rounded`).
* **In-App Onboarding:** Uygulama ilk açılışında spotlight rehberinde (`InAppTutorialService.aktuelChipKey`) `#38BDF8` (Gök Mavisi) vurgusuyla tanıtılır.
* **Arayüz Elemanları:**
  1. **Hero Tanıtım Kartı:** Turuncu degrade ikonu (`Icons.auto_stories_rounded`), "YENİ" rozeti ve kapatma butonu (`_hideHeroBanner`).
  2. **Arama Çubuğu:** Mağaza adı veya mağaza kodu üzerinden anlık filtreleme.
  3. **Kategori Filtre Çipleri:** Yatay kaydırılabilir 5 ana kategori:
     - `tumu` (Tümü - `Icons.apps_rounded`)
     - `market` (Süpermarket - `Icons.shopping_cart_rounded`)
     - `kozmetik` (Kozmetik & Bakım - `Icons.face_retouching_natural_rounded`)
     - `giyimYasam` (Ev & Yaşam - `Icons.chair_rounded`)
     - `teknoloji` (Elektronik - `Icons.devices_rounded`)
  4. **Mağaza Grid'i:** 3'lü dizilimde (`crossAxisCount: 3`, `childAspectRatio: 0.86`) modern kartlar.
     - Her kartın üstünde markanın kurumsal renginde 3.5px yükseklikte renk çizgisi (Brand Accent).
     - Beyaz yuvarlatılmış iç arka planda optimize mağaza logosu ([StoreAssetHelper](file:///d:/firsatkolik/lib/utils/store_asset_helper.dart)).
     - Koyu/açık tema uyumlu mağaza ismi.
  5. **Skeleton Yükleme Ekranı:** Firestore'dan veri beklenirken 9'lu Shimmer iskelet animasyonu.
  6. **Boş Durum (Empty State):** Arama veya filtreleme sonucu eşleşme bulunamazsa sıfırlama butonlu temiz bilgilendirme ekranı.

### 2.2. Seviye 2: Mağaza Katalog Listesi Ekranı ([KatalogListesiPage](file:///d:/firsatkolik/lib/screens/katalog_listesi_page.dart))
* **Giriş:** Seviye 1'de bir mağaza kartına tıklandığında `magazaKodu` ve `magazaAdi` parametreleriyle açılır.
* **Arayüz Elemanları:**
  1. **Mağaza Hero Başlık Kartı:**
     - Mağaza logosu, kurumsal renk çerçevesi ve üst marka çizgisi.
     - Büyük mağaza ismi ve sağda `BİM`, `A101` gibi büyük harfli mağaza kodu rozeti.
     - "X Yayında" yeşil durum çipi ve "Resmi Broşürler" doğrulama rozeti.
  2. **Dinamik Sıralama Çipleri (`KatalogSortOption`):**
     - `defaultNewest` (En Yeni - `Icons.calendar_month_rounded`)
     - `expirySoonest` (Bitişi Yaklaşanlar - `Icons.hourglass_bottom_rounded`)
     - `expiryLatest` (En Uzun Süreli - `Icons.event_available_rounded`)
  3. **Katalog Grid'i:** 2'li dizilimde (`crossAxisCount: 2`, `childAspectRatio: 0.58`) dikey broşür kartları.
     - **Kapak Görseli:** `ResilientCatalogImage` ile dayanıklı önbelleklenen görsel (Akakçe Referer/UA başlıkları ve otomatik Weserv proxy fallback'li), sol üstte geçerlilik rozeti, sağ altta sayfa sayısı rozeti (`X Sayfa`).
     - **Geçerlilik Rozeti Renk Kodları:**
       - Mavi (`#2563EB`): Henüz başlamamış / Gelecek kampanya ("Yarın başlıyor", "X gün sonra başlayacak").
       - Yeşil (`#16A34A`): 4 günden fazla süresi olan aktif kampanya ("X gün sonra bitecek").
       - Sarı/Turuncu (`#D97706`): Son 2-3 günü kalmış kampanya ("3 gün sonra bitiyor").
       - Kırmızı (`#DC2626`): Son günü veya yarın bitecek kampanya ("Bugün bitiyor", "Yarın bitiyor").
       - Gri (`#71717A`): Süresi dolmuş kampanya ("Süresi Doldu").
     - **Kart Metin Alanı:** 2 satırlı katalog başlığı, Türkçe tarih aralığı (`d MMMM yyyy`) ve "Broşürü İncele" butonu.

### 2.3. Seviye 3: Katalog Detay ve Tam Ekran İnceleme ([KatalogDetayPage](file:///d:/firsatkolik/lib/screens/katalog_detay_page.dart))
* **Giriş:** Seviye 2'de bir broşür kartına tıklandığında `Katalog` nesnesi ile açılır.
* **Arayüz ve Etkileşim Yetenekleri:**
  1. **Yatay Sayfa Kaydırma (PageView.builder):** Instagram/e-dergi tarzında pürüzsüz sayfa geçişleri.
  2. **Çift Parmakla Yakınlaştırma (Pinch-to-Zoom):** `InteractiveViewer` bileşeni ile `1.0x` - `4.0x` arası kayıpsız büyütme.
  3. **Çoklu Dokunma Koruması (Multi-touch Lock):** Kullanıcı iki parmağıyla zoom yaparken PageView kaydırması kilitlenir (`NeverScrollableScrollPhysics`), böylece görseli incelerken yanlışlıkla yan sayfaya geçilmez.
  4. **Çift Tıklama ile Hızlı Büyütme (Double-Tap to Zoom):** Çift tıklandığında `2.5x` odaklı yumuşak animasyon (`Matrix4Tween`, `Curves.easeInOutCubic`).
  5. **Buzlu Cam Üst Bar (Frosted Glass Header):** `BackdropFilter` (16px blur), geri butonu, katalog başlığı, geçerlilik noktası/metni ve paylaşım butonu.
  6. **Buzlu Cam Alt Sayfa İndikatörü (Frosted Glass Footer):** `Sayfa X / Y` kapsülü ve aktif sayfayı gösteren animasyonlu nokta çubuğu (Dots Indicator - Sayfa sayısı 12'den fazla olan kataloglarda `RenderFlex overflow` çökmesini önlemek için nokta çubuğu otomatik gizlenir, kompakt hap sayaç korunur).

---

## 3. 🏪 Desteklenen 36 Mağaza ve Taksonomi Matrisi

Kazıma motorunda ve mobil istemcide tanımlı 36 zincir marka, kategori ve renk standartları:

| Mağaza Kodu (`magazaKodu`) | Mağaza Adı | Kategori | Kurumsal Renk | Kazıma Anahtar Kelimeleri | Hariç Tutulanlar |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `bim` | BİM | `market` | `#005691` | `bim` | - |
| `a101` | A-101 | `market` | `#14B4C8` | `a101`, `a-101` | - |
| `sok` | ŞOK | `market` | `#FFD200` | `sok`, `şok` | - |
| `migros` | Migros | `market` | `#EE7C11` | `migros` | - |
| `carrefoursa` | CarrefourSA | `market` | `#0F4C81` | `carrefour` | - |
| `metro` | Metro | `market` | `#002F6C` | `metro` | - |
| `macrocenter` | MacroCenter | `market` | `#1B1B1B` | `macro` | - |
| `getirbuyuk` | GetirBüyük | `market` | `#5D3EBC` | `getir` | - |
| `bizim` | Bizim Toptan | `market` | `#FFCC00` | `bizim` | - |
| `file` | File | `market` | `#3498DB` | `file` | - |
| `happycenter` | Happy Center | `market` | `#8DC63F` | `happy` | - |
| `hakmarexpress` | Hakmar Express | `market` | `#D32F2F` | `express` | - |
| `hakmar` | Hakmar | `market` | `#D32F2F` | `hakmar` | `express` |
| `cagri` | Çağrı Hipermarket | `market` | `#E31B23` | `cagri`, `çağrı` | - |
| `kooperatifmarket` | Kooperatif Market | `market` | `#00755F` | `kooperatif`, `tarim`, `tarım` | - |
| `mopas` | Mopaş | `market` | `#E31E24` | `mopas`, `mopaş` | - |
| `ozkuruslar` | Özkuruşlar | `market` | `#D32F2F` | `ozkuruslar`, `özkuruşlar`, `kuruslar`, `kuruşlar` | - |
| `tahtakale` | Tahtakale Spot | `market` | `#D32F2F` | `tahtakale`, `tahtakalespot` | - |
| `watsons` | Watsons | `kozmetik` | `#00A19B` | `watsons` | - |
| `gratis` | Gratis | `kozmetik` | `#8B1E87` | `gratis` | - |
| `rossmann` | Rossmann | `kozmetik` | `#E2001A` | `rossmann` | - |
| `bauhaus` | Bauhaus | `giyimYasam` | `#E30613` | `bauhaus` | - |
| `koctas` | Koçtaş | `giyimYasam` | `#EA5906` | `koctas`, `koçtaş` | - |
| `tekzen` | Tekzen | `giyimYasam` | `#008CD2` | `tekzen` | - |
| `tedi` | Tedi | `giyimYasam` | `#0088CC` | `tedi` | - |
| `cetinkaya` | Çetinkaya | `giyimYasam` | `#E31E24` | `cetinkaya`, `çetinkaya` | - |
| `civil` | Civil | `giyimYasam` | `#FF6600` | `civil` | - |
| `evkur` | Evkur | `giyimYasam` | `#003399` | `evkur` | - |
| `mrdiy` | MR.DIY | `giyimYasam` | `#FFD100` | `mrdiy`, `mr.diy`, `diy` | - |
| `arcelik` | Arçelik | `teknoloji` | `#E30613` | `arcelik`, `arçelik` | - |
| `beko` | Beko | `teknoloji` | `#003087` | `beko` | - |
| `bosch` | Bosch | `teknoloji` | `#E20015` | `bosch` | - |
| `siemens` | Siemens | `teknoloji` | `#00646E` | `siemens` | - |
| `teknosa` | Teknosa | `teknoloji` | `#FF5F00` | `teknosa` | - |
| `vatan` | Vatan Bilgisayar | `teknoloji` | `#005691` | `vatan` | - |
| `vestel` | Vestel | `teknoloji` | `#CC0000` | `vestel` | - |

---

## 4. 🔥 Firestore Veri Modeli ve Şema Kontratı

Tüm aktüel broşür kayıtları Firestore veritabanında kök düzeydeki `kataloglar` koleksiyonunda saklanır.

### 4.1. Koleksiyon Yapısı: `/kataloglar/{katalogId}`
Doküman ID formatı standart olarak `{magazaKodu}_{brochureId}` bileşik anahtarından oluşur (Örn: `bim_56190`, `a101_59290`).

```json
{
  "katalogId": "bim_56190",
  "magazaKodu": "bim",
  "katalogBasligi": "İndirimli Ürünler",
  "baslangicTarihi": "2026-03-24T00:00:00.000Z",
  "bitisTarihi": "2026-09-24T20:59:59.999Z",
  "sayfaResimleri": [
    "https://cdn.akakce.com/_bro/u/731/56190/56190_464539.jpg",
    "https://cdn.akakce.com/_bro/u/731/56190/56190_464540.jpg"
  ],
  "kapakResmi": "https://cdn.akakce.com/_bro/l/731/56190/56190_464539.jpg",
  "olusturulmaTarihi": "2026-08-27T03:00:00.000Z",
  "guncellenmeTarihi": "2026-08-27T03:00:00.000Z"
}
```

### 4.2. Alan Tanımları ve Tipleri:

| Alan Adı | Tip | Zorunlu | Açıklama ve İş Kuralları |
| :--- | :--- | :--- | :--- |
| `katalogId` | `String` | Evet | Benzersiz katalog kimliği (`{magazaKodu}_{brochureId}`). |
| `magazaKodu` | `String` | Evet | `catalog_scraper.js` `STORES` listesindeki 36 mağazadan birinin normalize edilmiş kodu (Örn: `bim`, `a101`, `gratis`). |
| `katalogBasligi` | `String` | Evet | Kataloğun kampanya başlığı / türü (Örn: "Aldın Aldın", "Haftanın Yıldızları", "İndirim Broşürü"). |
| `baslangicTarihi` | `Timestamp` | Evet | Kampanyanın başlangıç tarihi (Türkiye saatiyle 00:00:00). |
| `bitisTarihi` | `Timestamp` | Evet | Kampanyanın son geçerlilik tarihi (Türkiye saatiyle 23:59:59.999). |
| `sayfaResimleri` | `Array<String>` | Evet | Kataloğa ait tüm sayfaların yüksek çözünürlüklü (`/_bro/u/`) CDN görsel URL dizisi. |
| `kapakResmi` | `String` | Evet | Listeleme gridinde kullanılacak optimize küçük kapak görseli URL'i (`/_bro/l/`). |
| `olusturulmaTarihi` | `Timestamp` | Evet | Veritabanına ilk yazılma zamanı (`serverTimestamp`). |
| `guncellenmeTarihi` | `Timestamp` | Evet | Son güncellenme zamanı (`serverTimestamp`). |

---

## 5. 🛡️ Güvenlik Kuralları ve İzin Matrisi (Security Rules)

Katalog verileri [firestore.rules](file:///d:/firsatkolik/firestore.rules) içerisinde aşağıdaki kural setiyle korunur:

```javascript
// ========================================
// KATALOGLAR COLLECTION
// ========================================
match /kataloglar/{katalogId} {
  // Tüm istemciler ve anonim kullanıcılar katalogları okuyabilir
  allow read: if true;
  
  // Yalnızca sistem adminleri ve Cloud Functions (Admin SDK) yazabilir
  allow write: if isAdmin();
}
```

* **Okuma Güvenliği:** Mobil istemciler ve Web Admin paneli katalogları herhangi bir kimlik doğrulama zorunluluğu olmadan herkese açık okuyabilir.
* **Yazma Güvenliği:** Doğrudan mobil kullanıcıların katalog oluşturması, güncellemesi veya silmesi engellenmiştir. Yalnızca `isAdmin()` doğrulamasından geçen yöneticiler ve Firebase Admin SDK kullanan Cloud Functions servisleri yazma yetkisine sahiptir.

---

## 6. ⚡ Firebase Cloud Functions ve Backend Mimarisi

Katalog kazıma ve veritabanı senkronizasyonu iki ayrı Cloud Function üzerinden yönetilir ([functions/index.js](file:///d:/firsatkolik/functions/index.js) & [functions/catalog_scraper.js](file:///d:/firsatkolik/functions/catalog_scraper.js)):

### 6.1. Zamanlanmış Otomatik Görev (`scrapeCatalogsScheduled`)
* **Tetikleyici:** Cloud Pub/Sub Cron.
* **Çalışma Zamanı:** Her gece **03:00** (Europe/Istanbul saat dilimi: `0 3 * * *`).
* **Kaynak Yapılandırması:** `timeoutSeconds: 540` (9 dakika), `memory: '1GB'`.
* **İşleyiş:** 36 mağazanın Akakçe sayfalarını tarar, broşürleri `kataloglar`'a `merge` ile yazar, ardından bu çalışmada görülmeyen eski kayıtları siler (uzlaştırma). Önce `systemLocks/catalog_scraping` dağıtık kilidi alınır (15 dk lease; manuel ve zamanlanmış tetikleme çakışmaz: `functions/index.js:4376`). `cleanupExpiredDeals` de aynı saatte (03:00) çalışır.

### 6.2. Manuel Yönetici Tetikleyicisi (`scrapeCatalogsManual`)
* **Tetikleyici:** HTTPS Callable (`functions.https.onCall`).
* **Yetkilendirme:** İstek yapan kullanıcının `users/{uid}` kaydında `isAdmin === true` olması zorunludur (`wrapCall` korumalı).
* **Kaynak Yapılandırması:** `timeoutSeconds: 540`, `memory: '1GB'`.
* **Kullanım:** Web Admin panelinde "Katalogları Kazı (Scrape Et)" butonuna basıldığında anlık olarak tetiklenir.

---

## 7. 🤖 Otonom Akakçe Kazıma Motoru ve WAF Bypass Hattı

> 🔗 **Detaylı Referans Dokümanı:**
> - [Akakçe Broşür Kazıma ve Doğrulama Notları](file:///d:/firsatkolik/documentation/_arsiv/aktuel/aktuel-scraper.md) — Cheerio DOM ayrıştırma, sayfa bağlantı haritası ve HTML filtreleme detayları.

Katalog kazıma motoru ([catalog_scraper.js](file:///d:/firsatkolik/functions/catalog_scraper.js)), Akakçe'nin anti-bot ve Cloudflare korumalarını aşmak ve GCP veri merkezi IP'lerinin WAF engellerine takılmasını önlemek üzere tasarlanmış 5 Katmanlı Kurşungeçirmez Master Mimariye (Bulletproof Architecture) sahiptir.

### 7.1. Gelişmiş Çok Katmanlı WAF Bypass Stratejisi (`fetchHtmlWithRetry`)
Her bir URL isteği için en fazla 3 tam deneme yapılır ve her denemede aşağıdaki stratejiler sırayla işletilir (`catalog_scraper.js:154`):

```mermaid
graph TD
    Start[🌐 Hedef Akakçe URL İstegi] --> S1{Strateji A1: Google Translate Proxy Standart}
    S1 -->|Başarılı & isValidHtml| Done[✅ 200 OK - HTML Alındı]
    S1 -->|429 Rate Limit Aşıldı| S2{Strateji A2: Yandex TurboPages Proxy Anlık Failover}
    S1 -->|Hata / Timeout 15s| S2
    S2 -->|Başarılı & isValidHtml| Done
    S2 -->|Hata / Timeout 15s| S3{Strateji A3: Google Translate WebApp Mode}
    S3 -->|Başarılı & isValidHtml| Done
    S3 -->|Hata / Timeout 15s| S4{Strateji B: Direct Googlebot 2.1 UA}
    S4 -->|Başarılı & isValidHtml| Done
    S4 -->|Hata / Timeout 5s| S5{Strateji C: Direct WhatsApp Mobile UA}
    S5 -->|Başarılı & isValidHtml| Done
    S5 -->|Hata / Timeout 5s| S6{Strateji D: Microlink API Proxy}
    S6 -->|Başarılı & isValidHtml| Done
    S6 -->|Hata / Timeout 12s| S7{Strateji E: Native OS Curl Subprocess}
    S7 -->|Başarılı & isValidHtml| Done
    S7 -->|Hata / Timeout 10s| Retry[🔁 Jitter ile Bekle ve Tekrar Dene: Max 3]
```

1. **User-Agent Havuzu (`USER_AGENTS`):** Modern masaüstü ve mobil tarayıcı başlıkları (Chrome 126/125, Safari 17.5, Firefox 127, Edge, mobil Safari/Chrome) rastgele rotasyonla seçilir.
2. **Strateji A1 (Google Translate Standart Proxy):** URL `*.translate.goog` formatına dönüştürülerek Google çeviri omurgası üzerinden çekilir (`_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`). HTTP 429 alınırsa beklemeden anında Strateji A2'ye yedekleme yapılır.
3. **Strateji A2 (Yandex TurboPages Proxy - Anlık Failover):** Google Translate proxy'sinde 429 rate limit veya geçici tıkanma olduğunda istek anında `https://translate.yandex.ru/translate?url=...&lang=tr-tr` omurgasına yönlendirilir. Yandex TurboPages mimarisi Cloudflare engeline takılmaz ve %100 başarıyla ham HTML döner.
4. **Strateji A3 (Google Translate WebApp Modu):** `_x_tr_pto=wapp` ve alternatif dil yönlendirmesiyle web app modu üzerinden istek denenir.
5. **Strateji B (Googlebot User-Agent):** `Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)` başlığı ile doğrudan istek.
6. **Strateji C (WhatsApp Mobile User-Agent):** `WhatsApp/2.23.4.15 A` mobil bot başlığı ile doğrudan istek.
7. **Strateji D (Microlink Proxy):** `api.microlink.io` servisi üzerinden headless HTML ayrıştırma.
8. **Strateji E (Native Curl Subprocess):** İşletim sisteminin yerel `curl` komutu (`spawnSync`) ile ham istek.

---

### 7.2. ⚡ Akıllı Artımlı Kazıma Motoru (Smart Incremental Scraping Engine)
Market broşürleri (BİM, A101, ŞOK vb.) haftalık ve dönemsel statik yayınlardır. Bir kez yayınlandıktan sonra iç sayfaları (`sayfaResimleri`), tarihleri ve kapakları kampanya süresince asla değişmez.

Her gece 113+ broşürün tamamının detay sayfalarını baştan çekmek (149+ dış proxy isteği) Google Translate rate limitlerini (HTTP 429) tüketmekteydi. Bu sorunu sıfır maliyetle kalıcı olarak çözmek için **Akıllı Artımlı Kazıma Motoru (Smart Incremental Scraping)** devreye alınmıştır:

```mermaid
sequenceDiagram
    participant CF as Cloud Function (catalog_scraper.js)
    participant FS as Firestore ('kataloglar')
    participant AK as Akakce / Proxy Omurgası

    Note over CF,FS: ADIM 0: Önbellek Yükleme
    CF->>FS: db.collection('kataloglar').get()
    FS-->>CF: Mevcut Aktif Kataloglar (existingCatalogMap)
    
    loop 36 Mağaza Taraması
        CF->>AK: Mağaza Liste Sayfası (/brosurler/bim)
        AK-->>CF: Aktif Broşür Linkleri (5 Adet)
        loop Her Broşür İçin
            alt existingCatalogMap.has(catalogId) && hasValidData
                Note over CF: ⚡ CACHE HIT (0 HTTP İsteği!)
                CF->>CF: Önbellekteki veriyi allScrapedCatalogs'a ekle
            else Yeni Yayınlanan Broşür (Cache Miss)
                Note over CF: 📄 CACHE MISS: Yeni Broşür Kazı
                CF->>AK: Detay Sayfası İsteği (fetchHtmlWithRetry)
                AK-->>CF: Sayfa Resimleri & Tarihler
                CF->>CF: Jitter Bekleme (600ms - 1000ms)
                CF->>CF: Kapak Storage'a Yedekle
            end
        end
        CF->>CF: Mağazalar Arası Akıllı Jitter (800ms - 1400ms)
    end

    Note over CF,FS: ADIM 1 & 2: Atomik Merge & Mutabakat
    CF->>FS: 400'lük Batch Merge Upsert
    CF->>FS: Obsolete Broşürleri Güvenle Temizle
    CF->>FS: settings/aktuel_meta Dokümanını Güncelle
```

* **İstek Hacminde %72 Azalma:** Günlük dış proxy istek sayısı ~149'dan ~42'ye düşer; Translate proxy token bucket tükenmesi (HTTP 429) %100 engellenir.
* **Fonksiyon Süresinde %65 Hızlanma:** Ortalama çalışma süresi 135 saniyeden ~40 saniyeye iner.
* **Sıfır Veri Kaybı ve Kusursuz Mutabakat:** Önbellekten alınan broşürler de `allScrapedCatalogs` dizisinde yer aldığı için Step 2 mutabakatında (`newCatalogIdSet`) asla silinmez; yalnızca marketin sitesinden kalkan süresi bitmiş broşürler silinir.
* **Kendi Kendini Onarma (Self-Healing):** Önbellekteki dokümanın sayfaları boşsa veya verisi eksikse otomatik olarak **Cache Miss** sayılarak web üzerinden yeniden taranır ve doküman tamir edilir.
* **Depolama Kapak İyileştirmesi (Storage Auto-Healing):** Önbellekten alınan geçerli bir broşürün Storage kapak görseli (`storageCoverUrl`) eksik kalmışsa, detay sayfasına girmeden arka planda otomatik olarak Firebase Storage'a yüklenir; böylece CDN kalkanı kesintisiz tamamlanır.
* **settings/aktuel_meta Matematiksel Uyum Kalkanı:** Mağaza rozet sayıları derlenirken, istemci tarafındaki `KatalogListesiPage` ile %100 örtüşecek şekilde süresi dolmuş kataloglar (`expiryDate < today`) elenir; Türkiye saat dilimi (UTC+3) gece yarısı baz alınarak UTC tarih kaymaları sıfırlanır.

---

### 7.3. Kapsamlı HTML Doğrulama ve Güvenlik Filtresi (`isValidHtml`)
Alınan yanıtın geçerli bir web sayfası olup olmadığı kontrol edilir:
* Minimum içerik uzunluğu: `2500` karakter.
* WAF, CAPTCHA ve hata engelleme kontrolü: Metinde aşağıdaki ifadelerden biri varsa yanıt geçersiz sayılır ve sonraki stratejiye geçilir:
  * `403 - forbidden`, `access is denied`, `robot verification`
  * `captcha-form`, `recaptcha`, `sıra dışı bir trafik`, `unusual traffic`
  * `cf-browser-verification`, `just a moment...`, `attention required! | cloudflare`
  * `429 too many requests`, `rate limit exceeded`, `özür dileriz, aradığınız ürünü bulamadık`

---

### 7.4. Multi-Proxy URL ve Görsel Normalizasyonu
Yandex TurboPages (`turbopages.org`) veya Google Translate (`translate.goog`) üzerinden çekilen sayfalarda:
* Link yolları (`cleanPath`) proxy öneklerinden arındırılarak temiz `/brosurler/{magaza}/{brosur}` formatına dönüştürülür.
* Görsel URL'leri (`sayfaResimleri` ve `kapakResmi`) proxy domainlerinden ve query stringlerinden (`?lang=tr-tr` vb.) arındırılarak doğrudan orijinal Akakçe CDN formatına (`https://cdn.akakce.com/_bro/u/...`) normalize edilir.

---

### 7.5. Mağaza Eşleşme ve Zehirlenme Koruması (Anti-Poisoning Filter)
Akakçe üzerinde broşürü bulunmayan bazı mağazalar (örn: Evkur, Bauhaus, Mopaş) genel `/brosurler/` anasayfasına yönlenebilir. Alakasız broşürlerin ilgili mağazaya eklenmesini önlemek için:
* Link yolunda (`cleanPath`) veya broşür mağaza adında (`storeNameText`) hedeflenen mağazanın anahtar kelimeleri (`keywords`) aranır.
* Hariç tutma kelimeleri (`excludeKeywords`) kontrol edilir (Örn: `hakmar` taranırken `express` içeren Hakmar Express broşürleri elenir).

---

### 7.6. Hassas Broşür Görseli Ayrıştırma ve Çözünürlük Yükseltme
* **Hedefli DOM Seçicisi:** Yan menü ve alt öneri çarkındaki alakasız mağaza broşürlerinin karışmasını engellemek için görseller strictly `#BP_W .p img, #BP_W div.p img, #BP_W img, .bpgc .p img, .bpgc div.p img` konteynerlerinden çekilir.
* `sayfaResimleri`: `/_bro/l/`, `/_bro/y/` ve `/_bro/m/` yolları `/_bro/u/` (Ultra High Res) ile değiştirilir.
* `kapakResmi`: Hızlı yükleme için `/_bro/l/` (Low/Medium Res) olarak normalize edilir.
* `t.gif` şeffaf yer tutucu görselleri filtrelenir.

---

### 7.7. Türkçe Tarih Ayrıştırma ve Zaman Dilimi Motoru
Katalogların geçerlilik süreleri `#br_s` etiketindeki metinden veya URL yolundan çözümlenir:
* **Tarih Aralığı:** `parseDatesFromSpan("12 Temmuz - 19 Temmuz")` ➔ Başlangıç: 12 Temmuz 00:00:00, Bitiş: 19 Temmuz 23:59:59.999.
* **Tek Gün:** `parseDatesFromSpan("21 Mart")` ➔ Başlangıç: 21 Mart 00:00:00, Bitiş: 21 Mart 23:59:59.999.
* **Yedek (Fallback):** URL'den tarih çekilemezse bugünün tarihi başlangıç, 7 gün sonrası ise bitiş kabul edilir.
* **Zaman Dilimi Senkronizasyonu (`createTurkeyDate`):** UTC+3 (İstanbul) saat farkı dikkate alınarak milisaniye düzeyinde doğru Timestamp üretilir.

---

### 7.8. Eşzamanlılık, Jitter ve 500'lük Toplu Veritabanı İşlemleri
* Mağaza içinde `mapConcurrent(items, 2, ...)` ile en fazla 2 eşzamanlı detay sayfası işlenir.
* Yeni çekilen detay sayfaları arasına `600ms - 1000ms`, mağazalar arasına `800ms - 1400ms` rastgele jitter gecikmesi eklenerek mekanik trafik kalıpları ve WAF tetikleyicileri bertaraf edilir.
* Yazma ve silme 400'lük `batch` parçalarıyla yapılır (Firestore limiti 500). Katalog ID'si sabittir (`{magazaKodu}_{brochureId}`). Merging (`merge: true`) ile sıfır kesintili güncelleme sağlanır.
* Fonksiyon bitiminde Cloud Logging'e önbellek istatistikleri (`cacheHits` / `cacheMisses`) raporlanır.

---

## 8. 📤 Sosyal Paylaşım Motoru (KatalogShareService)

Katalog detay ekranındaki paylaşım butonu [KatalogShareService](file:///d:/firsatkolik/lib/services/katalog_share_service.dart) servisini tetikler:

1. **Görsel İndirme (FS-AKT-04):** Aktif görüntülenen sayfa resmi Referer (`https://www.akakce.com/`) ve User-Agent başlıklarıyla `http.get` üzerinden indirilir; 403 veya ağ hatası durumunda otomatik olarak `images.weserv.nl` proxy CDN üzerinden çekilir.
2. **Geçici Dosya Oluşturma:** `path_provider` aracılığıyla `katalog_{id}_p{sayfa}.jpg` adıyla yerel önbelleğe yazılır.
3. **Natif Paylaşım Sayfası:** `share_plus` paketi ile telefonun natif paylaşım sayfasına (WhatsApp, Telegram, Instagram vb.) resim dosyası (`XFile`) olarak gönderilir.
4. **Tanıtım Metni Şablonu:**
```text
📰 {Mağaza Adı} - {Katalog Başlığı} (Sayfa {X} / {Y})
📅 Geçerlilik: {Başlangıç} - {Bitiş}

🔥 En güncel market kataloglarını, indirim broşürlerini ve sıcak fırsatları anında yakalamak için FırsatKolik uygulamasını yükle!
📱 Uygulamayı İndir: https://firsatkolik.app.link/aktuel
```
5. **Yedekleme (Fallback):** Görsel indirme başarısız olursa paylaşım metnine görselin doğrudan CDN linki eklenerek metin paylaşımı yapılır.

---

## 9. 💻 Web Admin Paneli Entegrasyonu

Web Admin panelinde [catalogsView](file:///d:/firsatkolik/web/admin/app.js) üzerinden aktüel kataloglar canlı yönetilir:

* **Gerçek Zamanlı Dinleyici (`loadCatalogs`):** `db.collection('kataloglar').orderBy('baslangicTarihi', 'desc').onSnapshot` ile veritabanındaki tüm kataloglar canlı tablo olarak listelenir.
* **Katalog Sayacı:** Aktif toplam katalog sayısı başlıkta dinamik gösterilir.
* **Manuel Kazıma Butonu (`scrapeCatalogsBtn`):** `scrapeCatalogsManual` Cloud Function'ını çağırarak anlık tarama başlatır.
* **Tüm Katalogları Sil Butonu (`deleteAllCatalogsBtn`):** Hatalı veya süresi geçmiş tüm katalogları istemci SDK'sıyla 400'lük batch bloklarıyla (`web/admin/app.js:14126`; Cloud Function değil, `firestore.rules:353-356` admin yazma) kalıcı olarak siler.

---

## 10. 🧪 Test, Doğrulama ve Operasyonel İzleme

Modülün kararlılığı [functions/tests/](file:///d:/firsatkolik/functions/tests/) altında yer alan test betikleri ile doğrulanır:

| Test Dosyası | Test Edilen Bileşen ve Senaryo |
| :--- | :--- |
| [test_catalog_scraper.js](file:///d:/firsatkolik/functions/tests/test_catalog_scraper.js) | Temel Akakçe kazıyıcı motorunun çalışması ve Cheerio DOM ayrıştırması. |
| [test_guaranteed_scraper.js](file:///d:/firsatkolik/functions/tests/test_guaranteed_scraper.js) | Fetch stratejilerinin ve proxy dayanıklılığının testi (canlı ağ gerektirir). |
| [test_catalog_scraper_flow.js](file:///d:/firsatkolik/functions/tests/test_catalog_scraper_flow.js) | Kazıma akışı simülasyonu. |
| [test_span_date_parser.js](file:///d:/firsatkolik/functions/tests/test_span_date_parser.js) | Türkçe tarih aralıklarının (hafta, ay, gün) ve saat dilimlerinin doğruluğu. |

---

## 11. 📂 İlgili Kaynak Kod Dosyaları ve Referanslar

| Rol / Katman | Dosya Yolu | Açıklama |
| :--- | :--- | :--- |
| **Mobil UI: Seviye 1** | [aktuel_magazalar_page.dart](file:///d:/firsatkolik/lib/screens/aktuel_magazalar_page.dart) | Mağaza gridi, arama ve kategori filtreleme ekranı. |
| **Mobil UI: Seviye 2** | [katalog_listesi_page.dart](file:///d:/firsatkolik/lib/screens/katalog_listesi_page.dart) | Mağaza katalog listesi, sıralama ve geçerlilik rozetleri. |
| **Mobil UI: Seviye 3** | [katalog_detay_page.dart](file:///d:/firsatkolik/lib/screens/katalog_detay_page.dart) | Tam ekran yüksek çözünürlüklü broşür inceleme ve zoom. |
| **Görsel Kalkanı** | [resilient_catalog_image.dart](file:///d:/firsatkolik/lib/widgets/resilient_catalog_image.dart) | Akakçe Referer/UA koruması ve otomatik Weserv proxy CDN fallback bileşeni. |
| **Mobil Model** | [katalog.dart](file:///d:/firsatkolik/lib/models/katalog.dart) | Katalog veri sınıfı, Firestore serileştirme ve geçerlilik metin motoru. |
| **Mobil Paylaşım** | [katalog_share_service.dart](file:///d:/firsatkolik/lib/services/katalog_share_service.dart) | Natif görsel indirme ve sosyal medya paylaşım servisi. |
| **Mağaza Yardımcısı** | [store_asset_helper.dart](file:///d:/firsatkolik/lib/utils/store_asset_helper.dart) | Mağaza logoları ve marka renkleri merkezi eşleme motoru. |
| **Giriş Noktası** | [home_screen.dart](file:///d:/firsatkolik/lib/screens/home_screen.dart) | Anasayfa App Bar "Aktüel" navigasyon butonu. |
| **Backend Kazıyıcı** | [catalog_scraper.js](file:///d:/firsatkolik/functions/catalog_scraper.js) | 5 aşamalı WAF bypass, Akakçe kazıma ve Firestore batch yazma motoru. |
| **Cloud Functions** | [index.js](file:///d:/firsatkolik/functions/index.js) | `scrapeCatalogsScheduled` (03:00) ve `scrapeCatalogsManual` trigger'ları. |
| **Veritabanı Güvenliği** | [firestore.rules](file:///d:/firsatkolik/firestore.rules) | `kataloglar` koleksiyonu okuma/yazma güvenlik kuralları. |
| **Web Yönetim Paneli** | [app.js](file:///d:/firsatkolik/web/admin/app.js) & [index.html](file:///d:/firsatkolik/web/admin/index.html) | `catalogsView` yönetim görünümü, liste, silme ve tetikleme. |
