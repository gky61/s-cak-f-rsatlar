# Affiliate Link Dönüştürme - Nasıl Çalışır?

## 🎯 Ne İşe Yarar?

Bot veya kullanıcılar fırsat paylaştığında, gelen linkleri **sizin affiliate linklerinize** otomatik olarak dönüştürür. Böylece satışlardan komisyon kazanırsınız.

## 📝 Örnek Senaryo

### Senaryo 1: Trendyol Linki

**Gelen Link (Bot'tan):**
```
https://www.trendyol.com/urun/iphone-15-pro-123456
```

**Sizin Affiliate ID'niz:** `ABC123`

**Dönüştürülmüş Link:**
```
https://www.trendyol.com/urun/iphone-15-pro-123456?boutiqueId=ABC123
```

**Sonuç:** Kullanıcı bu linkten alışveriş yaparsa, siz komisyon kazanırsınız! 💰

---

### Senaryo 2: Hepsiburada Linki (LinkGelir / Adjust Universal Deep-Link)

**Gelen Link:**
```
https://www.hepsiburada.com/laptop-xyz-p-HBCV00000ABC
```

**Sizin Affiliate Hesap Adınız (adj_adgroup):** `muratcan gokyokus`

**Dönüştürülmüş Link (0 ms Sentezlenen Adjust Deep-Link):**
```
https://7t4g.adj.st/product?sku=HBCV00000ABC&adj_t=10zuiki3_y4q2fze&adj_adgroup=muratcan%20gokyokus&adj_campaign=ux_gelistirmeleri&utm_source=influencer&utm_medium=linkgelir&adj_fallback=https%3A%2F%2Fwww.hepsiburada.com%2Flaptop-xyz-p-HBCV00000ABC...
```

---

## 🔧 Nasıl Yapılandırılır?

### 1. Adım: Affiliate ID'lerinizi Bulun

Her e-ticaret sitesinden affiliate programına üye olup ID'nizi alın:

- **Teknosa:** Teknosa Paylaş Kazan / TUNE (HasOffers) → User UUID (`906bd201-92dc-4898-914a-10309b2cd576`)
- **Hepsiburada:** Hepsiburada LinkGelir / Adjust → Hesap/Influencer Adı (`muratcan gokyokus`)
- **Trendyol:** Trendyol Partner Program → Boutique ID
- **N11:** N11 Affiliate → Referans ID
- **Amazon:** Amazon Associates → Associate Tag
- **GittiGidiyor:** GittiGidiyor Affiliate → Affiliate ID

### 2. Adım: `config.js` Dosyasını Düzenleyin

`web/admin/config.js` dosyasını açın ve ID'lerinizi ekleyin:

```javascript
const affiliateConfig = {
    teknosa: {
        userId: '906bd201-92dc-4898-914a-10309b2cd576', // ← TEKNOSA PAYLAŞ KAZAN UUID
        enabled: true,
    },
    trendyol: {
        boutiqueId: 'ABC123', // ← TRENDYOL ID'NİZ
        enabled: true,
    },
    hepsiburada: {
        accountName: 'muratcan gokyokus', // ← LINKGELİR ADGROUP ADINIZ
        trackerToken: '10zuiki3_y4q2fze', // ← ADJUST TAKİP TOKENI
        campaign: 'ux_gelistirmeleri',   // ← ADJUST KAMPANYA ADI
        enabled: true,
    },
    n11: {
        refId: 'affiliate789', // ← N11 ID'NİZ
        enabled: true,
    },
    amazon: {
        tag: 'yourstore-21', // ← AMAZON TAG'İNİZ
        enabled: true,
    },
    gittigidiyor: {
        affiliateId: 'partner012', // ← GİTTİGİDİYOR ID'NİZ
        enabled: true,
    }
};
```

### 3. Adım: Admin Panelinde Kullanın

> 🌟 **Canlı Desteklenen Mağazalar:** Canlı affiliate dönüşümü ve Çoklu Link (Dual View) arayüzü **Teknosa ve Hepsiburada** için tam aktiftir (`activeStores: ['teknosa', 'hepsiburada']`).

#### 🛑 Acil Durum Şalteri (Kill-Switch)
* Web Admin > Ayarlar (Settings) > Acil Durum Kontrolleri altından **Hepsiburada Affiliate (LinkGelir)** veya **Teknosa Affiliate (Paylaş Kazan)** şalteri kapatıldığında:
  1. Sistem hiçbir hata üretmeden güvenli fallback moduna geçer.
  2. Arayüzde affiliate rozetleri otomatik gizlenir; düzenleme modalı tek organik link moduna döner.
  3. Fırsat paylaşımında veya onayında affiliate üretimi durdurulur; temiz organik kanonik ürün URL'i kullanılır.
  4. Eski bir fırsat affiliate linki içerse bile, kullanıcı veya admin *"Mağazaya Git"* butonuna bastığında aracı yönlendirme olmadan doğrudan orijinal mağaza sayfası açılır.

#### Yöntem 1: Otomatik Dönüştürme (Varsayılan - Şalter Açıkken)

1. Fırsat kullanıcı tarafından paylaşıldığında sistem arka planda otomatik olarak affiliate linke dönüştürür.
2. Web Admin panelinde fırsat modalı açıldığında (`showDealModal`) link otomatik olarak kontrol edilir ve `#editAffiliateUrl` kutusuna hazır doldurulur.
3. Tablodaki **"Onayla"** butonuna tıklandığında veya modal kaydedildiğinde link doğrudan affiliate link olarak korunur/güncellenir.

#### Yöntem 2: Manuel Dönüştürme & Test

1. Fırsat detay modalını açın (fırsata tıklayın).
2. "Bağlantı & Affiliate (Çoklu Görünüm)" bölümünde **"Orijinalden Affiliate Üret"** butonuna basarak temiz linkten anında yeniden affiliate link türetebilirsiniz.
3. **"Affiliate Test Et"** butonuyla yönlendirmenin doğru çalıştığını kontrol edebilirsiniz.
4. "Kaydet" veya "Onayla" butonuna tıklayın.

---

## 🎬 Görsel Örnek

### Admin Panelinde Görünüm:

```
┌─────────────────────────────────────────────────────────────┐
│ Bağlantı & Affiliate (Çoklu Görünüm)                         │
│ 1. Orijinal Mağaza Linki (cleanUrl)                         │
│ ┌──────────────────────────────────────────────┐ [Orijinal  │
│ │ https://www.teknosa.com/urun/123456          │  Linki Aç] │
│ └──────────────────────────────────────────────┘            │
│ [Orijinalden Affiliate Üret]                                │
│                                                             │
│ 2. Aktif Affiliate Linki (link / url)                       │
│ ┌──────────────────────────────────────────────┐ [Affiliate │
│ │ https://rdr.btrck.com/aff_c?...              │  Test Et]  │
│ └──────────────────────────────────────────────┘            │
│ ✅ Teknosa TUNE affiliate linki hazır ve aktif              │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚠️ Önemli Notlar

1. **Affiliate ID / UUID yoksa:** Link dönüştürülmez, orijinal link kalır
2. **Desteklenmeyen / Taslak site:** Link dönüştürülmez, orijinal link korunur
3. **Otomatik dönüştürme:** Fırsat paylaşımında, modal açılışında ve onay/kaydet işlemlerinde koşulsuz olarak çalışır
4. **Manuel dönüştürme:** İhtiyaç duyduğunuzda "Orijinalden Affiliate Üret" butonuyla her zaman linki yeniden türetebilirsiniz

---

## 🔍 Nasıl Test Edilir?

1. Admin paneline giriş yapın
2. Bir fırsat seçin (Trendyol, Hepsiburada vb.)
3. "Affiliate Link'e Dönüştür" butonuna tıklayın
4. Link alanında `?boutiqueId=...` veya `?utm_source=...` gibi parametreler görünmeli
5. Linki kopyalayıp tarayıcıda açın, affiliate ID'nin eklendiğini kontrol edin

---

## 💡 İpuçları

- **Tüm siteler için ID ekleyin:** Daha fazla komisyon kazanırsınız
- **ID'leri güvenli tutun:** `config.js` dosyasını paylaşmayın
- **Düzenli kontrol edin:** Affiliate programınızdan komisyonlarınızı takip edin

---

## ❓ Sorun Giderme

**Problem:** Link dönüştürülmüyor
- **Çözüm:** `config.js` dosyasında ilgili site için ID eklediğinizden emin olun

**Problem:** "Affiliate ID yapılandırılmamış" hatası
- **Çözüm:** İlgili site için ID'yi `config.js` dosyasına ekleyin

**Problem:** Buton görünmüyor
- **Çözüm:** Sayfayı yenileyin (F5) veya tarayıcı cache'ini temizleyin

---

## 🌟 Çoklu Görünüm (Dual View): Orijinal Link vs Affiliate Link

Web ve Mobil Admin panellerinde ürün düzenleme ekranında her iki link de bağımsız olarak yönetilir:
1. **Orijinal Mağaza Linki (`cleanUrl`):** Kullanıcılara gösterilen, "Mağaza linkini kopyala" denildiğinde kopyalanan ve WhatsApp/Telegram paylaşımlarında yer alan temiz kanonik linktir.
2. **Aktif Affiliate Linki (`link` / `url`):** Yalnızca kullanıcı "Mağazaya Git" butonuna bastığında çalışan ve komisyon kazandıran linktir.
"Orijinalden Affiliate Üret" butonuyla temiz linkten anında affiliate link üretilebilir; kaydederken her iki alan da Firestore'a eksiksiz yazılır.

---

## 🚀 Mağazaya Git Butonunda Hibrit Yönlendirme & Zero Browser / Zero Flicker Mimarisi

Kullanıcı "Mağazaya Git"e bastığında FırsatKolik mobil uygulamasında çalışan **Profesyonel Hibrit Yönlendirme Motoru (`StoreRedirectService`)**, Web Admin'deki şalterlerinize göre akıllıca davranır:

* **Şalter KAPALI İken (Eski Dünya Güvencesi):**
  * Kullanıcı "Mağazaya Git"e bastığında affiliate linki **anında temiz organik linke unwrap edilir**.
  * Hiçbir geçiş HUD'ı veya bekleme ekranı açılmaz; kullanıcı doğrudan orijinal mağaza sayfasına yönlendirilir (eski organik çalışma prensibi %100 korunur).
* **Şalter AÇIK İken (Profesyonel Hibrit Yönlendirme):**
  * **Hepsiburada (0 ms Doğrudan Yerel Şema):** Cihazda Hepsiburada uygulaması yüklüyse, `hbapp://` derin linki ile **0 ms'de, popupsız ve tarayıcısız doğrudan Hepsiburada uygulaması açılır**. Adjust SDK gelen intent parametrelerini cihazın kendi GAID'siyle okur. Sentetik arka plan bot pingi atılmaz (%0 sahtekarlık riski).
  * **Teknosa (Diyalog İçi 302 Çözümleme & Zero Chrome Flicker):** Ekranda 1.2 saniyelik şık ve kurumsal **"Teknosa Mağazasına Güvenle Aktarılıyorsunuz"** HUD'ı belirir. Diyalog ekrandayken arka planda (300 ms içinde) TUNE (`rdr.btrck.com`) linkinin 302 yönlendirmesi sessizce çözülür, TUNE tıklaması kaydedilir ve yakalanan nihai `teknosa.com` adresi doğrudan yerel Teknosa uygulamasına (`com.tmob.teknosa`) fırlatılır. **Chrome tarayıcısı hiç açılmaz, adres çubuğunda hiçbir takip linki görünmez ve kullanıcı HUD'dan doğrudan Teknosa uygulamasına geçer!** Cihazda Teknosa uygulaması yoksa harici tarayıcı temiz ürün sayfasına yönlenir.




