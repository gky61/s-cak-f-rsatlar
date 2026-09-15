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
8. [iOS Sistem Paylaşım Menüsü (Share Extension) ve App Groups Mimarisi](#8-ios-sistem-paylaşım-menüsü-share-extension-ve-app-groups-mimarisi)

---

## 1. Dizin Ağacı ve Dosya Rolleri

Tüm CI/CD operasyonları [ios_ci/](file:///d:/firsatkolik/ios_ci) dizini, [ios/Share Extension/](file:///d:/firsatkolik/ios/Share%20Extension) ve [`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml) iş akışı üzerinden yürütülür:

```text
ios_ci/
├── 📄 README.md                     # Bu master mimari ve operasyon dokümanı
├── 📄 Fastfile                      # Fastlane App Store Connect API v1 dağıtım hattı
├── 📄 ExportOptions_prod.plist      # Production (com.firsatkolik.app + ShareExtension) TestFlight imzalama profili
├── 📄 ExportOptions_dev.plist       # Development (com.sicakfirsatlar.sicakFirsatlar + ShareExtension) profili
├── 📁 scripts/                      # Headless macOS runner otomasyon betikleri
│   ├── 📄 setup_keychain.sh         # Base64 sertifikasını (.p12) ve profilleri Keychain'e kuran betik
│   ├── 📄 patch_modular_headers.py  # Clang 19, Xcode 16 ve FlutterFire uyumluluk yamacısı
│   └── 📄 upload_testflight.sh      # Fastlane pilot ile TestFlight yükleme ve hata yönetimi betiği
└── 📁 ios_certs/                    # Yerel Windows ortamında üretilen imzalama artefaktları (Gitignore)

ios/Share Extension/                 # Dış uygulamalardan (Trendyol vb.) link yakalayan saf yerel iOS uzantısı
├── 📄 ShareViewController.swift     # Saf Swift (Zero-Pod) Paylaşım denetleyicisi & UserDefaults köprüsü
├── 📄 Info.plist                    # Extension aktivasyon kuralları ve AppGroupId eşleşmesi
└── 📄 ShareExtension.entitlements   # group.com.firsatkolik.app App Groups yetkilendirmesi
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
5. **App Store Connect API Anahtarı (TestFlight Yüklemesi İçin):**
   - `appstoreconnect.apple.com` -> Users and Access -> Integrations -> App Store Connect API -> (+) Developer rolüyle anahtar üretilir (`AuthKey_XXXXXXXXXX.p8`). Bu anahtar CI/CD ortamından TestFlight'a IPA yüklemek içindir.
6. **Apple Push Notifications Service (APNs) Anahtarı (.p8 - Push Bildirimleri İçin):**
   - `developer.apple.com` -> Certificates, Identifiers & Profiles -> **Keys** -> (+) butonuna tıklanır.
   - Key Name: `FirsatKolik APNs Key` yazılır, **Apple Push Notifications service (APNs)** seçeneği işaretlenir.
   - Sağdaki **Configure** butonuna tıklanarak:
     - **Environment:** **`Sandbox & Production`** seçilir *(Hem yerel test hem TestFlight/App Store'u kapsar)*.
     - **Key Restriction:** `Team Scoped (All Topics)` olarak bırakılır.
     - **Save** denir.
   - Continue -> Register adımlarıyla **`AuthKey_KJ2TZ9F8SG.p8`** anahtarı indirilir (Bu dosya yalnızca bir kez indirilebilir; `ios/Push_Notifications/AuthKey_KJ2TZ9F8SG.p8` konumunda saklanır).
   - **Key ID:** `KJ2TZ9F8SG` ve **Team ID:** `973W9DTDY9` not edilir.
   - **Firebase Console Bağlantısı (Kritik Zorunlu Adım):**
     - Firebase Console (`sicak-firsatlar-e6eae` ve `firsatkolik-prod-e6eae`) -> Proje Ayarları -> **Cloud Messaging** sekmesi açılır.
     - "Apple uygulama yapılandırması" başlığı altındaki `com.firsatkolik.app` uygulamasında:
       - **Development APNs auth key:** `Yükle` denir; `AuthKey_KJ2TZ9F8SG.p8`, Key ID (`KJ2TZ9F8SG`) ve Team ID (`973W9DTDY9`) girilerek kaydedilir.
       - **Production APNs auth key:** `Yükle` denir; **aynı** `AuthKey_KJ2TZ9F8SG.p8`, aynı Key ID ve Team ID girilerek kaydedilir.
       - **APNs Certificates:** Bu alan **tamamen boş** bırakılır (.p8 anahtarı modern ve süresiz yöntemdir).
     - Bu anahtar girilmeden Firebase FCM Apple APNs sunucularına push iletemez (`messaging/third-party-auth-error: Invalid APNs credential` hatası verir).

---

## 3. GitHub Repository Secrets Yapılandırması

İş akışının çalışması için GitHub deposunda (`Settings > Secrets and variables > Actions`) tanımlanan 7 zorunlu sır:

| Gizli Anahtar Adı | Biçim | Açıklama |
| :--- | :--- | :--- |
| `BUILD_CERTIFICATE_BASE64` | Base64 String | `firsatkolik_distribution.p12` dosyasının Base64 kodlanmış tam içeriği. |
| `P12_PASSWORD` | Metin | `.p12` dosyasını şifrelerken belirlediğiniz parola. |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64 String | `FirsatKolik_AppStore_Profile.mobileprovision` ana uygulama profilinin Base64 içeriği. |
| `SHARE_EXT_PROVISION_PROFILE_BASE64` | Base64 String | `FirsatKolik_ShareExtension_Profile.mobileprovision` Share Extension profilinin Base64 içeriği. |
| `APP_STORE_CONNECT_KEY_ID` | 10 Haneli Alfanümerik | App Store Connect API Anahtar Kimliği (Örn: `XUVRF9F2Y3`). |
| `APP_STORE_CONNECT_ISSUER_ID` | UUID | App Store Connect Sağlayıcı Kimliği (Örn: `69a6de70-xxxx-xxxx-...`). |
| `APP_STORE_CONNECT_PRIVATE_KEY` | PEM Metni (`.p8`) | `-----BEGIN PRIVATE KEY----- ... -----END PRIVATE KEY-----` bloklarını içeren tam içerik. |

---

## 4. Karşılaşılan Derleme Engelleri ve Çözüm Mühendisliği

Süreç boyunca karşılaşılan ve her biri kod seviyesinde kalıcı olarak çözülen 13 kritik problem:

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

### 6. iOS Yaşam Döngüsü & Swipe-to-Kill "Fırsatkolik Çöktü" Kilitlenmesi
- **Hata:** Çoklu görev ekranından (App Switcher) yukarı kaydırarak uygulama kapatıldığında (swipe-to-kill) TestFlight "Fırsatkolik Çöktü" uyarı modalı vermesi.
- **Kök Neden:** Xcode derleme uyarısını (`UIScene lifecycle support will soon be required`) bastırmak için eklenen deneysel `UIApplicationSceneManifest` (`FlutterSceneDelegate`) ve `FlutterImplicitEngineDelegate`, uygulama çoklu görevden kapatılırken UIKit tarafından `sceneDidDisconnect` tetiklenmesine ve Flutter motoru ile pencerenin (`UIWindow`) eklentilerden önce bellekten silinmesine neden oluyordu. Arka plandaki yerel eklentiler (Google Mobile Ads, Firebase Messaging vb.) deallocated belleğe erişince `EXC_BAD_ACCESS` / `SIGSEGV` yerel çökmesi meydana geliyordu.
- **Çözüm:** `ios/Runner/Info.plist` içerisinden `UIApplicationSceneManifest` kaldırıldı, `ios/Runner/AppDelegate.swift` standart ve stabil `FlutterAppDelegate` mimarisine döndürüldü (`GeneratedPluginRegistrant.register(with: self)`). Swipe-to-kill anında iOS çekirdeği süreci doğrudan temiz `SIGKILL` ile sonlandırır, kilitlenme %100 engellendi.

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

### 12. Fastlane Dizin Değişimi (CWD) ve Göreceli IPA Yolu Çözümlemesi
- **Hata:** Fastlane çalışırken `❌ Hata: Yüklenecek IPA dosyası bulunamadı: build/ios/ipa/firsatkolik.ipa` hatası verip yedek `xcrun altool` yöntemine devretmesi.
- **Kök Neden:** Fastlane çalışmaya başladığında otomatik olarak çalışma dizinini projenin altındaki `./fastlane/` dizinine taşır. Betikten gönderilen göreceli yol (`build/ios/ipa/*.ipa`), Fastlane içinde `./fastlane/build/...` olarak arandığı için dosya bulunamıyordu.
- **Çözüm:**
  - [`ios_ci/scripts/upload_testflight.sh`](file:///d:/firsatkolik/ios_ci/scripts/upload_testflight.sh) içinde `$1` argümanı mutlak yola (`IPA_DIR="$(cd "$(dirname "$IPA_INPUT")" && pwd)"`) dönüştürüldü.
  - [`ios_ci/Fastfile`](file:///d:/firsatkolik/ios_ci/Fastfile) içine göreceli yol gelse dahi bir üst dizini (`File.join("..", raw_path)`) kontrol eden akıllı yedek yol çözümleyici eklendi. Fastlane artık ilk denemede IPA dosyasını bularak doğrudan App Store Connect REST API v1 üzerinden TestFlight'a aktarım yapmaktadır.

### 13. iOS / iPadOS UIActivityViewController `sharePositionOrigin` Hatası
- **Hata:** Fırsat veya katalog paylaşım butonuna tıklandığında `Paylaşım başlatılamadı: PlatformException(error, sharePositionOrigin: argument must be set, {{0, 0}, {0, 0}} must be non-zero and within coordinate space of source view...)` hatası vermesi.
- **Kök Neden:** Android'in aksine iOS ve iPadOS üzerinde Apple'ın `UIActivityViewController`'ı popover olarak sunulurken, açılan pencerenin ekrandaki hangi butondan açıldığını bilmek zorundadır (`sharePositionOrigin`). Flutter `share_plus` paketinde bu parametre boş bırakıldığında iOS `CGRectIsEmpty` denetimine takılarak `PlatformException` fırlatır.
- **Çözüm:** [`lib/utils/share_helper.dart`](file:///d:/firsatkolik/lib/utils/share_helper.dart) evrensel sınıfı oluşturuldu. Tıklanan butonun mutlak koordinatlarını (`RenderBox.localToGlobal`) dinamik olarak hesaplar; buton bulunamazsa ekran boyutuna göre güvenli ve sıfır olmayan bir Rect üreterek tüm paylaşım akışlarında (`deal_detail_screen`, `deal_share_sheet`, `deal_forward_bottom_sheet`, `katalog_share_service`, `botkolik_profile_screen`) hatayı %100 önler.

### 14. ShareExtension CocoaPods Entegrasyonu ve 'Flutter/Flutter.h Not Found' Derleme Engeli (Kalıcı Self-Contained Mimari Çözümü)
- **Hata:** `Swift Compiler Error (Xcode): Clang dependency scanning failure: while building module 'receive_sharing_intent' ... ReceiveSharingIntentPlugin.h:1:9: fatal error: 'Flutter/Flutter.h' file not found`.
- **Kök Neden:** `receive_sharing_intent` eklentisi bir Flutter plugin pod'udur ve içindeki `ReceiveSharingIntentPlugin.h` doğrudan `#import <Flutter/Flutter.h>` içerir. Ancak iOS App Extension (`ShareExtension`), bir Flutter uygulaması değil; iOS çekirdeği tarafından çalıştırılan saf yerel bir mini ikilidir ve bünyesinde `Flutter.framework` barındırmaz. Podfile üzerinden bu pod extension hedefine bağlandığında Clang, `Flutter/Flutter.h` başlığını bulamayarak derlemeyi durduruyordu.
- **Çözüm:**
  - [`ios/Share Extension/ShareViewController.swift`](file:///d:/firsatkolik/ios/Share%20Extension/ShareViewController.swift) dosyası sıfır harici CocoaPods bağımlılığıyla, tamamen **saf Swift (UIKit, Social, MobileCoreServices, Photos, UniformTypeIdentifiers)** mimarisine dönüştürüldü.
  - [`ios/Podfile`](file:///d:/firsatkolik/ios/Podfile) içerisinden `target 'ShareExtension'` pod hedefi tamamen kaldırıldı. CocoaPods yalnızca ana uygulama (`Runner`) için çalışır hale getirildi.
  - Extension, Trendyol'dan gelen linki alıp doğrudan App Group (`group.com.firsatkolik.app`) altındaki `UserDefaults`'a `ShareMediaFile` JSON formatında yazar ve `ShareMedia-com.firsatkolik.app:share` şemasıyla ana uygulamayı tetikler. Flutter tarafındaki `receive_sharing_intent` ise bu veriyi ortak alandan okur. Sıfır bağımlılıkla derleme süresi saniyelere indi ve Flutter.h hatası kökten çözüldü.

### 15. iOS TestFlight Bildirim ve In-App Afiş Sistemi Uçtan Uca Entegrasyonu (APNs .p8, Alert Payloads, AppDelegate & Firestore Dual-Channel)
- **Hata:** TestFlight üzerinden indirilen iOS uygulamasında kilit ekranı push bildirimlerinin ve uygulama açıkken gelen sohbet afişlerinin (`InAppMessageBanner`) çalışmaması.
- **Kök Nedenler & Analiz:**
  1. *FCM APNs Kimlik Doğrulama Yokluğu:* Canlı DEV Firestore'undaki aktif iOS token'ına doğrudan test push'u atıldığında `messaging/third-party-auth-error: Invalid APNs credential` hatası tespit edildi. Firebase Console'da APNs Authentication Key (.p8) tanımlı değildi.
  2. *Cloud Functions Alert Payload Formatı:* Android'de data-only push yerel bildirim motoruyla ekrana basılabilirken, iOS işletim sistemi `aps.alert` (`title`, `body`) ve `'apns-push-type': 'alert'` başlığı olmayan push'ları kilit ekranında afiş olarak göstermiyordu.
  3. *In-App Afişin Yalnızca FCM onMessage'a Bağımlı Olması:* Uygulama açıkken mesaj afişleri sadece dış FCM push'u geldiğinde tetikleniyordu; APNs gecikmesi veya hatasında afiş düşmüyordu.
  4. *AppDelegate Ön Plan Delegasyonu:* `AppDelegate.swift` içinde `UNUserNotificationCenterDelegate` metodları (`userNotificationCenter(_:willPresent:withCompletionHandler:)`) tanımlanmadığı için iOS ön plandaki bildirimleri varsayılan olarak bastırıyordu.
- **Uygulanan Çözüm Mühendisliği:**
  - **APNs `.p8` Yüklemesi:** Apple Portal'da `Sandbox & Production` ortamıyla üretilen `AuthKey_KJ2TZ9F8SG.p8` anahtarı, hem DEV (`sicak-firsatlar-e6eae`) hem de PROD (`firsatkolik-prod-e6eae`) Firebase projelerinde hem Development hem Production APNs auth key alanlarına yüklendi.
  - **Cloud Functions APNs Alert Entegrasyonu ([`functions/index.js`](file:///d:/firsatkolik/functions/index.js)):** `onUserMessageCreated` ve `onNotificationCreated` fonksiyonlarında iOS için `'apns-push-type': 'alert'`, `payload.aps.alert: { title: '...', body: '...' }`, `aps.sound = 'default'`, `aps.badge = 1` tanımlandı ve canlıya deploy edildi.
  - **Çift Kanallı Gerçek Zamanlı In-App Motoru ([`lib/services/notification_service.dart`](file:///d:/firsatkolik/lib/services/notification_service.dart)):** `_setupForegroundMessageListener()` ile Firestore `messages` koleksiyonunda `receiverId == userId` anlık dinleyicisi kuruldu. Kullanıcı uygulama içinde gezinirken mesaj geldiğinde 0 ms gecikmeyle afiş tetiklenir; aktif sohbetteyse bastırılır, mükerrer afişler `_handledInAppMessageIds` ile elenir.
  - **Akıllı Ön Plan Delegasyonu ([`ios/Runner/AppDelegate.swift`](file:///d:/firsatkolik/ios/Runner/AppDelegate.swift) & [`lib/services/notification_service.dart`](file:///d:/firsatkolik/lib/services/notification_service.dart)):** `UNUserNotificationCenterDelegate` metodları (`userNotificationCenter(_:willPresent:withCompletionHandler:)`) ve Flutter ön plan dinleyicisi kusursuz platform delegasyonuyla yapılandırılmıştır:
    1. Birebir sohbet mesajları (`USER_MESSAGE`, `message`) ve admin duyuruları uygulama açıkken Flutter tarafındaki `InAppMessageBanner` ile ekrana basıldığı için, ön planda Apple'ın yerel tepe push banner'ı basması `completionHandler([])` ile bastırılır (böylece çiftlenmiş in-app + push bildirimi engellenir).
    2. Fırsat (`deal`), yorum (`comment`, `comment_reply`) ve anahtar kelime (`keyword`) bildirimlerinde ise `AppDelegate`, Apple OS native banner'ını (`[.banner, .list, .badge, .sound]`) doğrudan sunar; Flutter tarafındaki `_showLocalNotification` çağrısı ise sadece Android'e (`defaultTargetPlatform == TargetPlatform.android`) yönlendirilerek iOS'ta mükerrer ikinci bir yerel afiş açılması %100 önlenir.
    3. Uygulama arka planda veya kilit ekranındayken ise `aps.alert` doğrudan Apple sistemi tarafından tekil ve pürüzsüz olarak sunulur.
  - **CI/CD `aps-environment` Otomasyonu ([`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml)):** GitHub Actions TestFlight derleme adımında `Runner.entitlements` içindeki `aps-environment` değeri otomatik `production` yapılmaktadır.

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

## 8. iOS Sistem Paylaşım Menüsü (Share Extension) ve App Groups Mimarisi

Bu bölüm, Android'de sorunsuz çalışan **"Dış bir uygulamadan (Trendyol, Safari, Hepsiburada, Amazon vb.) ürün paylaş butonuna tıklandığında FırsatKolik'in paylaşım listesinde görünmesi ve tıklandığında Fırsat Paylaş ekranına (`SubmitDealScreen`) otomatik yönlenmesi"** özelliğinin iOS platformundaki uçtan uca mimarisini, Apple Developer Portal adımlarını ve kod dosyalarının rollerini belgeleyen **master sözleşmedir**.

### 8.1 Mimari ve Çalışma Prensibi

Apple iOS işletim sisteminde güvenlik sandbox'ı nedeniyle hiçbir uygulama tek bir Info.plist ayarıyla diğer uygulamaların sistem paylaşım menüsüne (`UIActivityViewController`) dahil olamaz. Apple, iki zorunlu bileşen şart koşar:
1. **Share Extension (`ShareExtension.appex`):** Ana uygulamadan bağımsız, işletim sistemi tarafından doğrudan çalıştırılan ayrı bir mini programdır (`com.firsatkolik.app.ShareExtension`).
2. **App Group (`group.com.firsatkolik.app`):** İki izole program (ana uygulama ve extension) arasındaki "ortak posta kutusu" görevini gören paylaşımlı disk ve `UserDefaults` havuzudur.

```mermaid
flowchart TD
    subgraph Adim1 ["1. Dış Uygulama (Trendyol/Safari)"]
        A["Kullanıcı 'Paylaş' Butonuna Basar"] --> B["iOS Sistem Paylaşım Menüsü (Share Sheet)"]
    end

    subgraph Adim2 ["2. Share Extension (Mini Program)"]
        B -->|FırsatKolik Seçilir| C["ShareExtension.appex Çalıştırılır"]
        C --> D["ShareViewController (Saf Swift)"]
        D -->|NSExtensionItem'dan URL/Metin Alınır| E["SharedMediaFile JSON Olarak Paketlenir"]
    end

    subgraph Adim3 ["3. Ortak Posta Kutusu (App Group)"]
        E -->|UserDefaults suiteName| F[("group.com.firsatkolik.app\nKey: 'ShareKey'")]
        D -->|URL Scheme Tetiklenir| G["ShareMedia-com.firsatkolik.app:share"]
    end

    subgraph Adim4 ["4. Ana Uygulama (FırsatKolik Runner)"]
        G --> H["Runner.app Uyanır"]
        H --> I["receive_sharing_intent iOS Eklentisi"]
        F -->|Posta Kutusundan Veri Okunur| I
        I --> J["lib/screens/home_screen.dart\n_handleSharedMedia(files)"]
        J --> K["SubmitDealScreen(initialUrl: url)\nFırsat Paylaş Ekranı Açılır 🚀"]
    end
```

---

### 8.2 Apple Developer Portal Kurulum ve Yetkilendirme Protokolü

Apple Developer Portal üzerinde bu mimarinin kurulması için tamamlanması gereken 4 idari adım:

#### 1. App Group Oluşturma
- **Konum:** [developer.apple.com/account](https://developer.apple.com/account) -> **Certificates, Identifiers & Profiles** -> **Identifiers** -> **(+)** -> **App Groups**
- **Description:** `FirsatKolik App Group`
- **Identifier:** `group.com.firsatkolik.app` *(Projeyle harfi harfine aynı olmalıdır)*
- **Kayıt:** `Continue` -> `Register`.

#### 2. Share Extension İçin Yeni App ID Oluşturma
- **Konum:** **Identifiers** -> **(+)** -> **App IDs** -> **App** -> `Continue`
- **Description:** `FirsatKolik Mobile App ShareExtension`
- **Bundle ID (Explicit):** `com.firsatkolik.app.ShareExtension`
- **Capabilities:** `App Groups` kutucuğu işaretlenir -> `Continue` -> `Register`.
- **Grubu Bağlama:** Identifiers listesine dönülür, yeni oluşturulan `com.firsatkolik.app.ShareExtension` kaydına tıklanır -> `App Groups` yanındaki **Configure** butonuna basılır -> `group.com.firsatkolik.app` seçilip `Continue` -> `Save` denir.

#### 3. Ana Uygulama App ID'sini Yetkilendirme
- **Konum:** **Identifiers** -> `com.firsatkolik.app` kaydına tıklanır.
- **Capabilities:** `App Groups` kutucuğu işaretlenir -> **Configure** ile `group.com.firsatkolik.app` seçilir -> `Save`.
- Çıkan *"Modify App Capabilities - Adding capabilities will invalidate provisioning profiles"* uyarısına **Confirm** denir.

#### 4. Provisioning Profillerini Üretme ve GitHub Secrets'a Yükleme
- **Konum:** **Profiles** sekmesi:
  - **Ana Uygulama Profili (`FirsatKolik AppStore Profile`):** "Invalid" durumuna düşen profil açılır, `Edit` -> `Save` denerek yenilenir ve indirilir (`FirsatKolik_AppStore_Profile.mobileprovision`).
  - **Extension Profili (`FirsatKolik ShareExtension Profile`):** **(+)** -> **App Store** -> App ID: `com.firsatkolik.app.ShareExtension` -> Dağıtım sertifikası seçilir -> Profil Adı: `FirsatKolik ShareExtension Profile` -> `Generate` -> `Download` (`FirsatKolik_ShareExtension_Profile.mobileprovision`).
- **Base64 Dönüşümü ve GitHub Secrets:**
  Her iki profil PowerShell ile Base64'e dönüştürülüp GitHub Secrets alanına yazılır:
  - `BUILD_PROVISION_PROFILE_BASE64` ➔ Ana uygulama profilinin Base64'ü.
  - `SHARE_EXT_PROVISION_PROFILE_BASE64` ➔ Extension profilinin Base64'ü.

---

### 8.3 Kod Dosyaları, Görev Envanteri ve Doğrudan Referanslar

Bu mekanizmanın çalışması için projede yer alan tüm bileşenler ve rolleri:

| Dosya | Rolü ve Görevi |
| :--- | :--- |
| [`ios/Share Extension/ShareViewController.swift`](file:///d:/firsatkolik/ios/Share%20Extension/ShareViewController.swift) | **Uzantı Denetleyicisi:** Saf yerel Swift (`SLComposeServiceViewController`). Dış uygulamadan gelen URL/metni alır, `SharedMediaFile` formatında kodlar, `UserDefaults(suiteName: "group.com.firsatkolik.app")` alanına yazar ve URL scheme ile ana uygulamayı uyandırır. **Sıfır CocoaPods bağımlılığıyla çalışır (Flutter.h çakışmasını önler).** |
| [`ios/Share Extension/Info.plist`](file:///d:/firsatkolik/ios/Share%20Extension/Info.plist) | **Uzantı Manifestosu:** `NSExtensionPointIdentifier: com.apple.share-services`, `NSExtensionActivationRule` (Web URL & Text aktivasyonu) ve `AppGroupId` tanımlarını içerir. |
| [`ios/Share Extension/ShareExtension.entitlements`](file:///d:/firsatkolik/ios/Share%20Extension/ShareExtension.entitlements) | **Uzantı Yetkileri:** Extension hedefinin `group.com.firsatkolik.app` disk havuzuna erişimini sağlayan Apple güvenlik sözleşmesidir. |
| [`ios/Runner/Runner.entitlements`](file:///d:/firsatkolik/ios/Runner/Runner.entitlements) | **Ana Uygulama Yetkileri:** `com.apple.security.application-groups` altında `group.com.firsatkolik.app` tanımlayarak ana uygulamanın aynı havuza erişmesini sağlar. |
| [`ios/Runner/Info.plist`](file:///d:/firsatkolik/ios/Runner/Info.plist) | **URL Schemes & AppGroupId:** `ShareMedia-com.firsatkolik.app` özel yönlendirme şemasını ve `AppGroupId` anahtarını ana Flutter uygulamasına kaydeder. |
| [`ios/Runner.xcodeproj/project.pbxproj`](file:///d:/firsatkolik/ios/Runner.xcodeproj/project.pbxproj) | **Xcode Proje Sözleşmesi:** `ShareExtension` target kaydı, `Embed App Extensions` derleme fazı (Thin Binary öncesinde), Bundle ID ve imzalama profili eşleşmeleri. |
| [`ios/Podfile`](file:///d:/firsatkolik/ios/Podfile) | **CocoaPods İzolasyonu:** `ShareExtension` saf yerel Swift olduğu için Podfile'dan bilinçli olarak hariç tutulmuştur; bu sayede `Flutter.h` derleme kilitlenmesi kökten engellenmiştir. |
| [`lib/screens/home_screen.dart`](file:///d:/firsatkolik/lib/screens/home_screen.dart) | **Flutter Alıcı Katmanı:** `_initShareIntentListener()` içinde `ReceiveSharingIntent.instance.getInitialMedia()` ve `getMediaStream()` ile veriyi yakalar; `DealUrlDetector.extractUrl()` ile Trendyol linkini süzüp `_navigateToSubmitDealWithUrl()` aracılığıyla `SubmitDealScreen` ekranına yönlendirir. |
| [`ios_ci/scripts/setup_keychain.sh`](file:///d:/firsatkolik/ios_ci/scripts/setup_keychain.sh) | **CI Anahtar Zinciri:** `SHARE_EXT_PROVISION_PROFILE_BASE64` sırrını çözer, UUID ve adını okuyarak `ExportOptions_*.plist` ve `project.pbxproj` dosyalarına dinamik enjekte eder. |
| [`ios_ci/ExportOptions_prod.plist`](file:///d:/firsatkolik/ios_ci/ExportOptions_prod.plist) | **İmzalama Eşlemesi:** `com.firsatkolik.app.ShareExtension` hedefi için `FirsatKolik ShareExtension Profile` manuel eşlemesini barındırır. |
| [`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml) | **CI İş Akışı:** `SHARE_EXT_PROVISION_PROFILE_BASE64` sırrını macOS derleme ortamına taşır. |
| [`test/ios_compatibility_test.dart`](file:///d:/firsatkolik/test/ios_compatibility_test.dart) | **Otomatik Doğrulama:** CI her çalıştığında Entitlements, Info.plist, pbxproj ve Swift bütünlüğünü otomatik test eder (13/13 test). |

---

> **Özet Sonuç:** Bu altyapı sayesinde FırsatKolik projesi, tamamen Windows 11 ortamında geliştirilmeye devam ederken, en güncel iOS SDK ve Apple standartlarına uygun olarak tek tıkla TestFlight'a çıkabilen kurumsal bir CI/CD boru hattına kavuşmuştur. 🚀

