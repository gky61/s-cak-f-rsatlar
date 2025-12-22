# Google Play Store Yayınlama Checklist

## ✅ Tamamlanması Gerekenler

### 1. **Release Signing Key Oluşturma** (KRİTİK)
Şu anda debug key kullanılıyor. Production için release key oluşturulmalı:

```bash
# Release key oluştur
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# key.properties dosyası oluştur (android/ klasöründe)
storePassword=<şifre>
keyPassword=<şifre>
keyAlias=upload
storeFile=<keystore dosya yolu>
```

**build.gradle** dosyasında signing config güncellenmeli.

### 2. **Version Code ve Version Name**
- `pubspec.yaml`: `version: 1.0.0+1` ✅
- Her yayında version code artırılmalı (1, 2, 3...)
- Version name kullanıcıya görünen versiyon (1.0.0, 1.0.1...)

### 3. **App Icon ve Splash Screen**
- ✅ App icon mevcut
- Splash screen kontrol edilmeli

### 4. **Privacy Policy** (ZORUNLU)
- Privacy policy sayfası oluşturulmalı
- Firebase kullanıldığı için veri toplama açıklaması gerekli
- Google Sign-In kullanıldığı için OAuth açıklaması gerekli
- URL: `https://yourdomain.com/privacy-policy`

### 5. **Content Rating**
- Google Play Console'da içerik derecelendirmesi yapılmalı
- Yaş sınırı belirlenmeli

### 6. **App Store Listing**
- Uygulama adı: "FIRSATKOLİK" ✅
- Kısa açıklama (80 karakter)
- Uzun açıklama (4000 karakter)
- Ekran görüntüleri (en az 2, farklı cihaz boyutları)
- Feature graphic (1024x500)
- Kategori seçimi

### 7. **Permissions Açıklamaları**
AndroidManifest.xml'de kullanılan izinler:
- INTERNET ✅
- POST_NOTIFICATIONS ✅
- VIBRATE ✅
- CAMERA (opsiyonel, image picker için)

Her izin için Google Play Console'da açıklama yapılmalı.

### 8. **ProGuard/R8 Kuralları**
- ✅ `proguard-rules.pro` oluşturuldu
- Release build'de test edilmeli

### 9. **Firebase Yapılandırması**
- ✅ `google-services.json` mevcut olmalı
- Release SHA-1 fingerprint Firebase Console'a eklenmeli:
  ```bash
  keytool -list -v -keystore ~/upload-keystore.jks -alias upload
  ```

### 10. **Test**
- [ ] Release APK test edilmeli
- [ ] Google Sign-In release build'de çalışmalı
- [ ] Firebase bağlantıları çalışmalı
- [ ] Bildirimler çalışmalı
- [ ] Tüm özellikler test edilmeli

### 11. **Target SDK**
- ✅ `targetSdkVersion 35` (güncel)

### 12. **Min SDK**
- ✅ `minSdkVersion 21` (Android 5.0+)

### 13. **Data Safety Form** (Google Play Console)
- Veri toplama açıklamaları
- Veri paylaşımı açıklamaları
- Güvenlik uygulamaları

### 14. **Release Notes**
- Her güncelleme için release notes yazılmalı

## 🚨 Önemli Notlar

1. **Release Key Güvenliği**: Release key'i kaybetmeyin! Yedekleyin ve güvenli bir yerde saklayın.
2. **Version Code**: Her yayında mutlaka artırın, geri alamazsınız.
3. **Privacy Policy**: Zorunlu, yoksa uygulama reddedilir.
4. **Test**: Internal testing → Closed testing → Open testing → Production sırasıyla test edin.

## 📝 Yayınlama Adımları

1. Release key oluştur ve yapılandır
2. Release APK/AAB oluştur:
   ```bash
   flutter build appbundle --release
   ```
3. Google Play Console'da uygulama oluştur
4. Store listing bilgilerini doldur
5. Privacy policy linkini ekle
6. Content rating yap
7. Data safety formu doldur
8. Internal testing'e yükle
9. Test et
10. Production'a yayınla

## 🔧 Hızlı Düzeltmeler Yapıldı

- ✅ ProGuard kuralları eklendi
- ✅ Release build optimizasyonları açıldı (minify, shrink)
- ✅ Permissions eklendi (POST_NOTIFICATIONS, VIBRATE)
- ✅ Version kontrolü yapıldı

## ⚠️ Yapılması Gerekenler

- [ ] Release signing key oluştur ve yapılandır
- [ ] Privacy policy sayfası oluştur
- [ ] Firebase Console'a release SHA-1 ekle
- [ ] Release build test et
- [ ] Google Play Console'da store listing doldur

