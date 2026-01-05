import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_auth/firebase_auth.dart';

void _log(String message) {
  if (kDebugMode) _log(message);
}

/// Global hata yönetimi ve kullanıcı dostu mesajlar
class ErrorHandler {
  /// Hata mesajını kullanıcı dostu Türkçe mesaja çevir
  static String getErrorMessage(dynamic error) {
    if (error == null) {
      return 'Bilinmeyen bir hata oluştu. Lütfen tekrar deneyin.';
    }

    final errorString = error.toString().toLowerCase();
    final errorMessage = error is Exception ? error.toString() : errorString;

    // Firebase Auth hataları
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
        case 'network_error':
          return 'İnternet bağlantınızı kontrol edin.';
        case 'user-not-found':
          return 'Kullanıcı bulunamadı.';
        case 'wrong-password':
          return 'Hatalı şifre. Lütfen tekrar deneyin.';
        case 'email-already-in-use':
          return 'Bu e-posta adresi zaten kullanılıyor.';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi.';
        case 'weak-password':
          return 'Şifre çok zayıf. En az 6 karakter olmalı.';
        case 'too-many-requests':
          return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
        case 'operation-not-allowed':
          return 'Bu işlem şu anda kullanılamıyor.';
        case 'requires-recent-login':
          return 'Güvenlik için lütfen tekrar giriş yapın.';
        case 'invalid-credential':
          return 'Geçersiz kimlik bilgisi. Lütfen tekrar deneyin.';
        case 'account-exists-with-different-credential':
          return 'Bu e-posta adresi farklı bir giriş yöntemiyle kayıtlı.';
        default:
          return 'Giriş yapılamadı. Lütfen tekrar deneyin.';
      }
    }

    // Network hataları
    if (errorMessage.contains('network') ||
        errorMessage.contains('socket') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('failed host lookup')) {
      return 'İnternet bağlantınızı kontrol edin.';
    }

    // Firebase/Firestore hataları
    if (errorMessage.contains('permission-denied') ||
        errorMessage.contains('permission denied')) {
      return 'Bu işlem için yetkiniz yok.';
    }

    if (errorMessage.contains('unavailable') ||
        errorMessage.contains('service unavailable')) {
      return 'Servis şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
    }

    if (errorMessage.contains('deadline-exceeded') ||
        errorMessage.contains('timeout')) {
      return 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.';
    }

    if (errorMessage.contains('not-found') ||
        errorMessage.contains('not found')) {
      return 'Aranan içerik bulunamadı.';
    }

    // Veri tipi hataları
    if (errorMessage.contains("type 'list") ||
        errorMessage.contains("type 'map") ||
        errorMessage.contains('is not a subtype')) {
      return 'Veri okunurken bir hata oluştu. Lütfen tekrar deneyin.';
    }

    // Google Sign-In hataları
    if (errorMessage.contains('sign_in_canceled') ||
        errorMessage.contains('canceled')) {
      return 'Giriş iptal edildi.';
    }

    if (errorMessage.contains('sign_in_failed') ||
        errorMessage.contains('sign_in')) {
      return 'Giriş başarısız oldu. Lütfen tekrar deneyin.';
    }

    // Genel hata mesajları
    if (errorMessage.contains('invalid') ||
        errorMessage.contains('geçersiz')) {
      return 'Geçersiz bilgi. Lütfen kontrol edin.';
    }

    if (errorMessage.contains('empty') ||
        errorMessage.contains('boş')) {
      return 'Lütfen tüm alanları doldurun.';
    }

    // Çok uzun hata mesajlarını kısalt
    if (errorMessage.length > 150) {
      return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }

    // Özel hata mesajları varsa onları kullan
    if (error is Exception && error.toString().startsWith('Exception: ')) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.isNotEmpty && message.length < 100) {
        return message;
      }
    }

    // Varsayılan mesaj
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  /// Hata mesajını SnackBar olarak göster
  static void showError(BuildContext? context, dynamic error, {Duration? duration}) {
    if (context == null) return;

    final message = getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Tamam',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Başarı mesajını SnackBar olarak göster
  static void showSuccess(BuildContext? context, String message, {Duration? duration}) {
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Bilgi mesajını SnackBar olarak göster
  static void showInfo(BuildContext? context, String message, {Duration? duration}) {
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Hata logla (debug için)
  static void logError(dynamic error, [StackTrace? stackTrace]) {
    _log('❌ Hata: $error');
    if (stackTrace != null) {
      _log('📍 Stack trace: $stackTrace');
    }
  }
}

