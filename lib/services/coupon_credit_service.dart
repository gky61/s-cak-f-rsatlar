import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

void _log(String message) {
  if (kDebugMode) {
    print('🎟️ [CouponCreditService] $message');
  }
}

/// FırsatKolik Kupon Açma Kredisi ve Hak Yönetim Motoru (P1-KUP-02 UID-İzoleli)
///
/// 1. Her kullanıcıya (UID bazlı) günlük 2 adet ÜCRETSİZ kupon açma hakkı tanımlar.
/// 2. Gün değiştiğinde (00:00) hakları otomatik olarak 2'ye yeniler.
/// 3. Haklar bittiğinde Rewarded Ad (Ödüllü Video Reklam) izlenerek +2 Kredi kazanılmasını sağlar.
/// 4. Aynı gün içinde kilidi açılan bir kupon, kullanıcıdan tekrar hak düşmez.
/// 5. Cihaz paylaşımı veya çıkış/giriş senaryolarında kullanıcı hakları ve açılan kuponlar birbiriyle çakışmaz.
class CouponCreditService extends ChangeNotifier {
  CouponCreditService._internal();
  static final CouponCreditService instance = CouponCreditService._internal();
  factory CouponCreditService() => instance;

  static const String _keyCredits = 'firsatkolik_coupon_credits_count';
  static const String _keyDate = 'firsatkolik_coupon_credits_date';
  static const String _keyUnlockedIds = 'firsatkolik_coupon_unlocked_ids';
  static const String _keyDailyRewardedWatched = 'firsatkolik_daily_rewarded_watched';

  static const int defaultDailyCredits = 2;
  static const int rewardCreditsPerAd = 2;
  static const int defaultMaxDailyRewardedVideos = 10;

  int dailyFreeCredits = defaultDailyCredits;
  int rewardCreditsPerVideo = rewardCreditsPerAd;
  int maxDailyRewardedVideos = defaultMaxDailyRewardedVideos;
  int dailyRewardedVideosWatched = 0;

  String _currentScope = 'guest';
  bool _hasAuthListener = false;

