# Multi-Source Kupon Scraper Dokümantasyonu

> [!NOTE]
> Bu doküman 3 kaynaklı kupon kazıma motorunun teknik referans kılavuzudur. Sistemin canlıdaki eksiksiz mimari, 3 kademeli Wilson Score sıralama algoritması, idempotent oylama motoru, veri şeması, güvenlik kuralları ve şalter kontratı için lütfen **[Kuponlar ve İndirim Kodları Master Mimari Rehberi](file:///d:/firsatkolik/documentation/kuponlar/kuponlar_modulu_rehberi.md)** dokümanını inceleyiniz.

Bu doküman, FırsatKolik uygulamasındaki birden fazla web kaynağından otomatik ve manuel olarak indirim kuponlarını scrape eden (kazıyan) sistemin teknik mimarisini ve çalışma mantığını açıklamaktadır.

---

## 1. Genel Mimarisi ve Akış Özeti

Mevcut tek kaynaklı (DonanımHaber) kupon kazıma yapısı genişletilerek 3 farklı kaynaktan kupon çeken ve ardından **Liyakate Dayalı Kalite ve Skorlama Motoru (Meritocratic Quality Scoring Engine)** ile süzen yüksek performanslı bir mimariye dönüştürülmüştür. 

```
                          ┌────────────────────────┐
                          │  scrapeAndSaveCoupons  │
                          └───────────┬────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         │ (Kaynak 1)                 │ (Kaynak 2)                 │ (Kaynak 3)
         ▼                            ▼                            ▼
┌──────────────────┐        ┌──────────────────┐        ┌────────────────────┐
│  DonanımHaber    │        │   Kuponla.com    │        │  Kuponburada.com   │
│  (16 Mağaza)     │        │ (Sayfa 1 ve 2)   │        │  (18 Mağaza URL)   │
└────────┬─────────┘        └────────┬─────────┘        └─────────┬──────────┘
         │                           │                            │
         └───────────────────────────┼────────────────────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │   Anti-Garbage Gate           │ (isValidCouponCode: 2-30 krk, boşluksuz,
                     │   Sert Kod Doğrulama Filtresi │  sahte buton metinlerini engelleme)
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │   Store-Level Aday Havuzu     │ (Mağaza bazlı havuzlama &
                     │   & Case-Insensitive Dedup    │  seenCodes tekilleştirme)
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │   calculateCouponScore        │ (Tazelik, DH otoritesi, Editör rozeti,
                     │   Kompozit Skorlama Motoru   │  İndirim oranı, Temiz kod bonusu)
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │   Top 6 Curation & Store Cap  │ (Her mağaza için en yüksek skorlu
                     │   (MAX_PER_STORE_FINAL = 6)   │  maksimum 6 seçkin kupon)
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │   Sıralı Timestamp Atama      │ (Date.now() - i*1000 ile deterministik)
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │   Firestore Deterministik     │ (batch.set merge: true ile
                     │   Upsert & Scoped Reconcile   │  oyları koruyarak 95 seçkin kupon)
                     └───────────────────────────────┘
```

---

## 2. Kaynaklar ve Detaylı Çalışma Mantığı

### Kaynak 1: DonanımHaber (`indirimkodu.donanimhaber.com`) — Ana Otorite Kaynağı
- **URL**: `https://indirimkodu.donanimhaber.com/{magaza-slug}/`
- **Öncelik**: Yüksek Otorite (Aktif kupon onayında +40 puan bonus)
- **Çalışma Şekli**:
  - `DH_STORES_MAP` içindeki 16 mağaza için tek tek liste sayfasına gidilir.
  - "Geçmiş Kuponlar" başlığı altındaki süresi dolmuş kuponlar filtrelenir.
  - Her geçerli kuponun detay sayfasına (`/kupon/...`) HTTP isteği atılarak `input#coupon_copy` alanından tam kupon kodu, `meta[property="og:title"]` ve `meta[property="og:description"]` alanlarından başlık ve açıklama çekilir (100ms throttle).
- **`kaynakSite` Etiketi**: `'donanimhaber'`

### Kaynak 2: Kuponla.com — Yardımcı Keşif Kaynağı
- **URL**: 
  - Sayfa 1: `https://kuponla.com/son-eklenen-kuponlar/`
  - Sayfa 2: `https://kuponla.com/son-eklenen-kuponlar/page/2/`
- **Çalışma Şekli**:
  - Liste sayfasındaki `div.coupon-item` kartları taranır.
  - Sadece `a.coupon-code[data-code]` (kod tipi) olan kuponlar alınır (indirim/kampanya duyuruları elenir).
  - Kupon kodu: `data-code` attribute'undan alınır.
  - Mağaza adı: `div.store-name > a` metninden çözümlenir (Örn: "Pazarama Kuponları" → `Pazarama`).
  - Başlık: `h3.coupon-title > a` başlığından.
  - Açıklama: `div.coupon-des-full > p` veya `div.coupon-des-ellip` metninden çekilir.
- **`kaynakSite` Etiketi**: `'kuponla'`

### Kaynak 3: Kuponburada.com — Mağaza Hedefli Curation Kaynağı
- **URL**: `https://www.kuponburada.com/${storeSlug}-indirim-kodu/` (18 mağaza doğrudan hedeflenir) ve yedek olarak `/kesfet/yeni-indirim-kuponlari/`
- **Çalışma Şekli**:
  - 18 büyük zincir mağazayı doğrudan hedefleyen URL mimarisi kullanılır.
  - Sayfadaki `li[data-coupon-type="code"]` kartları taranır. Süresi dolmuş (`data-coupon-expired="1"`) kartlar atlanır.
  - Tarih ayrıştırması: `data-coupon-updated` niteliğinden ISO tarih parse edilerek tazelik skoru hesaplanır.
  - Rozet tespiti: "Editörün Seçimi" (`data-coupon-editor="1"` -> +20 puan) ve "Özel İndirim/İşbirliği" (`data-coupon-exclusive="1"` -> +15 puan) nitelikleri okunur.
  - Kod ayrıştırması: `a.coupon-button` üzerindeki `aria-label` veya `span.code-text` alanlarından temiz kod ayıklanır.
- **`kaynakSite` Etiketi**: `'kuponburada'`

---

## 3. Desteklenen Mağazalar ve Normalizasyon

Sistem `SUPPORTED_STORES` listesindeki 21 mağazaya ait kuponları kabul eder. Bilinmeyen mağazalar otomatik elenir:

```javascript
const SUPPORTED_STORES = [
  'Trendyol', 'Hepsiburada', 'Amazon', 'N11', 'Pazarama',
  'Teknosa', 'MediaMarkt', 'Mavi', 'DeFacto', 'Zara',
  'Mango', 'Beymen', 'PttAVM', 'İncehesap', 'Idefix',
  'Havit', 'Migros', 'Getir', 'Boyner', 'Watsons', 'Gratis'
];
```

**Slug Dönüşüm Haritası (`SLUG_TO_STORE`)**:
- `amazon-com-tr`, `amazoncomtr` → `Amazon`
- `media-markt`, `mediamarkt` → `MediaMarkt`
- `ptt-avm`, `pttavm` → `PttAVM`
- `watsons`, `watsons-turkiye` → `Watsons`
- `gratis`, `gratis-tr` → `Gratis`
- Ve diğer standart slug karşılıkları...

---

## 4. Anti-Garbage Gate ve Skorlama Motoru (Curation & Scoring)

### 4.1. Anti-Garbage Gate (`isValidCouponCode`)
Web kazıma kaynaklarında bazen indirim butonları veya afiş metinleri (örneğin "KODU GÖSTER", "KAMPANYAYI İNCELE", "MARKA GÜNLERİ") yanlışlıkla kupon kodu olarak DOM'dan gelebilmektedir. Bu durumları sıfıra indirmek için şu kurallar katı olarak uygulanır:
1. **Uzunluk:** 2 ila 30 karakter arasında olmalıdır.
2. **Boşluksuzluk:** Gerçek kupon kodlarında kelime boşluğu bulunmaz (`/\s/.test(code) === false`). Boşluk içeren kampanya sloganları doğrudan elenir.
3. **Yasaklı Desenler:** `KODU AL`, `KODU GOR`, `KAMPANYA`, `INDIRIM`, `FIRSAT`, `GIRIS YAP`, `TIKLA` gibi sahte buton etiketleri filtrelenir.

### 4.2. Liyakate Dayalı Kompozit Skorlama (`calculateCouponScore`)
Her bir geçerli kupon adayı için nesnel bir kalite ve güvenilirlik puanı (0-100+) hesaplanır:
- **Tazelik Bonusu (`updatedAt` / `createdAt`):**
  - Son 30 gün içinde güncellenmiş: **+45 puan**
  - Son 60 gün içinde güncellenmiş: **+35 puan**
  - Son 90 gün içinde güncellenmiş: **+20 puan**
  - 180 günden eski: **-25 puan** (bayat kupon cezası)
- **Editör Rozeti (`isEditorChoice`):** **+20 puan**
- **Özel Marka İşbirliği (`isExclusive`):** **+15 puan**
- **DonanımHaber Aktif Kupon Otoritesi:** **+40 puan** (DH mağaza sayfasında aktif liste doğrulaması)
- **Başlıkta Somut İndirim Belirteci:** `%`, `TL`, `İndirim`, `Kuponu` terimleri içeriyorsa **+10 puan**
- **Temiz Kupon Kodu Biçimi:** 3-15 karakterlik standart promo kod formatı için **+10 puan**

### 4.3. Mağaza Başına Tavan Kotası (`MAX_PER_STORE_FINAL = 6`)
Tüm kaynaklardan gelen kuponlar mağaza bazında havuzlanır ve `calculateCouponScore` değerine göre azalan şekilde sıralanır. Her mağaza için en yüksek skora sahip ilk 6 seçkin kupon seçilir.
- **Sonuç:** Canlı veritabanındaki 242 dağınık kupon sayısı, **95 adet son derece taze, yüksek çalışan ve seçkin kupona** optimize edilmiştir.
- **İstemci Performansı:** İstemciye çekilen kupon listesi veri büyüklüğü 95 KB'den 35 KB'ye düşmüş; filtre çipleri anında yüklenir ve liste sıfır takılmayla kaydırılır.

---

## 5. Mükerrer Kontrolü ve Sıralama (Deduplication)

- Çekilen kupon kodları mağaza bazında (Case-Insensitive - büyük/küçük harf duyarsız) bir `Set` veri yapısında (`seenCodes`) tutulur.
- Aynı mağazada aynı kupon kodu birden fazla kaynakta varsa, skoru daha yüksek olan versiyon korunur ve mükerrer oluşumu %100 engellenir.
- **Deterministik Sıralı Timestamp:** Seçilen kuponlar skor sıralamasına göre `Date.now() - (i * 1000)` formülüyle sıralanır. Böylece en yüksek skorlu kuponlar hem veritabanında hem mobil arayüzde en üst sırada listelenir.

---

## 6. Hata Yönetimi ve Güvenlik (Fail-Safe)

1. **İzolasyon**:
   - `scrapeKuponla()`, `scrapeKuponburada()` ve `scrapeDonanimhaber()` yardımcı fonksiyonları kendi `try-catch` blokları ile tamamen izole edilmiştir.
   - Ek sitelerden biri veya ikisi tamamen çökse / hata verse dahi ana akış kesilmez ve taranabilen diğer kaynaklar işlenmeye devam eder.

2. **Tam Veri Kaybını Önleme Checkpoint'i**:
   - Eğer tüm kaynaklardan toplamda **0 kupon** çekilebilirse (örn: internet kesintisi, site DOM değişiklikleri vb.), veritabanındaki mevcut web kuponları **SİLİNMEZ**.
   - Sistem bir uyarı logu basarak var olan kuponları korur.
   - **Kısmi Başarısızlık ve Oy Koruması (FS-KUP-02):** Kısmi kayıplarda ise kullanıcı oyu (`sicakOySayisi + sogukOySayisi > 0`) almış kuponlar asla silinmez, yalnızca `durum: 'gecersiz'` olarak arşivlenir. Yalnızca hiç oyu olmayan sahipsiz kuponlar silinir.

3. **Topluluk Kuponlarının ve Kullanıcı Oylarının Korunması (FS-KUP-02)**:
   - **Deterministik ID:** Her cron çalışmasında rastgele ID üretilmez; mağaza ve kupon kodundan türetilen deterministik anahtar kullanılır (`generateCouponDocId` -> `web_${store}_${code}`).
   - **Oy ve Tarih Koruma:** Scraper önce mevcut web kuponlarının oylarını ve orijinal oluşturulma tarihlerini hafızaya alır. `batch.set(docRef, data, { merge: true })` ile güncelleme yaparken kullanıcıların verdiği sıcak/soğuk oyları sıfırlamaz.
   - **Yetim Alt Doküman Engeli & Kapsamlı Uzlaşma (Scoped Reconciliation):** İlgili mağaza veya kaynak bu kazıma turunda başarıyla taranamadıysa (`successfulDhStores`, `kuponlaSucceeded`, `kuponburadaSucceeded`), o mağazaya ait kuponlar korunur. Başarıyla taranan mağazalarda siteden tamamen kalkan kuponlardan kullanıcı oyu olanlar silinmez, `durum: 'gecersiz'`, `sonlanmaNedeni: 'scraper_stale'` yapılır. Böylece `votes/{userId}` alt dokümanları korunur ve oylar canlı tutulur; yalnızca hiç oyu olmayan çöp kuponlar temizlenir.
   - Kullanıcıların uygulama içerisinden paylaştığı `kaynakTipi == 'topluluk'` kuponlara bu işlemde asla dokunulmaz.

---

## 6. Firestore Veri Modeli

Firestore `kuponlar` koleksiyonuna kaydedilen kupon dokümanı yapısı:

```typescript
interface KuponDocument {
  magazaAdi: string;            // Örn: "Trendyol"
  baslik: string;               // Örn: "%30 Trendyol İndirim Kodu"
  aciklama: string;             // Kupon detay açıklaması
  kuponKodu: string;            // Örn: "SUPER30"
  paylasanKullaniciId: string;  // "admin" (kazıyıcıdan gelenler)
  olusturulmaTarihi: Timestamp; // Firestore Timestamp
  kaynakTipi: string;           // "web" (topluluk kuponlarından ayırmak için)
  kaynakSite: string;           // "donanimhaber" | "kuponla" | "kuponburada"
  sicakOySayisi: number;        // 0
  sogukOySayisi: number;        // 0
  durum: string;                // "aktif"
}
```

---

## 7. Cloud Functions ve Tetikleyiciler

Firebase Cloud Functions altında iki ayrı tetikleyici mevculttur:

1. **Zamanlanmış Tetikleyici (`scrapeCouponsScheduled`)**:
   - **Tetiklenme**: PubSub Cron — `0 4 * * *`, `Europe/Istanbul` (her gün 04:00 TSİ; `functions/index.js:4470`). Katalog kazıma ise 03:00'tadır.
   - **Bölge**: açıkça belirtilmemiş (varsayılan `us-central1`)
   - **Timeout**: 540 saniye (9 dakika), Memory: 1GB
   - **Kilit**: `systemLocks/coupon_scraping` (Firestore, 15 dk lease; `executeWithScraperLock`, `index.js:4376`); kilit varsa çalıştırma atlanır.

2. **Manuel Tetikleyici (`scrapeCouponsManual`)**:
   - **Tetiklenme**: HTTPS Callable (`firebase.functions().httpsCallable('scrapeCouponsManual')`)
   - **Yetki**: Sadece Admin yetkisine sahip kullanıcılar çalıştırabilir.
   - **Kullanım Yeri**: Web Admin Paneli üzerindeki Kupon Scrape Et butonu.
