# AdMob Test Cihazı Ekleme Kılavuzu

## Telefonun Advertising ID'sini Bulma

### Yöntem 1: Uygulama İçinden (Otomatik)
Uygulama çalışırken log'larda Advertising ID otomatik olarak gösterilecek (gelecekte eklenecek).

### Yöntem 2: ADB Komutu (USB Bağlantısı İle)
Telefonu USB ile bilgisayara bağlayın ve şu komutu çalıştırın:

```bash
adb shell "settings get secure android_id"
```

**VEYA** Advertising ID için:

```bash
adb shell "settings get secure advertising_id"
```

### Yöntem 3: Telefon Ayarlarından
1. **Ayarlar** > **Google** > **Reklamlar**
2. **Reklam kimliği** veya **Reklam ID'sini sıfırla** seçeneğine dokunun
3. Reklam kimliğini kopyalayın

**VEYA**

1. **Ayarlar** > **Google** > **Hesabım**
2. **Gizlilik ve özelleştirme** > **Reklamlar**
3. Reklam kimliğini görüntüleyin

## AdMob Konsolunda Test Cihazı Ekleme

1. [AdMob Konsolu](https://admob.google.com) açın
2. Sol menüden **Ayarlar** > **Test cihazı ekleme** seçin
3. Formu doldurun:
   - **Cihaz adı**: Telefonunuzun adı (örn: "Test Telefonu")
   - **Platform**: Android
   - **Reklam kimliği**: Telefondan kopyaladığınız Advertising ID'yi yapıştırın
4. **Kaydet** butonuna tıklayın

## Kodda Test Cihazı ID'sini Kullanma

`lib/main.dart` dosyasında `RequestConfiguration` bölümünü bulun ve test cihaz ID'nizi ekleyin:

```dart
final configuration = RequestConfiguration(
  testDeviceIds: const <String>[
    'TELEFONUN-ADVERTISING-ID-SI-BURAYA', // AdMob'a eklediğiniz ID
  ],
);
```

## Önemli Notlar

- ✅ Test cihazı ekledikten sonra reklamların görünmesi birkaç dakika sürebilir
- ✅ Test reklamlarında "Test Ad" rozeti görünmelidir
- ✅ Gerçek reklamlar yerine test reklamları gösterilir
- ✅ Test cihazında tıklama yapmak gelir getirmez
- ⚠️ Şu anda Google'ın test ad unit ID'sini kullanıyoruz (`ca-app-pub-3940256099942544/2247696110`), bu yüzden test cihazı eklemeye gerek yok
- ⚠️ Gerçek ad unit ID'ye geçtiğinizde test cihazı eklemek zorunlu olacak

## Test Reklamlarını Kontrol Etme

Test reklamlarının gösterildiğini doğrulamak için:
1. Reklamın üzerinde "Test Ad" veya "Test Reklam" rozeti olmalı
2. Log'larda `✅ Banner reklam başarıyla yüklendi!` mesajını görmelisiniz
3. Reklamları tıklamadan önce test rozetini kontrol edin




