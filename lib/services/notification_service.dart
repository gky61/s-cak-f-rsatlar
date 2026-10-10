import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data'; // For Int64List
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_preferences.dart';
import 'analytics_service.dart';
import 'auth_service.dart';
import 'system_log_service.dart';

import '../main.dart'; // navigatorKey için
import '../screens/deal_detail_screen.dart';
import '../screens/admin_notifications_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/message_screen.dart';
import '../screens/messages_list_screen.dart';
import '../screens/kuponlar_page.dart';
import '../widgets/in_app_message_banner.dart';

/// Bildirim yönlendirme hedef tipleri
enum NotificationDestinationType {
  deal,
  chat,
  messagesList,
  adminChat,
  adminScreen,
  adminNotifications,
  coupons,
  none,
}

/// Bildirim yönlendirme karar modeli
class NotificationRoutingDecision {
  final NotificationDestinationType destination;
  final String? dealId;
  final String? commentId;
  final String? senderId;
  final String? senderName;
  final String? kuponId;
  final String? notificationId;
  final int initialTabIndex;

  const NotificationRoutingDecision({
    required this.destination,
    this.dealId,
    this.commentId,
    this.senderId,
    this.senderName,
    this.kuponId,
    this.notificationId,
    this.initialTabIndex = 0,
  });
}

