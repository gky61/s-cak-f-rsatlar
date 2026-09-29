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
   - **DAU / WAU / MAU & Stickiness (Sadakat Skoru):** Günlük, haftalık ve aylık tekil aktif kullanıcı havuzu ile DAU/MAU bağlılık yüzdesini sunar.
   - **Yeni Kullanıcı Edinimi & Odak Süresi:** Son 28 günde gelen ilk açılışlar (`newUsers`) ve oturum başına ortalama aktif odak süresini (`userEngagementDuration / sessions`) gösterir.
   - **Bildirim Dönüşü (FCM) & Viral Paylaşımlar:** Push bildirimlerine dokunma (`notification_interaction`), WhatsApp/Telegram paylaşımları (`deal_shared`) ve sıcak/soğuk oyları (`deal_voted`) ölçer.
   - **En Çok Gezilen Ekranlar (Screen Views):** Son 7 günde kullanıcıların en çok vakit geçirdiği ekranları (`unifiedScreenName`) listeler.
   - **AdMob Reklam Monetizasyonu & CTR:** Gösterilen reklam adedi (`ad_impression` onPaidEvent), tıklama sayısı (`ad_click`) ve reklam tıklama oranını (% CTR) canlı gösterir.
2. **⚡ Altyapı & Kota Sağlığı (Free Tier & Veritabanı):**
   - **Firestore Günlük Okuma Kotası (Bugün - 50.000):** Gece 03:00'te sıfırlanan 24 saatlik okuma kotasıdır; ücretsiz sınırın aşılmamasını sağlar.
   - **Firestore Günlük Yazma Kotası (Bugün - 20.000):** Bot fırsat yazımı ve oy verme kayıtlarıdır; faturaya girmeyi önler.
   - **Storage Bant Genişliği (Bugün - 1 GB):** Katalog ve fırsat fotoğraflarının indirme boyutudur; WebP ile kotayı korur.
   - **Cloud Functions Çağrı Kotası (Bu Ay - 2.000.000):** 26 fonksiyonun aylık 2 milyon ücretsiz çağrı sınırını korur.
   - **GCP Harcama & Bütçe Koruması (Bu Ay):** 0.00 TL Free Tier durumunu ve bütçe alarmlarını denetler.
   - **App Check İstek Doğrulama (Canlı - >= %95):** Sahte bot ve korsan scraping isteklerini kapıda engeller.
3. **🤖 Botlar & Servis Durumu (GCP VM & Telegram MTProto):**
   - **Otonom Telegram Botu Sağlık Durumu (Anlık Sinyal):** 3 kademeli kalp atışı kontrolüdür (<15 dk: 🟢 Online, 15-60 dk: 🟡 Sinyal Gecikmeli, >60 dk: 🔴 Çevrimdışı); botun anlık durumunu ve Node.js Heap RAM kullanımını gösterir.
   - **HTTP Canlılık Probu (Anlık Ping):** Bot sunucusuna anlık ping atarak ağ yanıt hızını (ms) ve uptime'ı test eder.
   - **Oturum Sayaçları (Son Başlatmadan Beri):** Yakalanan ham mesaj (`msgCount`), paylaşılan fırsat (`dealCount`), elenen çift mesaj (`dupCount`), hata sayısı (`errCount`) ve Node.js Heap RAM (MB) telemetrisi.
   - **SSH Müdahale Rehberi:** Bot kilitlendiğinde sunucuda 3 hazır komutla yeniden başlatma sağlar.
