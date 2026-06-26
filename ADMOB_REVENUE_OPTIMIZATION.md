# AdMob Gelir Optimizasyonu Rehberi 💰

## 📊 Mevcut Durum

### ✅ Şu An Kullanılanlar
- **Reklam Formatı**: Banner (Medium Rectangle, Large Banner)
- **Reklam Yerleşimi**: Ana sayfa (5-6-5-6-5-6 pattern)
- **Ad Unit ID**: 1 adet (Ana Sayfa Banner)
- **Mediation**: Henüz aktif değil

### 📈 Gelir Potansiyeli
- **Mevcut**: Sadece banner reklamlar
- **Potansiyel**: %200-400 artış mümkün (doğru optimizasyonla)

---

## 🎯 Gelir Artırma Stratejileri (Öncelik Sırasına Göre)

### 1. ⭐⭐⭐ YÜKSEK ÖNCELİK - AdMob Mediation Aktifleştir

**Gelir Artışı**: %50-150

**Neden Önemli?**
- Birden fazla reklam ağından reklam alırsınız
- En yüksek teklifi veren ağ seçilir
- Reklam doldurulabilirliği artar

**Nasıl Yapılır?**
1. AdMob Konsol → Uyumlulaştırma (Mediation)
2. "Reklam kaynağı ekle" butonuna tıklayın
3. Önerilen ağlar:
   - **AppLovin** (yüksek eCPM)
   - **Unity Ads** (iyi performans)
   - **Chartboost** (ek gelir)
   - **AdColony** (ek gelir)

**Beklenen Sonuç:**
- eCPM: %30-80 artış
- Fill Rate: %85-95'e çıkar
- Toplam gelir: %50-150 artış

---

### 2. ⭐⭐⭐ YÜKSEK ÖNCELİK - Farklı Ekranlara Reklam Ekle

**Gelir Artışı**: %100-200

**Mevcut**: Sadece ana sayfa
**Önerilen**: 3-4 farklı ekran

**Yeni Reklam Yerleşimleri:**

#### A. Deal Detay Sayfası (Yüksek Değer)
- **Format**: Banner (sayfanın altında)
- **Gelir Potansiyeli**: Yüksek (kullanıcı ilgili içerikte)
- **Yerleşim**: Yorumların altında, sayfa sonunda

#### B. Profil Sayfası
- **Format**: Banner (sayfanın üstünde veya altında)
- **Gelir Potansiyeli**: Orta
- **Yerleşim**: Profil bilgilerinin altında

