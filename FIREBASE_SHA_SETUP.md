# Firebase SHA-1/SHA-256 Sertifika Parmak İzi Ekleme Rehberi

## 🔑 Sertifika Parmak İzleri

### Release Keystore (APK için)
- **SHA-1**: `E9:6A:4A:47:60:8B:15:74:C4:04:1E:5D:FB:52:DC:0C:46:B3:2D:74`
- **SHA-256**: `E0:22:25:2A:81:C9:52:AF:29:2C:AF:D5:9A:C0:4A:01:9B:4A:89:1C:20:F5:D0:3E:05:C7:0D:56:5C:26:02:09`

### Debug Keystore (Geliştirme için - zaten ekli olabilir)
- **SHA-1**: `FE:C7:87:55:21:E6:07:0B:63:BB:2F:16:27:9E:49:42:8C:AE:A6:54`
- **SHA-256**: `26:BE:1E:C5:C1:44:84:98:09:F9:A9:A0:17:AE:1D:4D:7A:E1:6C:C3:C7:69:61:03:1F:3B:9C:1B:CD:BF:C2:82`

## 📝 Firebase Console'da Ekleme Adımları

1. **Firebase Console'a gidin**: https://console.firebase.google.com/
2. **Projenizi seçin**: "SICAK FIRSATLAR" veya ilgili proje
3. **Project Settings'e gidin**: 
   - Sol menüden ⚙️ (Settings) ikonuna tıklayın
   - "Project settings" seçeneğine tıklayın
4. **Android uygulamanızı bulun**: "Your apps" bölümünde Android uygulamanızı seçin
5. **SHA certificate fingerprints bölümüne gidin**: 
   - "SHA certificate fingerprints" bölümünü bulun
   - "Add fingerprint" butonuna tıklayın
6. **Release SHA-1'i ekleyin**:
   - `E9:6A:4A:47:60:8B:15:74:C4:04:1E:5D:FB:52:DC:0C:46:B3:2D:74`
   - "Save" butonuna tıklayın
7. **Release SHA-256'i ekleyin**:
   - "Add fingerprint" butonuna tekrar tıklayın
   - `E0:22:25:2A:81:C9:52:AF:29:2C:AF:D5:9A:C0:4A:01:9B:4A:89:1C:20:F5:D0:3E:05:C7:0D:56:5C:26:02:09`
   - "Save" butonuna tıklayın
8. **google-services.json dosyasını yeniden indirin**:
   - "Download google-services.json" butonuna tıklayın
   - İndirilen dosyayı `android/app/google-services.json` konumuna kopyalayın (mevcut dosyanın üzerine yazın)

## ⚠️ Önemli Notlar

- Release SHA-1 ve SHA-256 değerlerini **mutlaka** eklemeniz gerekiyor, aksi halde APK'da Google Sign-In çalışmaz
- Debug SHA değerleri zaten ekli olabilir, ama yoksa onları da ekleyin
- `google-services.json` dosyasını güncelledikten sonra uygulamayı yeniden build etmeniz gerekebilir
- Firebase Console'da değişikliklerin yayılması birkaç dakika sürebilir

## 🔄 Değişikliklerden Sonra

1. `google-services.json` dosyasını güncelleyin
2. Uygulamayı temizleyin: `flutter clean`
3. APK'yı yeniden oluşturun: `flutter build apk --release`
4. Yeni APK'yı test edin

## 🐛 Sorun Giderme

Eğer hala Google Sign-In çalışmıyorsa:
- Firebase Console'da SHA değerlerinin doğru eklendiğini kontrol edin
- `google-services.json` dosyasının güncel olduğundan emin olun
- Uygulamayı tamamen kaldırıp yeniden yükleyin
- Firebase Console'da birkaç dakika bekleyin (değişikliklerin yayılması için)







