# Türkiye E-Ticaret Gelir Ortaklığı (Affiliate / Paylaş Kazan) Saha Araştırması ve Uygulanabilirlik Raporu

> [!NOTE]
> Bu rapor; FırsatKolik'te **Amazon Türkiye (Associates TR)**, **Hepsiburada (LinkGelir / Adjust)** ve **Teknosa (Paylaş Kazan / TUNE HasOffers)** için başarıyla devreye alınan 0 ms algoritmik gelir ortaklığı mimarisinin ardından, platforma entegre edilebilecek **yeni mağazaları, güncel pazar dinamiklerini, ad-tech altyapılarını ve teknik uygulanabilirlik fizibilitesini** detaylandırmak amacıyla hazırlanmıştır.

---

## 📑 İçindekiler
1. [🎯 1. Yönetici Özeti ve Araştırmanın Amacı](#1--yönetici-özeti-ve-araştırmanın-amacı)
2. [🏛️ 2. FırsatKolik Mimari Filtresi (Değerlendirme Kriterleri)](#2-️-fırsatkolik-mimari-filtresi-değerlendirme-kriterleri)
3. [🔬 3. Detaylı Mağaza Analizleri ve Saha Bulguları](#3--detaylı-mağaza-analizleri-ve-saha-bulguları)
   - [3.1. Dev Pazaryerleri: Trendyol, N11, Pazarama, Çiçeksepeti](#31-dev-pazaryerleri-trendyol-n11-pazarama-çiçeksepeti)
   - [3.2. Teknoloji & Donanım: İncehesap, MediaMarkt, Vatan, İtopya](#32-teknoloji--donanım-incehesap-mediamarkt-vatan-itopya)
   - [3.3. Moda & Yaşam: Boyner, Beymen, DeFacto, LC Waikiki](#33-moda--yaşam-boyner-beymen-defacto-lc-waikiki)
   - [3.4. Kültür & Kitap: D&R, İdefix](#34-kültür--kitap-dr-idefix)
   - [3.5. Global Pazarlar: Temu, AliExpress](#35-global-pazarlar-temu-aliexpress)
   - [3.6. Çoklu Ağlar: Fenomio, Winfluenced, Optimise Media, Admitad](#36-çoklu-ağlar-fenomio-winfluenced-optimise-media-admitad)
4. [📊 4. Büyük Karşılaştırma Matrisi](#4--büyük-karşılaştırma-matrisi)
5. [🚀 5. FırsatKolik İçin Önceliklendirilmiş Yol Haritası (Roadmap)](#5--fırsatkolik-için-önceliklendirilmiş-yol-haritası-roadmap)

---

## 1. 🎯 Yönetici Özeti ve Araştırmanın Amacı

FırsatKolik platformunun sürdürülebilir finansal gelir modeli; kullanıcıların ve Telegram botlarının paylaştığı indirimli ürün linklerini, arka planda **0 ms gecikmeyle, harici API bağımlılığı olmadan ve Cloudflare/WAF engellerine takılmadan** resmi gelir ortaklığı (affiliate) linklerine dönüştürmesine dayanmaktadır.

Bugüne kadar tamamlanan üç öncü sistem:
1. **Amazon Türkiye:** `tag=firsatkolik-21` Associates parametre enjeksiyonu, ASIN ayıklama, anti-hijack ve Android App Links ile doğrudan yerel Amazon App açılışı.
2. **Hepsiburada:** Adjust (`7t4g.adj.st`) Universal Deep-Link sentezleme motoru, `muratcan gokyokus` adgroup enjeksiyonu, `app.hb.biz` WAF bypass çözümlemesi ve `hbapp://` yerel intent açılışı.
3. **Teknosa:** TUNE (HasOffers / `rdr.btrck.com`) deep-link sentezleme motoru, `aff_sub3` düz slash standardı, `shopId` satıcı koruması ve HUD içi 302 arka plan çözümlemesi ile yerel Teknosa uygulaması açılışı.

Bu saha araştırmasının amacı; FırsatKolik'in desteklediği 290+ mağaza arasından **benzer şekilde gelir, puan, nakit komisyon veya hediye çeki kazanılabilecek yeni mağazaları tespit etmek** ve bunların FırsatKolik'in "0 ms Matematiksel Deep-Link / Algoritmik Sentezleme (Yol D)" felsefesine uygunluğunu ortaya koymaktır.

---

## 2. 🏛️ FırsatKolik Mimari Filtresi (Değerlendirme Kriterleri)

Bir mağazanın FırsatKolik gelir ortaklığı mimarisine dahil edilebilmesi için şu 5 altın kriterden geçmesi gerekir:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    FIRSATKOLİK AFFILIATE UYGUNLUK FİLTRESİ                      │
├──────────────────────────────┬──────────────────────────────────────────────────┤
│ Kriter                       │ Kabul Koşulu                                     │
├──────────────────────────────┼──────────────────────────────────────────────────┤
│ 1. 0 ms Algoritmik Üretim    │ Ağ isteği atmadan matematiksel URL sentezi       │
│ 2. WAF & Oturum Bağımsızlığı │ Sunucuda çerez/login tutmadan çalışabilme        │
│ 3. Anti-Hijack Kabiliyeti    │ Başkasına ait referans kodunu tespit edip ezme   │
│ 4. Clean URL Ayrımı          │ Kullanıcıya saf ürün linki, butona affiliate     │
│ 5. Yerel Uygulama Uyumu      │ Deep-link ile doğrudan yerel mobil uygulamaya    │
└──────────────────────────────┴──────────────────────────────────────────────────┘
```

* **Yol A (Sunucu Tarafı API POST):** Çerez ve IP kilitli WAF (Cloudflare/Akamai) nedeniyle sürdürülemez.
* **Yol D (Algoritmik Sentezleme - TUNE/Adjust/Parametrik):** FırsatKolik'in uyguladığı ve sıfır bakım maliyetiyle çalışan altın standart.

---

## 3. 🔬 Detaylı Mağaza Analizleri ve Saha Bulguları

---

### 3.1. Dev Pazaryerleri

#### A. Trendyol (Influencer / Partner) — ⭐⭐⭐⭐ (Çok Yüksek Hacim)
* **Pazar Konumu:** Türkiye'nin işlem hacmi bakımından 1 numaralı e-ticaret platformu.
* **Kullanılan Takip Altyapısı:** **Adjust** mobil attribution altyapısı ve `ty.gl` yönlendirme servisi.
* **Link Mimarisi:**
  * Masaüstü / Doğrudan: `https://www.trendyol.com/...-p-XXXXXX?boutiqueId=...&merchantId=...&adjust_tracker=...`
  * Mobil Kısa Link: `https://ty.gl/xxxxxx`
  * Tıklandığında arka planda Adjust token'ı üzerinden `com.trendyol.trendyolapp` mobil deep-link'ine yönlendirir.
* **Kazanç Modeli:** Satış başına %3 - %15 komisyon (Kategoriye göre değişir: Moda %15, Elektronik %2-3). Ödemeler fatura karşılığı veya ajans üzerinden nakit.
* **FırsatKolik Uygulanabilirlik Analizi:**
  * FırsatKolik'te şu an `TrendyolAffiliateAdapter` taslak olarak `boutiqueId` parametresi eklemektedir. Ancak gerçek komisyon takibi Adjust tracker token'ı ile çalışır.
  * Hepsiburada'da çözdüğümüz Adjust universal deep-link mantığının (`7t4g.adj.st` benzeri) aynısı Trendyol'un Adjust token'ı ile kurulabilir.
  * **Gereksinim:** Trendyol Influencer Programı'na (min. 10.000 takipçi) veya Fenomio / Ajans iş ortaklığına sahip olunması ve resmi tracker token'ının adaptöre tanımlanması gerekir.

#### B. N11 (Fenomio / n11 Gelir Ortaklığı) — ⭐⭐⭐ (Orta-Yüksek)
* **Pazar Konumu:** Getir bünyesinde, özellikle teknoloji, oto aksesuar ve ev yaşamda güçlü pazaryeri.
* **Kullanılan Takip Altyapısı:** **Fenomio** entegrasyonu ve `sl.n11.com` kısa link yönlendiricisi.
* **Link Mimarisi:** Fenomio üzerinden üretilen `https://fnm.al/xxx` veya N11'in `https://sl.n11.com/xxx` linkleri. Tıklandığında ürün sayfasına `utm_source=affiliate&utm_medium=fenomio` ve kampanya parametreleriyle düşer.
* **Kazanç Modeli:** Satış başına komisyon (KDV hariç sepet tutarı üzerinden).
* **FırsatKolik Uygulanabilirlik Analizi:**
  * N11 doğrudan açık bir "tag/parametre" sistemi yerine Fenomio paneli üzerinden benzersiz link üretimini şart koşmaktadır.
  * `LinkPreviewService` ve botumuz `sl.n11.com` linklerini başarıyla çözebilmektedir.
  * FırsatKolik için en temiz yol: Fenomio hesabı üzerinden N11 kampanyasına bağlanmak veya Fenomio deep-link parametrelerini haritalandırmaktır.

#### C. Çiçeksepeti (Çiçeksepeti Extra) — ⭐⭐⭐⭐⭐ (MÜKEMMEL UYUM - ALTIN FIRSAT)
* **Pazar Konumu:** Çiçek dışına taşarak teknoloji, kozmetik, moda ve ev yaşamda devasa bir pazaryeri (Extra) haline geldi.
* **Kullanılan Takip Altyapısı:** **TUNE (HasOffers)** altyapısı! (Tıpkı Teknosa gibi!)
  * Resmi affiliate portali: `partners.lolacicek.com` (HasOffers altyapısı).
* **Bireysel "Paylaş Kazan":** Bireysel kullanıcılar için koleksiyon paylaşımlarından %5 kupon/indirim kazanımı.
* **FırsatKolik Uygulanabilirlik Analizi:**
  * **Teknik Uyum %100:** FırsatKolik'in `TeknosaAffiliateAdapter` için inşa ettiği TUNE HasOffers matematiksel motoru (`rdr.btrck.com` veya `lolacicek` TUNE redirect'i), Çiçeksepeti ile **birebir aynı ad-tech altyapısına** sahiptir!
  * 0 ms sentezleme, UUID enjeksiyonu, kanonik unwrap ve anti-hijack akışı Teknosa ile tamamen aynı mimaride çalıştırılabilir.
  * Çiçeksepeti TUNE affiliate ağ ID'si ve Offer ID'si alındığı anda sisteme 1 günde entegre edilebilir.

#### D. Pazarama (Türkiye İş Bankası) — ⭐⭐⭐ (Gelişmekte Olan)
* **Pazar Konumu:** İş Bankası ekosisteminde hızla büyüyen, MaxiPuan ve Pazarama Puan avantajı sunan pazaryeri.
* **Kullanılan Takip Altyapısı:** Fenomio Influencer Programı.
* **Kazanç Modeli:** Satış başı komisyon ve Pazarama Puan.
* **FırsatKolik Uygulanabilirlik Analizi:** Fenomio paneli üzerinden yönetilmektedir; doğrudan tekil parametrik deep-link henüz halka açık değildir.

---

### 3.2. Teknoloji & Donanım Perakendecileri (FırsatKolik'in En Sıcak Kategorisi)

#### A. İncehesap ("Paylaştıkça Kazan") — ⭐⭐⭐⭐⭐ (EN YÜKSEK ÖNCELİK / 1 NUMARALI ADAY)
* **Pazar Konumu:** Türkiye'nin en popüler bilgisayar donanımı, hazır sistem ve oyuncu ekipmanı mağazalarından biri.
* **Kritik Stratejik Önem:** İncehesap'ın her Cuma akşamı düzenlediği **"Gaming Gecesi"**, DonanımHaber ve FırsatKolik topluluğunda haftanın en çok paylaşılan ve en yüksek satış hacmine ulaşan indirim etkinliğidir!
* **Program Yapısı ("Paylaştıkça Kazan"):**
  * **Takipçi Sınırı YOK:** Influencer olma veya 10.000 takipçi şartı aranmaz. Forum üyeleri ve teknoloji meraklıları doğrudan kabul edilir.
  * **Kişiye Özel Link & Liste:** Panel üzerinden istenen ürün veya liste için takip edilebilir link üretilir.
  * **Nakit Para Çekme:** 10 TL'den itibaren hakediş görünür; 500 TL ve üzeri nakit olarak banka IBAN hesabına çekilebilir!
  * **Kalıcı Takip:** Linklerin süresi dolmaz; aylar sonra yapılan alışverişler dahi komisyon hanesine yazılır.
* **FırsatKolik Uygulanabilirlik Analizi:**
  * FırsatKolik kitlesinin donanım ve oyuncu ekipmanı odaklı olması sebebiyle İncehesap Paylaştıkça Kazan entegrasyonu **en yüksek dönüşüm oranına (conversion rate)** sahip olacaktır.
  * İncehesap linklerinin içerdiği token/parametre yapısı incelenip doğrudan `IncehesapAffiliateAdapter` geliştirilebilir.

#### B. MediaMarkt Türkiye — ⭐⭐⭐ (Orta)
* **Pazar Konumu:** Türkiye tüketici elektroniğinin lider zincir mağazalarından biri.
* **Takip Altyapısı:** Doğrudan kendi açık affiliate programı bulunmamaktadır; affiliate operasyonunu küresel **Optimise Media** ağı üzerinden yürütmektedir.
* **Bireysel Program:** "MediaMarkt CLUB" sadakat programı (puan/kupon kazandırır ancak satış ortaklığı değildir).
* **FırsatKolik Uygulanabilirlik:** Optimise Media yayıncı hesabı açılarak deep-link şablonu oluşturulabilir.

#### C. Vatan Bilgisayar & İtopya — ⚪ (Doğrudan Program Yok)
* **Vatan Bilgisayar:** Bireysel affiliate programı yoktur; yalnızca kurumsal B2B toplu satış hizmeti mevcuttur.
* **İtopya:** Halka açık standart bir gelir ortaklığı programı bulunmamaktadır; birebir anlık sponsorluklarla çalışmaktadır.

---

### 3.3. Moda & Yaşam Perakendecileri

#### A. Boyner & Beymen
* **Boyner:** "Boyner Influencer Programı" Fenomio üzerinden yürütülmektedir. Satış başına komisyon modeli vardır.
* **Beymen:** Açık bir affiliate programı yoktur; özel PR projeleriyle çalışmaktadır.

#### B. DeFacto & LC Waikiki
* **DeFacto:** "Marka Elçisi" ve dönemsel "Paylaş Kazan" kampanyaları mevcuttur. Yurt dışı için FlexOffers ağında listelenmektedir.
* **LC Waikiki:** "Bizim Influencer'ımız Sensin" projesiyle (500+ takipçi) ürün paylaşımı karşılığı indirim kuponu ve hediye çeki sağlamaktadır. Ayrıca "KazanıYORUM" anket ödül sistemi mevcuttur.

---

### 3.4. Kültür, Kitap & Hobi

#### A. D&R (dr.com.tr) — ⭐⭐⭐ (Niş & İstikrarlı)
* **Pazar Konumu:** Kitap, kırtasiye, hobi, plak ve e-kitap alanında Türkiye lideri.
* **Program:** Web sitesinde resmi **"D&R Affiliate Marketing"** başvuru sayfası ve sistemi aktiftir.
* **FırsatKolik Uygulanabilirlik:** Kitap ve hobi fırsatları için sabit referans parametresi ile kolayca entegre edilebilir.

#### B. İdefix
* Turkuvaz Medya bünyesinde pazaryeri satıcı odaklıdır; genel kullanıcılara açık affiliate sistemi bulunmamaktadır.

---

### 3.5. Global / Sınır Ötesi (Cross-Border) Pazaryerleri

#### A. AliExpress (AliExpress Portals) — ⭐⭐⭐⭐ (Global Dev)
* **Altyapı:** Dünyanın en gelişmiş affiliate platformlarından biri (`portals.aliexpress.com`).
* **Avantajları:** Resmi API desteği, anlık deep-link üretimi, 30 günlük çerez süresi, global nakit ödeme.
* **Dikkat Edilmesi Gereken:** Türkiye'deki 30 Euro yurt dışı hızlı kargo gümrük muafiyeti düzenlemesi sebebiyle sipariş hacmi geçmiş yıllara göre düşmüştür; ancak niş elektronik parçalar için popülerliğini korumaktadır.

#### B. Temu (Temu Affiliate Turkey) — ⭐⭐⭐ (Yüksek Komisyon / Riskli Lojistik)
* **Program:** Türkiye'den kayıt kabul eden, %10-%30 arası agresif komisyon ve yeni indirme başına nakit bonus veren resmi affiliate programı mevcuttur.
* **Kısıt:** Türkiye gümrük mevzuatı ve teslimat süreleri yakından izlenmelidir.

---

### 3.6. Çoklu Marka Affiliate Ağları (Agregator Networks)

Türkiye'de onlarca bağımsız e-ticaret markası kendi affiliate altyapısını kurmak yerine aracı ağlarla çalışmaktadır:

1. **Fenomio:** Hepsiburada, N11, Pazarama, Boyner, DeFacto gibi devleri tek çatı altında toplayan Türkiye'nin en popüler influencer affiliate ağıdır.
2. **Winfluenced:** Teknosa'nın resmi altyapı sağlayıcısıdır; TUNE HasOffers altyapısını kullanır.
3. **Optimise Media:** MediaMarkt Türkiye gibi büyük oyuncuların affiliate operasyonlarını yönetir.
4. **Admitad & Awin:** Global ve yerel yüzlerce moda/elektronik markasının CPA kampanyalarını barındırır.

---

## 4. 📊 Büyük Karşılaştırma Matrisi

| Mağaza / Platform | Mevcut Durum | Altyapı / Model | Kazanç Türü | Giriş Şartı (Bariyer) | 0 ms Matematiksel Sentezleme (Yol D) | FırsatKolik Uygunluk Skoru |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Amazon Türkiye** | 🟢 **CANLI / AKTİF** | Associates TR (`tag=`) | Nakit Komisyon (IBAN) | Kolay (Vergi/Şirket şartı yok) | ✅ **Mükemmel (0 ms)** | 🏆 **%100 (Tamamlandı)** |
| **Hepsiburada** | 🟢 **CANLI / AKTİF** | Adjust (`7t4g.adj.st`) | Nakit Komisyon (IBAN) | Influencer / LinkGelir hesabı | ✅ **Mükemmel (0 ms)** | 🏆 **%100 (Tamamlandı)** |
| **Teknosa** | 🟢 **CANLI / AKTİF** | TUNE HasOffers (`btrck`) | Nakit Komisyon (IBAN) | Paylaş Kazan hesabı | ✅ **Mükemmel (0 ms)** | 🏆 **%100 (Tamamlandı)** |
| **İncehesap** | 🟡 **İncelendi (Hazır)** | Paylaştıkça Kazan | Nakit Para (IBAN) | 🟢 **Çok Kolay (Takipçi şartı yok)** | ✅ **Yüksek (Parametrik)** | ⭐⭐⭐⭐⭐ **(%95 - 1. Öncelik)** |
| **Çiçeksepeti** | 🟡 **İncelendi (Hazır)** | **TUNE HasOffers** | Nakit Komisyon / Kupon | Partner Başvurusu | ✅ **Mükemmel (Teknosa ile Aynı)** | ⭐⭐⭐⭐⭐ **(%95 - 1. Öncelik)** |
| **Trendyol** | 🟡 **İncelendi (Hazır)** | Adjust (`ty.gl`) | Nakit Komisyon (Fatura) | 10K Takipçi / Partnerlik | ✅ **Yüksek (HB benzeri Adjust)** | ⭐⭐⭐⭐ **(%90 - 2. Öncelik)** |
| **N11** | 🟡 **İncelendi** | Fenomio / sl.n11.com | Nakit Komisyon | Fenomio Üyeliği | ⚠️ Orta (Fenomio Redirect) | ⭐⭐⭐ **(%75 - 3. Öncelik)** |
| **Pazarama** | 🟡 **İncelendi** | Fenomio / Pazarama Puan | Komisyon / Puan | Fenomio Üyeliği | ⚠️ Orta | ⭐⭐⭐ **(%70 - 4. Öncelik)** |
| **D&R** | 🟡 **İncelendi** | Affiliate Marketing | Nakit / Hediye Çeki | Başvuru Formu | ✅ Yüksek (Parametrik) | ⭐⭐⭐ **(%70 - 4. Öncelik)** |
| **MediaMarkt** | 🟡 **İncelendi** | Optimise Media Ağı | Nakit Komisyon | Optimise Yayıncılığı | ⚠️ Orta (Network Deep-Link) | ⭐⭐⭐ **(%65 - 5. Öncelik)** |
| **LC Waikiki** | 🟡 **İncelendi** | Bizim Influencer'ımız Sensin| İndirim Kuponu / Çek | 500+ Takipçi | ⚠️ Düşük (Kupon odaklı) | ⭐⭐ **(%50)** |
| **Vatan / İtopya** | 🔴 **Program Yok** | — | — | — | ❌ Yok | ⚪ **(%0)** |

---

## 5. 🚀 FırsatKolik İçin Önceliklendirilmiş Yol Haritası (Roadmap)

Saha araştırması verileri ışığında, FırsatKolik'in gelirlerini maksimize edecek ve geliştirme eforunu minimize edecek **en stratejik 3 adım**:

### 🥇 Adım 1: İncehesap ("Paylaştıkça Kazan") Entegrasyonu
* **Neden?**
  1. Takipçi şartı, şirket zorunluluğu veya ağır sözleşme bariyerleri yoktur; forum ve topluluk odaklıdır.
  2. FırsatKolik kullanıcı kitlesi donanım, hazır PC ve oyuncu ekipmanı indirimlerine bayılmaktadır.
  3. Cuma günleri düzenlenen "Gaming Gecesi" haftalık en büyük satış patlamasını yaratır.
  4. Nakit para ödemesi doğrudan banka hesabına yapılmaktadır.
* **Eylem Planı:** İncehesap Paylaştıkça Kazan hesabı açılarak link parametresi çözümlenecek; `IncehesapAffiliateAdapter` inşa edilecektir.

### 🥈 Adım 2: Çiçeksepeti (TUNE HasOffers Mimarisi) Entegrasyonu
* **Neden?**
  1. Çiçeksepeti'nin arka planındaki affiliate motoru, Teknosa'da başarıyla çözdüğümüz dünya devi **TUNE (HasOffers)** altyapısının aynısıdır!
  2. Kod mimarimiz, unwrap mantığımız ve dual-URL yapımız Çiçeksepeti için %100 hazırdır; yeni bir teknoloji öğrenme maliyeti sıfırdır.
  3. Çiçeksepeti Extra; parfüm, küçük ev aletleri, hediye ve teknoloji kategorisinde çok yüksek sepete dönüşüm oranına sahiptir.
* **Eylem Planı:** `CiceksepetiAffiliateAdapter`, Teknosa adaptörü klonlanarak ve TUNE kampanya ID'si girilerek 1 gün içinde tamamlanabilir.

### 🥉 Adım 3: Trendyol (Adjust / Influencer Mimarisi) Entegrasyonu
* **Neden?**
  1. Türkiye'nin en büyük sipariş hacmi Trendyol'dadır.
  2. Hepsiburada için geliştirdiğimiz Adjust deep-link mimarisi Trendyol'un `ty.gl` ve Adjust tracker altyapısıyla neredeyse ikizdir.
* **Eylem Planı:** Onaylı bir Trendyol Partner / Influencer tracker token'ı temin edildiğinde, Hepsiburada Adjust motorumuz revize edilerek `TrendyolAffiliateAdapter` canlıya alınabilir.

---

> [!TIP]
> **Sonuç:** FırsatKolik'in 3 devi (Amazon, Hepsiburada, Teknosa) tamamlanmıştır. Sırada ekosistemi mükemmelleştirecek **İncehesap** ve **Çiçeksepeti** bulunmaktadır!
