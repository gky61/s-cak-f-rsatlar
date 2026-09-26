import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../main.dart'; // navigatorKey
import 'auth_service.dart';
import 'firestore_service.dart';
import '../utils/deal_url_detector.dart';
import '../screens/submit_deal_screen.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../widgets/deal_restriction_bottom_sheet.dart';

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

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription? _intentSub;
  Timer? _pendingCheckTimer;
  String? _pendingUrl;
  bool _isInitialized = false;
  bool _isNavigating = false;

  String? _lastHandledUrl;
  DateTime? _lastHandledTime;

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

  /// Gelen paylaşılan medya listesini analiz eder ve URL'i işleme alır.
  void handleSharedMedia(List<SharedMediaFile> files, {bool isColdStart = false}) {
    if (files.isEmpty) return;

    final sharedText = files.first.path;
    _log('📥 Paylaşılan ham veri: $sharedText (coldStart: $isColdStart)');

    final url = DealUrlDetector.extractUrl(sharedText);
    if (url == null || url.trim().isEmpty) {
      _log('⚠️ Paylaşılan metinde geçerli bir HTTP/HTTPS linki bulunamadı.');
      // Geçersiz içerik için native intent kuyruğunu sıfırla ki takılı kalmasın
      ReceiveSharingIntent.instance.reset();
      return;
    }

    _log('🎯 Ayıklanan URL: $url');

    // Mükerrer tetikleme koruması: Aynı URL son 3 saniye içinde işlendiyse atla
    final now = DateTime.now();
    if (_lastHandledUrl == url &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(milliseconds: 3000)) {
      _log('⚠️ Mükerrer paylaşım linki engellendi (Debounce 3s): $url');
      return;
    }

    _pendingUrl = url.trim();
    _startPendingShareCheck(isColdStart: isColdStart);
  }

  /// Navigator ve Firebase Auth oturum durumu hazır olana kadar kuyruğu kontrol eder.
  void _startPendingShareCheck({bool isColdStart = false}) {
    _pendingCheckTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 60; // 60 * 150ms = 9 saniye tavan kontrol süresi

    // Warm start durumunda sistem zaten hazırsa 0 ms gecikmeyle ilk kontrolde anında açılır.
    _pendingCheckTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) async {
      attempts++;
      final navigatorState = navigatorKey.currentState;
      final currentUser = _authService.currentUser;

      // Soğuk başlangıçta Firebase Auth'un yerel depolamadan kullanıcıyı yüklemesi 100-300ms sürer.
      // Bu yüzden ilk birkaç denemede hemen "misafir" varsaymayıp auth'un yerleşmesini bekliyoruz.
      final bool isAuthSettled = currentUser != null || attempts >= 10;
      final bool isReady = navigatorState != null && isAuthSettled;

      if (isReady) {
        timer.cancel();
        _pendingCheckTimer = null;

        if (_pendingUrl != null && !_isNavigating) {
          final targetUrl = _pendingUrl!;
          _log('🚀 Navigator ve Oturum hazır (Deneme: $attempts, coldStart: $isColdStart). Yönlendirme icra ediliyor: $targetUrl');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _executeNavigation(targetUrl);
          });
        }
      } else if (attempts >= maxAttempts) {
        timer.cancel();
        _pendingCheckTimer = null;
        _log('⚠️ ShareIntentService zaman aşımı ($maxAttempts deneme): Navigator veya Oturum hazır hale gelmedi.');
        _pendingUrl = null;
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  /// Hedef URL ile SubmitDealScreen ekranına yönlendirmeyi icra eder.
  Future<void> _executeNavigation(String url) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      final navState = navigatorKey.currentState;
      final navContext = navigatorKey.currentContext;

      if (navState == null || navContext == null) {
        _log('❌ Navigator context bulunamadı.');
        _isNavigating = false;
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
        return;
      }

      // 2. Sistem Şalteri ve Kullanıcı Ban Kontrolü
      final results = await Future.wait([
        _firestoreService.isDealSharingEnabled(),
        _firestoreService.isUserDealBanned(user.uid),
      ]);

      final isSharingEnabled = results[0];
      final isDealBanned = results[1];

      final currentContext = navigatorKey.currentContext;
      if (currentContext == null || !currentContext.mounted) {
        _isNavigating = false;
        return;
      }

      if (!isSharingEnabled) {
        _log('⛔ Fırsat paylaşımı sistem genelinde devre dışı.');
        _isNavigating = false;
        showDealSharingDisabledBottomSheet(currentContext);
        ReceiveSharingIntent.instance.reset();
        _pendingUrl = null;
        return;
      }

      if (isDealBanned) {
        _log('🚫 Kullanıcının fırsat paylaşım yetkisi kısıtlanmış.');
        _isNavigating = false;
        showDealBannedBottomSheet(currentContext);
        ReceiveSharingIntent.instance.reset();
        _pendingUrl = null;
        return;
      }

      // 3. Başarılı Yönlendirme İcrası
      _lastHandledUrl = url;
      _lastHandledTime = DateTime.now();
      _pendingUrl = null;

      _log('🎉 SubmitDealScreen ekranına yönlendiriliyor: $url');
      await navState.push(
        MaterialPageRoute(
          builder: (_) => SubmitDealScreen(initialUrl: url),
        ),
      );

      // Yalnızca işlem başarıyla tamamlandıktan sonra native kuyruğu sıfırla
      ReceiveSharingIntent.instance.reset();
    } catch (e) {
      _log('❌ Paylaşım yönlendirme hatası: $e');
    } finally {
      _isNavigating = false;
    }
  }

  /// Servisi temizler (Uygulama sonlanırken)
  void dispose() {
    _pendingCheckTimer?.cancel();
    _intentSub?.cancel();
    _isInitialized = false;
    _isNavigating = false;
  }
}