4. **🚨 Kararlılık, Hatalar & Konsol Köprüleri (Stability & Bridges):**
   - **Sistem Hataları (Canlı - Son 50 Kayıt):** Mobil ve sunucuda karşılaşılan teknik hataları (`createdAt` sıralı) listeler; çözülmemiş aktif hata sayısını (`unresolved / total`) başlık rozetinde anlık gösterir.
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
| **Canlı Trafik & Aktif Kullanıcılar (Realtime)** | GA4 Realtime Dashboard | [PROD GA4 Realtime](https://analytics.google.com/analytics/web/) | [DEV GA4 Realtime](https://analytics.google.com/analytics/web/#/a374649967p512542954/realtime/overview) | Test cihazı ve canlı aktif kullanıcıları saniyelik izleme |
| **Kullanıcı Olayları & Dönüşümler (Events)** | GA4 Olay Raporları | [PROD GA4 Events](https://analytics.google.com/analytics/web/) | [DEV GA4 Events](https://analytics.google.com/analytics/web/#/a374649967p512542954/reports/events) | Fırsat/Kupon tıklamaları ve dönüşüm analizi |
| **Canlı Test & Debug Akışı (DebugView)** | GA4 DebugView | [PROD GA4 DebugView](https://analytics.google.com/analytics/web/) | [DEV GA4 DebugView](https://analytics.google.com/analytics/web/#/a374649967p512542954/admin/debugview) | Cihaz testlerinde eventleri anlık izlerken |
| **Firebase Analytics Entegrasyon Paneli** | Firebase Integrations | [PROD Integrations](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/settings/integrations) | [DEV Integrations](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/settings/integrations) | Firebase konsoluna GA4 mülkünü bağlayarak gömülü izleme |
| **Çökmeler & Kararlılık** | Firebase Crashlytics | [PROD Crashlytics](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/crashlytics) | [DEV Crashlytics](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/crashlytics) | Yeni sürüm sonrası Crash-free % ve stack trace |
| **Açılış Hızı & Ağ Gecikmesi** | Firebase Performance | [PROD Performance](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/performance) | [DEV Performance](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/performance) | Soğuk açılış, Frozen frame ve API gecikmeleri |
| **Korsan & Sahte İstekler** | Firebase App Check | [PROD App Check](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/appcheck) | [DEV App Check](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/appcheck) | Doğrulanmamış bot/emülatör trafiği tespiti |
| **Cloud Functions Kullanımı** | Firebase Functions | [PROD Functions](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/functions/usage) | [DEV Functions](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/functions/usage) | Çağrı sayısı, bellek aşımı, süre aşımı (timeout) |
| **Firestore Veritabanı Kotaları**| Firebase Firestore | [PROD Firestore](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/firestore/databases/-default-/usage) | [DEV Firestore](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/firestore/databases/-default-/usage) | Günlük 50K okuma / 20K yazma kotaları |
| **Depolama & Resim İndirme** | Firebase Storage | [PROD Storage](https://console.firebase.google.com/project/firsatkolik-prod-e6eae/storage) | [DEV Storage](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/storage) | Günlük 1 GB görsel bant genişliği takibi |
| **Sistem Hataları (Canlı)** | **Web Admin Modül 8** | [PROD Web Admin](https://firsatkolik.app/admin/) | [DEV Web Admin](https://sicak-firsatlar-e6eae.web.app/admin/) | `systemErrors` koleksiyonunu okuma & çözme |
| **Bot Canlılık & Kalp Atışı** | **Web Admin Modül 1** | [PROD Dashboard](https://firsatkolik.app/admin/) | [DEV Dashboard](https://sicak-firsatlar-e6eae.web.app/admin/) | `lastHeartbeat` yeşil/kırmızı canlılık durumu |
| **Sunucu Sağlık Probu** | HTTP Health Endpoint | `http://34.135.181.112:8082/health` | `http://34.135.181.112:8081/health` | Bot konteynerinin HTTP 200 uptime kontrolü |
| **VM CPU/RAM & PM2 Logları** | Compute Engine & SSH | [PROD VM Konsolu](https://console.cloud.google.com/compute/instances?project=firsatkolik-prod-e6eae) | — | `pm2 status` ve `pm2 logs` ile MTProto akışı |
| **Derinlemesine Backend Logları**| GCP Cloud Logging | [PROD Logs Explorer](https://console.cloud.google.com/logs/query?project=firsatkolik-prod-e6eae) | [DEV Logs Explorer](https://console.cloud.google.com/logs/query?project=sicak-firsatlar-e6eae) | Functions `error_logger` ve `functions.logger` |
| **Aylık Fatura ve Bütçe** | GCP Cloud Billing | [PROD Billing Raporu](https://console.cloud.google.com/billing/reports?project=firsatkolik-prod-e6eae) | [DEV Billing Raporu](https://console.cloud.google.com/billing/reports?project=sicak-firsatlar-e6eae) | 0 TL Free Tier koruması & 500 TL alarm eşiği |

---

## 🔑 1.1 GA4 Data API & Servis Hesabı Yetkilendirme Rehberi

Web Admin Modül 11'in Google Analytics 4 (GA4) anlık aktif kullanıcı verilerini (`activeUsers`) sunucu taraflı çekebilmesi için Cloud Function servis hesabının GA4 mülkünde tanımlı olması gerekir:

1. **Google Analytics Paneline Giriş Yapın:** [analytics.google.com](https://analytics.google.com/)
2. Sol alttan **Yönetici (Admin)** çark simgesine tıklayın.
3. Mülk sütunundan ilgili projeyi seçin (DEV: `512542954`).
4. **Mülk Erişimi Yönetimi (Property Access Management)** sekmesine tıklayın ([Doğrudan Link](https://analytics.google.com/analytics/web/#/a374649967p512542954/admin/property-access-management)).
5. Sağ üstteki mavi **"+"** butonuna basarak **Kullanıcı ekle** seçeneğini seçin.
6. **E-posta adresi alanına ekleyin:**
   * DEV Projesi için: `sicak-firsatlar-e6eae@appspot.gserviceaccount.com`
   * PROD Projesi için: `firsatkolik-prod-e6eae@appspot.gserviceaccount.com`
7. **Standart Rol:** **Görüntüleyen (Viewer)** seçin ve **Ekle** butonuna basın.
8. *Sonuç:* `getObservabilityMetrics` Cloud Function'ı saniyeler içinde yetki hatasından çıkarak canlı kullanıcı verilerini web paneline yansıtmaya başlar.

---

## 🔗 1.2 Firebase Konsolunda Neden "Add an app to get started" Görünür ve Nasıl Bağlanır?

- **Kök Neden:** Google Analytics ve Firebase, Google çatısı altında entegre olabilen iki ayrı üründür. Firebase projesi oluşturulurken GA4 mülkü doğrudan bağlanmamışsa veya GA4 mülkü bağımsız oluşturulmuşsa, Firebase Konsolu (`console.firebase.google.com/.../analytics/realtime`) mülk eşleşmesini bilmediği için hoş geldin ("Add an app to get started") ekranına düşer.
- **Canlı Veri Durumu:** Flutter uygulamanızdaki `firebase_analytics` SDK'sı test cihazından verileri doğrudan **GA4 Mülk ID: 512542954**'e iletmektedir. Bu nedenle [GA4 Doğrudan Konsolu](https://analytics.google.com/analytics/web/#/a374649967p512542954/realtime/overview) üzerinde son 30 dakikadaki aktif kullanıcı sayısı (1 Kişi) eksiksiz ve canlı görünmektedir.
- **Firebase Konsolunu da Canlı Yapma (İsteğe Bağlı 1 Dakikalık İşlem):**
  1. [Firebase Entegrasyonlar Sayfasını Açın](https://console.firebase.google.com/project/sicak-firsatlar-e6eae/settings/integrations).
  2. **Google Analytics** kartında **Bağla / Etkinleştir** butonuna tıklayın.
  3. Google Analytics hesabınızı (`374649967`) ve mevcut mülkünüzü (`512542954`) seçin.
  4. **Google Analytics'i Bağla** butonuna basın.
  5. *Sonuç:* Firebase Konsolu Realtime sekmesi de açılır ve GA4 ile birebir senkronize çalışmaya başlar.

---

## 📱 1.3 Android Test Cihazlarında Canlı Olay Hızlandırma (DebugView & Realtime)

Android işletim sisteminde Firebase Analytics, **pil tasarrufu sağlamak için olayları varsayılan olarak cihazda depolar ve yaklaşık 1 saatlik aralıklarla (batch)** sunucuya gönderir. Test cihazınızda bir butona (kupon kopyalama, mağazaya git vb.) bastığınız anda olayın GA4 DebugView ve Realtime ekranına **gecikmesiz (1 saniye içinde)** düşmesi için test cihazınız bağlıyken şu komut çalıştırılır:

```bash
adb shell setprop debug.firebase.analytics.app com.sicakfirsatlar.sicak_firsatlar
adb shell setprop log.tag.FA VERBOSE
adb shell setprop log.tag.FA-SVC VERBOSE
```

* **Etki:** Olaylar kuyruğa alınmadan anında Google Analytics'e iletilir ve GA4 DebugView'de saniyelik film şeridi gibi akar.
* **Kapatmak İçin:** `adb shell setprop debug.firebase.analytics.app .none.`

---

## ⚡ 1.4 Metriklerin Canlılık & Gecikme Matrisi (Canlı vs Gecikmeli Metrikler ve DEV vs PROD Davranışı)

Web Admin Paneli Observability Hub üzerindeki metrikler farklı veri kaynaklarından (GA4 Realtime API, GA4 Standart Raporlama, Firestore, Cloud Functions, VM Heartbeat, Crashlytics, GCP Billing) beslenir. Bu kaynakların doğası gereği canlılık ve gecikme davranışları şu şekildedir:

### 1. DEV vs PROD Karşılaştırması: Davranış Aynı mı Olacak?
* **Google Cloud & Firebase Altyapısı Açısından:** **EVET, tamamen aynıdır.** GA4 Realtime API her iki ortamda da 0-5 sn içinde çalışır, Standart 24s Raporlar her iki ortamda da 24-48 saat gecikmeyle kesinleşir, GCP Billing her iki ortamda da 12-24 saatlik gecikmeyle harcamayı işler.
* **Mobil İstemci Davranışı Açısından:**
  * **PROD Ortamında:** Binlerce aktif kullanıcı gün boyu uygulamayı açıp kapatır, arka plana atar veya gezinir. Firebase SDK cihaz arka plana her alındığında ve tampon bellek dolduğunda paketleri sunucuya iletir. Çok sayıda kullanıcı olduğundan veri akışı **kesintisiz ve canlıdır**.
  * **DEV Ortamında:** Tek bir test cihazı bağlıdır. Cihaz pil tasarrufu için olayları yerel belleğinde (SQLite) bekletir; uygulama arka plana atılmadıkça veya yukarıdaki **ADB debug komutu (`debug.firebase.analytics.app`)** çalıştırılmadıkça verileri sunucuya anında göndermez. Bu sebeple geliştirici "tıkladım ama panele hemen yansımadı" yanılgısına düşebilir. ADB komutu aktifken DEV cihazı da her tıklamayı 1 saniyede fırlatır.
* **Observability Hub Çözümü (Realtime Event Fusion):** Cloud Functions `observability_service.js` motoru, GA4 Standart Raporlarının 24 saatlik gecikmesini bypass etmek için son 30 dakikanın canlı olaylarını (`deal_outbound_click`, `coupon_copied`, `catalog_view`) GA4 Realtime API'den saniyelik okur ve 24 saatlik toplama dinamik olarak ekler!

### 2. Dört Sekmedeki Tüm Metriklerin Canlılık Durumu

| Sekme | Metrik Kartı | Canlılık Durumu | Gecikme Süresi | Açıklama |
| :--- | :--- | :---: | :---: | :--- |
| **1. Trafik & Gelir** | **Anlık Aktif Kullanıcı** | 🟢 **Tam Canlı** | 0 - 5 Saniye | GA4 Realtime API son 30 dakikalık pencereli aktif akışı verir. |
| **1. Trafik & Gelir** | **Mağazaya Git (deal_outbound_click)** | 🟢 **Hibrit Canlı** | 0 - 15 Saniye | Cihazdan çıktığı an Realtime Fusion ile yakalanır; kalıcı rapora 24s'de işlenir. |
| **1. Trafik & Gelir** | **Kupon Kopyalama (coupon_copied)** | 🟢 **Hibrit Canlı** | 0 - 15 Saniye | Anlık kupon kopyalamaları Realtime motoruyla yakalanır. |
| **1. Trafik & Gelir** | **Katalog Görüntüleme (catalog_view)** | 🟢 **Hibrit Canlı** | 0 - 15 Saniye | Gezilen aktüel sayfalar anlık yakalanır. |
| **1. Trafik & Gelir** | **Mağaza Dağılım Çubukları** | 🟢 **Tam Canlı** | Saniyelik | Firestore'daki aktif fırsat ve mağaza dağılımından saniyelik derlenir. |
| **1. Trafik & Gelir** | **Fırsat Dönüşüm Hunisi** | 🟢 **Hibrit Canlı** | Saniyelik | Fırsat detay açılışı ile mağazaya yönlendirme oranını anlık hesaplar. |
| **1. Trafik & Gelir** | **Arama Radarı (search_performed)** | 🟡 **Gecikmeli** | 24 - 48 Saat | Arama kelimeleri Google Analytics tarafından 24-48 saatte raporlanır. |
| **1. Trafik & Gelir** | **DAU (Günlük Aktif Kullanıcı)** | 🟢 **Tam Canlı** | 0 - 5 Saniye | Bugünün tekil aktifleri; GA4 Realtime motoruyla desteklenir. |
| **1. Trafik & Gelir** | **WAU (Haftalık Aktif Kullanıcı)** | 🟡 **Yarı Canlı** | 4 - 8 Saat | Son 7 günün tekil aktif kullanıcı havuzudur. |
| **1. Trafik & Gelir** | **MAU (Aylık Aktif Kullanıcı)** | 🟡 **Yarı Canlı** | 4 - 8 Saat | Son 28 günün tekil aktif kullanıcı havuzudur (Total Reach). |
| **1. Trafik & Gelir** | **Bağlılık (Stickiness Skoru %)** | 🟢 **Hibrit Canlı** | Saniyelik | DAU / MAU sadakat oranını anlık hesaplar (Sektör standardı: %20+). |
| **1. Trafik & Gelir** | **Yeni Kullanıcı Edinimi** | 🟡 **Yarı Canlı** | 4 - 8 Saat | Son 28 gündeki ilk açılış (first_open) sayısıdır; ASO başarısını ölçer. |
| **1. Trafik & Gelir** | **Ortalama Odak Süresi** | 🟡 **Yarı Canlı** | 4 - 8 Saat | Oturum başına aktif etkileşim süresini (dakika/saniye) gösterir. |
| **1. Trafik & Gelir** | **Bildirim Dönüşü (FCM)** | 🟢 **Hibrit Canlı** | 0 - 15 Saniye | Push bildirimlerine dokunma adedidir (`notification_interaction`). |
| **1. Trafik & Gelir** | **Viral Paylaşım & Oylar** | 🟢 **Hibrit Canlı** | 0 - 15 Saniye | WhatsApp/Telegram paylaşımları (`deal_shared`) ve sıcak/soğuk oylarıdır. |
| **1. Trafik & Gelir** | **En Çok Gezilen Ekranlar** | 🟡 **Yarı Canlı** | 4 - 8 Saat | Son 7 günde en çok ziyaret edilen ekranları (`unifiedScreenName`) sıralar. |
| **1. Trafik & Gelir** | **AdMob Reklam Monetizasyonu** | 🟢 **Hibrit Canlı** | 0 - 15 Saniye | Reklam gösterimi (`ad_impression`), tıklaması (`ad_click`) ve CTR oranını (% CTR) gösterir. |
| **2. Altyapı & Kota** | **Firestore Okuma Kotası (50K)** | 🟢 **Tam Canlı** | Saniyelik | Veritabanındaki aktif doküman sayısı anlıktır; konsol grafiği ~1-2s gecikmelidir. |
| **2. Altyapı & Kota** | **Firestore Yazma Kotası (20K)** | 🟢 **Tam Canlı** | Saniyelik | Bot fırsat ve oylama hacminden anlık projeksiyon üretir. |
| **2. Altyapı & Kota** | **Storage Bant Genişliği (1 GB)** | 🟡 **Yarı Canlı** | 12 - 24 Saat | Katalog adetleri anlıktır; indirilen net GB tüketimi 12-24s'de konsola işlenir. |
| **2. Altyapı & Kota** | **Cloud Functions Çağrı (2M)** | 🔴 **Gecikmeli** | 12 - 24 Saat | 26 fonksiyonun toplam çağrı grafiği ve CPU metrikleri GCP'de 12-24s'de işlenir. |
| **2. Altyapı & Kota** | **GCP Harcama & Bütçe (0 TL)** | 🔴 **Gecikmeli** | 12 - 24 Saat | GCP Cloud Billing günde 1 kez mutabakat yapar; harcamalar 12-24s gecikmelidir. |
| **2. Altyapı & Kota** | **App Check Doğrulama Oranı** | 🟢 **Tam Canlı** | 0 - 5 Saniye | Gelen her API isteği Play Integrity ile anlık kriptografik doğrulanır. |
| **3. Botlar & Servis**| **Otonom Bot Kalp Atışı** | 🟢 **Tam Canlı** | < 1 Dakika | VM'deki bot her 60 saniyede bir Firestore'a kalp atışı sinyali basar. |
| **3. Botlar & Servis**| **HTTP Canlılık Probu (/health)** | 🟢 **Tam Canlı** | 50 - 200 ms | Butona tıklandığı an bot konteynerine doğrudan canlı HTTP isteği atılır. |
| **3. Botlar & Servis**| **Bot Sayaçları (Mesaj, Fırsat, Hata)**| 🟢 **Tam Canlı** | < 1 Dakika | Botun RAM'indeki sayaçlar her kalp atışında Firestore ile senkronize olur. |
| **4. Kararlılık** | **Sistem Hataları (systemErrors)** | 🟢 **Tam Canlı** | 0 Saniye | Try-catch ile yakalanan teknik istisnalar anında Firestore'a yazılır. |
| **4. Kararlılık** | **Firebase Crashlytics** | 🟡 **Gecikmeli** | 5 - 15 Dakika | Uygulama çöktüğünde rapor BİR SONRAKİ AÇILIŞTA iletilir; konsola 5-15 dk'da yansır. |
| **4. Kararlılık** | **Firebase Performance** | 🔴 **Gecikmeli** | 24 - 48 Saat | Cold start ve ağ gecikmeleri Google sunucularında 24-48 saatte işlenir. |
| **4. Kararlılık** | **GCP Cloud Logging** | 🟢 **Tam Canlı** | 0 - 2 Saniye | Cloud Functions console logları 2 saniye içinde Cloud Logging'e akar. |
| **4. Kararlılık** | **GCP Bütçe Alarmı (500 TL)** | 🔴 **Gecikmeli** | 12 - 24 Saat | GCP Billing günlük harcama mutabakatıyla tetiklenir. |
| **4. Kararlılık** | **App Check Güvenlik Koruması** | 🟢 **Tam Canlı** | 0 - 5 Saniye | Korsan botlar kapıda anında engellenir. |

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
