# ⚖️ FırsatKolik — Ticari Reklam Yönetmeliği Uyum ve Etiketleme Rehberi

Bu doküman, T.C. Ticaret Bakanlığı'nın **Ticari Reklam ve Haksız Ticari Uygulamalar Yönetmeliği** (özellikle 1 Ağustos düzenlemeleri ve Sosyal Medya Etkileyicileri Kılavuzu) kapsamında FırsatKolik platformundaki tüm içeriklerde uygulanan **Otomatik Reklam/Tanıtım Etiketleme Standartları**'nı ve teknik altyapısını açıklamaktadır.

---

## 🏛️ 1. Yasal Zorunluluk ve Düzenleme Arka Planı

Türkiye'deki tüketiciyi koruma ve ticari reklam mevzuatı uyarınca:
1. **Açık ve Anlaşılır İfade Zorunluluğu:** Gelir ortaklığı (affiliate marketing), sponsorluk veya ticari kazanç sağlayan tüm indirim, fırsat ve kampanya paylaşımlarında tüketicinin doğrudan bilgilendirilmesi zorunludur.
2. **Standartlaştırılmış Etiketleme:** Reklam içeriklerinin karmaşık, yanıltıcı veya küçük harfli gizli ibareler yerine açıkça görülebilir **`#tanıtım`** etiketi ile yayınlanması esastır.
3. **Kapsam:** Hem son kullanıcıların uygulama içinden paylaştığı fırsatlar hem de Telegram botu aracılığıyla taranarak platforma eklenen tüm otomatik ilanlar bu yasal zorunluluğa tabidir.

---

## 🏗️ 2. `AdvertisingComplianceService` Mimarisi

Yasal uyumu %100 otonom hale getirmek ve insan hatasını sıfıra indirmek amacıyla sistemde iki dilde (Dart ve Node.js) birebir aynı mantıkla çalışan uyum servisi geliştirilmiştir:

* **Mobil İstemci Servisi:** `lib/services/advertising_compliance_service.dart`
* **Sunucu / Bot Servisi:** `cloud-run-bot/advertising_compliance_service.js`

```mermaid
graph TD
    A[Ham Fırsat Açıklaması / Telegram Mesajı] --> B[ensureAdvertisingDisclosure Metodu]
    B --> C[ADVERTISING_TAG_CLEANUP_REGEX: Eski/Düzensiz Etiketler Temizlenir]
    C -->|#reklam, #işbirliği, [SPONSORLU] vb. kaldırılır| D[Metin Boşlukları Normalize Edilir]
    D --> E[Metnin En Sonuna Standart #tanıtım Eklenir]
    E --> F[Firestore deals Koleksiyonuna Kayıt]
```

---

## 🔍 3. Teknik Çalışma Prensipleri ve Regex Kuralları

### 3.1 Eski / Uyumsuz Etiketlerin Temizlenmesi (`ADVERTISING_TAG_CLEANUP_REGEX`):
Kullanıcılar veya Telegram kanalları içeriklerinde farklı varyasyonlarda reklam ibareleri kullanmış olabilir. Sistem bu düzensiz etiketleri temizler:

```javascript
const ADVERTISING_TAG_CLEANUP_REGEX = /(?:#|\[|\()(?:reklam|reklamdır|reklamdir|tanıtım|tanitim|işbirliği|isbirligi|sponsorlu|ortaklık|ortaklik|affiliate)(?:\]|\))?/gi;
```

### 3.2 Standart `#tanıtım` Etiketinin Eklenmesi (`ensureAdvertisingDisclosure`):
Temizleme işleminden sonra açıklama metninin sonuna iki satır boşluk (`\n\n`) bırakılarak resmi `#tanıtım` etiketi eklenir.

```javascript
function ensureAdvertisingDisclosure(text, defaultTag = '#tanıtım') {
  let safeText = (text || '').trim();

  // Metin tamamen boşsa varsayılan açıklama + etiket döner
  if (!safeText) {
    return `Fırsat Ürünü Detayları\n\n${defaultTag}`;
  }

  // Varsa eski etiketleri temizle
  safeText = safeText.replace(ADVERTISING_TAG_CLEANUP_REGEX, '').trim();
  safeText = safeText.replace(/\n{3,}/g, '\n\n').trim();

  if (!safeText) {
    return `Fırsat Ürünü Detayları\n\n${defaultTag}`;
  }

  // Standart #tanıtım etiketini ekle
  return `${safeText}\n\n${defaultTag}`;
}
```

---

## 📱 4. Entegrasyon Noktaları (Tetiklenme Yerleri)

Sistemdeki hiçbir fırsatın etiketsiz kaydedilmemesi için uyum servisi 4 ana noktada zorunlu kılınmıştır:

1. **Mobil Fırsat Paylaşım Ekranı (`lib/screens/submit_deal_screen.dart`):**
   - Kullanıcı formu gönderdiğinde açıklama alanı `AdvertisingComplianceService.ensureAdvertisingDisclosure` ile filtrelenir.
2. **Fırsat Servisi (`lib/services/deal_service.dart`):**
   - `createDeal` metodunda `description` parametresi kaydedilmeden önce son bir güvenlik katmanı olarak filtreden geçirilir.
3. **Telegram Botu Canlı Akışı (`cloud-run-bot/telegram_bot.js`):**
   - Telegram kanalından yakalanan mesajlar parse edildikten sonra açıklama metnine otomatik `#tanıtım` eklenir.
4. **Geçmiş Mesaj Çekme Servisi (`cloud-run-bot/fetch_history.js`):**
   - Geçmişe dönük taranan tüm fırsat içerikleri aynı uyum filtresinden geçirilir.

---

## 🧪 5. Otomatik Doğrulama Testleri

Yasal uyum mekanizması iki bağımsız test süitiyle sürekli test edilmektedir:

| Test Dosyası | Ortam | Komut |
| :--- | :--- | :--- |
| **`test/advertising_compliance_test.dart`** | Flutter / Dart | `flutter test test/advertising_compliance_test.dart` |
| **`cloud-run-bot/tests/test_advertising_compliance.test.js`** | Node.js / Bot | `node cloud-run-bot/tests/test_advertising_compliance.test.js` |

---
*FırsatKolik Ticari Reklam Yönetmeliği Uyum Dokümanı — 2026*
