import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../firebase_options.dart';
import 'analytics_service.dart';
import 'coupon_credit_service.dart';

void _log(String message) {
  if (kDebugMode) {
    print('📢 [AdManager] $message');
  }
}

/// FırsatKolik Merkezi AdMob Monetizasyon, Havuz (AdPool) ve Yaşam Döngüsü Servisi
/// 
/// 1. AdMob SDK ve UMP başlatma durumunu yönetir.
/// 2. Tüm reklam formatları (Banner, Interstitial, Native, Rewarded, App Open) için tek merkezdir.
/// 3. onPaidEvent telemetrisi ile reklam gelirini (micro-cents) Firebase Analytics'e iletir (ROAS optimizasyonu).
/// 4. Hata durumlarında akıllı soğuma (cooldown - 20s) uygulayarak AdMob hesap kısıtlamalarını önler.
/// 5. Frekans sınırlaması (Frequency Capping) ile kullanıcı deneyimini korur.
/// 6. Acil Durum Şalteri (Kill-Switch) ile reklamları anında kapatabilir.
class AdManagerService extends ChangeNotifier {
  AdManagerService._internal();
  static final AdManagerService instance = AdManagerService._internal();
  factory AdManagerService() => instance;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Dinamik Reklam Şalteri (Kill-Switch) — Firestore settings/admob üzerinden güncellenir
  bool isAdsEnabled = true;

  // ─── Format Bazlı Şalterler (Web Admin Kontrollü) ─────────────────────
  bool bannerEnabled = true;
  bool rewardedEnabled = true;
  bool nativeEnabled = true;
  bool interstitialEnabled = true;

  // ─── Hata Soğuma (Cooldown) Takibi ───────────────────────────────────────
  final Map<String, DateTime> _lastFailedTime = {};
  Duration _failureCooldown = const Duration(seconds: 25);

  // ─── Interstitial (Geçiş Reklamı) Yönetimi ───────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  DateTime? _lastInterstitialShownTime;
  Duration _interstitialCooldown = const Duration(minutes: 3); // 3 dakikada max 1

  // ─── Firestore Canlı Ayar Dinleyicisi ────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;

  // ─── App Open (Açılış Reklamı) Yönetimi ─────────────────────────────────
  AppOpenAd? _appOpenAd;
  bool _isAppOpenLoading = false;
  DateTime? _appOpenLoadTime;

