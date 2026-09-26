import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _log(String message) {
  if (kDebugMode) {
    print('🎟️ [CouponCreditService] $message');
  }
}

/// FırsatKolik Kupon Açma Kredisi ve Hak Yönetim Motoru
///
/// 1. Her giriş yapan kullanıcıya günlük 2 adet ÜCRETSİZ kupon açma hakkı tanımlar.
/// 2. Gün değiştiğinde (00:00) hakları otomatik olarak 2'ye yeniler.
/// 3. Haklar bittiğinde Rewarded Ad (Ödüllü Video Reklam) izlenerek +2 Kredi kazanılmasını sağlar.
/// 4. Aynı gün içinde kilidi açılan bir kupon, kullanıcıdan tekrar hak düşmez.
/// 5. Oylama Bütünlüğü: Kredi avcılığı ve manipülasyonu önlemek için oy karşılığı hak iadesi yapılmaz; hak kazanımı daima Rewarded Video (+2) üzerinden yürütülür.
class CouponCreditService extends ChangeNotifier {
  CouponCreditService._internal();
  static final CouponCreditService instance = CouponCreditService._internal();
  factory CouponCreditService() => instance;

  static const String _keyCredits = 'firsatkolik_coupon_credits_count';
  static const String _keyDate = 'firsatkolik_coupon_credits_date';
  static const String _keyUnlockedIds = 'firsatkolik_coupon_unlocked_ids';

  static const int defaultDailyCredits = 2;
  static const int rewardCreditsPerAd = 2;

  int dailyFreeCredits = defaultDailyCredits;
  int rewardCreditsPerVideo = rewardCreditsPerAd;

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

  final ValueNotifier<int> creditsNotifier = ValueNotifier<int>(defaultDailyCredits);
  final Set<String> _unlockedCouponIds = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  int get remainingCredits => creditsNotifier.value;

  /// Servisi başlatır ve gün kontrolünü yapar
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _getTodayString();
      final savedDate = prefs.getString(_keyDate);

      if (savedDate != todayStr) {
        // Yeni bir gün başladı -> Günlük hakka sıfırla
        _log('🌅 Yeni gün tespit edildi ($todayStr). Günlük $dailyFreeCredits hak tanımlanıyor.');
        await prefs.setString(_keyDate, todayStr);
        await prefs.setInt(_keyCredits, dailyFreeCredits);
        await prefs.setStringList(_keyUnlockedIds, []);
        creditsNotifier.value = dailyFreeCredits;
        _unlockedCouponIds.clear();
      } else {
        // Aynı gün içindeyiz -> Kayıtlı bakiyeyi oku
        final currentCredits = prefs.getInt(_keyCredits) ?? dailyFreeCredits;
        final unlocked = prefs.getStringList(_keyUnlockedIds) ?? [];

        creditsNotifier.value = currentCredits;
        _unlockedCouponIds.addAll(unlocked);
        _log('✅ Kayıtlı kupon kredisi yüklendi: $currentCredits hak | Açılan kuponlar: ${unlocked.length}');
      }
      _isInitialized = true;
    } catch (e) {
      _log('⚠️ Başlatma hatası: $e');
      creditsNotifier.value = dailyFreeCredits;
      _isInitialized = true;
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
  /// 1. Kendi paylaştığı kupon ise oy kullanamaz (Topluluk manipülasyonu engeli).
  /// 2. Daha önceden verilmiş geçerli bir oyu varsa oyunu serbestçe değiştirebilir/geri alabilir.
  /// 3. Kupon kodu bugün açılmışsa (Doğrulanmış Testçi) oy kullanabilir.
  /// Aksi takdirde kullanıcının önce kupon kodunu açması gerekir.
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

      await prefs.setInt(_keyCredits, newCredits);
      await prefs.setStringList(_keyUnlockedIds, _unlockedCouponIds.toList());
      _log('🎟️ 1 kupon hakkı harcandı. Kalan hak: $newCredits | Kupon: $kuponId');
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

      await prefs.setInt(_keyCredits, newCredits);
      _log('🎉 Reklam izlendi! +$credits kupon hakkı eklendi. Yeni bakiye: $newCredits');
      return newCredits;
    } catch (e) {
      _log('⚠️ Kredi ekleme hatası: $e');
      return remainingCredits;
    }
  }

  /// Misafir kullanıcının video reklam izleyerek tek bir kuponu açması.
  /// Giriş yapmamış kullanıcı için kredi bakiyesi düşülmez, yalnızca kuponun kilidi bugün için açılır.
  Future<bool> unlockCouponForGuest(String kuponId) async {
    await _ensureRollover();
    if (isUnlockedToday(kuponId)) {
      return true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _unlockedCouponIds.add(kuponId);
      await prefs.setStringList(_keyUnlockedIds, _unlockedCouponIds.toList());
      _log('🔓 Misafir kuponu video ile açtı: $kuponId');
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
    final savedDate = prefs.getString(_keyDate);

    if (savedDate != todayStr) {
      await prefs.setString(_keyDate, todayStr);
      await prefs.setInt(_keyCredits, dailyFreeCredits);
      await prefs.setStringList(_keyUnlockedIds, []);
      creditsNotifier.value = dailyFreeCredits;
      _unlockedCouponIds.clear();
      _log('🌅 Gece yarısı devri tamamlandı ($todayStr). Haklar $dailyFreeCredits\'e sıfırlandı.');
    }
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Testler için sıfırlama metodu
  @visibleForTesting
  Future<void> resetForTesting({int credits = defaultDailyCredits}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDate, _getTodayString());
    await prefs.setInt(_keyCredits, credits);
    await prefs.setStringList(_keyUnlockedIds, []);
    creditsNotifier.value = credits;
    _unlockedCouponIds.clear();
    _isInitialized = true;
  }
}
