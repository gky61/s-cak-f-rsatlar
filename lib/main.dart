import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, FlutterError;
import 'dart:async';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/connectivity_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firestore_service.dart';
import 'services/ai_service.dart';
import 'theme/app_theme.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler - uygulama arka planda veya kapalıyken FCM burada çalışır (arka planda)
// Uygulama tamamen kapalıyken bu handler ÇALIŞMAZ; o durumda sistem notification payload ile bildirimi gösterir
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (kDebugMode) {
    print('🌙 Arka plan mesajı alındı: ${message.messageId}');
    print('🌙 Data: ${message.data}');
    print('🌙 Notification: ${message.notification?.title}');
  }

  // ⚠️ DUPLİKE ÖNLEYİCİ: FCM notification payload varsa, Android zaten sistem bildirimi gösteriyor
  // Bu durumda biz tekrar local notification göstermemeliyiz (çift bildirim önleme)
  if (message.notification != null) {
    if (kDebugMode) {
      print('📬 FCM sistem bildirimi var, local bildirim atlanıyor');
    }
    return; // Android sistem bildirimi gösterecek, biz göstermeyelim
  }

  // Sadece data-only mesajları için local notification göster
  final data = message.data;
  final type = data['type'] ?? 'deal';

  String? title;
  String? body;
  String? payload;
  String channelId = 'admin_channel';

  if (type == 'admin_deal') {
    title = data['notification_title'] ?? '👮‍♂️ Yeni Onay Bekleyen Fırsat';
    body = data['notification_body'] ?? 'Onay için bekleyen bir fırsat var. Dokunun.';
    payload = 'admin_deal:${data['dealId']}';
  } else if (type == 'admin_message') {
    title = data['notification_title'] ?? data['title'] ?? '📩 Yeni Admin Mesajı';
    body = data['notification_body'] ?? 'Bir mesajınız var. Dokunun.';
    payload = 'message:${data['messageId']}';
    channelId = 'admin_messages_channel_v3';
  } else if (type == 'message') {
    title = data['notification_title'] ?? '💬 ${data['senderName'] ?? 'Biri'}';
    body = data['notification_body'] ?? data['messageText'] ?? 'Yeni mesaj';
    payload = 'message:${data['messageId']}';
    channelId = 'messages_channel';
  }

  if (title == null || body == null) return;

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Plugin'i initialize et (Arka planda çalışması için gerekli olabilir)
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const androidChannel = AndroidNotificationChannel(
    'admin_channel',
    'Admin Bildirimleri',
    description: 'Arka plan bildirimleri',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  const androidChannelMessages = AndroidNotificationChannel(
    'admin_messages_channel_v3',
    'Admin Mesajları',
    description: 'Admin mesaj bildirimleri',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  const androidChannelUserMsg = AndroidNotificationChannel(
    'messages_channel',
    'Mesajlar',
    description: 'Sohbet bildirimleri',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  
  // Eksik kanalları oluştur
  final plugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await plugin?.createNotificationChannel(androidChannel);
  await plugin?.createNotificationChannel(androidChannelMessages);
  await plugin?.createNotificationChannel(androidChannelUserMsg);

  // Bildirimi göster
  try {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == 'admin_messages_channel_v3' ? 'Admin Mesajları' : (channelId == 'messages_channel' ? 'Mesajlar' : 'Admin Bildirimleri'),
          channelDescription: 'Bildirim',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2196F3),
        ),
      ),
      payload: payload,
    );
    if (kDebugMode) print('✅ Arka plan bildirimi gösterildi: $title');
  } catch (e) {
    if (kDebugMode) print('❌ Arka plan bildirimi gösterme hatası: $e');
  }
}

