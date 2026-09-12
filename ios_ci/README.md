# 🍎 FırsatKolik — İzole iOS CI/CD ve TestFlight Altyapısı (`ios_ci/`)

Bu dizin, **Windows veya Linux geliştirme ortamında Mac bilgisayara ihtiyaç duymadan**, bulut tabanlı **GitHub Actions (macOS-14 Apple Silicon M2 runner)** ve sektör standardı **Fastlane (App Store Connect API v1)** kullanarak FırsatKolik uygulamasının iOS IPA paketini derleyen ve otomatik olarak **Apple TestFlight**'a yükleyen bağımsız/izole CI/CD altyapısını barındırır.

Mevcut Flutter uygulama kodları, Android yapılandırmaları ve backend servisleriyle çakışmaması ve projeyi kirletmemesi için tüm iOS dağıtım betikleri, Fastlane dosyaları ve plist profilleri bu izole klasörde toplanmıştır.

---

## 📂 Dizin Yapısı

```
ios_ci/
├── 📄 README.md                     # Bu özet bilgilendirme ve operasyon el kitabı
├── 📄 Fastfile                      # [YENİ] Fastlane App Store Connect API v1 TestFlight yükleme hattı
├── 📄 ExportOptions_prod.plist      # Production (com.firsatkolik.app) App Store / TestFlight imzalama profili
├── 📄 ExportOptions_dev.plist       # Development (com.sicakfirsatlar.sicakFirsatlar) imzalama profili
└── 📁 scripts/                      # Headless macOS runner üzerinde koşan otomasyon betikleri
    ├── 📄 setup_keychain.sh         # Base64 sertifikasını (.p12) geçici macOS Keychain'ine kuran betik
    └── 📄 upload_testflight.sh      # Fastlane pilot (ve yedek xcrun altool) ile TestFlight yükleme betiği
```

Ayrıca bu altyapıyı tetikleyen GitHub Actions iş akışı:
* [`.github/workflows/ios_testflight_deploy.yml`](file:///d:/firsatkolik/.github/workflows/ios_testflight_deploy.yml)

---

## 🔍 Teknik Araştırma ve Mimari Doğrulamalar

Süreç kurulurken yapılan derin teknik analiz ve doğrulama sonuçları:

1. **`xcrun altool` Deprecation Durumu ve Fastlane:**
   * Apple, `xcrun altool` aracını macOS Notarization için Kasım 2023 itibarıyla kaldırmıştır (TN3147). App Store ve TestFlight yüklemeleri için de `altool` komut satırı aracını aşamalı olarak App Store Connect REST API standardına yönlendirmektedir.
   * *Not:* Bazı kaynaklarda geçen `xcrun ditto` (yalnızca yerel dosya sıkıştırma/kopyalama aracıdır) veya `xcrun simctl` (yalnızca yerel iOS Simulator kontrol aracıdır) TestFlight'a yükleme yapamaz.
   * **Seçilen Çözüm:** Sektör standardı olan **Fastlane (`Fastfile` & `upload_to_testflight`)** doğrudan Apple'ın resmi App Store Connect API v1 REST uç noktalarını kullanır. `upload_testflight.sh` dosyamız öncelikli olarak Fastlane'i çalıştırır; beklenmedik bir durumda ise `xcrun altool`'u yedek (fallback) olarak devreye sokar.

2. **"Yumurta mı Tavuk mu" Sertifika Paradoksu:**
   * Apple'ın resmi dokümanları bir Mac bilgisayarınızın olduğunu ve "Keychain Access" programını açarak CSR (Sertifika İmzalama Talebi) oluşturacağınızı varsayar. Mac'i olmayan bir geliştirici sertifika üretemez döngüsüne girer.
   * **Seçilen Çözüm:** Windows 11 üzerinde `openssl` komut satırı ile 2048-bit RSA anahtarı ve CSR üretilerek Apple Developer portalına sunulur; ardından üretilen `.cer` dosyası yine Windows'ta şifreli `.p12` formatına dönüştürülür. Sıfır Mac ile %100 yasal ve geçerli imzalama sağlanır.

3. **GitHub Actions 10x macOS Dakika Çarpanı ve Maliyet Tasarrufu:**
   * GitHub Free hesapları gizli (private) repolara aylık **2.000 dakika** ücretsiz kullanım verir.
   * Ancak macOS sanal makineleri (M2 dahil) için **10 katı çarpan (10x multiplier)** uygulanır. Yani ayda net **200 macOS dakikanız** vardır.
   * Standart bir derleme 15 dakika sürerse ayda yalnızca ~13-15 derleme hakkınız kalır.
   * **Geliştirilen Savunma Mekanizmaları:**
     1. **Yalnızca Manuel Tetikleme (`workflow_dispatch`):** Her `git push`'ta build alınmaz; yalnızca siz butona bastığınızda çalışır.
     2. **CocoaPods Önbelleği (`actions/cache@v4`):** Pod indirmeleri önbelleğe alınarak build süresi 15 dakikadan **~7-8 dakikaya** düşürülür (Build hakkı ayda 25+ adede çıkar).
     3. **`skip_waiting_for_build_processing: true`:** Fastlane, paket Apple sunucusuna ulaştığı an derlemeyi tamamlar; Apple'ın 10-15 dakikalık işleme kuyruğunu beklemez. Böylece tek çalıştırmada fazladan 100-150 dakika harcanması önlenir.

---

## 🔐 Zorunlu GitHub Repository Secrets

GitHub deponuzun **Settings > Secrets and variables > Actions** menüsüne eklenmesi gereken 6 gizli anahtar:

| Gizli Anahtar Adı | Format | Açıklama |
| :--- | :--- | :--- |
| `BUILD_CERTIFICATE_BASE64` | Base64 | Apple Dağıtım Sertifikası (`.p12`) Base64 çıktısı. |
| `P12_PASSWORD` | String | `.p12` dosyasını oluştururken belirlediğiniz şifre. |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64 | `AppStore.mobileprovision` dosyasının Base64 çıktısı. |
| `APP_STORE_CONNECT_KEY_ID` | 10 Haneli Kod | App Store Connect API Key ID (Örn: `2X9R4ABCD2`). |
| `APP_STORE_CONNECT_ISSUER_ID` | UUID | App Store Connect Issuer ID (Örn: `69a6de70-...`). |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Metin (.p8) | İndirilen `AuthKey_XXXXXXXXXX.p8` dosyasının tam içeriği. |

---

## 🚀 Pipeline'ı Çalıştırma

1. GitHub deponuzda **Actions** sekmesine gidin.
2. Sol menüden **iOS TestFlight Deployment** iş akışını seçin.
3. Sağ üstteki **"Run workflow"** butonuna tıklayın:
   * **Flavor:** `prod` (önerilen)
   * **Upload to TestFlight:** `true`
4. Yaklaşık 8-12 dakika sonra derleme tamamlanır ve TestFlight konsolunuzda yeni build listelenir!

---

## 📖 Kapsamlı Kurulum El Kitabı

Tüm detaylı kurulum adımları, Windows komutları ve ödünç iPhone'da canlı test protokolü için:
👉 **[`documentation/yayin-ve-surec/ios_testflight_ve_ci_cd_kurulum_rehberi.md`](file:///d:/firsatkolik/documentation/yayin-ve-surec/ios_testflight_ve_ci_cd_kurulum_rehberi.md)**
