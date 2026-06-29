# 🏪 Store Yayını İçin Eksikler ve Yapılması Gerekenler

## 📱 Google Play Store (Android)

### ✅ Tamamlananlar
- ✅ Release signing key oluşturuldu (`upload-keystore.jks`)
- ✅ `key.properties` yapılandırıldı
- ✅ `build.gradle` release signing config hazır
- ✅ App icon mevcut
- ✅ Version kontrolü (`1.1.0+2`)
- ✅ Target SDK 35 (güncel)
- ✅ Min SDK 21 (Android 5.0+)
- ✅ Permissions tanımlı (INTERNET, POST_NOTIFICATIONS, VIBRATE)

### ❌ Eksikler ve Yapılması Gerekenler

#### 1. **Privacy Policy (ZORUNLU)** 🔴
**Durum:** Yok  
**Öncelik:** YÜKSEK

Google Play Store, privacy policy olmadan uygulama yayınlamaz. Firebase, Google Sign-In ve Apple Sign-In kullandığınız için mutlaka gerekli.

**Yapılacaklar:**
- Privacy policy sayfası oluştur (web sitesi veya GitHub Pages)
- URL: `https://yourdomain.com/privacy-policy` veya `https://github.com/username/repo/blob/main/PRIVACY_POLICY.md`
- İçerik:
  - Toplanan veriler (email, profil fotoğrafı, kullanıcı adı)
  - Veri kullanım amacı
  - Firebase kullanımı
  - Google Sign-In ve Apple Sign-In açıklaması
  - Veri güvenliği
  - Kullanıcı hakları

**Örnek Privacy Policy şablonu:** `PRIVACY_POLICY_TEMPLATE.md` dosyası oluşturulacak.

---

#### 2. **App Bundle (AAB) Oluşturma** 🔴
**Durum:** Sadece APK var, AAB yok  
**Öncelik:** YÜKSEK

Google Play Store artık APK yerine AAB (Android App Bundle) formatını tercih ediyor ve zorunlu kılıyor.

**Yapılacaklar:**
```bash
flutter build appbundle --release
```
Çıktı: `build/app/outputs/bundle/release/app-release.aab`

---

#### 3. **Firebase Release SHA-1 Fingerprint** 🟡
**Durum:** Kontrol edilmeli  
**Öncelik:** ORTA

Google Sign-In'in release build'de çalışması için Firebase Console'a release SHA-1 eklenmeli.

**Yapılacaklar:**
```bash
keytool -list -v -keystore android/upload-keystore.jks -alias upload -storepass sicakfirsatlar2024
```
SHA-1 değerini alıp Firebase Console > Project Settings > Your apps > Android app > SHA certificate fingerprints bölümüne ekle.

---

#### 4. **Google Play Console Store Listing** 🟡
**Durum:** Hazırlanmalı  
**Öncelik:** ORTA

**Gerekli Bilgiler:**
- **Uygulama Adı:** FIRSATKOLİK ✅
- **Kısa Açıklama (80 karakter):** 
  - Örnek: "Topluluk temelli indirim ve kampanya paylaşım uygulaması. En sıcak fırsatları keşfedin!"
- **Uzun Açıklama (4000 karakter):**
  - Uygulamanın özelliklerini detaylı anlat
  - Kategoriler, arama, takip, bildirimler vb.
- **Ekran Görüntüleri:**
  - En az 2 adet (farklı cihaz boyutları)
  - Telefon: 1080x1920 veya 1440x2560
  - Tablet: 1200x1920
  - Format: PNG veya JPEG
- **Feature Graphic (1024x500):**
  - Uygulamanın tanıtım görseli
- **Kategori:** Shopping / Social
- **İletişim Bilgileri:**
  - Email, telefon, web sitesi

---

#### 5. **Content Rating** 🟡
**Durum:** Yapılmamış  
**Öncelik:** ORTA

Google Play Console'da içerik derecelendirmesi yapılmalı.

**Yapılacaklar:**
- Google Play Console > Content Rating
- Anket doldur (sosyal özellikler, kullanıcı içeriği vb.)
- Genellikle "Everyone" veya "Teen" olur

---

#### 6. **Data Safety Form** 🟡
**Durum:** Doldurulmalı  
**Öncelik:** ORTA

Google Play Console'da Data Safety formu doldurulmalı.

