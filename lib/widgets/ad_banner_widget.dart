import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';

void _log(String message) {
  if (kDebugMode) print(message);
}

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
  int _retryCount = 0; // Retry sayacı (exponential backoff için)
  static const int _maxRetries = 2; // Maksimum 2 deneme (daha hızlı)
  DateTime? _loadStartTime; // Load başlangıç zamanı (timeout için)
  Timer? _timeoutTimer; // Timeout timer'ı

  @override
  void initState() {
    super.initState();
    // Reklamı hemen yüklemeye başla (gecikme yok)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAd();
    });
  }

  void _loadAd() {
    _loadStartTime = DateTime.now();
    _log('🔄 Reklam yükleniyor... Ad Unit ID: ${widget.adUnitId}');
    _log('   Ad Size: ${widget.adSize.width}x${widget.adSize.height}');
    if (_retryCount > 0) {
      _log('   Deneme: $_retryCount/$_maxRetries');
    }
    
    // Önceki timeout timer'ı iptal et
    _timeoutTimer?.cancel();
    
    // Timeout kontrolü (5 saniye - daha hızlı)
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isAdLoaded && _bannerAd != null) {
        _log('⏱️ Reklam yükleme timeout (5 saniye)');
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
      request: const AdRequest(
        // Performans optimizasyonları
        keywords: <String>[], // Boş keywords daha hızlı yüklenir
      ),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          final loadTime = _loadStartTime != null 
              ? DateTime.now().difference(_loadStartTime!).inMilliseconds 
              : 0;
          _log('✅ Banner reklam başarıyla yüklendi!');
          _log('   Reklam boyutu: ${_bannerAd?.size.width}x${_bannerAd?.size.height}');
          _log('   Yüklenme süresi: ${loadTime}ms');
          _retryCount = 0; // Başarılı yüklemede retry sayacını sıfırla
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          _log('❌ Banner reklam yüklenemedi!');
          _log('   Ad Unit ID: ${widget.adUnitId}');
          _log('   Hata Kodu: ${error.code}');
          _log('   Hata Mesajı: ${error.message}');
          _log('   Etki Alanı: ${error.domain}');
          if (error.responseInfo != null) {
            _log('   Response ID: ${error.responseInfo?.responseId}');
            _log('   Mediation Adapter: ${error.responseInfo?.mediationAdapterClassName}');
          }
          
          // Test ad unit ID kontrolü
          final isTestAd = widget.adUnitId.contains('3940256099942544');
          
          // Hesap onaylanmamış hatası (kod 3) için özel mesaj
          if (error.code == 3) {
            if (isTestAd) {
              _log('⚠️ TEST REKLAM HATASI: Test ad unit ID kullanılıyor ancak hata kodu 3.');
              _log('   Bu, AndroidManifest.xml\'deki gerçek App ID\'nin hesap durumuyla ilgili olabilir.');
              _log('   Test reklamları için genellikle bu hata görülmez.');
              _log('   Çözüm: Emülatörü yeniden başlatmayı deneyin veya gerçek cihazda test edin.');
            } else {
              _log('⚠️ AdMob hesabı henüz onaylanmadı. Lütfen AdMob konsolundan hesap durumunu kontrol edin.');
              _log('   Hesap onaylanması 1-2 gün sürebilir. Onaylandıktan sonra reklamlar otomatik olarak gösterilecektir.');
            }
          }
          
          if (isTestAd) {
            _log('ℹ️ Test ad unit ID kullanılıyor: ${widget.adUnitId}');
            _log('   Test reklamları her zaman yüklenmelidir.');
            _log('   Sorun devam ederse:');
            _log('   1. Emülatörü yeniden başlatın');
            _log('   2. Google Play Services\'in güncel olduğundan emin olun');
            _log('   3. İnternet bağlantısını kontrol edin');
          }
          
          ad.dispose();
          _bannerAd = null;
          
          // Exponential backoff stratejisi ile tekrar deneme (daha hızlı)
          if (_retryCount < _maxRetries) {
            _retryCount++;
            // Daha kısa delay'ler: 1s, 2s (toplam 3 saniye bekleme)
            final delaySeconds = _retryCount;
            _log('🔄 Reklam yükleme tekrar deneniyor... ($_retryCount/$_maxRetries - ${delaySeconds}s sonra)');
            
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (mounted && _bannerAd == null) {
                _loadAd();
              }
            });
          } else {
            _log('❌ Maksimum deneme sayısına ulaşıldı ($_maxRetries). Reklam yükleme durduruldu.');
            _retryCount = 0; // Reset counter
          }
          
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
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
    _timeoutTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reklam yüklenene kadar minimal loading göster (daha hızlı görünüm)
    if (!_isAdLoaded || _bannerAd == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[100], // Daha açık renk
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.grey[400]!,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white, // Reklam yüklenene kadar beyaz arka plan
      child: FittedBox(
        fit: BoxFit.contain, // Reklamı bozmadan kart içine sığdır
        alignment: Alignment.center,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}

