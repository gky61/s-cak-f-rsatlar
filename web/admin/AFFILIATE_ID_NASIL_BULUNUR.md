# Affiliate ID Nasıl Bulunur? 📋

## 🎯 Genel Bilgi

Affiliate ID'leriniz, her e-ticaret sitesinin **affiliate/ortaklık programına** üye olduktan sonra size verilen özel kodlardır. Her site için farklı bir ID alırsınız.

---

## 1️⃣ Trendyol Affiliate ID (Boutique ID)

### Nasıl Bulunur?

1. **Trendyol Partner Program**'a giriş yapın:
   - https://partner.trendyol.com
   - Hesabınız yoksa kayıt olun

2. Giriş yaptıktan sonra:
   - **Dashboard** → **Ayarlar** → **Boutique Bilgileri**
   - Veya **Link Oluşturucu** bölümünde
   - **Boutique ID**'niz görünecektir

3. **Örnek Format:**
   ```
   Boutique ID: 123456
   veya
   Boutique ID: ABC123
   ```

4. **config.js'de kullanım:**
   ```javascript
   trendyol: {
       boutiqueId: '123456', // ← Buraya yazın
   }
   ```

---

## 2️⃣ Hepsiburada Affiliate ID (Link Gelir - UTM Source)

### Nasıl Bulunur?

1. **Hepsiburada Link Gelir Programı**'na giriş yapın:
   - https://www.hepsiburada.com/link-gelir
   - Hesabınız yoksa kayıt olun
   - "Ürün tavsiye ettikçe kazan" veya "Listeni tavsiye ettikçe kazan" seçeneklerinden birini seçin

2. Giriş yaptıktan sonra:
   - **Hesabım** → **Link Gelir** bölümüne gidin
   - Veya **Ürün Paylaş** butonuna tıklayın
   - Paylaştığınız linklerde otomatik olarak UTM parametreleri eklenir

3. **Link Formatı:**
   Hepsiburada Link Gelir programında linkler şu şekilde oluşturulur:
   ```
   https://www.hepsiburada.com/urun/123456?utm_source=linkgelir&utm_medium=referral&utm_campaign=urun_paylasim
   ```
   
   Ancak bizim sistemimiz için sadece `utm_source` parametresini kullanıyoruz:
   ```
   utm_source=linkgelir
   ```

4. **config.js'de kullanım:**
   ```javascript
   hepsiburada: {
       utmSource: 'linkgelir', // ← Genellikle 'linkgelir' olarak sabit
   }
   ```
   
   **Not:** Hepsiburada Link Gelir programında genellikle `utm_source=linkgelir` sabit olarak kullanılır. Eğer özel bir partner ID'niz varsa onu kullanabilirsiniz.

5. **Alternatif Yöntem:**
   - Hepsiburada hesabınızda **Link Gelir** bölümüne gidin
   - Bir ürün paylaşın ve oluşan linki kontrol edin
   - Link'teki `utm_source` parametresindeki değeri kullanın

---

## 3️⃣ N11 Affiliate ID (Referans ID)

### Nasıl Bulunur?

1. **N11 Affiliate Program**'a giriş yapın:
   - https://www.n11.com/affiliate
   - Hesabınız yoksa kayıt olun

2. Giriş yaptıktan sonra:
   - **Panel** → **Link Oluşturucu**
   - **Referans ID** veya **Ref ID**'niz görünecektir

3. **Örnek Format:**
   ```
   Referans ID: affiliate789
   veya
   Ref ID: partner012
   ```

4. **config.js'de kullanım:**
   ```javascript
   n11: {
       refId: 'affiliate789', // ← Buraya yazın
   }
   ```

---

## 4️⃣ Amazon Affiliate ID (Associate Tag)

### Nasıl Bulunur?

1. **Amazon Associates** programına giriş yapın:
   - https://affiliate.amazon.com.tr (Türkiye)
   - https://affiliate.amazon.com (Global)
   - Hesabınız yoksa kayıt olun

2. Giriş yaptıktan sonra:
   - **Account Settings** → **Account Info**
   - **Associate Tag** veya **Tracking ID**'niz görünecektir

3. **Örnek Format:**
   ```
   Associate Tag: yourstore-21
   veya
   Tracking ID: yourstore-20
   ```

