# ⚙️ FırsatKolik — Ortam Yönetimi ve Canlıya Geçiş Kılavuzu (Environment Management)

> [!NOTE]
> Bu doküman Ortam Yönetimi ve Canlıya Geçiş operasyonel el kitabıdır. Sistemin güncel güvenlik kuralları, 26 Cloud Function envanteri, sıfır maliyet VM mimarisi ve test süitleri için lütfen **[Backend ve Bulut Altyapısı Master Mimari Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/backend_ve_altyapi_rehberi.md)** dokümanını inceleyiniz.

Bu doküman, FırsatKolik projesinde Geliştirme (DEV) ve Canlı (PROD) ortamlarının mobil, web, cloud functions ve bot katmanlarında nasıl yönetileceğini ve hangi komutlarla operasyon yapılacağını açıklayan operasyonel el kitabıdır.

---

## 📱 1. MOBİL UYGULAMA (Flutter) Yönetimi

Mobil uygulama, kod içerisinde hiçbir el ile müdahale gerektirmeksizin tamamen derleme anındaki flavor parametreleri ile ortamını tayin eder.

### 🔸 DEV (Geliştirme / Test) Modu
*   **Amaç:** Bilgisayarda geliştirme yaparken, emülatörde veya test telefonunda test etmek.
*   **Çalıştırma Komutu:**
    ```bash
    flutter run -d <cihaz_id> --flavor dev --dart-define=FLAVOR=dev
    ```
*   **Özellikleri:**
    - Uygulama adı: **FırsatKolik Dev**
    - Paket adı: `com.sicakfirsatlar.sicak_firsatlar`
    - Firebase Projesi: `sicak-firsatlar-e6eae` (DEV)
    - AdMob: Otomatik **Google Test Reklamları** gösterilir (Hesabınız banlanmaz).
    - App Check: **Debug Provider** (Logcat'ten alınan debug tokenlar) ile çalışır.

### 🔸 PROD (Canlı / Production) Modu
*   **Amaç:** Google Play Store'a yüklenecek paketi üretmek veya gerçek telefonunuzda canlı verileri test etmek.
*   **Google Play Store (AAB) Derleme Komutları:**
    ```bash
    # 1. Shorebird Code-Push Destekli AAB Derleme (Tavsiye Edilen)
    shorebird release android --flavor prod -t lib/main.dart

    # 2. Standart AAB Derleme
    flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
    ```
    *(Detaylı Code-Push kılavuzu için bkz: [Flutter Canlı Kod Güncelleme Rehberi](file:///d:/firsatkolik/documentation/mobil-ve-ui/flutter_live_code_push_and_hot_reload_strategies.md))*
*   **Kendi Cihazınızda Canlı Test Komutu:**
    ```bash
    flutter run -d <cihaz_id> --flavor prod --dart-define=FLAVOR=prod
    ```
*   **Özellikleri:**
    - Uygulama adı: **FırsatKolik**
    - Paket adı: `com.firsatkolik.app`
    - Firebase Projesi: `firsatkolik-prod-e6eae` (PROD)
    - AdMob: Kodda tanımlanmış olan **Gerçek Reklamlar** gösterilir.
    - App Check: **Play Integrity** (Google Play Store güvenliği) ile çalışır.

---

## 🌐 2. WEB ADMİN PANELİ Yönetimi

Web admin paneli, derleme işlemi gerektirmez. Tarayıcının çalıştığı **Web Adresine (Hostname)** bakarak hangi Firebase projesine bağlanacağını otomatik seçer.

*   **DEV (Yerel Test):** Tarayıcıda `localhost` veya `127.0.0.1` adreslerinde çalışırken otomatik olarak **DEV Firebase projesine (`sicak-firsatlar-e6eae`)** bağlanır.
*   **PROD (Canlı Yayın):** Web klasöründeki değişiklikleri canlıya almak için şu komut çalıştırılır:
    ```bash
    firebase deploy --only hosting --project prod
    ```
    Yayınlanan adreste (`https://firsatkolik-prod-e6eae.web.app`) çalışırken otomatik olarak **PROD Firebase projesine (`firsatkolik-prod-e6eae`)** bağlanır.

---

## 🚀 3. Hızlı Operasyon Tablosu (Cheat-Sheet)

| Yapmak İstediğiniz İşlem | DEV Ortamı İçin Komut | PROD Ortamı İçin Komut |
|---|---|---|
| **Mobil Uygulamayı Başlatma** | `flutter run -d <cihaz> --flavor dev --dart-define=FLAVOR=dev` | `flutter run -d <cihaz> --flavor prod --dart-define=FLAVOR=prod` |
| **Play Store İçin Derleme Alma** | — | `flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release` |
| **Bulut Fonksiyonlarını Güncelleme** | `firebase deploy --only functions --project dev` | `firebase deploy --only functions --project prod` |
| **Güvenlik Kuralları / İndeks Güncelleme** | `firebase deploy --only firestore --project dev` | `firebase deploy --only firestore --project prod` |
| **Storage Kurallarını Güncelleme** | `firebase deploy --only storage --project dev` | `firebase deploy --only storage --project prod` |
| **Web Admin Panelini Yayınlama** | `firebase deploy --only hosting --project dev` | `firebase deploy --only hosting --project prod` |
| **Telegram Botunu Güncelleme/Deploy** | `python deploy_agent.py sicak-firsatlar-e6eae` | `python deploy_agent.py firsatkolik-prod-e6eae` |

---

## ⚠️ Kritik Hatırlatmalar

1.  **Release Komutunda Parametre:** Canlı AAB derlemesi alırken `--dart-define=FLAVOR=prod` parametresini yazmayı kesinlikle unutmayın. Bu parametre unutulursa uygulama PROD paket adı altında DEV veritabanına bağlanmaya çalışır ve hata verir.
2.  **App Check Canlı Entegrasyonu:** Canlı (PROD) sürümde cihazlara debug token kaydetmenize gerek yoktur. Sadece **Google Play Console > Setup > App Integrity** sayfasından Firebase PROD projenizi ilişkilendirmeniz yeterlidir.
3.  **Google ile Giriş Canlı Sorunu:** Canlı sürümde Google Giriş'in çalışması için, **Google Play Console > Setup > App Integrity > App Signing** sekmesindeki SHA-1 değerini kopyalayıp Firebase PROD projesindeki Android Uygulama ayarlarına eklemeyi unutmayın.
