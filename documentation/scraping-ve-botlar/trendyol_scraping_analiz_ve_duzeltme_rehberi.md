# 🛍️ Trendyol ve Hepsiburada Scraping Analizi, Kök Neden ve Çözüm Rehberi

Bu doküman, **FırsatKolik** platformunda (Flutter / Dart Mobil İstemci ve Node.js Otonom Bot Hattı) Hepsiburada ve Trendyol mağazalarından yapılan veri kazıma (scraping) işlemlerindeki kök neden analizlerini, uygulanan mimari çözümleri ve test doğrulama matrislerini kapsamlı şekilde açıklamaktadır.

---

## 📌 1. Hepsiburada Premium Fiyat ve Rozet İyileştirmesi

### 1.1 Problem Tanımı
Hepsiburada ürünlerinin bir kısmında sayfada kullanıcıya **"Premium ile ... TL"** şeklinde gösterilen özel 100 TL'lik indirimler ve Premium rozeti uygulamada çekilemiyor; bunun yerine 100 TL daha yüksek olan normal sepet fiyatı alınıyordu.

### 1.2 Kök Neden Analizi (Root Cause)
1. **`_isIgnoredHbTag` Filtresi:** Kodlarımızda `tagId` içerisinde `premium-a-gec`, `premiuma-gec`, `premiuma-gecis` geçen etiketler Hepsiburada'nın `/api/v1/withoutAffordability` API'sine gönderilirken filtreleniyordu.
2. **`_isValidPremiumCampaignResult` Engelleyicisi:** Hepsiburada API'sinden gelen `evaluateAsPremiumResult` nesnesinde kampanya adı `"Premium'a Geç 100 TL İndirim Kazan"` olduğunda bu sonuç geçersiz sayılıp eleniyordu.
3. **Neden Bazı Ürünlerde Çalışıyordu?:**
   - Satıcı/Kategori bazlı Premium indirimleri olan ürünlerde kampanya adında `"premium'a geç"` geçmediği için çalışıyordu.
   - Doğrudan Hepsiburada'nın 100 TL'lik Premium sübvansiyon kampanyasına sahip ürünlerde ise bu filtreler indirimi ve rozeti siliyordu.

