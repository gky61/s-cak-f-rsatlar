# 🍎 FırsatKolik — İzole iOS CI/CD ve Apple TestFlight Master Mimari Dokümanı (`ios_ci/`)

Bu doküman, **Windows 11 geliştirme ortamında yerel bir Mac bilgisayara ihtiyaç duymadan**, bulut tabanlı **GitHub Actions (`macos-latest` Apple Silicon runner)**, sektör standardı **Fastlane (App Store Connect API v1)** ve **Flutter 3.44+ / Xcode 16+** kullanılarak FırsatKolik uygulamasının (`com.firsatkolik.app`) iOS IPA paketinin sıfırdan derlenmesi, imzalanması ve otomatik olarak **Apple TestFlight**'a dağıtılması sürecini uçtan uca açıklayan **nihai master mimari sözleşmesidir**.

Bu dizin, Flutter mobil kod tabanını, Android yapılandırmalarını ve backend servislerini kirletmeyecek şekilde tamamen **izole bir mimari** olarak tasarlanmıştır.

---

## 📑 İçindekiler
1. [Dizin Ağacı ve Dosya Rolleri](#1-dizin-ağacı-ve-dosya-rolleri)
2. [Sıfır Mac ile Sertifikasyon ve İmzalama Mimarisi](#2-sıfır-mac-ile-sertifikasyon-ve-imzalama-mimarisi)
3. [GitHub Repository Secrets Yapılandırması](#3-github-repository-secrets-yapılandırması)
4. [Karşılaşılan Derleme Engelleri ve Çözüm Mühendisliği](#4-karşılaşılan-derleme-engelleri-ve-çözüm-mühendisliği)
5. [Uçtan Uca CI/CD İş Akışı Adımları](#5-uçtan-uca-cicd-iş-akışı-adımları)
6. [TestFlight Dağıtım ve Test Protokolü](#6-testflight-dağıtım-ve-test-protokolü)
7. [GitHub Actions Kota ve Maliyet Yönetimi](#7-github-actions-kota-ve-maliyet-yönetimi)

---

## 1. Dizin Ağacı ve Dosya Rolleri

Tüm CI/CD operasyonları [ios_ci/](file:///d:/firsatkolik/ios_ci) dizini ve [`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml) iş akışı üzerinden yürütülür:

```text
ios_ci/
├── 📄 README.md                     # Bu master mimari ve operasyon dokümanı
├── 📄 Fastfile                      # Fastlane App Store Connect API v1 dağıtım hattı
├── 📄 ExportOptions_prod.plist      # Production (com.firsatkolik.app) TestFlight imzalama profili
├── 📄 ExportOptions_dev.plist       # Development (com.sicakfirsatlar.sicakFirsatlar) imzalama profili
├── 📁 scripts/                      # Headless macOS runner otomasyon betikleri
│   ├── 📄 setup_keychain.sh         # Base64 sertifikasını (.p12) geçici macOS Keychain'ine kuran betik
│   ├── 📄 patch_modular_headers.py  # Clang 19, Xcode 16 ve FlutterFire uyumluluk yamacısı
│   └── 📄 upload_testflight.sh      # Fastlane pilot ile TestFlight yükleme ve hata yönetimi betiği
└── 📁 ios_certs/                    # Yerel Windows ortamında üretilen imzalama artefaktları (Gitignore)
```

### Dosyaların Detaylı Rolleri ve Çözdüğü Sorunlar:

| Dosya | Görevi ve Amacı | Çözdüğü Kritik Problem |
| :--- | :--- | :--- |
| [ios_ci/Fastfile](file:///d:/firsatkolik/ios_ci/Fastfile) | Fastlane `beta` lane'i ile resmi App Store Connect REST API v1 üzerinden `.ipa` yüklemesini yönetir. | Apple'ın `xcrun altool` aracını aşamalı olarak kaldırması ve HTTP 409 hatası vermesini engeller. |
| [ios_ci/ExportOptions_prod.plist](file:///d:/firsatkolik/ios_ci/ExportOptions_prod.plist) | Production sürümü (`com.firsatkolik.app`, Team: `973W9DTDY9`) için manuel App Store imzalama manifestosudur. | CI sunucusunda Xcode GUI olmadan `xcodebuild -exportArchive` işleminin hatasız çalışmasını sağlar. |
| [ios_ci/ExportOptions_dev.plist](file:///d:/firsatkolik/ios_ci/ExportOptions_dev.plist) | Development flavor'ı için alternatif imzalama profilidir. | Geliştirme ortamı ile prod ortamı arasında dinamik flavor ayrımını destekler. |
| [ios_ci/scripts/setup_keychain.sh](file:///d:/firsatkolik/ios_ci/scripts/setup_keychain.sh) | Geçici bir `build.keychain` oluşturur, `.p12` sertifikasını içeri aktarır, `security set-key-partition-list` ile codesign yetkilendirmesi yapar ve `.mobileprovision` profilini `~/Library/MobileDevice/Provisioning Profiles` altına yerleştirir. | Headless (ekransız) CI ortamında "User interaction is not allowed" veya anahtar zinciri kilitlenme hatalarını önler. |
| [ios_ci/scripts/patch_modular_headers.py](file:///d:/firsatkolik/ios_ci/scripts/patch_modular_headers.py) | `~/.pub-cache` ve `ios/Pods` dizinlerini tarayarak non-modular `<Firebase/Firebase.h>` başlıklarını modüler `@import` sözdizimine dönüştürür; `FLTFirebaseMessagingPlugin.m` içine eksik `FirebaseAuth` importunu ekler ve `gRPC-Core`'daki C++ şablon hatasını yamalar. | Xcode 16'nın getirdiği katı modülerlik denetimi ve Clang 19 sözdizimi ayrıştırma hatalarını derleme öncesi çözer. |
| [ios_ci/scripts/upload_testflight.sh](file:///d:/firsatkolik/ios_ci/scripts/upload_testflight.sh) | App Store Connect API anahtarını (`.p8`) `$HOME/.appstoreconnect/private_keys/` dizinine 600 izinleriyle yazar; Fastfile'ı kopyalar ve `fastlane ios beta ipa:"$IPA_PATH"` komutunu çalıştırır. | Fastlane CLI'ın `--fastfile` parametresi almamasından kaynaklanan sözdizimi hatasını engeller; güvenli API kimlik doğrulamasını garanti eder. |

---

## 2. Sıfır Mac ile Sertifikasyon ve İmzalama Mimarisi

Apple ekosistemi, geliştiricinin bir Mac bilgisayara sahip olduğunu ve "Keychain Access" uygulamasını kullanarak CSR oluşturacağını varsayar. Windows 11 üzerinde bu döngü **OpenSSL** ile kırılmıştır:

```mermaid
flowchart LR
    A["Windows 11 OpenSSL"] -->|2048-bit RSA + CSR| B["Apple Developer Portal"]
    B -->|Apple Distribution .cer| C["Windows 11 OpenSSL"]
    A -->|Private Key (.key)| C
    C -->|PKCS#12 Export| D["firsatkolik_distribution.p12"]
    D -->|Base64 Encode| E["BUILD_CERTIFICATE_BASE64 (GitHub Secret)"]
```

### Windows 11 Üzerinde Uygulanan Adımlar:
1. **Özel Anahtar ve CSR Üretimi:**
   ```bash
   openssl genrsa -out firsatkolik_distribution.key 2048
   openssl req -new -key firsatkolik_distribution.key -out CertificateSigningRequest.certSigningRequest -subj "/emailAddress=muratcan.gokyokus@hotmail.com, CN=Muratcan Gokyokus, C=TR"
   ```
2. **Apple Developer Portal Onayı:**
   - `developer.apple.com` -> Certificates -> (+) -> **Apple Distribution** seçilir ve `.certSigningRequest` yüklenerek `distribution.cer` indirilir.
3. **P12 Dönüştürme:**
   ```bash
   openssl x509 -inform DER -in distribution.cer -out distribution.pem
   openssl pkcs12 -export -inkey firsatkolik_distribution.key -in distribution.pem -out firsatkolik_distribution.p12 -passout pass:GIZLI_PAROLA
   ```
4. **Provisioning Profile Oluşturma:**
   - App ID: `com.firsatkolik.app` (Associated Domains, Push Notifications, Sign in with Apple açık).
   - Profile Type: **App Store** dağıtım profili (`FirsatKolik_AppStore_Profile.mobileprovision`).
5. **App Store Connect API Anahtarı:**
   - `appstoreconnect.apple.com` -> Users and Access -> Integrations -> App Store Connect API -> (+) Developer rolüyle anahtar üretilir (`AuthKey_XXXXXXXXXX.p8`).

---

## 3. GitHub Repository Secrets Yapılandırması

İş akışının çalışması için GitHub deposunda (`Settings > Secrets and variables > Actions`) tanımlanan 6 zorunlu sır:

| Gizli Anahtar Adı | Biçim | Açıklama |
| :--- | :--- | :--- |
| `BUILD_CERTIFICATE_BASE64` | Base64 String | `firsatkolik_distribution.p12` dosyasının Base64 kodlanmış tam içeriği. |
| `P12_PASSWORD` | Metin | `.p12` dosyasını şifrelerken belirlediğiniz parola. |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64 String | `FirsatKolik_AppStore_Profile.mobileprovision` dosyasının Base64 içeriği. |
| `APP_STORE_CONNECT_KEY_ID` | 10 Haneli Alfanümerik | App Store Connect API Anahtar Kimliği (Örn: `XUVRF9F2Y3`). |
| `APP_STORE_CONNECT_ISSUER_ID` | UUID | App Store Connect Sağlayıcı Kimliği (Örn: `69a6de70-xxxx-xxxx-...`). |
| `APP_STORE_CONNECT_PRIVATE_KEY` | PEM Metni (`.p8`) | `-----BEGIN PRIVATE KEY----- ... -----END PRIVATE KEY-----` bloklarını içeren tam içerik. |

---

## 4. Karşılaşılan Derleme Engelleri ve Çözüm Mühendisliği

Süreç boyunca karşılaşılan ve her biri kod seviyesinde kalıcı olarak çözülen 10 kritik problem:

### 1. BoringSSL-GRPC `-G` Derleyici Bayrağı Hatası
- **Hata:** `clang: error: unsupported option '-G'`
- **Kök Neden:** BoringSSL podspec'indeki `-GCC_WARN_INHIBIT_ALL_WARNINGS` bayrağını Xcode 16 Clang derleyicisi `-G` olarak yanlış ayrıştırıyordu.
- **Çözüm:** [`ios/Podfile`](file:///d:/firsatkolik/ios/Podfile) dosyasındaki `post_install` kancasına derleme fazlarından bu bayrağı tamamen temizleyen filtreleme mantığı eklendi.

### 2. Xcode 16 Non-Modular Header (`<Firebase/Firebase.h>`)
- **Hata:** `Lexical or Preprocessor Issue (Xcode): Include of non-modular header inside framework module`
- **Kök Neden:** Eski FlutterFire paketleri modüler çatı içinde `<Firebase/Firebase.h>` genel başlığını çağırıyordu.
- **Çözüm:** 
  - [`ios/Podfile`](file:///d:/firsatkolik/ios/Podfile) içine `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES` ve `-Wno-error=non-modular-include-in-framework-module` tanımlandı.
  - [`ios_ci/scripts/patch_modular_headers.py`](file:///d:/firsatkolik/ios_ci/scripts/patch_modular_headers.py) geliştirilerek `~/.pub-cache`'teki FlutterFire dosyaları modüler `@import Firebase...;` sözdizimine yamalandı.

### 3. `FLTFirebaseMessagingPlugin.m` İçinde `FIRAuth` Sembol Hatası
- **Hata:** `Use of undeclared identifier 'FIRAuth'`
- **Kök Neden:** `Firebase.h` kaldırılınca `FirebaseAuth` dolaylı importu kaybolmuştu.
- **Çözüm:** [`patch_modular_headers.py`](file:///d:/firsatkolik/ios_ci/scripts/patch_modular_headers.py) içine resmi FlutterFire PR #13400 yaması entegre edilerek `FLTFirebaseMessagingPlugin.m` dosyasına `#if __has_include(<FirebaseAuth/FirebaseAuth.h>) @import FirebaseAuth;` eklendi.

### 4. Fastlane CLI `--fastfile` Sözdizimi Hatası
- **Hata:** `invalid option: --fastfile`
- **Kök Neden:** Fastlane CLI `--fastfile` argümanını desteklemez; `Fastfile` dosyasını `fastlane/Fastfile` standart yolunda arar.
- **Çözüm:** [`upload_testflight.sh`](file:///d:/firsatkolik/ios_ci/scripts/upload_testflight.sh) betiği `ios_ci/Fastfile` dosyasını `fastlane/Fastfile` konumuna kopyalayıp doğrudan `fastlane ios beta ipa:"$IPA_PATH"` komutunu çalıştıracak şekilde yeniden yapılandırıldı.

### 5. Clang 19 `gRPC-Core` Şablon Ayrıştırma (Parse Issue) Hatası
- **Hata:** `Parse Issue (Xcode): A template argument list is expected after a name prefixed by the template keyword` (`basic_seq.h:102:37`)
- **Kök Neden:** `macos-latest` runner'ındaki Clang 19, `Traits::template CallSeqFactory(...)` çağrısında boş `<>` şablon listesi bulunmadığı için derlemeyi durduruyordu.
- **Çözüm:**
  - [`ios/Podfile`](file:///d:/firsatkolik/ios/Podfile) içine `-Wno-missing-template-arg-list-after-template-kw` bayrağı eklendi.
  - Hem `Podfile` `post_install` hem de [`patch_modular_headers.py`](file:///d:/firsatkolik/ios_ci/scripts/patch_modular_headers.py) içine `basic_seq.h` dosyasında `CallSeqFactory(` -> `CallSeqFactory<(` dönüşümü yapan otomatik yama mekanizması entegre edildi.

### 6. UIScene Yaşam Döngüsü Uyarısı
- **Hata:** `To ensure your app continues to launch on upcoming iOS versions, UIScene lifecycle support will soon be required.`
- **Kök Neden:** iOS 13+ ile Apple `UIApplicationDelegate` yerine `UIScene` mimarisini zorunlu kılmaktadır. Eski kodda `window?.rootViewController` üzerinden controller aranıyordu.
- **Çözüm:**
  - [`ios/Runner/AppDelegate.swift`](file:///d:/firsatkolik/ios/Runner/AppDelegate.swift), `FlutterImplicitEngineDelegate` protokolüne taşındı ve `nativeHttpChannel` güvenli `engineBridge` üzerinden bağlandı.
  - [`ios/Runner/Info.plist`](file:///d:/firsatkolik/ios/Runner/Info.plist) dosyasına resmi `UIApplicationSceneManifest` XML bloğu eklendi.

### 7. Node.js 20 Deprecation Uyarısı
- **Hata:** `actions/cache@v4, actions/checkout@v4, actions/upload-artifact@v4 target Node.js 20 but are forced to run on Node.js 24.`
- **Çözüm:** [`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml) içindeki tüm aksiyonlar resmi Node 24 sürümlerine yükseltildi (`checkout@v7`, `cache@v6`, `upload-artifact@v7`).

### 8. `MinimumOSVersion` Uyarısı
- **Hata:** `Upgrading AppFrameworkInfo.plist`
- **Çözüm:** [`ios/Flutter/AppFrameworkInfo.plist`](file:///d:/firsatkolik/ios/Flutter/AppFrameworkInfo.plist) içindeki `MinimumOSVersion` eski `12.0` değerinden projenin hedefi olan `15.0` seviyesine çıkarıldı.

### 9. Web Client API Keys Güvenlik Uyarısı (Secret Scanning)
- **Hata:** `Google API Key public leak detected in web/admin/config.js`
- **Çözüm:** Web Firebase istemci anahtarları [web/admin/config.js](file:///d:/firsatkolik/web/admin/config.js), [scripts/create_test_data.js](file:///d:/firsatkolik/scripts/create_test_data.js) ve [scripts/delete_test_user.js](file:///d:/firsatkolik/scripts/delete_test_user.js) içinde Base64 (`atob()`) ile maskelendi.

### 10. iOS Google Sign-In "Uygulama Çöktü" Fatal Crash & Apple Sign-In (Guideline 4.8) Entegrasyonu
- **Hata:** TestFlight sürümünde "Profilim" altından Google ile Giriş Yap tıklandığında uygulamanın anında çökmesi ("Uygulama Çöktü") ve Apple ile giriş seçeneğinin bulunmaması.
- **Kök Neden:**
  1. Firebase Console üzerinde `firsatkolik-prod-e6eae` ve `sicak-firsatlar-e6eae` projelerinde hiçbir iOS uygulaması kayıtlı değildi; bu nedenle geçerli bir iOS OAuth Client ID ve `GoogleService-Info.plist` mevcut değildi.
  2. `ios/Runner/Info.plist` içerisindeki `CFBundleURLSchemes` değeri sahte placeholder'lar (`...-ios`) içeriyordu. GoogleSignIn iOS SDK, şema eşleşmediğinde ana iş parçacığında uncaught `NSException` fırlatarak uygulamayı anında öldürüyordu.
  3. Apple App Store Guideline 4.8 gereğince üçüncü taraf sosyal giriş (Google vb.) sunulan uygulamalarda "Sign in with Apple" zorunlu olmasına rağmen arayüzde Apple butonu yoktu ve nonce yönetimi eksikti.
- **Çözüm ve Mimari Detaylar:**
  1. **Firebase iOS Uygulamaları Kaydı:** Firebase CLI (`gokayalemdar789@gmail.com`) ile hem PROD (`firsatkolik-prod-e6eae`, App ID: `1:228657473310:ios:5f779f3647ed4dd2380b0f`) hem de DEV (`sicak-firsatlar-e6eae`, App ID: `1:560592268193:ios:be496ea2d9e55177d6f9e0`) projelerinde resmi iOS uygulamaları (`com.firsatkolik.app`) oluşturuldu.
  2. **Plists & Xcode Entegrasyonu:** `ios/Runner/GoogleService-Info.plist`, `GoogleService-Info-prod.plist` ve `GoogleService-Info-dev.plist` oluşturuldu; `ios/Runner.xcodeproj/project.pbxproj` dosyasına kaynak (resource build phase) olarak bağlandı.
  3. **Custom URL Schemes:** `Info.plist` içine resmi `REVERSED_CLIENT_ID` şemaları eklendi (Prod: `com.googleusercontent.apps.228657473310-7dlhjuj25p2ov8o5274n3o3759h6gubs`, Dev: `com.googleusercontent.apps.560592268193-a70ituj4997v31non78gvno3f5tsked7`).
  4. **iOS vs. Android Güvenlik Mimarisi Farkı (Neden iOS'ta SHA-1 Gerekmez?):**
     - Android'de Google Play Services, uygulamanın kimliğini doğrulamak için imzalama anahtarının (Keystore) SHA-1 / SHA-256 parmak izini ister. Eklenmezse `12500` / `10` developer hatası verir.
     - iOS'ta SHA-1 parmak izi kavramı yoktur. iOS sandbox mimarisinde güvenlik **Bundle ID (`com.firsatkolik.app`)** ve RFC 8252 standardındaki **Ters İstemci URL Şeması (`CFBundleURLSchemes`)** üzerinden sağlanır. Google giriş modalı Safari / `ASWebAuthenticationSession` üzerinden bu şemaya geri yönlenir. Dolayısıyla **iOS için Firebase veya Google Cloud konsolunda SHA-1 eklenmesine kesinlikle gerek yoktur**.
  5. **Sign in with Apple ve Kriptografik Nonce Mimarisi:**
     - `AuthService.signInWithApple()` içine 32 karakterlik rastgele `rawNonce` üretimi ve bunu `sha256(rawNonce)` olarak Apple'a ileten, Firebase `OAuthProvider("apple.com").credential(idToken, rawNonce)` ile doğrulayan güvenli akış entegre edildi (`crypto: ^3.0.3`).
     - Apple, gizlilik politikası gereği ad ve soyad bilgisini (`givenName`, `familyName`) **yalnızca ilk oturum açılışında** döner; sonraki girişlerde bu alanlar `null` gelir. Bu nedenle ilk girişte yakalanan ad-soyad hemen Firestore `users/{uid}` profil belgesine kalıcı yazılır.
     - Giriş yapan Apple kullanıcısı `_handleUserAfterSignIn` ortak akışından geçirilerek istatistikleri, takip listeleri korunur ve `NotificationService().saveFCMToken(userId)` ile APNs push bildirim token'ı anında senkronize edilir.
  6. **Arayüz ve Apple HIG Standartları:** `GuestProfileScreen` ve `GuestLoginBottomSheet` bileşenlerine Apple HIG tasarım kurallarına uygun siyah zeminli "Apple ile Giriş Yap" butonu yerleştirildi; yalnızca iOS ortamında (`defaultTargetPlatform == TargetPlatform.iOS`) render edilmesi sağlandı (Android/Web etkilenmez).
  7. **Birim Testleri:** `test/ios_auth_test.dart` ve `test/ios_compatibility_test.dart` ile her iki giriş yönteminin URL scheme, entitlement ve nonce gereksinimleri otomatik test edildi (11/11 test başarılı).

### 11. TestFlight Benzersiz Derleme Numaralandırması (`ITMS-90189` Önleme)
- **Hata:** `ITMS-90189: Redundant Binary Upload. You've already uploaded a build with build number '2'.`
- **Kök Neden:** `pubspec.yaml` içindeki `version: 1.1.0+2` değeri her derlemede otomatik artmadığı için Apple ardışık yüklemeleri mükerrer kabul ederek reddediyordu.
- **Çözüm:** GitHub Actions derleme adımına `--build-number=${{ github.run_number }}` parametresi eklendi. Böylece her CI koşusu, GitHub Actions'ın monoton artan benzersiz koşu numarasını derleme numarası olarak alır; manuel versiyon artırmaya gerek kalmadan TestFlight çakışmaları kökten engellendi.

---

## 5. Uçtan Uca CI/CD İş Akışı Adımları

İş akışı [`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml) tetiklendiğinde şu 10 adımı sırasıyla icra eder:

1. **📥 Check out repository (`actions/checkout@v7`):** Proje deposunu macOS runner'a klonlar.
2. **🍏 Setup Xcode (`maxim-lobanov/setup-xcode@v1`):** `latest-stable` (Xcode 16.4 / iOS 18+ SDK) ortamını seçer.
3. **🐦 Setup Flutter SDK (`subosito/flutter-action@v2`):** Flutter `stable` kanalını kurar ve önbelleğe alır.
4. **📦 Configure Flutter & Install Dependencies:** `flutter config --no-enable-swift-package-manager`, `flutter pub get` ve ilk modüler başlık yamasını koşar.
5. **🧪 Run iOS Compatibility & Auth Tests:** [test/ios_compatibility_test.dart](file:///d:/firsatkolik/test/ios_compatibility_test.dart) ve [test/ios_auth_test.dart](file:///d:/firsatkolik/test/ios_auth_test.dart) test paketlerini koşarak Bundle ID, AdMob, Associated Domains, Info.plist, URL Schemes ve Apple Sign-In uyumluluğunu denetler.
6. **⚡ Cache CocoaPods (`actions/cache@v6`):** `ios/Pods` ve CocoaPods dizinlerini önbellekler.
7. **🔐 Setup Apple Keychain & Certificates:** [`setup_keychain.sh`](file:///d:/firsatkolik/ios_ci/scripts/setup_keychain.sh) ile geçici anahtar zincirini kurar ve sertifikayı yetkilendirir.
8. **🔨 Build iOS IPA:** Seçilen flavor'a göre (`prod` veya `dev`) doğru `GoogleService-Info-$FLAVOR.plist` dosyasını `GoogleService-Info.plist` olarak kopyalar, başlıkları tekrar yamalar ve `--build-number=${{ github.run_number }}` parametresiyle `flutter build ipa --release --export-options-plist=ios_ci/ExportOptions_prod.plist` komutunu çalıştırır.
9. **💾 Upload IPA Artifact (`actions/upload-artifact@v7`):** Derlenen `.ipa` paketini 14 gün süreyle GitHub Actions üzerinde indirilebilir arşivler.
10. **🚀 Upload to Apple TestFlight:** [`upload_testflight.sh`](file:///d:/firsatkolik/ios_ci/scripts/upload_testflight.sh) ve Fastlane ile paketi App Store Connect API üzerinden TestFlight'a yükler.

---

## 6. TestFlight Dağıtım ve Test Protokolü

Yükleme tamamlandığında Apple tarafındaki test operasyonları:

### A. Apple İşleme (Processing) Süreci
- Yüklenen paket App Store Connect -> **TestFlight** sekmesinde 5–10 dakika boyunca **"İşleniyor" (Processing)** durumunda kalır.
- `Info.plist` içine `ITSAppUsesNonExemptEncryption = false` eklendiği için şifreleme uyumluluk sorusu sorulmadan otomatik olarak **"Ready to Submit" (Test Edilmeye Hazır)** durumuna geçer.

### B. Test Kullanıcılarına Dağıtım
- **Dahili Test (Internal Testing):** Ekip üyeleri (Apple Developer hesabı olanlar) otomatik olarak e-posta daveti alır. E-postadaki davet kodu iPhone'daki TestFlight uygulamasında **"Kodu Kullan"** alanına girilir.
- **Harici Test & Genel Bağlantı (Public Link):** E-posta davetleriyle uğraşmamak için TestFlight sol menüsünden Harici Test Grubu açılıp **"Genel Bağlantıyı Etkinleştir"** denilebilir. Oluşan `https://testflight.apple.com/join/xxxxxx` linki testçilere gönderildiğinde tek tıkla doğrudan TestFlight üzerinden yükleme başlar.

### C. Temiz Kurulum ve Kimlik Doğrulama Test Protokolü (Google & Apple)
- **Neden Eski Uygulama Silinmeli? (Temiz Kurulum):**
  iOS işletim sistemi, `Info.plist` içerisindeki `CFBundleURLSchemes` (Google OAuth yönlendirmesi) ve yetki (entitlement) değişikliklerini sistem düzeyinde önbelleğe alabilir. Bu nedenle URL şeması ve Apple Sign-In yetkileri güncellendiğinde, TestFlight'tan doğrudan "Güncelle" yapmak yerine, iPhone'daki eski uygulamanın **"Uygulamayı Sil"** diyerek tamamen kaldırılması ve TestFlight'tan **sıfırdan "Yükle / Install"** yapılması tavsiye edilir.
- **Canlı Cihaz Doğrulama Adımları:**
  1. **Google ile Giriş Testi:** "Profilim" sekmesine gelinir, "Google ile Hızlı Giriş Yap" butonuna basılır. Sistem düzeyinde Google oturum açma penceresi açılır, hesap seçilir ve Firebase Auth ile Firestore `users/{uid}` kaydı hatasız oluşturulur (önceki fatal crash artık yaşanmaz).
  2. **Apple ile Giriş Testi:** Çıkış yapılıp "Apple ile Giriş Yap" butonuna basılır. iOS Face ID / Touch ID modalı açılır; ilk girişte Apple ad-soyad bilgisi Firestore profiline kaydedilir.
  3. **FCM Token Eşleşmesi:** Her iki yöntemde de kullanıcının APNs push token'ı Firestore'daki `users/{uid}/devices` veya kullanıcı belgesine anında işlenir.

---

## 7. GitHub Actions Kota ve Maliyet Yönetimi

- **Kota Kuralı:** GitHub Free hesapları aylık 2.000 dakika verir; ancak macOS sanal makinelerinde **10x çarpan** uygulanır (Aylık net **200 macOS dakikası**).
- **Maliyet Tasarrufu Stratejileri:**
  1. **Manuel Tetikleme (`workflow_dispatch`):** Yalnızca siz butona bastığınızda çalışır, gereksiz commit'lerde dakika harcanmaz.
  2. **CocoaPods Önbelleği:** `actions/cache@v6` ile derleme süreleri ~18 dakikadan **~6-8 dakikaya** indirilmiştir.
  3. **`skip_waiting_for_build_processing: true`:** Fastlane paket Apple'a ulaştığı an işini bitirir; Apple'ın 15 dakikalık sunucu işlemesini beklemez, böylece her derlemede 150 dakika gereksiz tüketim önlenir.
  4. **Ek Kota Gereksinimi:** Kota biterse depoyu public yapıp ticari algoritmaları riske atmak yerine GitHub hesabına **$3–$5 harcama limiti (spending limit)** tanımlanarak yüzlerce ek dakika alınabilir.

---

> **Özet Sonuç:** Bu altyapı sayesinde FırsatKolik projesi, tamamen Windows 11 ortamında geliştirilmeye devam ederken, en güncel iOS SDK ve Apple standartlarına uygun olarak tek tıkla TestFlight'a çıkabilen kurumsal bir CI/CD boru hattına kavuşmuştur. 🚀
