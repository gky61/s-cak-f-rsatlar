import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // Lazy getters: Firebase.initializeApp() öncesinde çağrıldığında [core/no-app] çökmesini engeller
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Bellek içi tekilleştirme önbelleği: Fingerprint -> Son gönderim zamanı
  final Map<String, DateTime> _dedupCache = {};

  // Saatlik hata bütçesi kontrolü
  DateTime _currentHourWindow = DateTime.now();
  int _hourlyLogCount = 0;
  int get _maxLogsPerHour => isProductionFlavor ? 10 : 50;

  static final Set<String> _sensitiveKeys = {
    'password', 'token', 'secret', 'authorization', 'cookie', 
    'apikey', 'accesstoken', 'idtoken', 'refreshtoken',
    'credential', 'bearer', 'privatekey', 'fcmtoken'
  };

  static Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic>? meta) {
    if (meta == null || meta.isEmpty) return {};
    final clean = <String, dynamic>{};
    for (final entry in meta.entries) {
      final normKey = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      var isSensitive = false;
      for (final sKey in _sensitiveKeys) {
        if (normKey.contains(sKey)) {
          isSensitive = true;
          break;
        }
      }
      if (isSensitive) {
        clean[entry.key] = '[REDACTED]';
      } else if (entry.value is Map<String, dynamic>) {
        clean[entry.key] = _sanitizeMetadata(entry.value as Map<String, dynamic>);
      } else {
        clean[entry.key] = entry.value;
      }
    }
    return clean;
  }

  static String _normalizeMessageForFingerprint(String msg) {
    if (msg.isEmpty) return '';
    return msg
        .replaceAll(RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'), '[UUID]')
        .replaceAll(RegExp(r'\b[0-9a-zA-Z]{20}\b'), '[DOC_ID]')
        .replaceAll(RegExp(r'\b\d{4,}\b'), '[NUM]')
        .trim();
  }

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
    final normalizedMsg = _normalizeMessageForFingerprint(message);
    final shortMsg = normalizedMsg.length > 80 ? normalizedMsg.substring(0, 80) : normalizedMsg;
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
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) {
          print('⚠️ [SystemLog] Firebase henüz başlatılmadı. Firestore log yazması atlandı.');
        }
        return;
      }
      final currentUser = _auth.currentUser;
      final currentUserId = currentUser?.uid;
      final currentUserEmail = currentUser?.email;
      final currentUserDisplayName = currentUser?.displayName;
      final env = isProductionFlavor ? 'prod' : 'dev';
      final platform = kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      final sanitizedCustomMeta = _sanitizeMetadata(metadata);

      final logData = {
        'environment': env,
        'service': 'mobile',
        'category': category.length > 50 ? category.substring(0, 50) : category,
        if (subCategory != null) 'subCategory': subCategory,
        if (currentUserId != null) 'userId': currentUserId,
        if (currentUserEmail != null) 'userEmail': currentUserEmail,
        'errorType': errorType.length > 100 ? errorType.substring(0, 100) : errorType,
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
          ...sanitizedCustomMeta,
        },
        'lastOccurredAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('systemErrors').add(logData).timeout(const Duration(seconds: 5));
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
