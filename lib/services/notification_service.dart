import 'dart:async';
import 'dart:math';
import 'dart:typed_data'; // For Int64List
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_preferences.dart';
import '../models/notification_subscription.dart';
import '../models/user_device.dart';

import '../main.dart'; // navigatorKey için
import '../screens/deal_detail_screen.dart';
import '../screens/admin_notifications_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/message_screen.dart';
import '../screens/messages_list_screen.dart';
import '../widgets/in_app_message_banner.dart';

/// Debug modda log yazdır
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
  // Logları stream'e ekle (Debug ekranı için)
  NotificationService.logStream.add(message);
}

class NotificationService {
  static final StreamController<String> logStream = StreamController<String>.broadcast();
  static String? activeChatUserId;

  static bool _notificationListenersSetup = false;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _keywordListener;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _followDealsListener;
  final Set<String> _notifiedDealIds = <String>{};
  final Set<String> _notifiedFollowDealIds = <String>{};
  bool _keywordListenerAttached = false;

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
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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

    // Uygulama tamamen kapalıyken (cold start) tıklanan yerel bildirimi yakala
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

    // Local notifications izinleri
    await initializeLocalNotifications();

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
        await docRef.update({
          'active': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _log('✅ Device token marked inactive on logout');
      }
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

  // --- FCM Token Kaydetme ---
  Future<void> saveFCMToken({String? userId}) async {
    try {
      final token = await _messaging.getToken(vapidKey: kIsWeb ? null : null);
      final resolvedUserId = userId ?? _auth.currentUser?.uid;
      
      if (token != null && resolvedUserId != null) {
        final deviceId = await _getOrCreateDeviceId();
        final deviceIdDoc = '${resolvedUserId}_$deviceId';
        
        final permissionStatus = await checkSystemPermissionStatus();
        final platform = kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

        await _firestore.collection('userDevices').doc(deviceIdDoc).set({
          'uid': resolvedUserId,
          'deviceId': deviceId,
          'platform': platform,
          'fcmToken': token,
          'permissionStatus': permissionStatus,
          'active': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        _log('✅ User device / FCM Token registered in userDevices: $deviceIdDoc');
        
        _messaging.onTokenRefresh.listen((newToken) async {
          final currentUserId = resolvedUserId;
          if (currentUserId != null) {
            await _firestore.collection('userDevices').doc('${currentUserId}_$deviceId').set({
              'fcmToken': newToken,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            _log('✅ User device FCM Token refreshed');
          }
        });
      }
    } catch (e) {
      _log('❌ FCM Token kaydetme hatası: $e');
      if (!kIsWeb) rethrow;
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
  Future<void> ensureAdminTopicSubscriptionIfAdmin() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      final data = userDoc.data();
      final adminValue = data?['isAdmin'] ?? data?['isadmin'];
      final isAdmin = adminValue == true || adminValue == 'true' || adminValue == 1;
      if (isAdmin) {
        await subscribeToAdminTopic();
      }
    } catch (e) {
      _log('❌ ensureAdminTopicSubscriptionIfAdmin: $e');
    }
  }

  // Admin bildirimlerinden çık (normal kullanıcılar için)
  Future<void> unsubscribeFromAdminTopic() async {
    try {
      await _messaging.unsubscribeFromTopic('admin_deals');
      _log('🚫 Admin bildirimlerinden (admin_deals) çıkıldı');
    } catch (e) {
      _log('❌ Admin abonelik çıkış hatası: $e');
    }
  }

  /// Çıkış yapıldığında TÜM topic aboneliklerini temizle
  /// Bu fonksiyon signOut sırasında çağrılmalı
  // Yorum cevabı bildirim listener'ını durdur
  void _stopCommentReplyListener() {
    _commentReplyListener?.cancel();
    _commentReplyListener = null;
    _log('🛑 Yorum cevabı bildirim listener\'ı durduruldu');
  }

  Future<void> clearAllSubscriptions() async {
    try {
      _log('🧹 Tüm bildirim abonelikleri temizleniyor...');
      
      // Yorum cevabı bildirim listener'ını durdur
      _stopCommentReplyListener();
      
      // Admin topic'inden çık
      await _messaging.unsubscribeFromTopic('admin_deals');
      
      // Genel bildirimlerden çık
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
        await subscribeToAdminTopic();
        
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

  void _setupAdminDealsListener() {
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
        // .where('isUserSubmitted', isEqualTo: true) // KALDIRILDI: Bot fırsatları da gelsin diye
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
        const NotificationDetails(android: androidDetails),
        payload: 'admin_deal:$dealId',
      );
      _log('✅ Admin bildirimi gösterildi: $dealId');
    } catch (e) {
      _log('❌ Admin bildirim hatası: $e');
    }
  }

  // Yorum cevabı bildirimlerini dinle (Firestore üzerinden)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentReplyListener;
  
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
        .where('type', isEqualTo: 'comment_reply')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) async {
        _log('📬 Yorum cevabı bildirim listener tetiklendi: ${snapshot.docChanges.length} (Değişiklik) (isFirst: $isFirst)');
        
        if (isFirst) {
          isFirst = false;
          _log('ℹ️ Yorum cevabı ilk snapshot es geçildi, bildirim tetiklenmeyecek.');
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
              
              final dealId = data['dealId'] as String? ?? '';
              final commentId = data['commentId'] as String? ?? '';
              final replyUserName = data['replyUserName'] as String? ?? 'Birisi';
              final replyText = data['replyText'] as String? ?? '';
              final dealTitle = data['dealTitle'] as String? ?? 'Fırsat';
              
              _log('📨 Yorum cevabı bildirimi işleniyor: dealId=$dealId, commentId=$commentId, replyUserName=$replyUserName');
              
              // Yorum bildirimleri açıksa telefon bildirimi göster
              if (commentNotificationsEnabled) {
                // Local bildirim göster
                await _showCommentReplyLocalNotification(
                  dealId: dealId,
                  commentId: commentId,
                  replyUserName: replyUserName,
                  replyText: replyText,
                  dealTitle: dealTitle,
                );
                _log('✅ Yorum cevabı telefon bildirimi gösterildi');
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
        if (error.toString().contains('permission-denied')) {
          _log('ℹ️ Yorum cevabı bildirim listener çıkış sırasında kapandı (beklenen)');
        } else {
          _log('❌ Yorum cevabı bildirim listener hatası: $error');
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
      '$replyUserName yorumunuza cevap verdi',
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

  Future<void> _startKeywordListener() async {
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
  
  // Kullanıcının takip ettiği tüm topic'lere yeniden abone ol
  Future<void> resubscribeToTopics() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final categoryEnabled = await getCategoryNotificationsEnabled(userId);
      
      final categories = await getFollowedCategories();
      final subCategories = await getFollowedSubCategories();
      
      // Kategorilere abone ol
      for (final categoryId in categories) {
        if (categoryEnabled) {
          await _messaging.subscribeToTopic('category_$categoryId');
          _log('✅ Kategori topic abone olundu: category_$categoryId');
        } else {
          await _messaging.unsubscribeFromTopic('category_$categoryId');
          _log('🚫 Kategori topic aboneliği kaldırıldı: category_$categoryId');
        }
      }
      
      // Alt kategorilere abone ol
      for (final subCategoryKey in subCategories) {
        final parts = subCategoryKey.split(':');
        if (parts.length == 2) {
          final categoryId = parts[0];
          final subCategoryId = parts[1];
          final sanitizedSubCategory = _sanitizeTopicName(subCategoryId);
          final topic = 'subcategory_${categoryId}_$sanitizedSubCategory';
          if (categoryEnabled) {
            await _messaging.subscribeToTopic(topic);
            _log('✅ Alt kategori topic abone olundu: $topic');
          } else {
            await _messaging.unsubscribeFromTopic(topic);
            _log('🚫 Alt kategori topic aboneliği kaldırıldı: $topic');
          }
        }
      }
    } catch (e) {
      _log('❌ Topic yeniden abonelik hatası: $e');
    }
  }





  static Map<String, dynamic>? _pendingNotificationTapData;
  static Timer? _pendingTimer;
  static DateTime? _lastHandledTapTime;
  static String? _lastHandledTapKey;

  void _startPendingNotificationCheck(Map<String, dynamic> data) {
    _pendingNotificationTapData = data;
    _pendingTimer?.cancel();
    int attempts = 0;
    _pendingTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      final navigator = navigatorKey.currentState;
      final currentUser = _auth.currentUser;
      if (navigator != null && currentUser != null) {
        timer.cancel();
        if (_pendingNotificationTapData != null) {
          final pendingData = _pendingNotificationTapData!;
          _pendingNotificationTapData = null;
          _log('🚀 Navigator ve Oturum aktifleşti, bekleyen bildirim açılıyor: $pendingData');
          _handleNotificationTap(pendingData);
        }
      } else if (attempts > 30) {
        timer.cancel();
        _pendingNotificationTapData = null;
      }
    });
  }

  void _handlePayloadString(String payload) {
    if (payload.startsWith('admin_message:') || payload == 'admin_message') {
      _handleNotificationTap({'type': 'admin_message'});
    } else if (payload.startsWith('admin_deal:')) {
      final dealId = payload.substring('admin_deal:'.length);
      _handleNotificationTap({'type': 'admin_deal', 'dealId': dealId});
    } else if (payload.startsWith('comment_reply:')) {
      final parts = payload.split(':');
      final dealId = parts.length > 1 ? parts[1] : '';
      final commentId = parts.length > 2 ? parts[2] : '';
      _handleNotificationTap({'type': 'comment_reply', 'dealId': dealId, 'commentId': commentId});
    } else if (payload.startsWith('message:')) {
      final parts = payload.split(':');
      final senderId = parts.length > 1 ? parts[1] : '';
      final senderName = parts.length > 2 ? parts.sublist(2).join(':') : 'Kullanıcı';
      _handleNotificationTap({'type': 'message', 'senderId': senderId, 'senderName': senderName});
    } else {
      _handleNotificationTap({'type': 'deal', 'dealId': payload});
    }
  }

  void handleNotificationTapPublic(Map<String, dynamic> data) {
    _handleNotificationTap(data);
  }

  // Bildirime tıklandığında yönlendirme yap
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = (data['type'] ?? 'deal').toString();
    _log('🔔 Bildirim tipi: $type, data: $data');
    
    final senderId = (
      data['senderId'] ??
      data['sender_id'] ??
      data['senderUid'] ??
      data['sender_uid'] ??
      data['fromUserId'] ??
      data['from_user_id'] ??
      data['userId'] ??
      data['user_id'] ??
      ''
    ).toString().trim();

    final tapKey = '$type:$senderId';
    final now = DateTime.now();

    // 2.5 saniye içinde aynı bildirim tıklaması geldiyse es geç (Çift açılış ve geri gitme saçmalamasını engeller)
    if (_lastHandledTapKey == tapKey && _lastHandledTapTime != null) {
      if (now.difference(_lastHandledTapTime!).inMilliseconds < 2500) {
        _log('⚠️ Mükerrer bildirim tıklaması engellendi: $tapKey');
        return;
      }
    }

    _lastHandledTapKey = tapKey;
    _lastHandledTapTime = now;

    final senderName = (
      data['senderName'] ??
      data['sender_name'] ??
      data['notification_title'] ??
      'Kullanıcı'
    ).toString().replaceAll('💬 ', '').trim();

    final senderImageUrl = (
      data['senderImageUrl'] ??
      data['sender_image_url'] ??
      ''
    ).toString().trim();

    final navigator = navigatorKey.currentState;
    final currentUser = _auth.currentUser;
    if (navigator == null || currentUser == null) {
      _log('⏳ Navigator veya Oturum henüz hazır değil, bildirim tıklaması sıraya alındı: $data');
      _startPendingNotificationCheck(data);
      return;
    }

    _pendingNotificationTapData = null;

    if (type == 'message' || type == 'user_message' || type == 'admin_message' || (senderId.isNotEmpty && type != 'deal' && type != 'comment_reply' && type != 'admin_deal')) {
      if (senderId == 'admin' || type == 'admin_message') {
        _navigateToAdminChat();
      } else if (senderId.isNotEmpty) {
        _navigateToChat(senderId, senderName, userImageUrl: senderImageUrl);
      } else {
        _navigateToMessagesList();
      }
      return;
    }

    switch (type) {
      case 'admin_deal':
        _navigateToAdminScreen();
        break;
        
      case 'comment_reply':
        final dealId = (data['dealId'] ?? '').toString();
        final commentId = (data['commentId'] ?? '').toString();
        if (dealId.isNotEmpty) {
          _navigateToDeal(dealId, commentId: commentId.isNotEmpty ? commentId : null);
        }
        break;
        
      case 'keyword':
      case 'follow':
      case 'deal':
      default:
        final dealId = (data['dealId'] ?? '').toString();
        if (dealId.isNotEmpty) {
          _navigateToDeal(dealId);
        }
        break;
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
    }
  }

  // Sohbet sayfasına yönlendirme
  void _navigateToChat(String userId, String userName, {String? userImageUrl}) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Sohbet sayfasına yönlendiriliyor: $userId ($userName)');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => MessageScreen(
            otherUserId: userId,
            otherUserName: userName.isNotEmpty ? userName : 'Kullanıcı',
            otherUserImageUrl: userImageUrl ?? '',
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
      _log('⚠️ Navigator henüz hazır değil, yönlendirme yapılamıyor');
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
      _log('⚠️ Navigator henüz hazır değil, admin sohbet yönlendirmesi yapılamıyor');
    }
  }

  // Admin bildirimler ekranına yönlendirme
  void _navigateToAdminNotifications() {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Admin bildirimler ekranına yönlendiriliyor');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const AdminNotificationsScreen(),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, yönlendirme yapılamıyor');
    }
  }

