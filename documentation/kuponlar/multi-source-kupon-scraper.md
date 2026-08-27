# Multi-Source Kupon Scraper Dokümantasyonu

> [!NOTE]
> Bu doküman 3 kaynaklı kupon kazıma motorunun teknik referans kılavuzudur. Sistemin canlıdaki eksiksiz mimari, 3 kademeli Wilson Score sıralama algoritması, idempotent oylama motoru, veri şeması, güvenlik kuralları ve şalter kontratı için lütfen **[Kuponlar ve İndirim Kodları Master Mimari Rehberi](file:///d:/firsatkolik/documentation/kuponlar/kuponlar_modulu_rehberi.md)** dokümanını inceleyiniz.

Bu doküman, FırsatKolik uygulamasındaki birden fazla web kaynağından otomatik ve manuel olarak indirim kuponlarını scrape eden (kazıyan) sistemin teknik mimarisini ve çalışma mantığını açıklamaktadır.

---

## 1. Genel Mimarisi ve Akış Özeti

Mevcut tek kaynaklı (DonanımHaber) kupon kazıma yapısı genişletilerek 3 farklı kaynaktan kupon çekecek modüler bir yapıya dönüştürülmüştür. 

```
                          ┌────────────────────────┐
                          │  scrapeAndSaveCoupons  │
                          └───────────┬────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         │ (1. Öncelik)               │ (2. Öncelik)               │ (3. Öncelik)
         ▼                            ▼                            ▼
┌──────────────────┐        ┌──────────────────┐        ┌────────────────────┐
│  DonanımHaber    │        │   Kuponla.com    │        │  Kuponburada.com   │
└────────┬─────────┘        └────────┬─────────┘        └─────────┬──────────┘
         │                           │                            │
         └───────────────────────────┼────────────────────────────┘
                                     │
                                     ▼
                        ┌────────────────────────┐
                        │   Mükerrer Kontrolü    │ (kuponKodu Case-Insensitive Set)
                        └────────────┬───────────┘
                                     │
                                     ▼
                        ┌────────────────────────┐
                        │   Firestore Güncelleme │ (kaynakTipi='web' silinip yeniden yazılır)
                        └────────────────────────┘
```

---

## 2. Kaynaklar ve Detaylı Çalışma Mantığı

### Kaynak 1: DonanımHaber (`indirimkodu.donanimhaber.com`) — Ana Kaynak
- **URL**: `https://indirimkodu.donanimhaber.com/{magaza-slug}/`
- **Öncelik**: 1. Sırada (En yüksek öncelik)
- **Çalışma Şekli**:
  - `DH_STORES_MAP` içindeki 16 mağaza için tek tek liste sayfasına gidilir.
  - "Geçmiş Kuponlar" başlığı altındaki süresi dolmuş kuponlar filtrelenir.
  - Her geçerli kuponun detay sayfasına (`/kupon/...`) HTTP isteği atılarak `input#coupon_copy` alanından tam kupon kodu, `meta[property="og:title"]` ve `meta[property="og:description"]` alanlarından başlık ve açıklama çekilir.
- **`kaynakSite` Etiketi**: `'donanimhaber'`

### Kaynak 2: Kuponla.com — Yardımcı Kaynak
- **URL**: 
  - Sayfa 1: `https://kuponla.com/son-eklenen-kuponlar/`
  - Sayfa 2: `https://kuponla.com/son-eklenen-kuponlar/page/2/`
- **Öncelik**: 2. Sırada
- **Çalışma Şekli**:
  - Liste sayfasındaki `div.coupon-item` kartları taranır.
  - Sadece `a.coupon-code[data-code]` (kod tipi) olan kuponlar alınır (indirim/kampanya duyuruları elenir).
  - Kupon kodu: `data-code` attribute'undan alınır.
  - Mağaza adı: `div.store-name > a` metninden çözümlenir (Örn: "Pazarama Kuponları" → `Pazarama`).
  - Başlık: `h3.coupon-title > a` başlığından.
  - Açıklama: `div.coupon-des-full > p` veya `div.coupon-des-ellip` metninden çekilir.
- **`kaynakSite` Etiketi**: `'kuponla'`

### Kaynak 3: Kuponburada.com — Yardımcı Kaynak (Geliştirilmiş Mimarisi)
- **URL**: 
  - Sayfa 1: `https://www.kuponburada.com/kesfet/yeni-indirim-kuponlari/`
  - Sayfa 2 (AJAX): `https://www.kuponburada.com/kesfet/yeni-indirim-kuponlari/?page=2`
- **Öncelik**: 3. Sırada
- **Çalışma Şekli**:
  - **Sayfa 1**: HTML içinde yer alan `<script type="application/ld+json">` yapısındaki Schema.org verisi parse edilir. `@type: "Offer"` olan ve `identifier.propertyID === "couponCode"` nesnelerinden doğrudan kupon kodu, mağaza adı ve açıklaması kırılgan olmayan yapısal JSON verisi olarak süzülür.
  - **Sayfa 2**: Sitenin AJAX uç noktasına `X-Requested-With: XMLHttpRequest` başlığı eklenerek HTTP GET isteği gönderilir. Dönen JSON yanıtındaki `json.html` dizesi `cheerio` ile parse edilerek 2. sayfadaki yeni kupon kartları da sisteme dahil edilir.
- **`kaynakSite` Etiketi**: `'kuponburada'`

---

## 3. Desteklenen Mağazalar ve Slug Eşleştirme (Normalization)

Sistem sadece uygulamada tanımlı 20 ana mağaza için gelen kuponları kabul eder. Bilinmeyen mağazalar otomatik atlanır.

```javascript
const SUPPORTED_STORES = [
  'Trendyol', 'Hepsiburada', 'Amazon', 'N11', 'Pazarama',
  'Teknosa', 'MediaMarkt', 'Mavi', 'DeFacto', 'Zara',
  'Mango', 'Beymen', 'PttAVM', 'İncehesap', 'Idefix',
  'Havit', 'Migros', 'Getir', 'Boyner'
];
```

**Slug Dönüşüm Haritası (`SLUG_TO_STORE`)**:
- `amazon-com-tr`, `amazoncomtr` → `Amazon`
- `media-markt`, `mediamarkt` → `MediaMarkt`
- `ptt-avm`, `pttavm` → `PttAVM`
- Ve diğer standart slug karşılıkları...

---

## 4. Mükerrer Kayıt Önleme (Deduplication)

- Çekilen kupon kodları (Case-Insensitive - büyük/küçük harf duyarsız) bir `Set` veri yapısında (`seenCodes`) tutulur.
- **Öncelik Mantığı**:
  1. DonanımHaber'den gelen kupon kodları `seenCodes` kümesine eklenir.
  2. Kuponla.com'dan gelen kupon kodları kontrol edilir; eğer `seenCodes` içinde zaten varsa atlanır, yoksa eklenir.
  3. Kuponburada.com'dan gelen kuponlar aynı şekilde kontrol edilip eklenir.
- Bu sayede aynı kupon kodu birden fazla sitede yayınlanmışsa, sadece ilk (en güvenilir) kaynaktan gelen veri saklanır.

---

## 5. Hata Yönetimi ve Güvenlik (Fail-Safe)

1. **İzolasyon**:
   - `scrapeKuponla()` ve `scrapeKuponburada()` yardımcı fonksiyonları kendi `try-catch` blokları ile tamamen izole edilmiştir.
   - Ek sitelerden biri veya ikisi tamamen çökse / hata verse dahi ana akış kesilmez ve DonanımHaber kuponları kaydedilmeye devam eder.

2. **Tam Veri Kaybını Önleme Checkpoint'i**:
   - Eğer 3 kaynaktan toplamda **0 kupon** çekilebilirse (örn: internet kesintisi, site DOM değişiklikleri vb.), veritabanındaki mevcut web kuponları **SİLİNMEZ**.
   - Sistem bir uyarı logu basarak var olan kuponları korur.

3. **Topluluk Kuponlarının Korunması**:
   - Firestore'da silme işlemi yapılırken sadece `kaynakTipi == 'web'` olan dokümanlar silinir.
   - Kullanıcıların uygulama içerisinden paylaştığı `kaynakTipi == 'topluluk'` olan kuponlar asla silinmez.

---

## 6. Firestore Veri Modeli

Firestore `kuponlar` koleksiyonuna kaydedilen kupon dokümanı yapısı:

```typescript
interface KuponDocument {
  magazaAdi: string;            // Örn: "Trendyol"
  baslik: string;               // Örn: "%30 Trendyol İndirim Kodu"
  aciklama: string;             // Kupon detay açıklaması
  kuponKodu: string;            // Örn: "SUPER30"
  paylasanKullaniciId: string;  // "admin"
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
   - **Tetiklenme**: PubSub Cron — `0 4 * * *` (Her gün gece 04:00 TSİ)
   - **Bölge**: `us-central1`
   - **Timeout**: 540 saniye (9 dakika), Memory: 1GB

2. **Manuel Tetikleyici (`scrapeCouponsManual`)**:
   - **Tetiklenme**: HTTPS Callable (`firebase.functions().httpsCallable('scrapeCouponsManual')`)
   - **Yetki**: Sadece Admin yetkisine sahip kullanıcılar çalıştırabilir.
   - **Kullanım Yeri**: Web Admin Paneli üzerindeki Kupon Scrape Et butonu.
