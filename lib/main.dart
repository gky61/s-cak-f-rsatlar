import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:async';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/connectivity_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/deal_detail_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Release'de log yok
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Background message handler'ı sadece web dışı platformlarda kaydet
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    
    _log('🔥 FIRSATKOLİK başlatılıyor...');
    
    // Connectivity service'i başlat
    await ConnectivityService().initialize();
  } catch (e) {
    _log('❌ Firebase başlatma hatası: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    // Theme service'i dinle
    _themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = AppTheme.getLightTheme();
    final darkTheme = AppTheme.getDarkTheme();
    
    return AnimatedTheme(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      data: _themeService.themeMode == ThemeMode.dark ? darkTheme : lightTheme,
      child: MaterialApp(
        title: 'FIRSATKOLİK',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _themeService.themeMode,
        navigatorKey: navigatorKey,
        // Türkçe locale desteği
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [
          Locale('tr', 'TR'), // Türkçe
          Locale('en', 'US'), // İngilizce (fallback)
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(
          child: AuthWrapper(),
        ),
      ),
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
  final FirestoreService _firestoreService = FirestoreService();
  String? _lastUserId;
  Timer? _cleanupTimer;
  
  @override
  void initState() {
    super.initState();
    // Uygulama başladığında temizlik işlemlerini çalıştır
    _runCleanupTasks();
    
    // Her 6 saatte bir kontrol et
    _cleanupTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      _runCleanupTasks();
    });
  }

  /// Tüm temizlik işlemlerini çalıştır
  void _runCleanupTasks() {
    // 1. 24 saatten eski onay bekleyen fırsatları sil
    _firestoreService.deleteUnapprovedDealsAfter24Hours();
    
    // 2. 24 saatten eski yayındaki fırsatları sil
    _firestoreService.deleteOldDeals();
    
    // 3. Süresi bitmiş (isExpired: true) ve 1 günden eski fırsatları sil
    _firestoreService.cleanupExpiredDeals();
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // Bildirim servisini başlat
  void _initializeNotificationService(String userId) async {
    try {
      // Admin kontrolü yap - daha güvenilir hale getir
      final isAdmin = await _authService.isAdmin();
      _log('👤 Kullanıcı Admin mi? $isAdmin');
      
      if (isAdmin) {
        _log('✅ Admin kullanıcı tespit edildi, admin bildirimleri aktifleştiriliyor...');
      }

      await _notificationService.initializeForUser(isAdmin: isAdmin);
      
      // Admin ise, aboneliği doğrula
      if (isAdmin) {
        // Kısa bir gecikme sonrası admin topic'ine abone olduğundan emin ol
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            await _notificationService.subscribeToAdminTopic();
            _log('✅ Admin topic aboneliği doğrulandı');
          } catch (e) {
            _log('⚠️ Admin topic abonelik doğrulama hatası: $e');
          }
        });
      }
    } catch (e) {
      _log('❌ Bildirim servisi başlatma hatası: $e');
    }
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
          _log('Auth error: ${snapshot.error}');
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
          _log('User logged in: ${snapshot.data!.email}');
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
        
        // Kullanıcı giriş yapmamış (çıkış yaptı veya hiç giriş yapmadı)
        // Eğer daha önce giriş yapmışsa (lastUserId != null), abonelikleri temizle
        if (_lastUserId != null) {
          _notificationService.clearAllSubscriptions();
        }
        _lastUserId = null;
        _log('No user logged in');
        return const AuthScreen();
      },
    );
  }
}

