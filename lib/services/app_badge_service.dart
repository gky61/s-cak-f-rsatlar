import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

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

  int _currentBadgeCount = 0;
  bool _isNativeBadgeZero = false;

  DateTime? _lastSyncTime;
  String? _lastSyncUserId;
  static const Duration _syncCooldown = Duration(seconds: 15);

  int get currentBadgeCount => _currentBadgeCount;

  /// Native taraftaki (iOS / Android) gerçek rozet sayısını sorgular
  Future<int> getNativeBadgeCount() async {
    if (kIsWeb) return 0;
    try {
      final res = await _channel.invokeMethod<int>('getBadge');
      return res ?? 0;
    } catch (_) {
      return _currentBadgeCount;
    }
  }

  /// Rozet sayısını doğrudan belirle (Hedef 0 ise kesin clearBadge çağırır)
  Future<void> setBadge(int count) async {
    if (kIsWeb) return;
    final targetCount = count < 0 ? 0 : count;

    if (targetCount == 0) {
      await clearBadge(force: true);
      return;
    }

    _currentBadgeCount = targetCount;
    _isNativeBadgeZero = false;

    try {
      await _channel.invokeMethod('setBadge', {'count': targetCount});
      _log('✅ Rozet sayısı güncellendi: $targetCount');
    } catch (e) {
      _log('⚠️ setBadge hatası: $e');
    }
  }

  /// Rozeti tamamen sıfırla (İşletim sistemi SpringBoard ve yerel bildirimleri koşulsuz temizler)
  Future<void> clearBadge({bool force = true}) async {
    if (kIsWeb) return;
    if (!force && _currentBadgeCount == 0 && _isNativeBadgeZero) {
      return; // Zaten doğrulanmış şekilde sıfırsa gereksiz IPC çağrısı yapma
    }
    _currentBadgeCount = 0;

    try {
      await _channel.invokeMethod('clearBadge');
      _isNativeBadgeZero = true;
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
      await clearBadge(force: true);
      return 0;
    }

    // Cooldown / Debounce: Arka plan senkronizasyonlarında son çağrıdan bu yana 15 saniye geçmediyse count sorgularını atla.
    // Kullanıcı bir bildirim veya mesajı okuduğunda (targetUserId verildiğinde veya forceSync=true olduğunda)
    // rozet kullanıcının gözü önünde anında ve gecikmesiz senkronize edilir.
    if (!forceSync &&
        targetUserId == null &&
        _lastSyncUserId == uid &&
        _lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < _syncCooldown) {
      return _currentBadgeCount;
    }

    try {
      // Buluttaki bildirim tercihlerini (okundu/silindi listeleri) SharedPreferences'a hydrate et (Reinstall dirilme kalkanı)
      await FirestoreService().syncAnnouncementPreferencesFromCloud(uid);

      // 1. Okunmamış Bildirimler (users/{uid}/notifications where read == false)
      // Maliyet ve hız optimizasyonu için AggregateQuery (count) kullanılır
      final notifsCountSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .count()
          .get();
      int unreadNotifs = notifsCountSnap.count ?? 0;

      // Kendi Kendini Onaran (Self-Healing) Mutabakat Kalkanı:
      // Yalnızca kullanıcı bir bildirimle etkileşime girdiğinde (forceSync veya targetUserId != null)
      // ve küçük sayaçlarda (1-10 bildirim), yerelde/bulutta zaten okunmuş veya gizlenmiş yetim kupon/duyuru dokümanlarını
      // tespit edip sayacı 0'a düşürür ve Firestore'daki kaydı arka planda okundu yapar.
      // 100k kullanıcı ölçeğinde rutin arka plan senkronizasyonlarında doküman çekilmez; kota patlama riski sıfırdır.
      if ((forceSync || targetUserId != null) && unreadNotifs > 0 && unreadNotifs <= 10) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final localRead = prefs.getStringList('read_announcements') ?? [];
          final localDismissed = prefs.getStringList('dismissed_announcements') ?? [];
          final readSet = {...localRead, ...FirestoreService.cachedReadAnnouncements};
          final dismissedSet = {...localDismissed, ...FirestoreService.cachedDismissedAnnouncements};

          if (readSet.isNotEmpty || dismissedSet.isNotEmpty) {
            final unreadDocs = await _firestore
                .collection('users')
                .doc(uid)
                .collection('notifications')
                .where('read', isEqualTo: false)
                .limit(10)
                .get();

            int adjusted = 0;
            for (final d in unreadDocs.docs) {
              final id = d.id;
              final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
              final annId = d.data()['announcementId'] as String?;
              final isDismissed = dismissedSet.contains(id) ||
                  dismissedSet.contains(normalizedId) ||
                  (annId != null && (dismissedSet.contains(annId) || dismissedSet.contains('manual_$annId')));
              final isRead = readSet.contains(id) ||
                  readSet.contains(normalizedId) ||
                  (annId != null && (readSet.contains(annId) || readSet.contains('manual_$annId')));

              if (isDismissed || isRead) {
                d.reference.update({'read': true}).catchError((_) {});
              } else {
                adjusted++;
              }
            }
            unreadNotifs = adjusted;
          }
        } catch (_) {}
      }

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

      // 4. Okunmamış Genel Duyurular (globalAnnouncements where active == true)
      int unreadAnnouncements = 0;
      try {
        final prefs = await SharedPreferences.getInstance();
        final localRead = prefs.getStringList('read_announcements') ?? [];
        final localDismissed = prefs.getStringList('dismissed_announcements') ?? [];
        final readSet = {...localRead, ...FirestoreService.cachedReadAnnouncements};
        final dismissedSet = {...localDismissed, ...FirestoreService.cachedDismissedAnnouncements};

        final annSnap = await _firestore
            .collection('globalAnnouncements')
            .where('active', isEqualTo: true)
            .limit(15)
            .get();
        final now = DateTime.now();
        for (final doc in annSnap.docs) {
          final id = doc.id;
          final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
          if (dismissedSet.contains(id) || dismissedSet.contains(normalizedId)) continue;
          if (readSet.contains(id) || readSet.contains(normalizedId)) continue;
          final exp = doc.data()['expiresAt'];
          if (exp is Timestamp && exp.toDate().isBefore(now)) continue;
          unreadAnnouncements++;
        }
      } catch (_) {}

      _lastSyncTime = DateTime.now();
      _lastSyncUserId = uid;

      final totalUnread = unreadNotifs + unreadMessages + unreadAdminMessages + unreadAnnouncements;
      _log('📊 Firestore senkronizasyonu: $unreadNotifs bildirim + $unreadMessages mesaj + $unreadAdminMessages admin + $unreadAnnouncements duyuru = Toplam $totalUnread');

      if (totalUnread <= 0) {
        await clearBadge(force: true);
      } else {
        await setBadge(totalUnread);
      }
      return totalUnread;
    } catch (e) {
      _log('❌ syncBadgeWithFirestore hatası: $e');
      return _currentBadgeCount;
    }
  }

  /// FS-16: 100k kullanıcı ölçeğinde 300.000 açık WebSocket snapshot dinleyicisinin
  /// thundering herd ve kota patlaması yaratmasını engellemek için On-Demand & Event-Driven
  /// rozet modeline geçilmiştir. Sürekli açık stream'ler kapatılmış olup rozet sayısı
  /// FCM push payload'ları ve [syncBadgeWithFirestore] aggregate query ile senkronize edilir.
  void startRealtimeBadgeSync(String userId) {
    if (kIsWeb || userId.isEmpty) return;
    stopRealtimeBadgeSync();
    _log('ℹ️ [AppBadgeService] FS-16 Kalkanı: On-Demand & Event-Driven rozet senkronizasyonu aktif (300k socket tasarrufu, uid: $userId)');
  }


  /// Oturum kapatıldığında veya kullanıcı değiştiğinde rozet durumunu sıfırlar
  void stopRealtimeBadgeSync() {
    _lastSyncTime = null;
    _lastSyncUserId = null;
    _isNativeBadgeZero = false;
    _log('🛑 Canlı rozet dinleyicileri durduruldu');
  }
}
