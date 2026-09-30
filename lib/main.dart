import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, FlutterError, defaultTargetPlatform;
import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/app_badge_service.dart';
import 'services/theme_service.dart';
import 'services/connectivity_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firestore_service.dart';
import 'services/affiliate/affiliate_service.dart';
import 'theme/app_theme.dart';
import 'utils/circular_theme_transition.dart';
import 'services/system_log_service.dart';
import 'services/ad_manager_service.dart';
import 'services/coupon_credit_service.dart';
import 'services/share_intent_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

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
  } else if (type == 'submission_status') {
    final rawStatus = (data['status'] ?? '').toString().trim().toLowerCase();
    final notifTitle = data['notification_title'] ?? data['title'] ?? '';
    final titleLower = notifTitle.toString().toLowerCase();
    final notifBody = data['notification_body'] ?? data['body'] ?? '';
    final bodyLower = notifBody.toString().toLowerCase();

    final isAppr = rawStatus == 'approved' ||
        (rawStatus.isEmpty && (titleLower.contains('onaylandı') || titleLower.contains('onaylandi') || bodyLower.contains('onaylandı') || bodyLower.contains('onaylandi')));
    final isRej = rawStatus == 'rejected' ||
        (rawStatus.isEmpty && (titleLower.contains('reddedildi') || bodyLower.contains('reddedildi')));
    final status = isAppr ? 'approved' : (isRej ? 'rejected' : rawStatus);

    title = data['notification_title'] ?? (isAppr ? '🎉 Fırsatınız Onaylandı!' : (isRej ? 'ℹ️ Fırsatınız Reddedildi' : '📋 Fırsat Durumu'));
    body = data['notification_body'] ?? (isAppr ? 'Gönderdiğiniz fırsat onaylandı ve yayınlandı.' : (isRej ? 'Gönderdiğiniz fırsat maalesef onaylanamadı.' : 'Fırsatınızın gönderim durumu güncellendi.'));
    payload = 'submission_status:${data['dealId']}:$status';
    channelId = 'sicak_firsatlar_general_v2';
  } else if (type == 'admin_message') {
    title = data['notification_title'] ?? data['title'] ?? '📩 Yeni Admin Mesajı';
    body = data['notification_body'] ?? 'Bir mesajınız var. Dokunun.';
    payload = 'admin_message';
    channelId = 'admin_messages_channel_v3';
  } else if (type == 'message') {
    final senderId = data['senderId']?.toString() ?? '';
    final senderName = data['senderName']?.toString() ?? 'Kullanıcı';
    title = data['notification_title'] ?? '💬 $senderName';
    body = data['notification_body'] ?? data['messageText'] ?? 'Yeni mesaj';
    payload = 'message:$senderId:$senderName:$body';
    channelId = 'messages_channel_v3';
  }

  if (title == null || body == null) return;

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Plugin'i initialize et (Arka planda çalışması için gerekli olabilir)
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
    'messages_channel_v3',
    'Mesaj Bildirimleri',
    description: 'Kullanıcılar arası mesajlaşma bildirimleri',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  
  // Eksik kanalları oluştur
  final plugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await plugin?.createNotificationChannel(androidChannel);
  await plugin?.createNotificationChannel(androidChannelMessages);
  await plugin?.createNotificationChannel(androidChannelUserMsg);

  // Bildirimi göster (Spam stacking önleyici sabit ID ve tag)
  try {
    final senderId = (data['senderId'] ?? '').toString();
    final dealId = (data['dealId'] ?? '').toString();
    final isMessage = type == 'message' || type == 'user_message' || type == 'admin_message';
    
    final notifId = isMessage
        ? ((senderId.isNotEmpty ? senderId : 'admin').hashCode % 100000)
        : (dealId.isNotEmpty ? dealId.hashCode % 100000 : DateTime.now().millisecondsSinceEpoch % 100000);
        
    final tag = isMessage
        ? 'msg_${senderId.isNotEmpty ? senderId : "admin"}'
        : (dealId.isNotEmpty ? 'deal_$dealId' : null);

    await flutterLocalNotificationsPlugin.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == 'admin_messages_channel_v3'
              ? 'Admin Mesajları'
              : (channelId == 'messages_channel_v3' ? 'Mesaj Bildirimleri' : 'Admin Bildirimleri'),
          channelDescription: 'Bildirim',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2196F3),
          tag: tag,
          onlyAlertOnce: isMessage,
          groupKey: isMessage ? 'group_messages' : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  FlutterError.onError = (details) {
    if (kDebugMode) {
      print('FlutterError: ${details.exception}');
      if (details.stack != null) print('Stack: ${details.stack}');
    }
    FlutterError.presentError(details);

    // Layout/RenderFlex taşmaları uygulamayı çökertmez (Crashlytics'te fatal: false olarak izlenir)
    // Ancak kesinlikle çözülmesi gereken UI hatalarıdır; Web Admin panelinde ve Firestore'da görünmesi için 'error' olarak kaydedilir
    final isOverflow = details.exceptionAsString().contains('overflowed by');
    if (isOverflow) {
      FirebaseCrashlytics.instance.recordFlutterError(details, fatal: false);
      SystemLogService.instance.logError(
        category: 'mobile',
        subCategory: 'ui_layout',
        errorType: 'RenderFlexOverflow',
        message: details.exceptionAsString(),
        stack: details.stack,
        severity: SystemErrorSeverity.error,
      );
      return;
    }

    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    SystemLogService.instance.logError(
      category: 'app_crash',
      errorType: 'FlutterError',
      message: details.exceptionAsString(),
      stack: details.stack,
      severity: SystemErrorSeverity.fatal,
    );
  };

  // Widget çizim (build) hatalarında gri ekran yerine kullanıcı dostu kurtarma ve hata telemetrisi
  ErrorWidget.builder = (FlutterErrorDetails details) {
    SystemLogService.instance.logError(
      category: 'mobile',
      subCategory: 'ui_widget',
      errorType: 'WidgetBuildError',
      message: details.exceptionAsString(),
      stack: details.stack,
      severity: SystemErrorSeverity.error,
    );

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.orange.shade700, size: 32),
              const SizedBox(height: 6),
              const Text(
                'Bu alan yüklenirken bir sorun oluştu.',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Modern Flutter 3+ Asenkron / Root Isolate / Platform Channel Hata Yakalayıcısı
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('PlatformDispatcher unhandled error: $error');
      print('Stack: $stack');
    }

    final isPermissionDenied = error.toString().contains('permission-denied');
    if (isPermissionDenied) {
      // Yalnızca kullanıcı oturumu kapalıyken veya çıkış esnasında beklenen durumdur
      if (FirebaseAuth.instance.currentUser == null) {
        if (kDebugMode) {
          print('ℹ️ PlatformDispatcher: Çıkış esnasında yetkisiz dinleyici kapanışı (yoksayıldı)');
        }
        return true;
      }
      // Giriş yapmış kullanıcıda permission-denied gerçek bir güvenlik kuralı / yetki hatasıdır!
      SystemLogService.instance.logError(
        category: 'security',
        errorType: 'FirestorePermissionDenied',
        message: error.toString(),
        stack: stack,
        severity: SystemErrorSeverity.error,
      );
      return true;
    }

    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    SystemLogService.instance.logError(
      category: 'app_crash',
      errorType: 'PlatformDispatcherUnhandledError',
      message: error.toString(),
      stack: stack,
      severity: SystemErrorSeverity.fatal,
    );
    return true;
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _log('🔥 Firebase çekirdeği başarıyla başlatıldı');
  } catch (e) {
    _log('❌ Firebase başlatma hatası: $e');
  }

  // Kritik olmayan servisleri arka planda, ilk kare çizimini (runApp) bloklamadan başlat
  _initializeBackgroundServices();

  runApp(const MyApp());

  }, (error, stack) {
    // Güvenlik & Yetki Hata Ayrımı:
    final isPermissionDenied = error.toString().contains('permission-denied');
    if (isPermissionDenied) {
      // Yalnızca kullanıcı oturumu kapalıyken veya çıkış esnasında beklenen bir durumdur
      if (FirebaseAuth.instance.currentUser == null) {
        if (kDebugMode) {
          print('ℹ️ ZonedGuarded: Çıkış sırasında beklenen permission-denied hatası (yoksayıldı)');
        }
        return;
      }
      // Giriş yapmış kullanıcıda permission-denied gerçek bir kural/yetki hatasıdır; görünür kıl!
      SystemLogService.instance.logError(
        category: 'security',
        errorType: 'FirestorePermissionDenied',
        message: error.toString(),
        stack: stack,
        severity: SystemErrorSeverity.error,
      );
      return;
    }
    if (kDebugMode) {
      print('ZonedGuarded yakalanmamış hata: $error');
      print('Stack: $stack');
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    SystemLogService.instance.logError(
      category: 'app_crash',
      errorType: 'ZonedGuardedUnhandledError',
      message: error.toString(),
      stack: stack,
      severity: SystemErrorSeverity.fatal,
    );
  });
}