#### C. Favoriler Sayfası
- **Format**: Banner (her 5-6 favori item'dan sonra)
- **Gelir Potansiyeli**: Orta-Yüksek

**AdMob Konsolunda Yapılacaklar:**
1. Her ekran için yeni Ad Unit oluşturun
2. Ad Unit ID'lerini kodda kullanın
3. Performansı ayrı ayrı takip edin

**Beklenen Sonuç:**
- Reklam gösterim sayısı: 3-4x artış
- Toplam gelir: %100-200 artış

---

### 3. ⭐⭐ ORTA ÖNCELİK - Native Ads (Yerel Reklamlar)

**Gelir Artışı**: %30-60

**Neden Önemli?**
- Banner'lardan %30-60 daha yüksek eCPM
- Kullanıcı deneyimi daha iyi (doğal görünüm)
- Tıklama oranı (CTR) daha yüksek

**Nasıl Uygulanır?**
- Ana sayfada deal kartları arasına native ad yerleştir
- Deal kartlarına benzer görünüm
- "Reklam" etiketi ile işaretle

**Örnek Yerleşim:**
```
Deal 1
Deal 2
Deal 3
Deal 4
Deal 5
[Native Ad - Deal görünümünde]
Deal 6
Deal 7
...
```

**Beklenen Sonuç:**
- eCPM: %30-60 artış
- CTR: %20-40 artış
- Kullanıcı deneyimi: Daha iyi

---

### 4. ⭐⭐ ORTA ÖNCELİK - Interstitial Ads (Tam Ekran Reklamlar)

**Gelir Artışı**: %50-100

**⚠️ DİKKAT**: Kullanıcı deneyimini bozmadan kullanılmalı!

**Önerilen Yerleşimler:**
1. **Deal detay sayfasından çıkışta** (geri butonuna basıldığında)
   - Kullanıcı içeriği okudu, çıkıyor
   - Rahatsız edici değil

2. **Kategori değiştirirken** (nadiren, her 3-4 değişiklikte bir)
   - Çok sık olmamalı

3. **Uygulamayı açtıktan sonra** (sadece ilk açılışta)
   - Her açılışta değil, günde 1-2 kez

**Nasıl Uygulanır:**
- Pre-loading: Reklamı önceden yükle
- Gösterim: Doğru anlarda göster
- Skip: 5 saniye sonra "Atla" butonu

**Beklenen Sonuç:**
- eCPM: Banner'dan 3-5x daha yüksek
- Gelir: %50-100 artış
- Kullanıcı deneyimi: Dikkatli kullanılırsa kabul edilebilir

---

### 5. ⭐ DÜŞÜK ÖNCELİK - Rewarded Ads (Ödüllü Reklamlar)

**Gelir Artışı**: %20-40

**Ne Zaman Kullanılır?**
- Kullanıcıya değer sağladığında
- Örnek: "Premium özellikler için reklam izle"

**Uygulamanız İçin Örnekler:**
- "5 ekstra favori slot için reklam izle"
- "Özel kategori bildirimleri için reklam izle"
- "Öncelikli deal paylaşımı için reklam izle"

**Beklenen Sonuç:**
- eCPM: Çok yüksek (kullanıcı isteyerek izliyor)
- Gelir: %20-40 artış
- Kullanıcı memnuniyeti: Yüksek (değer alıyor)

---

## 📊 AdMob Konsol Optimizasyonları

### 1. Ad Unit Ayarları

**Her Ad Unit İçin:**
- ✅ **Otomatik yenileme**: Açık (Google optimize eder)
- ✅ **eCPM floor**: Otomatik (Google optimize eder)
- ✅ **Reklam türleri**: Tümünü açık tut
  - Metin reklamlar
  - Resim reklamlar
  - Rich media reklamlar
  - Video reklamlar

### 2. Mediation Ayarları

**Waterfall Stratejisi:**
1. AdMob (ilk öncelik)
2. AppLovin
3. Unity Ads
4. Chartboost
5. AdColony

**eCPM Floor Ayarları:**
- Başlangıç: Otomatik (Google optimize eder)
- 1-2 hafta sonra: Performansa göre ayarla
- Hedef: %80-90 fill rate

### 3. Blocking Controls (Engelleme Kontrolleri)

**Yapılacaklar:**
- Uygunsuz kategorileri engelle
- Hassas kategorileri kontrol et
- Spam reklamları engelle

**Neden Önemli?**
- Kullanıcı deneyimi korunur
- Uzun vadede daha iyi performans

---

## 📈 Performans Takibi

### Önemli Metrikler

1. **eCPM (Effective Cost Per Mille)**
   - Hedef: $1-5 (ülkeye göre değişir)
   - Takip: Günlük/haftalık

2. **Fill Rate (Doldurulabilirlik Oranı)**
   - Hedef: > %80
   - Düşükse: Mediation ekle, ad unit sayısını artır

3. **CTR (Click-Through Rate)**
   - Hedef: %0.5-2
   - Yüksekse: Reklam yerleşimi iyi
   - Düşükse: Yerleşimi optimize et

4. **Ad Request (Reklam İsteği)**
   - Hedef: Mümkün olduğunca çok
   - Daha fazla istek = daha fazla gelir

### Raporlama

**Günlük Takip:**
- Toplam gelir
- eCPM trendi
- Fill rate

**Haftalık Analiz:**
- Hangi ad unit daha karlı?
- Hangi reklam formatı daha iyi?
- Hangi ekran daha fazla gelir getiriyor?

**Aylık Optimizasyon:**
- Performansı düşük ad unit'leri kaldır
- Yüksek performanslı yerleşimleri artır
- Yeni reklam formatları test et

---

## 🎯 Hızlı Kazanç Stratejisi (1 Hafta İçinde)

### Hafta 1: Temel Optimizasyonlar
1. ✅ Mediation aktifleştir (AppLovin, Unity Ads)
2. ✅ Deal detay sayfasına banner ekle
3. ✅ Profil sayfasına banner ekle
4. ✅ AdMob konsolunda raporları takip et

**Beklenen Sonuç**: %50-100 gelir artışı

### Hafta 2-3: Gelişmiş Optimizasyonlar
1. ✅ Native ads test et
2. ✅ Interstitial ads ekle (dikkatli)
3. ✅ Performans analizi yap
4. ✅ Optimizasyon yap

**Beklenen Sonuç**: %100-200 gelir artışı

### Hafta 4+: Sürekli Optimizasyon
1. ✅ Yeni reklam formatları test et
2. ✅ A/B test yap
3. ✅ Kullanıcı geri bildirimlerini dinle
4. ✅ Sürekli iyileştir

**Beklenen Sonuç**: %200-400 gelir artışı

---

## ⚠️ Dikkat Edilmesi Gerekenler

### 1. Kullanıcı Deneyimi Dengesi
- Reklamlar çok sık olmamalı
- Kullanıcıyı rahatsız etmemeli
- İçerik öncelikli olmalı

### 2. AdMob Politikaları
- Tıklama sahtekarlığı yapmayın
- Reklamları gizlemeyin
- Doğru ad unit ID kullanın

### 3. Performans
- Reklam yükleme süresi < 2 saniye olmalı
- Uygulama performansını etkilememeli
- Bellek kullanımını optimize edin

---

## 📚 Kaynaklar

- [AdMob Best Practices](https://developers.google.com/admob/android/best-practices)
- [AdMob Mediation](https://developers.google.com/admob/android/mediate)
- [AdMob Revenue Optimization](https://support.google.com/admob/answer/2931287)
- [AdMob Policies](https://support.google.com/admob/answer/6128543)

---

## 💡 Sonuç

**En Hızlı Gelir Artışı İçin:**
1. ⭐⭐⭐ Mediation aktifleştir (1 gün)
2. ⭐⭐⭐ Farklı ekranlara reklam ekle (2-3 gün)
3. ⭐⭐ Native ads test et (1 hafta)
4. ⭐⭐ Interstitial ads ekle (1 hafta)

**Beklenen Toplam Gelir Artışı**: %200-400

**Önemli**: Adım adım ilerleyin, performansı takip edin, kullanıcı deneyimini koruyun!



