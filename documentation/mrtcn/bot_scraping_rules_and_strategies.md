# FırsatKolik Cloud Run Telegram Bot Scraping Kuralları ve Stratejileri

Bu belge, Google Cloud Run üzerinde çalışan Telegram Bot servisinin (`cloud-run-bot`) entegre e-ticaret mağazalarından ürün bilgilerini çekerken kullandığı scraping mimarisini, bypass stratejilerini ve teknik çözüm yollarını detaylıca açıklamaktadır.

---

## 🏗️ Genel Sunucu Taraflı Scraping Mimarisi ve Karar Ağacı

Bulut ortamında (Cloud Run - us-central1) istek atarken en büyük zorluk, Cloudflare/Akamai bot korumalarının veri merkezi IP aralıklarını ve programatik TLS kütüphanelerini doğrudan engellemesidir. Sunucudaki istek akışı bu engelleri aşmak için özel olarak tasarlanmıştır:

```mermaid
graph TD
    A[Telegram Mesajından Link Alınır] --> B[link_scraper_service: resolveUrlRedirects]
    B --> C{Kısaltılmış / Yönlendirmeli Link mi?}
    C -- Evet --> D[Redirect Takip Edilerek Hedef Link Çözülür]
    C -- Hayır --> E[Hedef Domain Analiz Edilir]
    D --> E
    E --> F{Hangi Bypass Yöntemi Tanımlı?}
    
    F -->|Google Translate Proxy| G[URL *.translate.goog Formatına Çevrilir]
    F -->|Googlebot UA| H[Doğrudan İstek + Googlebot/2.1 UA]
    F -->|curl spawnSync| I[Sistem curl Komutu + WhatsApp UA]
    F -->|Standart Fetch| J[Doğrudan İstek + WhatsApp/Tarayıcı UA]
    
    G --> K[fetchHtml Çalıştırılır]
    H --> K
    I --> K
    J --> K
    
    K --> L{Cevap Durumu OK mi?}
    L -- Evet --> M[Cheerio DOM Yükleme & Scraper Eşleştirme]
    L -- Hayır (403/401) --> N[Alternatif UA / Fallback Mekanizmaları]
    
    M --> O[Ürün Verileri (Fiyat, Görsel, Başlık, Kategori) Parse Edilir]
    O --> P[Firestore Veritabanına Kaydetme]
```

---

## 🏪 Bot Tarafı Mağaza Bypass Stratejileri ve Çözüm Yolları

Sunucu ortamındaki bot korumalarını aşmak için geliştirilen 5 temel bypass stratejisi ve bunların mağaza eşleşmeleri:

### 1. Google Translate Proxy (`translate.goog`)
*   **Kullanıldığı Mağazalar:** `N11`, `Vatan Bilgisayar`, `Itopya`
*   **Problem:** Bu mağazalar Google Cloud bulut IP adreslerini (veri merkezleri) doğrudan engeller ve Cloudflare/WAF koruması ile `403 Forbidden` döndürür.
*   **Çözüm:** İstekler `https://www-domain-com.translate.goog/path?_x_tr_sl=auto&_x_tr_tl=tr` formatına dönüştürülerek gönderilir. Google Translate sunucuları, Cloudflare/Akamai sistemlerinde beyaz listede olduğu için istek meşru bir arama motoru IP'sinden geliyormuş gibi görünür ve 403 engeli aşılır.
*   **Kritik Detay (Tracking Temizleme):** 
    *   **N11:** Sadece mağaza bazlı indirimlerin doğru hesaplanması için `magaza` parametresi korunur.
    *   **Itopya:** URL üzerindeki takip veya yönlendirme parametreleri temizlenerek doğrudan temiz ürün detayı proxy ile çekilir.

### 2. `curl` spawnSync ile Doğrudan Erişim (TLS/JA3/Geo-Redirect Bypass)
*   **Kullanıldığı Mağazalar:** `Trendyol`, `Teknosa`, `Mavi`, `Hepsiburada`
*   **Problem:** 
    *   **Teknosa & Mavi:** Bu mağazalar Google Cloud IP bloklarını engellemez; ancak Node.js (`fetch`/`undici`) kütüphanesinin SSL el sıkışması (TLS Handshake JA3/JA4 parmak izi) imzasını "şüpheli bot" olarak algılayıp `403 Forbidden` (Cloudflare WAF Challenge) döndürür.
    *   **Hepsiburada:** Hepsiburada'nın Akamai Bot Manager koruması, Google Translate Proxy sunucu IP'lerini (ve Googlebot IP'lerini) Captcha sayfasına (`HBBlockandCaptcha.html`) yönlendirir (403 WAF engeli, ~80KB HTML boyutu ama ürün bilgileri ve reduxStore bulunmaz). Ayrıca Microlink API'sinin ücretsiz sürümü Hepsiburada'yı engellemiştir (`EPROXYNEEDED` hatası döner).
    *   **Trendyol:** Yurt dışı (Iowa/Iowa-Central1 Cloud Run) IP'lerinden gelen direct istekleri otomatik olarak `/en/select-country?cb=...` (ülke seçimi) sayfasına yönlendirerek orijinal ürün detay sayfasını engeller (74KB anasayfa HTML'i döner). Google Translate Proxy ile gidildiğinde ise, Translate sunucuları yurt dışında olduğu için Trendyol local butik/sepet indirimlerini (`boutiqueId`) render etmeyip standart/indirimsiz global fiyatları (`65374 TL` yerine `63299 TL`) gösterir.