/// Kritik olmayan arka plan servislerini ve başlangıç konfigürasyonlarını
/// ana UI thread'ini ve açılış çizimini (runApp) BLOKLAMADAN asenkron başlatır.
void _initializeBackgroundServices() {
  // Background message handler'ı sadece web dışı platformlarda kaydet
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Affiliate şalterlerini Firestore settings/app belgesinden gerçek zamanlı dinle
  AffiliateService.initSettingsListener();

  // App Check Aktivasyonu (arka planda - Play Integrity ağ gecikmesini açılış ekranından soyutlar)
  FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  ).then((_) {
    _log('🛡️ Firebase App Check başarıyla başlatıldı');
  }).catchError((e) {
    _log('⚠️ Firebase App Check başlatma hatası: $e');
  });

  // Firebase Performance Monitoring'i başlat
  FirebasePerformance.instance.setPerformanceCollectionEnabled(true).then((_) {
    _log('✅ Firebase Performance Monitoring aktifleştirildi');
  }).catchError((e) {
    _log('⚠️ Firebase Performance Monitoring başlatma hatası: $e');
  });

  // Crashlytics ve Observability Ortam Parametreleri
  try {
    final envFlavor = isProductionFlavor ? 'prod' : 'dev';
    final platformName = kIsWeb ? 'web' : defaultTargetPlatform.name;
    FirebaseCrashlytics.instance.setCustomKey('flavor', envFlavor);
    FirebaseCrashlytics.instance.setCustomKey('platform', platformName);
    _log('✅ Crashlytics ortam parametreleri aktifleştirildi: flavor=$envFlavor, platform=$platformName');
  } catch (e) {
    _log('⚠️ Crashlytics setCustomKey hatası: $e');
  }

  // AdMob ve UMP Consent Başlatma
  _initAdMobAndUmp();

  // Kupon açma kredisi motorunu başlat
  CouponCreditService.instance.initialize().catchError((e) {
    _log('⚠️ CouponCreditService başlatma hatası: $e');
  });

  // Connectivity service'i başlat
  ConnectivityService().initialize().catchError((e) {
    _log('⚠️ ConnectivityService başlatma hatası: $e');
  });

  // Kanalları ve bildirim dinleyicilerini arka planda önyükle
  if (!kIsWeb) {
    final notifService = NotificationService();
    notifService.initializeLocalNotifications().then((_) {
      notifService.setupNotificationListeners();
      _log('✅ Bildirim kanalları ve dinleyicileri önyüklendi');
    }).catchError((e) {
      _log('⚠️ Kanal ve dinleyici önyükleme hatası: $e');
    });

    // Dış mağazalardan (Amazon, Trendyol) paylaşılan ürün linklerini yakala
    ShareIntentService.instance.initialize();
  }
}

