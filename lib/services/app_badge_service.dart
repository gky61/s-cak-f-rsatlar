import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void _log(String message) {
  if (kDebugMode) {
    print('🏷️ [AppBadgeService] $message');
  }
}

/// Dünya Standartlarında (PROD-READY) Uygulama İkonu Rozet (App Badge) Yöneticisi.
///
/// iOS üzerinde [UIApplication.shared.applicationIconBadgeNumber] ve [UNUserNotificationCenter.setBadgeCount],
/// Android üzerinde aktif bildirim çekmecesi ve başlatıcı (launcher) bildirim noktasını
/// Firestore'daki gerçek okunmamış bildirim ve mesajlarla 100% reaktif senkronize eder.
class AppBadgeService {
  static final AppBadgeService _instance = AppBadgeService._internal();
  factory AppBadgeService() => _instance;
  AppBadgeService._internal();

  static AppBadgeService get instance => _instance;

  static const MethodChannel _channel = MethodChannel('com.sicakfirsatlar.app/badge');
  FirebaseFirestore? _customFirestore;
  FirebaseAuth? _customAuth;
  FlutterLocalNotificationsPlugin? _customLocalNotifications;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FlutterLocalNotificationsPlugin get _localNotifications => _customLocalNotifications ?? FlutterLocalNotificationsPlugin();

  @visibleForTesting
  void setDependenciesForTesting({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) {
    _customFirestore = firestore;
    _customAuth = auth;
    _customLocalNotifications = localNotifications;
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _adminMessagesSub;

  int _cachedUnreadNotifications = 0;
  int _cachedUnreadMessages = 0;
  int _cachedUnreadAdminMessages = 0;
  int _currentBadgeCount = 0;

  DateTime? _lastSyncTime;
  String? _lastSyncUserId;
  static const Duration _syncCooldown = Duration(seconds: 45);

  int get currentBadgeCount => _currentBadgeCount;

  /// Rozet sayısını doğrudan belirle (Değer aynıysa gereksiz native çağrıyı engeller)
  Future<void> setBadge(int count) async {
    if (kIsWeb) return;
    final targetCount = count < 0 ? 0 : count;

    if (targetCount == 0) {
      await clearBadge();
      return;
    }

    if (_currentBadgeCount == targetCount) {
      return; // Değer değişmediyse native çağrıyı atla
    }

    _currentBadgeCount = targetCount;

    try {
      await _channel.invokeMethod('setBadge', {'count': targetCount});
      _log('✅ Rozet sayısı güncellendi: $targetCount');
    } catch (e) {
      _log('⚠️ setBadge hatası: $e');
    }
  }

  /// Rozeti tamamen sıfırla (Zaten sıfırsa mükerrer native çağrıları ve logları engeller)
  Future<void> clearBadge({bool force = false}) async {
    if (kIsWeb) return;
    if (!force && _currentBadgeCount == 0) {
      return; // Zaten temiz ise gereksiz native IPC çağrısı yapma
    }
    _currentBadgeCount = 0;

    try {
      await _channel.invokeMethod('clearBadge');
    } catch (e) {
      _log('⚠️ Native clearBadge hatası: $e');
    }

    try {
      // Android bildirim çekmecesini de temizle (böylece launcher dot anında söner)
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _localNotifications.cancelAll();
      }
    } catch (e) {
      _log('⚠️ LocalNotifications cancelAll hatası: $e');
    }

    _log('🧹 Uygulama rozeti ve aktif bildirimler tamamen temizlendi (0)');
  }

  /// Kullanıcının Firestore'daki gerçek okunmamış bildirim ve mesaj sayısını toplayıp rozeti senkronize eder
  Future<int> syncBadgeWithFirestore({String? targetUserId, bool forceSync = false}) async {
    if (kIsWeb) return 0;
    final uid = targetUserId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      await clearBadge();
      return 0;
    }

    // Cooldown / Debounce: Son senkronizasyondan bu yana 45 saniye geçmediyse gereksiz Firestore count sorgularını atla
    if (!forceSync &&
        _lastSyncUserId == uid &&
        _lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < _syncCooldown) {
      return _currentBadgeCount;
    }

    try {
      // 1. Okunmamış Bildirimler (users/{uid}/notifications where read == false)
      // Maliyet ve hız optimizasyonu için AggregateQuery (count) kullanılır
      final notifsCountSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .count()
          .get();
      final unreadNotifs = notifsCountSnap.count ?? 0;

      // 2. Okunmamış Birebir Mesajlar (messages where receiverId == uid && isRead == false)
      final messagesCountSnap = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      final unreadMessages = messagesCountSnap.count ?? 0;

      // 3. Okunmamış Admin-User Mesajları
      int unreadAdminMessages = 0;
      try {
        final adminMsgSnap = await _firestore
            .collection('adminToUserMessages')
            .where('userId', isEqualTo: uid)
            .where('isRead', isEqualTo: false)
            .count()
            .get();
        unreadAdminMessages = adminMsgSnap.count ?? 0;
      } catch (_) {}

      _lastSyncTime = DateTime.now();
      _lastSyncUserId = uid;

      final totalUnread = unreadNotifs + unreadMessages + unreadAdminMessages;
      _log('📊 Firestore senkronizasyonu: $unreadNotifs bildirim + $unreadMessages mesaj + $unreadAdminMessages admin = Toplam $totalUnread');

      if (totalUnread <= 0) {
        await clearBadge();
      } else {
        await setBadge(totalUnread);
      }
      return totalUnread;
    } catch (e) {
      _log('❌ syncBadgeWithFirestore hatası: $e');
      return _currentBadgeCount;
    }
  }

