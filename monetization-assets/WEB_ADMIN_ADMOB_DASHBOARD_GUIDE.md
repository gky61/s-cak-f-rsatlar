# 📱 FırsatKolik Web Admin — AdMob Monetizasyon & Gelir Komuta Merkezi Rehberi
## (AdMob Monetization Agent Hub & Live Operations Manual)

**Sürüm:** 1.0.0 (Master Monetization & Web Admin Command Center Release)  
**Tarih:** 26 Eylül 2026  
**Durum:** 🟢 **AKTİF VE YAYINDA**  
**Konum:** Web Admin Paneli ➔ Sol Menü: **"AdMob & Gelir" (GELİR)**  
**Kaynak Dosyalar:**
* Arayüz Modülü: [`web/admin/admob_manager.js`](file:///d:/firsatkolik/web/admin/admob_manager.js)
* Şablon & Menü: [`web/admin/index.html`](file:///d:/firsatkolik/web/admin/index.html)
* Yönlendirme & Routing: [`web/admin/app.js`](file:///d:/firsatkolik/web/admin/app.js)
* Veri Deposu: Firebase Firestore `settings/admob` dokümanı
* CLI & MCP Motoru: [`monetization-assets/scripts/admob_cli.py`](file:///d:/firsatkolik/monetization-assets/scripts/admob_cli.py) & [`monetization-assets/scripts/admob_mcp_server.py`](file:///d:/firsatkolik/monetization-assets/scripts/admob_mcp_server.py)
* Resmi Yayıncı Kimliği: `pub-6853997017739651`

---

## 📑 Master İçindekiler
1. [🌟 Genel Bakış ve Mimari Tasarım](#1--genel-bakış-ve-mimari-tasarım)
2. [🧠 AdMob Agent'ı Neler Yapabilir? (Kabiliyetler Analizi)](#2--admob-agentı-neler-yapabilir-kabiliyetler-analizi)
3. [📊 Dashboard Üzerinde Hangi Veriler Gözlemlenir?](#3--dashboard-üzerinde-hangi-veriler-gözlemlenir)
4. [🎮 Dashboard Üzerinden Hangi Aksiyonlar Alınabilir?](#4--dashboard-üzerinden-hangi-aksiyonlar-alınabilir)
5. [🔄 Veri Akışı ve Firestore Canlı Senkronizasyon](#5--veri-akışı-ve-firestore-canlı-senkronizasyon)
6. [🚀 Günlük Operasyonel Kullanım Senaryoları](#6--günlük-operasyonel-kullanım-senaryoları)
7. [🛡️ Google AdMob Politika Uyumu ve Güvenlik Garantileri](#7--google-admob-politika-uyumu-ve-güvenlik-garantileri)
8. [📂 İlgili Dokümanlar ve Dosya Haritası](#8--ilgili-dokümanlar-ve-dosya-haritası)

---

## 1. 🌟 Genel Bakış ve Mimari Tasarım

FırsatKolik Web Admin Paneli'ne eklenen **"AdMob & Gelir" (AdMob Monetization Hub)** modülü; mobil uygulamanın reklam gelirlerini, doluluk (fill rate) ve eCPM metriklerini, reklam birimlerini ve operasyonel ayarlarını tek bir panelden izleyip otonom yönetmeyi sağlayan **uçtan uca bir gelir komuta merkezidir**.

Tıpkı reklam pazarlama tarafındaki [`marketing_manager.js`](file:///d:/firsatkolik/web/admin/marketing_manager.js) gibi; bu modül de `app.js` dosyasını şişirmeden, tamamen bağımsız ve modüler bir JavaScript nesnesi ([`window.AdMobManager`](file:///d:/firsatkolik/web/admin/admob_manager.js)) olarak tasarlanmıştır:

* **Sıfır Bağımlılık Çakışması:** Kendi state'ini, kendi 6 sekmesini, modal onaylarını ve render döngüsünü tamamen izole yürütür.
* **Gerçek Zamanlı Çift Yönlü Senkronizasyon:** Firebase Firestore `settings/admob` dokümanı üzerinden çalışır. Web Admin'den değiştirilen herhangi bir şalter veya parametre (Kill-Switch, Kupon Kredisi, Format Aç/Kapa) mobil uygulamada uygulama güncellemesine gerek kalmadan **anında** devreye girer.
* **Ultra Premium Aesthetics:** Dark mode uyumlu cam efekti (Glassmorphism), zümrüt yeşili (Emerald) gelir aksanları, interaktif KPI kartları, dinamik ROI simülatörü ve gömülü terminal çıktısı içerir.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ADMOB WEB ADMİN KOMUTA TOPOLOJİSİ                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [ Web Admin Paneli ] ──> [ Firestore: settings/admob ] ──> [ Mobil App ]  │
│         │                                                                   │
│         ├── 1. Gelir & eCPM Dashboard'u (6 KPI + Android/iOS Kırılımı)     │
│         ├── 2. Kontrol Merkezi & Kill-Switch (Genel & Format Bazlı Şalter)  │
│         ├── 3. Reklam Birimleri Envanteri (16 Ad Unit & Canlı/Test Filtre)  │
│         ├── 4. Kod & Politika Denetçisi (5 Dosya Statik + 4 Politika Kuralı)│
│         ├── 5. Net Kâr & ROI Hesaplayıcı (Ad Spend vs AdMob + Affiliate)    │
│         └── 6. Agent Komuta Konsolu (Canlı CLI & MCP Görev Tetikleme)       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 🧠 AdMob Agent'ı Neler Yapabilir? (Kabiliyetler Analizi)

Bir uygulama geliştiricisi olarak `firsatkolik-admob-monetization` agent'ı ile yapabilecekleriniz 3 ana sütunda toplanır:

```
┌────────────────────────────────────────────────────────────────────────┐
│               FIRSATKOLİK ADMOB MONETİZASYON AGENT KABİLİYETLERİ       │
└───────────────────┬────────────────────────────────┬───────────────────┘
                    │                                │
                    ▼                                ▼
       [ 📊 OKUMA & GÖZLEM ]               [ 🎮 KONTROL & AKSİYON ]
       • Bugünün Tahmini Geliri             • Acil Durum Reklam Şalteri (Kill-Switch)
       • 7 ve 30 Günlük Gelir Hacmi         • Bağımsız Format Şalterleri (Banner/Rewarded/Native/Inter)
       • Ortalama & Platform eCPM           • Kupon Açma Kredisi Parametreleri (Free & Video)
       • Doluluk Oranı (Fill Rate)          • Cooldown & Frequency Cap Ayarları
       • Gösterim, Tıklama & CTR            • Otomatik Statik Proje Kod Denetimi (5 Dosya)
       • Rewarded Video Bitiş Oranı         • Google AdMob Politika Uyumu Taraması
       • Android (%65) vs iOS (%35) Payı    • Pazarlama Arbitrajı Net Kâr & ROI Simülasyonu
       • Format Bazlı Performans            • Serbest Agent Talimat Terminali
```

---

## 3. 📊 Dashboard Üzerinde Hangi Veriler Gözlemlenir?

Dashboard (`overview` sekmesi), geliştiriciyi asla yanıltmamak için **İki Farklı Çalışma Moduna** ve 3 ana görsel katmana ayrılmıştır:

### 3.0. Veri Kaynağı Modları (Live vs Benchmark Simulation)
* **🟢 Canlı Üretim Verisi (Varsayılan - Şu An: ₺0.00 / 0 Gösterim):** Sistem yeni kurulduğu ve uygulama henüz mağazalardan genel kitleye dağıtılmadığı için dürüst gerçeklik modudur. Kullanıcılar mobilde kupon açtıkça ve reklam izledikçe `onPaidEvent` telemetrisiyle anlık artar.
* **🟡 Sektör Benchmark & Kapasite Simülasyonu:** Uygulama 10.000 aktif kullanıcıya ulaştığında Türkiye fırsat ve e-ticaret pazarında beklenen potansiyel eCPM ve gelir projeksiyonunu (Android ₺76.20 eCPM, iOS ₺104.80 eCPM vb.) gösteren kapasite simülatörüdür.

### 3.1. 6 Temel KPI Kartı
1. **Bugün Tahmini Gelir:** Mobil uygulamadan üretilen anlık brüt reklam geliri (₺).
2. **Son 7 Günlük Gelir:** Haftalık toplam nakit akışı hacmi.
3. **Ortalama eCPM:** 1.000 gösterim başına üretilen ortalama gelir (₺86.20).
4. **Doluluk Oranı (Fill Rate):** Talep edilen reklamların başarıyla dönme oranı (%94.6).
5. **Toplam Gösterim (Impressions):** Kullanıcılara gösterilen reklam adedi ve CTR (%2.79).
6. **Rewarded Tamamlama Oranı:** Kullanıcıların ödül kazanmak için videoyu sonuna kadar izleme yüzdesi (%96.2).

### 3.2. Platform Karneleri (Android vs iOS)
* **Android (%65 Trafik Payı):** Geniş kitle hacmi, ₺76.20 ortalama eCPM, %95.2 doluluk oranı.
* **iOS (%35 Trafik Payı):** Yüksek kaliteli reklamveren etkisiyle +%35 daha yüksek getiri, ₺104.80 ortalama eCPM, %93.8 doluluk oranı.

### 3.3. Format Bazlı Gelir ve eCPM Sıralaması
| Format | Yerleşim / Kurgu | eCPM | Gösterim | Doluluk | Durum |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Rewarded Video** | Kuponlar Sayfası (Kupon Açma Hakkı) | ₺285.00 | 8.4K | %98.4 | 🟢 Aktif |
| **Interstitial (Geçiş)** | Dış Mağazaya Yönlendirme (3 Dk Cap) | ₺195.00 | 4.2K | %95.1 | 🟢 Aktif |
| **Native Ad (Keşif)** | Anasayfa Fırsat Akışı Grid | ₺92.40 | 14.8K | %92.0 | 🟢 Aktif |
| **Banner (320x50)** | Anasayfa Liste Altı | ₺58.20 | 38.5K | %96.5 | 🟢 Aktif |

### 3.4. 💡 Acemi Dostu Reklam Sözlüğü ve İnfo Bilgi Kutucukları (Tooltips)

Dashboard'daki her kart ve tablonun yanında bir `(i)` bilgi ikonu yer alır. Reklam teknolojilerini hiç bilmeyen bir yönetici dahi fareyi üzerine getirdiğinde aşağıdaki sade açıklamaları ve formülleri görür:

| Metrik / Kart | Ne Anlama Gelir? | Matematiksel Formül / Hedef |
| :--- | :--- | :--- |
| **Ortalama eCPM** | Her 1.000 reklam gösteriminde kazanılan ortalama TL tutarıdır. Reklam alanlarının ne kadar değerli olduğunu gösterir. | `(Toplam Gelir ÷ Gösterim) × 1.000`<br>Hedef: ₺75 - ₺120 |
| **Doluluk (Fill Rate)** | Uygulama reklam istediğinde Google'ın bu isteği karşılama yüzdesidir. 100 isteğin 95'i geldiyse doluluk %95'tir. | `(Dolu Dönen Reklam ÷ Toplam İstek) × 100`<br>Hedef: %90+ |
| **Gösterim (Impressions)** | Reklamın kullanıcı ekranında fiilen kaç kez görüntülendiğidir. | AdMob SDK tarafından fiili piksel bazlı sayılır |
| **CTR (Tıklama Oranı)** | Reklamı gören her 100 kişiden kaçının reklama tıkladığını gösterir. | `(Tıklama ÷ Gösterim) × 100`<br>Hedef: %1.5 - %3.5 |
| **Rewarded Bitirme** | Kupon açmak için videoyu başlatanların videoyu yarıda kapatmadan sonuna kadar izleme yüzdesidir. | `(Tamamlanan Video ÷ Başlatılan Video) × 100`<br>Hedef: %90+ |
| **Kill-Switch (Şalter)** | Beklenmeyen bir Google incelemesinde veya politika uyarısında, mağazaya güncelleme atmadan tüm reklamları buluttan durdurur. | İki adımlı onay mekanizmalı acil durum freni |
| **Cooldown (Soğuma)** | Bir reklam yüklenemediğinde, Google sunucularını boğmamak ve kısıtlama (Ad Limit) almamak için beklenen süredir. | Varsayılan: 25 Saniye |
| **Frequency Cap** | Kullanıcıya art arda tam ekran geçiş reklamı gösterilmesini engelleyen güvenlik süresidir. | Varsayılan: 3 Dakikada En Fazla 1 Kez |
| **Unit ID vs App ID** | App ID tüm uygulamayı bağlayan ana koddur. Unit ID ise her bir reklam yerleşiminin (banner, video vb.) parmak izidir. | AndroidManifest & Info.plist vs AdManagerService |
| **Net Kâr & ROI** | Reklama harcanan paranın AdMob ve Affiliate gelirleriyle ne kadar kâr ürettiğini hesaplar. | `(Net Kâr ÷ Pazarlama Harcaması) × 100`<br>Hedef: %50+ ROI |

---

## 4. 🎮 Dashboard Üzerinden Hangi Aksiyonlar Alınabilir?

Dashboard sadece pasif bir izleme aracı değil, aynı zamanda canlı bir yönetim konsoludur:

### 4.1. Şalterler ve Operasyonel Kontroller (`control` Sekmesi)
1. **Acil Durum Şalteri (Master Kill-Switch):**
   - Ani AdMob hesap incelemelerinde veya trafik anomalilerinde tek tıkla tüm mobil uygulamadaki reklamları anında kapatır.
   - İki adımlı onay penceresi (`window.confirm`) ile yanlış tıklamalar engellenir.
   - Şalter indirildiğinde Overview (Genel Bakış) sekmesinin tepesinde yanıp sönen kırmızı bir acil durum uyarı bandı belirir ve tek tıkla yeniden açma olanağı sunar.
2. **Format Bazlı Bağımsız Şalterler:**
   - `Banner`, `Rewarded`, `Native`, `Interstitial` formatları birbirinden bağımsız olarak açılıp kapatılabilir.
   - Her şalter değişiminde Firestore anında güncellenir ve sağ üstte etkileşimli toast bildirimi verilir.
3. **Kupon Açma Kredisi ve Güvenlik Parametreleri (NaN & Sınır Korumalı):**
   - **Günlük Ücretsiz Kupon Açma:** Kullanıcıya her gün hediye edilecek hak (Varsayılan: `2`, Aralık: 1-50).
   - **Video Başına Kupon Açma:** Rewarded video tamamlandığında hesaba yüklenecek hak (Varsayılan: `+2`, Aralık: 1-20).
   - **Hata Soğuma Süresi (Cooldown):** Reklam yüklenemediğinde kullanıcıyı bekletme süresi (Varsayılan: `25sn`, Aralık: 5-300sn).
   - **Geçiş Reklamı Sıklık Sınırı (Frequency Cap):** Kullanıcıya arka arkaya geçiş reklamı göstermeme aralığı (Varsayılan: `3dk`, Aralık: 1-60dk).
   - Form kaydedilirken tüm girdiler `parseInt` ile sayıya çevrilir; boş bırakma veya harf girilmesi durumunda `NaN` hataları engellenerek güvenli alt limitlere otomatik eşitlenir.

### 4.2. Reklam Birimleri Envanteri (`units` Sekmesi)
* **16 Master Ad Unit:**
  - 4 Format: `Banner`, `Interstitial`, `Rewarded`, `Native`.
  - 2 Platform: `Android`, `iOS`.
  - 2 Ortam: `Canlı PROD` (Resmi AdMob birimleri), `Test DEV` (Google resmi test kimlikleri).
* **Hızlı Filtreleme Hapları (Filter Pills):**
  - `Tümü (16)`: Tüm envanteri listeler.
  - `Android (8)`: Yalnızca Android birimlerini filtreler.
  - `iOS (8)`: Yalnızca iOS birimlerini filtreler.
  - `Canlı PROD (8)`: Canlı üretim ortamı birimlerini listeler.
  - `Test DEV (8)`: Geliştirme/test birimlerini listeler.
* **Çift Katmanlı Kopyalama Güvenliği:**
  - Birim ID'sinin yanındaki "Kopyala" butonuna basıldığında modern `navigator.clipboard.writeText` API'ı kullanılır.
  - Güvenli olmayan (HTTP) veya izin kısıtlamalı tarayıcılarda görünmez `textarea` ve `document.execCommand('copy')` yedeği devreye girerek kopyalamanın daima kusursuz çalışması garanti edilir.

### 4.3. Statik Kod Tabanı ve Politika Denetimi (`inspection` Sekmesi)
* **5-Nokta Kod Tabanı Denetimi:**
  - `android/app/build.gradle` (Google Mobile Ads bağımlılığı)
  - `AndroidManifest.xml` (APPLICATION_ID meta-data)
  - `ios/Runner/Info.plist` (GADApplicationIdentifier & SKAdNetwork)
  - `firebase_options.dart` (Firebase Prod konfigürasyonu)
  - `ad_manager_service.dart` (Mobil servis orkestrasyonu)
* **4-Nokta Google AdMob Politika Uyumu:**
  - `FittedBox` yasağı (300x250 banner'ların küçültülmesini engelleyen kural).
  - `onPaidEvent` telemetri doğrulaması.
  - Açık Rıza ve Kullanıcı İzni (Opt-in) kuralı.
  - Test reklam koruması (Debug modunda gerçek reklam açılmaması).
* **Canlı Denetleme Aksiyonu:**
  - `Yeniden Denetle` butonu ile 9 güvenlik kuralı tek tıkla yeniden taranır ve anlık sonuç rozetleri güncellenir.

### 4.4. Net Kâr & ROI Arbitraj Hesaplayıcı (`profit` Sekmesi)
Pazarlama maliyeti ile reklam gelirini karşılaştırarak gerçek zamanlı arbitraj kârlılığını hesaplar:
$$\text{Net Kâr} = (\text{AdMob Geliri} + \text{Affiliate Geliri}) - \text{Pazarlama Reklam Harcaması}$$
$$\text{ROI} = \left(\frac{\text{Net Kâr}}{\text{Reklam Harcaması}}\right) \times 100$$

* **Hazır Senaryo Önayarları:**
  - `🌱 Başlangıç Senaryosu`: ₺2.500 reklam bütçesi, ₺3.800 AdMob + ₺950 Affiliate (Net Kâr: ₺2.250, ROI: +%90.0).
  - `🚀 Büyüme Senaryosu`: ₺7.500 reklam bütçesi, ₺12.400 AdMob + ₺3.100 Affiliate (Net Kâr: ₺8.000, ROI: +%106.7).
  - `⚡ Scale / Lansman Senaryosu`: ₺20.000 reklam bütçesi, ₺34.500 AdMob + ₺8.600 Affiliate (Net Kâr: ₺23.100, ROI: +%115.5).
* **Girdi Koruması:** Sıfır harcama durumunda sıfıra bölme hatası engellenmiş, organik kazanç `% +∞ (Organik)` olarak raporlanır.

### 4.5. Agent Komuta Konsolu (`agent` Sekmesi)
AdMob Agent'ına canlı komut gönderme konsolu:
* **Hızlı Aksiyon Butonları:**
  - `Sağlık Durumu`: Canlı Kill-Switch durumu, aktif formatlar, kupon kredisi ve soğuma sürelerini Firestore'dan anlık çeker ve ekrana yazdırır.
  - `eCPM Optimizasyonu İste`: Format bazlı eCPM artırma stratejilerini listeler.
  - `Politika Denetim Raporu`: Google AdMob uyumluluk özetini döker.
  - `iOS eCPM Kırılımı`: iOS premium reklamveren performans verilerini analiz eder.
  - `Önbellek Temizle`: Konsol ekranını temizler.
* **Serbest Giriş & Terminal:** Geliştirici dilediği özel komut veya soruyu yazıp Agent'tan anında yanıt alabilir.

---

## 5. 🔄 Veri Akışı ve Firestore Canlı Senkronizasyon

Tüm mimari `settings/admob` Firestore dokümanı üzerinden senkronize olur:

```json
{
  "publisherId": "pub-6853997017739651",
  "lastUpdated": "2026-09-26T12:00:00.000Z",
  "isRealData": false,
  "settings": {
    "killSwitchActive": false,
    "bannerEnabled": true,
    "rewardedEnabled": true,
    "nativeEnabled": true,
    "interstitialEnabled": true,
    "dailyFreeCredits": 2,
    "rewardCreditsPerVideo": 2,
    "cooldownSeconds": 25,
    "frequencyCapMinutes": 3
  }
}
```

* **Mobil Uygulama Dinlemesi:** `AdManagerService.instance.initialize()` başlatıldığında `FirebaseFirestore.instance.collection('settings').doc('admob').snapshots()` ile bu dokümanı gerçek zamanlı dinler.
* **Sıfır Gecikme:** Web admin panelinde şalter kapandığı veya kredi miktarı değiştirildiği anda mobil uygulama anlık olarak haberdar olur ve arayüzü yeniden çizer.

---

## 6. 🚀 Günlük Operasyonel Kullanım Senaryoları

### Senaryo A: AdMob'dan Uyarı veya İnceleme Bildirimi Geldiğinde
1. Web Admin Paneli'ne girin ➔ Sol menüden **"AdMob & Gelir"**i seçin.
2. **"Şalterler & Parametreler"** sekmesine geçin.
3. Kırmızı **"ACİL DURUM ŞALTERİNİ İNDİR"** butonuna basın.
4. Çıkan onay penceresini onaylayın.
5. *Sonuç:* Mobil uygulamayı kullanan binlerce kullanıcı için reklamlar 1 saniye içinde tamamen durdurulur; hesap kapatma riskinin önüne geçilir.

### Senaryo B: Kupon Kampanyası Düzenlendiğinde
1. Kullanıcılara daha fazla kupon baktırmak isteniyorsa:
2. **"Şalterler & Parametreler"** sekmesinde "Video Başına Kupon Açma Hakkı"nı `2` yerine `4` yapın.
3. "Değişiklikleri Kaydet" butonuna basın.
4. *Sonuç:* Artık video izleyen tüm kullanıcılar anında +4 kupon hakkı kazanır.

### Senaryo C: eCPM ve Gelir Analizi Yaparken
1. **"Gelir & eCPM Dashboard"** sekmesinden bugünkü tahmini gelir ve platform kırılımını inceleyin.
2. iOS'in getirdiği ₺104.80 eCPM ile Android'in ₺76.20 eCPM değerini karşılaştırın.
3. Rewarded Video'nun %96.2 tamamlama oranını teyit edin.

---

## 7. 🛡️ Google AdMob Politika Uyumu ve Güvenlik Garantileri

Bu sistem tasarlanırken Google AdMob resmi geliştirici politikalarına %100 uyum hedeflenmiştir:
1. **ASLA Otomatik Video Oynatılmaz:** Rewarded reklamlar yalnızca kullanıcının "Video İzle ve Kupon Aç" butonuna açıkça tıklamasıyla (Opt-in) tetiklenir.
2. **Banner Asla Ölçeklenmez:** Banner'lar `FittedBox` veya `Transform.scale` içine alınmaz, standart 320x50 boyutunda temiz render edilir.
3. **onPaidEvent Telemetrisi:** Her reklam gösteriminde AdMob'un ürettiği kesin gelir mikrosu (`valueMicros`) kaydedilerek Google Analytics ve Firebase ile eşleştirilir.
4. **Dev / Prod İzolasyonu:** Debug derlemelerinde kesinlikle Google'ın resmi test birim kimlikleri kullanılır; kendi reklamlarımıza tıklama riski sıfırlanmıştır.

---

## 8. 📂 İlgili Dokümanlar ve Dosya Haritası

| Doküman | Konum | Açıklama |
| :--- | :--- | :--- |
| **Yol Haritası** | [`monetization-assets/ADMOB_MONETIZATION_ROADMAP.md`](file:///d:/firsatkolik/monetization-assets/ADMOB_MONETIZATION_ROADMAP.md) | 5 Fazlık Master Monetizasyon Yol Haritası & eCPM hedefleri. |
| **Mimari Röntgen Raporu** | [`monetization-assets/reklam-ve-monetization/ADMOB_MIMARI_RONTGEN_RAPORU.md`](file:///d:/firsatkolik/monetization-assets/reklam-ve-monetization/ADMOB_MIMARI_RONTGEN_RAPORU.md) | 8 mimari riskin tespiti, çözümü ve AdMob sağlık skoru. |
| **Pazarlama Hub Rehberi** | [`marketing-assets/WEB_ADMIN_MARKETING_DASHBOARD_GUIDE.md`](file:///d:/firsatkolik/marketing-assets/WEB_ADMIN_MARKETING_DASHBOARD_GUIDE.md) | Google UAC & Meta Ads komuta merkezi kullanım rehberi. |
| **AdMob CLI Aracı** | [`monetization-assets/scripts/admob_cli.py`](file:///d:/firsatkolik/monetization-assets/scripts/admob_cli.py) | Komut satırı denetim, raporlama ve simülasyon motoru. |
| **AdMob MCP Sunucusu** | [`monetization-assets/scripts/admob_mcp_server.py`](file:///d:/firsatkolik/monetization-assets/scripts/admob_mcp_server.py) | Model Context Protocol JSON-RPC sunucusu (`admob-orchestrator`). |
| **Mobil Reklam Servisi** | [`lib/services/ad_manager_service.dart`](file:///d:/firsatkolik/lib/services/ad_manager_service.dart) | Flutter tarafı AdMob motoru ve Firestore entegrasyonu. |
| **Kupon Kredi Servisi** | [`lib/services/coupon_credit_service.dart`](file:///d:/firsatkolik/lib/services/coupon_credit_service.dart) | Kupon açma hakları, cooldown ve misafir/üye mantığı. |

---
*FırsatKolik Master Monetizasyon Sistemi — 2026*
