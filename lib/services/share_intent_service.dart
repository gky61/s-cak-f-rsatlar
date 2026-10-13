import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // navigatorKey
import 'auth_service.dart';
import 'notification_service.dart';
import '../utils/deal_url_detector.dart';
import '../screens/submit_deal_screen.dart';
import '../widgets/guest_login_bottom_sheet.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Dış mağazalardan (Amazon, Trendyol, Hepsiburada vb.) paylaşılan ürün linklerini
/// hem Warm Start (arka planda açıkken) hem de Cold Start (uygulama tamamen kapalıyken)
/// senaryolarında kayıpsız, yarış durumsuz (race-condition free) ve profesyonel
/// şekilde yöneten merkezi servis.
class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService instance = ShareIntentService._();

  static const MethodChannel _nativeChannel = MethodChannel('com.sicakfirsatlar.app/share_intent');
  static const String _prefConsumedUrl = 'share_intent_last_consumed_url';
  static const String _prefConsumedTime = 'share_intent_last_consumed_time';
  static const String _prefConsumedUrlList = 'share_intent_consumed_urls_list';
  static const int _maxConsumedUrlsToKeep = 30;

  AuthService get _authService => AuthService();

  StreamSubscription? _intentSub;
  String? _pendingUrl;
  bool _isInitialized = false;
  bool _isNavigating = false;
  int _shareCheckToken = 0;

  String? _lastHandledUrl;
  DateTime? _lastHandledTime;

  /// Android Activity intent'ini nötrler (ACTION_MAIN), böylece Activity yeniden
  /// oluşturulduğunda eski ACTION_SEND intent'i tekrar tetiklenmez.
  Future<void> _clearNativeIntent() async {
    if (kIsWeb) return;
    try {
      await _nativeChannel.invokeMethod('clearIntent');
    } catch (e) {
      _log('⚠️ Native clearIntent çağrısı atlandı: $e');
    }
  }

  /// Native ve Flutter katmanlarındaki paylaşım intent kuyruklarını güvenle sıfırlar.
  Future<void> _resetSafely() async {
    if (kIsWeb) return;
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (e) {
      _log('⚠️ ReceiveSharingIntent reset çağrısı atlandı: $e');
    }
    await _clearNativeIntent();
  }

  /// Fırsat başarıyla paylaşıldığında veya SubmitDealScreen kapatıldığında çağrılır.
  /// URL'i hem diskte kalıcı olarak "tüketildi" (consumed) damgalar hem de Android
  /// Activity intent'ini sıfırlayarak mükerrer açılışları %100 engeller.
  Future<void> markUrlConsumed(String url) async {
    if (url.trim().isEmpty) return;
    final targetUrl = url.trim();
    _lastHandledUrl = targetUrl;
    _lastHandledTime = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefConsumedUrlList) ?? <String>[];
      list.remove(targetUrl);
      list.insert(0, targetUrl);
      if (list.length > _maxConsumedUrlsToKeep) {
        list.removeRange(_maxConsumedUrlsToKeep, list.length);
      }
      await prefs.setStringList(_prefConsumedUrlList, list);
      await prefs.setString(_prefConsumedUrl, targetUrl);
      await prefs.setInt(_prefConsumedTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _log('⚠️ SharedPreferences markUrlConsumed kayıt hatası: $e');
    }

    await _resetSafely();
    _log('🛡️ Paylaşım URL\'i başarıyla tüketildi ve intent temizlendi: $targetUrl');
  }

  /// URL'in daha önce başarıyla paylaşılıp tüketilmediğini diskten denetler.
  Future<bool> _isUrlConsumed(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final target = url.trim();
      final list = prefs.getStringList(_prefConsumedUrlList);
      if (list != null && list.contains(target)) {
        return true;
      }

      final consumedUrl = prefs.getString(_prefConsumedUrl);
      final consumedTimeMs = prefs.getInt(_prefConsumedTime);
      if (consumedUrl != null && consumedTimeMs != null && consumedUrl == target) {
        final consumedTime = DateTime.fromMillisecondsSinceEpoch(consumedTimeMs);
        // Son 24 saat içinde bu URL tüketilmişse ve aynı URL soğuk başlangıçta geliyorsa
        if (DateTime.now().difference(consumedTime) < const Duration(hours: 24)) {
          return true;
        }
      }
    } catch (e) {
      _log('⚠️ SharedPreferences _isUrlConsumed okuma hatası: $e');
    }
    return false;
  }

  /// Servisi başlatır. Hem soğuk başlangıç (getInitialMedia) hem de
  /// canlı dinleme (getMediaStream) kanallarını açar.
  void initialize() {
    if (kIsWeb) return;
    if (_isInitialized) {
      _log('ℹ️ ShareIntentService zaten başlatılmış, tekrar başlatılmıyor.');
      return;
    }
    _isInitialized = true;
    _log('🚀 ShareIntentService başlatılıyor...');

    try {
      // 1. Canlı akış (Uygulama arka plandayken veya açıkken gelen paylaşımlar)
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) {
          if (files.isNotEmpty) {
            _log('📥 [Warm Start] Paylaşım akışından veri yakalandı (${files.length} öğe)');
            handleSharedMedia(files, isColdStart: false);
          }
        },
        onError: (err) {
          _log('❌ ShareIntent getMediaStream hatası: $err');
        },
      );

      // 2. Soğuk başlangıç (Uygulama tamamen kapalıyken paylaşımla açıldığında)
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        if (files.isNotEmpty) {
          _log('📥 [Cold Start] Başlangıç medyasından veri yakalandı (${files.length} öğe)');
          handleSharedMedia(files, isColdStart: true);
        }
      }).catchError((err) {
        _log('❌ ShareIntent getInitialMedia hatası: $err');
      });
    } catch (e) {
      _log('❌ ShareIntentService initialize genel hatası: $e');
    }
  }

  /// Gelen paylaşılan medya listesini analiz eder ve ilk geçerli e-ticaret URL'ini işleme alır.
  Future<void> handleSharedMedia(List<SharedMediaFile> files, {bool isColdStart = false}) async {
    if (files.isEmpty) return;

    // 1. Bildirim Önceliği ve Karşılıklı Dışlama (Mutual Exclusion):
    // Eğer uygulama bir bildirim tıklaması (Cold-Start Push) ile açılıyorsa,
    // eski paylaşım medyasını bastır ve bildirimin (DealDetailScreen) önüne geçmesini engelle!
    if (isColdStart && NotificationService.isColdStartNotificationTapActive) {
      _log('🛡️ [Stale Intent Kalkanı] Bildirimle açılış aktif olduğundan soğuk paylaşım intent\'i bastırıldı.');
      await _resetSafely();
      return;
    }

    // Birden fazla medya (küçük resim + url vb.) paylaşıldığında geçerli URL içeren öğeyi tara
    String? detectedUrl;
    for (final file in files) {
      final rawPath = file.path;
      final url = DealUrlDetector.extractUrl(rawPath);
      if (url != null && url.trim().isNotEmpty) {
        detectedUrl = url.trim();
        _log('📥 Paylaşılan veri içerisinden URL bulundu: $detectedUrl (coldStart: $isColdStart)');
        break;
      }
    }

    if (detectedUrl == null || detectedUrl.isEmpty) {
      _log('⚠️ Paylaşılan metin veya dosyalarda geçerli bir HTTP/HTTPS linki bulunamadı.');
      // Geçersiz içerik için native intent kuyruğunu sıfırla ki takılı kalmasın
      await _resetSafely();
      return;
    }

    final targetUrl = detectedUrl;

    // 2. Soğuk Başlangıçta Tüketilmiş (Stale) Intent Kontrolü:
    // Eğer kullanıcı dışarıdan taze bir paylaşım yapmadıysa (isColdStart == true) ve bu URL
    // daha önce başarıyla paylaşılmış/tüketilmişse, Android OS'un eski intent re-delivery'sidir!
    if (isColdStart) {
      final isConsumed = await _isUrlConsumed(targetUrl);
      if (isConsumed) {
        _log('🛡️ [Stale Intent Kalkanı] Soğuk başlangıçta eski tüketilmiş link yakalandı ve yutuldu: $targetUrl');
        await _resetSafely();
        return;
      }
    }

    // 3. Mükerrer tetikleme koruması: Aynı URL son 3 saniye içinde işlendiyse atla
    final now = DateTime.now();
    if (_lastHandledUrl == targetUrl &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(milliseconds: 3000)) {
      _log('⚠️ Mükerrer paylaşım linki engellendi (Debounce 3s): $targetUrl');
      return;
    }

    _pendingUrl = targetUrl;
    _startPendingShareCheck(isColdStart: isColdStart);
  }

  /// Navigator ve Firebase Auth oturum durumu hazır olduğunda anında yönlendirmeyi tetikler.
  /// Warm Start senaryosunda Navigator ve Auth hazır olduğundan 0 ms gecikmeyle ilk mikrosaniyede açılır.
  /// Cold Start senaryosunda Navigator ilk frame'i çizene kadar (50ms sequential loop) beklenir,
  /// ardından SubmitDealScreen ekranına anında (0 ms ağ beklemesi) geçilir.
  Future<void> _startPendingShareCheck({bool isColdStart = false}) async {
    final int currentToken = ++_shareCheckToken;
    if (_pendingUrl == null || _isNavigating) return;

    // 1. Navigator hazırlığı: Cold start durumunda ilk kare çizilene kadar hafif sequential bekleme
    int attempts = 0;
    const maxAttempts = 60; // 60 * 50ms = 3 saniye tavan emniyet süresi

    while ((navigatorKey.currentState == null ||
            navigatorKey.currentContext == null ||
            !(navigatorKey.currentContext?.mounted ?? false)) &&
           attempts < maxAttempts) {
      if (currentToken != _shareCheckToken || _pendingUrl == null) return;
      attempts++;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (currentToken != _shareCheckToken || _pendingUrl == null || _isNavigating) return;

    // Bekleme esnasında bir bildirim tıklaması devreye girdiyse paylaşım yönlendirmesini iptal et
    if (isColdStart) {
      if (NotificationService.isColdStartNotificationTapActive) {
        _log('🛡️ [Stale Intent Kalkanı] Bekleyen paylaşım kontrolünde bildirim açılışı tespit edildi, yönlendirme iptal edildi.');
        _pendingUrl = null;
        await _resetSafely();
        return;
      }

      // Soğuk başlangıçta bildirim kontrolünün sonucunu kısa bir emniyet payı (handshake) ile bekle
      try {
        final hadNotification = await NotificationService.coldStartNotificationFuture
            .timeout(const Duration(milliseconds: 150), onTimeout: () => false);
        if (hadNotification || NotificationService.isColdStartNotificationTapActive) {
          _log('🛡️ [Stale Intent Kalkanı] Bildirim el sıkışmasında (handshake) bildirim tespit edildi, yönlendirme iptal edildi.');
          _pendingUrl = null;
          await _resetSafely();
          return;
        }
      } catch (_) {}
    }

    final navState = navigatorKey.currentState;
    final navContext = navigatorKey.currentContext;
    if (navState == null || navContext == null || !navContext.mounted) {
      _log('⚠️ ShareIntentService zaman aşımı: Navigator hazır hale gelmedi.');
      _pendingUrl = null;
      await _resetSafely();
      return;
    }

    // 2. Auth durumu hazırlığı: Cold start'ta yerel anahtarlıktan oturumun okunmasını bekle
    var currentUser = _authService.currentUser;
    if (currentUser == null && isColdStart) {
      try {
        currentUser = await _authService.authStateChanges
            .first
            .timeout(const Duration(milliseconds: 350), onTimeout: () => null);
      } catch (_) {}
    }

    if (currentToken != _shareCheckToken || _pendingUrl == null || _isNavigating) return;

    // Hedef URL'i hemen tüket ve kilit koyarak frame aralığında mükerrer kuyruk oluşmasını engelle
    final targetUrl = _pendingUrl!;
    _pendingUrl = null;
    _isNavigating = true;

    _log('🚀 Navigator ve Oturum hazır (Deneme: $attempts, coldStart: $isColdStart, uid: ${currentUser?.uid ?? "guest"}). Yönlendirme icra ediliyor: $targetUrl');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeNavigation(targetUrl);
    });
  }

  /// Hedef URL ile SubmitDealScreen ekranına yönlendirmeyi icra eder.
  Future<void> _executeNavigation(String url) async {
    _isNavigating = true;

    try {
      final navState = navigatorKey.currentState;
      final navContext = navigatorKey.currentContext;

      if (navState == null || navContext == null || !navContext.mounted) {
        _log('❌ Navigator context bulunamadı veya mounted değil.');
        return;
      }

      final user = _authService.currentUser;

      // 1. Misafir Kontrolü
      if (user == null) {
        _log('👤 Misafir kullanıcı tespit edildi, giriş bottom sheet açılıyor.');
        _isNavigating = false;
        showGuestLoginBottomSheet(
          navContext,
          title: 'Fırsat Paylaşmak İçin Giriş Yap! 🚀',
          message: 'Yakaladığın harika fırsatı tüm toplulukla paylaşmak için hızlıca giriş yap.',
          primaryButtonText: '🚀 Google ile Giriş Yap',
          onLoginSuccess: () {
            // Giriş başarılı olunca bekleyen link ile tekrar yönlendirmeyi tetikle
            _executeNavigation(url);
          },
        );
        await _resetSafely();
        return;
      }

      // 2. Başarılı Yönlendirme İcrası:
      // DİKKAT: SubmitDealScreen (lib/screens/submit_deal_screen.dart:214-242) initState'inde
      // _checkDealSharingStatus() metodu ile hem sistem şalterini (isDealSharingEnabled)
      // hem de kullanıcı engelini (isUserDealBanned) ZATEN tam korumalı biçimde paralel sorgulamakta;
      // engel durumunda showDealSharingDisabledBottomSheet veya showDealBannedBottomSheet gösterip
      // ekranı otomatik kapatmaktadır (Navigator.pop).
      // Yönlendirme öncesinde soğuk ağ üzerinden bu iki Firestore sorgusunu beklemek Cold Start'ta
      // kullanıcının anasayfada 2-3 saniye takılmasına (UI jank) yol açıyordu.
      // Bu nedenle SubmitDealScreen ANINDA (0 ms) açılır, kontroller arka planda güvenle işletilir.
      _lastHandledUrl = url;
      _lastHandledTime = DateTime.now();

      _log('🎉 SubmitDealScreen ekranına anında yönlendiriliyor: $url');
      navState.push(
        MaterialPageRoute(
          builder: (_) => SubmitDealScreen(initialUrl: url),
        ),
      );

      // Yönlendirme icra edildikten hemen sonra native intent kuyruğunu ve Android Activity intent'ini sıfırla
      await _resetSafely();
    } catch (e) {
      _log('❌ Paylaşım yönlendirme hatası: $e');
    } finally {
      _isNavigating = false;
    }
  }

  /// Servisi temizler (Uygulama sonlanırken)
  void dispose() {
    _shareCheckToken++;
    _intentSub?.cancel();
    _isInitialized = false;
    _isNavigating = false;
  }
}
