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

class _AdNativeWidgetState extends State<AdNativeWidget>
    with AutomaticKeepAliveClientMixin<AdNativeWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 1;
  DateTime? _loadStartTime;
  Timer? _timeoutTimer;
  bool _isDisposed = false;

  // FS-27: Sınırlı Keep-Alive Havuzu (Bounded KeepAlive Pool - Azami 5 Aktif Reklam)
  // Uzun liste kaydırmalarında sınırsız Native PlatformView birikimini engelleyerek
  // düşük RAM'li Android/iOS cihazlarda OOM (Out Of Memory) çökmesini %100 önler.
  static final List<_AdNativeWidgetState> _activeAdsPool = [];
  static const int _maxConcurrentActiveAds = 5;
  bool _isKeepAliveGranted = false;

  void _grantKeepAlive() {
    if (_isDisposed || !mounted || !_isAdLoaded) return;
    if (!_isKeepAliveGranted) {
      _isKeepAliveGranted = true;
      _activeAdsPool.remove(this);
      _activeAdsPool.add(this);
      if (_activeAdsPool.length > _maxConcurrentActiveAds) {
        final oldest = _activeAdsPool.removeAt(0);
        oldest._revokeKeepAlive();
      }
      updateKeepAlive();
    } else {
      _activeAdsPool.remove(this);
      _activeAdsPool.add(this);
    }
  }

  void _revokeKeepAlive() {
    if (_isKeepAliveGranted) {
      _isKeepAliveGranted = false;
      if (mounted && !_isDisposed) {
        updateKeepAlive();
      }
    }
  }

  void _touchKeepAlive() {
    if (!_isDisposed && _isAdLoaded) {
      if (_isKeepAliveGranted) {
        _activeAdsPool.remove(this);
        _activeAdsPool.add(this);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed && _isAdLoaded) {
            _grantKeepAlive();
          }
        });
      }
    }
  }

  @override
  bool get wantKeepAlive => _isAdLoaded && !_isDisposed && _isKeepAliveGranted;

  @override
  void initState() {
    super.initState();
    AdManagerService.instance.addListener(_onAdSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) _loadAd();
    });
  }

  @override
  void didUpdateWidget(AdNativeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adUnitId != oldWidget.adUnitId || widget.viewMode != oldWidget.viewMode) {
      _timeoutTimer?.cancel();
      _isKeepAliveGranted = false;
      _activeAdsPool.remove(this);
      final adToDispose = _nativeAd;
      _nativeAd = null;
      _isAdLoaded = false;
      _isAdFailed = false;
      _isLoading = false;
      _retryCount = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          adToDispose?.dispose();
        } catch (_) {}
      });
      _loadAd();
    }
  }

  void _onAdSettingsChanged() {
    if (!mounted || _isDisposed) return;
    final adManager = AdManagerService.instance;
    if (!adManager.isAdsEnabled || !adManager.nativeEnabled) {
      _timeoutTimer?.cancel();
      _isLoading = false;
      _isKeepAliveGranted = false;
      _activeAdsPool.remove(this);
      final adToDispose = _nativeAd;
      _nativeAd = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          adToDispose?.dispose();
        } catch (_) {}
      });
      if (_isAdLoaded) {
        setState(() {
          _isAdLoaded = false;
          _isAdFailed = true;
        });
      }
    } else if (_nativeAd == null && !_isAdLoaded && !_isAdFailed && !_isLoading) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    // 0. Atomic eşzamanlılık ve mükerrer yükleme kilidi (Cold-start yarış durumunu ve boş kalmayı kesin önler)
    if (_isLoading || _isAdLoaded || !mounted) {
      _log('⏭️ _loadAd atlandı: isLoading=$_isLoading, isAdLoaded=$_isAdLoaded, mounted=$mounted');
      return;
    }

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

    _isLoading = true;

    // 1. AdMob SDK'nın başlatılmasını bekle (Cold-start yarış durumunu ve boş kalmayı kesin olarak çözer)
    if (!adManager.isInitialized) {
      _log('⏳ AdMob SDK henüz başlatılmadı, başlatma bekleniyor...');
      final ready = await adManager.waitForInitialization.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      if (!ready || !mounted) {
        _log('⚠️ AdMob SDK başlatma zaman aşımı veya unmounted, fallback devreye alınıyor');
        _isLoading = false;
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
      _isLoading = false;
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
      if (mounted && !_isDisposed && !_isAdLoaded && _nativeAd != null) {
        _log('⏱️ Native Ad yükleme zaman aşımı (8 saniye) → Fallback tetikleniyor');
        final adToDispose = _nativeAd;
        _nativeAd = null;
        _isLoading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            adToDispose?.dispose();
          } catch (_) {}
        });
        if (mounted && !_isDisposed) {
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

    late final NativeAd adInstance;
    adInstance = NativeAd(
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
          _isLoading = false;

          // Eğer bu callback anında ad örneği güncel aktif adInstance değilse veya widget unmount olduysa dispose et
          if (!mounted || _isDisposed || ad != adInstance) {
            _log('⚠️ Eski veya geçersiz ad örneği yüklendi, güvenle temizleniyor');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                ad.dispose();
              } catch (_) {}
            });
            return;
          }

          final loadTime = _loadStartTime != null
              ? DateTime.now().difference(_loadStartTime!).inMilliseconds
              : 0;
          _log('✅ Native Ad başarıyla yüklendi (${loadTime}ms)');
          adManager.recordAdSuccess(widget.adUnitId);
          _retryCount = 0;

          if (mounted && !_isDisposed) {
            setState(() {
              _nativeAd = adInstance;
              _isAdLoaded = true;
              _isAdFailed = false;
            });
            _grantKeepAlive();
          }
        },
        onPaidEvent: (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
          adManager.handlePaidEvent(
            adUnitId: widget.adUnitId,
            adFormat: 'native',
            valueMicros: valueMicros,
            precision: precision,
            currencyCode: currencyCode,
            responseInfo: adInstance.responseInfo,
          );
        },
        onAdFailedToLoad: (ad, error) {
          _timeoutTimer?.cancel();
          _isLoading = false;
          _log('❌ Native Ad yüklenemedi: [${error.code}] ${error.message}');
          adManager.recordAdFailure(widget.adUnitId, error);
          if (adInstance == _nativeAd) {
            _nativeAd = null;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              ad.dispose();
            } catch (_) {}
          });

          if (error.code != 3 && _retryCount < _maxRetries) {
            _retryCount++;
            _log('🔄 Native Ad yükleme 15 saniye sonra tekrar denenecek...');
            Future.delayed(const Duration(seconds: 15), () {
              if (mounted && !_isDisposed && _nativeAd == null && !_isLoading) {
                _loadAd();
              }
            });
          } else {
            _retryCount = 0;
          }

          if (mounted && !_isDisposed) {
            _isKeepAliveGranted = false;
            _activeAdsPool.remove(this);
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

    _nativeAd = adInstance;
    adInstance.load();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isKeepAliveGranted = false;
    _activeAdsPool.remove(this);
    AdManagerService.instance.removeListener(_onAdSettingsChanged);
    _timeoutTimer?.cancel();
    _isLoading = false;
    final adToDispose = _nativeAd;
    _nativeAd = null;
    _isAdLoaded = false;
    super.dispose();
    // NativeAd nesnesi, widget ağacı ve Android platform view katmanı tamamen unmount
    // edildikten sonra post-frame callback içinde güvenle dispose edilir.
    // Bu sayede RenderAndroidView._sizePlatformView ve ViewGroup$LayoutParams.width null çökmesi %100 önlenir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        adToDispose?.dispose();
      } catch (e) {
        if (kDebugMode) print('⚠️ Safe Ad dispose exception: $e');
      }
    });
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
    super.build(context);
    _touchKeepAlive();
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

    // Reklam henüz yükleniyorsa veya dispose aşamasındaysa skeleton placeholder gösterilir
    if (!_isAdLoaded || _nativeAd == null || _isDisposed) {
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Android PlatformView'e sıfır veya negatif genişlik gönderilmesi NullPointerException fırlatır
            if (constraints.maxWidth <= 0) {
              return _buildSkeleton(context, isDark);
            }
            return SizedBox(
              width: constraints.maxWidth,
              height: innerHeight,
              child: AdWidget(
                key: ValueKey('ad_widget_${widget.adUnitId}_${_nativeAd.hashCode}'),
                ad: _nativeAd!,
              ),
            );
          },
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Unconstrained veya sıfır boyutlu grid render aşamalarında platform view çökmesini önler
            if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
              return _buildSkeleton(context, isDark);
            }
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: AdWidget(
                key: ValueKey('ad_widget_${widget.adUnitId}_${_nativeAd.hashCode}'),
                ad: _nativeAd!,
              ),
            );
          },
        ),
      );
    }
  }
}
