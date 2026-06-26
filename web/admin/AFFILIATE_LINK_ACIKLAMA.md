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

### Senaryo 2: Hepsiburada Linki

**Gelen Link:**
```
https://www.hepsiburada.com/laptop-xyz-p-HBCV00000ABC
```

**Sizin Affiliate ID'niz:** `partner456`

**Dönüştürülmüş Link:**
```
https://www.hepsiburada.com/laptop-xyz-p-HBCV00000ABC?utm_source=partner456&utm_medium=affiliate
```

---

## 🔧 Nasıl Yapılandırılır?

### 1. Adım: Affiliate ID'lerinizi Bulun

Her e-ticaret sitesinden affiliate programına üye olup ID'nizi alın:

- **Trendyol:** Trendyol Partner Program → Boutique ID
- **Hepsiburada:** Hepsiburada Affiliate → UTM Source ID
- **N11:** N11 Affiliate → Referans ID
- **Amazon:** Amazon Associates → Associate Tag
- **GittiGidiyor:** GittiGidiyor Affiliate → Affiliate ID

### 2. Adım: `config.js` Dosyasını Düzenleyin

`web/admin/config.js` dosyasını açın ve ID'lerinizi ekleyin:

```javascript
const affiliateConfig = {
    trendyol: {
        boutiqueId: 'ABC123', // ← BURAYA TRENDYOL ID'NİZİ YAZIN
    },
    hepsiburada: {
        utmSource: 'partner456', // ← BURAYA HEPSIBURADA ID'NİZİ YAZIN
    },
    n11: {
        refId: 'affiliate789', // ← BURAYA N11 ID'NİZİ YAZIN
    },
    amazon: {
        tag: 'yourstore-21', // ← BURAYA AMAZON TAG'İNİZİ YAZIN
    },
    gittigidiyor: {
        affiliateId: 'partner012', // ← BURAYA GİTTİGİDİYOR ID'NİZİ YAZIN
    }
};
```

### 3. Adım: Admin Panelinde Kullanın

#### Yöntem 1: Otomatik Dönüştürme (Önerilen)

1. Admin paneline giriş yapın
2. "Onay Bekleyen" fırsatları görüntüleyin
3. Bir fırsatın yanındaki **"Onayla"** butonuna tıklayın
4. ✅ Link otomatik olarak affiliate link'e dönüştürülür!

#### Yöntem 2: Manuel Dönüştürme

1. Fırsat detay modalını açın (fırsata tıklayın)
2. "Mağaza / Affiliate Linki" bölümünde **"Affiliate Link'e Dönüştür"** butonuna tıklayın
3. Link otomatik olarak dönüştürülür
4. "Kaydet" butonuna tıklayın

---

## 🎬 Görsel Örnek

### Admin Panelinde Görünüm:

```
┌─────────────────────────────────────────────────┐
│ Mağaza / Affiliate Linki                         │
│                                    [Affiliate    │
│                                    Link'e       │
│                                    Dönüştür]    │
│ ┌─────────────────────────────────────────────┐ │
│ │ https://www.trendyol.com/urun/123456       │ │
│ └─────────────────────────────────────────────┘ │
│ ✅ Trendyol affiliate linkine dönüştürüldü     │
└─────────────────────────────────────────────────┘
```

### Butona Tıkladıktan Sonra:

```
┌─────────────────────────────────────────────────┐
│ Mağaza / Affiliate Linki                         │
│                                    [Affiliate    │
│                                    Link'e       │
│                                    Dönüştür]    │
│ ┌─────────────────────────────────────────────┐ │
│ │ https://www.trendyol.com/urun/123456?        │ │
│ │ boutiqueId=ABC123                            │ │
│ └─────────────────────────────────────────────┘ │
│ ✅ Trendyol affiliate linkine dönüştürüldü     │
└─────────────────────────────────────────────────┘
```

---

## ⚠️ Önemli Notlar

1. **Affiliate ID yoksa:** Link dönüştürülmez, orijinal link kalır
2. **Desteklenmeyen site:** Link dönüştürülmez, uyarı gösterilir
3. **Otomatik dönüştürme:** Sadece fırsat onaylandığında çalışır
4. **Manuel dönüştürme:** İstediğiniz zaman butona tıklayarak yapabilirsiniz

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