4. **config.js'de kullanım:**
   ```javascript
   amazon: {
       tag: 'yourstore-21', // ← Buraya yazın
   }
   ```

---

## 5️⃣ GittiGidiyor Affiliate ID

### Nasıl Bulunur?

1. **GittiGidiyor Affiliate Program**'a giriş yapın:
   - https://www.gittigidiyor.com/affiliate
   - Hesabınız yoksa kayıt olun

2. Giriş yaptıktan sonra:
   - **Panel** → **Ayarlar** veya **Link Oluşturucu**
   - **Affiliate ID** veya **Partner ID**'niz görünecektir

3. **Örnek Format:**
   ```
   Affiliate ID: partner456
   veya
   Partner ID: affiliate789
   ```

4. **config.js'de kullanım:**
   ```javascript
   gittigidiyor: {
       affiliateId: 'partner456', // ← Buraya yazın
   }
   ```

---

## ⚠️ Önemli Notlar

### 1. Hesabınız Yoksa:
- Her site için ayrı ayrı **affiliate programına kayıt olmanız** gerekir
- Kayıt işlemi genellikle **ücretsizdir**
- Onay süreci 1-3 gün sürebilir

### 2. ID Formatı:
- Her site farklı format kullanır
- Bazıları sadece sayı (123456)
- Bazıları harf-sayı karışımı (ABC123)
- Bazıları özel format (yourstore-21)

### 3. Güvenlik:
- Affiliate ID'lerinizi **kimseyle paylaşmayın**
- `config.js` dosyasını **GitHub'a push etmeden önce** kontrol edin
- ID'lerinizi **güvenli bir yerde** saklayın

---

## 🔍 ID'lerinizi Nerede Bulabilirsiniz?

### Ortak Yerler:
1. **Dashboard/Ana Panel** → Genellikle üst kısımda
2. **Ayarlar/Settings** → Hesap bilgileri bölümünde
3. **Link Oluşturucu** → Link oluştururken görünür
4. **E-posta** → Kayıt onay e-postasında olabilir
5. **Dokümantasyon** → Site'nin yardım sayfalarında

---

## 📝 Örnek config.js Dosyası

ID'lerinizi bulduktan sonra `web/admin/config.js` dosyasını şu şekilde düzenleyin:

```javascript
const affiliateConfig = {
    trendyol: {
        boutiqueId: '123456', // ← Trendyol'dan aldığınız ID
    },
    hepsiburada: {
        utmSource: 'affiliate123', // ← Hepsiburada'dan aldığınız ID
    },
    n11: {
        refId: 'affiliate789', // ← N11'den aldığınız ID
    },
    amazon: {
        tag: 'yourstore-21', // ← Amazon'dan aldığınız Tag
    },
    gittigidiyor: {
        affiliateId: 'partner456', // ← GittiGidiyor'dan aldığınız ID
    }
};
```

---

## ❓ Sık Sorulan Sorular

**S: Tüm siteler için ID almam gerekli mi?**
C: Hayır, sadece komisyon kazanmak istediğiniz siteler için ID almanız yeterli.

**S: ID olmadan link dönüştürme çalışır mı?**
C: Hayır, ID yoksa link dönüştürülmez, orijinal link kalır.

**S: ID'lerimi değiştirebilir miyim?**
C: Evet, `config.js` dosyasını düzenleyip yeni ID'lerinizi yazabilirsiniz.

**S: ID'lerim güvende mi?**
C: `config.js` dosyası sadece sizin bilgisayarınızda ve sunucunuzda olmalı. GitHub'a push etmeden önce kontrol edin.

---

## 🚀 Hızlı Başlangıç

1. **En çok kullandığınız site** için affiliate programına kayıt olun (örn: Trendyol)
2. **ID'nizi bulun** ve `config.js` dosyasına ekleyin
3. **Admin panelinde test edin** - Bir fırsat onaylayın ve linkin dönüştüğünü kontrol edin
4. **Diğer siteler için de** aynı işlemi tekrarlayın

---

## 💡 İpuçları

- **Önce bir site ile başlayın** (örn: Trendyol)
- **Test edin** - Linkin dönüştüğünü kontrol edin
- **Başarılı olursa** diğer siteler için de ID ekleyin
- **Düzenli kontrol edin** - Affiliate programınızdan komisyonlarınızı takip edin

