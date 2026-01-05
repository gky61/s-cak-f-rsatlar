import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Görsel sıkıştırma servisi
/// Firebase Storage maliyetini azaltmak ve yükleme hızını artırmak için
class ImageCompressionService {
  final ImagePicker _picker = ImagePicker();

  /// Maksimum görsel boyutu (piksel)
  static const int maxWidth = 1920;
  static const int maxHeight = 1920;
  
  /// Maksimum dosya boyutu (KB)
  static const int maxFileSizeKB = 500; // 500 KB
  
  /// Kalite (0-100)
  static const int quality = 85;

  /// Galeriden görsel seç ve sıkıştır
  /// 
  /// [maxWidth] ve [maxHeight]: Maksimum boyutlar (piksel)
  /// [quality]: Kalite (0-100, varsayılan 85)
  /// [maxFileSizeKB]: Maksimum dosya boyutu (KB, varsayılan 500)
  /// 
  /// Returns: Sıkıştırılmış görsel dosyası (XFile) veya null
  Future<XFile?> pickAndCompressImage({
    int? maxWidth,
    int? maxHeight,
    int? quality,
    int? maxFileSizeKB,
  }) async {
    try {
      // Görsel seç
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Önce tam kalite al, sonra sıkıştır
      );

      if (pickedFile == null) {
        _log('📷 Kullanıcı görsel seçmedi');
        return null;
      }

      _log('📷 Görsel seçildi: ${pickedFile.path}');

      // Sıkıştır
      return await compressImage(
        pickedFile,
        maxWidth: maxWidth ?? ImageCompressionService.maxWidth,
        maxHeight: maxHeight ?? ImageCompressionService.maxHeight,
        quality: quality ?? ImageCompressionService.quality,
        maxFileSizeKB: maxFileSizeKB ?? ImageCompressionService.maxFileSizeKB,
      );
    } catch (e) {
      _log('❌ Görsel seçme hatası: $e');
      return null;
    }
  }

  /// Kameradan görsel çek ve sıkıştır
  Future<XFile?> takeAndCompressImage({
    int? maxWidth,
    int? maxHeight,
    int? quality,
    int? maxFileSizeKB,
  }) async {
    try {
      // Görsel çek
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Önce tam kalite al, sonra sıkıştır
      );

      if (pickedFile == null) {
        _log('📷 Kullanıcı görsel çekmedi');
        return null;
      }

      _log('📷 Görsel çekildi: ${pickedFile.path}');

      // Sıkıştır
      return await compressImage(
        pickedFile,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
        maxFileSizeKB: maxFileSizeKB,
      );
    } catch (e) {
      _log('❌ Görsel çekme hatası: $e');
      return null;
    }
  }

  /// Görseli sıkıştır
  /// 
  /// [file]: Sıkıştırılacak görsel dosyası
  /// [maxWidth] ve [maxHeight]: Maksimum boyutlar (piksel)
  /// [quality]: Kalite (0-100)
  /// [maxFileSizeKB]: Maksimum dosya boyutu (KB)
  /// 
  /// Returns: Sıkıştırılmış görsel dosyası (XFile) veya null
  Future<XFile?> compressImage(
    XFile file, {
    int? maxWidth,
    int? maxHeight,
    int? quality,
    int? maxFileSizeKB,
  }) async {
    try {
      if (kIsWeb) {
        // Web'de sıkıştırma desteklenmiyor, orijinal dosyayı dön
        _log('⚠️ Web platformunda görsel sıkıştırma desteklenmiyor');
        return file;
      }

      // Dosya boyutunu kontrol et
      final fileSize = await file.length();
      final fileSizeKB = fileSize / 1024;
      _log('📊 Orijinal dosya boyutu: ${fileSizeKB.toStringAsFixed(2)} KB');

      final finalMaxWidth = maxWidth ?? ImageCompressionService.maxWidth;
      final finalMaxHeight = maxHeight ?? ImageCompressionService.maxHeight;
      final finalQuality = quality ?? ImageCompressionService.quality;
      final finalMaxFileSizeKB = maxFileSizeKB ?? ImageCompressionService.maxFileSizeKB;

      // Eğer dosya zaten küçükse, sıkıştırmaya gerek yok
      if (fileSizeKB <= finalMaxFileSizeKB) {
        _log('✅ Dosya zaten küçük, sıkıştırma gerekmiyor');
        return file;
      }

      // Sıkıştır
      final filePath = file.path;
      final targetPath = '${filePath}_compressed.jpg';
      
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        quality: finalQuality,
        minWidth: 0,
        minHeight: 0,
        maxWidth: finalMaxWidth,
        maxHeight: finalMaxHeight,
        format: CompressFormat.jpeg, // JPEG formatı (daha küçük)
      );

      if (compressedFile == null) {
        _log('❌ Görsel sıkıştırma başarısız');
        return file; // Hata olursa orijinal dosyayı dön
      }

      // Sıkıştırılmış dosya boyutunu kontrol et
      final compressedSize = await compressedFile.length();
      final compressedSizeKB = compressedSize / 1024;
      _log('📊 Sıkıştırılmış dosya boyutu: ${compressedSizeKB.toStringAsFixed(2)} KB');
      _log('📉 Boyut azalması: ${((1 - compressedSize / fileSize) * 100).toStringAsFixed(1)}%');

      // Eğer sıkıştırma yeterli değilse, kaliteyi düşür ve tekrar dene
      if (compressedSizeKB > finalMaxFileSizeKB && finalQuality > 50) {
        _log('⚠️ Sıkıştırma yeterli değil, kalite düşürülüyor...');
        return await compressImage(
          file,
          maxWidth: finalMaxWidth,
          maxHeight: finalMaxHeight,
          quality: (finalQuality * 0.7).round(), // Kaliteyi %30 düşür
          maxFileSizeKB: finalMaxFileSizeKB,
        );
      }

      return XFile(compressedFile.path);
    } catch (e) {
      _log('❌ Görsel sıkıştırma hatası: $e');
      return file; // Hata olursa orijinal dosyayı dön
    }
  }

  /// URL'den görsel indir ve sıkıştır (opsiyonel)
  /// 
  /// Not: Bu fonksiyon şu an kullanılmıyor çünkü deal görselleri
  /// direkt URL olarak saklanıyor. Ancak gelecekte kullanılabilir.
  Future<XFile?> downloadAndCompressImage(
    String imageUrl, {
    int? maxWidth,
    int? maxHeight,
    int? quality,
    int? maxFileSizeKB,
  }) async {
    try {
      _log('📥 Görsel indiriliyor: $imageUrl');

      // Görseli indir
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        _log('❌ Görsel indirme hatası: ${response.statusCode}');
        return null;
      }

      // Geçici dosya oluştur
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);

      final xFile = XFile(tempFile.path);

      // Sıkıştır
      return await compressImage(
        xFile,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
        maxFileSizeKB: maxFileSizeKB,
      );
    } catch (e) {
      _log('❌ Görsel indirme ve sıkıştırma hatası: $e');
      return null;
    }
  }

  /// Görsel boyutunu kontrol et (KB cinsinden)
  Future<double> getImageSizeKB(XFile file) async {
    try {
      final size = await file.length();
      return size / 1024;
    } catch (e) {
      _log('❌ Görsel boyutu kontrol hatası: $e');
      return 0;
    }
  }

  /// Görsel boyutunu kontrol et (MB cinsinden)
  Future<double> getImageSizeMB(XFile file) async {
    final sizeKB = await getImageSizeKB(file);
    return sizeKB / 1024;
  }
}