  /// Oturum açıkken Firestore snapshot'ları üzerinden rozeti 100% reaktif canlı tutar
  void startRealtimeBadgeSync(String userId) {
    if (kIsWeb || userId.isEmpty) return;
    stopRealtimeBadgeSync();
    _log('🚀 Canlı rozet dinleyicileri başlatılıyor (uid: $userId)...');

    // 1. Bildirimler Dinleyicisi
    _notificationsSub = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .limit(100)
        .snapshots()
        .listen((snap) {
      _cachedUnreadNotifications = snap.docs.length;
      _updateTotalAndApply();
    }, onError: (e) => _log('⚠️ Bildirim rozet dinleme hatası: $e'));

    // 2. Birebir Sohbet Mesajları Dinleyicisi
    _messagesSub = _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .limit(100)
        .snapshots()
        .listen((snap) {
      _cachedUnreadMessages = snap.docs.length;
      _updateTotalAndApply();
    }, onError: (e) => _log('⚠️ Mesaj rozet dinleme hatası: $e'));

    // 3. Admin-Kullanıcı Mesajları Dinleyicisi
    _adminMessagesSub = _firestore
        .collection('adminToUserMessages')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .limit(100)
        .snapshots()
        .listen((snap) {
      _cachedUnreadAdminMessages = snap.docs.length;
      _updateTotalAndApply();
    }, onError: (e) => _log('⚠️ Admin mesaj rozet dinleme hatası: $e'));
  }

  void _updateTotalAndApply() {
    final total = _cachedUnreadNotifications + _cachedUnreadMessages + _cachedUnreadAdminMessages;
    if (total <= 0) {
      clearBadge();
    } else {
      setBadge(total);
    }
  }

  /// Oturum kapatıldığında veya kullanıcı değiştiğinde dinleyicileri bellek sızıntısız durdurur
  void stopRealtimeBadgeSync() {
    _notificationsSub?.cancel();
    _notificationsSub = null;
    _messagesSub?.cancel();
    _messagesSub = null;
    _adminMessagesSub?.cancel();
    _adminMessagesSub = null;

    _cachedUnreadNotifications = 0;
    _cachedUnreadMessages = 0;
    _cachedUnreadAdminMessages = 0;
    _lastSyncTime = null;
    _lastSyncUserId = null;
    _log('🛑 Canlı rozet dinleyicileri durduruldu');
  }
}
