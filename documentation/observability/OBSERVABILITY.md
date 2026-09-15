# 👁️‍🗨️ FırsatKolik — Observability & Monitoring Master Portalı

> [!IMPORTANT]
> **Canlı Telemetri, Hata ve Performans Gözlem Merkezi:** Bu portal; mobil istemci (Android/iOS), sunucusuz backend (Cloud Functions), otonom botlar (GCP Free Tier VM) ve Web Admin panelindeki **tüm izlenebilir metriklerin, panellerin ve konsolların merkezi hızlı erişim haritasıdır**.
>
> 📖 **Detaylı Mimari Dokümantasyon ve Kod Sözleşmesi:**  
> 👉 **[documentation/observability/observability_rehberi.md](file:///d:/firsatkolik/documentation/observability/observability_rehberi.md)**

---

## 🖥️ 0. TEK MERKEZİ GÖZLEMLEME ÜSSÜ: Web Admin Modül 11 (Observability HUB)

> [!TIP]
> **Tüm Metrikler Tek Ekranda:** FırsatKolik Web Admin Paneline eklenen **Modül 11 (Observability HUB)** sayesinde yöneticiler artık 15'ten fazla harici Google ve Firebase konsolu arasında kaybolmadan; anlık aktifleri, dönüşüm hunisini, veritabanı kotalarını, bot sağlığını ve sistem hatalarını **tek bir arayüzden** takip edebilir.

### 🔗 Doğrudan Panel Girişleri
* **Canlı Canlı (PROD) Observability HUB:** [firsatkolik.app/admin/](https://firsatkolik.app/admin/) ➔ Menüden **"Observability HUB"**
* **Test / Geliştirme (DEV) Observability HUB:** [sicak-firsatlar-e6eae.web.app/admin/](https://sicak-firsatlar-e6eae.web.app/admin/)

### 🧭 Observability HUB İçerisindeki 4 Ana Sekme:
1. **📊 Canlı Trafik & Gelir Analitiği (GA4 & Dönüşüm):**
   - **Anlık Aktif Kullanıcı (Son 30 Dakika):** Uygulamayı şu an aktif kullanan kişi sayısıdır. Bildirim veya kampanya sonrası anlık ziyaretçi patlamasını doğrulamaya yarar.
   - **Mağazaya Git Tıklaması (Son 24 Saat):** `deal_outbound_click` affiliate yönlendirme adedidir. Platformun komisyon geliri getiren ana ticari gücünü ölçer.
   - **Kupon Kopyalama (Son 24 Saat):** `coupon_copied` adedidir. Kullanıcıların indirim kuponlarına olan talebini ölçer.
   - **Katalog Görüntüleme (Son 24 Saat):** `catalog_view` adedidir. BİM, A101 vb. aktüel broşürlerin okunma trafiğini ölçer.
   - **Mağaza Dağılım Çubukları (Son 24 Saat):** Kullanıcıların en çok hangi mağazaya gitmek istediğini gösterir (Trendyol, Amazon, Hepsiburada vb.).
   - **Fırsat Dönüşüm Hunisi (Son 24 Saat):** Fırsat detayını açanların yüzde kaçının mağazaya git butonuna bastığını ölçer.
   - **Arama & Talep Radarı (Son 24 Saat):** Kullanıcıların arayıp bulamadığı ürünleri bot radarına eklemek için kullanılır.
2. **⚡ Altyapı & Kota Sağlığı (Free Tier & Veritabanı):**
   - **Firestore Günlük Okuma Kotası (Bugün - 50.000):** Gece 03:00'te sıfırlanan 24 saatlik okuma kotasıdır; ücretsiz sınırın aşılmamasını sağlar.
   - **Firestore Günlük Yazma Kotası (Bugün - 20.000):** Bot fırsat yazımı ve oy verme kayıtlarıdır; faturaya girmeyi önler.
   - **Storage Bant Genişliği (Bugün - 1 GB):** Katalog ve fırsat fotoğraflarının indirme boyutudur; WebP ile kotayı korur.
   - **Cloud Functions Çağrı Kotası (Bu Ay - 2.000.000):** 26 fonksiyonun aylık 2 milyon ücretsiz çağrı sınırını korur.
   - **GCP Harcama & Bütçe Koruması (Bu Ay):** 0.00 TL Free Tier durumunu ve bütçe alarmlarını denetler.
   - **App Check İstek Doğrulama (Canlı - >= %95):** Sahte bot ve korsan scraping isteklerini kapıda engeller.
3. **🤖 Botlar & Servis Durumu (GCP VM & Telegram MTProto):**
   - **Otonom Telegram Botu Sağlık Durumu (Anlık Sinyal):** Son 15 dakikalık kalp atışıdır; botun donup donmadığını gösterir.
   - **HTTP Canlılık Probu (Anlık Ping):** Bot sunucusuna anlık ping atarak ağ yanıt hızını (ms) ve uptime'ı test eder.
   - **Oturum Sayaçları (Son Başlatmadan Beri):** Yakalanan ham mesaj (`msgCount`), paylaşılan fırsat (`dealCount`), elenen çift mesaj (`dupCount`) ve hata sayısı (`errCount`).
   - **SSH Müdahale Rehberi:** Bot kilitlendiğinde sunucuda 3 hazır komutla yeniden başlatma sağlar.
4. **🚨 Kararlılık, Hatalar & Konsol Köprüleri (Stability & Bridges):**
   - **Sistem Hataları (Canlı - Son 50 Kayıt):** Mobil ve sunucuda karşılaşılan açık hataları ve çözülme durumunu listeler.
   - **Firebase Crashlytics (Canlı & Sürümler):** Ölümcül çökmeleri izler; hedef %99.5 çökmesiz kullanıcı oranını korumaktır.
   - **Firebase Performance (Canlı Gözlem):** Açılış hızı (<2 sn), donan kareler ve mağaza yönlendirme gecikmelerini denetler.
   - **GCP Cloud Logging (Canlı Loglar):** 26 fonksiyonun ham backend loglarını ve gizli kalan hataları sorgular.
   - **GCP Bütçe Alarmı (Bu Ay):** Beklenmeyen aşımda 250 TL ve 500 TL alarmlarıyla sürpriz faturayı önler.
   - **App Check Doğrulama (Canlı):** Gerçek mobil uygulama trafiğini kriptografik olarak doğrular.

---

## 🌐 1. Harici Konsol ve Dashboard Hızlı Erişim Haritası

| Gözlem Alanı | Konsol / Araç | PROD Doğrudan Bağlantı | DEV Doğrudan Bağlantı | Hangi Durumda Bakılır? |
| :--- | :--- | :--- | :--- | :--- |
| **Observability HUB (Merkezi)** | **Web Admin Modül 11** | [PROD Hub Girişi](https://firsatkolik.app/admin/) | [DEV Hub Girişi](https://sicak-firsatlar-e6eae.web.app/admin/) | **Günlük tüm metriklerin tek ekrandan takibi** |
| **Canlı Trafik & Kullanıcılar** | Firebase Realtime | [PROD Realtime](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/analytics/realtime) | [DEV Realtime](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/analytics/realtime) | Bildirim atıldığında, anlık aktifleri izlerken |
| **Kullanıcı Olayları & Dönüşüm** | Firebase Analytics Events | [PROD Events](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/analytics/events) | [DEV Events](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/analytics/events) | Fırsat/Kupon tıklamaları ve dönüşüm analizi |
| **Canlı Test & Debug Akışı** | Firebase DebugView | [PROD DebugView](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/analytics/debugview) | [DEV DebugView](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/analytics/debugview) | Cihaz testlerinde eventleri saniyelik izlerken |
| **Çökmeler & Kararlılık** | Firebase Crashlytics | [PROD Crashlytics](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/crashlytics) | [DEV Crashlytics](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/crashlytics) | Yeni sürüm sonrası Crash-free % ve stack trace |
| **Açılış Hızı & Ağ Gecikmesi** | Firebase Performance | [PROD Performance](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/performance) | [DEV Performance](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/performance) | Soğuk açılış, Frozen frame ve API gecikmeleri |
| **Korsan & Sahte İstekler** | Firebase App Check | [PROD App Check](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/appcheck) | [DEV App Check](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/appcheck) | Doğrulanmamış bot/emülatör trafiği tespiti |
| **Cloud Functions Kullanımı** | Firebase Functions | [PROD Functions](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/functions/usage) | [DEV Functions](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/functions/usage) | Çağrı sayısı, bellek aşımı, süre aşımı (timeout) |
| **Firestore Veritabanı Kotaları**| Firebase Firestore | [PROD Firestore](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/firestore/databases/-default-/usage) | [DEV Firestore](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/firestore/databases/-default-/usage) | Günlük 50K okuma / 20K yazma kotaları |
| **Depolama & Resim İndirme** | Firebase Storage | [PROD Storage](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/storage/firsatkolik-prod-e6eae.appspot.com/usage) | [DEV Storage](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/storage/sicak-firsatlar-e6eae.appspot.com/usage) | Günlük 1 GB görsel bant genişliği takibi |
| **Sistem Hataları (Canlı)** | **Web Admin Modül 8** | [PROD Web Admin](https://firsatkolik.app/admin/) | [DEV Web Admin](https://sicak-firsatlar-e6eae.web.app/admin/) | `systemErrors` koleksiyonunu okuma & çözme |
| **Bot Canlılık & Kalp Atışı** | **Web Admin Modül 1** | [PROD Dashboard](https://firsatkolik.app/admin/) | [DEV Dashboard](https://sicak-firsatlar-e6eae.web.app/admin/) | `lastHeartbeat` yeşil/kırmızı canlılık durumu |
| **Sunucu Sağlık Probu** | HTTP Health Endpoint | `http://34.135.181.112:8082/health` | `http://34.135.181.112:8081/health` | Bot konteynerinin HTTP 200 uptime kontrolü |
| **VM CPU/RAM & PM2 Logları** | Compute Engine & SSH | [PROD VM Konsolu](https://console.cloud.google.com/compute/instances?project=firsatkolik-prod-e6eae) | — | `pm2 status` ve `pm2 logs` ile MTProto akışı |
| **Derinlemesine Backend Logları**| GCP Cloud Logging | [PROD Logs Explorer](https://console.cloud.google.com/logs/viewer?project=firsatkolik-prod-e6eae) | [DEV Logs Explorer](https://console.cloud.google.com/logs/viewer?project=sicak-firsatlar-e6eae) | Functions `error_logger` ve `functions.logger` |
| **Aylık Fatura ve Bütçe** | GCP Cloud Billing | [GCP Billing Paneli](https://console.cloud.google.com/billing) | — | 0 TL Free Tier koruması & 500 TL alarm eşiği |

---

## 📊 2. Uçtan Uca İzlenen Metrik Grupları Özeti

```
[ FırsatKolik Telemetri & Observability Ekosistemi ]
 ├── 1. Kullanıcı & Büyüme ──► DAU, WAU, MAU, Retention, Realtime, Screen Duration
 ├── 2. Ticari Dönüşüm ──────► deal_outbound_click, deal_view, coupon_copied, catalog_view
 ├── 3. Kararlılık & Hata ───► Crash-Free Users %, Fatal Crashes, Breadcrumbs, systemErrors
 ├── 4. Performans & UI ─────► App Cold Start, Slow Frames, Frozen Frames, store_redirect_latency
 ├── 5. Altyapı & Backend ───► Functions Invocations, Firestore Reads/Writes (50K/20K), Storage Bandwidth
 ├── 6. Botlar & Kazıyıcı ───► lastHeartbeat, /health Uptime, PM2 Restarts, MTProto Telegram Stream
 └── 7. Güvenlik & Bütçe ────► App Check Verified %, GCP Current Spend (0 TL), Budget Alerts
```

---

## 🚦 3. Hızlı Operasyonel Senaryolar

* **☕ Günlük Sabah Rutini (2 Dk):** [Web Admin Observability HUB](https://firsatkolik.app/admin/) açılır. **Sekme 3**'ten Bot Kalp Atışının yeşil olduğu, **Sekme 2**'den Firestore kotalarının güvende olduğu ve **Sekme 4**'ten gece boyu birikmiş kritik bir `systemErrors` kaydı olmadığı saniyeler içinde teyit edilir.
* **🔔 Push Bildirim Atıldığında:** Observability HUB **Sekme 1 (Canlı Trafik & Gelir Analitiği)** açılarak anlık aktif kullanıcı sıçraması ve Mağazaya Git (`deal_outbound_click`) grafiği canlı izlenir.
* **🚀 Yeni Sürüm / OTA Yaması Yayınlandığında:** Observability HUB **Sekme 4 (Kararlılık)** üzerinden tek tıkla Crashlytics'e zıplanarak "Crash-free users" oranının **>= %99.5** olduğu doğrulanır.
* **💰 Ay Ortası Bütçe Kontrolü:** Observability HUB **Sekme 2** ve **Sekme 4** üzerinden Cloud Billing köprüsüne tıklanarak harcamanın **0.00 TL** olduğu teyit edilir.

---

> Detaylı mimari kuralları, tüm kod örnekleri ve olay parametreleri için lütfen **[Observability Master Rehberi](file:///d:/firsatkolik/documentation/observability/observability_rehberi.md)** dosyasını referans alınız.
