import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/deal_detail_screen.dart';
import 'theme/app_theme.dart';

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 Background bildirim alındı: ${message.notification?.title}');
  print('📬 Bildirim verisi: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Background message handler'ı kaydet
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  print('🔥 Sıcak Fırsatlar uygulaması başlatılıyor...');
  print('📱 Build zamanı: ${DateTime.now()}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sıcak Fırsatlar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  String? _lastUserId;

  // Bildirim servisini başlat
  void _initializeNotificationService(String userId) async {
    // Admin kontrolü yap
    final isAdmin = await _authService.isAdmin();
    print('👤 Kullanıcı Admin mi? $isAdmin');

    _notificationService.initializeForUser(isAdmin: isAdmin).catchError((e) {
      print('Bildirim servisi başlatma hatası: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // İlk yükleme durumu - Firebase Auth'un mevcut kullanıcısını kontrol et
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Stream henüz hazır değilse, mevcut kullanıcıyı kontrol et
          final currentUser = _authService.currentUser;
          if (currentUser != null) {
            // Kullanıcı zaten giriş yapmış, bildirim servisini başlat ve HomeScreen'e git
            if (_lastUserId != currentUser.uid) {
              _lastUserId = currentUser.uid;
              _initializeNotificationService(currentUser.uid);
            }
            return const HomeScreen();
          }
          // Kullanıcı yoksa loading göster
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Hata durumu
        if (snapshot.hasError) {
          print('Auth error: ${snapshot.error}');
          // Hata olsa bile mevcut kullanıcıyı kontrol et
          final currentUser = _authService.currentUser;
          if (currentUser != null) {
            if (_lastUserId != currentUser.uid) {
              _lastUserId = currentUser.uid;
              _initializeNotificationService(currentUser.uid);
            }
            return const HomeScreen();
          }
          return const AuthScreen();
        }
        
        // Kullanıcı giriş yapmış
        if (snapshot.hasData && snapshot.data != null) {
          final currentUserId = snapshot.data!.uid;
          // Kullanıcı değiştiyse _lastUserId'yi güncelle ve bildirim servisini başlat
          if (_lastUserId != currentUserId) {
            _lastUserId = currentUserId;
            // Kullanıcı giriş yaptığında bildirim servisini başlat
            _initializeNotificationService(currentUserId);
          }
          print('User logged in: ${snapshot.data!.email}');
          // Herkes normal ekrana gider, yönetici paneline geçiş butonu HomeScreen'de olacak
          return const HomeScreen();
        }
        
        // Stream null döndüyse, mevcut kullanıcıyı tekrar kontrol et
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          // Kullanıcı varsa ama stream henüz güncellenmemiş, HomeScreen'e git
          if (_lastUserId != currentUser.uid) {
            _lastUserId = currentUser.uid;
            _initializeNotificationService(currentUser.uid);
          }
          return const HomeScreen();
        }
        
        // Kullanıcı giriş yapmamış
        _lastUserId = null;
        print('No user logged in');
        return const AuthScreen();
      },
    );
  }
}