  /// AdMob SDK Başlatma
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        final configuration = RequestConfiguration(
          testDeviceIds: const <String>[
            '7dc74815-ecce-4731-b631-27ab9c0cbd15', // Android Test Telefonu
            'SIMULATOR', // iOS Simülatör
          ],
        );
        await MobileAds.instance.updateRequestConfiguration(configuration);
        _log('✅ Test cihazları yapılandırıldı');
      }

      final initStatus = await MobileAds.instance.initialize();
      _isInitialized = true;
      _log('✅ AdMob SDK başarıyla başlatıldı: ${initStatus.adapterStatuses.keys.join(", ")}');

      // Arka planda geçiş ve ödüllü reklamları önyükle
      preloadInterstitial();
      preloadRewardedAd();

      // Firestore settings/admob dinleyicisini başlat (Web Admin senkronizasyonu)
      _startFirestoreSettingsListener();
    } catch (e) {
      _log('⚠️ AdMob başlatma hatası: $e');
    }
  }

  /// Reklam isteği atmadan önce soğuma süresini (cooldown) denetler
  bool canRequestAd(String adUnitId) {
    if (!isAdsEnabled) return false;
    final lastFail = _lastFailedTime[adUnitId];
    if (lastFail == null) return true;

    final elapsed = DateTime.now().difference(lastFail);
    if (elapsed < _failureCooldown) {
      _log('⏳ $adUnitId için soğuma süresi aktif (${_failureCooldown.inSeconds - elapsed.inSeconds}s kaldı)');
      return false;
    }
    return true;
  }

  /// Başarısız reklam isteğini kaydeder
  void recordAdFailure(String adUnitId, LoadAdError error) {
    _lastFailedTime[adUnitId] = DateTime.now();
    _log('❌ Reklam yüklenemedi: $adUnitId | Kod: ${error.code} | Mesaj: ${error.message}');
  }

  /// Başarılı reklam isteğinde soğuma kaydını sıfırlar
  void recordAdSuccess(String adUnitId) {
    _lastFailedTime.remove(adUnitId);
  }

  /// AdMob Paid Event (Gelir & Telemetri) Kaydı
  void handlePaidEvent({
    required String adUnitId,
    required String adFormat,
    required double valueMicros,
    required PrecisionType precision,
    required String currencyCode,
    ResponseInfo? responseInfo,
  }) {
    try {
      _log('💰 Paid Event: $adFormat ($adUnitId) -> $valueMicros $currencyCode');
      AnalyticsService.instance.logAdImpression(
        adUnitId: adUnitId,
        adFormat: adFormat,
        valueMicros: valueMicros.toInt(),
        currencyCode: currencyCode,
        precisionType: precision.index,
        adNetwork: responseInfo?.mediationAdapterClassName,
      );
    } catch (e) {
      _log('⚠️ Paid Event kayıt hatası: $e');
    }
  }

  // ===========================================================================
  // INTERSTITIAL (GEÇİŞ REKLAMI) YÖNETİMİ
  // ===========================================================================

  /// Geçiş reklamını arka planda önceden yükler (Pre-load)
  void preloadInterstitial() {
    if (!isAdsEnabled || !interstitialEnabled || _isInterstitialLoading || _interstitialAd != null) return;

    final unitId = DefaultFirebaseOptions.interstitialAdUnitId;
    if (!canRequestAd(unitId)) return;

    _isInterstitialLoading = true;
    _log('🔄 Geçiş reklamı önyükleniyor...');

    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isInterstitialLoading = false;
          _interstitialAd = ad;
          recordAdSuccess(unitId);
          _log('✅ Geçiş reklamı belleğe yüklendi ve hazır');

          ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
            handlePaidEvent(
              adUnitId: unitId,
              adFormat: 'interstitial',
              valueMicros: valueMicros,
              precision: precision,
              currencyCode: currencyCode,
              responseInfo: ad.responseInfo,
            );
          };

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              _log('📱 Geçiş reklamı tam ekranda açıldı');
            },
            onAdDismissedFullScreenContent: (ad) {
              _log('📱 Geçiş reklamı kapatıldı');
              ad.dispose();
              _interstitialAd = null;
              // Bir sonraki gösterim için hemen yenisini önyükle
              preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _log('❌ Geçiş reklamı gösterilemedi: ${error.message}');
              ad.dispose();
              _interstitialAd = null;
              preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _interstitialAd = null;
          recordAdFailure(unitId, error);
        },
      ),
    );
  }

  /// Belirli bir aksiyon sonrasında (Örn: Dış mağaza linkine tıklama) frekans uygunsa gösterir
  bool showInterstitialIfAllowed({VoidCallback? onDismissed}) {
    if (!isAdsEnabled || !interstitialEnabled || _interstitialAd == null) {
      onDismissed?.call();
      preloadInterstitial();
      return false;
    }

    // Frekans kontrolü (cooldown)
    if (_lastInterstitialShownTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialShownTime!);
      if (elapsed < _interstitialCooldown) {
        _log('⏱️ Interstitial frekans limiti aktif (${_interstitialCooldown.inSeconds - elapsed.inSeconds}s kaldı)');
        onDismissed?.call();
        return false;
      }
    }

    _lastInterstitialShownTime = DateTime.now();
    _interstitialAd!.show();
    return true;
  }

  // ===========================================================================
  // REWARDED (ÖDÜLLÜ REKLAM) YÖNETİMİ
  // ===========================================================================

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  /// Ödüllü reklamı arka planda önceden yükler (Pre-load)
  void preloadRewardedAd() {
    if (!isAdsEnabled || !rewardedEnabled || _isRewardedLoading || _rewardedAd != null) return;

    final unitId = DefaultFirebaseOptions.rewardedAdUnitId;
    if (!canRequestAd(unitId)) return;

    _isRewardedLoading = true;
    _log('🔄 Ödüllü reklam önyükleniyor...');

    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isRewardedLoading = false;
          _rewardedAd = ad;
          recordAdSuccess(unitId);
          _log('✅ Ödüllü reklam belleğe yüklendi ve hazır');

          ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
            handlePaidEvent(
              adUnitId: unitId,
              adFormat: 'rewarded',
              valueMicros: valueMicros,
              precision: precision,
              currencyCode: currencyCode,
              responseInfo: ad.responseInfo,
            );
          };

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              _log('📱 Ödüllü reklam tam ekranda açıldı');
            },
            onAdDismissedFullScreenContent: (ad) {
              _log('📱 Ödüllü reklam kapatıldı');
              ad.dispose();
              _rewardedAd = null;
              preloadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _log('❌ Ödüllü reklam gösterilemedi: ${error.message}');
              ad.dispose();
              _rewardedAd = null;
              preloadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          _rewardedAd = null;
          recordAdFailure(unitId, error);
        },
      ),
    );
  }

  /// Ödüllü reklam hazır mı?
  bool get isRewardedAdReady => isAdsEnabled && _rewardedAd != null;

  /// Ödüllü reklamı gösterir ve ödül kazanıldığında callback'i tetikler
  Future<bool> showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
  }) async {
    if (!isAdsEnabled || !rewardedEnabled) {
      _log('⚠️ Reklamlar genel şalterle veya format şalteriyle kapalı.');
      return false;
    }

    if (_rewardedAd == null) {
      _log('⚠️ Ödüllü reklam henüz hazır değil, yükleme tetikleniyor...');
      preloadRewardedAd();
      return false;
    }

    final adToShow = _rewardedAd!;
    _rewardedAd = null;

    adToShow.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _log('📱 Ödüllü reklam açıldı'),
      onAdDismissedFullScreenContent: (ad) {
        _log('📱 Ödüllü reklam kapatıldı');
        ad.dispose();
        onDismissed?.call();
        preloadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log('❌ Ödüllü reklam gösterilemedi: ${error.message}');
        ad.dispose();
        onDismissed?.call();
        preloadRewardedAd();
      },
    );

    await adToShow.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _log('🎉 Kullanıcı ödülü kazandı: ${reward.amount} ${reward.type}');
        onUserEarnedReward(reward);
      },
    );

    return true;
  }

  // ===========================================================================
  // APP OPEN (UYGULAMA AÇILIŞ REKLAMI) YÖNETİMİ
  // ===========================================================================

  /// Açılış reklamını önyükler
  void preloadAppOpenAd() {
    if (!isAdsEnabled || _isAppOpenLoading || _appOpenAd != null) return;

    final unitId = DefaultFirebaseOptions.appOpenAdUnitId;
    if (!canRequestAd(unitId)) return;

    _isAppOpenLoading = true;
    _log('🔄 App Open reklamı önyükleniyor...');

    AppOpenAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isAppOpenLoading = false;
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          recordAdSuccess(unitId);
          _log('✅ App Open reklamı belleğe yüklendi');

          ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
            handlePaidEvent(
              adUnitId: unitId,
              adFormat: 'app_open',
              valueMicros: valueMicros,
              precision: precision,
              currencyCode: currencyCode,
              responseInfo: ad.responseInfo,
            );
          };

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _appOpenAd = null;
              preloadAppOpenAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _appOpenAd = null;
              preloadAppOpenAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isAppOpenLoading = false;
          _appOpenAd = null;
          recordAdFailure(unitId, error);
        },
      ),
    );
  }

  /// Uygulama arka plandan öne geldiğinde App Open reklamını gösterir (4 saatten taze ise)
  void showAppOpenAdIfAvailable() {
    if (!isAdsEnabled || _appOpenAd == null || _appOpenLoadTime == null) {
      preloadAppOpenAd();
      return;
    }

    final isExpired = DateTime.now().difference(_appOpenLoadTime!) > const Duration(hours: 4);
    if (isExpired) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      preloadAppOpenAd();
      return;
    }

    _appOpenAd?.show();
  }

  // ===========================================================================
  // FIRESTORE SETTINGS/ADMOB CANLI SENKRONİZASYON (Web Admin ↔ Mobil Köprüsü)
  // ===========================================================================

  /// Firestore `settings/admob` dokümanını gerçek zamanlı dinler.
  /// Web Admin panelinden yapılan her değişiklik (Kill-Switch, format şalterleri,
  /// cooldown, frekans sınırı, kupon kredileri) mobil uygulamaya anında yansır.
  void _startFirestoreSettingsListener() {
    try {
      _settingsSubscription?.cancel();
      _settingsSubscription = FirebaseFirestore.instance
          .collection('settings')
          .doc('admob')
          .snapshots()
          .listen(
        (snapshot) {
          if (!snapshot.exists) {
            _log('ℹ️ settings/admob dokümanı henüz oluşturulmamış, varsayılanlar kullanılıyor.');
            return;
          }

          final data = snapshot.data();
          if (data == null) return;

          final settings = data['settings'] as Map<String, dynamic>? ?? data;

          // 1. Kill-Switch Senkronizasyonu
          final killSwitchActive = settings['killSwitchActive'] as bool? ?? false;
          final newAdsEnabled = !killSwitchActive;
          bool hasChanges = false;

          if (isAdsEnabled != newAdsEnabled) {
            isAdsEnabled = newAdsEnabled;
            hasChanges = true;
            _log('🚨 [FIRESTORE-SYNC] Kill-Switch güncellendi: isAdsEnabled=$isAdsEnabled');

            // Eğer Kill-Switch aktif edildiyse bellekteki tüm önyüklenmiş reklamları derhal temizle!
            if (!isAdsEnabled) {
              _interstitialAd?.dispose();
              _interstitialAd = null;
              _rewardedAd?.dispose();
              _rewardedAd = null;
              _appOpenAd?.dispose();
              _appOpenAd = null;
              _log('🧹 [KILL-SWITCH] Önceden bellekte tutulan tüm reklamlar temizlendi.');
            }
          }

          // 2. Format Bazlı Şalterler
          final newBanner = settings['bannerEnabled'] as bool? ?? true;
          final newRewarded = settings['rewardedEnabled'] as bool? ?? true;
          final newNative = settings['nativeEnabled'] as bool? ?? true;
          final newInterstitial = settings['interstitialEnabled'] as bool? ?? true;

          if (bannerEnabled != newBanner) {
            bannerEnabled = newBanner;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Banner şalteri: $bannerEnabled');
          }
          if (rewardedEnabled != newRewarded) {
            rewardedEnabled = newRewarded;
            hasChanges = true;
            if (!rewardedEnabled) {
              _rewardedAd?.dispose();
              _rewardedAd = null;
            }
            _log('⚙️ [FIRESTORE-SYNC] Rewarded şalteri: $rewardedEnabled');
          }
          if (nativeEnabled != newNative) {
            nativeEnabled = newNative;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native şalteri: $nativeEnabled');
          }
          if (interstitialEnabled != newInterstitial) {
            interstitialEnabled = newInterstitial;
            hasChanges = true;
            if (!interstitialEnabled) {
              _interstitialAd?.dispose();
              _interstitialAd = null;
            }
            _log('⚙️ [FIRESTORE-SYNC] Interstitial şalteri: $interstitialEnabled');
          }

          // 3. Cooldown ve Frekans Sınırı
          final cooldownSec = settings['cooldownSeconds'] as int? ?? 25;
          final freqCapMin = settings['frequencyCapMinutes'] as int? ?? 3;
          _failureCooldown = Duration(seconds: cooldownSec);
          _interstitialCooldown = Duration(minutes: freqCapMin);

          // 4. Kupon Kredi Parametreleri → CouponCreditService'e aktar
          final dailyCredits = settings['dailyFreeCredits'] as int? ?? 2;
          final rewardCredits = settings['rewardCreditsPerVideo'] as int? ?? 2;
          if (CouponCreditService.instance.dailyFreeCredits != dailyCredits ||
              CouponCreditService.instance.rewardCreditsPerVideo != rewardCredits) {
            hasChanges = true;
          }
          CouponCreditService.instance.updateDailyFreeCredits(dailyCredits);
          CouponCreditService.instance.updateRewardCreditsPerAd(rewardCredits);

          _log('✅ [FIRESTORE-SYNC] settings/admob senkronize edildi → '
              'Kill:$killSwitchActive | Banner:$newBanner | Rewarded:$newRewarded | '
              'Native:$newNative | Interstitial:$newInterstitial | '
              'Cooldown:${cooldownSec}s | FreqCap:${freqCapMin}m | '
              'DailyCredits:$dailyCredits | RewardCredits:$rewardCredits');

          if (hasChanges) {
            notifyListeners();
          }
        },
        onError: (e) {
          _log('⚠️ [FIRESTORE-SYNC] settings/admob dinleme hatası: $e');
        },
      );
      _log('🔗 [FIRESTORE-SYNC] settings/admob canlı dinleyici başlatıldı');
    } catch (e) {
      _log('⚠️ [FIRESTORE-SYNC] Dinleyici başlatma hatası: $e');
    }
  }

  /// Servis temizliği (Uygulama kapanışı veya hot-restart)
  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _log('🧹 AdManagerService temizlendi (dispose)');
    super.dispose();
  }
}