**Sorular:**
- Toplanan veriler (email, kullanıcı adı, profil fotoğrafı)
- Veri kullanım amacı
- Veri paylaşımı (Firebase, Google)
- Güvenlik uygulamaları

---

#### 7. **Release Notes** 🟢
**Durum:** Her güncellemede yazılmalı  
**Öncelik:** DÜŞÜK

Her yeni versiyon için release notes yazılmalı.

**Örnek:**
```
v1.1.0
- Yeni arama özelliği eklendi
- Profil fotoğrafı değiştirme özelliği
- Bildirim sistemi iyileştirildi
- Hata düzeltmeleri
```

---

#### 8. **Test Süreci** 🟡
**Durum:** Yapılmalı  
**Öncelik:** YÜKSEK

**Test Aşamaları:**
1. **Internal Testing:** Geliştirici ekibi test eder
2. **Closed Testing:** Beta test kullanıcıları test eder
3. **Open Testing:** Genel beta test
4. **Production:** Canlı yayın

**Test Edilmesi Gerekenler:**
- ✅ Google Sign-In (release build'de)
- ✅ Apple Sign-In (iOS için)
- ✅ Firebase bağlantıları
- ✅ Bildirimler
- ✅ Tüm özellikler (paylaşım, takip, mesajlaşma)
- ✅ Offline durum
- ✅ Farklı cihazlarda test

---

## 🍎 App Store (iOS) - Opsiyonel

### ✅ Tamamlananlar
- ✅ iOS klasörü mevcut
- ✅ App icon yapılandırması
- ✅ Bundle ID: `com.sicakfirsatlar.sicakFirsatlar`

### ❌ Eksikler

#### 1. **Apple Developer Account** 🔴
- Yıllık $99 ücretli
- App Store Connect erişimi

#### 2. **Privacy Policy** 🔴
- Android ile aynı (tek bir sayfa yeterli)

#### 3. **App Store Connect Yapılandırması** 🟡
- App Store listing
- Screenshots (iPhone ve iPad için)
- App description
- Keywords
- Category

#### 4. **Provisioning Profiles** 🟡
- Xcode'da otomatik oluşturulur
- App Store Connect'te yapılandırılır

---

## 📋 Hızlı Başlangıç Checklist

### Google Play Store İçin:
- [ ] Privacy Policy oluştur ve yayınla
- [ ] App Bundle (AAB) oluştur: `flutter build appbundle --release`
- [ ] Firebase Console'a release SHA-1 ekle
- [ ] Google Play Console'da uygulama oluştur
- [ ] Store listing bilgilerini doldur
- [ ] Ekran görüntüleri hazırla ve yükle
- [ ] Feature graphic hazırla
- [ ] Content rating yap
- [ ] Data Safety formu doldur
- [ ] Internal testing'e AAB yükle
- [ ] Test et
- [ ] Production'a yayınla

### App Store İçin (Opsiyonel):
- [ ] Apple Developer Account al
- [ ] App Store Connect'te uygulama oluştur
- [ ] Privacy Policy linkini ekle
- [ ] iOS screenshots hazırla
- [ ] App Store listing doldur
- [ ] TestFlight'a yükle
- [ ] Test et
- [ ] App Store'a gönder

---

## 🚨 Önemli Notlar

1. **Release Key Güvenliği:**
   - `upload-keystore.jks` dosyasını YEDEKLEYİN!
   - Bu key'i kaybederseniz uygulamayı güncelleyemezsiniz
   - Güvenli bir yerde saklayın (şifreli cloud storage)

2. **Version Code:**
   - Her yayında mutlaka artırın (`1.1.0+2` → `1.1.0+3`)
   - Geri alamazsınız, sadece yeni versiyon yükleyebilirsiniz

3. **Privacy Policy:**
   - Zorunlu, yoksa uygulama reddedilir
   - URL çalışır durumda olmalı

4. **Test Süreci:**
   - Internal → Closed → Open → Production
   - Her aşamada test edin

5. **Firebase Yapılandırması:**
   - Release SHA-1 mutlaka eklenmeli
   - Aksi halde Google Sign-In çalışmaz

---

## 📞 Destek

Sorularınız için:
- Google Play Console: https://play.google.com/console
- Firebase Console: https://console.firebase.google.com
- Flutter Dokümantasyon: https://flutter.dev/docs/deployment/android