*   **Çözüm:** 
    *   **Teknosa, Mavi & Hepsiburada:** İşletim sistemi düzeyinde çalışan `curl` aracı, Node.js'ten tamamen farklı bir TLS stack'i (libcurl/OpenSSL) kullanır. `spawnSync('curl', [...args])` yardımıyla istek doğrudan `WhatsApp/2.23.4.15 A` User-Agent'ı ile atılarak hem TLS engelleri hem de Google Translate IP engelleri aşılır. Hepsiburada doğrudan 200 OK ile orijinal DOM ve `reduxStore` verilerini (~1MB HTML boyutu) eksiksiz döndürür.
    *   **Trendyol:** İstek doğrudan `curl` ile atılırken, header'lara **`Cookie: storefrontId=1; countryCode=TR; language=tr`** çerezleri eklenir. Bu çerezler sayesinde Trendyol yurt dışı IP yönlendirmesini (`select-country`) tamamen atlar, botu Türkiye lokasyonlu bir kullanıcı gibi algılar ve orijinal ürün sayfasını (425KB+) butik kampanya indirimli fiyatıyla beraber kusursuzca render eder. Linklerdeki affiliate/kampanya parametreleri temizlenmezse, Trendyol JSON-LD şemasını HTML içerisinden kaldırdığı için sadece `boutiqueId`, `merchantId` ve `storefrontId` parametreleri korunur, gerisi silinir.
*   **Gereksinim:** Docker imajında (`Dockerfile`) `apk add --no-cache curl` komutuyla curl yüklü olmalıdır.

### 3. Googlebot User-Agent Taklidi
*   **Kullanıldığı Mağazalar:** `MediaMarkt`
*   **Problem:** MediaMarkt Cloudflare koruması normal tarayıcı ve mobil UA'leri engeller.
*   **Çözüm:** `Googlebot/2.1 (+http://www.google.com/bot.html)` User-Agent değeri doğrudan set edilerek istek atılır. MediaMarkt'ın Cloudflare ayarlarında Googlebot IP doğrulaması (DNS lookup) aktif veya sıkı olmadığı için bu imza doğrudan geçiş izni alır.

### 4. Alan Adı Filtreleme İyileştirmesi (Domain Filtering)
*   **Kullanıldığı Mağazalar:** `Idefix` (ve genel x.com yönlendirmeleri)
*   **Problem:** Botun x.com (Twitter) paylaşımlarını filtrelerken kullandığı basit `.includes('x.com')` kontrolü, `idefix.com` linklerinin de yanlışlıkla filtrelenip atlanmasına neden oluyordu.
*   **Çözüm:** `telegram_bot.js` ve `fetch_history.js` dosyalarındaki kontrol mekanizması URL Hostname analizine dönüştürülerek çözüldü.
    Bu sayede Idefix linklerinin bot tarafından filtrelenmeden başarıyla işlenmesi sağlandı.

### 5. Microlink HTML API Proxy (`api.microlink.io`)
*   **Kullanıldığı Mağazalar:** `Amazon`, `Pttavm`
*   **Problem:** 
    *   **Pttavm:** Pttavm'nin Cloudflare yapılandırması hem Node.js `fetch` hem de `curl` isteklerini Google Cloud IP ranges'ten atıldığında tamamen `403 Forbidden` ile engeller. Google Translate Proxy'leri de engellidir. Ayrıca bazı popüler/yüksek fiyatlı ürün sayfalarında statik proxy istekleri de doğrudan engellenmekte ve 25KB boyutlu Cloudflare WAF block/challenge sayfasına yönlendirilmektedir.
    *   **Amazon:** Amazon, ABD tabanlı bulut IP adreslerinden (`Iowa / us-central1`) yapılan isteklerde varsayılan teslimat konumunu United States (US) olarak ayarlar. Bu co-location (teslimat konumu) kısıtlaması nedeniyle Amazon Türkiye satıcısının buybox/promosyonlu fiyatlarını sunucuda gizler, sayfa içerisinden indirimli fiyatları kaldırarak sadece fallback liste fiyatını (`5199 TL` gibi) gösterir. Ayrıca sayfa altındaki "Benzer Ürünler" veya "Sponsorlu Ürünler" karusellerindeki ucuz kılıf/aksesuar fiyatları, asıl ürünün fiyatıymış gibi taranıp hatalı fiyat çekilmesine neden olabilir.
