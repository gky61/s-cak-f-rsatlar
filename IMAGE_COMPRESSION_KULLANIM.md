# 📸 Görsel Sıkıştırma Servisi Kullanım Kılavuzu

## 🎯 Amaç

Firebase Storage maliyetini azaltmak ve görsel yükleme hızını artırmak için görsel sıkıştırma servisi eklendi.

## 📦 Kurulum

Paket zaten `pubspec.yaml`'a eklendi:
```yaml
flutter_image_compress: ^2.3.0
```

Paketi yüklemek için:
```bash
flutter pub get
```

## 🔧 Özellikler

- ✅ Otomatik görsel sıkıştırma
- ✅ Maksimum boyut kontrolü (1920x1920 piksel)
- ✅ Maksimum dosya boyutu kontrolü (500 KB)
- ✅ Kalite ayarı (85% varsayılan)
- ✅ Otomatik kalite düşürme (gerekirse)
- ✅ Web desteği (sıkıştırma olmadan)

## 📝 Kullanım Örnekleri

### 1. Galeriden Görsel Seç ve Sıkıştır

```dart
import 'package:your_app/services/image_compression_service.dart';

final compressionService = ImageCompressionService();

// Varsayılan ayarlarla
final compressedImage = await compressionService.pickAndCompressImage();

// Özel ayarlarla
final compressedImage = await compressionService.pickAndCompressImage(
  maxWidth: 1280,
  maxHeight: 1280,
  quality: 80,
  maxFileSizeKB: 300,
);
```

### 2. Kameradan Görsel Çek ve Sıkıştır

```dart
final compressedImage = await compressionService.takeAndCompressImage(
  maxWidth: 1920,
  maxHeight: 1920,
  quality: 85,
  maxFileSizeKB: 500,
);
```

### 3. Mevcut Görseli Sıkıştır

```dart
import 'package:image_picker/image_picker.dart';

final XFile originalImage = ...; // Mevcut görsel

final compressedImage = await compressionService.compressImage(
  originalImage,
  maxWidth: 1920,
  maxHeight: 1920,
  quality: 85,
  maxFileSizeKB: 500,
);
```

### 4. Görsel Boyutunu Kontrol Et

```dart
final sizeKB = await compressionService.getImageSizeKB(compressedImage!);
final sizeMB = await compressionService.getImageSizeMB(compressedImage!);

print('Görsel boyutu: ${sizeKB.toStringAsFixed(2)} KB');
print('Görsel boyutu: ${sizeMB.toStringAsFixed(2)} MB');
```

## 🔄 Firebase Storage'a Yükleme Örneği

```dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:your_app/services/image_compression_service.dart';

Future<String> uploadCompressedImage(XFile imageFile) async {
  final compressionService = ImageCompressionService();
  
  // Görseli sıkıştır
  final compressedImage = await compressionService.compressImage(
    imageFile,
    maxWidth: 1920,
    maxHeight: 1920,
    quality: 85,
    maxFileSizeKB: 500,
  );
  
  if (compressedImage == null) {
    throw Exception('Görsel sıkıştırılamadı');
  }
  
  // Firebase Storage'a yükle
  final storage = FirebaseStorage.instance;
  final ref = storage.ref().child('images/${DateTime.now().millisecondsSinceEpoch}.jpg');
  
  await ref.putFile(File(compressedImage.path));
  
  // URL'i al
  final downloadUrl = await ref.getDownloadURL();
  
  return downloadUrl;
}
```

## ⚙️ Varsayılan Ayarlar

```dart
static const int maxWidth = 1920;        // Maksimum genişlik (piksel)
static const int maxHeight = 1920;       // Maksimum yükseklik (piksel)
static const int maxFileSizeKB = 500;    // Maksimum dosya boyutu (KB)
static const int quality = 85;           // Kalite (0-100)
```

## 📊 Performans

- **Ortalama boyut azalması:** %60-80
- **Sıkıştırma süresi:** 1-3 saniye (cihaza göre değişir)
- **Kalite kaybı:** Minimal (85% kalite ile)

## 🚨 Önemli Notlar

1. **Web Desteği:** Web platformunda sıkıştırma desteklenmiyor, orijinal dosya döndürülüyor.

2. **Dosya Formatı:** Tüm görseller JPEG formatına dönüştürülüyor (daha küçük boyut).

3. **Otomatik Kalite Düşürme:** Eğer sıkıştırma yeterli değilse, kalite otomatik olarak %30 düşürülüp tekrar deneniyor.

4. **Hata Durumu:** Sıkıştırma başarısız olursa, orijinal dosya döndürülüyor (veri kaybı olmaz).

5. **Geçici Dosyalar:** Sıkıştırılmış görseller geçici dosya olarak oluşturuluyor. Firebase Storage'a yüklendikten sonra silinmeli.

## 🔮 Gelecek Geliştirmeler

- [ ] Profil fotoğrafı yükleme ekranına entegrasyon
- [ ] Deal görseli yükleme ekranına entegrasyon (eğer image picker eklenirse)
- [ ] Progress indicator ekleme
- [ ] Batch compression (birden fazla görsel)
- [ ] Cloud Functions ile otomatik resize (Firebase Storage'da)

## 📝 Örnek Kullanım Senaryoları

### Senaryo 1: Profil Fotoğrafı Yükleme

```dart
Future<void> uploadProfilePicture() async {
  final compressionService = ImageCompressionService();
  
  // Galeriden görsel seç ve sıkıştır
  final compressedImage = await compressionService.pickAndCompressImage(
    maxWidth: 800,  // Profil fotoğrafı için daha küçük
    maxHeight: 800,
    quality: 90,    // Profil fotoğrafı için daha yüksek kalite
    maxFileSizeKB: 200,
  );
  
  if (compressedImage != null) {
    // Firebase Storage'a yükle
    final url = await uploadCompressedImage(compressedImage);
    
    // Firestore'a kaydet
    await updateProfileImage(url);
  }
}
```

### Senaryo 2: Deal Görseli Yükleme

```dart
Future<void> uploadDealImage() async {
  final compressionService = ImageCompressionService();
  
  // Galeriden görsel seç ve sıkıştır
  final compressedImage = await compressionService.pickAndCompressImage(
    maxWidth: 1920,  // Deal görseli için daha büyük
    maxHeight: 1920,
    quality: 85,
    maxFileSizeKB: 500,
  );
  
  if (compressedImage != null) {
    // Firebase Storage'a yükle
    final url = await uploadCompressedImage(compressedImage);
    
    // Deal'e ekle
    _imageUrlController.text = url;
  }
}
```

## 🐛 Sorun Giderme

### Sorun: Sıkıştırma çok yavaş
**Çözüm:** `maxWidth` ve `maxHeight` değerlerini düşürün (örn: 1280x1280).

### Sorun: Görsel kalitesi çok düşük
**Çözüm:** `quality` değerini artırın (örn: 90-95).

### Sorun: Dosya hala çok büyük
**Çözüm:** `maxFileSizeKB` değerini düşürün ve `quality` değerini azaltın.

### Sorun: Web'de çalışmıyor
**Çözüm:** Web platformunda sıkıştırma desteklenmiyor, orijinal dosya kullanılıyor. Bu normal bir davranış.