/// Debug modda log yazdır
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
  // Logları stream'e ekle (Debug ekranı için)
  NotificationService.logStream.add(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final StreamController<String> logStream = StreamController<String>.broadcast();
  static String? activeChatUserId;
  static String? activeDealId;
  static bool isAdminScreenActive = false;
  static bool isCouponsScreenActive = false;

  static bool _notificationListenersSetup = false;
  static bool _isLocalNotificationsInitialized = false;
  static bool _hasHandledColdStartNotification = false;
  static const MethodChannel _iosNotificationChannel = MethodChannel('com.sicakfirsatlar.app/notifications');
  static bool _isIosChannelSetup = false;

  // Oturum içi mükerrer FCM token kaydı ve admin topic abonelik koruması
  static String? _lastRegisteredDocId;
  static String? _lastRegisteredToken;
  static DateTime? _lastDeviceTokenRegisterTime;
  static const Duration _deviceTokenRegisterCooldown = Duration(minutes: 30);
  static const Duration _deviceTokenRegisterDiskTTL = Duration(hours: 24);
  static const String _prefFcmDocId = 'fcm_last_registered_doc_id';
  static const String _prefFcmToken = 'fcm_last_registered_token';
  static const String _prefFcmTimestamp = 'fcm_last_registered_timestamp';
  static const int _maxActiveDevicesPerUser = 3;
  static Future<void>? _inFlightTokenSave;

  static bool _isAdminTopicSubscribedInSession = false;
  static String? _lastSubscribedAdminUid;

  // Lazy getters: Firebase.initializeApp() öncesinde çağrıldığında [core/no-app] çökmesini engeller
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _keywordListener;
  final Set<String> _notifiedDealIds = <String>{};
  bool _keywordListenerAttached = false;

  StreamSubscription<String>? _tokenRefreshSub;

  // Topic adını geçerli formata çevir (Firebase Cloud Messaging kurallarına uygun)
  String _sanitizeTopicName(String name) {
    // Türkçe karakterleri İngilizce karşılıklarına çevir
    String sanitized = name
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('Ç', 'c')
        .replaceAll('Ğ', 'g')
        .replaceAll('İ', 'i')
        .replaceAll('Ö', 'o')
        .replaceAll('Ş', 's')
        .replaceAll('Ü', 'u');
    
    // Boşlukları ve özel karakterleri tire ile değiştir
    sanitized = sanitized
        .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-') // Birden fazla tireyi tek tireye çevir
        .replaceAll(RegExp(r'^-|-$'), ''); // Başta ve sonda tireyi kaldır
    
    return sanitized;
  }

  // Local notifications'ı başlat
  Future<void> initializeLocalNotifications() async {
    // Web'de local notifications desteklenmiyor
    if (kIsWeb) {
      _log('⚠️ Web platformunda local notifications desteklenmiyor');
      return;
    }

    if (_isLocalNotificationsInitialized) {
      _log('📬 Local notifications zaten başlatılmış, tekrar başlatma atlanıyor.');
      return;
    }
    _isLocalNotificationsInitialized = true;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _log('🔔 Local notification response payload: ${response.payload}');
          _handlePayloadString(response.payload!);
        }
      },
    );

    // Uygulama tamamen kapalıyken (cold start) tıklanan yerel bildirimi yakala (SADECE BİR KEZ)
    if (!_hasHandledColdStartNotification) {
      _hasHandledColdStartNotification = true;
      try {
        final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
          final payload = launchDetails.notificationResponse?.payload;
          if (payload != null && payload.isNotEmpty) {
            _log('🚀 Uygulama kapalıyken tıklanan yerel bildirim (cold start): $payload');
            _handlePayloadString(payload);
          }
        }
      } catch (e) {
        _log('⚠️ Cold start yerel bildirim kontrol hatası: $e');
      }
    }

    // Android notification channel oluştur (genel bildirimler)
    const androidChannel = AndroidNotificationChannel(
      'sicak_firsatlar_general_v2',
      'Sıcak Fırsatlar Bildirimleri',
      description: 'Yeni fırsat bildirimleri için kanal',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Android notification channel oluştur (yorum cevapları)
    const commentReplyChannel = AndroidNotificationChannel(
      'comment_replies_channel',
      'Yorum Cevapları',
      description: 'Yorumlarınıza gelen cevaplar için bildirimler',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(commentReplyChannel);

    // Android notification channel oluştur (anahtar kelime bildirimleri - özel ses)
    const keywordChannel = AndroidNotificationChannel(
      'keyword_alerts_channel',
      'Özel Fırsat Bildirimleri',
      description: 'İlginizi çeken kelimeler için özel ve vurgulu bildirimler',
      importance: Importance.max, // En yüksek önem seviyesi
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFF9800), // Turuncu LED
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(keywordChannel);

    // Android notification channel oluştur (admin bildirimleri - onay bekleyen fırsatlar)
    const adminChannel = AndroidNotificationChannel(
      'admin_channel',
      'Admin Bildirimleri',
      description: 'Onay bekleyen fırsatlar için admin bildirimleri',
      importance: Importance.max, // En yüksek önem seviyesi
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF2196F3), // Mavi LED
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(adminChannel);

    // Android notification channel oluştur (mesaj bildirimleri)
    const messagesChannel = AndroidNotificationChannel(
      'messages_channel_v3', // v3
      'Mesaj Bildirimleri',
      description: 'Kullanıcılar arası mesajlaşma bildirimleri',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF2196F3),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messagesChannel);

    // Android notification channel oluştur (admin mesaj bildirimleri)
    const adminMessagesChannel = AndroidNotificationChannel(
      'admin_messages_channel_v3',
      'Admin Mesaj Bildirimleri',
      description: 'Admin tarafından gönderilen mesaj bildirimleri',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF2196F3),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(adminMessagesChannel);

    // Android notification channel oluştur (takip bildirimleri)
    const followChannel = AndroidNotificationChannel(
      'follow_channel',
      'Takip Bildirimleri',
      description: 'Takip ettiğiniz kullanıcıların paylaşımları için bildirimler',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF4CAF50), // Yeşil LED
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(followChannel);

    _log('✅ Local notifications başlatıldı (genel + anahtar kelime + admin + mesaj + takip kanalları)');
  }

  // Bildirim izinlerini iste
  Future<void> requestPermission() async {
    // Web'de farklı bir izin mekanizması var
    if (kIsWeb) {
      try {
        NotificationSettings settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          _log('✅ Web: Kullanıcı bildirimleri kabul etti');
        }
      } catch (e) {
        _log('⚠️ Web bildirim izni hatası: $e');
      }
      return;
    }
    
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _log('Kullanıcı bildirimleri kabul etti');
    }

    // Local notifications izinleri (yalnızca ilk seferde başlat)
    if (!_isLocalNotificationsInitialized) {
      await initializeLocalNotifications();
    }

    // Android 13+ (API 33+): Bildirim iznini runtime'da iste (mesaj vb. bildirimler için gerekli)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (granted == true) {
        _log('✅ Android: Bildirim izni verildi');
      }
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('notification_device_id');
    if (deviceId == null) {
      final rand = Random();
      final randomId = List.generate(16, (index) => rand.nextInt(10)).join();
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_$randomId';
      await prefs.setString('notification_device_id', deviceId);
    }
    return deviceId;
  }

  Future<void> clearDeviceToken() async {
    try {
      final userId = _auth.currentUser?.uid;
      final deviceId = await _getOrCreateDeviceId();
      if (userId != null) {
        final docRef = _firestore.collection('userDevices').doc('${userId}_$deviceId');
        await docRef.set({
          'active': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _log('✅ Device token marked inactive on logout');
      }
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      if (!kIsWeb) {
        try {
          await _messaging.deleteToken();
          _log('🧹 FCM yerel token önbelleği temizlendi');
        } catch (e) {
          _log('⚠️ deleteToken hatası (devam ediliyor): $e');
        }
      }
      _lastRegisteredDocId = null;
      _lastRegisteredToken = null;
      _lastDeviceTokenRegisterTime = null;
      _isAdminTopicSubscribedInSession = false;
      _lastSubscribedAdminUid = null;

      // FS-AUTH-04: Disk üzerindeki FCM önbelleğini de temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefFcmDocId);
      await prefs.remove(_prefFcmToken);
      await prefs.remove(_prefFcmTimestamp);
    } catch (e) {
      _log('⚠️ Error clearing device token: $e');
    }
  }

  String _getSubscriptionId(String uid, String type, String key) {
    final sanitizedKey = _sanitizeTopicName(key);
    return '${uid}_${type}_$sanitizedKey';
  }

  String normalizeKeyword(String text) {
    return text
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('Ç', 'c')
        .replaceAll('Ğ', 'g')
        .replaceAll('İ', 'i')
        .replaceAll('Ö', 'o')
        .replaceAll('Ş', 's')
        .replaceAll('Ü', 'u')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }

  // --- Kategori Abonelikleri ---
  Future<void> subscribeToCategory(String categoryId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final subId = _getSubscriptionId(userId, 'category', categoryId);
    try {
      await _firestore.collection('notificationSubscriptions').doc(subId).set({
        'uid': userId,
        'type': 'category',
        'key': categoryId,
        'displayValue': categoryId,
        'normalizedValue': categoryId.toLowerCase(),
        'includeDescendants': true,
        'enabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // P0-13 (R-SCL-01): FCM Konusuna abone ol (Sınırsız ölçeklenebilir 0 maliyetli dağıtım)
      final cleanCat = categoryId.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      try {
        await _messaging.subscribeToTopic('cat_$cleanCat');
      } catch (topicErr) {
        _log('⚠️ Kategori topic abonelik uyarısı: $topicErr');
      }
      _log('✅ Category subscription added: $categoryId');
    } catch (e) {
      _log('❌ Category subscription add error: $e');
      rethrow;
    }
  }

  Future<void> unsubscribeFromCategory(String categoryId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final subId = _getSubscriptionId(userId, 'category', categoryId);
    try {
      await _firestore.collection('notificationSubscriptions').doc(subId).delete();
      // P0-13 (R-SCL-01): FCM Konusu aboneliğinden çık
      final cleanCat = categoryId.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      try {
        await _messaging.unsubscribeFromTopic('cat_$cleanCat');
      } catch (topicErr) {
        _log('⚠️ Kategori topic abonelikten çıkış uyarısı: $topicErr');
      }
      _log('✅ Category subscription deleted: $categoryId');
    } catch (e) {
      _log('❌ Category subscription delete error: $e');
      rethrow;
    }
  }

  // --- Alt Kategori Abonelikleri ---
  Future<void> subscribeToSubCategory(String categoryId, String subCategoryId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final key = '$categoryId:$subCategoryId';
    final subId = _getSubscriptionId(userId, 'category', key);
    try {
      await _firestore.collection('notificationSubscriptions').doc(subId).set({
        'uid': userId,
        'type': 'category',
        'key': key,
        'displayValue': subCategoryId,
        'normalizedValue': key.toLowerCase(),
        'includeDescendants': false,
        'enabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // P0-13 (R-SCL-01): FCM Alt Kategori konusuna abone ol
      final cleanSub = key.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      try {
        await _messaging.subscribeToTopic('cat_$cleanSub');
      } catch (topicErr) {
        _log('⚠️ Alt kategori topic abonelik uyarısı: $topicErr');
      }
      _log('✅ Subcategory subscription added: $key');
    } catch (e) {
      _log('❌ Subcategory subscription add error: $e');
      rethrow;
    }
  }

  Future<void> unsubscribeFromSubCategory(String categoryId, String subCategoryId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final key = '$categoryId:$subCategoryId';
    final subId = _getSubscriptionId(userId, 'category', key);
    try {
      await _firestore.collection('notificationSubscriptions').doc(subId).delete();
      // P0-13 (R-SCL-01): FCM Alt Kategori konusundan çık
      final cleanSub = key.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      try {
        await _messaging.unsubscribeFromTopic('cat_$cleanSub');
      } catch (topicErr) {
        _log('⚠️ Alt kategori topic abonelikten çıkış uyarısı: $topicErr');
      }
      _log('✅ Subcategory subscription deleted: $key');
    } catch (e) {
      _log('❌ Subcategory subscription delete error: $e');
      rethrow;
    }
  }

  // --- Takip Edilen Kategorileri Getir ---
  Future<List<String>> getFollowedCategories() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];
    try {
      final snap = await _firestore
          .collection('notificationSubscriptions')
          .where('uid', isEqualTo: userId)
          .where('type', isEqualTo: 'category')
          .where('enabled', isEqualTo: true)
          .get();
      return snap.docs
          .map((doc) => doc.data()['key'] as String)
          .where((key) => !key.contains(':'))
          .toList();
    } catch (e) {
      _log('Error getting followed categories: $e');
      return [];
    }
  }

  Future<List<String>> getFollowedSubCategories() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];
    try {
      final snap = await _firestore
          .collection('notificationSubscriptions')
          .where('uid', isEqualTo: userId)
          .where('type', isEqualTo: 'category')
          .where('enabled', isEqualTo: true)
          .get();
      return snap.docs
          .map((doc) => doc.data()['key'] as String)
          .where((key) => key.contains(':'))
          .toList();
    } catch (e) {
      _log('Error getting followed subcategories: $e');
      return [];
    }
  }

  Future<bool> hasCategorySubscriptionsDoc() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    try {
      final snap = await _firestore
          .collection('notificationSubscriptions')
          .where('uid', isEqualTo: userId)
          .where('type', isEqualTo: 'category')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // --- FCM Token Kaydetme (Otomatik İyileştirme & Taze Token Garantisi) ---
  Future<void> saveFCMToken({String? userId, bool forceRefresh = false, int retryCount = 0}) async {
    // Eşzamanlı (paralel) birden fazla kaydetme çağrısını tek bir Future altında birleştir (Single-Flight Pattern)
    if (_inFlightTokenSave != null) {
      _log('⏳ saveFCMToken zaten işlemde, mevcut işlem bekleniyor...');
      await _inFlightTokenSave;
      return;
    }

    final completer = Completer<void>();
    _inFlightTokenSave = completer.future;

    try {
      if (forceRefresh && !kIsWeb) {
        try {
          await _messaging.deleteToken();
        } catch (_) {}
      }

      // iOS: APNs token hazır olmadan getToken çağrılırsa 'apns-token-not-set' fırlatır
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          String? apnsToken = await _messaging.getAPNSToken();
          int retry = 0;
          while (apnsToken == null && retry < 8) {
            _log('⏳ iOS: APNs token bekleniyor... (${retry + 1}/8)');
            await Future.delayed(const Duration(milliseconds: 1000));
            apnsToken = await _messaging.getAPNSToken();
            retry++;
          }
          if (apnsToken != null) {
            _log('✅ iOS: APNs token hazır: ${apnsToken.substring(0, min(10, apnsToken.length))}...');
          } else {
            _log('⚠️ iOS: APNs token henüz hazır değil (simülatör veya izin bekleniyor), devam ediliyor');
          }
        } catch (apnsErr) {
          _log('⚠️ iOS APNs token alma hatası: $apnsErr');
        }
      }

      String? token;
      try {
        token = await _messaging.getToken(vapidKey: kIsWeb ? null : null);
      } catch (tokenErr) {
        _log('⚠️ FCM getToken hatası: $tokenErr');
      }

      // Token boş geldiyse önbelleği silip tekrar almayı dene
      if (token == null && !kIsWeb) {
        try {
          await _messaging.deleteToken();
          token = await _messaging.getToken();
        } catch (_) {}
      }

      final resolvedUserId = userId ?? _auth.currentUser?.uid;

      if (token == null && resolvedUserId != null && retryCount < 2) {
        _log('⏳ FCM token henüz alınamadı (GMS bağlanıyor), 3 sn sonra tekrar denenecek... (${retryCount + 1}/2)');
        Future.delayed(const Duration(seconds: 3), () {
          saveFCMToken(userId: resolvedUserId, forceRefresh: forceRefresh, retryCount: retryCount + 1);
        });
      }
      
      if (token != null && resolvedUserId != null) {
        final prefs = await SharedPreferences.getInstance();
        final deviceId = await _getOrCreateDeviceId();
        final deviceIdDoc = '${resolvedUserId}_$deviceId';

        // FS-AUTH-04: Thundering Herd Kalkanı (Bellek + Kalıcı Disk Önbelleği)
        // 35.000 eşzamanlı push tıklamasında veya soğuk başlatmada disk kontrolüyle 0 Firestore çağrısı
        if (!forceRefresh) {
          // 1. RAM Önbellek kontrolü (Aynı oturum içi hızlı baypas)
          if (_lastRegisteredDocId == deviceIdDoc &&
              _lastRegisteredToken == token &&
              _lastDeviceTokenRegisterTime != null &&
              DateTime.now().difference(_lastDeviceTokenRegisterTime!) < _deviceTokenRegisterCooldown) {
            _ensureTokenRefreshListener(resolvedUserId, deviceId);
            _log('ℹ️ Cihaz token\'ı RAM önbelleğinde güncel, mükerrer Firestore kaydı atlandı: $deviceIdDoc');
            return;
          }

          // 2. Kalıcı Disk Önbellek kontrolü (Soğuk başlatma / push açılışı sonrası 24 saatlik kalkan)
          final diskDocId = prefs.getString(_prefFcmDocId);
          final diskToken = prefs.getString(_prefFcmToken);
          final diskTimestampMs = prefs.getInt(_prefFcmTimestamp);
          if (diskDocId == deviceIdDoc &&
              diskToken == token &&
              diskTimestampMs != null) {
            final diskTime = DateTime.fromMillisecondsSinceEpoch(diskTimestampMs);
            if (DateTime.now().difference(diskTime) < _deviceTokenRegisterDiskTTL) {
              _lastRegisteredDocId = deviceIdDoc;
              _lastRegisteredToken = token;
              _lastDeviceTokenRegisterTime = diskTime;
              _ensureTokenRefreshListener(resolvedUserId, deviceId);
              _log('ℹ️ Cihaz token\'ı disk önbelleğinde güncel (son 24 saat), Thundering Herd önlendi: $deviceIdDoc');
              // Aktif kelime konularını arka planda senkronize et
              resubscribeAllKeywordTopics().catchError((_) {});
              return;
            }
          }
        }
        
        final permissionStatus = await checkSystemPermissionStatus();
        final platform = kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

        // FS-AUTH-06: Sil-Yükle Tekilleştirmesi ve Maksimum 3 Cihaz Tavanı Budama (WriteBatch)
        final batch = _firestore.batch();

        try {
          final existingSnap = await _firestore
              .collection('userDevices')
              .where('uid', isEqualTo: resolvedUserId)
              .where('active', isEqualTo: true)
              .get();

          final otherActiveDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (final doc in existingSnap.docs) {
            if (doc.id == deviceIdDoc) continue;

            final data = doc.data();
            final docToken = data['fcmToken'] as String?;

            // A) Aynı FCM Token'ına sahip eski kayıt (Sil-Yükle sonucu oluşan zombi kayıt)
            if (docToken != null && docToken == token) {
              batch.update(doc.reference, {
                'active': false,
                'deactivatedReason': 'reinstalled_duplicate_token',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              _log('🧹 Sil-yükle mükerrer token kaydı budandı: ${doc.id}');
            } else {
              // B) Farklı cihaz (tablet, ikinci telefon vb.)
              otherActiveDocs.add(doc);
            }
          }

          // Maksimum 3 aktif cihaz kuralı: Mevcut cihaz (1) + diğer aktif cihazlar (maks 2) = 3
          // Eğer 2'den fazla aktif cihaz varsa en eskileri pasife çek
          const maxAllowedOtherDevices = _maxActiveDevicesPerUser - 1; // 2
          if (otherActiveDocs.length > maxAllowedOtherDevices) {
            // Tarihe göre sırala: En yeni ilk gelsin
            otherActiveDocs.sort((a, b) {
              final aTime = (a.data()['lastSeenAt'] as Timestamp?)?.toDate() ??
                  (a.data()['updatedAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = (b.data()['lastSeenAt'] as Timestamp?)?.toDate() ??
                  (b.data()['updatedAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

            // İlk maxAllowedOtherDevices (2) tanesini koru, geri kalanları buda
            for (var i = maxAllowedOtherDevices; i < otherActiveDocs.length; i++) {
              final pruneDoc = otherActiveDocs[i];
              batch.update(pruneDoc.reference, {
                'active': false,
                'deactivatedReason': 'device_limit_exceeded',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              _log('✂️ 3 cihaz tavanı aşıldı, eski cihaz budandı: ${pruneDoc.id}');
            }
          }
        } catch (e) {
          _log('⚠️ userDevices tarama / budama hatası (devam ediliyor): $e');
        }

        // Mevcut cihaz kaydını batch'e ekle
        final currentDeviceRef = _firestore.collection('userDevices').doc(deviceIdDoc);
        batch.set(currentDeviceRef, {
          'uid': resolvedUserId,
          'deviceId': deviceId,
          'platform': platform,
          'fcmToken': token,
          'permissionStatus': permissionStatus,
          'active': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Atomik commit: Tüm budamalar ve mevcut cihaz kaydı tek bir istekte tamamlanır
        await batch.commit();
        
        _lastRegisteredDocId = deviceIdDoc;
        _lastRegisteredToken = token;
        _lastDeviceTokenRegisterTime = DateTime.now();

        // FS-AUTH-04: Disk önbelleğini güncelle (24 saatlik kalıcı kalkan)
        try {
          await prefs.setString(_prefFcmDocId, deviceIdDoc);
          await prefs.setString(_prefFcmToken, token);
          await prefs.setInt(_prefFcmTimestamp, _lastDeviceTokenRegisterTime!.millisecondsSinceEpoch);
        } catch (prefErr) {
          _log('⚠️ FCM disk önbelleği yazma hatası (tolere edildi): $prefErr');
        }

        _log('✅ User device / FCM Token registered in userDevices: $deviceIdDoc');
        
        // FS-25: Aktif kelime konularını arka planda senkronize et
        resubscribeAllKeywordTopics().catchError((_) {});
        
        // Tekil token refresh dinleyicisini garantiye al
        _ensureTokenRefreshListener(resolvedUserId, deviceId);
      }
    } catch (e) {
      _log('❌ FCM Token kaydetme hatası: $e');
      if (!kIsWeb) rethrow;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _inFlightTokenSave = null;
    }
  }

  /// FCM token yenilendiğinde (onTokenRefresh) Firestore ve yerel önbellekleri senkronize eden güvenli dinleyici
  void _ensureTokenRefreshListener(String userId, String deviceId) {
    if (_tokenRefreshSub != null) return;
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      try {
        final currentUserId = _auth.currentUser?.uid ?? userId;
        final docId = '${currentUserId}_$deviceId';
        await _firestore.collection('userDevices').doc(docId).set({
          'fcmToken': newToken,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Bellek ve disk önbelleğini de derhal senkronize et
        _lastRegisteredDocId = docId;
        _lastRegisteredToken = newToken;
        _lastDeviceTokenRegisterTime = DateTime.now();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefFcmDocId, docId);
        await prefs.setString(_prefFcmToken, newToken);
        await prefs.setInt(_prefFcmTimestamp, _lastDeviceTokenRegisterTime!.millisecondsSinceEpoch);

        _log('✅ User device FCM Token refreshed & re-activated in Firestore & cache');
      } catch (e) {
        _log('⚠️ onTokenRefresh senkronizasyon hatası: $e');
      }
    });
  }

  /// iOS ve Android bildirim merkezini ve rozet sayısını temizle
  Future<void> clearBadgeAndNotifications() async {
    try {
      if (!kIsWeb) {
        await _localNotifications.cancelAll();
        _log('🧹 Bildirim merkezi ve rozetler temizlendi.');
      }
    } catch (e) {
      _log('⚠️ clearBadgeAndNotifications hatası: $e');
    }
  }
  
  // Admin bildirimlerine abone ol (Retry mekanizmalı)
  Future<void> subscribeToAdminTopic() async {
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      try {
        await _messaging.subscribeToTopic('admin_deals');
        _log('✅ Admin bildirimlerine (admin_deals) abone olundu (Deneme ${attempts + 1})');
        return; // Başarılı
      } catch (e) {
        attempts++;
        _log('❌ Admin abonelik hatası (Deneme $attempts/$maxAttempts): $e');
        if (attempts >= maxAttempts) break;
        await Future.delayed(Duration(seconds: 2 * attempts)); // Exponential backoff
      }
    }
    _log('❌ Admin aboneliği $maxAttempts denemeden sonra BAŞARISIZ oldu.');
  }

  /// Uygulama ön plana geldiğinde veya manuel çağrıldığında: kullanıcı admin ise
  /// admin_deals topic'ine abone ol. Böylece abonelik kaybı veya gecikme durumunda düzelir.
  Future<void> ensureAdminTopicSubscriptionIfAdmin({bool force = false}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Oturum içi mükerrer FCM topic aboneliği kontrolü
      if (!force && _isAdminTopicSubscribedInSession && _lastSubscribedAdminUid == userId) {
        return;
      }

      final isAdmin = await AuthService().isAdmin();
      if (isAdmin) {
        await subscribeToAdminTopic();
        _isAdminTopicSubscribedInSession = true;
        _lastSubscribedAdminUid = userId;
      }
    } catch (e) {
      _log('❌ ensureAdminTopicSubscriptionIfAdmin: $e');
    }
  }

  // Admin bildirimlerinden çık (normal kullanıcılar için)
  Future<void> unsubscribeFromAdminTopic() async {
    try {
      _isAdminTopicSubscribedInSession = false;
      _lastSubscribedAdminUid = null;
      await _messaging.unsubscribeFromTopic('admin_deals');
      _log('🚫 Admin bildirimlerinden (admin_deals) çıkıldı');
    } catch (e) {
      _log('❌ Admin abonelik çıkış hatası: $e');
    }
  }

  // Topluluk Kuponları bildirimlerine abone ol (Retry mekanizmalı - NOTIF-15)
  Future<void> subscribeToCommunityTopic() async {
    if (kIsWeb) return;
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      try {
        await _messaging.subscribeToTopic('community_coupons');
        _log('✅ Topluluk kuponu bildirimlerine (community_coupons) abone olundu (Deneme ${attempts + 1})');
        return;
      } catch (e) {
        attempts++;
        _log('❌ Topluluk kuponu abonelik hatası (Deneme $attempts/$maxAttempts): $e');
        if (attempts >= maxAttempts) break;
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
    _log('❌ Topluluk kuponu aboneliği $maxAttempts denemeden sonra BAŞARISIZ oldu.');
  }

  // Topluluk Kuponları bildirimlerinden çık
  Future<void> unsubscribeFromCommunityTopic() async {
    if (kIsWeb) return;
    try {
      await _messaging.unsubscribeFromTopic('community_coupons');
      _log('🚫 Topluluk kuponu bildirimlerinden (community_coupons) çıkıldı');
    } catch (e) {
      _log('❌ Topluluk kuponu abonelik çıkış hatası: $e');
    }
  }

  // FS-02: Genel Fırsat & Yönetici Duyuruları konusuna abone ol (sicak_firsatlar_general_v2)
  Future<void> subscribeToGeneralTopic() async {
    if (kIsWeb) return;
    int attempts = 0;
    const maxAttempts = 3;
    while (attempts < maxAttempts) {
      try {
        await _messaging.subscribeToTopic('sicak_firsatlar_general_v2');
        _log('✅ Genel bildirim konusuna (sicak_firsatlar_general_v2) abone olundu (Deneme ${attempts + 1})');
        return;
      } catch (e) {
        attempts++;
        _log('❌ Genel bildirim abonelik hatası (Deneme $attempts/$maxAttempts): $e');
        if (attempts >= maxAttempts) break;
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
  }

  // FS-02: Genel Fırsat & Yönetici Duyuruları konusundan çık
  Future<void> unsubscribeFromGeneralTopic() async {
    if (kIsWeb) return;
    try {
      await _messaging.unsubscribeFromTopic('sicak_firsatlar_general_v2');
      _log('🚫 Genel bildirim konusundan (sicak_firsatlar_general_v2) çıkıldı');
    } catch (e) {
      _log('❌ Genel bildirim abonelik çıkış hatası: $e');
    }
  }

  // FS-02: Pazarlama & Özel Kampanya duyuruları konusuna abone ol (firsatkolik_marketing_v1)
  Future<void> subscribeToMarketingTopic() async {
    if (kIsWeb) return;
    int attempts = 0;
    const maxAttempts = 3;
    while (attempts < maxAttempts) {
      try {
        await _messaging.subscribeToTopic('firsatkolik_marketing_v1');
        _log('✅ Pazarlama bildirim konusuna (firsatkolik_marketing_v1) abone olundu (Deneme ${attempts + 1})');
        return;
      } catch (e) {
        attempts++;
        _log('❌ Pazarlama bildirim abonelik hatası (Deneme $attempts/$maxAttempts): $e');
        if (attempts >= maxAttempts) break;
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
  }

  // FS-02: Pazarlama & Özel Kampanya duyuruları konusundan çık
  Future<void> unsubscribeFromMarketingTopic() async {
    if (kIsWeb) return;
    try {
      await _messaging.unsubscribeFromTopic('firsatkolik_marketing_v1');
      _log('🚫 Pazarlama bildirim konusundan (firsatkolik_marketing_v1) çıkıldı');
    } catch (e) {
      _log('❌ Pazarlama bildirim abonelik çıkış hatası: $e');
    }
  }

  /// Çıkış yapıldığında TÜM topic aboneliklerini temizle
  /// Bu fonksiyon signOut sırasında çağrılmalı
  // Yorum cevabı bildirim listener'ını durdur
  void _stopCommentReplyListener() {
    _commentReplyListener?.cancel();
    _commentReplyListener = null;
    _handledCommentNotificationIds.clear();
    _log('🛑 Yorum cevabı bildirim listener\'ı durduruldu');
  }

  // Yorum bildirimleri mükerrer önleme önbelleği (Firestore vs FCM çift bildirim engelleme)
  static final Set<String> _handledCommentNotificationIds = <String>{};

  static void _addHandledCommentNotificationId(String id) {
    if (id.isEmpty) return;
    if (_handledCommentNotificationIds.length > 200) {
      _handledCommentNotificationIds.remove(_handledCommentNotificationIds.first);
    }
    _handledCommentNotificationIds.add(id);
  }

  // FCM broadcast deduplication (EventChannel çift tetikleme ve ağ tekrarları koruması)
  static final Map<String, int> _recentlyProcessedFcmMessages = <String, int>{};

  static bool _isDuplicateFcmMessage(RemoteMessage message) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentlyProcessedFcmMessages.removeWhere((_, timestamp) => (now - timestamp) > 30000);

    final fcmId = message.messageId;
    final data = message.data;
    final customKey = (fcmId != null && fcmId.isNotEmpty)
        ? fcmId
        : '${data['notificationId'] ?? ''}_${data['dealId'] ?? ''}_${data['commentId'] ?? ''}_${data['messageId'] ?? ''}_${data['type'] ?? ''}_${message.sentTime?.millisecondsSinceEpoch ?? ''}';

    if (customKey.replaceAll('_', '').isEmpty) {
      return false;
    }

    if (_recentlyProcessedFcmMessages.containsKey(customKey)) {
      return true;
    }

    _recentlyProcessedFcmMessages[customKey] = now;
    return false;
  }

  // Gerçek zamanlı ön plan mesaj dinleyicisi (FCM ve APNs gecikmelerinden bağımsız 0ms in-app afiş garantisi)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _foregroundMessageListener;
  static final Set<String> _handledInAppMessageIds = <String>{};

  static void _addHandledMessageId(String id) {
    if (id.isEmpty) return;
    if (_handledInAppMessageIds.length > 200) {
      _handledInAppMessageIds.remove(_handledInAppMessageIds.first);
    }
    _handledInAppMessageIds.add(id);
  }

  void _stopForegroundMessageListener() {
    _foregroundMessageListener?.cancel();
    _foregroundMessageListener = null;
    _handledInAppMessageIds.clear();
    _log('🛑 Ön plan mesaj dinleyicisi durduruldu');
  }

  void _setupForegroundMessageListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _log('⚠️ Ön plan mesaj listener başlatılamadı: userId null');
      return;
    }

    _foregroundMessageListener?.cancel();
    _log('🔔 Gerçek zamanlı ön plan mesaj dinleyicisi başlatılıyor: userId=$userId');

    bool isFirst = true;

    _foregroundMessageListener = _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) async {
      if (isFirst) {
        isFirst = false;
        for (final doc in snapshot.docs) {
          _addHandledMessageId(doc.id);
        }
        _log('ℹ️ Ön plan mesaj ilk snapshot hafızaya alındı (${snapshot.docs.length} mesaj).');
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final messageId = doc.id;
          if (_handledInAppMessageIds.contains(messageId)) continue;
          _addHandledMessageId(messageId);

          final data = doc.data();
          if (data == null) continue;

          if (data['isRead'] == true) continue;
          final senderId = (data['senderId'] ?? '').toString().trim();
          if (senderId.isEmpty || senderId == userId) continue;

          final currentActiveChat = activeChatUserId?.trim();
          if (currentActiveChat != null && currentActiveChat.isNotEmpty) {
            final isSameUser = currentActiveChat.toLowerCase() == senderId.toLowerCase();
            final isAdminChat = (currentActiveChat == 'admin' || currentActiveChat == 'adminToUser') && senderId == 'admin';
            if (isSameUser || isAdminChat) {
              _log('💬 Kullanıcı zaten aktif sohbette ($currentActiveChat), ön plan afişi bastırıldı.');
              continue;
            }
          }

          try {
            final userDoc = await _firestore.collection('users').doc(userId).get();
            final muted = List<String>.from(userDoc.data()?['mutedConversations'] ?? []);
            if (muted.contains(senderId)) {
              _log('🔕 Sohbet sessize alınmış ($senderId), afiş bastırıldı.');
              continue;
            }
          } catch (_) {}

          final senderName = (data['senderName'] ?? (senderId == 'admin' ? 'FırsatKolik Yönetim' : 'Kullanıcı')).toString();
          final senderImageUrl = (data['senderImageUrl'] ?? (senderId == 'admin' ? 'assets/logo.webp' : '')).toString();
          final messageText = (data['text'] ?? data['content'] ?? 'Yeni bir mesaj aldınız.').toString();
          final dealTitle = data['dealTitle']?.toString();
          final dealId = data['dealId']?.toString();
          final isAdmin = senderId == 'admin';

          DateTime? messageCreatedAt;
          final rawTs = data['createdAt'];
          if (rawTs is Timestamp) {
            messageCreatedAt = rawTs.toDate();
          } else if (rawTs is String && rawTs.isNotEmpty) {
            messageCreatedAt = DateTime.tryParse(rawTs);
          }

          _log('💬 [Firestore Realtime] Ön plan mesaj afişi açılıyor: $senderName ($senderId)');
          InAppMessageBanner.show(
            context: null,
            senderId: senderId,
            senderName: senderName,
            senderImageUrl: senderImageUrl,
            messageText: messageText,
            messageId: messageId,
            messageCreatedAt: messageCreatedAt,
            isAdminMessage: isAdmin,
            dealTitle: dealTitle,
            dealId: dealId,
          );
        }
      }
    }, onError: (err) {
      final isPerm = err.toString().contains('permission-denied');
      if (isPerm && FirebaseAuth.instance.currentUser == null) {
        _log('ℹ️ Ön plan mesaj listener çıkış sırasında kapandı (beklenen)');
      } else {
        _log('⚠️ Ön plan mesaj listener hatası: $err');
        SystemLogService.instance.logError(
          category: 'stream_listener',
          errorType: 'ForegroundMessageListenerException',
          message: err.toString(),
          severity: SystemErrorSeverity.error,
        );
      }
    });
  }

  Future<void> clearAllSubscriptions() async {
    try {
      _log('🧹 Tüm bildirim abonelikleri temizleniyor...');
      
      // Yorum cevabı ve ön plan mesaj listener'larını durdur
      _stopCommentReplyListener();
      _stopForegroundMessageListener();
      
      // Admin topic'inden çık
      await _messaging.unsubscribeFromTopic('admin_deals');
      
      // Topluluk kuponu topic'inden çık
      await unsubscribeFromCommunityTopic();
      
      // FS-02: Genel ve Pazarlama topic'lerinden çık
      await unsubscribeFromGeneralTopic();
      await unsubscribeFromMarketingTopic();
      await _messaging.unsubscribeFromTopic('all_deals');
      
      // Kullanıcının takip ettiği kategorilerden çık
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          
          // Kategorilerden çık
          final categories = data?['followedCategories'] as List<dynamic>? ?? [];
          for (final category in categories) {
            try {
              await _messaging.unsubscribeFromTopic('category_$category');
            } catch (_) {}
          }
          
          // Alt kategorilerden çık
          final subCategories = data?['followedSubCategories'] as List<dynamic>? ?? [];
          for (final subCat in subCategories) {
            try {
              final parts = subCat.toString().split(':');
              if (parts.length == 2) {
                final sanitized = _sanitizeTopicName(parts[1]);
                await _messaging.unsubscribeFromTopic('subcategory_${parts[0]}_$sanitized');
              }
            } catch (_) {}
          }
        }
      }
      
      // Keyword listener'ı durdur
      _stopKeywordListener();
      
      // Admin fırsat listener'ı durdur
      _adminDealsListener?.cancel();
      _adminDealsListener = null;
      
      _log('✅ Tüm bildirim abonelikleri temizlendi');
    } catch (e) {
      _log('❌ Abonelik temizleme hatası: $e');
    }
  }

  Future<void> initializeForUser({String? userId, bool isAdmin = false}) async {
    _log('🔔 Bildirim servisi başlatılıyor... (userId: $userId, isAdmin: $isAdmin)');
    
    try {
      // Kanalları oluşturmak için her açılışta başlat
      await initializeLocalNotifications();

      // Önce FCM token'ı kaydet (bunu her seferinde yap ki güncel kalsın)
      await saveFCMToken(userId: userId);
      
      final generalEnabled = await getGeneralNotificationsEnabled();
      _log('📋 Genel bildirimler: ${generalEnabled ? "Açık" : "Kapalı"}');
      
      // Admin ise, genel bildirimler kapalı olsa bile admin bildirimlerini al
      if (isAdmin) {
        _log('👮 Admin kullanıcı tespit edildi - Admin bildirimleri aktifleştiriliyor...');
        
        // Admin için admin topic'ine KESINLIKLE abone ol
        await ensureAdminTopicSubscriptionIfAdmin();
        
        // Genel bildirim ayarını kontrol et
        await _setAllDealsSubscription(generalEnabled);
        
        // NOT: _setupAdminDealsListener() KALDIRILDI!
        // FCM topic (admin_deals) üzerinden Cloud Functions zaten bildirim gönderiyor.
        // Hem FCM hem Firestore listener açıkken ÇİFT BİLDİRİM sorunu oluşuyordu.
        // Artık sadece FCM bildirimleri kullanılıyor.
      } else {
        _log('👤 Normal kullanıcı - Admin bildirimleri devre dışı');
        
        // Normal kullanıcı - genel bildirim ayarına göre ayarla
        await _setAllDealsSubscription(generalEnabled);
        
        // Normal kullanıcı - admin bildirimlerinden kesinlikle çık
        await unsubscribeFromAdminTopic();
      }

      // Kullanıcının takip ettiği topic'lere yeniden abone ol
      await resubscribeToTopics();

      // Yorum cevabı bildirimlerini dinle
      _setupCommentReplyListener();

      // Gerçek zamanlı ön plan mesajlaşma bildirimlerini dinle (In-App Banner garantisi)
      _setupForegroundMessageListener();

      // Bildirim dinleyicilerini başlat (ön plan, arka plan, kapalı durumlar için)
      // Bunu sadece bir kez başlatmak yeterli olabilir ama idempotent (tekrarlanabilir) olmalı
      setupNotificationListeners();

      _log('✅ Bildirim servisi başarıyla başlatıldı ve yapılandırıldı.');
    } catch (e) {
      _log('❌ Bildirim servisi başlatılırken hata oluştu: $e');
      // Kritik bir hata ise, belki daha sonra tekrar denenebilir
    }
  }

  // Onay bekleyen fırsatları dinle (Admin için - Bot & Kullanıcı Hepsi)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _adminDealsListener;

  void setupAdminDealsListener() {
    // Sadece admin çağırmalı (üst blokta kontrol ediliyor ama double-check)
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _adminDealsListener?.cancel();
    _log('🔔 Admin fırsat listener başlatılıyor (Bot & Kullanıcı dahili)...');

    // Onay bekleyen (isApproved: false) VE süresi bitmemiş (isExpired: false)
    // Bot veya Kullanıcı olması farketmez, hepsini getir.
    _adminDealsListener = _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      
      for (final doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data == null) continue;

          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt == null) continue;

          // Sadece yeni eklenenleri (son 10 dk) bildir
          final createdDate = createdAt.toDate();
          final now = DateTime.now();
          final difference = now.difference(createdDate).inMinutes;

          if (difference <= 10) {
            final title = data['title'] ?? 'Yeni Fırsat';
            final isUserSubmitted = data['isUserSubmitted'] == true;
            final source = isUserSubmitted ? 'Kullanıcı' : '🤖 Bot';

            _showAdminDealNotification(
              dealId: doc.doc.id,
              title: 'Onay Bekleyen Fırsat',
              body: '$source yeni bir fırsat yakaladı: $title',
            );
          }
        }
      }
    }, onError: (e) {
      _log('❌ Admin fırsat listener hatası: $e');
    });
  }

  // Admin için basit bildirim göster
  Future<void> _showAdminDealNotification({
    required String dealId,
    required String title,
    required String body,
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch % 100000;
      
      const androidDetails = AndroidNotificationDetails(
        'admin_channel', 
        'Admin Bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
      );

      await _localNotifications.show(
        id,
        '👮‍♂️ $title',
        body,
        const NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'admin_deal:$dealId',
      );
      _log('✅ Admin bildirimi gösterildi: $dealId');
    } catch (e) {
      _log('❌ Admin bildirim hatası: $e');
    }
  }

  // Yorum cevabı bildirimlerini dinle (Firestore üzerinden)
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentReplyListener;
  
  void _setupCommentReplyListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _log('⚠️ Yorum cevabı listener başlatılamadı: userId null');
      return;
    }

    _commentReplyListener?.cancel();
    
    _log('🔔 Yorum cevabı bildirim listener\'ı başlatılıyor: userId=$userId');
    
    bool isFirst = true;
    
    _commentReplyListener = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', whereIn: ['comment_reply', 'comment'])
        .where('read', isEqualTo: false)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) async {
        _log('📬 Yorum/cevap bildirim listener tetiklendi: ${snapshot.docChanges.length} (Değişiklik) (isFirst: $isFirst)');
        
        if (isFirst) {
          isFirst = false;
          _log('ℹ️ Yorum/cevap ilk snapshot es geçildi, bildirim tetiklenmeyecek.');
          return;
        }
        
        // Yorum bildirimleri ayarını kontrol et
        final commentNotificationsEnabled = await getCommentReplyNotificationsEnabled(userId);
        
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            try {
              final doc = change.doc;
              final data = doc.data();
              if (data == null) continue;
              
              final notifType = data['type'] as String? ?? 'comment_reply';
              final dealId = data['dealId'] as String? ?? '';
              final commentId = data['commentId'] as String? ?? '';
              final replyUserName = (data['replyUserName'] ?? data['commentUserName'] ?? 'Bir kullanıcı').toString();
              final replyText = (data['replyText'] ?? data['body'] ?? '').toString();
              final dealTitle = data['dealTitle'] as String? ?? 'Fırsat';
              final isRootComment = notifType == 'comment';
              final notifTitle = isRootComment
                  ? '$replyUserName fırsatınıza yorum yaptı'
                  : '$replyUserName yorumunuza cevap verdi';

              // 1. Kendi ekranı spam koruması (Kullanıcı zaten ilgili fırsatın detayındaysa bastır)
              if (activeDealId != null && activeDealId!.isNotEmpty && dealId.isNotEmpty && activeDealId == dealId) {
                _log('🛡️ Kullanıcı zaten bu fırsatın detay sayfasında ($dealId), Firestore yorum bildirimi bastırıldı.');
                continue;
              }

              // 2. Mükerrer / Çift bildirim kontrolü (FCM vs Firestore Deduplication)
              final notifDedupKey = '${doc.id}_${dealId}_$commentId';
              if (_handledCommentNotificationIds.contains(notifDedupKey) ||
                  (commentId.isNotEmpty && _handledCommentNotificationIds.contains(commentId)) ||
                  (doc.id.isNotEmpty && _handledCommentNotificationIds.contains(doc.id))) {
                _log('ℹ️ Yorum bildirimi zaten gösterildi (Firestore listener atlanıyor): $notifDedupKey');
                continue;
              }
              _addHandledCommentNotificationId(notifDedupKey);
              if (commentId.isNotEmpty) _addHandledCommentNotificationId(commentId);
              if (doc.id.isNotEmpty) _addHandledCommentNotificationId(doc.id);
              
              _log('📨 Yorum bildirimi işleniyor: type=$notifType, dealId=$dealId, commentId=$commentId, user=$replyUserName');
              
              // Yorum bildirimleri açıksa telefon bildirimi göster
              if (commentNotificationsEnabled) {
                // Local bildirim göster
                await _showCommentReplyLocalNotification(
                  dealId: dealId,
                  commentId: commentId,
                  replyUserName: replyUserName,
                  replyText: replyText,
                  dealTitle: dealTitle,
                  customTitle: notifTitle,
                );
                _log('✅ Yorum telefon bildirimi gösterildi: $notifTitle');
              } else {
                _log('🚫 Yorum bildirimleri kapalı, telefon bildirimi gösterilmedi (sadece profilde görünecek)');
              }
              
              // NOT: Okundu işaretleme işlemi artık burada otomatik yapılmamaktadır.
              // Kullanıcı bildirimler sayfasında tıklayınca/görünce okundu yapılacaktır.
            } catch (e) {
              _log('❌ Bildirim işleme hatası: $e');
            }
          }
        }
      },
      onError: (error) {
        final isPerm = error.toString().contains('permission-denied');
        if (isPerm && FirebaseAuth.instance.currentUser == null) {
          _log('ℹ️ Yorum cevabı bildirim listener çıkış sırasında kapandı (beklenen)');
        } else {
          _log('❌ Yorum cevabı bildirim listener hatası: $error');
          SystemLogService.instance.logError(
            category: 'stream_listener',
            errorType: 'CommentReplyListenerException',
            message: error.toString(),
            severity: SystemErrorSeverity.error,
          );
        }
      },
    );
    
    _log('✅ Yorum cevabı bildirim listener\'ı başlatıldı: userId=$userId');
  }
  
  // Yorum cevabı için local bildirim göster
  Future<void> _showCommentReplyLocalNotification({
    required String dealId,
    required String commentId,
    required String replyUserName,
    required String replyText,
    required String dealTitle,
    String? customTitle,
  }) async {
    if (kIsWeb) return;
    
    final androidDetails = AndroidNotificationDetails(
      'comment_replies_channel',
      'Yorum Cevapları',
      channelDescription: 'Yorumlarınıza gelen cevaplar için bildirimler',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      channelShowBadge: true,
      enableLights: true,
      color: const Color(0xFF2196F3),
      ledColor: const Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Payload: dealId ve commentId
    final payload = 'comment_reply:$dealId:$commentId';

    await _localNotifications.show(
      commentId.hashCode,
      customTitle ?? '$replyUserName yorumunuza cevap verdi',
      replyText,
      details,
      payload: payload,
    );

    _log('📬 Yorum cevabı bildirimi gösterildi: $replyUserName');
  }

  /// Keyword listener'ı durdur
  void _stopKeywordListener() {
    _keywordListener?.cancel();
    _keywordListener = null;
    _keywordListenerAttached = false;
    _notifiedDealIds.clear();
    _log('🛑 Keyword listener durduruldu');
  }

  Future<void> checkKeywordsAndNotify(String dealId, String title, String description) async {
    // Sadece tetikleyici.
    // İlerde gerekirse buraya manuel tetiklemeler eklenebilir.
    _log('KeywordCheck çağrıldı: $title');
  }

  Future<void> startKeywordListener() async {
    if (_keywordListenerAttached) return;
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final keywords = await getNotificationKeywords();
    if (keywords.isEmpty) {
      _log('ℹ️ Anahtar kelime yok, dinleyici başlatılmadı');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    int lastCheckMs = prefs.getInt('keyword_last_check_ms') ?? 0;

    _keywordListenerAttached = true;
    
    bool isFirst = true;
    
    _keywordListener = _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) async {
      _log('📬 Anahtar kelime listener tetiklendi: ${snapshot.docs.length} (isFirst: $isFirst)');
      
      // Kelime bildirimi ayarı kapalı ise hiçbir şey yapma
      final enabled = await getKeywordNotificationsEnabled(userId);
      if (!enabled) {
        _log('🎯 Kelime bildirimi kapalı, kontrol atlanıyor.');
        return;
      }
      
      int latestMs = lastCheckMs;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final title = (data['title'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final ownerId = (data['userId'] ?? '').toString();

        // createdAt kontrolü
        int createdMs = 0;
        if (createdAt is Timestamp) {
          createdMs = createdAt.millisecondsSinceEpoch;
        }
        latestMs = createdMs > latestMs ? createdMs : latestMs;
        if (createdMs != 0 && createdMs <= lastCheckMs) continue;

        // Aynı deal için bir kere gönder
        if (_notifiedDealIds.contains(doc.id)) continue;

        final searchText = '${title.toLowerCase()} ${description.toLowerCase()}';
        final matched = keywords.firstWhere(
          (kw) => searchText.contains(kw.toLowerCase()),
          orElse: () => '',
        );

        if (matched.isEmpty) continue;
        if (ownerId.isNotEmpty && ownerId == userId) continue; // kendi ilanı

        if (!isFirst) {
          await _showKeywordNotification(
            title: '🎯 İlginizi Çeken Bir Fırsat Bulundu!',
            body: '"$matched" kelimesi içeren yeni bir fırsat paylaşıldı. Hemen inceleyin!',
            payload: doc.id,
          );
          _notifiedDealIds.add(doc.id);
          _log('✅ Anahtar kelime bildirimi (client dinleyici): ${doc.id} / $matched');
        } else {
          // İlk snapshot'takileri sessizce işaretle
          _notifiedDealIds.add(doc.id);
        }
      }

      if (latestMs > lastCheckMs) {
        lastCheckMs = latestMs;
        await prefs.setInt('keyword_last_check_ms', latestMs);
      }
      
      if (isFirst) {
        isFirst = false;
        _log('ℹ️ Anahtar kelime ilk snapshot es geçildi, son kontrol zamanı güncellendi.');
      }
    }, onError: (err) {
      _log('❌ Anahtar kelime dinleyici hatası: $err');
    });
  }
  
  // Kullanıcının tercihlerine göre FCM Topic senkronizasyonunu yap (FS-02)
  Future<void> resubscribeToTopics() async {
    if (kIsWeb) return;
    try {
      final prefs = await getNotificationPreferences();
      
      // 1. Genel Fırsat & Yönetici Duyuruları (sicak_firsatlar_general_v2)
      final shouldSubscribeGeneral = prefs.pushMasterEnabled && prefs.dealNotificationsEnabled;
      if (shouldSubscribeGeneral) {
        await subscribeToGeneralTopic();
      } else {
        await unsubscribeFromGeneralTopic();
      }

      // 2. Pazarlama & Özel Kampanyalar (firsatkolik_marketing_v1)
      final shouldSubscribeMarketing = prefs.pushMasterEnabled && prefs.marketingNotificationsEnabled;
      if (shouldSubscribeMarketing) {
        await subscribeToMarketingTopic();
      } else {
        await unsubscribeFromMarketingTopic();
      }

      // 3. Topluluk Kuponları (community_coupons)
      final shouldSubscribeCommunity = prefs.pushMasterEnabled && prefs.communityNotificationsEnabled;
      if (shouldSubscribeCommunity) {
        await subscribeToCommunityTopic();
      } else {
        await unsubscribeFromCommunityTopic();
      }

      // 4. FS-25: Anahtar Kelime Radarı Dinamik Konuları (kw_<keyword>)
      try {
        final keywords = await getNotificationKeywords();
        for (final kw in keywords) {
          final cleanKw = _sanitizeKeywordForTopic(kw);
          if (cleanKw.isNotEmpty) {
            await _messaging.subscribeToTopic('kw_$cleanKw').catchError((_) {});
          }
        }
      } catch (kwErr) {
        _log('⚠️ Keyword topics resubscribe error: $kwErr');
      }
    } catch (e) {
      _log('❌ resubscribeToTopics hatası: $e');
    }
  }





  static Map<String, dynamic>? _pendingNotificationTapData;
  static Timer? _pendingTimer;
  static DateTime? _lastHandledTapTime;
  static String? _lastHandledTapKey;

  /// Bildirim yönlendirme kararını çözen saf (pure) ve test edilebilir resolver
  static NotificationRoutingDecision resolveRouting(Map<String, dynamic> data) {
    final rawType = (data['type'] ?? 'deal').toString().trim().toLowerCase();
    final reason = (data['reason'] ?? data['channel'] ?? '').toString().trim().toLowerCase();

    final dealId = (
      data['dealId'] ??
      data['deal_id'] ??
      data['targetDealId'] ??
      data['target_deal_id'] ??
      ''
    ).toString().trim();

    final kuponId = (
      data['kuponId'] ??
      data['kupon_id'] ??
      data['couponId'] ??
      data['coupon_id'] ??
      data['targetKuponId'] ??
      data['target_kupon_id'] ??
      ''
    ).toString().trim();

    final commentId = (
      data['commentId'] ??
      data['comment_id'] ??
      data['targetCommentId'] ??
      ''
    ).toString().trim();

    final category = (data['category'] ?? (data['aps'] is Map ? data['aps']['category'] : '') ?? '').toString().trim().toUpperCase();
    final isDirectMessage = rawType == 'message' || rawType == 'user_message' || rawType == 'chat' || category == 'USER_MESSAGE';

    // Mesajlaşma Gönderici ID'si:
    // SADECE açıkça mesaj tiplerinde (message, user_message, chat) userId fallback'i kullanılır.
    // Fırsat veya kelime bildirimlerindeki hedef/sahip userId alanı asla sohbet göndericisi sanılmamalıdır.
    String senderId = (
      data['senderId'] ??
      data['sender_id'] ??
      data['senderUid'] ??
      data['sender_uid'] ??
      data['fromUserId'] ??
      data['from_user_id'] ??
      ''
    ).toString().trim();

    if (senderId.isEmpty && isDirectMessage) {
      senderId = (data['userId'] ?? data['user_id'] ?? '').toString().trim();
    }

    final senderName = (
      data['senderName'] ??
      data['sender_name'] ??
      data['notification_title'] ??
      (data['aps'] is Map && data['aps']['alert'] is Map ? data['aps']['alert']['title'] : null) ??
      'Kullanıcı'
    ).toString().replaceAll('💬 ', '').trim();

    // 1. Yönetici Mesajı / Duyurusu
    if (rawType == 'admin_message') {
      return const NotificationRoutingDecision(destination: NotificationDestinationType.adminChat);
    }

    // 2. Yönetici Bildirim Merkezi
    if (rawType == 'admin_notifications') {
      final tabStr = (data['initialTab'] ?? data['tab'] ?? '').toString().trim().toLowerCase();
      final tabIdx = tabStr == 'admin' ? 1 : (tabStr == 'replies' ? 2 : 0);
      final notifId = (data['notificationId'] ?? data['notification_id'] ?? data['id'] ?? '').toString().trim();
      return NotificationRoutingDecision(
        destination: NotificationDestinationType.adminNotifications,
        dealId: dealId.isNotEmpty ? dealId : null,
        notificationId: notifId.isNotEmpty ? notifId : null,
        initialTabIndex: tabIdx,
      );
    }

    // 2.1 Kullanıcı Fırsat/Kupon Gönderim Durumu (submission_status)
    if (rawType == 'submission_status') {
      final rawStatus = (data['status'] ?? '').toString().trim().toLowerCase();
      final titleLower = (data['notification_title'] ?? data['title'] ?? '').toString().toLowerCase();
      final bodyLower = (data['notification_body'] ?? data['body'] ?? '').toString().toLowerCase();
      final isAppr = rawStatus == 'approved' ||
          (rawStatus.isEmpty && (titleLower.contains('onaylandı') || titleLower.contains('onaylandi') || bodyLower.contains('onaylandı') || bodyLower.contains('onaylandi')));
      final notifId = (data['notificationId'] ?? data['notification_id'] ?? data['id'] ?? '').toString().trim();

      if (isAppr) {
        if (dealId.isNotEmpty) {
          return NotificationRoutingDecision(
            destination: NotificationDestinationType.deal,
            dealId: dealId,
            notificationId: notifId.isNotEmpty ? notifId : null,
          );
        }
        if (kuponId.isNotEmpty) {
          return NotificationRoutingDecision(
            destination: NotificationDestinationType.coupons,
            kuponId: kuponId,
            initialTabIndex: 1, // 'Topluluk Kuponları' sekmesi
            notificationId: notifId.isNotEmpty ? notifId : null,
          );
        }
      }
      return NotificationRoutingDecision(
        destination: NotificationDestinationType.adminNotifications,
        dealId: dealId.isNotEmpty ? dealId : null,
        kuponId: kuponId.isNotEmpty ? kuponId : null,
        notificationId: notifId.isNotEmpty ? notifId : null,
        initialTabIndex: 1, // 'Admin' sekmesi
      );
    }

    // 3. Onay Bekleyen Fırsat (Admin)
    if (rawType == 'admin_deal') {
      return NotificationRoutingDecision(
        destination: NotificationDestinationType.adminScreen,
        dealId: dealId.isNotEmpty ? dealId : null,
        initialTabIndex: 0,
      );
    }

    // 3.1 Onay Bekleyen Kupon (Admin - FS-02)
    if (rawType == 'admin_coupon') {
      return NotificationRoutingDecision(
        destination: NotificationDestinationType.adminScreen,
        kuponId: kuponId.isNotEmpty ? kuponId : null,
        initialTabIndex: 2, // AdminScreen '🎟️ Kupon Onay' sekmesi
      );
    }

    // 4. Birebir Sohbet / Kullanıcı Mesajı
    if (isDirectMessage) {
      if (senderId.isNotEmpty) {
        return NotificationRoutingDecision(
          destination: NotificationDestinationType.chat,
          senderId: senderId,
          senderName: senderName,
          dealId: dealId.isNotEmpty ? dealId : null,
        );
      } else {
        return const NotificationRoutingDecision(destination: NotificationDestinationType.messagesList);
      }
    }

    // 5. Yorum veya Yoruma Cevap Bildirimi
    if (rawType == 'comment' || rawType == 'comment_reply') {
      if (dealId.isNotEmpty) {
        return NotificationRoutingDecision(
          destination: NotificationDestinationType.deal,
          dealId: dealId,
          commentId: commentId.isNotEmpty ? commentId : null,
        );
      }
      return const NotificationRoutingDecision(destination: NotificationDestinationType.none);
    }

    // 5.1. Topluluk Kuponu Bildirimi (NOTIF-15)
    if (rawType == 'coupon' || rawType == 'community_coupon') {
      return NotificationRoutingDecision(
        destination: NotificationDestinationType.coupons,
        kuponId: kuponId.isNotEmpty ? kuponId : null,
        initialTabIndex: 1, // Her zaman 'Topluluk Kuponları' sekmesi
      );
    }

    // 6. Fırsat Odaklı Tüm Bildirimler (Kelime Takibi, Yazar/Bot Takibi, Kategori, Fırsat, Pazarlama)
    // dealId içeren TÜM bildirimler öncelikli olarak doğrudan ilgili fırsat detayına yönlendirilir!
    if (dealId.isNotEmpty || rawType == 'deal' || rawType == 'keyword' || rawType == 'author' || rawType == 'follow' || reason == 'keyword' || reason == 'author' || reason == 'category') {
      if (dealId.isNotEmpty) {
        return NotificationRoutingDecision(
          destination: NotificationDestinationType.deal,
          dealId: dealId,
          commentId: commentId.isNotEmpty ? commentId : null,
        );
      }
    }

    // 7. Fırsat ID'si içermeyen pazarlama veya genel duyuru bildirimi
    return const NotificationRoutingDecision(destination: NotificationDestinationType.none);
  }

  void _startPendingNotificationCheck(Map<String, dynamic> data) {
    final decision = resolveRouting(data);
    final rawType = (data['type'] ?? 'deal').toString().trim().toLowerCase();
    final messageId = (data['messageId'] ?? data['message_id'] ?? '').toString().trim();
    final tapKey = '$rawType:${decision.senderId ?? ""}:${decision.dealId ?? ""}:${decision.commentId ?? ""}:$messageId';

    // Eğer aynı bildirim son 2.5 saniyede zaten işlendiyse sıraya tekrar ekleme
    if (_lastHandledTapKey == tapKey && _lastHandledTapTime != null) {
      if (DateTime.now().difference(_lastHandledTapTime!).inMilliseconds < 2500) {
        _log('⚠️ Mükerrer bildirim sıraya alma engellendi: $tapKey');
        return;
      }
    }

    _pendingNotificationTapData = data;
    _pendingTimer?.cancel();
    int attempts = 0;

    void tryNavigate() {
      final navigator = navigatorKey.currentState;
      final currentUser = _auth.currentUser;
      final isAuthRequired = decision.destination == NotificationDestinationType.chat ||
          decision.destination == NotificationDestinationType.messagesList;

      final isReady = navigator != null && (!isAuthRequired || currentUser != null);

      if (isReady) {
        _pendingTimer?.cancel();
        _pendingTimer = null;
        if (_pendingNotificationTapData != null) {
          final pendingData = _pendingNotificationTapData!;
          _pendingNotificationTapData = null;
          _log('🚀 Navigator ve Oturum aktifleşti, bekleyen bildirim açılıyor: $pendingData');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNotificationTap(pendingData, isFromPending: true);
          });
        }
      }
    }

    // 1. Anında kontrol (Eğer Navigator ve Auth hemen şimdi hazırsa bekleme)
    tryNavigate();
    if (_pendingNotificationTapData == null) return;

    // 2. Periyodik kontrol (Oturumun Keychain'den yüklenmesini veya Navigator'ı bekle)
    _pendingTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      attempts++;
      tryNavigate();
      if (_pendingNotificationTapData == null || attempts > 75) {
        timer.cancel();
        _pendingTimer = null;
        _pendingNotificationTapData = null;
      }
    });
  }

  void _handlePayloadString(String payload) {
    if (payload.isEmpty) return;

    // JSON formatında payload kontrolü (örn: {"type":"deal","dealId":"xyz"} veya {"dealId":"xyz"})
    if (payload.trim().startsWith('{') && payload.trim().endsWith('}')) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          _handleNotificationTap(decoded);
          return;
        }
      } catch (e) {
        _log('⚠️ Payload JSON ayrıştırma hatası, fallback formatlara geçiliyor: $e');
      }
    }

    if (payload.startsWith('{') && payload.endsWith('}')) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          _handleNotificationTap(decoded);
          return;
        }
      } catch (_) {}
    }

    if (payload.startsWith('admin_message:') || payload == 'admin_message') {
      _handleNotificationTap({'type': 'admin_message'});
    } else if (payload.startsWith('admin_deal:')) {
      final dealId = payload.substring('admin_deal:'.length);
      _handleNotificationTap({'type': 'admin_deal', 'dealId': dealId});
    } else if (payload.startsWith('admin_coupon:')) {
      final kuponId = payload.substring('admin_coupon:'.length);
      _handleNotificationTap({'type': 'admin_coupon', 'kuponId': kuponId});
    } else if (payload.startsWith('submission_status:')) {
      final parts = payload.split(':');
      final dealId = parts.length > 1 ? parts[1] : '';
      final status = parts.length > 2 ? parts[2] : '';
      _handleNotificationTap({'type': 'submission_status', 'dealId': dealId, 'status': status});
    } else if (payload.startsWith('submission_status_coupon:')) {
      final parts = payload.split(':');
      final kuponId = parts.length > 1 ? parts[1] : '';
      final status = parts.length > 2 ? parts[2] : '';
      _handleNotificationTap({'type': 'submission_status', 'kuponId': kuponId, 'status': status});
    } else if (payload.startsWith('comment_reply:') || payload.startsWith('comment:')) {
      final parts = payload.split(':');
      final dealId = parts.length > 1 ? parts[1] : '';
      final commentId = parts.length > 2 ? parts[2] : '';
      _handleNotificationTap({'type': 'comment_reply', 'dealId': dealId, 'commentId': commentId});
    } else if (payload.startsWith('message:')) {
      final parts = payload.split(':');
      final senderId = parts.length > 1 ? parts[1] : '';
      final senderName = parts.length > 2 ? parts[2] : 'Kullanıcı';
      String messageId = '';
      String messageText = '';
      if (parts.length > 4 && parts[3].length >= 15 && !parts[3].contains(' ')) {
        messageId = parts[3];
        messageText = parts.sublist(4).join(':');
      } else {
        messageText = parts.length > 3 ? parts.sublist(3).join(':') : '';
      }
      _handleNotificationTap({
        'type': 'message',
        'senderId': senderId,
        'senderName': senderName,
        'messageId': messageId.isNotEmpty ? messageId : null,
        'messageText': messageText,
      });
    } else if (payload.startsWith('coupon:')) {
      final kuponId = payload.substring('coupon:'.length);
      _handleNotificationTap({'type': 'coupon', 'kuponId': kuponId});
    } else {
      _handleNotificationTap({'type': 'deal', 'dealId': payload});
    }
  }

  void handleNotificationTapPublic(Map<String, dynamic> data) {
    _handleNotificationTap(data);
  }

  // Bildirime tıklandığında yönlendirme yap
  void _handleNotificationTap(Map<String, dynamic> data, {bool isFromPending = false}) {
    final rawType = (data['type'] ?? 'deal').toString().trim().toLowerCase();
    final reason = (data['reason'] ?? data['channel'] ?? '').toString().trim().toLowerCase();
    _log('🔔 Bildirim yönlendirmesi işleniyor: type=$rawType, reason=$reason, isFromPending=$isFromPending, data=$data');

    final decision = resolveRouting(data);

    // Observability: Bildirim etkileşim telemetrisi
    AnalyticsService.instance.logNotificationInteraction(
      type: rawType,
      reason: reason.isNotEmpty ? reason : 'push',
      dealId: decision.dealId,
    );

    final messageId = (data['messageId'] ?? data['message_id'] ?? '').toString().trim();
    final tapKey = '$rawType:${decision.senderId ?? ""}:${decision.dealId ?? ""}:${decision.commentId ?? ""}:$messageId';
    final now = DateTime.now();

    // 2.5 saniye içinde aynı bildirim tıklaması geldiyse es geç (Sadece direkt kullanıcı tıklamaları için; kuyruktan gelenler engellenmez)
    if (!isFromPending && _lastHandledTapKey == tapKey && _lastHandledTapTime != null) {
      if (now.difference(_lastHandledTapTime!).inMilliseconds < 2500) {
        _log('⚠️ Mükerrer bildirim tıklaması engellendi: $tapKey');
        return;
      }
    }

    final navigator = navigatorKey.currentState;
    final currentUser = _auth.currentUser;
    final isAuthRequired = decision.destination == NotificationDestinationType.chat ||
        decision.destination == NotificationDestinationType.messagesList;

    if (navigator == null || (isAuthRequired && currentUser == null)) {
      _log('⏳ Navigator veya Oturum henüz hazır değil (${navigator == null ? "Navigator yok" : "Oturum bekleniyor"}), bildirim tıklaması sıraya alındı: $data');
      _startPendingNotificationCheck(data);
      return;
    }

    // Yönlendirme şimdi icra edilecek -> duplicate damgasını güncelle
    _lastHandledTapKey = tapKey;
    _lastHandledTapTime = now;
    _pendingNotificationTapData = null;
    _pendingTimer?.cancel();

    switch (decision.destination) {
      case NotificationDestinationType.adminChat:
        _navigateToAdminChat();
        break;

      case NotificationDestinationType.adminNotifications:
        _navigateToAdminNotifications(
          initialTab: decision.initialTabIndex == 1 ? 'admin' : (decision.initialTabIndex == 2 ? 'replies' : 'all'),
          highlightNotificationId: decision.notificationId,
          highlightDealId: decision.dealId,
          highlightKuponId: decision.kuponId,
        );
        break;

      case NotificationDestinationType.adminScreen:
        _navigateToAdminScreen(
          dealId: decision.dealId,
          kuponId: decision.kuponId,
          tabIndex: decision.initialTabIndex,
        );
        break;

      case NotificationDestinationType.chat:
        final sId = decision.senderId ?? '';
        final sName = decision.senderName ?? 'Kullanıcı';
        final resolvedName = sName.isNotEmpty
            ? sName
            : (sId == 'admin'
                ? 'FırsatKolik Yönetim'
                : (sId == 'botkolik' ? 'Botkolik' : 'Kullanıcı'));
        final resolvedImage = (sId == 'admin'
            ? 'assets/logo.webp'
            : (sId == 'botkolik' ? 'assets/botkolik.webp' : null));

        final messageText = (
          data['messageText'] ??
          data['message_text'] ??
          data['notification_body'] ??
          data['body'] ??
          (data['aps'] is Map && data['aps']['alert'] is Map ? data['aps']['alert']['body'] : null) ??
          ''
        ).toString().trim();

        DateTime? messageCreatedAt;
        final rawCreatedAt = data['createdAt'] ?? data['created_at'] ?? data['timestamp'];
        if (rawCreatedAt != null) {
          if (rawCreatedAt is int) {
            messageCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
          } else if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
            messageCreatedAt = DateTime.tryParse(rawCreatedAt);
          }
        }

        final dealTitle = (data['dealTitle'] ?? data['deal_title'] ?? '').toString().trim();
        final dealImageUrl = (data['dealImageUrl'] ?? data['deal_image_url'] ?? '').toString().trim();
        final dealPrice = (data['dealPrice'] ?? data['deal_price'] ?? '').toString().trim();
        final dealStore = (data['dealStore'] ?? data['deal_store'] ?? '').toString().trim();

        _navigateToChat(
          sId,
          resolvedName,
          userImageUrl: resolvedImage,
          messageText: messageText.isNotEmpty ? messageText : null,
          messageId: messageId.isNotEmpty ? messageId : null,
          messageCreatedAt: messageCreatedAt,
          dealId: decision.dealId,
          dealTitle: dealTitle.isNotEmpty ? dealTitle : null,
          dealImageUrl: dealImageUrl.isNotEmpty ? dealImageUrl : null,
          dealPrice: dealPrice.isNotEmpty ? dealPrice : null,
          dealStore: dealStore.isNotEmpty ? dealStore : null,
        );
        break;

      case NotificationDestinationType.messagesList:
        _navigateToMessagesList();
        break;

      case NotificationDestinationType.deal:
        if (decision.dealId != null && decision.dealId!.isNotEmpty) {
          _navigateToDeal(decision.dealId!, commentId: decision.commentId);
        }
        break;

      case NotificationDestinationType.coupons:
        _navigateToCoupons(
          initialTabIndex: decision.initialTabIndex,
          kuponId: decision.kuponId,
        );
        break;

      case NotificationDestinationType.none:
        _log('ℹ️ Yönlendirme gerektirmeyen bildirim: $data');
        break;
    }
  }

  // Kuponlar sayfasına yönlendirme (Topluluk Kuponları sekmesi)
  void _navigateToCoupons({int initialTabIndex = 1, String? kuponId}) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Kuponlar sayfasına yönlendiriliyor (tab: $initialTabIndex, kuponId: $kuponId)');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => KuponlarPage(
            initialTabIndex: initialTabIndex,
            highlightKuponId: kuponId,
          ),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, kupon yönlendirmesi sıraya alınıyor');
      _startPendingNotificationCheck({
        'type': 'coupon',
        'kuponId': kuponId ?? '',
      });
    }
  }

  // Mesajlar listesi (Gelen Kutusu) sayfasına yönlendirme
  void _navigateToMessagesList() {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Mesajlar listesi ekranına yönlendiriliyor');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const MessagesListScreen(),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, mesajlar listesi sıraya alınıyor');
      _startPendingNotificationCheck({
        'type': 'message',
      });
    }
  }

  // Sohbet sayfasına yönlendirme
  void _navigateToChat(
    String userId,
    String userName, {
    String? userImageUrl,
    String? messageText,
    String? messageId,
    DateTime? messageCreatedAt,
    String? dealId,
    String? dealTitle,
    String? dealImageUrl,
    String? dealPrice,
    String? dealStore,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Sohbet sayfasına yönlendiriliyor: $userId ($userName)');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => MessageScreen(
            otherUserId: userId,
            otherUserName: userName.isNotEmpty ? userName : 'Kullanıcı',
            otherUserImageUrl: userImageUrl ?? '',
            initialIncomingMessageText: messageText,
            initialIncomingMessageId: messageId,
            initialIncomingMessageTime: messageCreatedAt,
            initialDealId: dealId,
            initialDealTitle: dealTitle,
            initialDealImageUrl: dealImageUrl,
            initialDealPrice: dealPrice,
            initialDealStore: dealStore,
          ),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, sohbet yönlendirmesi yapılamıyor. Sıraya alınıyor...');
      _startPendingNotificationCheck({
        'type': 'message',
        'senderId': userId,
        'senderName': userName,
        'senderImageUrl': userImageUrl,
        'messageText': messageText,
        'messageId': messageId,
        'createdAt': messageCreatedAt?.toIso8601String(),
        'dealId': dealId,
        'dealTitle': dealTitle,
        'dealImageUrl': dealImageUrl,
        'dealPrice': dealPrice,
        'dealStore': dealStore,
      });
    }
  }

  // Deal detay sayfasına yönlendirme
  void _navigateToDeal(String dealId, {String? commentId}) {
    if (dealId.isEmpty) {
      _log('⚠️ Deal ID boş, yönlendirme yapılamıyor');
      return;
    }
    
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Deal detay sayfasına yönlendiriliyor: $dealId${commentId != null ? " (yorum: $commentId)" : ""}');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => DealDetailScreen(
            dealId: dealId,
            scrollToCommentId: commentId,
          ),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, deal yönlendirmesi sıraya alınıyor: $dealId');
      _startPendingNotificationCheck({
        'type': 'deal',
        'dealId': dealId,
        if (commentId != null && commentId.isNotEmpty) 'commentId': commentId,
      });
    }
  }

  // Admin sohbet sayfasına yönlendirme
  void _navigateToAdminChat() {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Admin sohbet sayfasına yönlendiriliyor');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const MessageScreen(
            otherUserId: 'admin',
            otherUserName: 'FırsatKolik Yönetim',
            otherUserImageUrl: 'assets/logo.webp',
            isAdminMessage: true,
          ),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, admin sohbet yönlendirmesi sıraya alınıyor');
      _startPendingNotificationCheck({
        'type': 'admin_message',
      });
    }
  }

  // Bildirimler / Bildirim Merkezi ekranına yönlendirme
  Future<void> _navigateToAdminNotifications({
    String? initialTab,
    String? highlightNotificationId,
    String? highlightDealId,
    String? highlightKuponId,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Bildirimler ekranına yönlendiriliyor (tab: $initialTab, notifId: $highlightNotificationId, dealId: $highlightDealId, kuponId: $highlightKuponId)');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => AdminNotificationsScreen(
            initialTab: initialTab,
            highlightNotificationId: highlightNotificationId,
            highlightDealId: highlightDealId,
            highlightKuponId: highlightKuponId,
          ),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, bildirimler ekranı sıraya alınıyor');
      _startPendingNotificationCheck({
        'type': 'admin_notifications',
        if (initialTab != null) 'initialTab': initialTab,
        if (highlightNotificationId != null) 'notificationId': highlightNotificationId,
        if (highlightDealId != null) 'dealId': highlightDealId,
        if (highlightKuponId != null) 'kuponId': highlightKuponId,
      });
    }
  }

  // Admin ekranına yönlendirme (onay bekleyen fırsatlar ve kuponlar için)
  Future<void> _navigateToAdminScreen({String? dealId, String? kuponId, int? tabIndex}) async {
    final isAdmin = await AuthService().isAdmin();
    if (!isAdmin) {
      _log('🛡️ Admin ekranı yönlendirmesi engellendi: Kullanıcı admin değil');
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Admin ekranına yönlendiriliyor (onay bekleyenler, dealId: $dealId, kuponId: $kuponId, tabIndex: $tabIndex)');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => AdminScreen(
            initialDealId: dealId,
            initialTabIndex: tabIndex ?? (kuponId != null && kuponId.isNotEmpty ? 2 : 0),
          ),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, admin ekranı yönlendirmesi sıraya alınıyor');
      _startPendingNotificationCheck({
        'type': kuponId != null && kuponId.isNotEmpty ? 'admin_coupon' : 'admin_deal',
        if (dealId != null && dealId.isNotEmpty) 'dealId': dealId,
        if (kuponId != null && kuponId.isNotEmpty) 'kuponId': kuponId,
        if (tabIndex != null) 'tabIndex': tabIndex,
      });
    }
  }

  // Bildirim dinleyicilerini başlat (sadece bir kez; çift kayıt önlenir)
  void setupNotificationListeners() {
    if (_notificationListenersSetup) {
      _log('📬 Bildirim dinleyicileri zaten kayıtlı, atlanıyor');
      return;
    }
    _notificationListenersSetup = true;
    _log('📬 Bildirim dinleyicileri kaydediliyor...');

    // Ön planda iken işletim sisteminin sistem push bildirimi göstermesini kapat
    // (Böylece uygulama açıkken sistem push notif düşmez, SADECE InAppMessageBanner gösterilir)
    _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // Uygulama ön planda iken gelen bildirimler (PROD-READY Evrensel In-App Banner & Kendi Ekranı Bastırma)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // 0. MÜKERRER MESAJ KORUMASI (Duplicate FCM Delivery & Multiple Listener Protection)
      if (_isDuplicateFcmMessage(message)) {
        _log('🛡️ Mükerrer FCM bildirimi tespit edildi ve engellendi (messageId: ${message.messageId})');
        return;
      }

      _log('📬 Yeni bildirim (ön plan): ${message.notification?.title}');
      _log('📬 Bildirim verisi: ${message.data}');

      String clean(dynamic val) => val == null ? '' : val.toString().trim();

      final type = clean(message.data['type']).isEmpty ? 'deal' : clean(message.data['type']);
      final reason = clean(message.data['reason']).isEmpty ? clean(message.data['channel']) : clean(message.data['reason']);
      final dealId = clean(message.data['dealId']).isNotEmpty ? clean(message.data['dealId']) : clean(message.data['deal_id']);
      final dealTitle = clean(message.data['dealTitle']).isNotEmpty ? clean(message.data['dealTitle']) : clean(message.data['deal_title']);

      final senderId = clean(
        message.data['senderId'] ??
        message.data['sender_id'] ??
        message.data['senderUid'] ??
        message.data['sender_uid'] ??
        message.data['fromUserId'] ??
        message.data['from_user_id'] ??
        message.data['userId'] ??
        message.data['user_id'],
      );

      final senderName = clean(
        message.data['senderName'] ??
        message.data['sender_name'] ??
        message.data['notification_title'],
      ).replaceAll('💬 ', '').trim();

      final senderImageUrl = clean(
        message.data['senderImageUrl'] ??
        message.data['sender_image_url'] ??
        message.data['userImageUrl'] ??
        message.data['user_image_url'] ??
        message.data['dealImageUrl'] ??
        message.data['deal_image_url'],
      );

      final currentActiveChat = activeChatUserId?.trim();
      final currentActiveDeal = activeDealId?.trim();

      // 1. KENDİ EKRANI SPAM KORUMASI (ACTIVE SCREEN SUPPRESSION)
      // A. Kullanıcı ilgili fırsatın detay sayfasındaysa (DealDetailScreen)
      //    Yorumlar ve güncellemeler canlı aktığı için bildirimi bastır
      if (currentActiveDeal != null && currentActiveDeal.isNotEmpty && dealId.isNotEmpty && currentActiveDeal == dealId) {
        if (type == 'comment' || type == 'comment_reply' || type == 'deal' || type == 'vote' || type == 'keyword' || type == 'author') {
          _log('🛡️ Kullanıcı zaten bu fırsatın detay sayfasında ($dealId), ön plan bildirim bastırıldı.');
          return;
        }
      }

      // B. Yönetici Admin panelindeyse ve onay bekleyen fırsat/kupon bildirimi geldiyse bastır
      if (isAdminScreenActive && (type == 'admin_deal' || reason == 'admin_deal' || type == 'admin_coupon' || reason == 'admin_coupon')) {
        _log('🛡️ Yönetici zaten admin ekranında, onay bekleyen fırsat/kupon ön plan bildirimi bastırıldı.');
        return;
      }

      // C. Kullanıcı Kuponlar sayfasındaysa ve kupon bildirimi geldiyse bastır
      if (isCouponsScreenActive && (type == 'coupon' || type == 'community_coupon')) {
        _log('🛡️ Kullanıcı zaten Kuponlar sayfasında, ön plan kupon bildirimi bastırıldı.');
        return;
      }

      // D. Birebir sohbet mesajı ve kullanıcı aynı odadaysa veya sessize almışsa bastır
      final isMessageNotification = type == 'message' || type == 'user_message' || type == 'chat';
      if (isMessageNotification) {
        final msgId = (message.data['messageId'] ?? '').toString().trim();
        if (msgId.isNotEmpty && _handledInAppMessageIds.contains(msgId)) {
          _log('ℹ️ Mesaj afişi zaten Firestore üzerinden gösterildi (onMessage atlanıyor): $msgId');
          return;
        }
        if (msgId.isNotEmpty) {
          _addHandledMessageId(msgId);
        }

        if (currentActiveChat != null && currentActiveChat.isNotEmpty) {
          final isSameUser = senderId.isEmpty || currentActiveChat.toLowerCase() == senderId.toLowerCase();
          final isAdminChat = (currentActiveChat == 'admin' || currentActiveChat == 'adminToUser') && (senderId == 'admin' || type == 'admin_message');
          if (isSameUser || isAdminChat) {
            _log('💬 Kullanıcı zaten aynı sohbet odasında ($currentActiveChat), ön plan mesaj bildirimi BASTIRILDI.');
            return;
          }
        }

        final myUid = _auth.currentUser?.uid;
        if (myUid != null && senderId.isNotEmpty) {
          final userDoc = await _firestore.collection('users').doc(myUid).get();
          final muted = List<String>.from(userDoc.data()?['mutedConversations'] ?? []);
          if (muted.contains(senderId)) {
            _log('🔕 Sohbet kullanıcı tarafından sessize alınmış ($senderId), ön plan bildirim bastırıldı.');
            return;
          }
        }

        DateTime? messageCreatedAt;
        final rawCreatedAt = message.data['createdAt'];
        if (rawCreatedAt != null && rawCreatedAt.toString().isNotEmpty) {
          messageCreatedAt = DateTime.tryParse(rawCreatedAt.toString());
        }

        InAppMessageBanner.show(
          context: null,
          senderId: senderId,
          senderName: senderName.isNotEmpty ? senderName : (message.notification?.title ?? 'Kullanıcı'),
          senderImageUrl: senderImageUrl,
          messageText: clean(message.data['messageText']).isNotEmpty
              ? clean(message.data['messageText'])
              : (clean(message.data['notification_body']).isNotEmpty
                  ? clean(message.data['notification_body'])
                  : (message.notification?.body ?? '')),
          messageId: msgId.isNotEmpty ? msgId : null,
          messageCreatedAt: messageCreatedAt ?? message.sentTime,
          dealTitle: dealTitle.isNotEmpty ? dealTitle : null,
          dealId: dealId.isNotEmpty ? dealId : null,
          badgeText: 'Yeni Mesaj',
          badgeColor: const Color(0xFF2196F3),
          leadingIcon: Icons.chat_bubble_rounded,
          rawData: message.data,
        );
        return;
      }

      if (type == 'admin_message') {
        if (currentActiveChat != null && (currentActiveChat == 'admin' || currentActiveChat == 'adminToUser')) {
          _log('💬 Kullanıcı zaten admin sohbet odasında, bildirim bastırıldı.');
          return;
        }

        InAppMessageBanner.show(
          context: null,
          senderId: 'admin',
          senderName: 'FırsatKolik Yönetim',
          senderImageUrl: 'assets/logo.webp',
          messageText: clean(message.data['notification_body']).isNotEmpty
              ? clean(message.data['notification_body'])
              : (message.notification?.body ?? 'Yeni bir yönetici bildiriminiz var.'),
          isAdminMessage: true,
          badgeText: 'Yönetici Mesajı',
          badgeColor: Colors.redAccent,
          leadingIcon: Icons.admin_panel_settings_rounded,
          rawData: message.data,
        );
        return;
      }

      // 2. DÜNYA STANDARTLARINDA UNIVERSAL FOREGROUND IN-APP BANNER
      // Tüm diğer bildirim türleri (yorum, yanıt, fırsat onayı, anahtar kelime, yazar takip, marketing vs.)
      // için OS Heads-Up popupları yerine branded InAppMessageBanner gösterilir.

      // Başlık ve gövde tespiti
      String title = clean(message.data['notification_title']);
      if (title.isEmpty) title = clean(message.data['title']);
      if (title.isEmpty) title = clean(message.notification?.title);

      String body = clean(message.data['notification_body']);
      if (body.isEmpty) body = clean(message.data['body']);
      if (body.isEmpty) body = clean(message.data['messageText']);
      if (body.isEmpty) body = clean(message.notification?.body);

      // Konfigürasyon belirleme
      String badge = 'Bildirim';
      Color color = const Color(0xFFFF5722);
      IconData icon = Icons.notifications_active_rounded;

      if (type == 'comment_reply' || type == 'comment') {
        final commentId = clean(message.data['commentId'] ?? message.data['comment_id']);
        final notifId = clean(message.data['notificationId'] ?? message.data['notification_id']);
        final compositeKey = '${notifId}_${dealId}_$commentId';
        if ((compositeKey.isNotEmpty && _handledCommentNotificationIds.contains(compositeKey)) ||
            (commentId.isNotEmpty && _handledCommentNotificationIds.contains(commentId)) ||
            (notifId.isNotEmpty && _handledCommentNotificationIds.contains(notifId))) {
          _log('ℹ️ Yorum bildirimi zaten Firestore üzerinden gösterildi (onMessage atlanıyor): $commentId');
          return;
        }
        if (compositeKey.isNotEmpty) _addHandledCommentNotificationId(compositeKey);
        if (commentId.isNotEmpty) _addHandledCommentNotificationId(commentId);
        if (notifId.isNotEmpty) _addHandledCommentNotificationId(notifId);
      }

      if (type == 'comment_reply') {
        badge = 'Yorum Cevabı';
        color = const Color(0xFF673AB7); // Deep Purple
        icon = Icons.reply_rounded;
        if (title.isEmpty) title = senderName.isNotEmpty ? senderName : 'Yorumunuza Cevap';
        if (body.isEmpty) body = 'Yorumunuza yeni bir yanıt geldi.';
      } else if (type == 'comment') {
        badge = 'Yeni Yorum';
        color = const Color(0xFF2196F3); // Blue
        icon = Icons.comment_rounded;
        if (title.isEmpty) title = senderName.isNotEmpty ? senderName : 'Yeni Yorum';
        if (body.isEmpty) body = 'Fırsatınıza yeni bir yorum yapıldı.';
      } else if (type == 'submission_status') {
        final rawStatus = clean(message.data['status']).toLowerCase();
        final titleLower = (title.isNotEmpty ? title : clean(message.data['title'])).toLowerCase();
        final bodyLower = (body.isNotEmpty ? body : clean(message.data['body'])).toLowerCase();
        final isCouponSub = clean(message.data['kuponId']).isNotEmpty || clean(message.data['submissionType']) == 'coupon';

        final bool isApproved;
        final bool isRejected;
        if (rawStatus == 'approved') {
          isApproved = true;
          isRejected = false;
        } else if (rawStatus == 'rejected') {
          isApproved = false;
          isRejected = true;
        } else if (titleLower.contains('onaylandı') || titleLower.contains('onaylandi') || bodyLower.contains('onaylandı') || bodyLower.contains('onaylandi')) {
          isApproved = true;
          isRejected = false;
        } else if (titleLower.contains('reddedildi') || bodyLower.contains('reddedildi')) {
          isApproved = false;
          isRejected = true;
        } else {
          isApproved = false;
          isRejected = false;
        }

        if (isApproved) {
          badge = 'Onaylandı';
          color = const Color(0xFF10B981); // Emerald Green
          icon = Icons.verified_rounded;
          if (title.isEmpty) title = isCouponSub ? '🎉 Kuponunuz Onaylandı!' : '🎉 Fırsatınız Onaylandı!';
          if (body.isEmpty) body = isCouponSub ? 'Tebrikler! Gönderdiğiniz kupon onaylandı ve yayına alındı.' : 'Tebrikler! Gönderdiğiniz fırsat onaylandı ve yayına alındı.';
        } else if (isRejected) {
          badge = 'Reddedildi';
          color = const Color(0xFFF59E0B); // Amber / Kehribar (#F59E0B)
          icon = Icons.info_outline_rounded;
          if (title.isEmpty) title = isCouponSub ? 'ℹ️ Kuponunuz Reddedildi' : 'ℹ️ Fırsatınız Reddedildi';
          if (body.isEmpty) body = isCouponSub ? 'Gönderdiğiniz kupon maalesef onaylanamadı. Detaylar için dokunun.' : 'Gönderdiğiniz fırsat maalesef onaylanamadı. Detaylar için dokunun.';
        } else {
          badge = isCouponSub ? 'Kupon Durumu' : 'Fırsat Durumu';
          color = const Color(0xFF2196F3); // Blue
          icon = Icons.assignment_outlined;
          if (title.isEmpty) title = isCouponSub ? '📋 Kupon Durumu' : '📋 Fırsat Durumu';
          if (body.isEmpty) body = isCouponSub ? 'Kuponunuzun gönderim durumu güncellendi.' : 'Fırsatınızın gönderim durumu güncellendi.';
        }
      } else if (type == 'keyword' || reason == 'keyword') {
        badge = 'Kelime Radarı';
        color = const Color(0xFF9C27B0); // Purple
        icon = Icons.radar_rounded;
        if (title.isEmpty) title = 'Radarınıza Yakalandı!';
        if (body.isEmpty) body = dealTitle.isNotEmpty ? dealTitle : 'Takip ettiğiniz kelimeyle ilgili yeni fırsat!';
      } else if (type == 'author' || type == 'follow' || reason == 'author') {
        badge = 'Yazar Takip';
        color = const Color(0xFF00BCD4); // Cyan
        icon = Icons.person_pin_circle_rounded;
        if (title.isEmpty) title = senderName.isNotEmpty ? senderName : 'Takip Ettiğiniz Yazar';
        if (body.isEmpty) body = dealTitle.isNotEmpty ? dealTitle : 'Takip ettiğiniz kullanıcı yeni fırsat paylaştı.';
      } else if (type == 'admin_deal' || reason == 'admin_deal') {
        badge = 'Onay Bekliyor';
        color = const Color(0xFFD32F2F); // Deep Red
        icon = Icons.admin_panel_settings_rounded;
        if (title.isEmpty) title = 'Onay Bekleyen Fırsat';
        if (body.isEmpty) body = dealTitle.isNotEmpty ? dealTitle : 'Yeni bir fırsat onay kuyruğunda bekliyor.';
      } else if (type == 'admin_coupon' || reason == 'admin_coupon') {
        badge = 'Kupon Onay Bekliyor';
        color = const Color(0xFF7B1FA2); // Purple Admin
        icon = Icons.confirmation_number_rounded;
        if (title.isEmpty) title = '🎟️ Onay Bekleyen Kupon';
        final magaza = clean(message.data['magazaAdi']);
        if (body.isEmpty) {
          body = magaza.isNotEmpty
              ? '$magaza için yeni bir kupon onay bekliyor.'
              : 'Yeni bir kupon onay kuyruğunda bekliyor.';
        }
      } else if (type == 'badge' || type == 'level_up' || reason == 'gamification') {
        badge = 'Tebrikler!';
        color = const Color(0xFFFFB300); // Amber
        icon = Icons.military_tech_rounded;
        if (title.isEmpty) title = 'Yeni Başarı!';
        if (body.isEmpty) body = 'Yeni bir rozet kazandınız veya seviye atladınız!';
      } else if (type == 'marketing' || reason == 'marketing' || reason == 'campaign') {
        badge = 'FırsatKolik';
        color = const Color(0xFFFF5722); // Deep Orange
        icon = Icons.campaign_rounded;
        if (title.isEmpty) title = 'Özel Duyuru';
        if (body.isEmpty) body = 'Sizin için özel bir kampanya duyurusu!';
      } else if (type == 'coupon' || type == 'community_coupon') {
        badge = 'Topluluk Kuponu';
        color = const Color(0xFF8E24AA); // Purple
        icon = Icons.confirmation_number_rounded;
        if (title.isEmpty) title = 'Yeni Kupon Paylaşıldı';
        if (body.isEmpty) body = 'Toplulukta yeni bir indirim kuponu paylaşıldı.';
      } else {
        badge = 'Sıcak Fırsat';
        color = const Color(0xFFFF6D00); // Orange
        icon = Icons.local_fire_department_rounded;
        if (title.isEmpty) title = 'Yeni Fırsat Paylaşıldı';
        if (body.isEmpty) body = dealTitle.isNotEmpty ? dealTitle : 'İlginizi çekebilecek yeni bir indirim var.';
      }

      // Diğer bildirimler için (fırsat, yorum, anahtar kelime vb.):
      // iOS tarafında AppDelegate willPresent bu bildirimleri native banner ([.banner, .sound]) olarak
      // işletim sistemi seviyesinde doğrudan sunar. Bu nedenle iOS'ta yerel bildirim tetiklenmez (çift afiş önleyici).
      // Android'de ise ön planda sistem afişi düşmediğinden FlutterLocalNotificationsPlugin şarttır.
      if (defaultTargetPlatform == TargetPlatform.android) {
        _showLocalNotification(message);
      }

      InAppMessageBanner.show(
        context: null,
        senderId: senderId.isNotEmpty ? senderId : (dealId.isNotEmpty ? dealId : 'firsatkolik'),
        senderName: title,
        senderImageUrl: senderImageUrl,
        messageText: body,
        dealTitle: dealTitle.isNotEmpty ? dealTitle : null,
        dealId: dealId.isNotEmpty ? dealId : null,
        badgeText: badge,
        badgeColor: color,
        leadingIcon: icon,
        rawData: message.data,
      );
    });

    // Bildirime tıklayınca (uygulama arka planda veya kapalı)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _log('🔔 Bildirim açıldı (onMessageOpenedApp): ${message.data}');
      _handleNotificationTap(message.data);
    });
    
    // iOS Native Bildirim Köprüsünü dinle
    _setupIosNativeNotificationChannel();

    // Uygulama kapalıyken bildirime tıklanırsa (Cold Start: Hem iOS Native Köprü hem FCM getInitialMessage)
    checkInitialNotification();
  }

  /// iOS Native AppDelegate bildirim köprü dinleyicisini bağlar
  void _setupIosNativeNotificationChannel() {
    if (_isIosChannelSetup || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _isIosChannelSetup = true;
    _iosNotificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap') {
        if (call.arguments != null && call.arguments is Map) {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          _log('🔔 [iOS Native Bridge] onNotificationTap alındı: $data');
          _handleNotificationTap(data);
        }
      }
    });
  }

  /// Uygulama kapalıyken (cold start) tıklanan bildirimi yakalar ve yönlendirir.
  /// Hem iOS Native AppDelegate köprüsünü hem de FirebaseMessaging.getInitialMessage'ı
  /// sorgular; iOS'taki asenkron delegate gecikmesini telafi etmek için retry mekanizması içerir.
  Future<void> checkInitialNotification() async {
    if (kIsWeb) return;

    // 1. iOS Özel: Native AppDelegate kanalından başlangıç bildirim verisini sorgula
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final dynamic rawData = await _iosNotificationChannel.invokeMethod('getInitialNotification');
        if (rawData != null && rawData is Map) {
          final data = Map<String, dynamic>.from(rawData);
          if (data.isNotEmpty) {
            _log('🚀 [iOS Native Bridge] Cold start bildirimi yakalandı: $data');
            _handleNotificationTap(data);
            return;
          }
        }
      } catch (e) {
        _log('⚠️ iOS Native notification bridge sorgu hatası: $e');
      }
    }

    // 2. Firebase Messaging getInitialMessage (iOS asenkron delegate gecikmesi için retry mekanizmalı)
    try {
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage == null && defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS UNUserNotificationCenter delegate yanıtı asenkron aktığından
        // ilk mikrosaniyede null dönebilir. 150ms aralıklarla 4 kez tekrar dene.
        for (int i = 0; i < 4; i++) {
          await Future.delayed(const Duration(milliseconds: 150));
          initialMessage = await _messaging.getInitialMessage();
          if (initialMessage != null) break;
        }
      }

      if (initialMessage != null) {
        _log('🔔 Uygulama kapalıyken FCM bildirimiyle açıldı: ${initialMessage.data}');
        _handleNotificationTap(initialMessage.data);
        return;
      }
    } catch (e) {
      _log('⚠️ getInitialMessage hatası: $e');
    }

    // 3. Android Yerel Bildirim Cold Start kontrolü (Local Notifications)
    if (defaultTargetPlatform == TargetPlatform.android && !_hasHandledColdStartNotification) {
      _hasHandledColdStartNotification = true;
      try {
        final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
          final payload = launchDetails.notificationResponse?.payload;
          if (payload != null && payload.isNotEmpty) {
            _log('🚀 Uygulama kapalıyken tıklanan yerel bildirim (cold start): $payload');
            _handlePayloadString(payload);
          }
        }
      } catch (e) {
        _log('⚠️ Cold start yerel bildirim kontrol hatası: $e');
      }
    }
  }

  // Yerel bildirim gösterme yardımcısı (Boş/başlıksız bildirim korumalı & deterministik ID)
  Future<void> _showLocalNotification(RemoteMessage message) => showLocalNotification(message);

  Future<void> showLocalNotification(RemoteMessage message) async {
    try {
      final data = message.data;

      // 1. Ghost / DryRun / Sessiz push koruması (İçi boş veya test mesajlarını bastır)
      if (data.isEmpty && message.notification == null) {
        _log('⚠️ Boş veya veri içermeyen push mesajı yakalandı, yerel bildirim bastırıldı.');
        return;
      }
      if (data['dryRun'] == 'true' || data['silent'] == 'true') {
        _log('ℹ️ DryRun/Sessiz test mesajı yerel bildirim oluşturulmadan yutuldu.');
        return;
      }

      String clean(dynamic val) => val == null ? '' : val.toString().trim();

      final type = clean(data['type']).isEmpty ? 'deal' : clean(data['type']);
      final reason = clean(data['reason']);
      final dealId = clean(data['dealId']);
      final dealTitle = clean(data['dealTitle']);
      final commentId = clean(data['commentId']);
      final messageId = clean(data['messageId']);
      final notificationId = clean(data['notificationId']);

      String senderId = clean(
        data['senderId'] ??
        data['sender_id'] ??
        data['senderUid'] ??
        data['sender_uid'] ??
        data['fromUserId'] ??
        data['from_user_id'] ??
        data['userId'] ??
        data['user_id'],
      );

      String senderName = clean(
        data['senderName'] ??
        data['sender_name'] ??
        data['notification_title'],
      );
      if (senderName.isEmpty) {
        senderName = 'Kullanıcı';
      }
      senderName = senderName.replaceAll('💬 ', '').trim();

      // 2. Akıllı Başlık Çıkarma (Boş string veya "Yeni Bildirim" gibi anlamsız fallbacksiz)
      String title = clean(data['notification_title']);
      if (title.isEmpty) title = clean(data['title']);
      if (title.isEmpty) title = clean(message.notification?.title);

      if (title.isEmpty || title == 'Yeni Bildirim') {
        if (type == 'deal') {
          title = '🎯 Yeni Fırsat!';
        } else if (type == 'comment') {
          title = '💬 $senderName fırsatınıza yorum yaptı';
        } else if (type == 'comment_reply') {
          title = '💬 $senderName yorumunuza cevap verdi';
        } else if (type == 'submission_status') {
          final isCouponSub = clean(data['kuponId']).isNotEmpty || clean(data['submissionType']) == 'coupon';
          final rawStatus = (data['status'] ?? '').toString().trim().toLowerCase();
          final rawBodyCandidate = clean(data['notification_body']).isNotEmpty
              ? clean(data['notification_body'])
              : (clean(data['body']).isNotEmpty ? clean(data['body']) : clean(message.notification?.body));
          final bodyLower = rawBodyCandidate.toLowerCase();
          final titleLower = title.toLowerCase();
          final isAppr = rawStatus == 'approved' ||
              (rawStatus.isEmpty && (titleLower.contains('onaylandı') || titleLower.contains('onaylandi') || bodyLower.contains('onaylandı') || bodyLower.contains('onaylandi')));
          final isRej = rawStatus == 'rejected' ||
              (rawStatus.isEmpty && (titleLower.contains('reddedildi') || bodyLower.contains('reddedildi')));

          if (isAppr) {
            title = isCouponSub ? '🎉 Kuponunuz Onaylandı!' : '🎉 Fırsatınız Onaylandı!';
          } else if (isRej) {
            title = isCouponSub ? 'ℹ️ Kuponunuz Reddedildi' : 'ℹ️ Fırsatınız Reddedildi';
          } else {
            title = isCouponSub ? '📋 Kupon Durumu' : '📋 Fırsat Durumu';
          }
        } else if (type == 'admin_deal') {
          title = '👮‍♂️ Onay Bekleyen Fırsat';
        } else if (type == 'admin_message') {
          title = '🛡️ FırsatKolik Yönetim';
        } else if (type == 'keyword' || reason == 'keyword') {
          title = '🎯 İlginizi Çeken Kelime!';
        } else if (type == 'marketing') {
          title = '🔥 Özel Fırsat Duyurusu';
        } else if (type == 'coupon' || type == 'community_coupon') {
          final magazaAdi = clean(data['magazaAdi']);
          title = magazaAdi.isNotEmpty ? '🎟️ $magazaAdi Kuponu!' : '🎟️ Yeni Kupon!';
        } else if (type == 'admin_coupon') {
          title = '🎟️ Onay Bekleyen Kupon';
        } else if (dealTitle.isNotEmpty) {
          title = '🎯 $dealTitle';
        } else {
          title = '🔔 FırsatKolik';
        }
      }

      // 3. Akıllı Gövde Çıkarma (Asla boş string kalmayacak şekilde)
      String body = clean(data['notification_body']);
      if (body.isEmpty) body = clean(data['body']);
      if (body.isEmpty) body = clean(data['messageText']);
      if (body.isEmpty) body = clean(message.notification?.body);

      if (body.isEmpty) {
        if (dealTitle.isNotEmpty) {
          body = '$dealTitle\nFırsatı görmek için dokunun.';
        } else if (type == 'submission_status') {
          final rawStatus = (data['status'] ?? '').toString().trim().toLowerCase();
          final titleLower = title.toLowerCase();
          final isAppr = rawStatus == 'approved' ||
              (rawStatus.isEmpty && (titleLower.contains('onaylandı') || titleLower.contains('onaylandi')));
          final isRej = rawStatus == 'rejected' ||
              (rawStatus.isEmpty && (titleLower.contains('reddedildi') || titleLower.contains('red')));

          final isCouponSub = clean(data['kuponId']).isNotEmpty || clean(data['submissionType']) == 'coupon';
          if (isAppr) {
            body = isCouponSub ? 'Tebrikler! Gönderdiğiniz kupon onaylandı ve yayına alındı.' : 'Tebrikler! Gönderdiğiniz fırsat onaylandı ve yayınlandı.';
          } else if (isRej) {
            body = isCouponSub ? 'Gönderdiğiniz kupon maalesef onaylanamadı. Detaylar için dokunun.' : 'Gönderdiğiniz fırsat maalesef onaylanamadı. Detaylar için dokunun.';
          } else {
            body = isCouponSub ? 'Kuponunuzun gönderim durumu güncellendi. Detaylar için dokunun.' : 'Fırsatınızın gönderim durumu güncellendi. Detaylar için dokunun.';
          }
        } else if (type == 'deal') {
          body = 'İlginizi çekebilecek yeni bir indirim paylaşıldı.';
        } else if (type == 'comment' || type == 'comment_reply') {
          body = 'Yorum detaylarını incelemek için dokunun.';
        } else if (type == 'admin_message') {
          body = 'Yeni bir yönetici bildiriminiz var.';
        } else if (type == 'coupon' || type == 'community_coupon') {
          body = 'Toplulukta yeni bir indirim kuponu paylaşıldı.';
        } else if (type == 'admin_coupon') {
          final magazaAdi = clean(data['magazaAdi']);
          body = magazaAdi.isNotEmpty
              ? '$magazaAdi için yeni bir kupon onay bekliyor.'
              : 'Yeni bir topluluk kuponu onay kuyruğunda bekliyor.';
        } else {
          body = 'Detayları görüntülemek için dokunun.';
        }
      }

      // 4. Kanal, Tag ve Deterministik ID Yapılandırması
      String channelId = 'sicak_firsatlar_general_v2';
      String channelName = 'Sıcak Fırsatlar';
      String channelDescription = 'Fırsat ve indirim bildirimleri';
      String payload = dealId;

      // Deterministik tohum (Seed) anahtarı: Rastgele timestamp yerine tutarlı anahtar
      final seedKey = notificationId.isNotEmpty
          ? notificationId
          : (dealId.isNotEmpty
              ? dealId
              : (commentId.isNotEmpty
                  ? commentId
                  : (messageId.isNotEmpty
                      ? messageId
                      : (senderId.isNotEmpty ? senderId : type))));

      int notifId = (seedKey.hashCode & 0x7FFFFFFF) % 100000;
      String tag = '${type}_$seedKey';

      if (type == 'admin_deal') {
        channelId = 'admin_channel';
        channelName = 'Admin Bildirimleri';
        channelDescription = 'Onay bekleyen ve sistem admin bildirimleri';
        tag = 'admin_deal_${dealId.isNotEmpty ? dealId : seedKey}';
        notifId = ('admin_${dealId.isNotEmpty ? dealId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = 'admin_deal:$dealId';
      } else if (type == 'admin_coupon') {
        final kuponId = clean(data['kuponId'] ?? data['kupon_id'] ?? data['couponId'] ?? data['coupon_id']);
        channelId = 'admin_channel';
        channelName = 'Admin Bildirimleri';
        channelDescription = 'Onay bekleyen ve sistem admin bildirimleri';
        tag = 'admin_coupon_${kuponId.isNotEmpty ? kuponId : seedKey}';
        notifId = ('admin_coupon_${kuponId.isNotEmpty ? kuponId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = 'admin_coupon:$kuponId';
      } else if (type == 'submission_status') {
        final kId = clean(data['kuponId'] ?? data['kupon_id'] ?? data['couponId'] ?? data['coupon_id']);
        final rawStatus = (data['status'] ?? '').toString().trim().toLowerCase();
        final titleLower = title.toLowerCase();
        final isAppr = rawStatus == 'approved' || titleLower.contains('onaylandı') || titleLower.contains('onaylandi');
        final isRej = rawStatus == 'rejected' || titleLower.contains('reddedildi');
        final cleanStatus = isAppr ? 'approved' : (isRej ? 'rejected' : rawStatus);
        channelId = 'sicak_firsatlar_general_v2';
        channelName = kId.isNotEmpty ? 'Kupon Onay/Ret' : 'Fırsat Onay/Ret';
        channelDescription = kId.isNotEmpty ? 'Gönderdiğiniz kuponların onay veya ret bildirimleri' : 'Gönderdiğiniz fırsatların onay veya ret bildirimleri';
        final targetId = kId.isNotEmpty ? kId : dealId;
        tag = 'submission_${targetId.isNotEmpty ? targetId : seedKey}';
        notifId = ('submission_${targetId.isNotEmpty ? targetId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = kId.isNotEmpty ? 'submission_status_coupon:$kId:$cleanStatus' : 'submission_status:$dealId:$cleanStatus';
      } else if (type == 'keyword' || reason == 'keyword') {
        channelId = 'keyword_alerts_channel';
        channelName = 'Özel Fırsat Bildirimleri';
        channelDescription = 'Takip ettiğiniz anahtar kelimelere ait fırsat bildirimleri';
        tag = 'keyword_${dealId.isNotEmpty ? dealId : seedKey}';
        notifId = ('kw_${dealId.isNotEmpty ? dealId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = dealId;
      } else if (type == 'author' || type == 'follow' || reason == 'author') {
        channelId = 'follow_channel';
        channelName = 'Takip Bildirimleri';
        channelDescription = 'Takip ettiğiniz yazar veya bot fırsat bildirimleri';
        tag = 'author_${dealId.isNotEmpty ? dealId : seedKey}';
        notifId = ('author_${dealId.isNotEmpty ? dealId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = dealId;
      } else if (type == 'comment_reply') {
        channelId = 'comment_replies_channel';
        channelName = 'Yorum Cevapları';
        channelDescription = 'Yorumlarınıza gelen cevaplar için bildirimler';
        tag = 'reply_${commentId.isNotEmpty ? commentId : (dealId.isNotEmpty ? dealId : seedKey)}';
        notifId = ('reply_${commentId.isNotEmpty ? commentId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = 'comment_reply:$dealId:$commentId';
      } else if (type == 'comment') {
        channelId = 'comment_replies_channel';
        channelName = 'Yorum Bildirimleri';
        channelDescription = 'Fırsatlarınıza gelen yorumlar için bildirimler';
        tag = 'comment_${commentId.isNotEmpty ? commentId : (dealId.isNotEmpty ? dealId : seedKey)}';
        notifId = ('comment_${commentId.isNotEmpty ? commentId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = 'comment:$dealId:$commentId';
      } else if (type == 'admin_message') {
        channelId = 'admin_messages_channel_v3';
        channelName = 'Yönetici Bildirimleri';
        channelDescription = 'FırsatKolik Yönetim bildirimleri';
        tag = 'admin_msg_${messageId.isNotEmpty ? messageId : seedKey}';
        notifId = ('admin_msg_${messageId.isNotEmpty ? messageId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = 'admin_message';
      } else if (type == 'message' || type == 'user_message' || type == 'chat') {
        channelId = 'messages_channel_v3';
        channelName = 'Mesaj Bildirimleri';
        channelDescription = 'Kullanıcılar arası mesajlaşma bildirimleri';
        tag = 'msg_$senderId';
        notifId = (senderId.hashCode & 0x7FFFFFFF) % 100000;
        payload = jsonEncode({
          'type': 'message',
          'senderId': senderId,
          'senderName': senderName,
          'messageId': messageId.isNotEmpty ? messageId : null,
          'messageText': body,
          'createdAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
        });
      } else if (type == 'coupon' || type == 'community_coupon') {
        final kuponId = clean(data['kuponId'] ?? data['kupon_id'] ?? data['couponId'] ?? data['coupon_id']);
        channelId = 'sicak_firsatlar_general_v2';
        channelName = 'Kupon Bildirimleri';
        channelDescription = 'Topluluk tarafından paylaşılan indirim kuponu bildirimleri';
        tag = 'coupon_${kuponId.isNotEmpty ? kuponId : seedKey}';
        notifId = ('coupon_${kuponId.isNotEmpty ? kuponId : seedKey}'.hashCode & 0x7FFFFFFF) % 100000;
        payload = 'coupon:$kuponId';
      }

      final isMessage = type == 'message' || type == 'user_message' || type == 'admin_message';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        tag: tag,
        onlyAlertOnce: isMessage,
        groupKey: isMessage ? 'group_messages' : 'group_deals',
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          htmlFormatBigText: false,
          htmlFormatContentTitle: false,
        ),
      );

      await _localNotifications.show(
        notifId,
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      _log('❌ Yerel bildirim gösterme hatası: $e');
    }
  }

  // --- Notification Preferences ---
  Future<NotificationPreferences> getNotificationPreferences() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return NotificationPreferences.defaultPreferences();
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notificationPreferences')
          .doc('main')
          .get();
      return NotificationPreferences.fromFirestore(doc);
    } catch (e) {
      _log('Preferences get error: $e');
      return NotificationPreferences.defaultPreferences();
    }
  }

  Future<void> updateNotificationPreferences(NotificationPreferences prefs) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notificationPreferences')
          .doc('main')
          .set(prefs.toMap(), SetOptions(merge: true));
      _log('✅ Notification preferences updated in Firestore');
      
      // Kategori aboneliklerini tercihe göre güncelle (abone ol veya aboneliği kaldır)
      await resubscribeToTopics();
    } catch (e) {
      _log('❌ Preferences update error: $e');
      rethrow;
    }
  }

  Future<String> checkSystemPermissionStatus() async {
    if (kIsWeb) return 'authorized';
    try {
      final settings = await _messaging.getNotificationSettings();
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return 'authorized';
        case AuthorizationStatus.denied:
          return 'denied';
        case AuthorizationStatus.notDetermined:
          return 'notDetermined';
      }
    } catch (e) {
      return 'notDetermined';
    }
  }

  // --- Anahtar Kelime Abonelikleri ---
  Future<List<String>> getNotificationKeywords() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];
    try {
      final snap = await _firestore
          .collection('notificationSubscriptions')
          .where('uid', isEqualTo: userId)
          .where('type', isEqualTo: 'keyword')
          .where('enabled', isEqualTo: true)
          .get();
      return snap.docs.map((doc) => doc.data()['displayValue'] as String).toList();
    } catch (e) {
      _log('Error getting keyword subscriptions: $e');
      return [];
    }
  }

  Future<void> addKeywordSubscription(String keyword) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final normalized = normalizeKeyword(keyword);
    if (normalized.isEmpty) return;

    final subId = _getSubscriptionId(userId, 'keyword', normalized);
    try {
      await _firestore.collection('notificationSubscriptions').doc(subId).set({
        'uid': userId,
        'type': 'keyword',
        'key': normalized,
        'displayValue': keyword,
        'normalizedValue': normalized,
        'includeDescendants': true,
        'enabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _log('✅ Keyword subscription added: $keyword');

      // FS-25: Dinamik FCM Topic Aboneliği (150 limit tavanını aşan sıfır maliyetli kalkan)
      if (!kIsWeb) {
        final cleanKw = _sanitizeKeywordForTopic(normalized);
        if (cleanKw.isNotEmpty) {
          final kwTopic = 'kw_$cleanKw';
          await _messaging.subscribeToTopic(kwTopic).catchError((e) {
            _log('⚠️ Keyword topic ($kwTopic) subscribe error: $e');
          });
          _log('📢 [FCM-Topic] Kelime konusuna abone olundu: $kwTopic');
        }
      }
    } catch (e) {
      _log('❌ Keyword subscription add error: $e');
      rethrow;
    }
  }

  Future<void> removeKeywordSubscription(String keyword) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final normalized = normalizeKeyword(keyword);
    final subId = _getSubscriptionId(userId, 'keyword', normalized);
    try {
      await _firestore.collection('notificationSubscriptions').doc(subId).delete();
      _log('✅ Keyword subscription removed: $keyword');

      // FS-25: Dinamik FCM Topic Aboneliğinden Çıkış
      if (!kIsWeb) {
        final cleanKw = _sanitizeKeywordForTopic(normalized);
        if (cleanKw.isNotEmpty) {
          final kwTopic = 'kw_$cleanKw';
          await _messaging.unsubscribeFromTopic(kwTopic).catchError((e) {
            _log('⚠️ Keyword topic ($kwTopic) unsubscribe error: $e');
          });
          _log('📢 [FCM-Topic] Kelime konusundan çıkıldı: $kwTopic');
        }
      }
    } catch (e) {
      _log('❌ Keyword subscription remove error: $e');
      rethrow;
    }
  }

  /// FS-25: Kelimeyi FCM Topic kuralına göre güvenle temizleyen standartlaştırıcı
  String _sanitizeKeywordForTopic(String rawKeyword) {
    final normalized = normalizeKeyword(rawKeyword);
    return normalized
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// FS-25: Aktif anahtar kelime aboneliklerini FCM topic'lerine yeniden bağla (Cihaz değişikliği / yeniden kurulum / yükseltme sonrası kalkan)
  Future<void> resubscribeAllKeywordTopics() async {
    if (kIsWeb) return;
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      final snap = await _firestore
          .collection('notificationSubscriptions')
          .where('uid', isEqualTo: userId)
          .where('type', isEqualTo: 'keyword')
          .where('enabled', isEqualTo: true)
          .limit(100)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final rawKey = (data['key'] ?? data['displayValue'] ?? '').toString();
        final cleanKw = _sanitizeKeywordForTopic(rawKey);
        if (cleanKw.isNotEmpty) {
          final kwTopic = 'kw_$cleanKw';
          await _messaging.subscribeToTopic(kwTopic).catchError((e) {
            _log('⚠️ Keyword topic ($kwTopic) resubscribe error: $e');
          });
        }
      }
      _log('✅ FS-25: ${snap.docs.length} aktif kelime konusu FCM ile senkronize edildi.');
    } catch (e) {
      _log('⚠️ resubscribeAllKeywordTopics hatası: $e');
    }
  }

  // --- Genel Bildirim Ayarları (Geriye Dönük Uyumluluk) ---
  Future<bool> getGeneralNotificationsEnabled() async {
    final prefs = await getNotificationPreferences();
    return prefs.pushMasterEnabled;
  }

  Future<void> setGeneralNotifications(bool enabled) async {
    final prefs = await getNotificationPreferences();
    await updateNotificationPreferences(prefs.copyWith(
      pushMasterEnabled: enabled,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _setAllDealsSubscription(bool enabled) async {
    // Legacy topic subscription stub
  }

  // --- Yorum Cevap Bildirimleri (Geriye Dönük Uyumluluk) ---
  Future<bool> getCommentReplyNotificationsEnabled(String userId) async {
    final prefs = await getNotificationPreferences();
    return prefs.communityNotificationsEnabled;
  }

  Future<void> setCommentReplyNotificationsEnabled(String userId, bool enabled) async {
    final prefs = await getNotificationPreferences();
    await updateNotificationPreferences(prefs.copyWith(
      communityNotificationsEnabled: enabled,
      updatedAt: DateTime.now(),
    ));
  }

  Future<bool> getCategoryNotificationsEnabled(String userId) async {
    final prefs = await getNotificationPreferences();
    return prefs.categoryNotificationsEnabled;
  }

  Future<bool> getKeywordNotificationsEnabled(String userId) async {
    final prefs = await getNotificationPreferences();
    return prefs.keywordNotificationsEnabled;
  }

  // Anahtar kelime için local bildirim göster (özel kanal ve ses)
  Future<void> _showKeywordNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      return;
    }
    
    try {
      final androidDetails = AndroidNotificationDetails(
        'keyword_alerts_channel', // Özel kanal ID
        'Özel Fırsat Bildirimleri',
        channelDescription: 'Takip ettiğiniz anahtar kelimeler için özel bildirimler',
        importance: Importance.max, // En yüksek önem
        priority: Priority.max, // En yüksek öncelik
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]), // Titreşim deseni
        enableLights: true,
        color: const Color(0xFFFF9800), // Turuncu renk
        ledColor: const Color(0xFFFF9800),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'İlginizi çeken bir fırsat bulundu!',
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: '🎯 Özel Fırsat Bildirimi',
          htmlFormatBigText: false,
        ),
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default', // iOS default ses
        interruptionLevel: InterruptionLevel.timeSensitive, // Önemli bildirim
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      
      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      _log('✅ Anahtar kelime bildirimi gösterildi');
    } catch (e) {
      _log('❌ Anahtar kelime bildirim hatası: $e');
    }
  }
  
  // Mesaj bildirimi gönder
  Future<void> sendMessageNotification({
    required String receiverId,
    String senderId = '',
    required String senderName,
    required String messageText,
    required String messageId,
  }) async {
    try {
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) {
        _log('⚠️ Alıcı bulunamadı: $receiverId');
        return;
      }

      final receiverData = receiverDoc.data();
      final muted = List<String>.from(receiverData?['mutedConversations'] ?? []);
      if (senderId.isNotEmpty && muted.contains(senderId)) {
        _log('🔕 Alıcı bu sohbeti sessize almış ($senderId), bildirim gönderilmedi.');
        return;
      }
      final blocked = List<String>.from(receiverData?['blockedUsers'] ?? []);
      if (senderId.isNotEmpty && blocked.contains(senderId)) {
        _log('🚫 Alıcı bu kullanıcıyı engellemiş ($senderId), bildirim gönderilmedi.');
        return;
      }

      final fcmToken = receiverData?['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        _log('⚠️ Alıcının FCM token\'ı yok');
        return;
      }

      const title = '💬 Yeni Mesaj';
      final body = '$senderName: ${messageText.length > 50 ? "${messageText.substring(0, 50)}..." : messageText}';

      const androidDetails = AndroidNotificationDetails(
        'messages_channel_v3',
        'Mesaj Bildirimleri',
        channelDescription: 'Kullanıcılar arası mesajlaşma bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF2196F3),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.active,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'message:$senderId:$senderName',
      );

      _log('✅ Mesaj bildirimi gösterildi: $receiverId');
    } catch (e) {
      _log('❌ Mesaj bildirim hatası: $e');
    }
  }

  @Deprecated('Takip bildirimleri artık Cloud Function tarafından otomatik gönderiliyor')
  Future<void> sendFollowNotification({
    required String followingUserId,
    required String dealId,
    required String dealTitle,
    required String username,
  }) async {
    _log('ℹ️ Takip bildirimleri artık Cloud Function tarafından otomatik gönderiliyor');
    return;
  }

  @Deprecated('Yorum yanıt bildirimleri artık Cloud Function (onCommentCreated) tarafından otomatik ve yetkili şekilde gönderiliyor')
  Future<void> sendCommentReplyNotification({
    required String recipientUserId,
    required String dealId,
    required String dealTitle,
    required String commentId,
    required String parentCommentId,
    required String replyUserName,
    required String replyText,
  }) async {
    _log('ℹ️ Yorum cevabı bildirimleri artık Cloud Function (onCommentCreated) tarafından otomatik gönderiliyor');
    return;
  }

  // Debug için test bildirimi
  Future<void> testLocalNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'messages_channel_v3', // v3
        'Mesaj Bildirimleri',
        channelDescription: 'Kullanıcılar arası mesajlaşma bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.message,
        fullScreenIntent: true,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher', // İkonu açıkça belirtelim
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      
      await _localNotifications.show(
        999,
        'Test Bildirimi (Mesaj Kanalı)',
        'Bu bir test mesajıdır. Eğer bunu görüyorsanız mesaj bildirimleri çalışmalıdır.',
        details,
      );
      _log('✅ Test bildirimi gönderildi');
    } catch (e) {
      _log('❌ Test bildirimi hatası: $e');
      rethrow;
    }
  }
}