*   **Çözüm:** Ücretsiz ve kaliteli bir proxy/headless browser API'si olan Microlink kullanılarak sayfanın tüm HTML içeriği çekilir. Cloudflare JS challenge'larını veya Amazon konum kısıtlamalarını aşabilmek için `prerender=true` parametresiyle headless Chromium tarayıcısı üzerinden istek gerçekleştirilir. 
    Ayrıca sayfa altındaki karusel fiyatlarının sızmasını önlemek için, fiyat seçicileri sadece ana kolonlar olan `#rightCol` ve `#centerCol` altındaki DOM öğeleriyle sınırlandırılmıştır. Ebeveynlerinde bu ana kolonlar bulunmayan tüm fiyatlar elenir.
    URL formatı:
    `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&prerender=true&data.html.selector=html&data.html.type=html`
    Bu sorgu Microlink'in premium proxy/konut IP havuzu aracılığıyla Cloudflare korumasını aşarak orijinal sayfanın tüm HTML'ini (JSON-LD şemaları dahil) JSON içerisinde döndürür. Bot, bu HTML verisini Cheerio ile yükleyerek var olan `AmazonScraper` ve `PttavmScraper` sınıfları yardımıyla sorunsuzca parse eder.


---

## 📊 Mağaza ve Bypass Yöntemi Özet Tablosu

| Mağaza | Bot Karşılaşma Durumu | Kullanılan Bypass Yöntemi | Teknik Detay / Başlık |
| :--- | :--- | :--- | :--- |
| **Hepsiburada** | Akamai Captcha / Microlink Blok | `curl` spawnSync (Doğrudan) | TLS Fingerprint Bypass + `WhatsApp` UA (Google Translate Proxy engellendiği ve Microlink ücretli plan istediği için doğrudan curl ile çekilir) |
| **Trendyol** | Yurt dışı IP & Ülke Engeli | `curl` spawnSync (Doğrudan) | `storefrontId=1; countryCode=TR; language=tr` Cookie Entegrasyonu |
| **N11** | 403 Forbidden (IP Engeli) | Google Translate Proxy | `translate.goog` + `magaza` parametresi koruma |
| **Vatan Bilgisayar** | 403 Forbidden (IP Engeli) | Google Translate Proxy | `translate.goog` |
| **Itopya** | 403 Forbidden (Cloudflare Engeli) | Google Translate Proxy | `translate.goog` (VM ve Direct curl Cloudflare tarafından engellendiği için translate proxy üzerinden Node fetch ile çekilir) |
| **Teknosa** | 403 Forbidden (TLS Engeli) | `curl` spawnSync (Doğrudan) | TLS Fingerprint Bypass + `WhatsApp` UA |
| **Mavi** | 403 Forbidden (TLS Engeli) | `curl` spawnSync (Doğrudan) | TLS Fingerprint Bypass + `WhatsApp` UA |
| **Pttavm** | 403 Forbidden (Tam IP Blok) | **Microlink HTML Proxy** | `api.microlink.io` custom HTML selector |
| **Amazon** | US IP / Teslimat Adresi Engeli | **Microlink HTML Proxy** | Co-location / US adresi bypass ve Türkiye indirimli buybox fiyat çekimi |
| **MediaMarkt** | 403 Forbidden (Bot Engeli) | Googlebot UA (Doğrudan) | `Googlebot/2.1` taklidi |
| **Idefix** | Standart HTML Çekim | Standart Fetch | Regex filtre düzeltmesi (x.com karışıklığı giderildi) |

---

## 💡 Gelecek İçin Altın Kurallar ve Debug Yöntemleri

### 1. Bot Engeli / 403 Durumunun Teşhisi
Eğer bir mağaza 403 dönüyorsa, dönen cevaptaki `server` başlığı ve HTML body kontrol edilmelidir:
*   `server: ESF` (Google) geliyorsa: Google Translate sunucuları engellenmiştir veya Google Translate bizi engelliyordur.
*   `server: cloudflare` veya `server: akamai` geliyorsa: Doğrudan bulut sunucu IP'miz veya TLS parmak izimiz engellenmiştir.

### 2. TLS Engeli vs IP Engeli Test Etme
Yeni bir bot engeli yaşandığında `scratch/` dizini altında test scriptleri oluşturarak sırasıyla test edin:
1. `curl` ile doğrudan gitmeyi test edin (`node scratch/test_curl_quick.js`).
2. Eğer `curl` 200 dönüyorsa, sorun **TLS Fingerprint**'tir. Çözüm: Scraper servisinde o mağazayı `curlFetchHtml` kapsamına alın.
3. Eğer `curl` da 403 dönüyorsa, sorun **IP Engeli**'dir. Çözüm: Google Translate Proxy yöntemini uygulayın.

### 3. Komut Satırı / Shell Güvenliği
Node.js içinden harici araç (`curl`) çağırırken kesinlikle `execSync(commandString, { shell: true })` kullanılmamalıdır. Parametrelerin arasına sızabilecek boşluklar veya özel karakterler zaman aşımına veya güvenlik açıklarına yol açar. Her zaman **`spawnSync('curl', argsArray)`** tercih edilmelidir.