  String _getUserScope() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }

  String _scopedKey(String baseKey) => '${baseKey}_$_currentScope';

  /// Kullanıcının bugün daha fazla ödüllü video izleme hakkı var mı? (Anti-Abuse / Fraud Kalkanı)
  bool get canWatchRewardedAd => dailyRewardedVideosWatched < maxDailyRewardedVideos;

  /// Bugün kalan ödüllü video izleme hakkı adedi
  int get remainingRewardedAdWatches =>
      (maxDailyRewardedVideos - dailyRewardedVideosWatched).clamp(0, maxDailyRewardedVideos);

  /// Web Admin / Firestore ayarları üzerinden dinamik güncelleme
  void updateDailyFreeCredits(int val) {
    if (val > 0 && dailyFreeCredits != val) {
      dailyFreeCredits = val;
      _log('⚙️ Günlük ücretsiz kupon hakkı güncellendi: $dailyFreeCredits');
      notifyListeners();
    }
  }

  /// Web Admin / Firestore ayarları üzerinden dinamik güncelleme
  void updateRewardCreditsPerAd(int val) {
    if (val > 0 && rewardCreditsPerVideo != val) {
      rewardCreditsPerVideo = val;
      _log('⚙️ Rewarded video başına kupon hakkı güncellendi: $rewardCreditsPerVideo');
      notifyListeners();
    }
  }

  /// Web Admin / Firestore ayarları üzerinden dinamik güncelleme (Günlük Max Video Limiti)
  void updateMaxDailyRewardedVideos(int val) {
    if (val > 0 && maxDailyRewardedVideos != val) {
      maxDailyRewardedVideos = val;
      _log('⚙️ Günlük azami ödüllü video izleme limiti güncellendi: $maxDailyRewardedVideos');
      notifyListeners();
    }
  }

  final ValueNotifier<int> creditsNotifier = ValueNotifier<int>(defaultDailyCredits);
  final Set<String> _unlockedCouponIds = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  int get remainingCredits => creditsNotifier.value;

  /// Servisi başlatır, aktif kullanıcı kapsamını belirler ve auth değişikliklerini dinler
  Future<void> initialize() async {
    _currentScope = _getUserScope();
    _setupAuthListener();
    await _loadForCurrentScope();
  }

  void _setupAuthListener() {
    if (_hasAuthListener) return;
    _hasAuthListener = true;
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        final newScope = user?.uid ?? 'guest';
        if (newScope != _currentScope) {
          _log('🔄 Kullanıcı oturum değişimi algılandı: $_currentScope -> $newScope. Kupon bakiyesi yükleniyor.');
          _currentScope = newScope;
          _isInitialized = false;
          await _loadForCurrentScope();
          notifyListeners();
        }
      });
    } catch (_) {
      // Firebase initialize edilmemiş test ortamlarında sessizce geç
    }
  }

  Future<void> _loadForCurrentScope() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacyKeysIfAny(prefs, _currentScope);

      final todayStr = _getTodayString();
      final savedDate = prefs.getString(_scopedKey(_keyDate));

      if (savedDate != todayStr) {
        // Yeni bir gün başladı -> Günlük hakka sıfırla
        _log('🌅 Yeni gün tespit edildi ($todayStr) [Scope: $_currentScope]. Günlük $dailyFreeCredits hak tanımlanıyor.');
        await prefs.setString(_scopedKey(_keyDate), todayStr);
        await prefs.setInt(_scopedKey(_keyCredits), dailyFreeCredits);
        await prefs.setStringList(_scopedKey(_keyUnlockedIds), []);
        await prefs.setInt(_scopedKey(_keyDailyRewardedWatched), 0);
        creditsNotifier.value = dailyFreeCredits;
        _unlockedCouponIds.clear();
        dailyRewardedVideosWatched = 0;
      } else {
        // Aynı gün içindeyiz -> Kayıtlı bakiyeyi oku
        final currentCredits = prefs.getInt(_scopedKey(_keyCredits)) ?? dailyFreeCredits;
        final unlocked = prefs.getStringList(_scopedKey(_keyUnlockedIds)) ?? [];
        dailyRewardedVideosWatched = prefs.getInt(_scopedKey(_keyDailyRewardedWatched)) ?? 0;

        creditsNotifier.value = currentCredits;
        _unlockedCouponIds.clear();
        _unlockedCouponIds.addAll(unlocked);
        _log('✅ Kayıtlı kupon kredisi yüklendi [Scope: $_currentScope]: $currentCredits hak | Açılan kuponlar: ${unlocked.length} | İzlenen video: $dailyRewardedVideosWatched/$maxDailyRewardedVideos');
      }
      _isInitialized = true;
    } catch (e) {
      _log('⚠️ Başlatma hatası: $e');
      creditsNotifier.value = dailyFreeCredits;
      dailyRewardedVideosWatched = 0;
      _isInitialized = true;
    }
  }

  Future<void> _migrateLegacyKeysIfAny(SharedPreferences prefs, String scope) async {
    final scopedCreditsKey = '${_keyCredits}_$scope';
    if (!prefs.containsKey(scopedCreditsKey) && prefs.containsKey(_keyCredits)) {
      final legacyCredits = prefs.getInt(_keyCredits);
      final legacyDate = prefs.getString(_keyDate);
      final legacyUnlocked = prefs.getStringList(_keyUnlockedIds);
      final legacyWatched = prefs.getInt(_keyDailyRewardedWatched);

      if (legacyCredits != null) await prefs.setInt('${_keyCredits}_$scope', legacyCredits);
      if (legacyDate != null) await prefs.setString('${_keyDate}_$scope', legacyDate);
      if (legacyUnlocked != null) await prefs.setStringList('${_keyUnlockedIds}_$scope', legacyUnlocked);
      if (legacyWatched != null) await prefs.setInt('${_keyDailyRewardedWatched}_$scope', legacyWatched);

      await prefs.remove(_keyCredits);
      await prefs.remove(_keyDate);
      await prefs.remove(_keyUnlockedIds);
      await prefs.remove(_keyDailyRewardedWatched);
      _log('🔄 Legacy kupon verileri kullanıcıya ($scope) başarıyla taşındı.');
    }
  }

  /// Kuponun kilidi bugün zaten açılmış mı?
  bool isUnlockedToday(String kuponId) {
    return _unlockedCouponIds.contains(kuponId);
  }

  /// Kullanıcı bu kuponu açabilir mi? (Zaten açıksa veya kredisi varsa)
  bool canUnlock(String kuponId) {
    if (isUnlockedToday(kuponId)) return true;
    return remainingCredits > 0;
  }

  /// Kullanıcının bu kupon için oy kullanma hakkı var mı? (Doğrulanmış Testçi İlkesi)
  bool canVoteOnCoupon({
    required String kuponId,
    bool isOwner = false,
    bool hasExistingVote = false,
  }) {
    if (isOwner) return false;
    if (hasExistingVote) return true;
    return isUnlockedToday(kuponId);
  }

  /// Kupon için 1 kredi harcar.
  /// Kupon zaten bugün açılmışsa kredi DÜŞMEZ ve true döner.
  /// Kredi bittiyse ve kupon kilitliyse false döner.
  Future<bool> useCreditForCoupon(String kuponId) async {
    await _ensureRollover();

    // Zaten açılmışsa tekrar harcama yapma
    if (isUnlockedToday(kuponId)) {
      _log('🔓 Kupon $kuponId bugün zaten açık. Kredi düşülmedi.');
      return true;
    }

    if (remainingCredits <= 0) {
      _log('🛑 Kredi yetersiz ($remainingCredits). Kupon açılamadı.');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final newCredits = remainingCredits - 1;
      creditsNotifier.value = newCredits;
      _unlockedCouponIds.add(kuponId);

      await prefs.setInt(_scopedKey(_keyCredits), newCredits);
      await prefs.setStringList(_scopedKey(_keyUnlockedIds), _unlockedCouponIds.toList());
      _log('🎟️ 1 kupon hakkı harcandı [Scope: $_currentScope]. Kalan hak: $newCredits | Kupon: $kuponId');
      notifyListeners();
      return true;
    } catch (e) {
      _log('⚠️ Kredi düşme hatası: $e');
      return false;
    }
  }

  /// Reklam izlenerek hesaba +2 kredi eklenmesi
  Future<int> addRewardedCredits([int? amount]) async {
    final credits = amount ?? rewardCreditsPerVideo;
    await _ensureRollover();

    try {
      final prefs = await SharedPreferences.getInstance();
      final newCredits = remainingCredits + credits;
      creditsNotifier.value = newCredits;
      dailyRewardedVideosWatched++;

      await prefs.setInt(_scopedKey(_keyCredits), newCredits);
      await prefs.setInt(_scopedKey(_keyDailyRewardedWatched), dailyRewardedVideosWatched);
      _log('🎉 Reklam izlendi! +$credits kupon hakkı eklendi [Scope: $_currentScope]. Yeni bakiye: $newCredits | Bugün izlenen video: $dailyRewardedVideosWatched/$maxDailyRewardedVideos');
      notifyListeners();
      return newCredits;
    } catch (e) {
      _log('⚠️ Kredi ekleme hatası: $e');
      return remainingCredits;
    }
  }

  /// Misafir kullanıcının video reklam izleyerek tek bir kuponu açması.
  Future<bool> unlockCouponForGuest(String kuponId) async {
    await _ensureRollover();
    if (isUnlockedToday(kuponId)) {
      return true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _unlockedCouponIds.add(kuponId);
      dailyRewardedVideosWatched++;
      await prefs.setStringList(_scopedKey(_keyUnlockedIds), _unlockedCouponIds.toList());
      await prefs.setInt(_scopedKey(_keyDailyRewardedWatched), dailyRewardedVideosWatched);
      _log('🔓 Misafir kuponu video ile açtı: $kuponId | Bugün izlenen video: $dailyRewardedVideosWatched/$maxDailyRewardedVideos');
      notifyListeners();
      return true;
    } catch (e) {
      _log('⚠️ Misafir kupon açma hatası: $e');
      return false;
    }
  }

  /// Gün değişimi kontrolü (Uygulama açıkken gece yarısı geçerse)
  Future<void> _ensureRollover() async {
    final todayStr = _getTodayString();
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_scopedKey(_keyDate));

    if (savedDate != todayStr) {
      await prefs.setString(_scopedKey(_keyDate), todayStr);
      await prefs.setInt(_scopedKey(_keyCredits), dailyFreeCredits);
      await prefs.setStringList(_scopedKey(_keyUnlockedIds), []);
      await prefs.setInt(_scopedKey(_keyDailyRewardedWatched), 0);
      creditsNotifier.value = dailyFreeCredits;
      _unlockedCouponIds.clear();
      dailyRewardedVideosWatched = 0;
      _log('🌅 Gece yarısı devri tamamlandı ($todayStr) [Scope: $_currentScope]. Haklar $dailyFreeCredits\'e sıfırlandı.');
      notifyListeners();
    }
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  String getTodayStringForTesting() => _getTodayString();

  /// Testler için sıfırlama metodu
  @visibleForTesting
  Future<void> resetForTesting({int credits = defaultDailyCredits}) async {
    _currentScope = _getUserScope();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_keyDate), _getTodayString());
    await prefs.setInt(_scopedKey(_keyCredits), credits);
    await prefs.setStringList(_scopedKey(_keyUnlockedIds), []);
    await prefs.setInt(_scopedKey(_keyDailyRewardedWatched), 0);
    creditsNotifier.value = credits;
    _unlockedCouponIds.clear();
    dailyRewardedVideosWatched = 0;
    _isInitialized = true;
  }
}
