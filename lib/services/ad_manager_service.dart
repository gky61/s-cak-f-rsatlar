import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../firebase_options.dart';
import 'analytics_service.dart';
import 'coupon_credit_service.dart';
import 'system_log_service.dart';

void _log(String message) {
  if (kDebugMode) {
    print('📢 [AdManager] $message');
  }
}

/// FırsatKolik — Merkezi AdMob Monetizasyon, Havuz (AdPool) ve Yaşam Döngüsü Servisi
/// 
/// 1. AdMob SDK ve UMP başlatma durumunu yönetir.
/// 2. Uygulamanın birincil reklam omurgası olan Akış İçi Native Ads (Anasayfa, Kuponlar, Aktüel)
///    ve kullanıcı rızalı Ödüllü Video (Rewarded Ads - Kupon Kredisi) formatlarını yönetir.
/// 3. onPaidEvent telemetrisi ile reklam gelirini (micro-cents) Firebase Analytics'e iletir (ROAS optimizasyonu).
/// 4. Hata durumlarında akıllı soğuma (cooldown - 25s) uygulayarak AdMob hesap kısıtlamalarını önler.
/// 5. Acil Durum Şalteri (Kill-Switch) ve format bazlı bağımsız şalterler ile uzaktan yönetilebilir.
class AdManagerService extends ChangeNotifier {
  AdManagerService._internal();
  static final AdManagerService instance = AdManagerService._internal();
  factory AdManagerService() => instance;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  final Completer<bool> _initCompleter = Completer<bool>();
  Future<bool> get waitForInitialization => _initCompleter.isCompleted
      ? Future.value(true)
      : _initCompleter.future;

  /// Dinamik Reklam Şalteri (Kill-Switch) — Firestore settings/admob üzerinden güncellenir
  bool isAdsEnabled = true;

  // ─── Format Bazlı Şalterler (Web Admin Kontrollü) ─────────────────────
  bool bannerEnabled = true;
  bool rewardedEnabled = true;
  bool nativeEnabled = true;
  bool nativeCouponsEnabled = true; // Kuponlar sayfasında akış içi Native Ad şalteri
  bool nativeAktuelEnabled = true; // Aktüel kataloglar sayfasında akış içi Native Ad şalteri
  bool nativePopularEnabled = true; // Popüler Fırsatlar sayfasında akış içi Native Ad şalteri
  bool nativeFollowedCategoriesEnabled = true; // Favori Kategorilerim sayfasında akış içi Native Ad şalteri
  int nativeGridInterval = 6; // Anasayfa Grid'de kaç üründe bir yatay Native Ad gösterileceği
  int nativeCouponsInterval = 5; // Kuponlar sayfasında her kaç öğede bir Native Ad gösterileceği (4 kupon + 1 reklam = 5)
  int nativeAktuelInterval = 6; // Aktüel sayfasında kaç katalogda bir yatay Native Ad gösterileceği (varsayılan: 6)
  int nativePopularInterval = 6; // Popüler Fırsatlar sayfasında kaç fırsatta bir yatay Native Ad gösterileceği (varsayılan: 6)
  int nativeFollowedCategoriesInterval = 6; // Favori Kategorilerim sayfasında kaç fırsatta bir yatay Native Ad gösterileceği (varsayılan: 6)

  // ─── Hata Soğuma (Cooldown) Takibi ───────────────────────────────────────
  final Map<String, DateTime> _lastFailedTime = {};
  Duration _failureCooldown = const Duration(seconds: 25);

