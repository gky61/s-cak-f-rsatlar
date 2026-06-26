# Firebase SHA Fingerprint Ekleme Rehberi

## 🔑 Debug Keystore Fingerprint'leri

APK debug keystore ile imzalandığı için aşağıdaki fingerprint'leri Firebase Console'a eklemen gerekiyor:

### SHA-1:
```
FE:C7:87:55:21:E6:07:0B:63:BB:2F:16:27:9E:49:42:8C:AE:A6:54
```

### SHA-256:
```
26:BE:1E:C5:C1:44:84:98:09:F9:A9:A0:17:AE:1D:4D:7A:E1:6C:C3:C7:69:61:03:1F:3B:9C:1B:CD:BF:C2:82
```

## 📱 Firebase Console'da Ekleme Adımları

### Yöntem 1: Firebase Console (Önerilen)

1. **Firebase Console'a Git:**
   - https://console.firebase.google.com/
   - Projeni seç: `sicak-firsatlar-e6eae`

2. **Project Settings'e Git:**
   - Sol menüden ⚙️ (Settings) → **Project settings**

3. **Android App'i Bul:**
   - "Your apps" bölümünde Android uygulamanı bul
   - Package name: `com.sicakfirsatlar.sicak_firsatlar`

4. **SHA Fingerprint'leri Ekle:**
   - "SHA certificate fingerprints" bölümünü bul
   - **"Add fingerprint"** butonuna tıkla
   - SHA-1 değerini ekle: `FE:C7:87:55:21:E6:07:0B:63:BB:2F:16:27:9E:49:42:8C:AE:A6:54`
   - Tekrar **"Add fingerprint"** butonuna tıkla
   - SHA-256 değerini ekle: `26:BE:1E:C5:C1:44:84:98:09:F9:A9:A0:17:AE:1D:4D:7A:E1:6C:C3:C7:69:61:03:1F:3B:9C:1B:CD:BF:C2:82`

5. **Kaydet:**
   - Değişiklikler otomatik kaydedilir
   - **5-10 dakika bekle** (Google'ın sunucularında yayınlanması için)

### Yöntem 2: Google Cloud Console

1. **Google Cloud Console'a Git:**
   - https://console.cloud.google.com/
   - Projeni seç: `sicak-firsatlar-e6eae`

2. **APIs & Services → Credentials:**
   - Sol menüden **APIs & Services** → **Credentials**

3. **OAuth 2.0 Client ID'yi Bul:**
   - "OAuth 2.0 Client IDs" bölümünde Android client'ı bul
   - Veya yeni bir Android client oluştur

4. **SHA Fingerprint'leri Ekle:**
   - Android client'ı düzenle
   - "SHA-1 certificate fingerprint" alanına SHA-1 ekle
   - "SHA-256 certificate fingerprint" alanına SHA-256 ekle
   - Package name: `com.sicakfirsatlar.sicak_firsatlar`

5. **Kaydet ve Bekle:**
   - Değişiklikleri kaydet
   - **5-10 dakika bekle**

## ✅ Kontrol Etme

Fingerprint'leri ekledikten sonra:

1. **5-10 dakika bekle** (Google'ın sunucularında yayınlanması için)
2. **Uygulamayı kapat ve yeniden aç**
3. **Google ile giriş yapmayı dene**

## 🔄 Hala Çalışmıyorsa

1. **google-services.json dosyasını kontrol et:**
   - `android/app/google-services.json` dosyasının güncel olduğundan emin ol
   - Firebase Console'dan yeniden indirip değiştir

2. **OAuth Consent Screen'i kontrol et:**
   - Google Cloud Console → APIs & Services → OAuth consent screen
   - Test kullanıcıları eklenmiş mi kontrol et

3. **Logcat'te hata mesajlarını kontrol et:**
   ```bash
   flutter run
   # Veya Android Studio'da Logcat sekmesini aç
   ```

## 📝 Notlar

- **Debug keystore** ile imzalanmış APK'lar için bu fingerprint'ler yeterli
- **Release APK** için release keystore'un fingerprint'lerini de eklemen gerekir
- Her yeni cihaz/keystore için fingerprint eklemen gerekebilir
- Fingerprint'ler eklendikten sonra 5-10 dakika içinde aktif olur

