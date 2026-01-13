# FIRSATKOLİK Web Admin Paneli

PC'den tarayıcıda kullanılabilen özel admin paneli.

## 📍 Konum

`web/admin/index.html`

## 🚀 Kullanım

### Yerel Test

1. **Basit HTTP Server ile:**
   ```bash
   cd web/admin
   python3 -m http.server 8000
   ```
   Sonra tarayıcıda: `http://localhost:8000`

2. **Firebase Hosting ile:**
   ```bash
   firebase serve --only hosting
   ```
   Sonra: `http://localhost:5000/admin`

### Firebase Hosting'e Deploy

`firebase.json` dosyasına hosting yapılandırması ekleyin:

```json
{
  "hosting": {
    "public": "web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/admin/**",
        "destination": "/admin/index.html"
      }
    ]
  }
}
```

Sonra deploy edin:
```bash
firebase deploy --only hosting
```

## 🔐 Giriş

- Sadece **admin yetkisine sahip** kullanıcılar giriş yapabilir
- Google Sign-In ile giriş yapılır
- Admin kontrolü Firestore'da `users/{uid}/isAdmin: true` alanına göre yapılır

## ✨ Özellikler

- ✅ **Onay Bekleyen Deal'leri Görüntüleme**
- ✅ **Deal Onaylama/Reddetme**
- ✅ **Deal Yayından Kaldırma**
- ✅ **Deal Yeniden Aktifleştirme**
- ✅ **İstatistikler** (Onay bekleyen, Onaylanmış, Bot, Kullanıcı deal sayıları)
- ✅ **Filtreleme** (Onay bekleyen, Onaylanmış, Tümü)
- ✅ **Deal Detayları** (Modal ile)
- ✅ **Affiliate Link Dönüştürme** (Otomatik ve manuel)
- ✅ **Responsive Tasarım** (Mobil uyumlu)

## 💰 Affiliate Link Dönüştürme

Admin panelinde fırsat onaylarken veya düzenlerken, gelen linkleri otomatik olarak kendi affiliate linklerinize dönüştürebilirsiniz.

### Yapılandırma

1. `config.js` dosyasını açın
2. `affiliateConfig` objesine kendi affiliate ID'lerinizi ekleyin:

```javascript
const affiliateConfig = {
    trendyol: {
        boutiqueId: '123456', // Trendyol Boutique ID'niz
    },
    hepsiburada: {
        utmSource: 'affiliate123', // Hepsiburada UTM Source ID'niz
    },
    n11: {
        refId: 'affiliate789', // N11 Referans ID'niz
    },
    amazon: {
        tag: 'yourstore-21', // Amazon Associate Tag'iniz
    },
    gittigidiyor: {
        affiliateId: 'partner456', // GittiGidiyor Affiliate ID'niz
    }
};
```

### Kullanım

1. **Otomatik Dönüştürme**: Fırsatı onayladığınızda, eğer affiliate ID yapılandırılmışsa link otomatik olarak dönüştürülür.

2. **Manuel Dönüştürme**: 
   - Fırsat detay modalını açın
   - "Affiliate Link'e Dönüştür" butonuna tıklayın
   - Link otomatik olarak dönüştürülecektir

### Desteklenen Siteler

- ✅ Trendyol (boutiqueId parametresi)
- ✅ Hepsiburada (utm_source parametresi)
- ✅ N11 (ref parametresi)
- ✅ Amazon (tag parametresi)
- ✅ GittiGidiyor (affiliateId parametresi)

## 🎨 Tasarım

- Modern ve kullanıcı dostu arayüz
- Gradient arka plan
- Kart tabanlı deal görünümü
- Modal ile detay görüntüleme
- Responsive (mobil, tablet, desktop)

## 📝 Notlar

- Mobil uygulamaya **dokunulmadı**, sadece web admin paneli eklendi
- Firebase Authentication ve Firestore kullanılıyor
- Tüm işlemler gerçek zamanlı Firestore üzerinden yapılıyor




