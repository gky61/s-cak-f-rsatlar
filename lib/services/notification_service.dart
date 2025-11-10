import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Bildirim izinlerini iste
  Future<void> requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Kullanıcı bildirimleri kabul etti');
    }
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

  // FCM token'ı al ve kaydet
  Future<void> saveFCMToken() async {
    try {
      final token = await _messaging.getToken();
      final userId = _auth.currentUser?.uid;
      
      if (token != null && userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });
        print('FCM Token kaydedildi: $token');
      }
    } catch (e) {
      print('FCM Token kaydetme hatası: $e');
    }
  }

  // Bildirim dinleyicilerini başlat
  void setupNotificationListeners() {
    // Uygulama ön planda iken gelen bildirimler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Yeni bildirim: ${message.notification?.title}');
    });

    // Bildirime tıklayınca
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Bildirim açıldı: ${message.data}');
    });
  }
}

