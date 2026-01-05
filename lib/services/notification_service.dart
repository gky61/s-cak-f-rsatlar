import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../screens/deal_detail_screen.dart';

/// Debug modda log yazdır
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

class NotificationService {
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
        if (response.payload != null) {
          // Mesaj bildirimi ise mesaj ekranına yönlendir
          if (response.payload!.startsWith('message:')) {
            final messageId = response.payload!.substring(8);
            _navigateToMessage(messageId);
          } else {
            // Deal bildirimi ise deal ekranına yönlendir
            _navigateToDeal(response.payload!);
          }
        }
      },
    );

    // Android notification channel oluştur (genel bildirimler)
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
      'messages_channel',
      'Mesaj Bildirimleri',
      description: 'Kullanıcılar arası mesajlaşma bildirimleri',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF2196F3), // Mavi LED
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messagesChannel);

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
      
      _log('$categoryId kategorisine abone olundu');
    } catch (e) {
      _log('Kategori abonelik hatası: $e');
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
      
      _log('$categoryId kategorisinden çıkıldı');
    } catch (e) {
      _log('Kategori çıkış hatası: $e');
    }
  }

  // Alt kategori bildirimine abone ol
  Future<void> subscribeToSubCategory(String categoryId, String subCategoryId) async {
    try {
      final sanitizedSubCategory = _sanitizeTopicName(subCategoryId);
      final topic = 'subcategory_${categoryId}_$sanitizedSubCategory';
      await _messaging.subscribeToTopic(topic);
      _log('✅ Topic abone olundu: $topic');
      
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
        
        _log('✅ Firestore güncellendi: $subCategoryKey');
      }
      
      _log('✅ $categoryId - $subCategoryId alt kategorisine abone olundu');
    } catch (e) {
      _log('❌ Alt kategori abonelik hatası: $e');
      rethrow; // Hata fırlat ki UI'da gösterilebilsin
    }
  }

  // Alt kategori bildiriminden çık
  Future<void> unsubscribeFromSubCategory(String categoryId, String subCategoryId) async {
    try {
      final sanitizedSubCategory = _sanitizeTopicName(subCategoryId);
      final topic = 'subcategory_${categoryId}_$sanitizedSubCategory';
      await _messaging.unsubscribeFromTopic(topic);
      _log('✅ Topic abonelikten çıkıldı: $topic');
      
      // Kullanıcının takip ettiği alt kategorileri güncelle
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final subCategoryKey = '$categoryId:$subCategoryId';
        await _firestore.collection('users').doc(userId).update({
          'followedSubCategories': FieldValue.arrayRemove([subCategoryKey])
        });
        _log('✅ Firestore güncellendi: $subCategoryKey kaldırıldı');
      }
      
      _log('✅ $categoryId - $subCategoryId alt kategorisinden çıkıldı');
    } catch (e) {
      _log('❌ Alt kategori çıkış hatası: $e');
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
      _log('Takip edilen kategorileri alma hatası: $e');
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
      _log('Takip edilen alt kategorileri alma hatası: $e');
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
        _log('✅ FCM Token kaydedildi: ${token.substring(0, 20)}...');
        
        // Token yenilendiğinde güncelle
        _messaging.onTokenRefresh.listen((newToken) async {
          if (userId != null) {
            await _firestore.collection('users').doc(userId).update({
              'fcmToken': newToken,
            });
            _log('✅ FCM Token yenilendi: ${newToken.substring(0, 20)}...');
          }
        });
      }
    } catch (e) {
      _log('❌ FCM Token kaydetme hatası: $e');
      // Web'de token alınamazsa uygulama çalışmaya devam etmeli
      if (!kIsWeb) rethrow;
    }
  }
  
  // Admin bildirimlerine abone ol
  Future<void> subscribeToAdminTopic() async {
    try {
      // Önce mevcut abonelikleri kontrol et
      await _messaging.subscribeToTopic('admin_deals');
      _log('✅ Admin bildirimlerine (admin_deals) abone olundu');
      
      // Aboneliği doğrula - FCM token'ı kontrol et
      final token = await _messaging.getToken();
      if (token != null) {
        _log('✅ FCM Token mevcut: ${token.substring(0, 20)}...');
      } else {
        _log('⚠️ FCM Token bulunamadı!');
      }
    } catch (e) {
      _log('❌ Admin abonelik hatası: $e');
      // Hata durumunda tekrar dene
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          await _messaging.subscribeToTopic('admin_deals');
          _log('✅ Admin aboneliği tekrar denendi ve başarılı');
        } catch (retryError) {
          _log('❌ Admin abonelik tekrar deneme hatası: $retryError');
        }
      });
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
  Future<void> clearAllSubscriptions() async {
    try {
      _log('🧹 Tüm bildirim abonelikleri temizleniyor...');
      
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
      
      _log('✅ Tüm bildirim abonelikleri temizlendi');
    } catch (e) {
      _log('❌ Abonelik temizleme hatası: $e');
    }
  }

  // Kullanıcı giriş yaptığında çağrılacak
  Future<void> initializeForUser({bool isAdmin = false}) async {
    _log('🔔 Bildirim servisi başlatılıyor... (isAdmin: $isAdmin)');
    
    // Önce FCM token'ı kaydet
    await saveFCMToken();
    
    final generalEnabled = await getGeneralNotificationsEnabled();
    _log('📋 Genel bildirimler: ${generalEnabled ? "Açık" : "Kapalı"}');
    
    // Admin ise, genel bildirimler kapalı olsa bile admin bildirimlerini al
    if (isAdmin) {
      _log('👮 Admin kullanıcı tespit edildi - Admin bildirimleri aktifleştiriliyor...');
      
      // Admin için admin topic'ine KESINLIKLE abone ol (genel bildirim ayarından bağımsız)
      await subscribeToAdminTopic();
      
      // Aboneliği doğrula
      _log('✅ Admin topic aboneliği tamamlandı');
      
      // Genel bildirim ayarını kontrol et ve ona göre ayarla
      await _setAllDealsSubscription(generalEnabled);
    } else {
      _log('👤 Normal kullanıcı - Admin bildirimleri devre dışı');
      
      // Normal kullanıcı - genel bildirim ayarına göre ayarla
      await _setAllDealsSubscription(generalEnabled);
      
      // Normal kullanıcı - admin bildirimlerinden kesinlikle çık
      await unsubscribeFromAdminTopic();
    }

    // Kullanıcının takip ettiği topic'lere yeniden abone ol
    await resubscribeToTopics();

    _log('✅ Bildirim servisi başlatıldı');
    
    // NOT: Anahtar kelime bildirimleri artık Cloud Function üzerinden push ile geliyor.
    // Bu nedenle client-side dinleyici kapatıldı (aksi halde app açıldığında geçmiş ilanlar için bildirim basıyor).
  }

  /// Keyword listener'ı durdur
  void _stopKeywordListener() {
    _keywordListener?.cancel();
    _keywordListener = null;
    _keywordListenerAttached = false;
    _notifiedDealIds.clear();
    _log('🛑 Keyword listener durduruldu');
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
    _keywordListener = _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) async {
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

        await _showKeywordNotification(
          title: '🎯 İlginizi Çeken Bir Fırsat Bulundu!',
          body: '"$matched" kelimesi içeren yeni bir fırsat paylaşıldı. Hemen inceleyin!',
          payload: doc.id,
        );
        _notifiedDealIds.add(doc.id);
        _log('✅ Anahtar kelime bildirimi (client dinleyici): ${doc.id} / $matched');
      }

      if (latestMs > lastCheckMs) {
        lastCheckMs = latestMs;
        await prefs.setInt('keyword_last_check_ms', latestMs);
      }
    }, onError: (err) {
      _log('❌ Anahtar kelime dinleyici hatası: $err');
    });
  }
  
  // Kullanıcının takip ettiği tüm topic'lere yeniden abone ol
  Future<void> resubscribeToTopics() async {
    try {
      final categories = await getFollowedCategories();
      final subCategories = await getFollowedSubCategories();
      
      // Kategorilere abone ol
      for (final categoryId in categories) {
        await _messaging.subscribeToTopic('category_$categoryId');
        _log('✅ Kategori topic abone olundu: category_$categoryId');
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
          _log('✅ Alt kategori topic abone olundu: $topic');
        }
      }
    } catch (e) {
      _log('❌ Topic yeniden abonelik hatası: $e');
    }
  }

  // Ön planda bildirim göster
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Web'de local notifications desteklenmiyor
    if (kIsWeb) {
      _log('📬 Web: Bildirim alındı: ${message.notification?.title}');
      return;
    }
    
    final notification = message.notification;
    final data = message.data;
    final dealId = data['dealId'] ?? '';
    final type = data['type'] ?? 'deal';

    if (notification == null) return;

    // Bildirim tipine göre channel seç
    String channelId;
    String channelName;
    String channelDescription;
    Importance importance;
    
    switch (type) {
      case 'admin_deal':
        channelId = 'admin_channel';
        channelName = 'Admin Bildirimleri';
        channelDescription = 'Onay bekleyen fırsatlar için admin bildirimleri';
        importance = Importance.max; // En yüksek önem seviyesi
        break;
      case 'keyword':
        channelId = 'keyword_alerts_channel';
        channelName = 'Özel Fırsat Bildirimleri';
        channelDescription = 'İlginizi çeken kelimeler için özel ve vurgulu bildirimler';
        importance = Importance.max;
        break;
      case 'follow':
        channelId = 'follow_channel';
        channelName = 'Takip Bildirimleri';
        channelDescription = 'Takip ettiğiniz kullanıcıların paylaşımları için bildirimler';
        importance = Importance.high;
        break;
      case 'message':
        channelId = 'messages_channel';
        channelName = 'Mesaj Bildirimleri';
        channelDescription = 'Kullanıcılar arası mesajlaşma bildirimleri';
        importance = Importance.high;
        break;
      default:
        channelId = 'sicak_firsatlar_channel';
        channelName = 'Sıcak Fırsatlar Bildirimleri';
        channelDescription = 'Yeni fırsat bildirimleri için kanal';
        importance = Importance.high;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: Priority.high,
      showWhen: true,
      playSound: true, // Ses çal
      enableVibration: true, // Titreşim
      enableLights: true, // LED
      // Admin bildirimleri için mavi renk
      color: type == 'admin_deal' ? const Color(0xFF2196F3) : null,
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

    await _localNotifications.show(
      dealId.hashCode,
      notification.title,
      notification.body,
      details,
      payload: dealId,
    );

    _log('📬 Local bildirim gösterildi: ${notification.title} (channel: $channelId, type: $type)');
  }

  // Deal detay sayfasına yönlendirme
  void _navigateToDeal(String dealId) {
    if (dealId.isEmpty) {
      _log('⚠️ Deal ID boş, yönlendirme yapılamıyor');
      return;
    }
    
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Deal detay sayfasına yönlendiriliyor: $dealId');
      navigator.push(
        MaterialPageRoute(
          builder: (context) => DealDetailScreen(dealId: dealId),
        ),
      );
    } else {
      _log('⚠️ Navigator henüz hazır değil, yönlendirme yapılamıyor');
    }
  }

  void _navigateToMessage(String messageId) {
    if (messageId.isEmpty) {
      _log('⚠️ Message ID boş, yönlendirme yapılamıyor');
      return;
    }
    
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _log('🔔 Mesaj sayfasına yönlendiriliyor: $messageId');
      // Mesaj listesi ekranına yönlendir (mesaj ID'si ile scroll yapılabilir)
      // Şimdilik mesaj listesi ekranına yönlendiriyoruz
      // TODO: Mesaj listesi ekranı oluşturulduğunda buraya ekle
    } else {
      _log('⚠️ Navigator henüz hazır değil, yönlendirme yapılamıyor');
    }
  }

  // Bildirim dinleyicilerini başlat
  void setupNotificationListeners() {
    // Uygulama ön planda iken gelen bildirimler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log('📬 Yeni bildirim (ön plan): ${message.notification?.title}');
      _log('📬 Bildirim verisi: ${message.data}');
      // Local notification göster
      _showLocalNotification(message);
    });

    // Bildirime tıklayınca (uygulama arka planda veya kapalı)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _log('🔔 Bildirim açıldı: ${message.data}');
      final dealId = message.data['dealId'] ?? '';
      if (dealId.isNotEmpty) {
        _navigateToDeal(dealId);
      } else {
        _log('⚠️ Bildirimde dealId bulunamadı');
      }
    });
    
    // Uygulama kapalıyken bildirime tıklanırsa
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _log('🔔 Uygulama kapalıyken bildirim açıldı: ${message.data}');
        final dealId = message.data['dealId'] ?? '';
        if (dealId.isNotEmpty) {
          // Navigator'ın hazır olması için kısa bir gecikme
          Future.delayed(const Duration(milliseconds: 500), () {
            _navigateToDeal(dealId);
          });
        } else {
          _log('⚠️ Bildirimde dealId bulunamadı');
        }
      }
    });
  }

  Future<void> _setAllDealsSubscription(bool enabled) async {
    try {
      if (enabled) {
        await _messaging.subscribeToTopic('all_deals');
        _log('✅ Genel bildirimlere (all_deals) abone olundu');
      } else {
        await _messaging.unsubscribeFromTopic('all_deals');
        _log('🚫 Genel bildirimler kapatıldı (all_deals topic)');
      }
    } catch (e) {
      _log('❌ Genel bildirim abonelik hatası: $e');
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
      _log('Genel bildirim tercih okuma hatası: $e');
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
      _log(enabled
          ? '✅ Genel bildirimler kaydedildi (açık)'
          : '🚫 Genel bildirimler kaydedildi (kapalı)');
    } catch (e) {
      _log('Genel bildirim tercih güncelleme hatası: $e');
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
        // Öncelik: watchKeywords (yeni alan), yoksa notificationKeywords
        if (data != null && data.containsKey('watchKeywords')) {
          return List<String>.from(data['watchKeywords'] ?? []);
        }
        return List<String>.from(data?['notificationKeywords'] ?? []);
      }
      return [];
    } catch (e) {
      _log('Anahtar kelime alma hatası: $e');
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
      _log('✅ Anahtar kelime eklendi: $trimmedKeyword');
    } catch (e) {
      _log('❌ Anahtar kelime ekleme hatası: $e');
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
      _log('✅ Anahtar kelime kaldırıldı: $trimmedKeyword');
    } catch (e) {
      _log('❌ Anahtar kelime kaldırma hatası: $e');
      rethrow;
    }
  }

  // Yeni fırsat için anahtar kelime kontrolü yap ve eşleşen kullanıcılara bildirim gönder
  Future<void> checkKeywordsAndNotify(String dealId, String dealTitle, String dealDescription) async {
    try {
      _log('🔍 Anahtar kelime kontrolü: $dealTitle');
      
      // Tüm kullanıcıları al (watchKeywords alanı olanlar)
      final usersSnapshot = await _firestore
          .collection('users')
          .where('watchKeywords', isNotEqualTo: null)
          .get();
      
      if (usersSnapshot.docs.isEmpty) {
        return;
      }
      
      // Deal başlık ve açıklamasını küçük harfe çevir (case-insensitive arama için)
      final searchText = '${dealTitle.toLowerCase()} ${dealDescription.toLowerCase()}';
      
      int notificationCount = 0;
      
      for (var userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final watchKeywords = userData['watchKeywords'];
          
          if (watchKeywords == null || watchKeywords is! List || watchKeywords.isEmpty) {
            continue;
          }
          
          // Kullanıcının anahtar kelimelerini kontrol et
          final keywords = List<String>.from(watchKeywords);
          final matchedKeywords = <String>[];
          
          for (var keyword in keywords) {
            final keywordLower = keyword.toLowerCase();
            if (searchText.contains(keywordLower)) {
              matchedKeywords.add(keyword);
            }
          }
          
          // Eşleşme varsa bildirim gönder
          if (matchedKeywords.isNotEmpty) {
            final userId = userDoc.id;
            final currentUserId = _auth.currentUser?.uid;
            
            // Kendi fırsatını paylaşan kişiye bildirim gönderme
            if (userId == currentUserId) {
              continue;
            }
            
            // Local bildirim gönder
            try {
              await _showKeywordNotification(
                title: '🎯 İlginizi Çeken Bir Fırsat Bulundu!',
                body: '"${matchedKeywords.first}" kelimesi içeren yeni bir fırsat paylaşıldı. Hemen inceleyin!',
                payload: dealId,
              );
              
              notificationCount++;
              _log('✅ Bildirim: $userId → "${matchedKeywords.first}"');
            } catch (notifError) {
              _log('❌ Bildirim hatası: $notifError');
            }
          }
        } catch (e) {
          _log('❌ Kullanıcı işlem hatası: ${userDoc.id}');
        }
      }
      
      if (notificationCount > 0) {
        _log('✅ $notificationCount anahtar kelime bildirimi gönderildi');
      }
    } catch (e) {
      _log('❌ Anahtar kelime kontrolü hatası: $e');
    }
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
      // Anahtar kelime bildirimleri için özel kanal kullan
      final androidDetails = AndroidNotificationDetails(
        'keyword_alerts_channel', // Özel kanal ID
        'Anahtar Kelime Uyarıları',
        channelDescription: 'Takip ettiğiniz anahtar kelimeler için özel bildirimler',
        importance: Importance.max, // En yüksek önem
        priority: Priority.max, // En yüksek öncelik
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'), // Vurgulu ses
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
      
      // iOS için özel ses (kritik uyarı)
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
    required String senderName,
    required String messageText,
    required String messageId,
  }) async {
    try {
      // Alıcının FCM token'ını al
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

      // Local notification göster
      final title = '💬 Yeni Mesaj';
      final body = '$senderName: ${messageText.length > 50 ? messageText.substring(0, 50) + "..." : messageText}';

      // Android notification details
      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Mesaj Bildirimleri',
        channelDescription: 'Kullanıcılar arası mesajlaşma bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF2196F3), // Mavi LED
      );

      // iOS notification details
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
        payload: 'message:$messageId',
      );

      _log('✅ Mesaj bildirimi gösterildi: $receiverId');
    } catch (e) {
      _log('❌ Mesaj bildirim hatası: $e');
    }
  }

  // Takip edilen kullanıcı fırsat paylaştığında bildirim gönder
  // NOT: Bu fonksiyon artık kullanılmıyor - Cloud Function bu işi yapıyor
  // Sadece geriye dönük uyumluluk için bırakıldı
  @Deprecated('Takip bildirimleri artık Cloud Function tarafından otomatik gönderiliyor')
  Future<void> sendFollowNotification({
    required String followingUserId,
    required String dealId,
    required String dealTitle,
    required String username,
  }) async {
    // Cloud Function artık bu işi yapıyor, bu fonksiyon artık kullanılmıyor
    _log('ℹ️ Takip bildirimleri artık Cloud Function tarafından otomatik gönderiliyor');
    return;
  }
}

