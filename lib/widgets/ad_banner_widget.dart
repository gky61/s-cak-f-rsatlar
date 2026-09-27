import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import '../services/ad_manager_service.dart';
import '../services/analytics_service.dart';

void _log(String message) {
  if (kDebugMode) print('📢 [AdBannerWidget] $message');
}

/// [DEPRECATED - FAZ 3.3]: Akış içi banner reklamlar tamamen kaldırılmış ve
/// yerini yüksek eCPM ($1.50 - $3.50) üreten, 2 sütunlu ve yatay modlara %100 uyumlu
/// [AdNativeWidget] mimarisine bırakmıştır.
@Deprecated('Faz 3.3 kapsamında akış içi banner reklamlar AdNativeWidget formatına taşınmıştır.')
class AdBannerWidget extends StatefulWidget {
  final String adUnitId;
  final AdSize adSize;

  const AdBannerWidget({
    super.key,
    required this.adUnitId,
    this.adSize = AdSize.banner,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 1; // Sadece 1 kontrollü tekrar deneme
  DateTime? _loadStartTime;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    AdManagerService.instance.addListener(_onAdSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAd();
    });
  }

  void _onAdSettingsChanged() {
    if (!mounted) return;
    final adManager = AdManagerService.instance;
    if (!adManager.isAdsEnabled || !adManager.bannerEnabled) {
      if (_bannerAd != null) {
        _bannerAd?.dispose();
        _bannerAd = null;
      }
      if (_isAdLoaded) {
        setState(() {
          _isAdLoaded = false;
        });
      }
    } else if (_bannerAd == null && !_isAdLoaded) {
      _loadAd();
    }
  }

  void _loadAd() {
    final adManager = AdManagerService.instance;
    if (!adManager.isAdsEnabled || !adManager.bannerEnabled) {
      _log('🚫 Reklamlar genel şalter veya banner şalteriyle kapatılmış durumda');
      return;
    }

    if (!adManager.canRequestAd(widget.adUnitId)) {
      _log('⏳ ${widget.adUnitId} için soğuma süresi bekleniyor, istek atlanıyor');
      return;
    }

    _loadStartTime = DateTime.now();
    _log('🔄 Banner yükleniyor... Unit: ${widget.adUnitId} | Size: ${widget.adSize.width}x${widget.adSize.height}');

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_isAdLoaded && _bannerAd != null) {
        _log('⏱️ Banner yükleme zaman aşımı (8 saniye)');
        _bannerAd?.dispose();
        _bannerAd = null;
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
          });
        }
      }
    });

    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          final loadTime = _loadStartTime != null
              ? DateTime.now().difference(_loadStartTime!).inMilliseconds
              : 0;
          _log('✅ Banner başarıyla yüklendi (${loadTime}ms)');
          adManager.recordAdSuccess(widget.adUnitId);
          _retryCount = 0;

          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onPaidEvent: (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
          adManager.handlePaidEvent(
            adUnitId: widget.adUnitId,
            adFormat: 'banner',
            valueMicros: valueMicros,
            precision: precision,
            currencyCode: currencyCode,
            responseInfo: _bannerAd?.responseInfo,
          );
        },
        onAdFailedToLoad: (ad, error) {
          _log('❌ Banner yüklenemedi: [${error.code}] ${error.message}');
          adManager.recordAdFailure(widget.adUnitId, error);
          ad.dispose();
          _bannerAd = null;

          // Google AdMob kuralları gereği hata kodu 3'te agresif retry yapılmaz
          if (error.code != 3 && _retryCount < _maxRetries) {
            _retryCount++;
            _log('🔄 Reklam yükleme 15 saniye sonra tekrar denenecek...');
            Future.delayed(const Duration(seconds: 15), () {
              if (mounted && _bannerAd == null) {
                _loadAd();
              }
            });
          } else {
            _retryCount = 0;
          }

          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
        },
        onAdClicked: (_) {
          _log('📱 Banner reklam tıklandı');
          AnalyticsService.instance.logAdClick(
            adUnitId: widget.adUnitId,
            adFormat: 'banner',
          );
        },
        onAdOpened: (_) => _log('📱 Banner reklam açıldı'),
        onAdClosed: (_) => _log('❌ Banner reklam kapatıldı'),
        onAdImpression: (_) => _log('👁️ Banner reklam gösterildi (impression)'),
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    AdManagerService.instance.removeListener(_onAdSettingsChanged);
    _timeoutTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdManagerService.instance.isAdsEnabled || !AdManagerService.instance.bannerEnabled) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _bannerAd == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey.withValues(alpha: 0.04),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.withValues(alpha: 0.3)),
            ),
          ),
        ),
      );
    }

    // Google AdMob Politikası Uyumu:
    // Reklam asla ölçeklenerek küçültülmez; reklam gerçek boyutlarında merkezlenerek sunulur.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Center(
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}

