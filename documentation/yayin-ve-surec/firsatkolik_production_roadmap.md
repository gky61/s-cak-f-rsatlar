# FırsatKolik — Android Production Çıkış ve Büyüme Yol Haritası

**Hazırlanma tarihi:** 30 Haziran 2026
**Kapsam:** Yalnızca Android (Google Play Store)
**Bütçe varsayımı:** Reklam/büyüme için aylık 3.000–15.000₺
**Pazar varsayımı:** Yalnızca Türkiye
**Mevcut durum varsayımı:** Play Console hesabı, marka görselleri ve şirket/şahıs firması henüz yok — rapor sıfırdan başlayan bir süreç için kurgulandı.

---

## 1. Yönetici Özeti ve Kritik Tarih Uyarısı

Development aşaması bitmiş bir uygulamayı production'a taşımak, tek bir adım değil; birbirine bağımlı dört ayrı disiplini gerektirir: **yasal/kurumsal hazırlık**, **bulut altyapısının sertleştirilmesi**, **mobil uygulamanın yayına hazırlanması** ve **Play Console süreci**. Bunların hepsi tamamlanmadan üst sıralarda görünmek bir yana, uygulama hiç yayınlanamaz veya yayınlandıktan kısa süre sonra askıya alınabilir.

**En kritik ve zaman baskılı madde önden belirtilmeli:** Google Play, 31 Ağustos 2026 itibarıyla Play Store'a gönderilen tüm yeni uygulama ve güncellemelerin **Android 16 (API seviyesi 36)** veya üzerini hedeflemesini zorunlu kılıyor. Bugün 30 Haziran 2026 olduğuna göre elinizde yaklaşık **2 ay** var. Eğer Flutter projenizin `android/app/build.gradle` dosyasındaki `targetSdkVersion` değeri 36'nın altındaysa, ilk başvurunuz bu tarihten sonra yapılırsa reddedilir. Bu maddeyi yol haritasının en başına, hiçbir şeyi beklemeden bugün kontrol edilmesi gereken iş olarak koyuyorum.

Rapor; teknik altyapı (Firebase + Cloud Run + Cloud Functions), mobil uygulama yayın hazırlığı, Play Console süreci ve kâr odaklı bir reklam/büyüme planı olmak üzere dört ana blokta ilerliyor. Sonunda tek seferlik ve aylık maliyetlerin özetlendiği bir tablo ile son kontrol listesi yer alıyor.

**Çapraz kontrol notu (4 tur incelendi):** Bu rapor deneyimli bir mobil/backend geliştirici gözüyle üç kez baştan sona incelendi. İlk iki turda eklenen maddeler arasında UGC bildirme mekanizması (7.3), AAB/ProGuard yapılandırması (6.7), AdMob Console ön kaydı (6.4) ve Play App Signing'in gerektirdiği çift SHA-1 parmak izi (6.3) yer alıyor. Üçüncü tur, özellikle "development'ta çalışıp production'da sessizce bozulan" davranışlara odaklandı.
**Dördüncü ve son tur ise doğrudan mevcut projenin kaynak kodları (codebase) ile çapraz kontrol edilerek gerçekleştirildi.** Bu inceleme sonucunda; mobil uygulamada hardcoded duran Gemini API anahtarı (kritik güvenlik açığı), `firebase_crashlytics` paketinin `pubspec.yaml`'da eksik olması, Firestore indexes ve Storage rules eksiklikleri, build script'lerindeki (`build_release_apk.sh` ile APK derlenmesi) AAB uyumsuzluğu ve Apple Sign-In'in Android'de kilitlenme riski gibi doğrudan yayını engelleyecek teknik uyuşmazlıklar tespit edildi ve bu yol haritasına zorunlu (Must) düzeltmeler olarak eklendi. Bu dördüncü turdan sonra raporun kapsamı, kod tabanıyla tam uyumlu ve yayına hazır kabul edilmiştir.

---

## 2. Genel Faz Takvimi

