import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_manager_service.dart';
import '../services/analytics_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'skeletons/shimmer_box.dart';

void _log(String message) {
  if (kDebugMode) print('📢 [AdNativeWidget] $message');
}

/// FırsatKolik — Google AdMob Native Ads Advanced (Yerel Akış Reklamı) Bileşeni
///
/// Hem 2 sütunlu dikey GridView (`CardViewMode.vertical`) hem de tek sütunlu yatay ListView (`CardViewMode.horizontal`)
/// modlarında ürün kartlarıyla milimetrik uyumlu, %100 AdMob politika uyumlu ve yüksek eCPM'li ($1.50 - $3.50)
/// yerel reklam gösterimi sağlar.
class AdNativeWidget extends StatefulWidget {
  final CardViewMode viewMode;
  final String adUnitId;
  final Widget Function(BuildContext context)? fallbackBuilder;
  final String? placement;

  const AdNativeWidget({
    super.key,
    required this.viewMode,
    required this.adUnitId,
    this.fallbackBuilder,
    this.placement,
  });

  @override
  State<AdNativeWidget> createState() => _AdNativeWidgetState();
}

class _AdNativeWidgetState extends State<AdNativeWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;
  int _retryCount = 0;
  static const int _maxRetries = 1;
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
    if (!adManager.isAdsEnabled || !adManager.nativeEnabled) {
      if (_nativeAd != null) {
        _nativeAd?.dispose();
        _nativeAd = null;
      }
      if (_isAdLoaded) {
        setState(() {
          _isAdLoaded = false;
          _isAdFailed = true;
        });
      }
    } else if (_nativeAd == null && !_isAdLoaded && !_isAdFailed) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final adManager = AdManagerService.instance;
    if (!adManager.isAdsEnabled || !adManager.nativeEnabled) {
      _log('🚫 Reklamlar genel şalter veya native şalteriyle kapatılmış durumda');
      if (mounted) {
        setState(() {
          _isAdFailed = true;
        });
      }
      return;
    }

    // 1. AdMob SDK'nın başlatılmasını bekle (Cold-start yarış durumunu ve boş kalmayı kesin olarak çözer)
    if (!adManager.isInitialized) {
      _log('⏳ AdMob SDK henüz başlatılmadı, başlatma bekleniyor...');
      final ready = await adManager.waitForInitialization.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      if (!ready || !mounted) {
        _log('⚠️ AdMob SDK başlatma zaman aşımı veya unmounted, fallback devreye alınıyor');
        if (mounted) {
          setState(() {
            _isAdFailed = true;
          });
        }
        return;
      }
    }

    if (!adManager.canRequestAd(widget.adUnitId)) {
      _log('⏳ ${widget.adUnitId} için soğuma süresi bekleniyor, istek atlanıyor');
      if (mounted) {
        setState(() {
          _isAdFailed = true;
        });
      }
      return;
    }

    _loadStartTime = DateTime.now();
    _log('🔄 Native Ad yükleniyor... Unit: ${widget.adUnitId} | Mode: ${widget.viewMode.name}');

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_isAdLoaded && _nativeAd != null) {
        _log('⏱️ Native Ad yükleme zaman aşımı (8 saniye) → Fallback tetikleniyor');
        _nativeAd?.dispose();
        _nativeAd = null;
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
            _isAdFailed = true;
          });
        }
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final templateStyle = NativeTemplateStyle(
      templateType: widget.viewMode == CardViewMode.horizontal
          ? TemplateType.small
          : TemplateType.medium,
      mainBackgroundColor: surfaceColor,
      cornerRadius: 16.0,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        backgroundColor: AppTheme.primary,
        style: NativeTemplateFontStyle.bold,
        size: 12.0,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? Colors.white : AppTheme.textPrimary,
        style: NativeTemplateFontStyle.bold,
        size: 13.0,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? Colors.grey[400] : AppTheme.textSecondary,
        style: NativeTemplateFontStyle.normal,
        size: 11.0,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: isDark ? Colors.grey[500] : Colors.grey[600],
        style: NativeTemplateFontStyle.normal,
        size: 10.0,
      ),
    );

    // iOS platformunda Google'ın GADTSmallTemplateView.xib kısıtlarını (0.25 media width ve subpixel
    // AutoLayout taşması) aşmak için kurumsal standart olan FLTNativeAdFactory (firsatkolik_native_ad_factory)
    // kullanılır. Android tarafında ise sorunsuz çalışan NativeTemplateStyle mimarisi korunur.
    final String? factoryId = isIOS ? 'firsatkolik_native_ad_factory' : null;
    final NativeTemplateStyle? nativeStyle = isIOS ? null : templateStyle;
    final Map<String, Object>? customOpts = isIOS ? <String, Object>{'isDark': isDark} : null;

    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      factoryId: factoryId,
      nativeTemplateStyle: nativeStyle,
      customOptions: customOpts,
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.landscape,
        videoOptions: VideoOptions(
          startMuted: true,
          clickToExpandRequested: false,
          customControlsRequested: false,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _timeoutTimer?.cancel();
          final loadTime = _loadStartTime != null
              ? DateTime.now().difference(_loadStartTime!).inMilliseconds
              : 0;
          _log('✅ Native Ad başarıyla yüklendi (${loadTime}ms)');
          adManager.recordAdSuccess(widget.adUnitId);
          _retryCount = 0;

          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _isAdFailed = false;
            });

            // Android PlatformView (SurfaceTexture) ilk kare uyandırma tetikleyicisi
            // Native Ad yüklendiğinde render katmanını tazeleyerek boş (blank) kalmasını önler
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
              }
            });
          }
        },
        onPaidEvent: (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
          adManager.handlePaidEvent(
            adUnitId: widget.adUnitId,
            adFormat: 'native',
            valueMicros: valueMicros,
            precision: precision,
            currencyCode: currencyCode,
            responseInfo: _nativeAd?.responseInfo,
          );
        },
        onAdFailedToLoad: (ad, error) {
          _timeoutTimer?.cancel();
          _log('❌ Native Ad yüklenemedi: [${error.code}] ${error.message}');
          adManager.recordAdFailure(widget.adUnitId, error);
          ad.dispose();
          _nativeAd = null;

          if (error.code != 3 && _retryCount < _maxRetries) {
            _retryCount++;
            _log('🔄 Native Ad yükleme 15 saniye sonra tekrar denenecek...');
            Future.delayed(const Duration(seconds: 15), () {
              if (mounted && _nativeAd == null) {
                _loadAd();
              }
            });
          } else {
            _retryCount = 0;
          }

          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _isAdFailed = true;
            });
          }
        },
        onAdClicked: (ad) {
          _log('👆 Native Ad tıklandı');
          AnalyticsService.instance.logAdClick(
            adUnitId: widget.adUnitId,
            adFormat: 'native',
          );
          AnalyticsService.instance.logCustomEvent('sponsored_native_ad_click', {
            'placement': widget.placement ?? widget.viewMode.name,
            'ad_unit_id': widget.adUnitId,
          });
        },
        onAdImpression: (ad) {
          _log('👁️ Native Ad gösterildi');
          AnalyticsService.instance.logCustomEvent('sponsored_native_ad_impression', {
            'placement': widget.placement ?? widget.viewMode.name,
            'ad_unit_id': widget.adUnitId,
          });
        },
      ),
    );

    _nativeAd?.load();
  }

  @override
  void dispose() {
    AdManagerService.instance.removeListener(_onAdSettingsChanged);
    _timeoutTimer?.cancel();
    _nativeAd?.dispose();
    _nativeAd = null;
    super.dispose();
  }

  Widget _buildSkeleton(BuildContext context, bool isDark) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final double cardHeight = isIOS ? 142.0 : 126.0;
    final double mediaBoxSize = isIOS ? 120.0 : 90.0;

    if (widget.viewMode == CardViewMode.horizontal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: cardHeight,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            ShimmerBox(width: mediaBoxSize, height: mediaBoxSize, borderRadius: 12),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBox(width: 140, height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(width: 200, height: 10, borderRadius: 4),
                  SizedBox(height: 12),
                  ShimmerBox(width: 80, height: 26, borderRadius: 20),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1),
            width: 1.0,
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 14),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 100, height: 12, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: 70, height: 10, borderRadius: 4),
                    Spacer(),
                    ShimmerBox(width: double.infinity, height: 26, borderRadius: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    // Android platform view unclipped framing: height: 126, iOS 120x120 MediaView framing: 142
    final double cardHeight = isIOS ? 142.0 : 126.0; // height: 126
    final double innerHeight = isIOS ? 140.0 : 124.0;

    // Reklam yüklenememişse veya devre dışıysa fallback builder çağrılır
    if (_isAdFailed || (!AdManagerService.instance.isAdsEnabled || !AdManagerService.instance.nativeEnabled)) {
      if (widget.fallbackBuilder != null) {
        return widget.fallbackBuilder!(context);
      }
      return const SizedBox.shrink();
    }

    // Reklam henüz yükleniyorsa skeleton placeholder gösterilir
    if (!_isAdLoaded || _nativeAd == null) {
      return _buildSkeleton(context, isDark);
    }

    final cardBorderColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1);

    if (widget.viewMode == CardViewMode.horizontal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: cardHeight,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          height: innerHeight,
          child: AdWidget(
            key: ValueKey('ad_widget_${widget.adUnitId}_${_nativeAd.hashCode}'),
            ad: _nativeAd!,
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox.expand(
          child: AdWidget(
            key: ValueKey('ad_widget_${widget.adUnitId}_${_nativeAd.hashCode}'),
            ad: _nativeAd!,
          ),
        ),
      );
    }
  }
}
