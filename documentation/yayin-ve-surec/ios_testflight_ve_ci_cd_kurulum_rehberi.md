# 🚀 FırsatKolik — Sıfır Mac ile Uçtan Uca iOS TestFlight ve CI/CD Dağıtım Rehberi (Master Edition)

Bu el kitabı; **Windows 11 bilgisayar ve Android telefona sahip**, yerel bir Mac cihazı olmayan bir geliştiricinin, bulut tabanlı **GitHub Actions (macOS Apple Silicon M2 runner)** ve sektör standardı **Fastlane (App Store Connect API v1)** altyapısını kullanarak FırsatKolik uygulamasını arkadaşından ödünç alacağı gerçek bir iPhone üzerinde uçtan uca nasıl test edebileceğini adım adım anlatmaktadır.

Tüm kod yapısı, mevcut projeden tamamen izole edilmiş [`ios_ci/`](file:///d:/firsatkolik/ios_ci/) klasöründe ve [`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml) iş akışında kurulmuştur.

---

## 📑 İçindekiler
1. [🔬 Teknik Araştırma ve Geri Bildirimlerin Doğrulanması](#1--teknik-araştırma-ve-geri-bildirimlerin-doğrulanması)
2. [🌟 Mimarî Strateji: Sıfır Mac ile iOS Test Döngüsü](#2--mimarî-strateji-sıfır-mac-ile-ios-test-döngüsü)
3. [📁 İzole Altyapı ve Dosya Ağacı (`ios_ci/`)](#3--izole-altyapı-ve-dosya-ağacı-ios_ci)
4. [💰 GitHub Actions 10x macOS Dakika Kotası ve Tasarruf Stratejisi](#4--github-actions-10x-macos-dakika-kotası-ve-tasarruf-stratejisi)
5. [📋 Manuel Adım 1: Apple Developer Portal Hazırlıkları](#5--manuel-adım-1-apple-developer-portal-hazırlıkları)
6. [🔑 Manuel Adım 2: "Yumurta mı Tavuk mu" Paradoksu ve Windows'ta OpenSSL ile Sertifika (.p12) Üretimi](#6--manuel-adım-2-yumurta-mı-tavuk-mu-paradoksu-ve-windowsta-openssl-ile-sertifika-p12-üretimi)
7. [🤖 Manuel Adım 3: App Store Connect API Anahtarı (.p8) Üretimi](#7--manuel-adım-3-app-store-connect-api-anahtarı-p8-üretimi)
8. [🔔 Manuel Adım 4: Apple Push Notification Service (APNs) Anahtarı (.p8) ve Firebase Yapılandırması](#8--manuel-adım-4-apple-push-notification-service-apns-anahtarı-p8-ve-firebase-yapılandırması)
9. [🔐 Manuel Adım 5: Base64 Dönüşümü ve GitHub Secrets Yapılandırması](#9--manuel-adım-5-base64-dönüşümü-ve-github-secrets-yapılandırması)
10. [📱 Manuel Adım 6: App Store Connect'te Uygulama Kaydı ve Dahili Test Grubu Açma](#10--manuel-adım-6-app-store-connectte-uygulama-kaydı-ve-dahili-test-grubu-açma)
11. [🚀 Manuel Adım 7: GitHub Actions Üzerinden Derleme ve Fastlane ile TestFlight'a Yükleme](#11--manuel-adım-7-github-actions-üzerinden-derleme-ve-fastlane-ile-testflighta-yükleme)
12. [📲 Manuel Adım 8: Ödünç Alınan iPhone'da Canlı TestFlight Kurulumu ve Doğrulama Protokolü](#12--manuel-adım-8-ödünç-alınan-iphoneda-canlı-testflight-kurulumu-ve-doğrulama-protokolü)
13. [⚠️ Sık Karşılaşılan Hatalar, Uyarılar ve Anında Çözümler](#13-️-sık-karşılaşılan-hatalar-uyarılar-ve-anında-çözümler)

---

## 1. 🔬 Teknik Araştırma ve Geri Bildirimlerin Doğrulanması

Süreç tasarlanırken tarafımıza iletilen teknik tavsiyeler resmi Apple belgeleri, GitHub Actions dökümanları ve açık kaynak araçlar üzerinden titizlikle araştırılmış ve doğrulanmıştır:

### A. Tavsiye 1 Analizi: `xcrun altool` Deprecation Durumu ve Fastlane
* **Teknik Doğrulama:**
  * Apple, `xcrun altool` aracını macOS Notarization için resmi olarak **1 Kasım 2023** tarihi itibarıyla kaldırmıştır (Bkz: [Apple Technical Note TN3147](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool)).
  * App Store ve TestFlight yüklemelerinde `altool` komutu halen bazı Xcode sürümlerinde çalışsa da Apple, geliştiricileri modern **App Store Connect REST API v1** arayüzüne yönlendirmektedir.
  * *Düzeltme & Netleştirme:* Tavsiyede adı geçen `xcrun ditto` (yalnızca yerel dosya sıkıştırma/kopyalama aracıdır) ve `xcrun simctl` (yalnızca yerel iOS simülatör kontrol aracıdır) TestFlight'a paket yükleyemez.
  * **Uygulanan Çözüm:** Sektör standardı olan **Fastlane (`Fastfile` & `upload_to_testflight / pilot`)** altyapımıza birinci sınıf yükleyici olarak entegre edilmiştir. Fastlane doğrudan Apple'ın resmi REST API'sini kullanır; `altool` komut satırı aracının yürürlükten kalkmasından kesinlikle etkilenmez. Ayrıca her ihtimale karşı `xcrun altool` yedek (fallback) mekanizması olarak script içerisine yerleştirilmiştir.

### B. Tavsiye 2 Analizi: "Yumurta mı Tavuk mu" Sertifika Paradoksu
* **Teknik Doğrulama:**
  * Apple'ın resmi geliştirici rehberleri, kod imzalama sertifikası üretmek için bir Mac bilgisayarınızın olduğunu ve macOS üzerindeki "Keychain Access (Anahtar Zinciri Erişimi)" programından "Sertifika Yetkilisinden Sertifika İste (CSR)" yapacağınızı varsayar.
  * Mac'i olmayan bir geliştirici Apple portalına yükleyecek CSR oluşturamaz; Mac olmadan sertifika alamaz, sertifika olmadan da buluttaki Mac'te derleme yapamaz!
  * **Uygulanan Çözüm:** Windows 11 üzerinde `openssl` aracı kullanılarak 2048-bit RSA anahtarı ve geçerli bir `.certSigningRequest` (CSR) dosyası üretilir. Apple'dan indirilen `.cer` dosyası yine Windows'ta şifreli `.p12` formatına paketlenir. Bu yöntem Apple tarafından %100 geçerli kabul edilir ve Mac zorunluluğunu tamamen ortadan kaldırır.

### C. Tavsiye 3 Analizi: GitHub Actions 10x macOS Dakika Çarpanı
* **Teknik Doğrulama:**
  * GitHub Free hesapları, gizli (private) depolar için aylık **2.000 dakika** ücretsiz CI/CD süresi tanımlar.
  * Ancak GitHub, sanal donanım maliyetleri nedeniyle işletim sistemlerine farklı çarpanlar uygular:
    * Linux: **1x** (Aylık 2.000 dakika)
    * Windows: **2x** (Aylık 1.000 dakika)
    * macOS (`macos-14`, Apple Silicon M2): **10x çarpan!**
  * Bu matematik uyarınca aylık ücretsiz macOS süreniz net **200 dakikadır** (2.000 / 10 = 200 dk).
  * Standart bir Flutter iOS derlemesi 12-15 dakika sürdüğü için, ayda yalnızca **~13 ila 16 derleme** hakkınız kalır.
  * Eğer yükleme aracı Apple'ın bulutta paketi işlemesini (processing) beklerse (ortalama 15 dakika sürer), tek bir derleme 30 dakikaya çıkabilir ve tek seferde 300 dakika (tüm aylık kotayı) tüketebilir!
  * **Uygulanan Savunma ve Optimizasyonlar:**
    1. **CocoaPods Önbellekleme (`actions/cache@v4`):** `ios/Pods` ve `~/Library/Caches/CocoaPods` önbelleğe alınarak derleme süresi 15 dakikadan **~7-8 dakikaya** indirildi. Bu sayede aylık derleme kapasitesi **25+ adede** çıkarıldı.
    2. **`skip_waiting_for_build_processing: true`:** Fastlane konfigürasyonumuz, paket Apple sunucularına iletildiği anda derlemeyi başarılı sayıp GitHub Actions makinesini kapatır. Apple'ın 15 dakikalık işleme süresini beklemez; böylece fazladan 150 dakika harcanması kesin olarak engellenir.
    3. **Yalnızca Manuel Tetikleme (`workflow_dispatch`):** İş akışı asla her `git push`'ta veya PR'da çalışmaz; yalnızca siz TestFlight sürümü çıkarmak istediğinizde butona basarak çalıştırırsınız.
    4. **Sıfır Dolar Harcama Limiti:** GitHub fatura ayarlarınızda "Spending Limit" $0.00 olarak tutulur; kotanız dolsa dahi kredi kartınızdan asla 1 kuruş çekilmez.

---

## 2. 🌟 Mimarî Strateji: Sıfır Mac ile iOS Test Döngüsü

```mermaid
graph LR
    subgraph "💻 Geliştirici Ortamı (Windows 11)"
        Code[Flutter Kodları & Git Push]
        OpenSSL[OpenSSL ile Windows'ta CSR & .p12]
        Secrets[PowerShell ile Base64 Secrets]
    end

    subgraph "☁️ GitHub Bulut Altyapısı (macOS M2 Runner)"
        GHA[GitHub Actions: macos-14]
        Cache[CocoaPods Cache - Süre %50 Düşer]
        FlutterBuild[Flutter IPA Derleme & İmzalama]
        Fastlane[Fastlane Pilot - App Store Connect API]
    end

    subgraph "🍏 Apple Bulut Ekosistemi"
        ASC[App Store Connect REST API v1]
        TF[Apple TestFlight Sunucusu]
    end

    subgraph "📱 Canlı Test (Ödünç iPhone)"
        TestFlightApp[TestFlight Mobil Uygulaması]
        LiveApp[FırsatKolik Canlı Test Sürümü]
    end

    Code -->|Push| GHA
    Secrets -->|Repository Secrets| GHA
    OpenSSL -->|Sertifika| ASC
    GHA --> Cache --> FlutterBuild --> Fastlane -->|AuthKey.p8| ASC
    ASC --> TF -->|OTA Dağıtım| TestFlightApp --> LiveApp
```

---

## 3. 📁 İzole Altyapı ve Dosya Ağacı (`ios_ci/`)

Bu süreç için projenizde oluşturulan tüm izole dosyalar şunlardır:

d:\firsatkolik\
├── 📁 .github/workflows/
│   └── 📄 ios_testflight_deploy.yml         # macOS-latest önbellekli, 30 dk timeout'lu iş akışı
│
├── 📁 ios/Share Extension/                  # Trendyol vb. dış paylaşımları yakalayan saf yerel uzantı
│   ├── 📄 ShareViewController.swift         # Saf Swift (Zero-Pod) Paylaşım denetleyicisi & UserDefaults köprüsü
│   ├── 📄 Info.plist                        # Extension aktivasyon kuralları ve AppGroupId eşleşmesi
│   └── 📄 ShareExtension.entitlements       # group.com.firsatkolik.app App Groups yetkilendirmesi
│
├── 📁 ios_ci/                                # Tamamen izole edilmiş CI/CD klasörü
│   ├── 📄 README.md                          # Master mimari ve operasyon el kitabı
│   ├── 📄 Fastfile                           # Fastlane App Store Connect API yükleme hattı
│   ├── 📄 ExportOptions_prod.plist           # Production (com.firsatkolik.app + ShareExtension) imzalama profili
│   ├── 📄 ExportOptions_dev.plist            # Development imzalama profili
│   └── 📁 scripts/
│       ├── 📄 setup_keychain.sh              # macOS geçici anahtar zinciri ve profil kurucu
│       ├── 📄 patch_modular_headers.py       # Clang 19, Xcode 16 ve FlutterFire uyumluluk yamacısı
│       └── 📄 upload_testflight.sh           # Fastlane (ve yedek xcrun altool) yükleme betiği
```

---

## 4. 💰 GitHub Actions 10x macOS Dakika Kotası ve Tasarruf Stratejisi

GitHub Actions'ı ücretsiz ve sürpriz faturasız kullanabilmeniz için bilmeniz gereken kurallar:

| Metrik | Açıklama |
| :--- | :--- |
| **Aylık Ücretsiz Kota (Private Repo)** | 2.000 dakika (Linux bazında). |
| **macOS Çarpanı (M2)** | **10x** (1 dakika = 10 dakika tüketir). |
| **Net macOS Süresi** | **200 dakika / ay**. |
| **Önbelleksiz Derleme Süresi** | ~14-16 dakika (Ayda ~13 derleme hakkı). |
| **Önbellekli Derleme Süresi (Bizim Sistemimiz)** | **~7-8 dakika (Ayda ~25+ derleme hakkı!)**. |
| **Harcama Güvenliği** | GitHub > Settings > Billing > Spending Limit = **$0.00**. |

> [!TIP]
> **Tasarruf Tavsiyesi:** Geliştirme yaparken her commit'te TestFlight build'i almayın. Özellikleri yerel Android cihazınızda test edip geliştirmeyi tamamlayın. Yalnızca iOS'a özel canlı doğrulama yapacağınız zaman GitHub'dan "Run workflow" butonuna basın.

---

## 5. 📋 Manuel Adım 1: Apple Developer Portal Hazırlıkları

TestFlight kullanabilmek için aktif bir **Apple Developer Program** hesabınızın olması gerekir. Bu adımda ana uygulama, App Group ve Share Extension için gerekli kimlikler oluşturulur:

### 1.1. App Group Oluşturma (Ortak Posta Kutusu)
1. [developer.apple.com/account](https://developer.apple.com/account) adresine gidin -> **Certificates, Identifiers & Profiles** -> **Identifiers** sekmesine gelin.
2. Mavi **(+)** butonuna basın -> Listeden **App Groups** seçin -> **Continue**.
3. **Description:** `FirsatKolik App Group`
4. **Identifier:** `group.com.firsatkolik.app` *(Projeyle harfi harfine aynı olmalıdır)*
5. **Continue** -> **Register** diyerek kaydedin.

### 1.2. Ana Uygulama App ID'sini Oluşturma (`com.firsatkolik.app`)
1. **Identifiers** sekmesinde tekrar **(+)** butonuna basın -> **App IDs** -> **App** -> **Continue**.
2. **Description:** `FirsatKolik Mobile App`
3. **Bundle ID:** **Explicit** seçin ve tam olarak `com.firsatkolik.app` yazın.
4. **Capabilities (Yetenekler)** listesinden şu 4 kutuyu işaretleyin:
   * ✅ **Push Notifications** (FCM APNs bildirimleri için zorunlu)
   * ✅ **Sign in with Apple** (Apple ile Giriş Yap butonu için zorunlu)
   * ✅ **Associated Domains** (Universal Deeplink: `firsatkolik.app` için zorunlu)
   * ✅ **App Groups** (Share Extension ile ortak veri havuzu için zorunlu)
5. **Continue** ve ardından **Register** butonuna basarak kaydedin.
6. Listeden `com.firsatkolik.app` kaydına tıklayın, **App Groups** yanındaki **Configure** butonuna basarak `group.com.firsatkolik.app` grubunu seçip **Save** deyin.

### 1.3. Share Extension App ID'sini Oluşturma (`com.firsatkolik.app.ShareExtension`)
1. **Identifiers** sekmesinde tekrar **(+)** butonuna basın -> **App IDs** -> **App** -> **Continue**.
2. **Description:** `FirsatKolik Mobile App ShareExtension`
3. **Bundle ID:** **Explicit** seçin ve tam olarak `com.firsatkolik.app.ShareExtension` yazın.
4. **Capabilities** listesinden **App Groups** kutucuğunu işaretleyin -> **Continue** -> **Register**.
5. Listeden yeni oluşturulan `com.firsatkolik.app.ShareExtension` kaydına tıklayın, **App Groups** yanındaki **Configure** butonuna basarak `group.com.firsatkolik.app` grubunu bağlayıp **Save** deyin.

---

## 6. 🔑 Manuel Adım 2: "Yumurta mı Tavuk mu" Paradoksu ve Windows'ta OpenSSL ile Sertifika (.p12) Üretimi

> [!NOTE]
> **Yumurta mı Tavuk mu Çözümü:** Apple belgeleri sertifika oluşturmak için Mac'teki "Keychain Access" uygulamasını şart koşar. Mac'iniz olmadığı için bu adımı Windows 11 üzerinde **OpenSSL** (Git Bash veya PowerShell) ile 3 dakikada çözüyoruz.

### 2.1. Windows'ta CSR (Certificate Signing Request) Oluşturma
Windows terminalinizi (PowerShell veya Git Bash) açın ve geçici bir klasör oluşturun:

```bash
mkdir C:\ios_certs
cd C:\ios_certs

# 1. 2048-bit Private Key üretin:
openssl genrsa -out firsatkolik_distribution.key 2048

# 2. Apple'a sunulacak CSR dosyasını üretin:
openssl req -new -key firsatkolik_distribution.key -out CertificateSigningRequest.certSigningRequest -subj "/emailAddress=destek@firsatkolik.app, CN=FirsatKolik Distribution, C=TR"
```

### 2.2. Apple Developer Portal'dan Sertifikayı İndirme
1. Apple Developer Portal'da **Certificates** sekmesine gidin.
2. **(+)** butonuna tıklayın -> **Apple Distribution** seçeneğini işaretleyip **Continue** deyin.
3. Az önce ürettiğiniz `CertificateSigningRequest.certSigningRequest` dosyasını yükleyin ve **Generate** deyin.
4. Oluşan sertifikayı bilgisayarınıza indirin (dosya adı: `distribution.cer`). Bu dosyayı `C:\ios_certs\` klasörüne taşıyın.

### 2.3. Windows'ta `.cer` Dosyasını Şifreli `.p12` Formatına Dönüştürme
GitHub Actions'ın kod imzalamada kullanabilmesi için sertifikanın private key ile birleştirilip `.p12` yapılması gerekir:

```bash
cd C:\ios_certs

# 1. DER formatındaki .cer dosyasını PEM formatına çevirin:
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM

# 2. Private key ile PEM'i birleştirip şifreli .p12 üretin:
# (Bu komut sizden bir parola isteyecektir, örn: "FirsatKolik2026!", bu parolayı bir yere not edin!)
openssl pkcs12 -export -inkey firsatkolik_distribution.key -in distribution.pem -out firsatkolik_distribution.p12
```
Artık elinizde GitHub Actions'ın kullanacağı **`firsatkolik_distribution.p12`** dosyanız var!

### 2.4. Ana Uygulama Provisioning Profile Üretme ve İndirme
1. Apple Developer Portal > **Profiles** sekmesine gidin.
2. **(+)** butonuna basın -> Dağıtım türü olarak **App Store** (TestFlight için bu seçilir) seçin -> **Continue**.
3. **App ID:** `com.firsatkolik.app` seçin -> **Continue**.
4. **Certificates:** Az önce oluşturduğunuz Apple Distribution sertifikasını seçin -> **Continue**.
5. **Profile Name:** `FirsatKolik AppStore Profile` yazın ve **Generate** deyin.
6. Oluşan profili indirin (`FirsatKolik_AppStore_Profile.mobileprovision`). Bu dosyayı `C:\ios_certs\` klasörüne koyun.

### 2.5. Share Extension Provisioning Profile Üretme ve İndirme
1. Yine **Profiles** sekmesinde mavi **(+)** butonuna basın.
2. Dağıtım türü: **App Store** -> **Continue**.
3. **App ID:** `com.firsatkolik.app.ShareExtension` seçin -> **Continue**.
4. **Certificates:** Apple Distribution sertifikanızı seçin -> **Continue**.
5. **Profile Name:** `FirsatKolik ShareExtension Profile` yazın ve **Generate** deyin.
6. Oluşan profili indirin (`FirsatKolik_ShareExtension_Profile.mobileprovision`). Bu dosyayı da `C:\ios_certs\` klasörüne koyun.

---

## 7. 🤖 Manuel Adım 3: App Store Connect API Anahtarı (.p8) Üretimi

Fastlane ve GitHub Actions'ın Apple sunucularına bağlanırken SMS/2FA kodu sormadan doğrudan TestFlight'a yükleme yapabilmesi için modern API anahtarı üretilir:

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) adresine gidin.
2. Üst menüden **Users and Access (Kullanıcılar ve Erişim)** > **Integrations (Entegrasyonlar)** > **App Store Connect API** sekmesine geçin.
3. Mavi **(+)** butonuna tıklayın:
   * **Name:** `Fastlane CI CD`
   * **Access:** `App Manager` veya `Admin` seçin -> **Generate**.
4. Sayfada iki kritik bilgi belirecektir:
   * **Issuer ID:** Sayfanın en üstünde yer alan uzun UUID formatındaki kod (Örn: `69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
   * **Key ID:** Oluşturduğunuz anahtarın 10 haneli kimliği (Örn: `2X9R4ABCD2`).
5. Anahtar satırındaki **Download API Key** butonuna tıklayarak **`AuthKey_XXXXXXXXXX.p8`** dosyasını indirin.
   *(ÖNEMLİ: Apple bu dosyayı güvenlik gereği yalnızca 1 kez indirmenize izin verir. Dosyayı kaybetmeyin!)*

---

## 8. 🔔 Manuel Adım 4: Apple Push Notification Service (APNs) Anahtarı (.p8) ve Firebase Yapılandırması

> [!IMPORTANT]
> **App Store Connect API Key vs APNs Key Ayrımı:**
> - **App Store Connect API Key (`AuthKey_XUVRF9F2Y3.p8`):** Yalnızca GitHub Actions ve Fastlane'in derlenen `.ipa` paketini TestFlight'a yüklemesi içindir. Bildirimlerle **hiçbir ilgisi yoktur**.
> - **APNs Authentication Key (`AuthKey_KJ2TZ9F8SG.p8`):** Firebase Cloud Messaging (FCM) sunucularının Apple APNs ağına bağlanarak iOS cihazların kilit ekranına ve bildirim merkezine push iletmesini sağlayan kriptografik anahtardır.

### 4.1. Apple Developer Portal'da APNs Anahtarı Oluşturma
1. [developer.apple.com/account/resources/authkeys/list](https://developer.apple.com/account/resources/authkeys/list) adresine gidin.
2. Sol menüden **Certificates, Identifiers & Profiles** > **Keys** sekmesini açın.
3. Mavi **(+)** butonuna tıklayın:
   - **Key Name:** `FirsatKolik APNs Key`
   - Listeden **Apple Push Notifications service (APNs)** kutucuğunu işaretleyin.
   - Sağındaki **Configure** butonuna tıklayın:
     - **Environment:** **`Sandbox & Production`** seçin *(Kritik: Varsayılan Sandbox bırakılırsa TestFlight'ta bildirimler düşmez; bu seçenek hem yerel test hem TestFlight/App Store'u kapsar)*.
     - **Key Restriction:** `Team Scoped (All Topics)` olarak bırakın.
     - **Save** butonuna basın.
4. **Continue** ve ardından **Register** butonuna basın.
5. **Download** butonuna tıklayarak **`AuthKey_KJ2TZ9F8SG.p8`** dosyasını bilgisayarınıza indirin.
   *(ÖNEMLİ: Bu dosya da Apple tarafından yalnızca 1 kez indirilebilir. Dosyayı `d:\firsatkolik\ios\Push_Notifications\` klasöründe güvenle saklayın).*
6. Sayfada yazan 10 haneli **Key ID**'yi (`KJ2TZ9F8SG`) ve sağ üstteki **Team ID**'nizi (`973W9DTDY9`) not edin.

### 4.2. Firebase Console'a APNs Anahtarını Yükleme
Firebase Console'a giderek bu işlemi sırasıyla **her iki projeniz** için yapın (**`sicak-firsatlar-e6eae`** ve **`firsatkolik-prod-e6eae`**):
1. [Firebase Console](https://console.firebase.google.com/) -> Sol üstteki dişli simgesi -> **Proje Ayarları (Project Settings)**.
2. Üstteki sekmelerden **Cloud Messaging** sekmesini açın.
3. Sayfanın alt kısmındaki **Apple uygulama yapılandırması (Apple app configuration)** tablosuna gelin:
   - Sol tarafta `com.firsatkolik.app` uygulamasının seçili olduğundan emin olun.
   - **APNs Kimlik Doğrulama Anahtarı (APNs Authentication Key)** tablosunda:
     - **Development APNs auth key** yanındaki **Upload** butonuna tıklayın: `AuthKey_KJ2TZ9F8SG.p8` dosyasını seçin, Key ID (`KJ2TZ9F8SG`) ve Team ID (`973W9DTDY9`) girip kaydedin.
     - **Production APNs auth key** yanındaki **Upload** butonuna da tıklayın: **Yine aynı** `AuthKey_KJ2TZ9F8SG.p8` dosyasını seçin, aynı Key ID ve Team ID ile kaydedin.
   - **APNs Sertifikaları (APNs Certificates) Bölümü:** Bu bölümü **TAMAMEN BOŞ** bırakın. Modern `.p8` anahtarı yıllık yenileme gerektiren eski sertifikaların yerini almıştır.

### 4.3. Mimari ve Kod Seviyesinde Tamamlanan Güvenceler
1. **Cloud Functions APNs Alert Formatı ([`functions/index.js`](file:///d:/firsatkolik/functions/index.js)):** Birebir mesajlaşmada (`onUserMessageCreated`) Android için `data-only` yapısı korunurken, iOS APNs payload'ına `'apns-push-type': 'alert'`, `aps.alert: { title: '💬 ...', body: '...' }`, `aps.sound: 'default'` ve `aps.badge: 1` eklenmiştir. Bu sayede iOS işletim sistemi kilit ekranında doğrudan bildirim kartını gösterir.
2. **Çift Kanallı Anlık In-App Afiş Motoru ([`lib/services/notification_service.dart`](file:///d:/firsatkolik/lib/services/notification_service.dart)):** Uygulama açıkken (foreground) APNs gecikmelerinden bağımsız olarak, Firestore `messages` koleksiyonundaki `receiverId == userId` anlık dinleyicisi (`_setupForegroundMessageListener()`) sayesinde 0 ms gecikmeyle `InAppMessageBanner.show()` tetiklenir (Aktif sohbetteyse bastırılır, diğer ekranlarda afiş gösterilir).
3. **Natif `AppDelegate.swift` Delegasyonu ([`ios/Runner/AppDelegate.swift`](file:///d:/firsatkolik/ios/Runner/AppDelegate.swift)):** `UNUserNotificationCenterDelegate` metodları (`userNotificationCenter(_:willPresent:withCompletionHandler:)`) `[.banner, .list, .badge, .sound]` sunum seçenekleriyle sisteme bağlanmıştır.
4. **CI/CD `aps-environment` Production Eşitlemesi ([`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml)):** GitHub Actions TestFlight dağıtımında `Runner.entitlements` içindeki `aps-environment` değeri derleme anında otomatik `production` yapılmaktadır.

---

## 9. 🔐 Manuel Adım 5: Base64 Dönüşümü ve GitHub Secrets Yapılandırması

Sertifikaları ve profilleri GitHub Secrets'a dosya olarak değil, **Base64 metin dizgisi** olarak ekleriz.

### 5.1. Windows PowerShell ile Base64 Metinlerini Alma
Windows PowerShell açın ve şu komutları sırayla çalıştırın:

```powershell
# 1. P12 Sertifikasını Base64 yapıp panoya kopyalama:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ios_certs\firsatkolik_distribution.p12")) | Set-Clipboard
# (Panodaki P12 sertifikasını GitHub Secrets > BUILD_CERTIFICATE_BASE64'e yapıştırın)

# 2. Ana Uygulama Profilini Base64 yapıp panoya kopyalama:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ios_certs\FirsatKolik_AppStore_Profile.mobileprovision")) | Set-Clipboard
# (Panodaki ana profili GitHub Secrets > BUILD_PROVISION_PROFILE_BASE64'e yapıştırın)

# 3. Share Extension Profilini Base64 yapıp panoya kopyalama:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ios_certs\FirsatKolik_ShareExtension_Profile.mobileprovision")) | Set-Clipboard
# (Panodaki uzantı profilini GitHub Secrets > SHARE_EXT_PROVISION_PROFILE_BASE64'e yapıştırın)
```

### 5.2. GitHub Secrets Tablosunu Doldurma
GitHub deponuza gidin: **Settings** > **Secrets and variables** > **Actions** > **New repository secret** diyerek aşağıdaki 7 anahtarı tek tek ekleyin:

| Secret Adı | Değer (Value) | Nereden Alındı? |
| :--- | :--- | :--- |
| `BUILD_CERTIFICATE_BASE64` | `MIIK...` (Çok uzun Base64 metni) | PowerShell ile panoya kopyalanan `.p12` içeriği |
| `P12_PASSWORD` | Belirlediğiniz parola (Örn: `FirsatKolik2026!`) | OpenSSL ile `.p12` üretirken girdiğiniz parola |
| `BUILD_PROVISION_PROFILE_BASE64` | `MIIS...` (Çok uzun Base64 metni) | PowerShell ile panoya kopyalanan ana `.mobileprovision` |
| `SHARE_EXT_PROVISION_PROFILE_BASE64` | `MIIS...` (Çok uzun Base64 metni) | PowerShell ile panoya kopyalanan uzantı `.mobileprovision` |
| `APP_STORE_CONNECT_KEY_ID` | `2X9R4ABCD2` (10 haneli) | App Store Connect API sayfasındaki Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | `69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | App Store Connect API sayfasındaki Issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | `-----BEGIN PRIVATE KEY----- ... -----END PRIVATE KEY-----` | İndirdiğiniz `.p8` dosyasını Not Defteri ile açıp tamamını kopyalayın |

---

## 10. 📱 Manuel Adım 6: App Store Connect'te Uygulama Kaydı ve Dahili Test Grubu Açma

1. [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps) sayfasına gidin.
2. **(+)** butonuna tıklayıp **New App** deyin:
   * **Platforms:** `iOS`
   * **Name:** `FırsatKolik`
   * **Primary Language:** `Turkish (Türkçe)`
   * **Bundle ID:** Listeden az önce oluşturduğunuz `com.firsatkolik.app` seçin.
   * **SKU:** `firsatkolik-ios-app` (Sizin belirleyeceğiniz iç kod).
   * **User Access:** `Full Access` seçin ve **Create** butonuna basın.
3. Uygulama detay sayfası açılacaktır. Üstteki sekmelerden **TestFlight** sekmesine tıklayın.
4. Sol menüden **Internal Testing (Dahili Test)** yanındaki **(+)** butonuna basın:
   * Grup adı: `Çekirdek Test Ekibi`
   * Buraya kendi Apple ID e-postanızı ve arkadaşınızın Apple ID e-postasını ekleyin.
   *(Dahili test kullanıcıları için Apple incelemesi beklenmez, build yüklendiği an bildirim gider!)*

---

## 11. 🚀 Manuel Adım 7: GitHub Actions Üzerinden Derleme ve Fastlane ile TestFlight'a Yükleme

1. GitHub deponuza gidin ve üstteki **Actions** sekmesine tıklayın.
2. Sol menüdeki iş akışları listesinden **iOS TestFlight Deployment** seçeneğine tıklayın.
3. Sağ üst köşedeki **"Run workflow"** açılır kutusuna tıklayın:
   * **Derleme Ortamı (Flavor):** `prod` seçin.
   * **TestFlight’a Otomatik Yüklensin mi?:** `true` olarak bırakın.
   * Yeşil **"Run workflow"** butonuna basın!

```
[Otomatik Pipeline Süreci]:
1. 📥 Depo klonlanır ve Flutter stable kurulur.
2. 🧪 iOS platform uyumluluk ve auth testleri (ios_compatibility_test.dart, ios_auth_test.dart) koşulur.
3. ⚡ CocoaPods önbelleği taranır ve yüklenir (Süreyi ~6-8 dakikaya indirir).
4. 🔐 setup_keychain.sh çalışarak Apple sertifikasını geçici macOS keychain'ine enjekte eder.
5. 📋 Hedef flavor'a ait GoogleService-Info-$FLAVOR.plist dosyası GoogleService-Info.plist olarak kopyalanır.
6. 🔨 flutter build ipa --build-number=${{ github.run_number }} çalıştırılarak benzersiz numaralı signed .ipa üretilir.
7. 💾 .ipa dosyası GitHub Artifacts olarak depolanır (Bilgisayarınıza indirebilirsiniz).
8. 🏎️ Fastlane devreye girer; App Store Connect REST API üzerinden paketi TestFlight'a yükler.
9. 🏁 skip_waiting_for_build_processing sayesinde Apple işleme kuyruğunu beklemeden makine kapanır (10x kota korunur!).
```
*Süreç ortalama 7 ila 10 dakika içinde tamamlanır ve yeşil onay işareti (✅) yanar.*

---

## 12. 📲 Manuel Adım 8: Ödünç Alınan iPhone'da Canlı TestFlight Kurulumu ve Doğrulama Protokolü

Build başarıyla yüklendikten yaklaşık 5-10 dakika sonra Apple paketi işler (processing) ve arkadaşınızın iPhone'una TestFlight bildirimi düşer.

### 8.1. Cihaza Kurulum ve Temiz Kurulum Tavsiyesi
1. **Temiz Kurulum Tavsiyesi (Önemli):** Eğer iPhone'da daha önceden yüklenmiş bir FırsatKolik sürümü varsa, iOS'un yerel URL Scheme (`CFBundleURLSchemes`) ve yetki önbelleğini sıfırlamak için ana ekrandan uygulamaya uzun basıp **"Uygulamayı Sil"** diyerek tamamen kaldırın.
2. Arkadaşınızın iPhone'undan Apple'ın resmi **TestFlight** uygulamasını açın.
3. TestFlight ekranında yeni **FırsatKolik** derlemesini göreceksiniz. Sıfırdan **"YÜKLE (INSTALL)"** butonuna dokunun.

---

### 8.2. Uçtan Uca Canlı Test Protokolü (12 Kritik Kontrol)

Uygulama açıldıktan sonra aşağıdaki 12 testi sırayla gerçekleştirin:

| # | Test Başlığı | Nasıl Test Edilir? | Beklenen Başarı Kriteri |
| :---: | :--- | :--- | :--- |
| **1** | **Google ile Giriş Yap** | "Profilim" sekmesinde "Google ile Hızlı Giriş Yap" butonuna basın. | Uygulama kesinlikle çökmemeli; sistem Google oturum modalı açılmalı, hesap seçilince Firestore `users/{uid}` kaydı oluşmalı. |
| **2** | **Apple ile Giriş Yap (Guideline 4.8)** | Giriş ekranında siyah Apple butonuna basın, FaceID/TouchID ile onaylayın. | İlk girişte ad-soyad yakalanmalı, Firestore'a yazılmalı ve APNs token senkronize edilmelidir. |
| **3** | **APNs Push Bildirimi** | Uygulama açılışında gelen bildirim izni popup'ına "İzin Ver" deyin. Web Admin'den test bildirimi atın. | Cihaza bildirim anında düşmeli; tıklandığında ilgili fırsat detayına yönlendirmeli. |
| **4** | **Kamera ve Galeri İzni** | Fırsat paylaşma ekranına gidin veya profil resmi değiştirmeyi deneyin. | iOS sistem izin popup'ı Türkçe açıklamasıyla çıkmalı (`Info.plist`), fotoğraf seçilebilmeli. |
| **5** | **Universal Links (Deeplink)** | Safari tarayıcısını açıp `https://firsatkolik.app/firsat/<id>` linkine tıklayın. | Safari sayfada kalmamalı, doğrudan FırsatKolik uygulamasına geçip fırsatı açmalı. |
| **6** | **Safe Area & Dynamic Island** | Ekranın üst çentiğine, Dynamic Island alanına ve alttaki Home Indicator çizgisine bakın. | Butonlar veya metinler çentiklerin altına taşmamalı, güvenli alan sınırlarına tam uymalı. |
| **7** | **Haptic Feedback (Titreşim)** | Bir fırsata "Sıcak" veya "Soğuk" oy verin, kupon kodunu kopyalayın. | iPhone'un Taptic Engine motorundan hafif, zarif bir dokunsal titreşim hissedilmeli. |
| **8** | **In-App WebView & Mağazaya Git** | Bir fırsat detayında "Fırsata Git" butonuna dokunun. | Harici e-ticaret sayfası (Amazon, Trendyol vb.) Safari View Controller içinde sorunsuz açılmalı. |
| **9** | **Native Paylaşım Menüsü (Share Sheet)**| Fırsat detayındaki "Paylaş" ikonuna dokunun. | Standart iOS paylaşım menüsü açılmalı; WhatsApp, Telegram veya AirDrop seçilebilmeli. |
| **10**| **Ağ Kesintisi ve Offline Mod** | iPhone'u "Uçak Modu"na alın ve fırsat listesini yenilemeyi deneyin. | Uygulama çökmek yerine zarif "İnternet bağlantınızı kontrol edin" banner'ı göstermeli. |
| **11**| **Hesap Silme (Apple Guideline 5.1.1)** | Profil > Ayarlar > "Hesabımı Sil" seçeneğini test edin. | Apple incelemesinde red yememek için hesabın ve verilerin silindiğini onaylayan diyalog çalışmalı. |
| **12**| **Dış Mağazalardan Paylaşım (Share Extension)** | Trendyol, Amazon veya Safari'de herhangi bir ürün linkine gidip iOS "Paylaş" menüsünden FırsatKolik'i seçin. | FırsatKolik ön plana açılmalı, paylaşılan link `group.com.firsatkolik.app` havuzundan okunarak doğrudan "Fırsat Paylaş" ekranına (`SubmitDealScreen(initialUrl: url)`) otomatik yönlenmelidir. |

---

## 13. ⚠️ Sık Karşılaşılan Hatalar, Uyarılar ve Anında Çözümler

### 1. Hata: `ITMS-90186: Missing Push Notification Entitlement`
* **Neden:** Apple Developer Portal'da App ID oluşturulurken Push Notifications yeteneği açılmamış veya Provisioning Profile güncellenmemiştir.
* **Çözüm:** Adım 1'e dönüp `com.firsatkolik.app` için Push Notifications'ı işaretleyin, ardından yeni bir Provisioning Profile indirip GitHub Secrets'taki `BUILD_PROVISION_PROFILE_BASE64` değerini güncelleyin.

### 2. Hata: `ITMS-90078: Missing Compliance (İhracat Uyumluluğu)`
* **Neden:** Apple, TestFlight'a yüklenen uygulamaların şifreleme (HTTPS/TLS) kullanıp kullanmadığını sorar.
* **Çözüm:** Projemizde `ios/Runner/Info.plist` dosyasına `<key>ITSAppUsesNonExemptEncryption</key><false/>` anahtarı eklenmiştir. Bu sayede Apple her build'de manuel soru sormaz, derleme doğrudan hazır duruma geçer.

### 3. Hata: `Redundant Binary Upload (ITMS-90189 CFBundleVersion Conflict)`
* **Neden:** Aynı derleme numarasıyla (build number) TestFlight'a ikinci kez yükleme yapmaya çalışmak.
* **Çözüm:** CI/CD iş akışımıza `--build-number=${{ github.run_number }}` parametresi entegre edilmiştir. Bu sayede her GitHub Actions koşusu otomatik olarak bir öncekinden büyük benzersiz bir build numarası alır ve manuel versiyon artırmaya gerek kalmaz.

### 4. Hata: `Fastlane / altool: Authentication Failed (401 Unauthorized)`
* **Neden:** `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID` veya `.p8` anahtar içeriğinde boşluk/yazım hatası vardır.
* **Çözüm:** GitHub Secrets'taki bu 3 anahtarı tekrar kontrol edin. `.p8` dosyasını kopyalarken başında ve sonundaki `-----BEGIN PRIVATE KEY-----` satırlarının eksiksiz kopyalandığından emin olun.

### 5. Hata: `Google ile Giriş Yapınca Uygulama Çökmesi (Fatal NSException / Missing URL Scheme)`
* **Neden:** iOS'ta Google Sign-In SDK'sının dönüş adresi olan `REVERSED_CLIENT_ID` şeması `Info.plist` içinde `CFBundleURLSchemes` altında tanımlı değildir veya sahte bir değer içeriyordur.
* **Çözüm:** Firebase Console'da gerçek iOS uygulaması (`com.firsatkolik.app`) oluşturulup `REVERSED_CLIENT_ID` değeri `Info.plist` içerisine işlenmiştir. (Not: Android'in aksine iOS'ta Keystore SHA-1 parmak izi gerekmez; iOS güvenliği URL şeması ve Bundle ID üzerinden doğrular).

### 6. Hata: `Çoklu Görevden (App Switcher) Kaydırıp Kapatınca (Swipe-to-Kill) "Fırsatkolik Çöktü" Uyarısı`
* **Neden:** Xcode derleme uyarısını (`UIScene lifecycle support will soon be required`) bastırmak için eklenen deneysel `UIApplicationSceneManifest` (`FlutterSceneDelegate`) ve `FlutterImplicitEngineDelegate`, uygulama çoklu görevden kapatılırken UIKit tarafından `sceneDidDisconnect` tetiklenmesine ve Flutter motoru ile pencerenin (`UIWindow`) eklentilerden önce bellekten silinmesine neden olur. Arka planda dinlemede olan yerel eklentiler serbest bırakılmış belleğe (`EXC_BAD_ACCESS` / `SIGSEGV`) eriştiğinde sistem çökmesi oluşur ve TestFlight bu kilitlenmeyi yakalayıp ekrana uyarı basar. (Dart seviyesinde hata oluşmadığı için Admin paneline log düşmez).
* **Çözüm:** `ios/Runner/Info.plist` içerisinden `UIApplicationSceneManifest` kaldırılmış, `ios/Runner/AppDelegate.swift` stabil `FlutterAppDelegate` mimarisine döndürülmüştür. Bu sayede kullanıcı uygulamayı yukarı kaydırarak kapattığında iOS çekirdeği süreci doğrudan temiz `SIGKILL` ile sonlandırır ve çökme uyarısı tamamen engellenir.

### 7. Hata: `Fırsat veya Katalog Paylaş Butonuna Basınca PlatformException (sharePositionOrigin: argument must be set...) Hatası`
* **Neden:** Android'in aksine iOS ve iPadOS üzerinde `UIActivityViewController` (popover menüsü), paylaşım penceresinin ekrandaki hangi koordinattan/butondan tetiklendiğini bilmek zorundadır. Flutter `share_plus` paketinde `sharePositionOrigin` parametresi boş veya sıfır (`{{0,0}, {0,0}}`) kaldığında iOS `CGRectIsEmpty` denetimine takılarak `PlatformException` fırlatır.
* **Çözüm:** `lib/utils/share_helper.dart` içerisinde evrensel `ShareHelper` sınıfı oluşturulmuştur. Tıklanan butonun mutlak koordinatlarını (`RenderBox.localToGlobal`) dinamik olarak hesaplar; buton bulunamazsa ekran boyutuna göre güvenli ve sıfır olmayan bir Rect üreterek `ShareHelper.shareText` ve `ShareHelper.shareFiles` ile paylaşımı iOS'ta hatasız açar.

### 8. Hata: `Fastlane: Yüklenecek IPA dosyası bulunamadı (build/ios/ipa/*.ipa) Hatası & altool Fallback`
* **Neden:** Fastlane çalışmaya başladığında mevcut çalışma dizinini (CWD) otomatik olarak `./fastlane/` dizinine taşır. CI betiğinden lane parametresi olarak göreceli yol (`build/ios/ipa/*.ipa`) aktarıldığında Fastlane dosyayı `./fastlane/build/...` olarak arar ve bulamaz. Bu durum derlemenin Apple tarafından 1 Kasım 2023'te kullanımdan kaldırılmış (deprecated) `xcrun altool` yedek mekanizmasına devretmesine yol açar.
* **Çözüm:** `ios_ci/scripts/upload_testflight.sh` içinde `$1` argümanı Fastlane'e iletilmeden önce mutlak yola (`IPA_DIR="$(cd "$(dirname "$IPA_INPUT")" && pwd)"`) dönüştürülmüştür. Ayrıca `ios_ci/Fastfile` içine göreceli yolları bir üst proje kök diziniyle (`File.join("..", raw_path)`) harmanlayan çift katmanlı yol çözümleme mimarisi eklenmiştir. Fastlane artık ilk denemede doğrudan App Store Connect REST API v1 üzerinden TestFlight'a yükleme yapmaktadır.

### 9. Hata: `fatal error: 'Flutter/Flutter.h' file not found (Share Extension Derleme Hatası)`
* **Neden:** `ios/Podfile` içerisine `target 'ShareExtension'` eklenmesi veya uzantıya CocoaPods eklentilerinin bağlanması durumunda, Xcode derleyicisi iOS App Extension binary'sinde `Flutter.framework` arar ve bulamadığı için derlemeyi durdurur.
* **Çözüm:** Share Extension tamamen saf Swift (Zero-Pod) mimarisiyle kurulmuştur ([`ios/Share Extension/ShareViewController.swift`](file:///d:/firsatkolik/ios/Share%20Extension/ShareViewController.swift)). [`ios/Podfile`](file:///d:/firsatkolik/ios/Podfile) dosyasında ShareExtension için hiçbir CocoaPods hedefi tanımlanmamalıdır. Veri paylaşımı CocoaPods olmadan, Apple'ın yerel `App Groups` (`UserDefaults(suiteName: "group.com.firsatkolik.app")`) mekanizması üzerinden yürütülür.

### 10. Hata: `TestFlight'ta Push Bildirimlerinin Gelmemesi (messaging/third-party-auth-error: Invalid APNs credential)`
* **Neden:** TestFlight dağıtımı için App Store Connect API Key (`AuthKey_XXXXXXXXXX.p8`) GitHub Secrets'a girilmiş olsa da, Firebase Console'da Apple Push Notification service (APNs) Authentication Key (`.p8`) tanımlanmamıştır. Firebase, Apple APNs sunucularına bağlanamadığı için push istekleri `Invalid APNs credential` hatasıyla reddedilir.
* **Çözüm:** 
  1. [Apple Developer Portal - Keys](https://developer.apple.com/account/resources/authkeys/list) adresinden **Apple Push Notifications service (APNs)** yetkili yeni bir `.p8` anahtarı üretip indirin.
  2. Firebase Console -> Proje Ayarları -> Cloud Messaging -> Apple Uygulama Yapılandırması (`com.firsatkolik.app`) alanında bu `.p8` dosyasını, 10 haneli Key ID ve Team ID (`973W9DTDY9`) ile yükleyin. (Ayrıntılı rehber için bkz. [`ios_ci/README.md`](file:///d:/firsatkolik/ios_ci/README.md) Adım 6).
* **Ek Güvence:** CI/CD iş akışında (`.github/workflows/ios_testflight_deploy.yml`) derleme anında `Runner.entitlements` içindeki `aps-environment` otomatik olarak `production` yapılır. Ayrıca ön plandayken mesaj bildirim afişleri için `NotificationService` doğrudan Firestore `messages` koleksiyonunu gerçek zamanlı dinleyerek (`_setupForegroundMessageListener()`) APNs gecikmelerinden bağımsız anlık afiş sunumu sağlar.

---

## 🏁 Özet ve Sonuç

Bu kılavuzdaki adımları takip ederek:
1. Hiçbir Mac cihazı satın almadan veya kiralamadan,
2. `altool` deprecation riskine takılmadan sektör standardı **Fastlane & App Store Connect REST API** ile,
3. 10x macOS dakika kotasını CocoaPods önbelleği ve hızlı çıkış (`skip_waiting_for_build_processing`) ile koruyarak,
4. Sıfır ek maliyetle GitHub Actions üzerinden TestFlight dağıtımını gerçekleştirebilir,
5. Arkadaşınızdan alacağınız iPhone ile tüm sistem özelliklerini gerçek dünyada test edebilirsiniz!