  // Admin ekranına yönlendirme (onay bekleyen fırsatlar için)
  void _navigateToAdminScreen() {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Admin ekranına yönlendiriliyor (onay bekleyen fırsatlar)');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const AdminScreen(),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, yönlendirme yapılamıyor');
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

    // Uygulama ön planda iken gelen bildirimler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log('📬 Yeni bildirim (ön plan): ${message.notification?.title}');
      _log('📬 Bildirim verisi: ${message.data}');

      final type = (message.data['type'] ?? 'deal').toString();
      final senderId = (
        message.data['senderId'] ??
        message.data['sender_id'] ??
        message.data['senderUid'] ??
        message.data['sender_uid'] ??
        message.data['fromUserId'] ??
        message.data['from_user_id'] ??
        message.data['userId'] ??
        message.data['user_id'] ??
        ''
      ).toString().trim();
      final currentActiveChat = activeChatUserId?.trim();

      // Mesaj bildirimi kontrolü: Eğer kullanıcı herhangi bir sohbet odasındaysa BİLDİRİMİ TAMAMEN BASTIR
      final isMessageNotification = type == 'message' || type == 'user_message' || type == 'chat' || (senderId.isNotEmpty && type != 'deal' && type != 'comment_reply' && type != 'admin_deal');

      if (isMessageNotification) {
        _log('💬 Mesaj bildirimi (ön plan): senderId="$senderId", activeChatUserId="$currentActiveChat"');
        if (currentActiveChat != null && currentActiveChat.isNotEmpty) {
          final isSameUser = senderId.isEmpty || currentActiveChat.toLowerCase() == senderId.toLowerCase();
          final isAdminChat = (currentActiveChat == 'admin' || currentActiveChat == 'adminToUser') && (senderId == 'admin' || type == 'admin_message');
          if (isSameUser || isAdminChat) {
            _log('💬 Kullanıcı zaten aynı sohbet odasında ($currentActiveChat), ön plan mesaj bildirimi BASTIRILDI.');
            return;
          }
        }

        // Kullanıcı sohbet odasında değilse (örneğin anasayfada geziniyorsa) SADECE In-App Banner göster
        InAppMessageBanner.show(
          context: null,
          senderId: senderId,
          senderName: message.data['senderName']?.toString() ?? message.data['sender_name']?.toString() ?? message.notification?.title ?? 'Kullanıcı',
          senderImageUrl: message.data['senderImageUrl']?.toString() ?? message.data['sender_image_url']?.toString() ?? '',
          messageText: message.data['messageText']?.toString() ?? message.data['notification_body']?.toString() ?? message.notification?.body ?? '',
          dealTitle: message.data['dealTitle']?.toString(),
          dealId: message.data['dealId']?.toString(),
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
          messageText: message.data['notification_body'] ?? message.notification?.body ?? 'Yeni bir yönetici bildiriminiz var.',
          isAdminMessage: true,
        );
        return;
      }