  // ─── Firestore Canlı Ayar Dinleyicisi ────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;

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
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete(true);
      }
      _log('✅ AdMob SDK başarıyla başlatıldı: ${initStatus.adapterStatuses.keys.join(", ")}');

      // Arka planda ödüllü reklamları önyükle
      preloadRewardedAd();

      // Firestore settings/admob dinleyicisini başlat (Web Admin senkronizasyonu)
      _startFirestoreSettingsListener();

      // Başlatma tamamlandığında bekleyen widget'ları uyar
      notifyListeners();
    } catch (e) {
      _log('⚠️ AdMob başlatma hatası: $e');
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete(false);
      }
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

    // Kod 3 (ERROR_CODE_NO_FILL) doluluk oranına bağlı beklenen durumdur (gürültü önlenir).
    // Ancak Kod 0 (INTERNAL_ERROR) veya Kod 1 (INVALID_REQUEST / Yanlış AdUnitId) kritik konfigürasyon hatalarıdır!
    if (error.code != 3) {
      SystemLogService.instance.logError(
        category: 'admob',
        subCategory: 'ad_load_failure',
        errorType: 'AdMobLoadError_${error.code}',
        message: 'AdUnit: $adUnitId | Kod: ${error.code} | Mesaj: ${error.message}',
        severity: SystemErrorSeverity.error,
        metadata: {
          'adUnitId': adUnitId,
          'errorCode': error.code,
          'errorMessage': error.message,
          'errorDomain': error.domain,
        },
      );
    }
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
            onAdClicked: (ad) {
              AnalyticsService.instance.logAdClick(adUnitId: unitId, adFormat: 'rewarded');
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
  // FIRESTORE SETTINGS/ADMOB CANLI SENKRONİZASYON (Web Admin ↔ Mobil Köprüsü)
  // ===========================================================================

  static bool _parseBool(dynamic val, bool defaultVal) {
    if (val == null) return defaultVal;
    if (val is bool) return val;
    if (val is String) {
      final lower = val.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    if (val is num) return val != 0;
    return defaultVal;
  }

  static int _parseInt(dynamic val, int defaultVal) {
    if (val == null) return defaultVal;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val.trim()) ?? defaultVal;
    return defaultVal;
  }

  /// Firestore `settings/admob` dokümanını gerçek zamanlı dinler.
  /// Web Admin panelinden yapılan her değişiklik (Kill-Switch, format şalterleri,
  /// cooldown, frekans sınırı, kupon kredileri) mobil uygulamaya anında yansır.
  void _startFirestoreSettingsListener() {
    try {
      if (Firebase.apps.isEmpty) {
        _log('ℹ️ Firebase henüz başlatılmadı. settings/admob dinleyicisi ertelendi.');
        return;
      }
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
          final killSwitchActive = _parseBool(settings['killSwitchActive'], false);
          final newAdsEnabled = !killSwitchActive;
          bool hasChanges = false;

          if (isAdsEnabled != newAdsEnabled) {
            isAdsEnabled = newAdsEnabled;
            hasChanges = true;
            _log('🚨 [FIRESTORE-SYNC] Kill-Switch güncellendi: isAdsEnabled=$isAdsEnabled');

            // Eğer Kill-Switch aktif edildiyse bellekteki tüm önyüklenmiş reklamları derhal temizle!
            if (!isAdsEnabled) {
              _rewardedAd?.dispose();
              _rewardedAd = null;
              _log('🧹 [KILL-SWITCH] Önceden bellekte tutulan tüm reklamlar temizlendi.');
            }
          }

          // 2. Format Bazlı Şalterler
          final newBanner = _parseBool(settings['bannerEnabled'], true);
          final newRewarded = _parseBool(settings['rewardedEnabled'], true);
          final newNative = _parseBool(settings['nativeEnabled'], true);
          final newNativeCoupons = _parseBool(settings['nativeCouponsEnabled'], true);
          final newNativeAktuel = _parseBool(settings['nativeAktuelEnabled'], true);
          final newNativePopular = _parseBool(settings['nativePopularEnabled'], true);
          final newNativeFollowed = _parseBool(settings['nativeFollowedCategoriesEnabled'], true);

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
          if (nativeCouponsEnabled != newNativeCoupons) {
            nativeCouponsEnabled = newNativeCoupons;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native Kuponlar şalteri: $nativeCouponsEnabled');
          }
          if (nativeAktuelEnabled != newNativeAktuel) {
            nativeAktuelEnabled = newNativeAktuel;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native Aktüel şalteri: $nativeAktuelEnabled');
          }
          if (nativePopularEnabled != newNativePopular) {
            nativePopularEnabled = newNativePopular;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native Popüler şalteri: $nativePopularEnabled');
          }
          if (nativeFollowedCategoriesEnabled != newNativeFollowed) {
            nativeFollowedCategoriesEnabled = newNativeFollowed;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native Favori Kategoriler şalteri: $nativeFollowedCategoriesEnabled');
          }

          // 3. Cooldown Süresi
          final cooldownSec = _parseInt(settings['cooldownSeconds'], 25);
          _failureCooldown = Duration(seconds: cooldownSec);

          // 4. Native Grid, Kuponlar, Aktüel, Popüler ve Favori Kategoriler Sıklığı
          final newGridInterval = _parseInt(settings['nativeGridInterval'], 6);
          if (nativeGridInterval != newGridInterval && newGridInterval >= 4 && newGridInterval <= 20) {
            nativeGridInterval = newGridInterval;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native grid sıklığı: $nativeGridInterval');
          }
          final newCouponsInterval = _parseInt(settings['nativeCouponsInterval'], 5);
          if (nativeCouponsInterval != newCouponsInterval && newCouponsInterval >= 3 && newCouponsInterval <= 15) {
            nativeCouponsInterval = newCouponsInterval;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native Kuponlar sıklığı: $nativeCouponsInterval');
          }
          final newAktuelInterval = _parseInt(settings['nativeAktuelInterval'], 6);
          if (nativeAktuelInterval != newAktuelInterval && newAktuelInterval >= 4 && newAktuelInterval <= 20) {
            nativeAktuelInterval = newAktuelInterval;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native Aktüel sıklığı: $nativeAktuelInterval');
          }
          final newPopularInterval = _parseInt(settings['nativePopularInterval'], 6);
          if (nativePopularInterval != newPopularInterval && newPopularInterval >= 4 && newPopularInterval <= 20) {
            nativePopularInterval = newPopularInterval;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native Popüler sıklığı: $nativePopularInterval');
          }
          final newFollowedInterval = _parseInt(settings['nativeFollowedCategoriesInterval'], 6);
          if (nativeFollowedCategoriesInterval != newFollowedInterval && newFollowedInterval >= 4 && newFollowedInterval <= 20) {
            nativeFollowedCategoriesInterval = newFollowedInterval;
            hasChanges = true;
            _log('⚙️ [FIRESTORE-SYNC] Native Favori Kategoriler sıklığı: $nativeFollowedCategoriesInterval');
          }

          // 5. Kupon Kredi Parametreleri → CouponCreditService'e aktar
          final dailyCredits = _parseInt(settings['dailyFreeCredits'], 2);
          final rewardCredits = _parseInt(settings['rewardCreditsPerVideo'], 2);
          if (CouponCreditService.instance.dailyFreeCredits != dailyCredits ||
              CouponCreditService.instance.rewardCreditsPerVideo != rewardCredits) {
            hasChanges = true;
          }
          CouponCreditService.instance.updateDailyFreeCredits(dailyCredits);
          CouponCreditService.instance.updateRewardCreditsPerAd(rewardCredits);

          _log('✅ [FIRESTORE-SYNC] settings/admob senkronize edildi → '
              'Kill:$killSwitchActive | Banner:$newBanner | Rewarded:$newRewarded | '
              'Native:$newNative | NativeCoupons:$nativeCouponsEnabled | NativeAktuel:$nativeAktuelEnabled | '
              'NativePopular:$nativePopularEnabled | NativeFollowed:$nativeFollowedCategoriesEnabled | '
              'NativeGridInterval:$nativeGridInterval | '
              'NativeCouponsInterval:$nativeCouponsInterval | '
              'NativeAktuelInterval:$nativeAktuelInterval | '
              'NativePopularInterval:$nativePopularInterval | '
              'NativeFollowedInterval:$nativeFollowedCategoriesInterval | '
              'Cooldown:${cooldownSec}s | '
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
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _log('🧹 AdManagerService temizlendi (dispose)');
    super.dispose();
  }
}
