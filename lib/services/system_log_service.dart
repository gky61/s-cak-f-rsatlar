import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

enum SystemErrorSeverity {
  info,
  warning,
  error,
  fatal,
}

extension SystemErrorSeverityExt on SystemErrorSeverity {
  String get value {
    switch (this) {
      case SystemErrorSeverity.info:
        return 'info';
      case SystemErrorSeverity.warning:
        return 'warning';
      case SystemErrorSeverity.error:
        return 'error';
      case SystemErrorSeverity.fatal:
        return 'fatal';
    }
  }
}

/// FırsatKolik Sıfır Maliyetli (Zero-Cost / Free-Tier Safe) Merkezi Loglama Servisi
/// 
/// Firestore ücretsiz kotasını (günlük 20.000 yazma) korumak için:
/// 1. Bellek içi tekilleştirme (De-duplication - 5 dakika)
/// 2. Cihaz başına saatlik üst kota (azami 5 hata/saat)
/// 3. Yalnızca 'error' ve 'fatal' seviyelerini veritabanına yazma
/// 4. Çevrimdışı / SocketException durumunda sessiz koruma
class SystemLogService {
  SystemLogService._internal();
  static final SystemLogService instance = SystemLogService._internal();
  factory SystemLogService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Bellek içi tekilleştirme önbelleği: Fingerprint -> Son gönderim zamanı
  final Map<String, DateTime> _dedupCache = {};

  // Saatlik hata bütçesi kontrolü
  DateTime _currentHourWindow = DateTime.now();
  int _hourlyLogCount = 0;
  static const int _maxLogsPerHour = 5;

  /// Merkezi Hata Kaydı (Arka planda asenkron çalışır, uygulamayı asla bloklamaz veya çökertmez)
  Future<void> logError({
    required String category,
    required String errorType,
    required String message,
    dynamic stack,
    String? subCategory,
    SystemErrorSeverity severity = SystemErrorSeverity.error,
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Yerel debug loglama
    if (kDebugMode) {
      print('🚨 [SystemLog] [${severity.value.toUpperCase()}] [$category] $errorType: $message');
      if (stack != null) print('   Stack: $stack');
    }

    // 2. Sadece 'error' ve 'fatal' seviyeleri Firestore'a gider (Ücretsiz kota koruması)
    if (severity != SystemErrorSeverity.error && severity != SystemErrorSeverity.fatal) {
      return;
    }

    // 3. Çevrimdışı ve internet yokluğu hatalarını yut (İkinci bir Firestore hatası üretmeme)
    final msgLower = message.toLowerCase();
    if (message.contains('SocketException') ||
        msgLower.contains('network is unreachable') ||
        msgLower.contains('failed host lookup') ||
        msgLower.contains('connection refused') ||
        msgLower.contains('connection timed out')) {
      return;
    }

    // 4. Saatlik Bütçe Kontrolü (Hata döngülerini ve kota patlamasını engeller)
    final now = DateTime.now();
    if (now.difference(_currentHourWindow).inHours >= 1) {
      _currentHourWindow = now;
      _hourlyLogCount = 0;
      _dedupCache.clear();
    }

    if (_hourlyLogCount >= _maxLogsPerHour) {
      if (kDebugMode) {
        print('⚠️ [SystemLog] Saatlik hata limiti ($_maxLogsPerHour) aşıldı. Firestore yazması atlanıyor.');
      }
      return;
    }

    // 5. Bellek içi 5 Dakikalık Tekilleştirme (De-duplication)
    final shortMsg = message.length > 80 ? message.substring(0, 80) : message;
    final fingerprint = '${category}_${errorType}_$shortMsg';

    if (_dedupCache.containsKey(fingerprint)) {
      final lastTime = _dedupCache[fingerprint]!;
      if (now.difference(lastTime).inMinutes < 5) {
        if (kDebugMode) {
          print('ℹ️ [SystemLog] Mükerrer hata (5 dk içinde): $fingerprint. Atlandı.');
        }
        return;
      }
    }

    // Yeni kayıt için bütçeyi güncelle
    _dedupCache[fingerprint] = now;
    _hourlyLogCount++;

    // 6. Firestore'a Güvenli ve Zenginleştirilmiş Kayıt
    try {
      final currentUser = _auth.currentUser;
      final currentUserId = currentUser?.uid;
      final currentUserEmail = currentUser?.email;
      final currentUserDisplayName = currentUser?.displayName;
      final env = isProductionFlavor ? 'prod' : 'dev';
      final platform = kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

      final logData = {
        'environment': env,
        'service': 'mobile',
        'category': category,
        if (subCategory != null) 'subCategory': subCategory,
        if (currentUserId != null) 'userId': currentUserId,
        if (currentUserEmail != null) 'userEmail': currentUserEmail,
        'errorType': errorType,
        'message': message.length > 500 ? message.substring(0, 500) : message,
        'stack': stack != null ? (stack.toString().length > 2000 ? stack.toString().substring(0, 2000) : stack.toString()) : null,
        'severity': severity.value,
        'status': 'unresolved',
        'fingerprint': fingerprint,
        'occurrenceCount': 1,
        'platform': platform,
        'metadata': {
          if (currentUserId != null) 'userId': currentUserId,
          if (currentUserEmail != null) 'userEmail': currentUserEmail,
          if (currentUserDisplayName != null) 'userDisplayName': currentUserDisplayName,
          'platform': platform,
          ...?metadata,
        },
        'lastOccurredAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('systemErrors').add(logData);
      if (kDebugMode) {
        print('💾 [SystemLog] Hata başarıyla Firestore systemErrors koleksiyonuna kaydedildi.');
      }
    } catch (e) {
      // Hata kaydetme işlemi asla ana uygulamayı çökertmemeli
      if (kDebugMode) {
        print('⚠️ [SystemLog] Firestore log kaydetme hatası: $e');
      }
    }
  }
}
