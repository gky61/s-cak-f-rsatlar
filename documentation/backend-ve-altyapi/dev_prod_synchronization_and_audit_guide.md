# 🔄 FırsatKolik — DEV vs PROD Eşitleme, Denetim ve Senkronizasyon Master Kılavuzu

> [!IMPORTANT]
> **Mimari Eşitlik, Senkronizasyon ve Canlıya Geçiş Master Başvuru Belgesi:** Bu doküman; FırsatKolik platformunun Geliştirme (DEV) ve Canlı (PROD) ortamları arasındaki mimari, veritabanı, bulut servisleri, güvenlik kuralları, otonom botlar, API anahtarları ve mobil yapılandırma eşitliğini periyodik olarak denetlemek, iki ortam arasındaki farkları tespit etmek ve birkaç ay sonra dahi DEV'de yapılan tüm geliştirmeleri PROD'a sıfır hata ile aktarmak için hazırlanmış **resmi operasyonel master rehberdir**.

---

## 📑 İçindekiler
1. [🌟 7 Katmanlı ve 25 Noktalı Bütüncül Eşitlik Denetim Matrisi](#1--7-katmanlı-ve-25-noktalı-bütüncül-eşitlik-denetim-matrisi)
2. [🔍 Adım Adım Terminal Denetim Prosedürleri (Audit Commands)](#2--adım-adım-terminal-denetim-prosedürleri-audit-commands)
3. [🤖 Otomatik Teşhis ve Eşitleme Scriptleri](#3--otomatik-teşhis-ve-eşitleme-scriptleri)
4. [🚀 DEV'den PROD'a Canlıya Geçiş (Promotion) İş Akışı](#4--devden-proda-canlıya-geçiş-promotion-iş-akışı)
5. [📱 Google Play Store ve Android Release Özel Kontrolleri](#5--google-play-store-ve-android-release-özel-kontrolleri)
6. [🛡️ Firebase App Check ve Play Integrity Güvenlik Aşamaları](#6-️-firebase-app-check-ve-play-integrity-güvenlik-aşamaları)
7. [⚠️ Canlıya Geçiş Öncesi Kritik Kontrol Listesi (Master Pre-Flight Checklist)](#7-️-canlıya-geçiş-öncesi-kritik-kontrol-listesi-master-pre-flight-checklist)

---

## 1. 🌟 7 Katmanlı ve 25 Noktalı Bütüncül Eşitlik Denetim Matrisi

DEV ve PROD ortamlarının senkronizasyonunda aşağıdaki 25 kritik parametre tek tek kontrol edilmelidir:

### 🔹 Katman 1: Temel Bulut & Hesap Mimarisi (Cloud & Project Identity)
| # | Denetim Noktası | DEV (Geliştirme / Test) | PROD (Canlı / Production) | Eşitlik & Uyum Kuralı |
|---|---|---|---|---|
| **1** | **Firebase Proje ID** | `sicak-firsatlar-e6eae` | `firsatkolik-prod-e6eae` | İki izole GCP projesi. |
| **2** | **CLI Proje Alias (`.firebaserc`)**| `dev: sicak-firsatlar-e6eae` | `prod: firsatkolik-prod-e6eae` | CLI hedef komutları bu alias'ları kullanır. |
| **3** | **Google Cloud Faturalandırma** | Blaze Plan Aktif | Blaze Plan Aktif | Kotaların aşılmaması için bütçe alarmları devrede. |
| **4** | **GCP API Servisleri** | Play Integrity, Secret Manager vb. | Play Integrity, Secret Manager vb. | Gerekli tüm GCP API'leri iki projede de açık olmalı. |

### 🔹 Katman 2: Mobil Uygulama & Android Yapılandırması (Flutter Client)
| # | Denetim Noktası | DEV (Geliştirme / Test) | PROD (Canlı / Production) | Eşitlik & Uyum Kuralı |
|---|---|---|---|---|
| **5** | **Android Paket Adı (App ID)** | `com.sicakfirsatlar.sicak_firsatlar` | `com.firsatkolik.app` | Aynı telefona yan yana kurulabilmeli. |
| **6** | **google-services.json** | `android/app/src/dev/` | `android/app/src/prod/` | Her flavor kendi JSON dosyasını derleme anında alır. |
| **7** | **Android Keystore (İmzalama)** | Debug Keystore | `android/app/upload-keystore.jks` | Alias: `upload`, SHA-1 Firebase Console'a ekli. |
| **8** | **Google Play App Signing SHA-1**| — (Gerekmez) | Play Console'dan kopyalanan SHA-1 | Google Giriş ve Play Integrity için PROD Firebase'e eklenmeli. |
| **9** | **Shorebird Code-Push Config** | Flavor: `dev` App ID | Flavor: `prod` App ID | `shorebird.yaml` içinde iki ID tanımlı olmalı. |
| **10**| **AdMob Banner & App ID** | Test ID (`ca-app-pub-39402...`) | Canlı ID (`ca-app-pub-68539...`)| `firebase_options.dart` flavor'a göre seçmeli. |
| **11**| **App Check Sağlayıcısı** | `AndroidProvider.debug` | `AndroidProvider.playIntegrity` | Debug modda debug token, Release modda Play Integrity. |
| **12**| **Target SDK & Kotlin Sürümü** | SDK 36 (Android 16) / Java 17 | SDK 36 (Android 16) / Java 17 | `build.gradle` seviyesinde %100 eşit olmalı. |

### 🔹 Katman 3: Bulut Fonksiyonları (Cloud Functions Node.js 22)
| # | Denetim Noktası | DEV (Geliştirme / Test) | PROD (Canlı / Production) | Eşitlik & Uyum Kuralı |
|---|---|---|---|---|
| **13**| **Cloud Functions Sayısı** | 26 Adet Bağımsız Fonksiyon | 26 Adet Bağımsız Fonksiyon | Her iki projede de 26 fonksiyon aktif olmalı. |
| **14**| **Kod Dağıtım Sürümü** | En son `functions/` kodu | En son `functions/` kodu | Dağıtım zamanları (`updateTime`) güncel olmalı. |
| **15**| **GCP Secret Manager** | `GEMINI_API_KEY` (DEV) | `GEMINI_API_KEY` (PROD) | Secret Manager anahtarları iki projede de tanımlı. |
| **16**| **Cloud Scheduler (Zamanlanmış Cron)**| 5 Adet Aktif Cron İşi | 5 Adet Aktif Cron İşi | Gece 00:00, 03:00, 04:00, Kupon 6h, Katalog 12h. |

### 🔹 Katman 4: Veritabanı ve Güvenlik Kuralları (Firestore & Storage)
| # | Denetim Noktası | DEV (Geliştirme / Test) | PROD (Canlı / Production) | Eşitlik & Uyum Kuralı |
|---|---|---|---|---|
| **17**| **Firestore Güvenlik Kuralları**| `firestore.rules` | `firestore.rules` | İki projeye de aynı kurallar deploy edilmiş olmalı. |
| **18**| **Firestore Bileşik İndeksleri**| `firestore.indexes.json` | `firestore.indexes.json` | Composite ve Collection Group indeksleri tam eşit. |
| **19**| **Storage Güvenlik Kuralları** | `storage.rules` | `storage.rules` | `deals/` dizini okuma açık, yazma yetkili. |
| **20**| **Bildirim Hız Limitleri** | `systemConfig/notifications` (3/h, 8/d) | `systemConfig/notifications` (3/h, 8/d) | PROD limitleri tanımlı olmalı (spam önleme). |
| **21**| **Admin Yetkilendirmesi** | `users/{uid}.isAdmin == true` | `users/{uid}.isAdmin == true` | `muratcan.gokyokus@gmail.com` PROD'da admin olmalı. |

### 🔹 Katman 5: Web Admin Paneli & Domain
| # | Denetim Noktası | DEV (Geliştirme / Test) | PROD (Canlı / Production) | Eşitlik & Uyum Kuralı |
|---|---|---|---|---|
| **22**| **Web Admin Hosting Sürümü** | `https://sicak-firsatlar-e6eae.web.app`| `https://firsatkolik-prod-e6eae.web.app`| Son V9 Dashboard, APM Log ve Bildirim özellikleri aktif. |
| **23**| **Özel Alan Adı (Custom Domain)**| — | `https://firsatkolik.app/admin/` | Cloudflare Anycast IP (`199.36.158.100`, Gri Bulut). |

### 🔹 Katman 6: Otonom Botlar ve Sunucu (Compute Engine VM)
| # | Denetim Noktası | DEV (Geliştirme / Test) | PROD (Canlı / Production) | Eşitlik & Uyum Kuralı |
|---|---|---|---|---|
| **24**| **GCE VM Docker Konteynerleri** | Port 8081 (`dev-bot`) | Port 8082 (`prod-bot`) | `telegram-bot-server` üzerinde 7/24 aktif ve heartbeat atan. |
| **25**| **İzlenen Telegram Kanalları** | `@indirimkaplani`, `-3423...` | `@firsatkolik_canli`, `@indirimkaplani`| `settings/telegramBot.monitoredChannels` içinde tanımlı. |

---

## 2. 🔍 Adım Adım Terminal Denetim Prosedürleri (Audit Commands)

DEV ile PROD ortamlarını denetlerken aşağıdaki komutlar terminalden doğrudan çalıştırılır:

### 1. Bulut Fonksiyonlarının Durumunu ve Güncellenme Tarihlerini Denetleme
```bash
# DEV Fonksiyonları
gcloud functions list --project sicak-firsatlar-e6eae --format="table(name.basename(),updateTime,status)"

# PROD Fonksiyonları
gcloud functions list --project firsatkolik-prod-e6eae --format="table(name.basename(),updateTime,status)"
```
*Beklenen Sonuç:* Her iki projede de 26 fonksiyon listelenmeli, durumları `ACTIVE` olmalı ve `updateTime` değerleri son deploy tarihiyle örtüşmelidir.

### 2. Zamanlanmış Cron Görevlerinin (Cloud Scheduler) Denetlenmesi
```bash
# DEV Cron Görevleri
gcloud scheduler jobs list --project sicak-firsatlar-e6eae --location us-central1

# PROD Cron Görevleri
gcloud scheduler jobs list --project firsatkolik-prod-e6eae --location us-central1
```
*Beklenen Sonuç:* Her iki projede de 5 temel cron işi (`cleanupOldImages`, `purgeOldDeals`, `cleanupExpiredDeals`, `scrapeCouponsScheduled`, `scrapeCatalogsScheduled`) `ENABLED` durumda olmalıdır.

### 3. Web Hosting Dağıtım Sürümlerini Denetleme
```bash
firebase hosting:channel:list --project dev
firebase hosting:channel:list --project prod
```
*Beklenen Sonuç:* Her iki projenin `live` kanalındaki son yayın zamanı (`Last Release Time`) güncel olmalıdır.

### 4. Secret Manager Anahtarlarını Denetleme
```bash
firebase functions:secrets:access GEMINI_API_KEY --project dev
firebase functions:secrets:access GEMINI_API_KEY --project prod
```
*Beklenen Sonuç:* Her iki komut da ilgili ortama ait geçerli `AQ.Ab8RN...` anahtarını döndürmelidir.

---

## 3. 🤖 Otomatik Teşhis ve Eşitleme Scriptleri

Bu repo içinde hazır olarak bulunan Node.js scriptleri iki ortamı saniyeler içinde karşılaştırır ve eksikleri tamamlar:

### 1. Hızlı Tablo Karşılaştırması (`show_table.js`)
Tüm Firestore kök koleksiyonlarını ve doküman sayılarını yan yana tablo olarak basar:
```bash
node C:\Users\murat\.gemini\antigravity-ide\brain\44ca3c44-06fc-4fa1-b2ba-f813f16e189a\scratch\show_table.js
```

### 2. Derinlemesine Ayar Karşılaştırması (`inspect_special_collections.js`)
`settings`, `system` ve `systemConfig` koleksiyonlarındaki tüm dokümanların JSON içeriklerini yan yana listeler:
```bash
node C:\Users\murat\.gemini\antigravity-ide\brain\44ca3c44-06fc-4fa1-b2ba-f813f16e189a\scratch\inspect_special_collections.js
```

### 3. PROD Veritabanı Otomatik Eşitleyici (`sync_prod_firestore.js`)
PROD veritabanında hız limitlerini (`systemConfig/notifications`), bot kanallarını (`settings/telegramBot`) ve admin yetkisini (`users/k1lzOiOUiwXX60Sfrtv2uFekfDr2`) tek işlemle eşitler:
```bash
node C:\Users\murat\.gemini\antigravity-ide\brain\44ca3c44-06fc-4fa1-b2ba-f813f16e189a\scratch\sync_prod_firestore.js
```

---

## 4. 🚀 DEV'den PROD'a Canlıya Geçiş (Promotion) İş Akışı

DEV ortamında test edilip onaylanan bir geliştirme paketi canlıya taşınırken **aşağıdaki sıra kesinlikle takip edilmelidir**:

```bash
# -------------------------------------------------------------
# ADIM 1: GÜVENLİK KURALLARINI VE İNDEKSLERİ DAĞIT
# -------------------------------------------------------------
firebase deploy --only firestore:rules,storage --project prod
firebase deploy --only firestore:indexes --project prod

# -------------------------------------------------------------
# ADIM 2: CLOUD FUNCTIONS 26 SERVİSİ DAĞIT
# -------------------------------------------------------------
firebase deploy --only functions --project prod

# -------------------------------------------------------------
# ADIM 3: WEB ADMİN PANELİNİ YAYINLA
# -------------------------------------------------------------
firebase deploy --only hosting --project prod

# -------------------------------------------------------------
# ADIM 4: PROD VERİTABANI AYARLARINI DOĞRULA (Gerektiğinde)
# -------------------------------------------------------------
node C:\Users\murat\.gemini\antigravity-ide\brain\44ca3c44-06fc-4fa1-b2ba-f813f16e189a\scratch\sync_prod_firestore.js

# -------------------------------------------------------------
# ADIM 5: TELEGRAM BOTUNU GÜNCELLE (Bot kodunda değişiklik varsa)
# -------------------------------------------------------------
python cloud-run-bot/deploy_agent.py firsatkolik-prod-e6eae
```

---

## 5. 📱 Google Play Store ve Android Release Özel Kontrolleri

Mobil uygulamanın canlı sürümünü Google Play Console'a yüklemeden önce:

### 1. Versiyon Kodunu Artırma (`android/app/build.gradle` veya `local.properties`)
Her yeni Play Store yüklemesinde `versionCode` değeri bir önceki yayından kesinlikle büyük olmalıdır:
```properties
flutter.versionCode=2
flutter.versionName=1.0.1
```

### 2. AAB Derleme Komutu
```bash
# 1. Shorebird Canlı Kod Güncelleme Destekli AAB (Tavsiye Edilen)
shorebird release android --flavor prod -t lib/main.dart

# 2. Standart Flutter Release AAB
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
```

### 3. Google Play App Signing SHA-1 Kaydı (Kritik!)
Google Play Console uygulamanızı imzalarken kendi Google Play Signing sertifikasını kullanır:
1. **Google Play Console** > **Setup** > **App Integrity** > **App Signing** sekmesine gidin.
2. **SHA-1 fingerprint** değerini kopyalayın.
3. **Firebase Console** > **PROD Projesi (`firsatkolik-prod-e6eae`)** > **Project Settings** > **General** > **Android Uygulaması (`com.firsatkolik.app`)** ayarlarına gidin.
4. Bu SHA-1 değerini **Add fingerprint** ile kaydedin.
> *Eğer bu adım atlanırsa canlıya çıkan uygulamada Google ile Giriş ve Play Integrity çalışmaz!*

---

## 6. 🛡️ Firebase App Check ve Play Integrity Güvenlik Aşamaları

Canlıya çıkış sürecinde App Check yapılandırması iki kademeli yönetilmelidir:

1. **İzleme Modu (Monitoring / Audit Mode - İlk 14 Gün):**
   * Firebase Console > App Check > Firestore ve Cloud Functions servislerinde yaptırım (Enforce) **KAPALI** tutulur.
   * Amaç: Uygulamanın Play Integrity doğrulamalarının sorunsuz geçtiğini metrikler üzerinden izlemek, hiçbir meşru kullanıcının engellenmediğinden emin olmak.
2. **Yaptırım Modu (Enforced - Canlı Kararlı Faz):**
   * İsteklerin %98+ oranında Play Integrity'den geçtiği doğrulandıktan sonra **Enforce** butonuna basılarak yetkisiz API istekleri, botlar ve tersine mühendislik girişimleri tamamen engellenir.

---

## 7. ⚠️ Canlıya Geçiş Öncesi Kritik Kontrol Listesi (Master Pre-Flight Checklist)

Canlıya geçiş operasyonunda tek bir maddenin dahi atlanmadığından emin olmak için bu kontrol listesini kullanın:

- [ ] **1. Paket Adı:** `android/app/build.gradle` içinde PROD flavor `com.firsatkolik.app` olarak tanımlı mı?
- [ ] **2. Keystore:** `upload-keystore.jks` dosyası `android/app/` altında mevcut ve `key.properties` yapılandırılmış mı?
- [ ] **3. Google-Services:** `android/app/src/prod/google-services.json` dosyası PROD projesine (`228657473310`) ait mi?
- [ ] **4. AdMob:** `firebase_options.dart` dosyasının release modda gerçek canlı ID'yi (`ca-app-pub-6853997017739651/8758625050`) döndürdüğü doğrulandı mı?
- [ ] **5. Play Integrity:** Google Play Console App Integrity alanında Firebase PROD projesi bağlandı mı?
- [ ] **6. Play App Signing SHA-1:** Google Play App Signing SHA-1 parmak izi PROD Firebase Console'a eklendi mi?
- [ ] **7. Shorebird:** `shorebird.yaml` dosyasında `prod` flavor için doğru App ID tanımlı mı?
- [ ] **8. 26 Cloud Function:** PROD projesine 26 fonksiyonun tamamı `firebase deploy --only functions --project prod` ile hatasız dağıtıldı mı?
- [ ] **9. Cloud Scheduler:** PROD GCP konsolunda 5 cron görevinin tamamı `ENABLED` durumda mı?
- [ ] **10. Firestore Kuralları:** `firestore.rules` PROD'a deploy edildi mi?
- [ ] **11. Storage Kuralları:** `storage.rules` PROD'a deploy edildi mi?
- [ ] **12. Firestore İndeksleri:** `firestore.indexes.json` PROD'a deploy edildi mi?
- [ ] **13. Bildirim Hız Limitleri:** PROD `systemConfig/notifications` dokümanında `categoryHourlyLimit: 3` ve `categoryDailyLimit: 8` tanımlı mı?
- [ ] **14. Bot Kanalları:** PROD `settings/telegramBot` dokümanında `@indirimkaplani` ve `@firsatkolik_canli` kanalları tanımlı mı?
- [ ] **15. Bot Heartbeat:** PROD botunun VM üzerinde aktif çalıştığı (`lastHeartbeatAt` zaman damgasının güncel olduğu) teyit edildi mi?
- [ ] **16. Web Admin Dağıtımı:** `https://firsatkolik-prod-e6eae.web.app/admin/` ve `https://firsatkolik.app/admin/` adreslerine en son V9 / APM sürümü deploy edildi mi?
- [ ] **17. Admin Kullanıcı:** PROD Firestore `users` tablosunda `muratcan.gokyokus@gmail.com` hesabının `isAdmin: true` olduğu doğrulandı mı?
- [ ] **18. Cloudflare DNS:** `firsatkolik.app` için A kaydı `199.36.158.100` (Gri Bulut) ve TXT doğrulama kaydı aktif mi?

---
*FırsatKolik DEV vs PROD Eşitleme, Denetim ve Senkronizasyon Master Kılavuzu — 2026*