      // Diğer bildirimler için Local notification göster
      _showLocalNotification(message);
    });

    // Bildirime tıklayınca (uygulama arka planda veya kapalı)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _log('🔔 Bildirim açıldı (onMessageOpenedApp): ${message.data}');
      _handleNotificationTap(message.data);
    });
    
    // Uygulama kapalıyken bildirime tıklanırsa
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _log('🔔 Uygulama kapalıyken bildirim açıldı: ${message.data}');
        void attemptNavigation(int retries) {
          if (navigatorKey.currentState != null) {
            _handleNotificationTap(message.data);
          } else if (retries > 0) {
            Future.delayed(const Duration(milliseconds: 500), () => attemptNavigation(retries - 1));
          }
        }
        // Splash animasyonu (~1.7s) tamamlandıktan sonra sohbet sayfasına yönlendir
        Future.delayed(const Duration(milliseconds: 2000), () => attemptNavigation(5));
      }
    });
  }

  // Yerel bildirim gösterme yardımcısı
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final data = message.data;
      final type = (data['type'] ?? 'deal').toString();
      final senderId = (
        data['senderId'] ??
        data['sender_id'] ??
        data['senderUid'] ??
        data['sender_uid'] ??
        data['fromUserId'] ??
        data['from_user_id'] ??
        data['userId'] ??
        data['user_id'] ??
        ''
      ).toString().trim();

      final senderName = (
        data['senderName'] ??
        data['sender_name'] ??
        data['notification_title'] ??
        'Kullanıcı'
      ).toString().replaceAll('💬 ', '').trim();

      final title = data['notification_title'] ?? message.notification?.title ?? '💬 $senderName';
      final body = data['notification_body'] ?? data['messageText'] ?? message.notification?.body ?? 'Yeni mesaj';

      String payload = '';
      if (type == 'message' || type == 'user_message' || type == 'chat' || senderId.isNotEmpty) {
        payload = 'message:$senderId:$senderName';
      } else if (type == 'admin_message') {
        payload = 'admin_message';
      } else {
        payload = data['dealId']?.toString() ?? '';
      }

      const androidDetails = AndroidNotificationDetails(
        'messages_channel_v3',
        'Mesaj Bildirimleri',
        channelDescription: 'Kullanıcılar arası mesajlaşma bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        const NotificationDetails(android: androidDetails),
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
        default:
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
    } catch (e) {
      _log('❌ Keyword subscription remove error: $e');
      rethrow;
    }
  }

  // --- Genel Bildirim Ayarları (Geriye Dönük Uyumluluk) ---
  Future<bool> getGeneralNotificationsEnabled() async {
    final prefs = await getNotificationPreferences();
    return prefs.pushMasterEnabled;
  }

  Future<void> setGeneralNotifications(bool enabled) async {
    final prefs = await getNotificationPreferences();
    await updateNotificationPreferences(NotificationPreferences(
      pushMasterEnabled: enabled,
      dealNotificationsEnabled: prefs.dealNotificationsEnabled,
      communityNotificationsEnabled: prefs.communityNotificationsEnabled,
      submissionStatusNotificationsEnabled: prefs.submissionStatusNotificationsEnabled,
      marketingNotificationsEnabled: prefs.marketingNotificationsEnabled,
      quietHoursEnabled: prefs.quietHoursEnabled,
      quietHoursStart: prefs.quietHoursStart,
      quietHoursEnd: prefs.quietHoursEnd,
      timezone: prefs.timezone,
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
    await updateNotificationPreferences(NotificationPreferences(
      pushMasterEnabled: prefs.pushMasterEnabled,
      dealNotificationsEnabled: prefs.dealNotificationsEnabled,
      communityNotificationsEnabled: enabled,
      submissionStatusNotificationsEnabled: prefs.submissionStatusNotificationsEnabled,
      marketingNotificationsEnabled: prefs.marketingNotificationsEnabled,
      quietHoursEnabled: prefs.quietHoursEnabled,
      quietHoursStart: prefs.quietHoursStart,
      quietHoursEnd: prefs.quietHoursEnd,
      timezone: prefs.timezone,
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
      final fcmToken = receiverData?['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        _log('⚠️ Alıcının FCM token\'ı yok');
        return;
      }

      final title = '💬 Yeni Mesaj';
      final body = '$senderName: ${messageText.length > 50 ? messageText.substring(0, 50) + "..." : messageText}';

      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Mesaj Bildirimleri',
        channelDescription: 'Kullanıcılar arası mesajlaşma bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
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

  // Yorum cevabı bildirimi gönder (Firestore üzerinden)
  Future<void> sendCommentReplyNotification({
    required String recipientUserId,
    required String dealId,
    required String dealTitle,
    required String commentId,
    required String parentCommentId,
    required String replyUserName,
    required String replyText,
  }) async {
    try {
      _log('📤 Yorum cevabı bildirimi gönderiliyor: recipientUserId=$recipientUserId, dealId=$dealId, commentId=$commentId');

      await _firestore.collection('users').doc(recipientUserId).collection('notifications').doc('reply_${commentId}_$recipientUserId').set({
        'type': 'comment_reply',
        'title': '$replyUserName yorumunuza cevap verdi',
        'body': replyText.length > 100 ? '${replyText.substring(0, 100)}...' : replyText,
        'dealId': dealId,
        'dealTitle': dealTitle,
        'commentId': commentId,
        'parentCommentId': parentCommentId,
        'replyUserName': replyUserName,
        'replyText': replyText.length > 100 ? '${replyText.substring(0, 100)}...' : replyText,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      _log('✅ Yorum cevabı bildirimi Firestore\'a eklendi: $recipientUserId');
    } catch (e) {
      _log('❌ Yorum cevabı bildirimi gönderme hatası: $e');
      rethrow;
    }
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
