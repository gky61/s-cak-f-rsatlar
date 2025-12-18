import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../screens/deal_detail_screen.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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
      print('⚠️ Web platformunda local notifications desteklenmiyor');
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
        if (response.payload != null) {
          _navigateToDeal(response.payload!);
        }
      },
    );

    // Android notification channel oluştur
    const androidChannel = AndroidNotificationChannel(
      'sicak_firsatlar_channel',
      'Sıcak Fırsatlar Bildirimleri',
      description: 'Yeni fırsat bildirimleri için kanal',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    print('✅ Local notifications başlatıldı');
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
          print('✅ Web: Kullanıcı bildirimleri kabul etti');
        }
      } catch (e) {
        print('⚠️ Web bildirim izni hatası: $e');
      }
      return;
    }
    
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Kullanıcı bildirimleri kabul etti');
    }

    // Local notifications izinleri
    await initializeLocalNotifications();
  }

  // Kategori bildirimine abone ol
  Future<void> subscribeToCategory(String categoryId) async {
    try {
      await _messaging.subscribeToTopic('category_$categoryId');
      
      // Kullanıcının takip ettiği kategorileri güncelle
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'followedCategories': FieldValue.arrayUnion([categoryId])
        });
      }
      
      print('$categoryId kategorisine abone olundu');
    } catch (e) {
      print('Kategori abonelik hatası: $e');
    }
  }

  // Kategori bildiriminden çık
  Future<void> unsubscribeFromCategory(String categoryId) async {
    try {
      await _messaging.unsubscribeFromTopic('category_$categoryId');
      
      // Kullanıcının takip ettiği kategorileri güncelle
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'followedCategories': FieldValue.arrayRemove([categoryId])
        });
      }
      
      print('$categoryId kategorisinden çıkıldı');
    } catch (e) {
      print('Kategori çıkış hatası: $e');
    }
  }

  // Alt kategori bildirimine abone ol
  Future<void> subscribeToSubCategory(String categoryId, String subCategoryId) async {
    try {
      final sanitizedSubCategory = _sanitizeTopicName(subCategoryId);
      final topic = 'subcategory_${categoryId}_$sanitizedSubCategory';
      await _messaging.subscribeToTopic(topic);
      print('✅ Topic abone olundu: $topic');
      
      // Kullanıcının takip ettiği alt kategorileri güncelle
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final subCategoryKey = '$categoryId:$subCategoryId';
        
        // Önce kullanıcı dokümanının var olup olmadığını kontrol et
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          // Kullanıcı dokümanı yoksa oluştur
          await _firestore.collection('users').doc(userId).set({
            'followedSubCategories': [subCategoryKey],
            'followedCategories': [],
            'allNotificationsEnabled': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Kullanıcı dokümanı varsa güncelle
          await _firestore.collection('users').doc(userId).update({
            'followedSubCategories': FieldValue.arrayUnion([subCategoryKey])
          });
        }
        
        print('✅ Firestore güncellendi: $subCategoryKey');
      }
      
      print('✅ $categoryId - $subCategoryId alt kategorisine abone olundu');
    } catch (e) {
      print('❌ Alt kategori abonelik hatası: $e');
      rethrow; // Hata fırlat ki UI'da gösterilebilsin
    }
  }

  // Alt kategori bildiriminden çık
  Future<void> unsubscribeFromSubCategory(String categoryId, String subCategoryId) async {
    try {
      final sanitizedSubCategory = _sanitizeTopicName(subCategoryId);
      final topic = 'subcategory_${categoryId}_$sanitizedSubCategory';
      await _messaging.unsubscribeFromTopic(topic);
      print('✅ Topic abonelikten çıkıldı: $topic');
      
      // Kullanıcının takip ettiği alt kategorileri güncelle
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final subCategoryKey = '$categoryId:$subCategoryId';
        await _firestore.collection('users').doc(userId).update({
          'followedSubCategories': FieldValue.arrayRemove([subCategoryKey])
        });
        print('✅ Firestore güncellendi: $subCategoryKey kaldırıldı');
      }
      
      print('✅ $categoryId - $subCategoryId alt kategorisinden çıkıldı');
    } catch (e) {
      print('❌ Alt kategori çıkış hatası: $e');
      rethrow; // Hata fırlat ki UI'da gösterilebilsin
    }
  }

  // Kullanıcının takip ettiği kategorileri al
  Future<List<String>> getFollowedCategories() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return List<String>.from(data?['followedCategories'] ?? []);
      }
      return [];
    } catch (e) {
      print('Takip edilen kategorileri alma hatası: $e');
      return [];
    }
  }

  // Kullanıcının takip ettiği alt kategorileri al
  Future<List<String>> getFollowedSubCategories() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return List<String>.from(data?['followedSubCategories'] ?? []);
      }
      return [];
    } catch (e) {
      print('Takip edilen alt kategorileri alma hatası: $e');
      return [];
    }
  }

  // FCM token'ı al ve kaydet
  Future<void> saveFCMToken() async {
    try {
      // Web'de token almak için farklı bir yaklaşım gerekebilir
      final token = await _messaging.getToken(vapidKey: kIsWeb ? null : null);
      final userId = _auth.currentUser?.uid;
      
      if (token != null && userId != null) {
        // Kullanıcı dokümanının var olup olmadığını kontrol et
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          // Kullanıcı dokümanı yoksa oluştur
          await _firestore.collection('users').doc(userId).set({
            'fcmToken': token,
            'followedCategories': [],
            'followedSubCategories': [],
            'allNotificationsEnabled': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Kullanıcı dokümanı varsa güncelle
          await _firestore.collection('users').doc(userId).update({
            'fcmToken': token,
          });
        }
        print('✅ FCM Token kaydedildi: ${token.substring(0, 20)}...');
        
        // Token yenilendiğinde güncelle
        _messaging.onTokenRefresh.listen((newToken) async {
          if (userId != null) {
            await _firestore.collection('users').doc(userId).update({
              'fcmToken': newToken,
            });
            print('✅ FCM Token yenilendi: ${newToken.substring(0, 20)}...');
          }
        });
      }
    } catch (e) {
      print('❌ FCM Token kaydetme hatası: $e');
      // Web'de token alınamazsa uygulama çalışmaya devam etmeli
      if (!kIsWeb) rethrow;
    }
  }
  
  // Admin bildirimlerine abone ol
  Future<void> subscribeToAdminTopic() async {
    try {
      await _messaging.subscribeToTopic('admin_deals');
      print('✅ Admin bildirimlerine (admin_deals) abone olundu');
    } catch (e) {
      print('❌ Admin abonelik hatası: $e');
    }
  }

  // Kullanıcı giriş yaptığında çağrılacak
  Future<void> initializeForUser({bool isAdmin = false}) async {
    await saveFCMToken();
    
    final generalEnabled = await getGeneralNotificationsEnabled();
    await _setAllDealsSubscription(generalEnabled);

    // Eğer admin ise admin bildirimlerine de abone ol
    if (isAdmin) {
      await subscribeToAdminTopic();
    }

    // Kullanıcının takip ettiği topic'lere yeniden abone ol
    await _resubscribeToTopics();
  }
  
  // Kullanıcının takip ettiği tüm topic'lere yeniden abone ol
  Future<void> _resubscribeToTopics() async {
    try {
      final categories = await getFollowedCategories();
      final subCategories = await getFollowedSubCategories();
      
      // Kategorilere abone ol
      for (final categoryId in categories) {
        await _messaging.subscribeToTopic('category_$categoryId');
        print('✅ Kategori topic abone olundu: category_$categoryId');
      }
      
      // Alt kategorilere abone ol
      for (final subCategoryKey in subCategories) {
        final parts = subCategoryKey.split(':');
        if (parts.length == 2) {
          final categoryId = parts[0];
          final subCategoryId = parts[1];
          final sanitizedSubCategory = _sanitizeTopicName(subCategoryId);
          final topic = 'subcategory_${categoryId}_$sanitizedSubCategory';
          await _messaging.subscribeToTopic(topic);
          print('✅ Alt kategori topic abone olundu: $topic');
        }
      }
    } catch (e) {
      print('❌ Topic yeniden abonelik hatası: $e');
    }
  }

  // Ön planda bildirim göster
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Web'de local notifications desteklenmiyor
    if (kIsWeb) {
      print('📬 Web: Bildirim alındı: ${message.notification?.title}');
      return;
    }
    
    final notification = message.notification;
    final data = message.data;
    final dealId = data['dealId'] ?? '';

    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'sicak_firsatlar_channel',
      'Sıcak Fırsatlar Bildirimleri',
      channelDescription: 'Yeni fırsat bildirimleri için kanal',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      dealId.hashCode,
      notification.title,
      notification.body,
      details,
      payload: dealId,
    );

    print('📬 Local bildirim gösterildi: ${notification.title}');
  }

  // Deal detay sayfasına yönlendirme
  void _navigateToDeal(String dealId) {
    if (dealId.isEmpty) {
      print('⚠️ Deal ID boş, yönlendirme yapılamıyor');
      return;
    }
    
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      print('🔔 Deal detay sayfasına yönlendiriliyor: $dealId');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => DealDetailScreen(dealId: dealId),
        ),
      );
    } else {
      print('⚠️ Navigator henüz hazır değil, yönlendirme yapılamıyor');
    }
  }

  // Bildirim dinleyicilerini başlat
  void setupNotificationListeners() {
    // Uygulama ön planda iken gelen bildirimler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📬 Yeni bildirim (ön plan): ${message.notification?.title}');
      print('📬 Bildirim verisi: ${message.data}');
      // Local notification göster
      _showLocalNotification(message);
    });

    // Bildirime tıklayınca (uygulama arka planda veya kapalı)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Bildirim açıldı: ${message.data}');
      final dealId = message.data['dealId'] ?? '';
      if (dealId.isNotEmpty) {
        _navigateToDeal(dealId);
      } else {
        print('⚠️ Bildirimde dealId bulunamadı');
      }
    });
    
    // Uygulama kapalıyken bildirime tıklanırsa
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🔔 Uygulama kapalıyken bildirim açıldı: ${message.data}');
        final dealId = message.data['dealId'] ?? '';
        if (dealId.isNotEmpty) {
          // Navigator'ın hazır olması için kısa bir gecikme
          Future.delayed(const Duration(milliseconds: 500), () {
            _navigateToDeal(dealId);
          });
        } else {
          print('⚠️ Bildirimde dealId bulunamadı');
        }
      }
    });
  }

  Future<void> _setAllDealsSubscription(bool enabled) async {
    try {
      if (enabled) {
        await _messaging.subscribeToTopic('all_deals');
        print('✅ Genel bildirimlere (all_deals) abone olundu');
      } else {
        await _messaging.unsubscribeFromTopic('all_deals');
        print('🚫 Genel bildirimler kapatıldı (all_deals topic)');
      }
    } catch (e) {
      print('❌ Genel bildirim abonelik hatası: $e');
      rethrow;
    }
  }

  Future<bool> getGeneralNotificationsEnabled() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return true;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('allNotificationsEnabled')) {
          return data['allNotificationsEnabled'] as bool? ?? true;
        }
      }
      return true;
    } catch (e) {
      print('Genel bildirim tercih okuma hatası: $e');
      return true;
    }
  }

  Future<void> setGeneralNotifications(bool enabled) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _setAllDealsSubscription(enabled);
      await _firestore.collection('users').doc(userId).set(
        {'allNotificationsEnabled': enabled},
        SetOptions(merge: true),
      );
      print(enabled
          ? '✅ Genel bildirimler kaydedildi (açık)'
          : '🚫 Genel bildirimler kaydedildi (kapalı)');
    } catch (e) {
      print('Genel bildirim tercih güncelleme hatası: $e');
      rethrow;
    }
  }

  // Anahtar kelime bildirimleri için metodlar
  Future<List<String>> getNotificationKeywords() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return List<String>.from(data?['notificationKeywords'] ?? []);
      }
      return [];
    } catch (e) {
      print('Anahtar kelime alma hatası: $e');
      return [];
    }
  }

  Future<void> addNotificationKeyword(String keyword) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final trimmedKeyword = keyword.trim().toLowerCase();
      if (trimmedKeyword.isEmpty) return;

      // Kullanıcı dokümanının var olup olmadığını kontrol et
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userId).set({
          'notificationKeywords': [trimmedKeyword],
          'followedCategories': [],
          'followedSubCategories': [],
          'allNotificationsEnabled': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final currentKeywords = List<String>.from(
          userDoc.data()?['notificationKeywords'] ?? [],
        );
        if (!currentKeywords.contains(trimmedKeyword)) {
          await _firestore.collection('users').doc(userId).update({
            'notificationKeywords': FieldValue.arrayUnion([trimmedKeyword]),
          });
        }
      }
      print('✅ Anahtar kelime eklendi: $trimmedKeyword');
    } catch (e) {
      print('❌ Anahtar kelime ekleme hatası: $e');
      rethrow;
    }
  }

  Future<void> removeNotificationKeyword(String keyword) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final trimmedKeyword = keyword.trim().toLowerCase();
      await _firestore.collection('users').doc(userId).update({
        'notificationKeywords': FieldValue.arrayRemove([trimmedKeyword]),
      });
      print('✅ Anahtar kelime kaldırıldı: $trimmedKeyword');
    } catch (e) {
      print('❌ Anahtar kelime kaldırma hatası: $e');
      rethrow;
    }
  }
}

