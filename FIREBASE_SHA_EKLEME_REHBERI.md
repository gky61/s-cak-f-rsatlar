# Firebase'e SHA-1 ve SHA-256 Ekleme Rehberi

Bildirimlerin (FCM) ve Google ile girişin çalışması için Android uygulamanızın parmak izlerini Firebase Console'a eklemeniz gerekir.

---

## 1. Firebase Console'a Girin

1. [Firebase Console](https://console.firebase.google.com) açın.
2. Projenizi seçin (**Sıcak Fırsatlar** / ilgili proje).
3. Sol menüden **⚙️ Proje ayarları** (Project settings) tıklayın.
4. Aşağı kaydırıp **"Uygulamalarınız" (Your apps)** bölümüne gidin.
5. Android uygulamanızı (paket adı: `com.sicakfirsatlar.sicak_firsatlar`) bulun.

---

## 2. Parmak İzlerini (SHA) Ekleme

Android uygulama kartında **"Parmak izi (SHA)"** alanı vardır.

### Debug (emülatör / geliştirme) için

Emülatörde veya `flutter run` ile çalıştırdığınızda bu imza kullanılır. Aşağıdakileri ekleyin:

| Tür   | Değer |
|-------|--------|
| **SHA-1**  | `FE:C7:87:55:21:E6:07:0B:63:BB:2F:16:27:9E:49:42:8C:AE:A6:54` |
| **SHA-256**| `26:BE:1E:C5:C1:44:84:98:09:F9:A9:A0:17:AE:1D:4D:7A:E1:6C:C3:C7:69:61:03:1F:3B:9C:1B:CD:BF:C2:82` |

**Nasıl eklenir:**
- **"Parmak izi ekle"** veya **"Add fingerprint"** tıklayın.
- Önce SHA-1 değerini yapıştırın → Kaydedin.
- Tekrar **"Parmak izi ekle"** deyip SHA-256 değerini yapıştırın → Kaydedin.

### Release (Play Store / APK) için

Yayınladığınız APK’yı kendi keystore ile imzalıyorsanız, o keystore’un SHA’larını da eklemelisiniz.

**Release SHA’ları almak için** (bilgisayarınızda):

```bash
keytool -list -v -keystore /path/to/your/upload-keystore.jks -alias upload
```

(`key.properties` içindeki `storeFile` yolunu ve `keyAlias` değerini kullanın. Şifre sorulacak, `storePassword` değerinizi girin.)

Çıktıdaki **SHA1:** ve **SHA256:** satırlarındaki değerleri kopyalayıp Firebase’e aynı şekilde **"Parmak izi ekle"** ile ekleyin.

---

## 3. google-services.json’ı Güncelleme (isteğe bağlı)

SHA ekledikten sonra Firebase bazen yeni bir `google-services.json` üretir:

1. Proje ayarları → Genel → **Android uygulamanız** → **google-services.json indir**.
2. İndirdiğiniz dosyayı projede `android/app/google-services.json` konumuna kopyalayıp eskisinin üzerine yazın.
3. Projeyi yeniden derleyin: `flutter clean && flutter pub get && flutter run` veya release APK için `flutter build apk --release`.

---

## 4. Kontrol

- Emülatörde veya debug kurulumda: Debug SHA’ları eklediyseniz **DEVELOPER_ERROR** kaybolmalı ve bildirimler çalışmalı.
- Release APK’da: Sadece release keystore SHA’larını eklediyseniz, o APK’yı kuran cihazlarda FCM ve Google girişi doğru çalışır.

---

## Özet

| Kullanım        | Hangi SHA’lar eklenmeli |
|-----------------|--------------------------|
| Emülatör / `flutter run` | Yukarıdaki **Debug** SHA-1 ve SHA-256 |
| Yayınlanan APK (Play Store) | **Release** keystore’dan alınan SHA-1 ve SHA-256 |

Her iki imza türünü de (debug + release) Firebase’e ekleyebilirsiniz; böylece hem geliştirme hem production aynı projede çalışır.
