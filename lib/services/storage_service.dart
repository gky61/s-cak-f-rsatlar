import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Firebase Storage'dan görsel URL'si al (token ile)
  Future<String> getImageUrl(String imagePath) async {
    try {
      final ref = _storage.ref().child(imagePath);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('❌ Storage: Görsel URL alınamadı: $imagePath - Hata: $e');
      rethrow;
    }
  }

  // Firebase Storage URL'sinden path çıkar
  String? extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Format 1: https://firebasestorage.googleapis.com/v0/b/BUCKET_NAME/o/PATH?alt=media&token=TOKEN
      if (uri.host.contains('firebasestorage.googleapis.com')) {
        final pathSegments = uri.pathSegments;
        // Path segments: ['v0', 'b', 'BUCKET_NAME', 'o', 'PATH_PARTS...']
        if (pathSegments.length > 4 && pathSegments[0] == 'v0' && pathSegments[1] == 'b' && pathSegments[3] == 'o') {
          // Path kısmını al (pathSegments[4] ve sonrası)
          final pathParts = pathSegments.sublist(4);
          // URL decode yap
          return Uri.decodeComponent(pathParts.join('/'));
        }
      }
      
      // Format 2: https://storage.googleapis.com/BUCKET_NAME/PATH
      // Örnek: https://storage.googleapis.com/sicak-firsatlar-e6eae.firebasestorage.app/telegram/...
      if (uri.host.contains('storage.googleapis.com')) {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          // İlk segment bucket name, sonrası path
          // Örnek: ['sicak-firsatlar-e6eae.firebasestorage.app', 'telegram', 'Deneme', '32_1765221690906.jpg']
          if (pathSegments.length > 1) {
            // İlk segment'i atla (bucket name), geri kalanı path
            final pathParts = pathSegments.sublist(1);
            return pathParts.join('/');
          }
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Storage: URL parse hatası: $url - Hata: $e');
      return null;
    }
  }

  // URL'nin Firebase Storage URL'si olup olmadığını kontrol et
  bool isFirebaseStorageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Firebase Storage URL'leri iki formatta olabilir:
      // 1. https://firebasestorage.googleapis.com/...
      // 2. https://storage.googleapis.com/BUCKET_NAME/...
      return uri.host.contains('firebasestorage.googleapis.com') ||
             (uri.host.contains('storage.googleapis.com') && 
              uri.pathSegments.isNotEmpty &&
              uri.pathSegments[0].contains('firebasestorage'));
    } catch (e) {
      return false;
    }
  }

  // Firebase Storage URL'sini yenile (yeni token ile)
  Future<String> refreshImageUrl(String url) async {
    try {
      if (!isFirebaseStorageUrl(url)) {
        // Firebase Storage URL'si değilse, olduğu gibi dön
        return url;
      }

      final path = extractPathFromUrl(url);
      if (path == null) {
        print('⚠️ Storage: URL\'den path çıkarılamadı: $url');
        return url;
      }

      // Yeni token ile URL al
      return await getImageUrl(path);
    } catch (e) {
      print('❌ Storage: URL yenileme hatası: $url - Hata: $e');
      // Hata olursa eski URL'yi dön
      return url;
    }
  }

  // Web için CORS-safe görsel URL'si oluştur
  Future<String> getCorsSafeImageUrl(String imageUrl) async {
    try {
      print('🔍 Storage: URL kontrol ediliyor: $imageUrl');
      
      // Eğer Firebase Storage URL ise, token'ı kontrol et
      if (isFirebaseStorageUrl(imageUrl)) {
        print("📦 Storage: Firebase Storage URL tespit edildi");
        
        // Firebase Storage URL için path'i çıkar ve yeni token ile URL al
        final path = extractPathFromUrl(imageUrl);
        print('📂 Storage: Çıkarılan path: $path');
        
        if (path != null) {
          try {
            // Yeni token ile URL al
            final newUrl = await getImageUrl(path);
            print('✅ Storage: CORS-safe URL oluşturuldu: $newUrl');
            return newUrl;
          } catch (e) {
            print('⚠️ Storage: getImageUrl hatası, orijinal URL kullanılıyor: $e');
            // Hata olursa orijinal URL'i dön (belki zaten geçerli bir URL)
            return imageUrl;
          }
        } else {
          print('⚠️ Storage: Path çıkarılamadı, orijinal URL kullanılıyor');
        }
      } else {
        print('🌐 Storage: Normal URL, direkt kullanılıyor');
      }
      
      // Firebase Storage URL değilse veya path çıkarılamazsa, olduğu gibi dön
      return imageUrl;
    } catch (e, stackTrace) {
      print('❌ Storage: CORS-safe URL oluşturma hatası: $imageUrl - Hata: $e');
      print('❌ Storage: StackTrace: $stackTrace');
      // Hata olursa eski URL'yi dön
      return imageUrl;
    }
  }
}