### 1.3 Yapılan Kod Değişiklikleri
* **Dart ([lib/services/scrapers/hepsiburada_scraper.dart](file:///d:/firsatkolik/lib/services/scrapers/hepsiburada_scraper.dart)):**
  - `_isIgnoredHbTag`: Sadece `ilk-siparis` ve `yeni-uye` kuponlarını filtreleyecek şekilde daraltıldı.
  - `_isValidPremiumCampaignResult`: Hepsiburada'nın tüm gerçek Premium kampanyalarını geçerli kabul edecek şekilde güncellendi.
* **Node.js ([cloud-run-bot/scrapers/hepsiburada_scraper.js](file:///d:/firsatkolik/cloud-run-bot/scrapers/hepsiburada_scraper.js)):**
  - `_isIgnoredHbTag` ve `_isValidPremiumCampaignResult` aynı mantıkla güncellendi.

### 1.4 Hepsiburada Test ve Doğrulama Matrisi (6/6 Başarılı)

| # | Ürün Adı | Ürün Linki | Beklenen Gerçek Değer | Eski Kod Sonucu | Yeni Kod Sonucu | Durum |
|:---|:---|:---|:---|:---|:---|:---:|
| 1 | **Jo Moyner Mangal Kömürü** | [https://app.hb.biz/PSzkvEXUIP40](https://app.hb.biz/PSzkvEXUIP40) | **1.149,90 TL** (İndirimsiz: 1.785,57) + Premium | 1.249,90 TL (Rozet Yok) | **1.149,90 TL** (İndirimsiz: 1.785,57) + **Premium ile** | ✅ Başarılı |
| 2 | **GÜNKOR Mangal Kömürü** | [https://app.hb.biz/TcvdqCl0BIuv](https://app.hb.biz/TcvdqCl0BIuv) | **522,00 TL** (İndirimsiz: 622,00) + Premium | 622,00 TL (Rozet Yok) | **522,00 TL** (İndirimsiz: 622,00) + **Premium ile** | ✅ Başarılı |
| 3 | **Nehir Cezve Seti** | [https://app.hb.biz/qpMDKRcu5o2o](https://app.hb.biz/qpMDKRcu5o2o) | **799,00 TL** (İndirimsiz: 1.798,00) + Premium | 899,00 TL (Rozet Yok) | **799,00 TL** (İndirimsiz: 1.798,00) + **Premium ile** | ✅ Başarılı |
| 4 | **Karaca Sütlük** | [https://app.hb.biz/TJEaelOtSQPV](https://app.hb.biz/TJEaelOtSQPV) | **1.029,98 TL** (İndirimsiz: 1.129,98) + Premium | 1.129,98 TL (Tek Fiyat) | **1.029,98 TL** (İndirimsiz: 1.129,98) + **Premium ile** | ✅ Başarılı |
| 5 | **Madame Coco Terlik** *(Referans)* | [https://app.hb.biz/cguqiorVKt3T](https://app.hb.biz/cguqiorVKt3T) | **423,99 TL** (İndirimsiz: 529,99) + Premium | 423,99 TL + Premium ile | **423,99 TL** (İndirimsiz: 529,99) + **Premium ile** | ✅ Başarılı |
| 6 | **Adidas Spor Ayakkabı** *(Referans)* | [https://app.hb.biz/hIteKhHpiWea](https://app.hb.biz/hIteKhHpiWea) | **4.119,10 TL** (İndirimsiz: 4.799,00) + Premium | 4.119,10 TL + Premium ile | **4.119,10 TL** (İndirimsiz: 4.799,00) + **Premium ile** | ✅ Başarılı |

---

## 🧡 2. Trendyol Plus Fiyat Anomalisi ve Kök Neden Analizi

### 2.1 Problem Tanımı ve Ekran Görüntüleri
Kullanıcı tarafından paylaşılan 3 örnek ürün ve ekran görüntüleri:
1. **1. Ürün (Daniel Klein Saat):** `https://ty.gl/bm9q4ztvdo15a`
   - Gerçek Fiyat: **2.436,93 TL**
   - Ekranda Görünen: **2.43693** (Kartta: **2.44 ₺**) *(Hatalı)*
2. **2. Ürün (Lacoste Saat):** `https://ty.gl/v97x6vilus9qx`
   - Gerçek Fiyat: **5.802,30 TL** (İndirimsiz: **6.447 TL**)
   - Ekranda Görünen: **5.8023** (Kartta: **5.80 ₺**), İndirimsiz: **6 ₺** (6.447) *(Hatalı)*
3. **3. Ürün (Deppo Trend Telefon Tutucu - Çalışan Örnek):** `https://ty.gl/evt0in2j5hdke`
   - Gerçek Fiyat: **263.84 TL**
   - Ekranda Görünen: **263.84 TL** *(Doğru)*

### 2.2 Kök Neden Analizi (Root Cause)
Tüm ürünlerde **Trendyol Plus rozeti (`Trendyol +`) başarıyla çekiliyordu**; ancak fiyat parsing motorunda kritik bir sayı formatı uyuşmazlığı tespit edildi:

1. **Trendyol Plus UI Formatı:**
   Trendyol web ve mobil web arayüzünde Plus bileşeni (`.ty-plus-price-discounted-price` ve `.ty-plus-price-original-price`) metinleri **Amerikan/Uluslararası sayı formatında (US Number Format)** render etmektedir:
   - Daniel Klein: `"2,436.93 TL"` *(virgül binlik ayırıcı, nokta ondalık)*
   - Lacoste İndirimli: `"5,802.30 TL"` *(virgül binlik ayırıcı, nokta ondalık)*
   - Lacoste İndirimsiz: `"6,447 TL"` *(virgül binlik ayırıcı)*
   - Deppo Trend: `"263.84 TL"` *(binlik yok, nokta ondalık)*

2. **Eski `parsePriceText` Algoritmasındaki Hata:**
   Eski `parsePriceText` metodu, gelen her fiyat metnini sadece **Türkçe format (`1.234,56`)** varsayarak işliyordu:
   ```dart
   // ESKİ HATALI MANTIK:
   if (cleaned.contains('.') && cleaned.contains(',')) {
     cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
   } else if (cleaned.contains(',')) {
     cleaned = cleaned.replaceAll(',', '.');
   }
   ```
   Bu mantık nedeniyle:
   - `"2,436.93"` ifadesinde nokta silindi (`2,43693`), virgül noktaya dönüştürüldü -> **`2.43693`** (2 lira 44 kuruş)!
   - `"5,802.30"` ifadesinde nokta silindi (`5,80230`), virgül noktaya dönüştürüldü -> **`5.8023`** (5 lira 80 kuruş)!
   - `"6,447"` ifadesinde virgül noktaya dönüştürüldü -> **`6.447`** (6 lira 44 kuruş)!
   - `"263.84"` ifadesinde ise virgül olmadığı ve noktadan sonra 2 basamak olduğu için şans eseri etkilenmedi ve **`263.84`** olarak doğru kaldı.

### 2.3 Uygulanan Mimari Çözüm (Akıllı Çift Formatlı Sayı Ayrıştırıcısı)
`BaseProductScraper` sınıfında yer alan ve tüm scraper'lar (Trendyol, Hepsiburada, Amazon vb.) tarafından ortak kullanılan `parsePriceText` metodu, hem Türkçe (`1.234,56 TL`, `1.798 TL`, `423,99 TL`) hem de Uluslararası/Trendyol Plus (`2,436.93 TL`, `6,447 TL`, `263.84 TL`) formatlarını matematiksel basamak analizi ile ayırt edecek şekilde yeniden yazıldı:

```dart
// DART & NODE.JS YENİ AKILLI PARSER MANTIĞI:
final hasDot = cleaned.contains('.');
final hasComma = cleaned.contains(',');

if (hasDot && hasComma) {
  final lastDotIndex = cleaned.lastIndexOf('.');
  final lastCommaIndex = cleaned.lastIndexOf(',');
  if (lastCommaIndex > lastDotIndex) {
    // Türkçe Format: 1.234,56 -> noktalar binlik, virgül ondalık
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else {
    // US Format: 2,436.93 -> virgüller binlik, nokta ondalık
    cleaned = cleaned.replaceAll(',', '');
  }
} else if (cleaned.contains(',')) {
  final parts = cleaned.split(',');
  if (parts.length == 2) {
    // 6,447 (binlik ayırıcı) -> 6447; 423,99 veya 6,4 -> ondalık (423.99)
    if (parts[1].length == 3 && parts[0].length >= 1 && parts[0].length <= 3) {
      cleaned = cleaned.replaceAll(',', '');
    } else {
      cleaned = cleaned.replaceAll(',', '.');
    }
  } else {
    cleaned = cleaned.replaceAll(',', '');
  }
} else if (cleaned.contains('.')) {
  final parts = cleaned.split('.');
  if (parts.length == 2) {
    // 1.798 (binlik ayırıcı) -> 1798; 263.84 veya 12.5 -> ondalık (263.84)
    if (parts[1].length == 3 && parts[0].length >= 1 && parts[0].length <= 3) {
      cleaned = cleaned.replaceAll('.', '');
    }
  } else {
    cleaned = cleaned.replaceAll('.', '');
  }
}
```

---

### 2.4 Trendyol Test ve Doğrulama Matrisi

| # | Ürün Adı | Link | Ham Fiyat Metni | Eski Sonuç | Yeni Sonuç | Durum |
|:---|:---|:---|:---|:---|:---|:---:|
| 1 | **Daniel Klein Erkek Kol Saati** | [https://ty.gl/bm9q4ztvdo15a](https://ty.gl/bm9q4ztvdo15a) | `2,436.93 TL` | 2.43693 ₺ | **2.436,93 TL** + Plus'a Özel | ✅ Düzeltildi |
| 2 | **Lacoste Erkek Kol Saati** | [https://ty.gl/v97x6vilus9qx](https://ty.gl/v97x6vilus9qx) | `5,802.30 TL` / `6,447 TL` | 5.8023 ₺ / 6.447 ₺ | **5.802,30 TL** (Liste: 6.447 TL) + Plus'a Özel | ✅ Düzeltildi |
| 3 | **Deppo Trend Telefon Tutucu** | [https://ty.gl/evt0in2j5hdke](https://ty.gl/evt0in2j5hdke) | `263.84 TL` | 263.84 ₺ | **263.84 TL** + Plus'a Özel | ✅ Korundu |

---

## 🧪 3. Kapsamlı Sınır Değer (Edge Case) Doğrulama Matrisi (17/17 Başarılı)

Yeni ayrıştırıcı hem Node.js hem de Dart üzerinde 17 farklı senaryoda test edilmiş ve %100 doğrulukla geçmiştir:

1. `2,436.93 TL` -> `2436.93` ✅
2. `5,802.30 TL` -> `5802.3` ✅
3. `6,447 TL` -> `6447.0` ✅
4. `263.84 TL` -> `263.84` ✅
5. `1.785,57 TL` -> `1785.57` ✅
6. `1.798 TL` -> `1798.0` ✅
7. `423,99 TL` -> `423.99` ✅
8. `12,5 TL` -> `12.5` ✅
9. `12.5 TL` -> `12.5` ✅
10. `1,234,567.89 TL` -> `1234567.89` ✅
11. `1.234.567,89 TL` -> `1234567.89` ✅
12. `100 TL` -> `100.0` ✅
13. `100,00 TL` -> `100.0` ✅
14. `9.99` -> `9.99` ✅
15. `9,99` -> `9.99` ✅
16. `1,500` -> `1500.0` ✅
17. `1.500` -> `1500.0` ✅

---

## 📁 Değiştirilen Dosyalar
* **Mobil İstemci (Dart):**
  - [lib/services/scrapers/base_scraper.dart](file:///d:/firsatkolik/lib/services/scrapers/base_scraper.dart)
  - [lib/services/scrapers/hepsiburada_scraper.dart](file:///d:/firsatkolik/lib/services/scrapers/hepsiburada_scraper.dart)
* **Otonom Bot / Sunucu (Node.js):**
  - [cloud-run-bot/scrapers/base_scraper.js](file:///d:/firsatkolik/cloud-run-bot/scrapers/base_scraper.js)
  - [cloud-run-bot/scrapers/hepsiburada_scraper.js](file:///d:/firsatkolik/cloud-run-bot/scrapers/hepsiburada_scraper.js)
* **Dokümantasyon:**
  - [documentation/scraping-ve-botlar/trendyol_scraping_analiz_ve_duzeltme_rehberi.md](file:///d:/firsatkolik/documentation/scraping-ve-botlar/trendyol_scraping_analiz_ve_duzeltme_rehberi.md)
  - [documentation/scraping-ve-botlar/scraping_rules_and_strategies.md](file:///d:/firsatkolik/documentation/scraping-ve-botlar/scraping_rules_and_strategies.md)
  - [documentation/scraping-ve-botlar/scraping_mimarisi_rehberi.md](file:///d:/firsatkolik/documentation/scraping-ve-botlar/scraping_mimarisi_rehberi.md)
