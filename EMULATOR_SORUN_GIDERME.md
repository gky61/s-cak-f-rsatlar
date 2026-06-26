# Android Emülatör Hata Çözümleri

## 1. INSTALL_FAILED_INSUFFICIENT_STORAGE (Yetersiz depolama)

**Belirti:** Kurulum sırasında `Failure [INSTALL_FAILED_INSUFFICIENT_STORAGE]` hatası.

**Çözümler:**

### A) Emülatör verisini sil (Wipe Data)
1. Android Studio → **Device Manager** (Tools → Device Manager)
2. Emülatörün yanındaki **▼** → **Wipe Data**
3. Emülatörü yeniden başlat, tekrar `flutter run -d emulator-5554` çalıştır

### B) Emülatörde yer aç
- Emülatör açıkken: **Settings → Storage** → gereksiz verileri sil
- Veya yeni bir AVD oluştururken **Internal Storage** değerini en az **4096 MB** yap

### C) Eski uygulamayı kaldır
- Emülatörde: Uygulama simgesine uzun bas → Kaldır (Uninstall)
- Sonra tekrar `flutter run -d emulator-5554` ile yükle

---

## 2. DEVELOPER_ERROR / Google Play Services

**Belirti:** Uygulama açılıyor ama hemen kapanıyor veya `GoogleApiManager: SecurityException / DEVELOPER_ERROR` logları.

**Çözümler:**

### A) Doğru emülatör imajı
- **Google Play** etiketli sistem imajı kullanın (örn. "Pixel 7 API 35" + **Google Play**)
- Sadece "Google APIs" (Play Store’suz) imajda GMS tam çalışmayabilir

### B) Firebase’e debug SHA-1 ekleyin
1. Proje klasöründe:  
   `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
2. Çıktıdaki **SHA-1** değerini kopyalayın
3. [Firebase Console](https://console.firebase.google.com) → Proje → Project settings → Your apps → Android uygulaması → **Add fingerprint** → SHA-1’i ekleyin
4. `google-services.json` dosyasını tekrar indirip projeye koyun (isteğe bağlı, bazen gerekir)

### C) Emülatörde Google hesabı
- Emülatörde **Settings → Accounts** üzerinden bir Google hesabı ekleyin (giriş yapın)

---

## Hızlı komutlar

```bash
# Cihaz listesi
flutter devices

# Uygulamayı emülatörde çalıştır (cihaz ID’yi flutter devices ile görün)
flutter run -d emulator-5554
```

Emülatör kapalıysa önce Android Studio’dan veya komut satırından emülatörü başlatın, sonra `flutter run` yapın.