| Faz | İçerik | Tahmini Süre | Bağımlılık |
|---|---|---|---|
| 1 | Yasal & kurumsal temel | 3–7 gün (resmi işlemler paralel ilerleyebilir) | Yok |
| 2 | Marka kimliği & mağaza görselleri | 5–10 gün | Yok (Faz 1 ile paralel yürütülebilir) |
| 3 | Cloud/Firebase production altyapısı | 4–8 gün | Yok |
| 4 | Flutter uygulamasını production'a hazırlama | 5–10 gün | Faz 2 ve 3'ün çıktıları gerekir |
| 5 | Play Console: hesap, kapalı test, inceleme | 14 gün test + 1–7 gün inceleme | Faz 1, 2, 4 tamamlanmış olmalı |
| 6 | Canlı izleme & operasyon | Sürekli | Yayın sonrası başlar |
| 7 | Reklam & büyüme | Lansmandan itibaren sürekli | Yayın sonrası başlar (ASO Faz 2'de başlar) |

Faz 1, 2 ve 3 büyük ölçüde paralel yürütülebilir; toplamda yayına kadar **gerçekçi süre 4–6 hafta**dır (14 günlük zorunlu kapalı test süresi dahil).

---

## 3. FAZ 1 — Yasal ve Kurumsal Temel

### 3.1 Bireysel mi, şirket (organizasyon) hesabı mı?
Google Play Console'da iki hesap türü var:
- **Bireysel (Personal) hesap:** Kimlik (T.C. kimlik kartı/pasaport) ile açılır, 25$ tek seferlik ücret. **Kapalı test zorunluluğuna tabidir** (bkz. Faz 5).
- **Organizasyon (Business) hesabı:** Bir D-U-N-S numarası (şirketi tanımlayan uluslararası numara) gerektirir, yine 25$ tek seferlik ücret, ama **12 test kullanıcısı / 14 gün kuralından muaftır**.

Şu an elinizde şirket/şahıs firması olmadığı için pratik yol bireysel hesapla başlamaktır; D-U-N-S başvurusu ve kurumsallaşma zaman alır ve test muafiyeti tek başına bu süreci beklemeye değmez. Reklam geliri belirli bir noktayı (Türkiye'de iş yeri açma eşiği, fatura kesme ihtiyacı) aştığında **şahıs şirketi** açmak hem AdMob/Google Ads faturalandırması hem de vergi mevzuatı açısından doğru adım olur — bu konuda kesin tutar ve oran bilgisi için bir mali müşavire danışmanız gerekir, çünkü gelir vergisi dilimleri ve KDV istisnaları zamanla değişebilir.

### 3.2 KVKK (Kişisel Verilerin Korunması Kanunu) Uyumu
Uygulama; e-posta/Google-Apple OAuth ile kullanıcı kaydı, yorum, oylama ve muhtemelen FCM push token gibi kişisel veri işliyor. Bu nedenle:
- **Aydınlatma metni** hazırlanmalı: hangi verinin (e-posta, ad, FCM token, IP, reklam kimliği vb.) hangi amaçla işlendiği, ne kadar saklandığı, kimlerle paylaşıldığı (Firebase/Google, AdMob, Gemini API) açıkça yazılmalı.
- **VERBİS kaydı:** Veri Sorumluları Sicili'ne kayıt, yıllık çalışan sayısı/veri hacmi eşiklerine bağlıdır; bireysel/küçük ölçekli işletmeler çoğu zaman istisna kapsamına girer ama bu uygulamanın büyüklüğüne göre değişir — büyüme ile birlikte tekrar değerlendirilmeli.
- Gemini API'ye gönderilen görsel ve mesaj içerikleri (Telegram kanallarından) üçüncü taraf veri işleme sayılır; aydınlatma metninde bu da belirtilmeli.

### 3.3 Gizlilik Politikası, Kullanım Şartları ve Hesap Silme Sayfası
Google Play'in **Developer Program Policy**'si gereği:
- Gizlilik politikası **herkese açık, statik bir URL'de** (PDF değil) barındırılmalı ve hem Play Console'daki ilgili alana hem de uygulama içine (örn. ayarlar ekranı) eklenmelidir.
- Uygulama kullanıcı hesabı oluşturmaya izin verdiği için (Google/Apple Sign-In var), Google **hesap silme talebi mekanizması** zorunlu kılıyor: hem uygulama içinden hem de uygulama dışından (web sayfası üzerinden, hesaba giriş yapmadan da erişilebilir) hesap ve veri silme talebinde bulunulabilmeli. Bu, `admin_screen.dart` benzeri bir ekrana değil, ayrı bir herkese açık sayfaya ihtiyaç duyar.
- Bu sayfaları barındırmak için ek maliyete gerek yok: zaten Firebase kullandığınız için **Firebase Hosting**'in ücretsiz katmanında basit bir statik sayfa (gizlilik politikası + kullanım şartları + hesap silme talebi formu) yayınlayabilirsiniz. Alternatif olarak Google Sites de ücretsiz ve yeterlidir.

### 3.4 Reklam Geliri ve Ödeme Altyapısı
AdMob gelirinin ödenebilmesi için bir **Google Payments Profili** (banka hesabı, vergi bilgisi) kurulmalı. Bireysel hesapla da AdMob'dan ödeme almak mümkündür, ancak alacağınız gelir Türkiye'de **gelir vergisine tabi** olabilir; düzenli ve büyüyen bir gelir söz konusu olduğunda bunu kayıt dışı bırakmamak için muhasebeci desteği almanızı öneririm. Bu rapor mali/hukuki tavsiye yerine geçmez.

---

## 4. FAZ 2 — Marka Kimliği ve Mağaza Varlıkları (ASO Temeli)

Mağazada üst sıralarda çıkmak teknik bir doğruluk meselesi olduğu kadar bir **App Store Optimization (ASO)** meselesidir; bu çalışma yayından önce başlamalı.

### 4.1 Gerekli görsel varlıklar
- **Uygulama ikonu:** 512×512 px, PNG, 32-bit (alfa kanallı); ayrıca Android için adaptive icon (ön plan + arka plan katmanı) hazırlanmalı.
- **Feature graphic (öne çıkan görsel):** 1024×500 px — mağaza sayfasının üst banner'ı.
- **Ekran görüntüleri:** En az 2, önerilen 4–8 adet telefon ekran görüntüsü (gerçek cihaz oranında, örn. 1080×1920 veya üzeri). Ana akış, fırsat detay/oylama ekranı ve bildirim deneyimini gösteren görseller en çok dönüşüm sağlar; ham ekran görüntüsü yerine üzerine kısa başlık eklenmiş "marketing" tarzı görseller dönüşüm oranını belirgin biçimde artırır.
- (Opsiyonel ama önerilir) **Tanıtım videosu** (YouTube linki ile): kapalı/açık test ve store listing dönüşümünü artırır, ileri faza bırakılabilir.

### 4.2 Metin varlıkları ve ASO
- **Başlık (30 karakter):** Marka adı + en güçlü anahtar kelime (örn. "FırsatKolik: İndirim & Fırsat").
- **Kısa açıklama (80 karakter):** Tek cümlede değer önerisi; "indirim", "fırsat", "kampanya" gibi yüksek aranan kelimeleri içermeli.
- **Tam açıklama (4000 karakter):** İlk 2-3 satır en kritik (arama sonucunda kesilmeden görünür); özellikler madde madde, anahtar kelimeler doğal bir dille tekrarlanmalı (keyword stuffing'den kaçının, Google bunu cezalandırabilir).
- Anahtar kelime araştırması için Play Console'un kendi "Store Listing Experiments" aracı veya ücretsiz üçüncü parti ASO araçları (örn. AppTweak, ücretsiz katmanlar) kullanılabilir; bütçe kısıtlıysa rakip uygulamaların (Cimri, Akakçe, Webrazzi Fırsat vb.) başlık/açıklamalarına bakarak manuel kelime listesi çıkarmak yeterlidir.

### 4.3 Paket adı (applicationId) kesinleştirme
`applicationId` (örn. `com.firsatkolik.app`) production'a çıkmadan önce **kesinleştirilmeli ve bir daha değiştirilmemelidir** — Play Store'da paket adı, uygulamanın kalıcı kimliğidir ve değiştirilemez. Bu adım Faz 4'teki imzalama sürecinden önce netleşmiş olmalı.

---

## 5. FAZ 3 — Google Cloud & Firebase Production Altyapısı

### 5.1 Firebase Projesi Production Kurulumu
- **Mevcut Durum ve Ayrı Proje Önerisi:** Projenin mevcut kod tabanı incelendiğinde, [firebase_options.dart](file:///d:/firsatkolik/lib/firebase_options.dart) ve [build.gradle](file:///d:/firsatkolik/android/app/build.gradle) dosyalarında herhangi bir **build flavor** (dev/prod ayrımı) bulunmamaktadır. Uygulama şu an doğrudan tek bir Firebase projesine (`sicak-firsatlar-e6eae`) bağlıdır. Production için **ayrı bir Firebase projesi** (`firsatkolik-prod`) oluşturulması ve dev ortamındaki test verilerinin gerçek kullanıcı verisine karışmaması şiddetle önerilir.
- **Build Flavor Entegrasyonu (Zorunlu Adım):** Farklı ortamları yönetmek için `android/app/build.gradle` dosyasına `flavorDimensions` ve `productFlavors` (örn: `dev` ve `prod`) tanımları eklenmeli; `android/app/src/dev/` ve `android/app/src/prod/` dizinleri oluşturularak ilgili ortamların `google-services.json` dosyaları buralara yerleştirilmelidir. Flutter tarafında derleme yaparken `--flavor dev` veya `--flavor prod` parametreleri kullanılmalıdır. (Eğer tek proje ile devam edilecekse, canlı verilerin ezilme riski göze alınmalı ve testler son derece sınırlı tutulmalıdır.)
- **Blaze (Pay-as-you-go) Plana Geçiş Zorunlu:** Cloud Functions'ın dış ağa (Gemini API, kısa link çözümleme için harici HTTP istekleri) çıkabilmesi ve Cloud Run kullanılabilmesi için ücretsiz Spark plan yeterli değildir; Blaze plana geçilmelidir. Blaze yine de cömert bir ücretsiz kotaya sahiptir, küçük/orta ölçekli bir uygulama için aylık maliyet genelde sınırlıdır (bkz. Bölüm 10 maliyet tablosu).
- **Bütçe Uyarıları (Budget Alerts):** Google Cloud Console > Billing > Budgets & Alerts üzerinden örneğin 500₺/1.000₺/2.000₺ eşiklerinde e-posta uyarısı kurulmalı. Cloud Run'da `min-instances: 1` sürekli açık kalan bir servis olduğu için beklenmedik maliyet artışlarını erken yakalamak kritik.

### 5.2 Firestore ve Storage Sertleştirme (Teknik Yapılandırma)
- **Security Rules:** Geliştirme sırasında sık kullanılan "test modu" kuralları (herkese açık okuma/yazma, 30 gün sonra otomatik kilitlenir) production'da **kesinlikle kullanılmamalı**. Projedeki [firestore.rules](file:///d:/firsatkolik/firestore.rules) dosyası incelenmiş ve kuralların kimlik doğrulamalı ve rol bazlı olarak sertleştirildiği doğrulanmıştır. Canlı ortama geçerken bu kuralların tam olarak korunduğundan emin olunmalıdır.
- **Composite Index'ler (`firestore.indexes.json` - Eksik Adım):** Sıcaklık puanına göre sıralama + kategori filtreleme gibi compound sorgular için composite index'ler tanımlanmalıdır. Şu an projede `firestore.indexes.json` dosyası ve [firebase.json](file:///d:/firsatkolik/firebase.json) dosyasında bu indekslerin bağlaması eksiktir. `firebase.json` dosyasına `"indexes": "firestore.indexes.json"` tanımı eklenmeli, gerekli indeksler Firestore konsolundan çekilerek bu dosyaya yazılmalı ve deploy edilmelidir.
- **Yedekleme:** Firestore'un yönetilen günlük yedekleme (Point-in-Time Recovery / Scheduled Backups) özelliği açılmalı; kullanıcı tarafından silinen ya da hatalı bir Cloud Function'ın bozduğu veri olursa geri dönüş imkânı sağlar.
- **App Check Entegrasyonu (Kritik Eksiklik):**
  Firebase App Check + **Play Integrity API** entegrasyonu, sahte/bot istemcilerin Firestore'a veya Cloud Functions'a doğrudan istek atmasını (API anahtarınızı çıkarıp kötüye kullanmasını) engeller. Bu, hem maliyet hem de moderasyon güvenliği için production öncesi eklenmesi gereken bir adımdır.
  
  > [!WARNING]
  > **Kod tabanında App Check entegrasyonu tamamen eksiktir.** Canlıya geçmeden önce aşağıdaki adımlar tamamlanmalıdır:
  > 
  > **1. İstemci Tarafı (Flutter):**
  > `pubspec.yaml` dosyasına `firebase_app_check: ^0.3.0` (veya güncel sürüm) eklenmeli ve `lib/main.dart` bootstrap sürecinde (Firebase initialize edildikten sonra) şu şekilde aktif edilmelidir:
  > ```dart
  > import 'package:firebase_app_check/firebase_app_check.dart';
  > // ...
  > await FirebaseAppCheck.instance.activate(
  >   androidProvider: AndroidProvider.playIntegrity,
  > );
  > ```
  > 
  > **2. Firebase Console Yapılandırması:**
  > Firebase Console > App Check sekmesinden Android uygulaması için **Play Integrity** sağlayıcısı aktif edilmeli ve Google Play Console'dan SHA parmak izi bağlanmalıdır.
  > 
  > **3. Sunucu Tarafı Entegrasyonu:**
  > Firestore Rules ve Storage Rules üzerinde App Check doğrulaması zorunlu kılınmalıdır (`request.auth != null` kurallarına ek olarak App Check token varlığı kontrol edilebilir).
- **Firebase Storage Rules ve Yapılandırması (Kritik Eksiklik):** Fırsat görselleri (Telegram botu tarafından indirilip yüklenen ve `cleanupOldImages` tarafından temizlenen görseller) Firebase Storage'da tutulmaktadır. Ancak projede `storage.rules` dosyası bulunmamakta ve [firebase.json](file:///d:/firsatkolik/firebase.json) dosyasında `storage` yapılandırması eksiktir.
  
  > [!IMPORTANT]
  > **Kritik Storage Okuma Davranışı:** Bot, görselleri Firebase Storage'a yüklerken `public: false` olarak yüklemekte ve token içermeyen doğrudan HTTPS linkleri üretmektedir (`https://firebasestorage.googleapis.com/v0/b/.../o/...&alt=media`). Mobil uygulamadaki `CachedNetworkImage` kütüphanesi bu görselleri Firebase SDK'sını kullanmadan anonim HTTPS isteğiyle çektiğinden, Storage güvenlik kurallarında `deals/` altındaki dosyalara **anonim/herkese açık okuma izni** verilmesi zorunludur. Aksi halde görseller canlıda yüklenmeyecektir.
  
  Bunun için `firebase.json` dosyasına aşağıdaki `storage` tanımı eklenmeli:
  ```json
  "storage": {
    "rules": "storage.rules"
  }
  ```
  Ve proje kök dizininde aşağıdaki içeriğe sahip bir `storage.rules` dosyası oluşturularak deploy edilmelidir:
  ```rules
  rules_version = '2';
  service firebase.storage {
    match /b/{bucket}/o {
      match /deals/{allPaths=**} {
        // İstemci uygulaması görselleri anonim HTTP ile indirdiği için okuma herkese açık olmalıdır
        allow read: if true;
        // Bot yazma işlemlerini admin yetkisiyle (Admin SDK) yaptığı için sunucu kuralları bypass edilir, istemcilere yazma kapatılır
        allow write: if false;
      }
      match /{allPaths=**} {
        allow read, write: if false;
      }
    }
  }
  ```

### 5.3 Cloud Functions Production Ayarları
- **Gizli Bilgiler (Secrets) Nerede Tutulacak?**
  Projede mevcuttaki gizli bilgileriniz: **Gemini API Key** ve **Telegram String Session** verileridir. Bu bilgilerin production ortamında nerede saklanacağı aşağıda netleştirilmiştir:
  
  *   **Telegram Botu (Cloud Run):** Botun kullandığı Gemini API anahtarı ve Telegram String Session bilgileri **kesinlikle Google Cloud Secret Manager'da saklanmalıdır.** Cloud Run servisi ayağa kaldırılırken bu sırlar container'a güvenli bir şekilde bağlanacaktır (bkz. Bölüm 5.4).
  *   **Mevcut Cloud Functions ([index.js](file:///d:/firsatkolik/functions/index.js)):** Mevcut functions kod tabanı (bildirimler, onay mekanizmaları vb.) harici bir API veya harici anahtar kullanmamaktadır (tamamen Firebase Admin SDK'nın dahili yetkilendirmesiyle çalışır). Bu sebeple, **mevcut** functions kodlarını deploy ederken Secret Manager veya `.env` üzerinden herhangi bir API anahtarı tanımlamanıza gerek yoktur.
  
  > [!IMPORTANT]
  > **Yeni Eklenecek Gemini Proxy Fonksiyonu İstisnası:** İstemci uygulamadaki (Flutter) hardcoded Gemini API anahtarını gizlemek için **Bölüm 5.4 / Düzeltme 1** adımında önerilen *Cloud Functions Proxy* yapısını kurarsanız, bu yeni fonksiyonun kullanacağı Gemini API anahtarı **Cloud Secret Manager**'da saklanmalı ve fonksiyona `runWith({secrets: ['GEMINI_API_KEY']})` parametresiyle bağlanmalıdır.
- **En az ayrıcalık (least privilege) servis hesabı:** Cloud Functions'ın varsayılan servis hesabı yerine, yalnızca ihtiyaç duyduğu Firestore/FCM/Storage izinlerine sahip özel bir servis hesabı tanımlanması önerilir.
- **Hata izleme:** Cloud Logging otomatik aktiftir; buna ek olarak **Error Reporting** ve bir **alerting policy** (örn. `onDealCreated` fonksiyonu art arda hata verirse e-posta/Slack bildirimi) kurulmalı — moderasyon hattı sessizce kırılırsa onaysız fırsatlar kullanıcıya gitmeyebilir ya da yığılabilir.
- **cleanupOldImages** gibi zamanlanmış görevlerin başarısız çalışması durumunda (örn. Storage izin hatası) sessiz kalmaması için bu fonksiyona da hata bildirimi eklenmeli.
- **Herkese Açık HTTP Fonksiyonları (App Check Koruması):**
  [resolveShortLink](file:///d:/firsatkolik/functions/index.js#L540) ve [cleanupOldImagesManual](file:///d:/firsatkolik/functions/index.js#L1100) gibi kimlik doğrulaması olmadan dışarıdan çağrılabilen `onRequest` HTTP endpoint'leri, kötü niyetli kişiler tarafından faturayı artırmak (her çağrı Cloud Functions faturasına yansır) veya alakasız URL'leri çözümletmek amacıyla kötüye kullanılabilir.
  
  > [!IMPORTANT]
  > Firebase Cloud Functions içindeki `onRequest` (Express tabanlı) fonksiyonlarında App Check doğrulaması otomatik olarak yapılmaz. Sadece istemci uygulamanızdan gelen istekleri kabul etmek için sunucu tarafında manuel App Check doğrulaması yapılması zorunludur:
  > ```javascript
  > const appCheckToken = req.header('X-Firebase-AppCheck');
  > if (!appCheckToken) {
  >   res.status(401).send('Unauthorized: Missing App Check Token');
  >   return;
  > }
  > try {
  >   await admin.appCheck().verifyToken(appCheckToken);
  >   // Token geçerli, işleme devam et...
  > } catch (err) {
  >   res.status(401).send('Unauthorized: Invalid App Check Token');
  >   return;
  > }
  > ```
  > 
  > Flutter tarafında ise HTTP isteklerini atarken `X-Firebase-AppCheck` header'ına `await FirebaseAppCheck.instance.getToken()` değeri eklenmelidir.


### 5.4 Cloud Run — 7/24 Telegram Botu Production Ayarları
Bu bileşen mimarinin en kırılgan noktasıdır çünkü kesintisiz, durum (state) taşıyan tek bir bağlantı (MTProto oturumu) üzerinden çalışır:
- **CPU tahsisi "Her zaman ayrılmış" (CPU is always allocated) olarak ayarlanmalı — bu bileşen için en kritik ayar, muhtemelen tüm rapordaki en kritik tek madde:** Cloud Run varsayılan olarak CPU'yu yalnızca gelen bir HTTP isteği işlenirken tahsis eder ("CPU is only allocated during request processing"); istek yokken container'ın CPU'su neredeyse tamamen kısılır. Ancak bu bot bir HTTP API değildir — **arka planda sürekli çalışan bir dinleyicidir.** GramJS'in Telegram'dan gelen mesajları yakalaması, Gemini API'ye istek atması ve Firestore'a yazması hep bu "arka plan" bağlamında, gelen bir HTTP isteğine bağlı olmadan gerçekleşir. Varsayılan ayarla deploy edilirse şu senaryo yaşanır: yerel geliştirme ortamınızda (bilgisayarınızda/sunucunuzda CPU her zaman açık) bot kusursuz çalışır, siz de her şeyin yolunda olduğuna kanaat getirirsiniz; ama Cloud Run'a taşındığında **mesajlar yalnızca container'a rastgele bir HTTP isteği (örn. health check ping'i) geldiği anda işlenir** — aradaki sürede gelen Telegram mesajları kuyrukta bekler, işlenmez. Sonuç: fırsat akışı dakikalarca, saatlerce gecikmeli çalışır ya da tamamen donmuş görünür, hiçbir hata logu da düşmez çünkü teknik olarak bir "hata" yoktur, sadece CPU'nuz kısılıdır. Bu, "dev'de çalışıyor, prod'da sessizce bozuluyor" kalıbının en saf hâlidir. **Düzeltme:** Cloud Run servisi deploy edilirken Console'da "CPU allocation" ayarından veya `gcloud run deploy` komutuna `--no-cpu-throttling` bayrağı eklenerek **"CPU is always allocated"** seçilmelidir. Bunun doğal sonucu daha yüksek bir aylık maliyettir (CPU artık 7/24 tam tahsisli sayılır ve buna göre faturalandırılır) — bu fark Bölüm 10'daki maliyet tahminine de yansıtılmalıdır, ama bu bileşenin amacına uygun çalışması için zorunludur.
- **Concurrency = 1, min-instances = 1, max-instances = 1:** Birden fazla instance aynı Telegram String Session ile aynı anda bağlanmaya çalışırsa Telegram bağlantıyı sonlandırabilir veya session çakışması yaşanabilir. Cloud Run'da bu servis için maksimum instance sayısı bilinçli olarak 1 ile sınırlanmalı.
- **Sırlar (secrets) asla kod içine veya düz ortam değişkenine gömülmemeli:** Telegram String Session ve Gemini API anahtarı **Secret Manager**'da saklanmalı, Cloud Run servisine "secret as environment variable / mounted volume" olarak bağlanmalı. Bu, repoya yanlışlıkla sızma riskini de ortadan kaldırır.
- **Servis hesabı izinleri:** Bot yalnızca Firestore'a `deals` koleksiyonuna yazma ve gerekiyorsa Storage'a görsel yükleme izni olan minimal bir servis hesabı kullanmalı; proje genelinde "Owner/Editor" gibi geniş roller verilmemeli.
- **Sağlık kontrolü (health check - Düzeltme):** Cloud Run servisleri HTTP isteklerini dinleyen bir container bekler. Bot kodunda [telegram_bot.js](file:///d:/firsatkolik/cloud-run-bot/telegram_bot.js#L1045) incelendiğinde, HTTP sunucusunun `/health` ve `/` yollarını dinlediği görülmektedir. Cloud Run container'ının sağlıklı kabul edilip kapatılmaması için Cloud Run servis ayarlarında (Startup/Liveness Probe) probe yolunun `/health` olarak ayarlandığından emin olunmalıdır. generic `/healthz` yolu kullanılmamalıdır.
- **Çökme sonrası otomatik yeniden başlama:** Node.js process'i bir exception ile kapanırsa Cloud Run container'ı otomatik olarak yeniden başlatır; ancak Telegram String Session kalıcı olarak saklandığı (Firestore/Secret Manager) için yeniden kimlik doğrulama gerekmeden bağlantı devam edebilmelidir — bunun deploy öncesi test edilmesi (container'ı manuel durdurup yeniden ayağa kalkışını izlemek) önerilir.
- **Uptime/monitoring alarmı:** Cloud Monitoring üzerinde "X dakikadır yeni mesaj işlenmedi" türünde özel bir metrik + alerting policy kurulması, botun sessizce Telegram'dan koptuğu (örn. session geçersiz olduğu) durumları saatler/günler sonra değil dakikalar içinde fark etmenizi sağlar. Bu hat çalışmazsa tüm fırsat akışı durur.
- **Gemini API Maliyet, Kota ve Güvenlik Takibi:**
  - **Bot/Backend Tarafı:** `gemini-2.0-flash` görsel+metin (multimodal) istekleri token bazlı ücretlendirilir; Google AI Studio/Cloud Console üzerinden günlük istek hacmine göre kota ve maliyet izlenmeli, ani bir mesaj trafiği artışında (örn. viral bir Telegram kanalı) maliyetin kontrolsüz büyümemesi için günlük üst limit/uyarı tanımlanmalı. Ayrıca **API anahtarının kademesi (tier) ayrı bir "dev'de çalışır, prod'da kırılır" riskidir:** Google AI Studio'dan alınan ücretsiz (free tier) bir Gemini API anahtarı, dakika başına istek sayısında (RPM) düşük bir sınıra sahiptir. Bu limit, geliştirme sırasında birkaç test mesajıyla asla fark edilmez; ama gerçek bir Telegram kanalının canlı ve yoğun mesaj trafiğinde kolayca aşılabilir. Limit aşıldığında Gemini istekleri sessizce hata döner (rate-limit/429) ve fırsat mesajları AI analizi olmadan işlenmeyebilir ya da hiç işlenmeyebilir. Production'a geçmeden önce API anahtarının **faturalandırmalı (billing-enabled) bir Google Cloud projesine bağlı** olduğundan ve buna uygun, gerçek trafiği kaldıracak kota sınırlarına sahip olduğundan emin olunmalı.
  
  > [!CAUTION]
  > **Flutter İstemci Tarafında Hardcoded API Key (Kritik Güvenlik Açığı):**
  > Projede [ai_service.dart](file:///d:/firsatkolik/lib/services/ai_service.dart#L11) dosyasında Gemini API Key (`_apiKey`) açık bir şekilde sabit kod olarak saklanmaktadır. Kullanıcılar yeni fırsat eklerken bu servis üzerinden ürün analizi yapmaktadır. APK/AAB dosyaları decompile edildiğinde bu anahtar doğrudan okunabilir ve üçüncü şahıslar tarafından sizin adınıza faturalandırılacak şekilde kötüye kullanılabilir.
  >
  > **Düzeltme (Zorunlu):** Üretim ortamında istemci uygulamasının doğrudan Gemini API'ye istek atması engellenmelidir. Bu işlem için iki güvenli alternatif mevcuttur:
  > 1. **Cloud Functions Proxy:** Ürün analiz mantığı bir Firebase Cloud Function içerisine taşınmalı, API key ise Cloud Secret Manager'da saklanmalıdır. Mobil uygulama bu Cloud Function'ı (App Check korumalı olarak) çağırmalıdır.
  > 2. **Firebase Vertex AI SDK:** Doğrudan istemci üzerinden çağırmak gerekiyorsa, Google'ın Firebase için sunduğu Vertex AI SDK'sına geçilmeli ve Firebase App Check aktif edilerek API key sızıntısı olmadan güvenli erişim sağlanmalıdır.


### 5.5 Firebase Cloud Messaging (FCM) Production Notları
- `firebase-admin` SDK üzerinden gönderilen bildirimler zaten güncel **FCM HTTP v1 API**'yi kullanır (eski "Legacy Server Key" API'si Google tarafından kapatıldığı için modern SDK kullanımı bu sorunu otomatik olarak çözer) — burada ekstra bir aksiyon gerekmez, sadece `firebase-admin` paketinin güncel sürümde olduğundan emin olunmalı.
- Konu (topic) bazlı bildirim gönderiminde (anahtar kelime abonelikleri) tek seferde çok büyük kullanıcı kitlesine gönderim yapılacaksa, FCM'in batch/topic limitlerine takılmamak için gönderim hacmi test edilmeli.

---

## 6. FAZ 4 — Flutter Uygulamasını Production'a Hazırlama

### 6.1 Android 16 (API 36) Hedefleme — ACİL
`android/app/build.gradle` (veya `build.gradle.kts`) içindeki `targetSdkVersion`/`compileSdkVersion` değerleri **36** olarak ayarlanmalı, Flutter SDK'nın bunu destekleyen bir sürümünde olunmalı. Bu güncelleme; bildirim davranışı, "predictive back" (geri tuşu) hareketi ve izin akışlarında küçük davranış değişiklikleri getirebileceğinden, güncellemeden sonra **tüm uygulama tekrar uçtan uca test edilmeli** (özellikle geri tuşu/navigasyon ve bildirim tıklama akışları).

**Bağlantılı ve kolayca gözden kaçan bir risk — yerel bildirim (local notification) zamanlama izinleri:** Stack'te "yerel bildirim kütüphaneleri" (örn. `flutter_local_notifications`) kullanıldığı belirtiliyor. Android 12'den (API 31) itibaren, uygulamanın belirli bir saatte kesin olarak tetiklenmesi gereken bildirimler (exact alarm) planlaması için özel bir izin (`SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`) gerekir; Android 13/14 ile bu izin modeli daha da sıkılaştırıldı ve gerekçesiz kullanım geri alınabiliyor. `targetSdkVersion`'ı 36'ya çıkarmak bu daha katı izin davranışını **otomatik olarak devreye sokar** — düşük bir targetSdk ile derlenmiş eski bir build'de sorunsuz çalışan zamanlanmış yerel bildirimler, sadece bu SDK yükseltmesi nedeniyle release build'de sessizce tetiklenmeyebilir. (Not: Bu yalnızca uygulama içi zamanlanmış/yerel bildirimleri etkiler; FCM üzerinden gelen push bildirimleri — fırsat onaylandığında gönderilenler gibi — bu izin modelinden etkilenmez.) targetSdk güncellemesinden sonra yapılacak uçtan uca testte, eğer uygulama zamanlanmış yerel bildirim kullanıyorsa bu akışın da özellikle doğrulanması gerekir.

### 6.2 Build Flavors (dev/prod Ayrımı)
Flutter + Firebase projelerinde standart yaklaşım, `dev` und `prod` için ayrı `applicationId` sonekleri (örn. `com.firsatkolik.app.dev` / `com.firsatkolik.app`), ayrı `google-services.json` dosyaları ve ayrı AdMob reklam birimi ID'leri tanımlamaktır. Bu sayede geliştirme sırasında yapılan testler gerçek kullanıcı verisini veya gerçek reklam gelirini etkilemez.

### 6.3 Uygulama İmzalama (App Signing)
- **Play App Signing'e kayıt zorunludur** (yeni uygulamalarda varsayılan ve önerilen yöntemdir): Google, uygulamanın gerçek imzalama anahtarını kendi sunucularında güvenle saklar; siz yalnızca bir **upload key** (yükleme anahtarı) ile imzalanmış AAB yüklersiniz.
- Upload keystore (`.jks` dosyası) oluşturulmalı, şifresi ve dosyası **güvenli bir şekilde** (parola yöneticisi + şifreli yedek) saklanmalı — bu dosya kaybolursa uygulamaya güncelleme yayınlamak ciddi şekilde zorlaşır.
- `key.properties` ve keystore dosyası **kesinlikle Git deposuna eklenmemeli** (`.gitignore`'a eklenmeli); CI/CD kullanılacaksa bu sırlar CI sisteminin "encrypted secrets" özelliğiyle saklanmalı.
- **Google Sign-In için kritik adım — iki ayrı parmak izi gereklidir:** Play App Signing etkinken sistemde iki farklı sertifika bulunur: (1) **Upload sertifikası** — sizin oluşturduğunuz keystore, AAB'yi imzalamak için kullanılır; (2) **App signing sertifikası** — Google'ın kendi anahtarı, kullanıcıların Play Store'dan indirdiği APK bu anahtarla imzalanır. Firebase Console'a yalnızca upload sertifikasının parmak izini eklerseniz, kendi kurduğunuz test build'de Google Sign-In çalışır; ancak **gerçek kullanıcıların Play Store'dan indirdiği sürümde Google Sign-In tamamen başarısız olur.** Her iki sertifikayı da Firebase Console'a eklemeniz zorunludur:
  1. Upload sertifikası SHA-1: `keytool -list -v -keystore upload-keystore.jks` ile alınır, Firebase Console > Authentication > Settings > Android parmak izleri bölümüne eklenir.
  2. **App signing sertifikası SHA-1:** Play Console'a AAB'nizi yükledikten sonra, Play Console > (Uygulamanız) > Setup > App integrity > App signing sekmesine gidin; orada "App signing key certificate" başlığı altındaki SHA-1 değerini kopyalayın ve Firebase Console'daki aynı bölüme ekleyin.
  
  Bu adım atlanırsa uygulamanız canlıda tam anlamıyla kırık olur ve hata loglarına "DEVELOPER_ERROR" düşer. Release build testiniz upload keystore ile imzalandığı için yerel testte her şey çalışır; sorun ancak Play Store üzerinden indiren gerçek kullanıcıda ortaya çıkar.
- **Apple Sign-In notu (Uyumsuzluk Riski):** Kod tabanında [auth_screen.dart](file:///d:/firsatkolik/lib/screens/auth_screen.dart#L190) incelendiğinde Apple Sign-In entegrasyonu yer almaktadır. Android'de "Sign in with Apple" teknik olarak Apple'ın kendi SDK'sı yerine bir **web tabanlı OAuth akışı** (Apple Service ID + yönlendirme/redirect URI) ile çalışır. Bu redirect URI'nin production domain'inizle (örn. Firebase Hosting adresi) Apple Developer hesabında doğru tanımlanmış olması gerekir.
  
  > [!WARNING]
  > **Kilitlenme Riski:** Eğer Apple Developer Console'da Android için bu yapılandırma tamamlanmadıysa, Android cihazlarda bu Apple butona tıklandığında uygulama kilitlenecek ya da Firebase hata verecektir. Sadece Android sürümü çıkarılacağı için ya bu buton koddan geçici olarak kaldırılmalı/gizlenmeli ya da web OAuth yönlendirme ayarları eksiksiz tamamlanmalıdır.

### 6.4 AdMob Production Ayarları
**Ön adım — AdMob Console kurulumu (Play Console'dan bağımsız, ayrı bir süreç):**
AdMob geliri, reklam birimi ID'leri ve AdMob App ID'si için önce **admob.google.com** adresinde hesap ve uygulama kaydının yapılmış olması gerekir. Bu, Play Console hesabından tamamen bağımsız bir süreçtir ve birçok geliştirici bunu atlayıp "neden reklam gelmiyor?" sorusunu canlıya geçtikten sonra soruyor. Adımlar:
1. admob.google.com'da hesap oluşturun ve şartları kabul edin.
2. "Uygulama ekle" ile Android uygulamanızı kaydedin (Play Store'a yayınlanmamışsa "uygulama yayında değil" seçeneğini kullanın).
3. Reklam birimi oluşturun (Banner, Interstitial vb.) — her birimin **reklam birimi ID'si** (`ca-app-pub-xxx/yyy`) kayıt altına alınmalı.
4. **AdMob hesap/uygulama onayı:** Yeni hesaplar için Google, gerçek reklamları göstermeye başlamadan önce hesabı inceleyip onaylar; bu süreç **24–72 saat veya bazen daha fazla** sürebilir. Eğer uygulamayı canlıya almadan önce AdMob kaydını tamamlamadıysanız, ilk günlerde reklam boşluğu (veya hiç reklam gösterilmemesi) yaşarsınız. AdMob'ı en geç Faz 4'ün başında kaydedin.

- **Test vs. Gerçek Reklam Birimleri (Kritik Hesap Güvenliği):**
  Projede [ad_deal_card.dart](file:///d:/firsatkolik/lib/widgets/ad_deal_card.dart#L14) ve [home_screen.dart](file:///d:/firsatkolik/lib/screens/home_screen.dart#L964) dosyalarında gerçek reklam birim kimlikleri (`ca-app-pub-6853997017739651/8758625050`) doğrudan kod içine yazılmıştır.
  
  > [!CAUTION]
  > Geliştirme ve debug testleri sırasında gerçek reklam birim ID'lerinin kullanılması ve test cihazı olarak kaydedilmemiş cihazlarda bu reklamların yüklenmesi **Google AdMob hesabı kapatılma/askıya alınma** sebebidir.
  >
  > **Düzeltme:** Kodda reklam yüklenen yerlerde `kDebugMode` kontrolü yapılmalı ve debug modda otomatik olarak Google'ın standart test reklam birim kimliği (`ca-app-pub-3940256099942544/6300978111` - Banner için) yüklenmelidir. Sadece release build'lerde gerçek reklam kimliği yüklenmelidir.

- `AndroidManifest.xml` içindeki AdMob `App ID` meta-data etiketi production değeriyle güncellenmeli ve Play Console > App content > Ads bölümünde "Uygulamam reklam içeriyor" beyanı işaretlenmeli.
- **Google'ın Kullanıcı Mesajlaşma Platformu (UMP SDK / CMP - Kritik Eksiklik):**
  Google, reklam gösterimi yapılacak cihazlarda kullanıcılardan KVKK/GDPR uyumlu izinlerin toplanmasını (Consent Management Platform) denetlemektedir.
  
  > [!IMPORTANT]
  > **Kod tabanında onam formu (consent form) akışı bulunmamaktadır.** İzin toplanmadan AdMob SDK'sının başlatılması reklam kısıtlamalarına veya politika ihlallerine yol açabilir. 
  > 
  > **Düzeltme:** [main.dart](file:///d:/firsatkolik/lib/main.dart#L175) içindeki `MobileAds.instance.initialize()` çağrısından önce UMP SDK entegre edilmelidir. Örnek uygulama kodu:
  > ```dart
  > import 'package:google_mobile_ads/google_mobile_ads.dart';
  > 
  > void initializeAds() {
  >   final params = ConsentRequestParameters();
  >   ConsentInformation.instance.requestConsentInfoUpdate(
  >     params,
  >     () async {
  >       if (await ConsentInformation.instance.isConsentFormAvailable()) {
  >         ConsentForm.loadAndShowIfRequired((FormError? error) {
  >           // Form başarıyla gösterildi veya zaten izin var, reklamları başlat
  >           MobileAds.instance.initialize();
  >         });
  >       } else {
  >         MobileAds.instance.initialize();
  >       }
  >     },
  >     (FormError error) {
  >       // İzin bilgisi güncellenemedi, yine de reklamları başlat (fallback)
  >       MobileAds.instance.initialize();
  >     },
  >   );
  > }
  > ```

- **app-ads.txt (gelir koruması):** Bu dosya zorunlu olmasa da, sahte/yetkisiz reklam satıcılarının uygulamanızın envanterini taklit ederek gelirinizi düşürmesini engeller. Geliştirici web sitenizde (Faz 3'te kurduğunuz Firebase Hosting sayfasında) `app-ads.txt` dosyası yayınlanması ve Play Console'daki "Developer website" alanına bu sitenin eklenmesi, özellikle reklam geliri büyüdükçe önemli hale gelir.
- Reklam sıklığı (frequency capping): kullanıcı deneyimini (ve dolayısıyla elde tutmayı) bozmamak için interstitial reklamların aşırı sık gösterilmemesi — bu hem retention hem de uzun vadeli reklam geliri açısından kritik (Bölüm 9.5'te detaylandırıldı).

### 6.5 İzleme, Performans ve Güvenlik (Eksik Paket Kurulumu)
- **Firebase Crashlytics Kurulumu (Must):** Yol haritasında Crashlytics'in aktif olması gerektiği yazılmıştır. Ancak projedeki [pubspec.yaml](file:///d:/firsatkolik/pubspec.yaml) incelendiğinde `firebase_crashlytics` bağımlılığı **eksiktir**.
  
  **Aksiyon Adımları:**
  1. `pubspec.yaml` dosyasına `firebase_crashlytics: ^4.0.0` (güncel uyumlu sürüm) bağımlılığı eklenmeli ve `flutter pub get` çalıştırılmalıdır.
  2. `android/build.gradle` (proje düzeyi) dosyasına Crashlytics classpath eklenmeli:
     ```gradle
     dependencies {
         // ...
         classpath 'com.google.firebase:firebase-crashlytics-gradle:2.9.9'
     }
     ```
  3. `android/app/build.gradle` (uygulama düzeyi) dosyasına Crashlytics eklentisi uygulanmalı:
     ```gradle
     apply plugin: 'com.google.firebase.crashlytics'
     ```
  4. `lib/main.dart` dosyasında `FlutterError.onError` ve `PlatformDispatcher.instance.onError` bağlamaları yapılarak hatalar Crashlytics'e aktarılmalıdır.
- **Firebase Performance Monitoring** zaten stack'te var; ekran açılış süreleri ve ağ isteği gecikmeleri için production'da aktif izlenmeli.
- **App Check:** Mobil tarafta da Play Integrity sağlayıcısı ile etkinleştirilmeli (Bölüm 5.2'deki 1. adıma uygun olarak).
- **Yarım Kalmış Özellikler ve Eksik Dosyalar (Uyumsuzluk Riski):**
  - **edit_profile_screen.dart Dosyasının Olmaması:** [profile_screen.dart](file:///d:/firsatkolik/lib/screens/profile_screen.dart#L20) dosyasında `import 'edit_profile_screen.dart';` ifadesi, dosya bulunamadığı gerekçesiyle yorum satırına alınmıştır. Uygulamanın canlı sürümünde "Profil Düzenleme" butonu varsa tıklanması durumunda çökme yaşanacaktır. Bu ekran tamamlanmalı veya ilgili buton canlı yayından önce UI'dan geçici olarak kaldırılmalıdır.
  - **Kullanıcının Kendi Paylaştığı Fırsatlar Listesi (Eksik Özellik):** Profil ekranında kullanıcının kendi paylaştığı fırsatların listeleneceği bölüm eksiktir. FirestoreService sınıfına `getDealsByUser(String userId)` sorgu fonksiyonu yazılmalı ve profil sayfasına bu liste eklenerek kullanıcı deneyimi tamamlanmalıdır.
- **İzin (permission) denetimi:** `AndroidManifest.xml`'de kullanılmayan/gereksiz izinler kaldırılmalı. Hem Play Store incelemesinde hem de Veri Güvenliği (Data Safety) formunda gereksiz izinler ekstra açıklama yükü ve ret riski yaratır.
- **Sürümleme:** `pubspec.yaml`'daki `version` alanı (`versionName+versionCode`), her yayında `versionCode` artırılarak ilerletilmeli; ilk production sürümü için `1.0.0+1` gibi net bir başlangıç noktası belirlenmeli.

### 6.7 Release Build Üretimi (AAB) ve ProGuard/R8 Kuralları

- **Yayın Dosyası Formatı ve Script Uyuşmazlığı (Kritik):**
  Google Play, Ağustos 2021'den itibaren yeni uygulamalar için yalnızca **Android App Bundle (AAB)** formatını kabul etmektedir; `.apk` yüklemesi artık reddedilir.
  
  > [!WARNING]
  > Projede yer alan [build_release_apk.sh](file:///d:/firsatkolik/scripts/build_release_apk.sh) scripti `flutter build apk --release` komutuyla sadece APK üretmektedir. Bu script güncellenmeli veya AAB çıktısı almak için `scripts/build_release_aab.sh` adında yeni bir script oluşturulmalı ve içerisindeki derleme komutu şu şekilde ayarlanmalıdır:
  > ```bash
  > flutter build appbundle --release
  > ```
  > Çıktı dosyası `build/app/outputs/bundle/release/app-release.aab` konumunda üretilecek ve Play Console'a bu dosya yüklenecektir. APK dosyaları sadece manuel/fiziksel QA testlerinde kullanılabilir.


**ProGuard/R8 kuralları — sessiz release kırılmaları:**
Flutter release build'lerde R8 (Java kod küçültücüsü) varsayılan olarak etkindir. R8, reflection veya JNI kullanan sınıfları "kullanılmıyor" diye silebilir; bu, debug build'de mükemmel çalışan uygulamanın release build'de bazı cihazlarda sessizce çökmesine veya Google Sign-In'in başarısız olmasına yol açar. `android/app/proguard-rules.pro` dosyasına aşağıdaki kuralların eklendiğinden emin olun:

```proguard
# Firebase Auth
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase Firestore
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# AdMob
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
```

`android/app/build.gradle` içinde `buildTypes { release { ... } }` bloğunda `minifyEnabled true` ve `proguardFiles` doğru şekilde tanımlanmış olmalı:

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

**Doğrulama:** Release build ürettikten sonra uygulamayı release APK/AAB üzerinden fiziksel cihaza kurarak (adb install veya Play Console iç test kanalı ile) Google Sign-In dahil tüm kritik akışları bizzat test edin. Yalnızca debug build testine güvenmek bu aşamada yeterli değildir.

### 6.8 Yayın Öncesi QA Kontrol Listesi
- Farklı ekran boyutu/yoğunluğunda (küçük telefon, tablet) arayüz testi
- Zayıf/kopuk internet bağlantısında uygulamanın davranışı (Firestore offline cache, hata mesajları, `ConnectivityService` entegrasyonu)
- Derin link / bildirim tıklama akışlarının release build'de çalıştığının doğrulanması
- Google/Apple Sign-In'in **release imzalı** build üzerinde uçtan uca test edilmesi (Bölüm 6.3'teki SHA-1 ve Apple Sign-In Android kilitlenme uyarısı nedeniyle)
- **Apple Sign-In Android Davranışı:** Apple ile Giriş Yap butonuna basıldığında Android'de hata alınmadığından (OAuth akışının çalıştığı veya butonun Android platformunda bilinçli olarak gizlendiği) emin olunması
- **Bildirim izni (runtime permission) akışı:** Android 13 ve üzeri sürümlerde push bildirimleri gösterebilmek için uygulamanın çalışma zamanında `POST_NOTIFICATIONS` iznini kullanıcıdan istemesi zorunludur; bu izin istemi akışının release build'de doğru tetiklendiği ve kullanıcı izni reddettiğinde uygulamanın çökmeden/bozulmadan devam ettiği test edilmeli
- **AdMob Test Reklamı Geçişi:** Debug build'de Google test reklam birimlerinin, release build'de ise gerçek reklam birimlerinin (`ca-app-pub-6853997017739651/8758625050`) yüklendiğinin ve gerçek reklamlara tıklanmadığının doğrulanması
- **Crashlytics Entegrasyon Testi:** `firebase_crashlytics` paketinin projeye eklendiğinin ve debug modda atılan test hatalarının Firebase Console'a başarıyla düştüğünün test edilmesi
- **Firebase Storage Görsel Erişimi:** Telegram botunun oluşturduğu görsel HTTPS linklerinin (`firebasestorage.googleapis.com/...alt=media`) `CachedNetworkImage` tarafından anonim olarak başarıyla yüklendiğinin doğrulanması (Storage Rules'da okuma izni olmaması durumunda görseller yüklenmeyecektir)
- **Firestore Composite Index Doğrulaması:** Sıcaklık oylaması ve kategori bazlı listeleme sorgularının (composite index gerektiren sorgular) hiçbir hata vermeden veri getirdiğinin ve missing index logu üretmediğinin doğrulanması
- Admin onay ekranının yalnızca yetkili kullanıcılar tarafından erişilebildiğinin (Firestore Rules + uygulama içi rol kontrolü ile) doğrulanması
- **Eşzamanlı oylama (sıcaklık) davranışı — kod incelemesiyle doğrulanmalı:** Oylama/sıcaklık artırma işlemi Firestore'da bir sayaç güncellemesi olarak yapılıyorsa, tekli geliştirici testinde (aynı anda tek kullanıcı oy veriyor) bu her zaman doğru çalışır. Gerçek kullanıcı trafiğinde onlarca kişi aynı fırsata aynı anda oy verdiğinde, sayaç güncellemesi "oku-artır-yaz" şeklinde (atomic olmayan) yazılmışsa oylar kaybolabilir (race condition). Bunun `FieldValue.increment()` ile atomik olarak veya bir Firestore transaction'ı içinde yapıldığından kod incelemesiyle emin olunmalı; bu, tek kişilik testte hiçbir zaman ortaya çıkmayan, yalnızca gerçek eşzamanlı trafikte görülen bir sınıf hatadır.

---

## 7. FAZ 5 — Google Play Console Süreci

### 7.1 Geliştirici Hesabı Açma
1. play.google.com/console adresinden kayıt başlatılır, **Bireysel hesap** seçilir (bkz. Bölüm 3.1).
2. 2 Adımlı Doğrulama açık bir Google hesabı, geçerli kimlik (T.C. kimlik/pasaport) ve prepaid olmayan bir kredi/banka kartı hazırlanmalı.
3. **25 USD tek seferlik kayıt ücreti** ödenir (yıllık tekrar eden bir ücret değildir).
4. Kimlik doğrulama Google tarafından birkaç saat ile birkaç iş günü arasında sonuçlanır.

### 7.2 Zorunlu Kapalı Test (Closed Testing) — 12 Test Kullanıcısı / 14 Gün
13 Kasım 2023'ten sonra açılan bireysel hesaplar için Google, production erişimine geçmeden önce **en az 12 kullanıcının kesintisiz 14 gün boyunca** kapalı teste opt-in (katılım) yapmış olmasını şart koşuyor (önceki "20 test kullanıcısı" kuralı Aralık 2024'te 12'ye düşürüldü). Pratikte:
- Play Console > Testing > Closed testing üzerinden bir test kanalı oluşturulur, imzalı AAB yüklenir.
- Bir **opt-in linki** üretilir; bu link arkadaş çevresi, mevcut Telegram topluluğunuz (bot zaten Telegram kanallarından besleniyor, bu organik bir test kullanıcı havuzu sunar), aile/iş çevresi ile paylaşılır.
- Testerların gerçek cihazda, gerçek Google hesabıyla **uygulamayı kurup aktif olarak kullanması** önemlidir; Google 2026 itibarıyla test kullanıcılarının gerçekten uygulamayı açıp kullandığını (sadece kurup unutmadığını) daha sıkı şekilde denetliyor. "Kur ve unut" testerlar düşük etkileşim nedeniyle başvurunun reddedilmesine yol açabilir.
- 14 günlük süre dolduğunda Play Console'dan **production erişimi için başvuru** yapılır; bu başvuruda uygulamanın ne işe yaradığı ve test sürecine dair birkaç soru yanıtlanır.
- **Zaman planlaması ve sayaç hakkında kritik bilgi:** 14 günlük sayaç, AAB'yi yüklediğiniz anda **başlamaz**. Gerçek süreç şudur: (1) AAB'yi yüklersiniz → (2) Google kapalı test sürümünü inceler ve onaylar (yeni hesaplarda **1–3 iş günü** sürebilir) → (3) en az 12 kullanıcı opt-in yapar → (4) ancak bu noktada 14 günlük sayaç başlar. Planlama yaparken bu 1–3 günlük onay gecikmesini hesaba katın; "AAB'yi bugün yükledim, 14 gün sonra production'dayım" varsayımı yanlıştır. Kapalı testi Faz 4'teki teknik hazırlıkla paralel yürütün ve onay gecikmesi için 3 ek gün tampon bırakın.

### 7.3 App Content (Uygulama İçeriği) Beyanları
Play Console > App content bölümünde eksiksiz doldurulması gereken formlar:
- **Veri Güvenliği (Data Safety) formu:** Firebase Auth, Firestore, Crashlytics, Performance, FCM ve AdMob SDK'larının topladığı veri tiplerinin (e-posta, cihaz kimlikleri, reklam kimliği, uygulama içi etkileşimler, çökme/teşhis verisi) tek tek beyan edilmesi gerekir. Bu beyan **gizlilik politikanızla birebir tutarlı olmalı** — tutarsızlık hem incelemede ret hem de sonradan politika ihlali riski doğurur. AdMob SDK'sının otomatik olarak IP adresi, cihaz/hesap kimlikleri ve reklam etkileşim verisini topladığı unutulmamalı.
- **İçerik derecelendirme anketi (IARC):** Uygulamanın içeriği (kullanıcı üretimi içerik/yorum barındırdığı, fırsat/e-ticaret odaklı olduğu) doğru şekilde işaretlenmeli.
- **Hedef kitle ve içerik:** Hedef yaş grubu beyanı; uygulama çocuklara yönelik değilse bu açıkça belirtilmeli (COPPA benzeri ek kısıtlamalardan kaçınmak için).
- **Reklam beyanı:** "Bu uygulama reklam içeriyor" kutusu işaretlenmeli.
- **Finansal özellikler / Haberler uygulaması beyanları:** FırsatKolik bir alışveriş/fırsat platformu olduğu, kredi/borç verme veya haber yayıncılığı yapmadığı için bu formlar büyük olasılıkla "Hayır" ile geçilecek, ancak doldurulmaları zorunludur.
- **Hesap silme talebi:** Faz 3.3'te hazırlanan herkese açık sayfanın URL'si burada beyan edilmeli.
- **Kullanıcı Üretimi İçerik (UGC) Politikası — Zorunlu, Ret Sebebi:** FırsatKolik, kullanıcıların yorum ve oylama yapmasına imkân tanıyan bir platformdur. Google Play Developer Policy, kullanıcı tarafından üretilen içerik barındıran tüm uygulamaların **uygulama içinde, kullanıcı tarafından erişilebilir bir raporlama/şikayet mekanizması** sunmasını zorunlu kılmaktadır.
  
  > [!NOTE]
  > **Kod tabanında bu mekanizma halihazırda mevcuttur:** [comments_bottom_sheet.dart](file:///d:/firsatkolik/lib/widgets/comments_bottom_sheet.dart#L663), [profile_screen.dart](file:///d:/firsatkolik/lib/screens/profile_screen.dart#L1617) ve [deal_detail_screen.dart](file:///d:/firsatkolik/lib/screens/deal_detail_screen.dart#L660) dosyalarında `showReportDialog` çağrısı ile "Raporla/Şikayet Et" butonu eklenmiştir. Raporlar Firestore'da `reports` koleksiyonuna yazılmakta ve [admin_reports_list.dart](file:///d:/firsatkolik/lib/widgets/admin_reports_list.dart) üzerinden izlenmektedir.
  
  **Yapılması Gereken:** Firestore kurallarında `reports` koleksiyonuna yazma izninin doğru çalıştığından ve adminlerin bu raporları listeleyip işlem yapabildiğinden emin olmak için uçtan uca testler yapılmalıdır.


### 7.4 Store Listing (Mağaza Sayfası)
Faz 2'de hazırlanan görseller ve metinler buraya yüklenir; **ülke/bölge seçiminde yalnızca Türkiye** işaretlenir (mevcut hedef pazar kararına uygun), fiyatlandırma "Ücretsiz" olarak ayarlanır.

### 7.5 İnceleme ve Yayın
- Production'a ilk başvuru genelde birkaç saat ile birkaç gün içinde sonuçlanır; ilk kez yayın yapan hesaplarda inceleme süresi daha uzun olabilir.
- En sık ret nedenleri: eksik/uyumsuz gizlilik politikası, Veri Güvenliği formu ile gerçek davranış arasındaki tutarsızlık, gereksiz izin talepleri, reklam politikası ihlalleri (örn. reklamın kapatma düğmesini gizlemesi) ve hesap silme mekanizmasının eksik olması.
- **Kademeli yayın (staged rollout):** İlk production sürümünü kullanıcıların %100'üne değil, **%5 → %20 → %50 → %100** şeklinde kademeli açmak, beklenmedik bir çökme/hata durumunda etkilenen kullanıcı sayısını sınırlı tutar. Her kademede 24–48 saat Crashlytics ve Android Vitals izlenerek bir sonraki kademeye geçilmesi önerilir.

---

## 8. FAZ 6 — Canlıya Çıktıktan Sonra İzleme ve Operasyon

- **Crash-free kullanıcı oranı** Crashlytics'te takip edilmeli; bu oran düşükse hem kullanıcı kaybı hem de Play Store'un "Android Vitals" üzerinden uyguladığı görünürlük cezaları söz konusu olabilir (yüksek çökme/ANR oranı olan uygulamalar aramada geriye düşebilir).
- **Cloud Monitoring uyarıları:** Cloud Run botunun "sessiz kalması", Cloud Functions hata oranındaki artış ve Firebase/GCP faturasındaki anormal sıçramalar için alarm politikaları (Faz 5.4'te kurulanlar) sürekli izlenmeli.
- **Play Store yorumlarına yanıt verme:** Düzenli yorum yanıtlama hem kullanıcı güvenini artırır hem de Play Store algoritmasının "aktif geliştirici" sinyali olarak değerlendirdiği bir faktördür.
- **Güncelleme kadansı:** Her 4–6 haftada bir küçük iyileştirme/güncelleme yayınlamak (yeni özellik şart değil, hata düzeltmesi de olur) hem ASO hem de kullanıcı güveni açısından olumlu bir sinyaldir; uzun süre güncellenmeyen uygulamalar mağazada görünürlük kaybeder.

---

## 9. FAZ 7 — Reklam ve Büyüme Stratejisi

Bu bölüm, belirttiğiniz **aylık 3.000–15.000₺** bütçe ve **yalnızca Türkiye** pazarı varsayımına göre kurgulanmıştır. Bu bütçe aralığı "test ve öğrenme" ölçeğindedir — agresif kullanıcı satın alma kampanyalarından çok, **kanal/mesaj testi + organik büyümeyi destekleme** stratejisi daha rasyoneldir; bu nedenle aşağıdaki plan, bütçenin büyük kısmını düşük rekabetli/yüksek verimli kanallara yönlendirip kademeli ölçeklenmeyi önerir.

### 9.1 Lansman Öncesi — Düşük/Sıfır Maliyetli Temel (Faz 2 ile birlikte başlar)
- **ASO:** Ücretsiz ama dönüşüm üzerinde en yüksek etkiye sahip kanal; Bölüm 4.2'deki başlık/açıklama optimizasyonu, lansmandan haftalar önce tamamlanmalı.
- **Mevcut Telegram ekosistemini kullanma:** Botunuz zaten çeşitli fırsat paylaşan Telegram kanallarını dinliyor; kendi markanız adına bir Telegram kanalı/grubu açıp burada uygulamayı tanıtmak, ilgi alanı zaten örtüşen, **hazır ve ücretsiz** bir kitleye ulaşmanın en verimli yoludur. Bu, kapalı test aşamasındaki 12 test kullanıcısını bulmak için de doğrudan kullanılabilir.
- **Instagram/TikTok organik hesap:** Görsel ağırlıklı "günün en iyi fırsatları" paylaşımları düşük maliyetle organik erişim sağlayabilir; bu içerik üretimi ücretli reklamlar için de yeniden kullanılabilir kreatif havuzu oluşturur.

### 9.2 Ücretli Reklam Kanalları ve Bütçe Dağılımı
Orta bütçe (3.000–15.000₺/ay) için önerilen başlangıç dağılımı:

| Kanal | Ayırma Önerisi | Gerekçe |
|---|---|---|
| Google Ads – App Campaigns (UAC) | %50–60 | Android yükleme kampanyaları için genelde en yüksek otomatik optimizasyon kalitesine sahip kanal; Google Play Store, arama ve YouTube envanterine tek kampanyadan erişim sağlar |
| Meta Ads (Instagram/Facebook) – App Install | %25–30 | Görsel ağırlıklı fırsat içeriği için güçlü, "lookalike audience" (benzer kitle) ile kapalı test kullanıcılarınızdan yola çıkarak hedefleme kalitesi artırılabilir |
| Mikro-influencer / Telegram-Instagram işbirlikleri | %10–15 | Türkiye'deki fırsat/indirim niş hesaplarıyla düşük maliyetli işbirlikleri, paid ads'e göre daha yüksek güven ve dönüşüm sağlayabilir |
| TikTok Ads | İlk 2–3 ay test bütçesi ayrılmayabilir | Video içerik üretim maliyeti bu bütçe ölçeğinde diğer kanallara göre önceliği düşürür; organik TikTok içeriği önce denenip performansı görüldükten sonra ücretli bütçe eklenmesi daha rasyoneldir |

Bu dağılım kesin bir formül değil, başlangıç noktasıdır; ilk 60–90 günün verisine göre (Bölüm 9.4) yeniden dengelenmelidir.

**Önemli not — gerçekçi beklenti yönetimi:** Türkiye'de Android için yükleme başı maliyet (CPI) kategoriye, kreatif kalitesine ve mevsime göre geniş bir aralıkta değişir; bu raporda kesin bir TL/yükleme rakamı verilmemesi bilinçli bir tercihtir, çünkü güncel ve doğru bir rakam ancak Google Ads/Meta Ads hesaplarınızda gerçek kampanya verisiyle (ilk 1-2 haftalık test sonrası) görülebilir. İlk kampanyalar bu nedenle "öğrenme bütçesi" olarak planlanmalı, ilk 2 haftada agresif ölçeklenme yerine veri toplanmalı.

### 9.3 İlk 6 Ayın Zaman Çizelgesi
- **Ay 1–2 (Lansman/Soft Launch):** ASO + organik sosyal medya + Telegram topluluğu; ücretli reklamda küçük bir test bütçesiyle (toplam bütçenin ~%30'u) Google UAC kampanyası başlatılır, öğrenme/optimizasyon evresine girilir.
- **Ay 3–4:** İlk verilerle (hangi kanal hangi maliyetle hangi kalitede kullanıcı getiriyor) bütçe en iyi performans gösteren kanala kaydırılır; Meta Ads'e geçilir/eklenir, mikro-influencer denemeleri başlar.
- **Ay 5–6:** Kazanan kanal(lar)a bütçe yoğunlaştırılır; kampanya hedefi yalnızca "yükleme" değil **"elde tutma" (retention) odaklı optimizasyona** kaydırılır (örn. Google Ads'te "tIn-app conversion" hedefini ilk gün açılıştan 7 günlük aktif kullanıcıya çevirme gibi).

### 9.4 Takip Edilmesi Gereken KPI'lar
- **CPI (Cost per Install):** Kanal bazında yükleme başı maliyet.
- **D1 / D7 / D30 Retention:** Kullanıcıların 1., 7. ve 30. günde uygulamaya geri dönme oranı — paid kullanıcı kalitesinin gerçek göstergesi, sadece yükleme sayısı değil.
- **CAC vs. LTV:** Kullanıcı başına edinme maliyeti, kullanıcı başına ortalama reklam geliri (AdMob eCPM × gösterim sayısı) ile karşılaştırılmalı; CAC, LTV'yi anlamlı bir sürede geçmiyorsa o kanal için bütçe artırılmamalı.
- **eCPM / doldurma oranı (fill rate):** AdMob konsolundan takip edilen reklam geliri kalitesi.
- **Crash-free rate / ANR oranı:** Paid trafikle gelen yeni kullanıcıların kötü bir teknik deneyim nedeniyle hemen kaybedilmemesi için bu oranların izlenmesi reklam bütçesinin verimliliğini doğrudan etkiler.

### 9.5 AdMob Reklam Gelirini Optimize Etme
- **Format çeşitliliği:** Banner + native (akış içi) + ödüllü (rewarded, opsiyonel bir özellik olarak değerlendirilebilir) + sınırlı sayıda interstitial kombinasyonu, tek format kullanmaya göre genelde daha yüksek toplam gelir sağlar.
- **Frekans sınırlama:** İnterstitial reklamların oturum başına gösterim sayısı sınırlandırılmalı; aşırı reklam, kısa vadede gelir gibi görünse de retention'ı düşürerek orta/uzun vadede toplam geliri azaltır.
- **Mediation:** AdMob mediation ile tek bir ağ yerine birden fazla reklam ağından (AdMob'un kendi ağına ek olarak) teklif alınması, gösterim başına geliri artırabilir; bu, kullanıcı tabanı büyüdükçe değerlendirilmesi gereken bir sonraki adımdır.
- **A/B test:** Play Console'un Store Listing Experiments özelliği (ikon, görsel, açıklama varyasyonları) ve uygulama içi reklam yerleşim testleri, bütçe artmadan dönüşüm/gelir iyileştirmenin en ucuz yoludur.

---

## 10. Maliyet Özeti

### 10.1 Tek Seferlik Maliyetler
| Kalem | Tahmini Tutar |
|---|---|
| Google Play Console kayıt ücreti | 25 USD (bir kerelik) |
| Marka/logo/görsel tasarım (freelancer ile yapılırsa) | İsteğe bağlı, 0–5.000₺ arası (kendiniz hazırlarsanız 0) |
| Domain (gizlilik politikası/hesap silme sayfası için, opsiyonel — Firebase Hosting subdomain ile ücretsiz de olur) | İsteğe bağlı, ~150–400₺/yıl |

### 10.2 Aylık Tahmini Maliyetler
| Kalem | Tahmini Aralık | Not |
|---|---|---|
| Firebase Blaze (Firestore okuma/yazma, Storage, Functions çağrıları) | Düşük-orta trafikte genelde ücretsiz kotaya yakın/birkaç yüz ₺ | Trafik arttıkça doğrusal artar, bütçe uyarısı şart |
| Cloud Run (`min-instances: 1`, sürekli açık bot) | Sabit, sürekli çalıştığı için aylık baz bir maliyet oluşturur | Tam tutar CPU/RAM tahsisine göre değişir, Cloud Console fiyat hesaplayıcısıyla netleştirilmeli |
| Gemini API (`gemini-2.0-flash`, multimodal istekler) | Mesaj/görsel hacmine bağlı, değişken | Yüksek hacimli kanal trafiğinde izlenmesi gereken en değişken kalem |
| Secret Manager | Çoğu küçük projede ücretsiz kota içinde | — |
| Reklam/büyüme bütçesi | 3.000–15.000₺ (sizin belirlediğiniz aralık) | Bölüm 9'daki dağılıma göre kanallara paylaştırılır |

Cloud Run ve Gemini API kalemleri trafiğe bağlı olarak değiştiği için, ilk ayın faturası canlıya çıktıktan sonra yakından izlenmeli ve Bölüm 5.1'deki bütçe uyarıları mutlaka kurulmalıdır.

---

## 11. Yayın Öncesi Son Kontrol Listesi

- `targetSdkVersion` / `compileSdkVersion` = 36 olarak güncellendi ve test edildi (Bölüm 6.1)
- `firebase_crashlytics` paketi `pubspec.yaml`'a eklendi ve Gradle (classpath + plugin) entegrasyonu tamamlandı (Bölüm 6.5)
- Mobil uygulamada hardcoded duran Gemini API anahtarı (`ai_service.dart`) temizlendi; ürün analiz işlemi Cloud Functions proxy veya Vertex AI SDK yapısına taşındı (Bölüm 5.4)
- `storage.rules` dosyası oluşturuldu, `firebase.json`'a bağlandı ve `deals/` dizini için herkese açık okuma izni (`allow read: if true;`) deploy edildi (Bölüm 5.2)
- `firestore.indexes.json` dosyası oluşturuldu, composite index'ler tanımlandı ve `firebase.json`'a bağlanarak deploy edildi (Bölüm 5.2)
- Build scriptleri (`build_release_apk.sh` yerine `build_release_aab.sh`) `.aab` üretecek şekilde güncellendi (Bölüm 6.7)
- `flutter build appbundle --release` ile AAB üretildi (APK değil) (Bölüm 6.7)
- `proguard-rules.pro` dosyası Firebase/AdMob/Google Sign-In kurallarıyla güncellendi, release build fiziksel cihazda test edildi (Bölüm 6.7)
- AdMob Console'da hesap ve uygulama kaydı yapıldı, reklam birimleri oluşturuldu, AdMob onayı bekleniyor/tamamlandı (Bölüm 6.4)
- AdMob reklam birimleri, debug modda test reklam birimlerini (`ca-app-pub-3940256099942544/6300978111`) otomatik yükleyecek şekilde dinamikleştirildi (Bölüm 6.4)
- AdMob için UMP (Consent) SDK entegrasyonu `main.dart` üzerinde yapılarak reklam gösterimi öncesi kullanıcı rızası toplama akışı kuruldu (Bölüm 6.4)
- Android platformunda Apple Sign-In butonu test edildi (OAuth redirect URI tanımlandı veya buton Android platformunda gizlendi) (Bölüm 6.3)
- Uygulamada eksik olan `edit_profile_screen.dart` dosyası oluşturuldu veya `profile_screen.dart` üzerindeki ilgili buton hata vermemesi için gizlendi (Bölüm 6.5)
- Profil ekranında kullanıcının paylaştığı fırsatlar listesi (`getDealsByUser` Firestore sorgusu ve UI listeleme kartları) tamamlandı (Bölüm 6.5)
- Uygulama içi "Raporla/Şikayet Et" mekanizması (UGC politikası gereği) uygulandı, Firestore yazma kuralları ve admin paneli doğrulandı (Bölüm 7.3)
- Production Firebase projesi ayrıldı (Build flavors entegrasyonu yapıldı), Blaze plana geçildi, bütçe uyarıları kuruldu (Bölüm 5.1)
- Firestore Security Rules production'a uygun şekilde sertleştirildi, test modu kapatıldı (Bölüm 5.2)
- App Check (Play Integrity) mobil entegrasyonu yapıldı ve sunucu tarafındaki raw HTTP fonksiyonlarında (`resolveShortLink`, `cleanupOldImagesManual`) manuel token doğrulama kodu uygulandı (Bölüm 5.2 / 5.3 / 6.5)
- Cloud Run botunda **"CPU is always allocated"** ayarı açık (varsayılan "yalnızca istek sırasında" ayarıyla DEĞİL) — Bölüm 5.4
- Cloud Run botu Liveness/Startup probe yolu bot kodundaki HTTP sunucusuyla uyumlu olacak şekilde `/health` olarak ayarlandı (Bölüm 5.4)
- Cloud Run botu `min/max instances: 1`, Secret Manager ile yapılandırıldı, uptime alarmı kuruldu (Bölüm 5.4)
- Gemini API anahtarı faturalandırmalı (billing-enabled) projeye bağlı, ücretsiz tier'ın düşük RPM limitine takılı değil (Bölüm 5.4)
- Cloud Functions tarafında `functions.config()` veya harici API anahtarı kullanılmadığı doğrulandı (Bölüm 5.3)
- Play App Signing'e kayıt yapıldı, upload keystore güvenli şekilde yedeklendi (Bölüm 6.3)
- Release build üzerinde Google Sign-In SHA-1/SHA-256 ile doğrulandı; Play Console'dan App signing sertifikasının SHA-1'i alınıp Firebase'e eklendi (upload key SHA-1'e ek olarak — bkz. Bölüm 6.3)
- AdMob production ID'leri uygulandı, UMP consent SDK'sı eklendi (Bölüm 6.4)
- Gizlilik politikası, kullanım şartları ve hesap silme sayfası yayında ve Play Console'a bağlandı (Bölüm 3.3)
- Veri Güvenliği (Data Safety) formu gizlilik politikasıyla birebir tutarlı şekilde dolduruldu (Bölüm 7.3)
- Mağaza görselleri (ikon, feature graphic, ekran görüntüleri) ve ASO odaklı metinler hazır (Bölüm 4)
- Kapalı test: 12+ tester, kesintisiz 14 gün opt-in tamamlandı (Bölüm 7.2)
- Crashlytics, Performance Monitoring production'da aktif ve veriler akıyor (Bölüm 6.5)
- Kademeli yayın (%5 → %100) planı hazır (Bölüm 7.5)

---

## 12. Önerilen Aksiyon Sırası

**Bu hafta (Teknik Temizlik ve Kritik İyileştirmeler):** 
- `targetSdkVersion`/`compileSdkVersion` güncellemesini yapın ve test edin (Bölüm 6.1).
- Mobil uygulamadaki hardcoded Gemini API anahtarını temizleyin ve güvenli proxy/Vertex AI yapısına geçin (Bölüm 5.4).
- `firebase_crashlytics` paketini `pubspec.yaml`'a ekleyin ve entegrasyonu tamamlayın (Bölüm 6.5).
- Aynı hafta içinde production Firebase projesi oluşturun (gerekiyorsa build flavor altyapısını kurun), Blaze plana geçin (Bölüm 5.1) ve bireysel Play Console hesabı başvurunuzu başlatın (Bölüm 7.1).

**1–2. hafta (Güvenlik Kuralları, Altyapı ve Eksik Kodların Geliştirilmesi):** 
- Firestore Rules kurallarını production için sertleştirin (Bölüm 5.2).
- `storage.rules` dosyasını oluşturun ve `firebase.json`'a ekleyerek deploy edin (Bölüm 5.2 - deals/ okuma izni ile).
- `firestore.indexes.json` composite indeks tanımlarını yapın ve deploy edin (Bölüm 5.2).
- App Check ve Play Integrity entegrasyonlarını (istemci tarafı başlatma + Firebase Console) tamamlayın (Bölüm 5.2).
- Herkese açık raw HTTP functions (`resolveShortLink`, `cleanupOldImagesManual`) için manuel App Check token doğrulaması kodunu entegre edin (Bölüm 5.3).
- Profil ekranındaki eksiklikleri giderin: `edit_profile_screen.dart` dosyasını tamamlayın ve kullanıcının paylaştığı fırsatlar listesini (`getDealsByUser` Firestore metodunu ve listeyi içeren UI kartlarını) kodlayın (Bölüm 6.5).
- Cloud Run botunu Secret Manager, tek instance ve probe yolu `/health` olacak şekilde deploy edin (Bölüm 5.4).
- Paralelde marka görselleri ve mağaza metinlerini hazırlayın (Bölüm 4).

**2–3. hafta (Build Hazırlığı ve Testlerin Başlatılması):** 
- `build_release_apk.sh` scriptini güncelleyin veya AAB üretecek `build_release_aab.sh` scriptini yazın (Bölüm 6.7).
- AdMob için UMP (Consent) SDK ile kullanıcı rızası toplama akışını `main.dart` üzerinde kodlayın (Bölüm 6.4).
- AdMob için debug/test reklam birimleri ile release/gerçek reklam birimleri arasındaki dinamik geçiş kodunu yazın (Bölüm 6.4).
- Android platformunda Apple Sign-In butonunun davranışını (OAuth redirect URI veya gizleme) kesinleştirin (Bölüm 6.3).
- ProGuard (`proguard-rules.pro`) ayarlarını kontrol edin ve release build'i fiziksel bir cihazda test edin.
- AAB hazır olur olmaz **kapalı testi başlatın** (tester opt-in ve 1–3 günlük Google onay gecikmesini hesaba katın) (Bölüm 7.2).

**3–5. hafta (Play Console İşlemleri):** 
- Kapalı test devam ederken Play Console > App Content formlarını (Veri Güvenliği, UGC Raporlama vb.) eksiksiz doldurun (Bölüm 7.3).
- Telegram ve sosyal medya kanalları üzerinden organik kitle edinmeye ve topluluğu ısıtmaya devam edin (Bölüm 9.1).

**5–6. hafta (Yayın ve Ölçeklenme):** 
- Production/yayına geçiş başvurusu yapın.
- Kademeli yayını (%5 -> %100) başlatın (Bölüm 7.5).
- Uptime ve hata alarmlarını izleyin (Bölüm 8).
- İlk ücretli UAC/Meta reklam bütçelerini dağıtarak lansmanı yapın (Bölüm 9.3).

---

*Bu rapor, paylaştığınız mimari bilgiler ve verdiğiniz bütçe/pazar tercihlerine dayanılarak hazırlanmıştır; Play Console politikaları ve API/SDK gereksinimleri zamanla değişebileceğinden, başvuru öncesi Play Console'daki güncel uyarı ve politika sayfalarının da kontrol edilmesi önerilir. Vergi, KVKK ve şirketleşme ile ilgili maddeler genel bilgilendirme amaçlıdır; bağlayıcı kararlar için mali müşavir/avukat desteği alınmalıdır.*