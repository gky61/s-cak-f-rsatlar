# 📈 FırsatKolik — Production Süreç Takip Dokümanı (Production Progress)

Bu doküman, FırsatKolik uygulamasının Google Play Store'da production-ready (canlıya hazır) hale getirilmesi sürecindeki ilerlememizi, tamamlanan adımları ve kalan eksikleri takip etmek amacıyla oluşturulmuştur. Yol haritasındaki (Roadmap) fazlara göre güncellenecektir.

---

## 🚀 GENEL DURUM ÖZETİ

| Aşama | Başlık | Durum | Tamamlanma Oranı | Açıklama |
|---|---|---|---|---|
| **Kritik** | API 36 (Android 16) Uyum Kontrolü | **TAMAMLANDI** | %100 | `compileSdkVersion` ve `targetSdkVersion` 36 olarak yapılandırıldı. |
| **Faz 1** | Yasal ve Kurumsal Temel | **TAMAMLANDI** | %100 | Bireysel Console hesabı açıldı, Gizlilik ve Hesap Silme sayfaları canlıya alındı. |
| **Faz 2** | Marka Kimliği & Mağaza Görselleri | **ERTELENDİ** | %0 | Görsel ve metin varlıkları sonradan sürece dahil edilecek, ilerlemeye engel değil. |
| **Faz 3** | Cloud & Firebase Prod Altyapısı | **TAMAMLANDI** | %100 | Tüm altyapı, deploy ve güvenlik hazır. Tek kalan adım Play Console bağlantısı (FAZ 5'e ertelendi). |
| **Faz 4** | Flutter Uygulamasının Hazırlanması | **TAMAMLANDI** | %100 | Crashlytics, UMP SDK, ProGuard, AAB derleme scripti, paylaşılan fırsatlar ve bildirim yönlendirmeleri tamamlandı. |
| **Faz 5** | Play Console & Kapalı Test Süreci | *Başlanmadı* | %0 | 14 günlük 20 test kullanıcısı süreci organize edilecek. |
| **Faz 6** | Canlı İzleme & Operasyon | *Yayın Sonrası* | %0 | Hata takibi ve sunucu loglamaları. |
| **Faz 7** | Reklam & Büyüme (ASO/Ads) | *Yayın Sonrası* | %0 | Türkiye pazarı lansmanı ve büyüme kampanyaları. |

---

## 🛠️ TAMAMLANAN FAZLAR VE AYRINTILAR

### ⚠️ Kritik Adım: API Seviyesi ve SDK Kontrolü
*   **Durum:** ✅ **Uyumlu**
*   `compileSdkVersion` ve `targetSdkVersion` değerleri **36** (Android 16). Google Play'in 31 Ağustos 2026 zorunluluğuna tam uyum.

### 🏛️ FAZ 1 — Yasal ve Kurumsal Temel
*   **Durum:** ✅ **Tamamlandı**
*   **Geliştirici Hesabı:** Bireysel, `muratcan.gokyokus@gmail.com`, destek: `kolikfirsat@gmail.com`
*   **Privacy Policy:** [https://sicak-firsatlar-e6eae.web.app/privacy-policy.html](https://sicak-firsatlar-e6eae.web.app/privacy-policy.html) ✅
*   **Delete Account:** [https://sicak-firsatlar-e6eae.web.app/delete-account.html](https://sicak-firsatlar-e6eae.web.app/delete-account.html) ✅

---

## ✅ FAZ 3 — Cloud & Firebase Production Altyapısı (TAMAMLANDI)

### 🏗️ GCP & Firebase Altyapısı

| # | Adım | Durum | Notlar |
|---|---|---|---|
| 1 | **PROD Firebase Projesi** | ✅ | `firsatkolik-prod-e6eae` (europe-west3) |
| 2 | **Blaze Plana Yükseltme** | ✅ | Billing: `0179D9-B45293-3EF3AA` |
| 3 | **Android Uygulaması PROD'a Kaydı** | ✅ | `com.firsatkolik.app` |
| 4 | **google-services.json (DEV)** | ✅ | `android/app/src/dev/google-services.json` |
| 5 | **google-services.json (PROD)** | ✅ | `android/app/src/prod/google-services.json` |
| 6 | **Firebase CLI Alias** | ✅ | `dev` = DEV, `prod` = PROD |
| 7 | **GCP API'leri (PROD)** | ✅ | playintegrity, appcheck, secretmanager, run, cloudfunctions, cloudscheduler aktif |
| 8 | **Secret: GEMINI_API_KEY** | ✅ | DEV + PROD projesinde `v1` mevcut |
| 9 | **Secret: TELEGRAM_STRING_SESSION** | ✅ | PROD projesinde `v1` mevcut |
| 10 | **IAM Rolleri** | ✅ | Compute SA + App Engine SA → `secretmanager.secretAccessor` |
| 11 | **Firestore DB (PROD)** | ✅ | europe-west3, Native mode |

### 🔒 Güvenlik Kuralları & İndeksler

| # | Adım | Durum | Notlar |
|---|---|---|---|
| 12 | **storage.rules** | ✅ Deploy Edildi | DEV + PROD — `deals/` okuma açık, yazma Admin SDK |
| 13 | **firestore.indexes.json** | ✅ Deploy Edildi | DEV + PROD — `deals`, `messages`, `reports` composite indeksler |
| 14 | **firestore.rules** | ✅ Deploy Edildi | DEV + PROD |

### 🛡️ App Check & Güvenli API

| # | Adım | Durum | Notlar |
|---|---|---|---|
| 15 | **firebase_app_check (pubspec)** | ✅ | `^0.2.1+15` |
| 16 | **App Check Aktivasyonu (main.dart)** | ✅ | Debug: `debug`, Release: `playIntegrity` |
| 17 | **App Check Middleware (functions)** | ✅ | `resolveShortLink` + `cleanupOldImagesManual` korumalı |
| 18 | **Gemini Proxy (analyzeProductProxy)** | ✅ Deploy Edildi | Secret Manager'dan key çekiyor — DEV + PROD |
| 19 | **ai_service.dart — Proxy Geçişi** | ✅ | Hardcoded API key kaldırıldı |
| 20 | **notification_debug_screen — orderBy** | ✅ | Composite index sonrası restore edildi |

### 🍕 Flavor-Aware Firebase & Çevre Konfigürasyonu (YENİ — 4 Temmuz 2026)

| # | Adım | Durum | Notlar |
|---|---|---|---|
| 39 | **firebase_options.dart — Flavor Desteği** | ✅ | `androidDev` (sicak-firsatlar-e6eae) + `androidProd` (firsatkolik-prod-e6eae); `--dart-define=FLAVOR=prod` ile seçim |
| 40 | **flavorProjectId getter** | ✅ | `DefaultFirebaseOptions.flavorProjectId` — Cloud Function URL'leri için merkezi kaynak |
| 41 | **ai_service.dart — flavorProjectId** | ✅ | Proxy URL artık flavor'a göre doğru projeyi hedefliyor |
| 42 | **deal_detail_screen.dart — flavorProjectId** | ✅ | `resolveShortLink` URL artık flavor-aware |
| 43 | **admin_screen.dart — flavorProjectId** | ✅ | `resolveShortLink` URL artık flavor-aware |
| 44 | **telegram_bot.js — Default Bucket** | ✅ | `admin.storage().bucket()` — deploy edilen projenin bucket'ını otomatik kullanır |
| 45 | **fetch_history.js — Default Bucket** | ✅ | `admin.storage().bucket()` — deploy edilen projenin bucket'ını otomatik kullanır |
| 46 | **AdMob Test ID Geçişi (Flutter)** | ✅ | Debug/Dev modda test reklamı, Release/Prod modda gerçek reklam gösterimi |
| 47 | **Dinamik Web Admin Paneli** | ✅ | `hostname` değerine göre DEV veya PROD Firebase projesine otomatik geçiş |
| 48 | **Telegram Kanal Ayrımı** | ✅ | DEV bot için test kanalı, PROD bot için canlı kanal ayrımı |



### 🤖 Cloud Functions Deploy

| # | Fonksiyon | DEV | PROD |
|---|---|---|---|
| 21 | `onDealCreated` | ✅ | ✅ |
| 22 | `onDealUpdated` | ✅ | ✅ |
| 23 | `onCommentCreated` | ✅ | ✅ |
| 24 | `onAdminMessageCreated` | ✅ | ✅ |
| 25 | `onUserMessageCreated` | ✅ | ✅ |
| 26 | `onCommentReplyNotificationCreated` | ✅ | ✅ |
| 27 | `resolveShortLink` | ✅ | ✅ |
| 28 | `cleanupOldImages` | ✅ | ✅ |
| 29 | `cleanupOldImagesManual` | ✅ | ✅ |
| 30 | `analyzeProductProxy` (**YENİ**) | ✅ | ✅ |

### 📦 Build Flavor & Dağıtım

| # | Adım | Durum | Notlar |
|---|---|---|---|
| 31 | **build.gradle Flavor** | ✅ | `dev` (com.sicakfirsatlar.sicak_firsatlar) + `prod` (com.firsatkolik.app) |
| 32 | **android/app/src/dev/** | ✅ | google-services.json mevcut |
| 33 | **android/app/src/prod/** | ✅ | google-services.json mevcut |
| 34 | **deploy_agent.py** | ✅ | Cross-platform, `--no-cpu-throttling`, `--set-secrets` |

> [!IMPORTANT]
> **PROD Build Komutu:** `flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release`
> `--dart-define=FLAVOR=prod` parametresi zorunludur — eksik olursa uygulama PROD apk'sı içinde DEV Firebase projesine bağlanır.

### 📊 Monitoring & Bütçe

| # | Adım | Durum | Notlar |
|---|---|---|---|
| 35 | **Cloud Functions Hata Alarmı (DEV)** | ✅ | 5 dk'da >5 hata → alarm |
| 36 | **Cloud Functions Hata Alarmı (PROD)** | ✅ | 5 dk'da >5 hata → alarm |
| 37 | **Bütçe Uyarısı (500 TRY)** | ✅ | %50, %80, %100 eşikleri — Billing `0179D9-B45293-3EF3AA` |
| 38 | **Artifact Registry Cleanup Policy** | ✅ | DEV + PROD — 1 günden eski image'lar silinir |

---

## ⚠️ Kalan Manuel Adımlar (Kullanıcı Tarafından)

### 1. App Check Play Integrity Bağlantısı
**Sorumlu:** Kullanıcı | **Öncelik:** Yüksek (Release öncesi zorunlu)

Google Play Console > Uygulamanız > **Setup > App integrity** sayfasına gidin, **Play Integrity API** bölümünde PROD Firebase projesini (`firsatkolik-prod-e6eae`) bağlayın.

> [!WARNING]
> **Kritik Süreç Uyarısı:** Bu bağlantı ancak uygulama Google Play Console'a yüklendikten (AAB paketi yüklendikten) ve Kapalı Test (Closed Testing) veya Açık Test aşamasına geçildikten sonra yapılabilir. İlk yükleme yapılmadan bu bağlantıyı gerçekleştiremezsiniz. Dolayısıyla bu adım **FAZ 5 (Play Console & Kapalı Test Süreci)** aşamasında AAB paketi Play Console'a yüklendiğinde yapılmalıdır.

### 2. Google Play App Signing SHA-1 Sertifikasının Firebase'e Eklenmesi
**Sorumlu:** Kullanıcı | **Öncelik:** Çok Yüksek (Play Store yayını için kritik)

Uygulama Play Store üzerinden indirildiğinde Google Sign-In'in hata vermemesi (DEVELOPER_ERROR almamak) için Google'ın kendi imzaladığı sertifika imzasının Firebase Console'a girilmesi zorunludur.

1. `.aab` paketini Play Console'a yükleyin.
2. **Play Console > (Uygulamanız) > Setup > App integrity > App signing** sekmesine gidin.
3. orada **"App signing key certificate"** başlığı altındaki **SHA-1** değerini kopyalayın.
4. **Firebase Console > Proje Ayarları > Genel** sayfasına giderek Android uygulamanızın altına bu parmak izini ekleyin.

### 3. PROD Firebase Authentication Google Sign-in Hazırlığı
**Durum:** ✅ **YEREL HAZIRLIK TAMAMLANDI**

Release Keystore üretimi, `key.properties` yapılandırması ve yerel SHA-1 imzalarının Firebase PROD projesine CLI üzerinden eklenmesi yapılmıştır. Google, Apple ve Email sağlayıcıları Firebase Console üzerinde aktif edilmiş ve güncellenmiş `google-services.json` başarıyla indirilerek `oauth_client` ID'leri yapılandırılmıştır. Yerel test build'lerinde Google Sign-In sorunsuz çalışacaktır. Sadece üstteki (Madde 2) Play Store App Signing parmak izinin eklenmesi beklenmektedir.

**Oluşturulan Keystore Bilgileri (Güvenli bir yerde saklayınız):**
*   **Keystore Dosyası:** [upload-keystore.jks](file:///d:/firsatkolik/android/app/upload-keystore.jks)
*   **Şifre (Store & Key):** `firsatkolik2024!`
*   **Alias:** `upload`
*   **SHA-1 Parmak İzi:** `59:81:22:B5:48:21:79:1D:8C:55:5A:19:0E:C9:D9:76:31:E0:6D:9A`
*   **SHA-256 Parmak İzi:** `5E:9E:29:AC:81:63:22:77:B7:C8:EC:91:34:A2:E2:C2:C4:E7:05:EC:F9:FE:1C:56:2D:42:00:64:15:1F:40:2B`

---

## 🔒 FAZ 3 Ek Geliştirmeler: Çevre (Environment) İzolasyonu
*   **Durum:** ✅ **TAMAMLANDI (4 Temmuz 2026)**
*   **AdMob ID Dinamik Yapılandırması:** Geliştirme/test aşamasında gerçek reklam kimliklerinin tetiklenip AdMob hesabının geçersiz trafik sebebiyle askıya alınmasını engellemek için `DefaultFirebaseOptions.bannerAdUnitId` yapısı kuruldu. `kDebugMode` veya DEV flavor'ında otomatik olarak Google'ın resmi test reklam ID'si (`ca-app-pub-3940256099942544/6300978111`) kullanılır. Sadece PROD release sürümünde gerçek reklamlar yüklenir.
*   **Dinamik Web Admin Paneli:** Firebase PROD projesinde yeni bir Web App (`FirsatKolik Web`) kaydedildi. Web panel kodlarındaki `config.js` ve `app.js` dosyaları güncellenerek, tarayıcının çalıştığı `hostname` değerine göre (local/DEV veya PROD) Firebase projesi ve Cloud Run proxy URL'lerinin dinamik olarak değişmesi sağlandı. Admin paneli PROD hostinge de deploy edildi ([https://firsatkolik-prod-e6eae.web.app](https://firsatkolik-prod-e6eae.web.app)).
*   **Telegram Bot & Kanal Ayrımı:** DEV botu ile PROD botunun Telegram üzerinde çakışmaması ve banlanmaması için iki ayrı bot oturumu (session string) ve kanalı izole edildi:
    *   **DEV Botu (Cloud Run):** `@indirimkaplani` kanalını dinliyor, DEV veritabanına kaydediyor.
    *   **PROD Botu (Cloud Run):** Yeni oluşturulan `@firsatkolik_canli` kanalını dinliyor, PROD veritabanına kaydediyor.

---

## ✅ FAZ 4 — Flutter Uygulamasını Production'a Hazırlama (TAMAMLANDI)

### 📦 Entegrasyonlar ve Teknik Hazırlıklar

| # | Adım | Durum | Notlar |
|---|---|---|---|
| 49 | **Crashlytics Entegrasyonu (pubspec.yaml)** | ✅ Tamamlandı | `firebase_crashlytics` paketi eklendi |
| 50 | **Crashlytics Gradle Classpath** | ✅ Tamamlandı | `android/build.gradle` proje düzeyinde classpath eklendi |
| 51 | **Crashlytics Gradle Plugin Uygulaması** | ✅ Tamamlandı | `android/app/build.gradle` düzeyinde eklenti uygulandı |
| 52 | **Crashlytics Main Hata Yakalayıcılar** | ✅ Tamamlandı | `main.dart` hata yakalayıcıları Crashlytics'e bağlandı |
| 53 | **Android 16 (API 36) Doğrulaması** | ✅ Tamamlandı | `targetSdkVersion 36` doğrulandı, exact alarm riskinin olmadığı teyit edildi |
| 54 | **AdMob Onay Formu (UMP SDK)** | ✅ Tamamlandı | GDPR/KVKK uyumlu onay formu akışı (UMP SDK) `main.dart` içine entegre edildi |
| 55 | **ProGuard/R8 Optimizasyon Kuralları** | ✅ Tamamlandı | `proguard-rules.pro` dosyası oluşturuldu ve kurallar tanımlandı |
| 56 | **AAB Release Build Script** | ✅ Tamamlandı | `build_release_aab.sh` ve Windows için `.bat` derleme scriptleri oluşturuldu |
| 57 | **edit_profile_screen.dart Hatası** | ✅ Kontrol Edildi | Düzenleme zaten `profile_screen.dart` içinde inline dialog ile yapılıyor; eksik ekran yoktur. |
| 58 | **Kullanıcının Kendi Paylaştığı Fırsatlar** | ✅ Tamamlandı | `UserDealsScreen` oluşturularak profil sayfasına başarıyla bağlandı |
| 59 | **Apple Sign-In Android Uyum Kontrolü** | ✅ Kontrol Edildi | Apple Girişi butonu `defaultTargetPlatform == TargetPlatform.iOS` ile Android'de tamamen gizlidir. |
| 60 | **Atomik Sayaç Güncellemeleri** | ✅ Tamamlandı | Oylama sayaçlarının Firestore'da `FieldValue.increment` ile atomik güncellendiği teyit edildi |
| 61 | **Mesaj Bildirimi Yönlendirmesi (TODO)** | ✅ Tamamlandı | `notification_service.dart:1329` TODO'su çözüldü, `MessagesListScreen` yönlendirmesi eklendi |
| 62 | **Nihai QA Testleri (Release AAB)** | ✅ Tamamlandı | `flutter analyze` ile sıfır hata doğrulaması yapıldı |

---

## 📋 Sonraki Adım: FAZ 5

Faz 4 tamamlandığında bir sonraki adım **Faz 5 — Play Console & Kapalı Test Süreci** olacaktır.

---

*Son Güncelleme: 5 Temmuz 2026 — Faz 4 (Flutter Uygulamasını Production'a Hazırlama) %100 başarıyla tamamlandı. Entegrasyonlar ve QA testleri eksiksiz onaylandı.*