void main() async {
  // Yakalanmamış hatalar uygulamanın kapanmasını engelle (logla, çökme)
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    if (kDebugMode) {
      print('FlutterError: ${details.exception}');
      if (details.stack != null) print('Stack: ${details.stack}');
    }
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check Aktivasyonu
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      _log('🛡️ Firebase App Check başarıyla başlatıldı');
    } catch (e) {
      _log('⚠️ Firebase App Check başlatma hatası: $e');
    }
    
    // Background message handler'ı sadece web dışı platformlarda kaydet
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    
    _log('🔥 FIRSATKOLİK başlatılıyor...');
    
    // Firebase Performance Monitoring'i başlat
    try {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
      _log('✅ Firebase Performance Monitoring aktifleştirildi');
    } catch (e) {
      _log('⚠️ Firebase Performance Monitoring başlatma hatası: $e');
    }
    
    // AdMob Başlatıcı Yardımcı Fonksiyonu
    Future<void> initAdMob() async {
      try {
        if (kDebugMode) {
          final configuration = RequestConfiguration(
            testDeviceIds: const <String>[
              '7dc74815-ecce-4731-b631-27ab9c0cbd15', // Test telefonu
            ],
          );
          await MobileAds.instance.updateRequestConfiguration(configuration);
          _log('✅ Test cihazı yapılandırması eklendi (sadece debug mod)');
        }
        
        await MobileAds.instance.initialize();
        _log('✅ AdMob SDK başlatıldı');
        
        if (kDebugMode) {
          _log('   Test modu: ... (debug build)');
        } else {
          _log('   Production modu: Gerçek reklamlar gösterilecek');
        }
      } catch (e) {
        _log('⚠️ AdMob başlatma hatası: $e');
      }
    }

    // UMP Consent Information ve AdMob Başlatma
    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) async {
              if (error != null) {
                _log('⚠️ UMP ConsentForm hatası: ${error.message}');
              }
              await initAdMob();
            });
          } else {
            await initAdMob();
          }
        },
        (FormError error) async {
          _log('⚠️ UMP Consent request hatası: ${error.message}');
          await initAdMob(); // Hata durumunda yine de reklamları başlat (fallback)
        },
      );
    } catch (e) {
      _log('⚠️ AdMob/UMP başlatma genel hatası: $e');
    }
    
    // Connectivity service'i başlat
    await ConnectivityService().initialize();
    
    // Gemini API bağlantısını test et (arka planda, bloklamadan)
    if (kDebugMode) {
      _log('🤖 Gemini API bağlantısı test ediliyor...');
      // Biraz gecikme ile test et (diğer servisler başlasın)
      Future.delayed(const Duration(seconds: 2), () {
        AIService.testConnection().then((success) {
          if (success) {
            _log('✅ Gemini API çalışıyor!');
          } else {
            _log('⚠️ Gemini API bağlantı hatası - Fırsat paylaşımında AI özellikleri çalışmayabilir');
          }
        }).catchError((e) {
          _log('⚠️ Gemini API test hatası: $e');
        });
      });
    }
  } catch (e) {
    _log('❌ Firebase başlatma hatası: $e');
  }

  // Kanalları uygulamanın en başında (giriş yapmadan önce) oluşturmayı dene
  try {
    if (!kIsWeb) {
      final notifService = NotificationService();
      await notifService.initializeLocalNotifications();
      _log('✅ Bildirim kanalları önyüklendi');
    }
  } catch (e) {
    _log('⚠️ Kanal önyükleme hatası: $e');
  }

  runApp(const MyApp());
  }, (error, stack) {
    if (kDebugMode) {
      print('ZonedGuarded yakalanmamış hata: $error');
      print('Stack: $stack');
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Uygulama ön plana geldiğinde admin ise admin bildirim topic'ine yeniden abone ol
      NotificationService().ensureAdminTopicSubscriptionIfAdmin();
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
  StreamSubscription? _blockedUserListener;
  
  @override
  void initState() {
    super.initState();
    // Temizlik işlemlerini ilk frame sonrası çalıştır (uygulama açılmadan Firestore'a yüklenmesin)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runCleanupTasks();
    });
    // Her 6 saatte bir kontrol et
    _cleanupTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      if (mounted) _runCleanupTasks();
    });
  }

  /// Tüm temizlik işlemlerini çalıştır (hatanın uygulamayı kapatmaması için .catchError)
  void _runCleanupTasks() {
    void onError(Object e, StackTrace? st) {
      if (kDebugMode) print('Temizlik hatası: $e');
    }
    _firestoreService.deleteUnapprovedDealsAfter24Hours().catchError(onError);
    _firestoreService.deleteOldDeals().catchError(onError);
    _firestoreService.cleanupExpiredDeals().catchError(onError);
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _blockedUserListener?.cancel();
    super.dispose();
  }
  
  // Engellenen kullanıcıyı kontrol et ve çıkış yaptır
  Future<bool> _checkAndHandleBlockedUser(String userId) async {
    try {
      _log('🔍 Engelleme kontrolü yapılıyor: $userId');
      final isBlocked = await _firestoreService.isUserBlocked(userId);
      _log('🔍 Engelleme durumu: $isBlocked');
      
      if (isBlocked) {
        _log('🚫 Kullanıcı engellenmiş, oturum kapatılıyor: $userId');
        _blockedUserListener?.cancel();
        await _authService.signOut();
        await _notificationService.clearAllSubscriptions();
        
        final ctx = navigatorKey.currentContext;
        if (mounted && ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.block, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hesabınız engellenmiştir. Lütfen destek ekibi ile iletişime geçin.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return true; // Kullanıcı engellenmiş
      } else {
        // Kullanıcı engellenmemiş, real-time listener başlat
        _log('✅ Kullanıcı engellenmemiş, real-time listener başlatılıyor: $userId');
        _startBlockedUserListener(userId);
        return false; // Kullanıcı engellenmemiş
      }
    } catch (e) {
      _log('❌ Engelleme kontrolü hatası: $e');
      // Hata durumunda güvenli tarafta kal, listener başlatma
      return false;
    }
  }
  
  // Real-time listener: Kullanıcı uygulama açıkken engellenirse çıkış yaptır
  void _startBlockedUserListener(String userId) {
    _blockedUserListener?.cancel();
    
    _log('👂 Real-time engelleme listener başlatılıyor: $userId');
    try {
      _blockedUserListener = _firestoreService.firestore
          .collection('blockedUsers')
          .doc(userId)
          .snapshots()
          .listen((snapshot) async {
        _log('👂 Engelleme listener tetiklendi: exists=${snapshot.exists}, mounted=$mounted, userId=$userId');
        if (snapshot.exists && mounted) {
          _log('🚫 Kullanıcı engellendi (real-time), oturum kapatılıyor: $userId');
          _blockedUserListener?.cancel();
          
          try {
            // Önce bildirim aboneliklerini temizle
            await _notificationService.clearAllSubscriptions();
            _log('✅ Bildirim abonelikleri temizlendi');
            
            // Sonra oturumu kapat
            await _authService.signOut();
            _log('✅ Oturum kapatıldı');
            
            final ctx = navigatorKey.currentContext;
            if (mounted && ctx != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.block, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hesabınız engellenmiştir. Lütfen destek ekibi ile iletişime geçin.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          } catch (e) {
            _log('❌ Engelleme işlemi hatası: $e');
            // Hata olsa bile oturumu kapatmayı dene
            try {
              await _authService.signOut();
            } catch (signOutError) {
              _log('❌ SignOut hatası: $signOutError');
            }
          }
        } else if (!snapshot.exists) {
          _log('✅ Kullanıcı engeli kaldırıldı (real-time): $userId');
        }
      }, onError: (error) {
        _log('❌ Blocked user listener hatası: $error');
        // Hata durumunda listener'ı yeniden başlatmayı dene
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _lastUserId == userId) {
            _log('🔄 Listener hatası sonrası yeniden başlatılıyor...');
            _startBlockedUserListener(userId);
          }
        });
      });
      _log('✅ Real-time engelleme listener başarıyla başlatıldı: $userId');
    } catch (e) {
      _log('❌ Listener başlatma hatası: $e');
    }
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
            // Kullanıcı zaten giriş yapmış
            if (_lastUserId != currentUser.uid) {
              _lastUserId = currentUser.uid;
              // Önce engelleme kontrolü yap
              _checkAndHandleBlockedUser(currentUser.uid).then((isBlocked) {
                // Engellenmemişse bildirim servisini başlat
                if (!isBlocked && mounted && _lastUserId == currentUser.uid) {
                  _initializeNotificationService(currentUser.uid);
                }
              });
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
              // Önce engelleme kontrolü yap
              _checkAndHandleBlockedUser(currentUser.uid).then((isBlocked) {
                // Engellenmemişse bildirim servisini başlat
                if (!isBlocked && mounted && _lastUserId == currentUser.uid) {
                  _initializeNotificationService(currentUser.uid);
                }
              });
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
            // Önce engelleme kontrolü yap
            _checkAndHandleBlockedUser(currentUserId).then((isBlocked) {
              // Engellenmemişse bildirim servisini başlat
              if (!isBlocked && mounted && _lastUserId == currentUserId) {
                _initializeNotificationService(currentUserId);
              }
            });
          }
          _log('User logged in: ${snapshot.data!.email}');
          // Herkes normal ekrana gider, yönetici paneline geçiş butonu HomeScreen'de olacak
          return const HomeScreen();
        }
        
        // Stream null döndüyse, mevcut kullanıcıyı tekrar kontrol et
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          // Kullanıcı varsa ama stream henüz güncellenmemiş
          if (_lastUserId != currentUser.uid) {
            _lastUserId = currentUser.uid;
            // Önce engelleme kontrolü yap
            _checkAndHandleBlockedUser(currentUser.uid).then((isBlocked) {
              // Engellenmemişse bildirim servisini başlat
              if (!isBlocked && mounted && _lastUserId == currentUser.uid) {
                _initializeNotificationService(currentUser.uid);
              }
            });
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