/// AdMob ve UMP Consent akışını asenkron başlatır
void _initAdMobAndUmp() {
  bool adMobInitialized = false;

  Future<void> initAdMob() async {
    if (adMobInitialized) return;
    adMobInitialized = true;
    try {
      await AdManagerService.instance.initialize();
    } catch (e) {
      _log('⚠️ AdMob başlatma hatası: $e');
    }
  }

  // Güvenlik zaman aşımı: UMP ağ sorgusu 2.5 saniyeyi aşarsa cold-start akışında AdMob'u doğrudan başlat
  Timer(const Duration(milliseconds: 2500), () {
    if (!adMobInitialized) {
      _log('⏱️ UMP Consent zaman aşımı (2.5s), AdMob doğrudan başlatılıyor');
      initAdMob();
    }
  });

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
        await initAdMob();
      },
    );
  } catch (e) {
    _log('⚠️ AdMob/UMP başlatma genel hatası: $e');
    initAdMob();
  }
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
      // Uygulama ön plana geldiğinde uygulama ikonu rozetini senkronize et
      AppBadgeService.instance.syncBadgeWithFirestore();
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
    final isDark = _themeService.isDarkMode;
    final activeTheme = isDark ? darkTheme : lightTheme;
    
    return AnimatedTheme(
      duration: Duration.zero,
      data: activeTheme,
      child: MaterialApp(
        title: 'FIRSATKOLİK',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _themeService.themeMode,
        navigatorKey: navigatorKey,
        navigatorObservers: [
          AnalyticsService.instance.observer,
        ],
        builder: (context, child) {
          return RepaintBoundary(
            key: rootRepaintBoundaryKey,
            child: child ?? const SizedBox.shrink(),
          );
        },
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
        await _notificationService.clearAllSubscriptions();
        await _authService.signOut();
        
        final ctx = navigatorKey.currentContext;
        if (mounted && ctx != null) {
          final messenger = ScaffoldMessenger.of(ctx);
          messenger.removeCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: KeyedSubtree(
                key: UniqueKey(),
                child: const Row(
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
              final messenger = ScaffoldMessenger.of(ctx);
              messenger.removeCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: KeyedSubtree(
                    key: UniqueKey(),
                    child: const Row(
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
        final isPerm = error.toString().contains('permission-denied');
        if (isPerm && FirebaseAuth.instance.currentUser == null) {
          _log('ℹ️ Blocked user listener çıkış sırasında kapandı (beklenen)');
          return; // Çıkış sırasındaki beklenen hata, yeniden başlatma
        }
        _log('❌ Blocked user listener hatası: $error');
        SystemLogService.instance.logError(
          category: 'stream_listener',
          errorType: 'MainBlockedUserListenerException',
          message: error.toString(),
          severity: SystemErrorSeverity.error,
        );
        // Gerçek hata durumunda listener'ı yeniden başlatmayı dene
        Future.delayed(const Duration(seconds: 5), () {
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

      await _notificationService.initializeForUser(userId: userId, isAdmin: isAdmin);
      
      // Canlı rozet senkronizasyonunu başlat ve mevcut durumu çek
      AppBadgeService.instance.startRealtimeBadgeSync(userId);
      AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: userId);
      
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
              AnalyticsService.instance.setUser(currentUser.uid);
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
          // Kullanıcı henüz tespit edilmediyse de doğrudan HomeScreen gösterilir (loading noktası ve flicker engellenir)
          return const HomeScreen();
        }
        
        // Hata durumu
        if (snapshot.hasError) {
          _log('Auth error: ${snapshot.error}');
          // Hata olsa bile mevcut kullanıcıyı kontrol et
          final currentUser = _authService.currentUser;
          if (currentUser != null) {
            if (_lastUserId != currentUser.uid) {
              _lastUserId = currentUser.uid;
              AnalyticsService.instance.setUser(currentUser.uid);
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
            AnalyticsService.instance.setUser(currentUserId);
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
            AnalyticsService.instance.setUser(currentUser.uid);
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
          _blockedUserListener?.cancel();
          _blockedUserListener = null;
          AnalyticsService.instance.setUser(null);
          AppBadgeService.instance.stopRealtimeBadgeSync();
          AppBadgeService.instance.clearBadge();
        }
        _lastUserId = null;
        _log('No user logged in (Guest Mode Active)');
        return const HomeScreen();
      },
    );
  }
}

