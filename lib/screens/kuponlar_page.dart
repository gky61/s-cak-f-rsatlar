import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import '../models/kupon.dart';
import '../services/kupon_service.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/store_asset_helper.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../services/notification_service.dart';
import '../services/coupon_credit_service.dart';
import '../services/ad_manager_service.dart';
import 'kupon_form_page.dart';

class KuponlarPage extends StatefulWidget {
  final int initialTabIndex;
  final String? highlightKuponId;

  const KuponlarPage({
    super.key,
    this.initialTabIndex = 0,
    this.highlightKuponId,
  });

  @override
  State<KuponlarPage> createState() => _KuponlarPageState();
}

class _KuponlarPageState extends State<KuponlarPage> with SingleTickerProviderStateMixin {
  final KuponService _kuponService = KuponService();
  final Set<String> _copiedKuponIds = {};
  final Set<String> _expandedKuponIds = {};
  final Set<String> _hiddenKuponIds = {};
  final Set<String> _animatingOutKuponIds = {};
  final Set<String> _recentlyRestoredKuponIds = {};
  final Set<String> _recentlyUnlockedKuponIds = {};
  final Map<String, Timer> _unlockedEffectTimers = {};
  final Map<String, Timer> _hideTimers = {};
  final Map<String, String?> _userVotes = {};
  final Map<String, int> _localHotCounts = {};
  final Map<String, int> _localColdCounts = {};
  final Map<String, Timer> _couponVoteDebounceTimers = {};
  bool _isAdmin = false;
  bool _hideRadarBanner = false;
  bool _hideHeroBanner = false;
  late Stream<List<Kupon>> _kuponlarStream;
  late TabController _tabController;
  final ScrollController _radarScrollController = ScrollController();
  final ScrollController _toplulukScrollController = ScrollController();
  bool _hasAutoScrolledToHighlight = false;
  String _selectedStoreFilter = 'Tümü';
  String? _highlightedKuponId;
  Timer? _highlightTimer;

  // Custom In-Page Toast Banner State
  Timer? _toastTimer;
  String? _toastMessage;
  String? _toastActionLabel;
  VoidCallback? _toastAction;
  IconData _toastIcon = Icons.check_circle_rounded;
  Color? _toastBgColor;

  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    NotificationService.isCouponsScreenActive = true;
    if (widget.highlightKuponId != null && widget.highlightKuponId!.trim().isNotEmpty) {
      _highlightedKuponId = widget.highlightKuponId!.trim();
      _highlightTimer = Timer(const Duration(milliseconds: 3600), () {
        if (mounted) {
          setState(() {
            _highlightedKuponId = null;
          });
        }
      });
    }
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
      if (_tabController.indexIsChanging) {
        _hideToast();
      }
      if (mounted) setState(() {});
    });
    _kuponlarStream = _kuponService.getKuponlarStream();
    _checkAdminStatus();
    _loadHiddenCoupons();
    CouponCreditService.instance.initialize();
    CouponCreditService.instance.creditsNotifier.addListener(_onCreditsChanged);
    CouponCreditService.instance.addListener(_onCreditsChanged);
    AdManagerService.instance.preloadRewardedAd();
    _authSub = AuthService().authStateChanges.listen((user) {
      if (mounted) {
        _checkAdminStatus();
        _loadHiddenCoupons();
        CouponCreditService.instance.initialize();
        _userVotes.clear();
        _localHotCounts.clear();
        _localColdCounts.clear();
        setState(() {});
      }
    });
  }

  void _onCreditsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    NotificationService.isCouponsScreenActive = false;
    CouponCreditService.instance.creditsNotifier.removeListener(_onCreditsChanged);
    CouponCreditService.instance.removeListener(_onCreditsChanged);
    _highlightTimer?.cancel();
    _toastTimer?.cancel();
    for (final timer in _hideTimers.values) {
      timer.cancel();
    }
    _hideTimers.clear();
    for (final timer in _unlockedEffectTimers.values) {
      timer.cancel();
    }
    _unlockedEffectTimers.clear();
    for (final timer in _couponVoteDebounceTimers.values) {
      timer.cancel();
    }
    _couponVoteDebounceTimers.clear();
    _tabController.dispose();
    _radarScrollController.dispose();
    _toplulukScrollController.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  /// Yeni açılan kuponu Botkolik çerçeve ışıma efekti için 3.5 saniye boyunca işaretler
  void _markCouponRecentlyUnlocked(String kuponId) {
    _unlockedEffectTimers[kuponId]?.cancel();
    if (mounted) {
      setState(() {
        _recentlyUnlockedKuponIds.add(kuponId);
      });
    }
    _unlockedEffectTimers[kuponId] = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _recentlyUnlockedKuponIds.remove(kuponId);
        });
      }
    });
  }

  void _showToast({
    required String message,
    IconData icon = Icons.check_circle_rounded,
    String? actionLabel,
    VoidCallback? onAction,
    Color? backgroundColor,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    _toastTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() {
      _toastMessage = message;
      _toastIcon = icon;
      _toastActionLabel = actionLabel;
      _toastAction = onAction;
      _toastBgColor = backgroundColor;
    });

    _toastTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  void _hideToast() {
    _toastTimer?.cancel();
    if (_toastMessage != null && mounted) {
      setState(() {
        _toastMessage = null;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await AuthService().isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  void _confirmDelete(String kuponId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Kuponu Sil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Bu kuponu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _kuponService.deleteKupon(kuponId);
                if (mounted) {
                  _showToast(
                    message: 'Kupon başarıyla silindi.',
                    icon: Icons.check_circle_rounded,
                    backgroundColor: const Color(0xFF15803D),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showToast(
                    message: 'Silme sırasında hata oluştu: $e',
                    icon: Icons.error_outline_rounded,
                    backgroundColor: const Color(0xFFDC2626),
                  );
                }
              }
            },
            child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getStoreAsset(String storeName) {
    return StoreAssetHelper.getStoreAsset(storeName);
  }

  int _getStoreRank(String storeName) {
    switch (storeName) {
      case 'Trendyol': return 1;
      case 'Hepsiburada': return 2;
      case 'Amazon': return 3;
      case 'N11': return 4;
      case 'Pazarama': return 5;
      case 'Teknosa': return 6;
      case 'MediaMarkt': return 7;
      case 'PttAVM': return 8;
      case 'İncehesap': return 9;
      case 'Idefix': case 'İdefix': case 'idefix': return 10;
      case 'Havit': return 11;
      case 'Getir': return 100;
      case 'Migros': return 101;
      case 'Zara': return 200;
      case 'Mango': return 201;
      case 'DeFacto': return 202;
      case 'Mavi': return 203;
      case 'Beymen': return 204;
      default: return 99;
    }
  }

  String _getHiddenCouponsStorageKey() {
    final uid = AuthService().currentUser?.uid;
    return (uid != null && uid.isNotEmpty)
        ? 'hidden_kupon_ids_$uid'
        : 'hidden_kupon_ids_guest';
  }

  void _dismissHeroBanner() {
    HapticFeedback.lightImpact();
    setState(() {
      _hideHeroBanner = true;
    });
  }

  Future<void> _loadHiddenCoupons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getHiddenCouponsStorageKey();
      final list = prefs.getStringList(key) ?? [];
      if (mounted) {
        setState(() {
          _hiddenKuponIds.clear();
          _hiddenKuponIds.addAll(list);
        });
      }
    } catch (_) {}
  }

  Future<void> _hideCoupon(String kuponId, {String? reason}) async {
    HapticFeedback.lightImpact();

    // 1. Kartı yumuşakça küçültüp yok etme animasyonunu başlat
    setState(() {
      _animatingOutKuponIds.add(kuponId);
    });

    _hideTimers[kuponId]?.cancel();
    _hideTimers[kuponId] = Timer(const Duration(milliseconds: 320), () async {
      if (mounted && _animatingOutKuponIds.contains(kuponId)) {
        setState(() {
          _hiddenKuponIds.add(kuponId);
          _animatingOutKuponIds.remove(kuponId);
        });

        try {
          final prefs = await SharedPreferences.getInstance();
          final key = _getHiddenCouponsStorageKey();
          await prefs.setStringList(key, _hiddenKuponIds.toList());
        } catch (_) {}
      }
    });

    _showToast(
      message: reason != null ? 'Kupon gizlendi ($reason).' : 'Kupon akışınızdan gizlendi.',
      icon: Icons.visibility_off_rounded,
      actionLabel: 'GERİ AL',
      onAction: () {
        _hideToast();
        _unhideCoupon(kuponId);
      },
      duration: const Duration(milliseconds: 2500),
    );
  }

  Future<void> _unhideCoupon(String kuponId) async {
    HapticFeedback.selectionClick();

    // Eğer henüz çıkış animasyonu devam ediyorsa zamanlayıcıyı iptal et ve anında geri getir
    if (_animatingOutKuponIds.contains(kuponId)) {
      _hideTimers[kuponId]?.cancel();
      _hideTimers.remove(kuponId);
      setState(() {
        _animatingOutKuponIds.remove(kuponId);
        _recentlyRestoredKuponIds.add(kuponId);
      });
    } else {
      setState(() {
        _hiddenKuponIds.remove(kuponId);
        _recentlyRestoredKuponIds.add(kuponId);
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = _getHiddenCouponsStorageKey();
        await prefs.setStringList(key, _hiddenKuponIds.toList());
      } catch (_) {}
    }

    // 1.4 saniye sonra geri yükleme vurgusunu temizle
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _recentlyRestoredKuponIds.remove(kuponId);
        });
      }
    });
  }

  Future<void> _unhideCoupons(Set<String> idsToUnhide, {String? tabName}) async {
    HapticFeedback.selectionClick();

    for (final id in idsToUnhide) {
      _hideTimers[id]?.cancel();
      _hideTimers.remove(id);
      _animatingOutKuponIds.remove(id);
    }

    setState(() {
      _hiddenKuponIds.removeAll(idsToUnhide);
      _recentlyRestoredKuponIds.addAll(idsToUnhide);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getHiddenCouponsStorageKey();
      await prefs.setStringList(key, _hiddenKuponIds.toList());
    } catch (_) {}

    if (mounted) {
      final msg = tabName != null
          ? '$tabName sekmesindeki gizlenen kuponlar geri getirildi.'
          : 'Gizlenen kuponlar tekrar geri getirildi.';
      _showToast(
        message: msg,
        icon: Icons.visibility_rounded,
        backgroundColor: const Color(0xFF15803D),
        duration: const Duration(milliseconds: 2000),
      );
    }

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _recentlyRestoredKuponIds.removeAll(idsToUnhide);
        });
      }
    });
  }

  String _getStoreUrl(String storeName) {
    final clean = storeName.trim().toLowerCase();
    if (clean.contains('trendyol')) return 'https://www.trendyol.com';
    if (clean.contains('hepsiburada')) return 'https://www.hepsiburada.com';
    if (clean.contains('amazon')) return 'https://www.amazon.com.tr';
    if (clean.contains('n11')) return 'https://www.n11.com';
    if (clean.contains('pazarama')) return 'https://www.pazarama.com';
    if (clean.contains('teknosa')) return 'https://www.teknosa.com';
    if (clean.contains('mediamarkt') || clean.contains('media markt')) return 'https://www.mediamarkt.com.tr';
    if (clean.contains('pttavm') || clean.contains('ptt avm')) return 'https://www.pttavm.com';
    if (clean.contains('incehesap')) return 'https://www.incehesap.com';
    if (clean.contains('idefix')) return 'https://www.idefix.com';
    if (clean.contains('havit')) return 'https://www.havitstore.com.tr';
    if (clean.contains('getir')) return 'https://getir.com';
    if (clean.contains('migros')) return 'https://www.migros.com.tr';
    if (clean.contains('zara')) return 'https://www.zara.com/tr';
    if (clean.contains('mango')) return 'https://shop.mango.com/tr';
    if (clean.contains('defacto')) return 'https://www.defacto.com.tr';
    if (clean.contains('mavi')) return 'https://www.mavi.com';
    if (clean.contains('beymen')) return 'https://www.beymen.com';
    if (clean.contains('boyner')) return 'https://www.boyner.com.tr';
    if (clean.contains('watsons')) return 'https://www.watsons.com.tr';
    if (clean.contains('gratis')) return 'https://www.gratis.com';
    if (clean.contains('rossmann')) return 'https://www.rossmann.com.tr';
    if (clean.contains('flo')) return 'https://www.flo.com.tr';
    if (clean.contains('d&r') || clean.contains('dr')) return 'https://www.dr.com.tr';
    if (clean.contains('vatan')) return 'https://www.vatanbilgisayar.com';
    if (clean.contains('itopya')) return 'https://www.itopya.com';
    if (clean.contains('gamer.gen') || clean.contains('gamer gen') || clean == 'gamer gen') return 'https://www.gamer.gen.tr';
    if (clean.contains('gaming.gen') || clean.contains('gaming gen') || clean.contains('gaminggen')) return 'https://www.gaming.gen.tr';
    if (clean.contains('sinerji')) return 'https://www.sinerji.gen.tr';
    if (clean.contains('tebilon')) return 'https://www.tebilon.com';
    if (clean.contains('lcw') || clean.contains('lc waikiki')) return 'https://www.lcwaikiki.com';
    if (clean.contains('koton')) return 'https://www.koton.com';
    if (clean.contains('colins') || clean.contains('colin\'s')) return 'https://www.colins.com.tr';
    if (clean.contains('ipekyol')) return 'https://www.ipekyol.com.tr';
    if (clean.contains('yemeksepeti')) return 'https://www.yemeksepeti.com';
    if (clean.contains('a101')) return 'https://www.a101.com.tr';
    if (clean.contains('bim')) return 'https://www.bim.com.tr';
    if (clean.contains('sok') || clean.contains('şok')) return 'https://www.sokmarket.com.tr';
    if (clean.contains('carrefoursa')) return 'https://www.carrefoursa.com';
    if (clean.contains('ikea')) return 'https://www.ikea.com.tr';
    if (clean.contains('koctas') || clean.contains('koçtaş')) return 'https://www.koctas.com.tr';
    if (clean.contains('decathlon')) return 'https://www.decathlon.com.tr';
    if (clean.contains('adidas')) return 'https://www.adidas.com.tr';
    if (clean.contains('nike')) return 'https://www.nike.com/tr';
    if (clean.contains('apple')) return 'https://www.apple.com/tr';
    if (clean.contains('samsung')) return 'https://www.samsung.com/tr';
    
    return 'https://www.google.com/search?q=${Uri.encodeComponent('$storeName indirim kuponu')}';
  }

  bool _canOpenStore(String storeName) {
    final clean = storeName.trim().toLowerCase();
    if (clean.isEmpty || clean == 'diğer' || clean == 'diger' || clean == 'genel' || clean == 'belirtilmemiş') {
      return false;
    }
    return true;
  }

  Future<void> _openStore(String storeName) async {
    if (!_canOpenStore(storeName)) return;
    HapticFeedback.lightImpact();
    final url = _getStoreUrl(storeName);
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          message: 'Mağaza bağlantısı açılamadı: $e',
          icon: Icons.error_outline_rounded,
          backgroundColor: const Color(0xFFDC2626),
        );
      }
    }
  }

  void _copyToClipboard(String kuponId, String code, {String? storeName, String? source, int? remainingCredits}) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: code));

    // Observability: Kupon kopyalama telemetrisi
    AnalyticsService.instance.logCouponCopied(
      couponId: kuponId,
      storeName: storeName ?? 'magaza',
      source: source ?? 'kuponlar',
    );

    setState(() {
      _copiedKuponIds.add(kuponId);
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copiedKuponIds.remove(kuponId);
        });
      }
    });

    final creditMsg = remainingCredits != null ? ' (Kalan: $remainingCredits hak)' : '';
    _showToast(
      message: '"$code" kodu panoya kopyalandı! 🎉$creditMsg',
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF15803D),
      duration: const Duration(milliseconds: 1800),
    );
  }

  /// Kupon kopyalama isteğini kredi kontrolünden geçirir
  Future<void> _handleCouponCopyAction(Kupon kupon) async {
    final creditService = CouponCreditService.instance;
    final currentUser = AuthService().currentUser;
    final isOwner = currentUser != null && kupon.kaynakTipi == 'topluluk' && kupon.paylasanKullaniciId == currentUser.uid;
    final isAlreadyUnlocked = creditService.isUnlockedToday(kupon.id) || isOwner;

    if (isAlreadyUnlocked) {
      _copyToClipboard(
        kupon.id,
        kupon.kuponKodu,
        storeName: kupon.magazaAdi,
        source: kupon.kaynakTipi,
      );
      return;
    }

    if (creditService.remainingCredits > 0) {
      final success = await creditService.useCreditForCoupon(kupon.id);
      if (success) {
        _markCouponRecentlyUnlocked(kupon.id);
        _copyToClipboard(
          kupon.id,
          kupon.kuponKodu,
          storeName: kupon.magazaAdi,
          source: kupon.kaynakTipi,
          remainingCredits: creditService.remainingCredits,
        );
      }
    } else {
      _showCreditDepletedBottomSheet(context, kupon);
    }
  }

  /// Misafir kullanıcılar için Akıllı Hibrit Kapı Bottom Sheet'i
  /// 1. Seçenek (Vurgulu): Google / Apple ile giriş yap -> Günlük 2 kuponu ÜCRETSİZ aç
  /// 2. Seçenek (Alternatif): Giriş yapmadan 1 sponsor videosu izle -> Yalnızca bu kuponu aç
  void _showGuestCouponHybridBottomSheet(BuildContext context, Kupon kupon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isApple = defaultTargetPlatform == TargetPlatform.iOS;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        bool isLoadingGoogle = false;
        bool isLoadingApple = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(sheetContext).padding.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    Container(
                      width: 38,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top Gradient Icon
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A00), Color(0xFFFF9E00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF7A00).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_open_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      'Kupon Kodunu Aç! 🎟️',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      '${kupon.magazaAdi} kuponunu açmak için dilediğin yöntemi seç:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // SEÇENEK 1: EN AVANTAJLI - GİRİŞ YAP (HEDİYE 2 HAK)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  AppTheme.primary.withValues(alpha: 0.18),
                                  const Color(0xFF1E293B),
                                ]
                              : [
                                  const Color(0xFFFFF7ED),
                                  Colors.white,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.45),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      'ÖNERİLEN • EN AVANTAJLI',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Giriş Yap, Günlük 2 Kuponu Ücretsiz Aç 🎁',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildGuestBenefitRow(
                            icon: Icons.check_circle_rounded,
                            text: 'Her gün ${CouponCreditService.instance.dailyFreeCredits} kuponu tamamen ÜCRETSİZ aç',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildGuestBenefitRow(
                            icon: Icons.check_circle_rounded,
                            text: 'Hakların bittiğinde kısa bir video ile +${CouponCreditService.instance.rewardCreditsPerVideo} hak kazan',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildGuestBenefitRow(
                            icon: Icons.check_circle_rounded,
                            text: 'Flaş indirim ve kupon bildirimlerinden haberdar ol',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),

                          // Google Sign-In Button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: (isLoadingGoogle || isLoadingApple)
                                  ? null
                                  : () async {
                                      setSheetState(() => isLoadingGoogle = true);
                                      try {
                                        final user = await AuthService().signInWithGoogle();
                                        if (user != null && sheetContext.mounted) {
                                          Navigator.of(sheetContext).pop();
                                        }
                                        if (user != null && mounted) {
                                          _checkAdminStatus();
                                          await CouponCreditService.instance.initialize();
                                          final freeCredits = CouponCreditService.instance.dailyFreeCredits;
                                          _showToast(
                                            message: '🎉 Giriş yapıldı! $freeCredits ücretsiz kupon hakkın tanımlandı. Açmak istediğin kuponda "Aç" butonuna dokunabilirsin.',
                                            icon: Icons.check_circle_rounded,
                                            backgroundColor: const Color(0xFF15803D),
                                            duration: const Duration(seconds: 3),
                                          );
                                          if (mounted) setState(() {});
                                        }
                                      } catch (e) {
                                        // Error handled
                                      } finally {
                                        if (mounted) {
                                          setSheetState(() => isLoadingGoogle = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isLoadingGoogle
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Google ile Giriş Yap & Kuponu Aç',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // Apple Sign-In (Sadece iOS)
                          if (isApple) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: (isLoadingGoogle || isLoadingApple)
                                    ? null
                                    : () async {
                                        setSheetState(() => isLoadingApple = true);
                                        try {
                                          final user = await AuthService().signInWithApple();
                                          if (user != null && sheetContext.mounted) {
                                            Navigator.of(sheetContext).pop();
                                          }
                                          if (user != null && mounted) {
                                            _checkAdminStatus();
                                            await CouponCreditService.instance.initialize();
                                            final freeCredits = CouponCreditService.instance.dailyFreeCredits;
                                            _showToast(
                                              message: '🎉 Giriş yapıldı! $freeCredits ücretsiz kupon hakkın tanımlandı. Açmak istediğin kuponda "Aç" butonuna dokunabilirsin.',
                                              icon: Icons.check_circle_rounded,
                                              backgroundColor: const Color(0xFF15803D),
                                              duration: const Duration(seconds: 3),
                                            );
                                            if (mounted) setState(() {});
                                          }
                                        } catch (e) {
                                          // Error handled
                                        } finally {
                                          if (mounted) {
                                            setSheetState(() => isLoadingApple = false);
                                          }
                                        }
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white : Colors.black,
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: isLoadingApple
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.apple, size: 20),
                                          SizedBox(width: 6),
                                          Text(
                                            'Apple ile Giriş Yap & Kuponu Aç',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Divider with "VEYA GİRİŞ YAPMADAN"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'VEYA GİRİŞ YAPMADAN',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // SEÇENEK 2: GİRİŞSİZ 1 SPONSOR VİDEOSU İZLE
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6D00).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.videocam_rounded,
                                    size: 16,
                                    color: Color(0xFFFF6D00),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '1 Sponsor Videosu İzle',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hesap açmak istemiyorsan kısa bir sponsor videosu izleyerek yalnızca bu kupon kodunu anında görüntüle ve kopyala.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Watch Video Button
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () async {
                                Navigator.of(sheetContext).pop();
                                HapticFeedback.mediumImpact();

                                bool userEarnedReward = false;
                                final adShown = await AdManagerService.instance.showRewardedAd(
                                  onUserEarnedReward: (reward) {
                                    userEarnedReward = true;
                                  },
                                  onDismissed: () async {
                                    if (userEarnedReward && mounted) {
                                      await CouponCreditService.instance.unlockCouponForGuest(kupon.id);
                                      _markCouponRecentlyUnlocked(kupon.id);
                                      _showToast(
                                        message: '🎉 Kupon açıldı! Kodu kopyalamak için üzerine dokunabilirsin.',
                                        icon: Icons.lock_open_rounded,
                                        backgroundColor: const Color(0xFF15803D),
                                        duration: const Duration(seconds: 3),
                                      );
                                      if (mounted) setState(() {});
                                    }
                                  },
                                );

                                // Fail-Safe Fallback: Reklam yüklenemezse veya doluluk yoksa kullanıcıyı bekletme
                                if (!adShown && mounted) {
                                  await CouponCreditService.instance.unlockCouponForGuest(kupon.id);
                                  _markCouponRecentlyUnlocked(kupon.id);
                                  _showToast(
                                    message: '🎁 Hediye Kupon Açıldı! Kopyalamak için üzerine dokunabilirsin.',
                                    icon: Icons.card_giftcard_rounded,
                                    backgroundColor: AppTheme.primary,
                                    duration: const Duration(seconds: 3),
                                  );
                                  if (mounted) setState(() {});
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6D00),
                                side: const BorderSide(
                                  color: Color(0xFFFF6D00),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded, size: 17),
                                  SizedBox(width: 6),
                                  Text(
                                    'Videoyu İzle & Bu Kuponu Aç',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Dismiss Button
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8),
                      ),
                      child: const Text(
                        'Daha Sonra / Vazgeç',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuestBenefitRow({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 13.5,
          color: const Color(0xFF16A34A),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  /// Kredi bittiğinde açılan şık Rewarded Ad Bottom Sheet'i
  void _showCreditDepletedBottomSheet(BuildContext context, Kupon kupon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(sheetContext).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 18),

              // Animated Badge Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6D00), Color(0xFFFF9100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.confirmation_number_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                'Günlük Kupon Hakkın Doldu! 🎟️',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Bugünkü ${CouponCreditService.instance.dailyFreeCredits} ücretsiz kupon kopyalama hakkını kullandın. Alışverişine hız kesmeden devam etmek için 1 kısa sponsor videosu izle, anında +${CouponCreditService.instance.rewardCreditsPerVideo} YENİ KUPON HAKKI kazan!',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Community Voting & Video Reward Info Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.35 : 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '💡 İpucu: Kuponları mağazada denedikten sonra Sıcak (🔥) veya Soğuk (❄️) oylayarak topluluğa katkı sağlayabilir, hakların bittiğinde dilediğin zaman video izleyerek yeni haklar kazanabilirsin.',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Watch Video Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    HapticFeedback.mediumImpact();

                    bool userEarnedReward = false;
                    final adShown = await AdManagerService.instance.showRewardedAd(
                      onUserEarnedReward: (reward) {
                        userEarnedReward = true;
                      },
                      onDismissed: () async {
                        if (userEarnedReward && mounted) {
                          final creditAmount = CouponCreditService.instance.rewardCreditsPerVideo;
                          await CouponCreditService.instance.addRewardedCredits();
                          _showToast(
                            message: '🎉 +$creditAmount Kupon Hakkı Eklendi! Kalan: ${CouponCreditService.instance.remainingCredits} Hak. Açmak istediğin kuponda "Aç" butonuna dokunabilirsin.',
                            icon: Icons.confirmation_number_rounded,
                            backgroundColor: const Color(0xFF15803D),
                            duration: const Duration(seconds: 3),
                          );
                          if (mounted) setState(() {});
                        }
                      },
                    );

                    // Ağ gecikmesi veya reklam henüz hazır değilse kullanıcıyı asla mağdur etme
                    if (!adShown && mounted) {
                      await CouponCreditService.instance.addRewardedCredits(1);
                      _showToast(
                        message: '🎁 1 Hediye Kupon Hakkı Eklendi! Kalan: ${CouponCreditService.instance.remainingCredits} Hak.',
                        icon: Icons.card_giftcard_rounded,
                        backgroundColor: AppTheme.primary,
                        duration: const Duration(seconds: 3),
                      );
                      if (mounted) setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_fill_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '🎬 Kısa Video İzle (+${CouponCreditService.instance.rewardCreditsPerVideo} Hak Kazan)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(
                  'Vazgeç / Daha Sonra',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Kupon kredisi bilgi diyaloğu
  void _showCreditInfoDialog(BuildContext context, int currentCredits) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.confirmation_number_rounded, color: AppTheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Kupon Açma Kredisi',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🎟️ Kalan Kupon Hakkın: $currentCredits Adet',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '• Her gün gece yarısı ${CouponCreditService.instance.dailyFreeCredits} adet ücretsiz kupon açma hakkın yenilenir.\n'
                '• Gün içinde açtığın kuponları tekrar kopyalarken hakkın DÜŞMEZ.\n'
                '• Hakların bittiğinde 1 kısa video izleyerek anında +${CouponCreditService.instance.rewardCreditsPerVideo} Hak kazanabilirsin.\n'
                '• Kuponu mağazada kullandıktan sonra oy vererek diğer fırsat avcılarına kuponun güncelliği hakkında rehberlik edebilirsin.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Anladım', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  /// Kupon kodu henüz açılmamışken oylama yapmaya çalışan kullanıcıya gösterilen bilgilendirme ve hızlı açma modalı
  void _showUnlockToVoteBottomSheet(BuildContext context, Kupon kupon, String intendedVoteType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creditService = CouponCreditService.instance;
    final hasCredits = creditService.remainingCredits > 0;
    final voteLabel = intendedVoteType == 'hot' ? 'Sıcak (Çalışıyor 🔥)' : 'Soğuk (Çalışmıyor ❄️)';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(sheetContext).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),

              // Top Icon (Verified Badge Gradient)
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                'Oylamak İçin Önce Kodu Görmelisin! 🎟️',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Store and title
              Text(
                '${kupon.magazaAdi} • ${kupon.baslik}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),

              // Community Rule Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.30),
                    width: 1.1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Topluluk Doğrulama İlkesi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'FırsatKolik\'te kupon oylamaları gerçek alışveriş deneyimlerine dayanır. "$voteLabel" oyu verebilmek için kuponu açıp mağazada denemiş olman gerekir.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Remaining Credits Info or Video Offer
              if (hasCredits) ...[
                // Hakkı var -> 1 hak ile aç
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      HapticFeedback.mediumImpact();

                      final success = await creditService.useCreditForCoupon(kupon.id);
                      if (success && mounted) {
                        _markCouponRecentlyUnlocked(kupon.id);
                        _copyToClipboard(
                          kupon.id,
                          kupon.kuponKodu,
                          storeName: kupon.magazaAdi,
                          source: kupon.kaynakTipi,
                          remainingCredits: creditService.remainingCredits,
                        );
                        _showToast(
                          message: '🎉 Kupon açıldı ve kopyalandı! Kodu mağazada denedikten sonra oylayabilirsin.',
                          icon: Icons.lock_open_rounded,
                          backgroundColor: const Color(0xFF15803D),
                          duration: const Duration(seconds: 4),
                        );
                        setState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.confirmation_number_rounded, size: 19),
                        const SizedBox(width: 8),
                        Text(
                          '🎟️ 1 Hak İle Kuponu Aç (Kalan: ${creditService.remainingCredits})',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Hakkı bitmiş -> Reklam izleyerek +2 hak al
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _showCreditDepletedBottomSheet(context, kupon);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6D00),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '🎬 Video İzle (+${CouponCreditService.instance.rewardCreditsPerVideo} Hak Kazan & Kuponu Aç)',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Dismiss Button
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(
                  'Vazgeç / Daha Sonra',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleVote(Kupon kupon, dynamic currentUser, String voteType) {
    final kuponId = kupon.id;

    if (currentUser == null) {
      showGuestLoginBottomSheet(
        context,
        title: 'Bu Kuponu Oylamak İçin Giriş Yap! 🔥',
        message: 'Topluluğa yön vermek ve kuponun çalışıp çalışmadığını bildirmek için hızlıca giriş yapabilirsin.',
        primaryButtonText: '🚀 Google ile Giriş Yap',
      ).then((loggedIn) {
        if (loggedIn == true && mounted) {
          final freshUser = AuthService().currentUser;
          if (freshUser != null) {
            _handleVote(kupon, freshUser, voteType);
          }
        }
      });
      return;
    }

    final userId = currentUser.uid;

    // 1. Kendi paylaştığı topluluk kuponunu oylama engeli (Self-vote manipulation prevention)
    final isOwner = kupon.kaynakTipi == 'topluluk' && kupon.paylasanKullaniciId == userId;
    if (isOwner) {
      HapticFeedback.lightImpact();
      _showToast(
        message: 'Kendi paylaştığın kuponu oylayamazsın 😊',
        icon: Icons.info_outline_rounded,
        backgroundColor: const Color(0xFF64748B),
      );
      return;
    }

    // 2. Doğrulanmış Testçi Kuralı (Proof-of-Access Gate):
    // Kullanıcının kuponu oylayabilmesi için kodu bugün açmış olması veya geçmişte verilmiş bir oyu olması gerekir.
    final canVote = CouponCreditService.instance.canVoteOnCoupon(
      kuponId: kuponId,
      isOwner: isOwner,
      hasExistingVote: _userVotes[kuponId] != null,
    );

    if (!canVote) {
      HapticFeedback.lightImpact();
      _showUnlockToVoteBottomSheet(context, kupon, voteType);
      return;
    }

    HapticFeedback.lightImpact();

    // Observability: Kupon oylama telemetrisi
    AnalyticsService.instance.logCustomEvent('coupon_voted', {
      'coupon_id': kuponId,
      'vote_type': voteType,
    });

    final currentVote = _userVotes[kuponId];

    final prevHot = _localHotCounts[kuponId] ?? 0;
    final prevCold = _localColdCounts[kuponId] ?? 0;

    // 0ms Anında Optimistic UI Güncellemesi (Kilitlenme ve tıklama kaybı yok)
    setState(() {
      if (currentVote == voteType) {
        // Tıklanan oyu geri al (toggle off)
        _userVotes[kuponId] = null;
        if (voteType == 'hot') {
          _localHotCounts[kuponId] = (prevHot > 0) ? prevHot - 1 : 0;
        } else {
          _localColdCounts[kuponId] = (prevCold > 0) ? prevCold - 1 : 0;
        }
      } else {
        _userVotes[kuponId] = voteType;

        if (voteType == 'hot') {
          _localHotCounts[kuponId] = prevHot + 1;
          if (currentVote == 'cold') {
            _localColdCounts[kuponId] = (prevCold > 0) ? prevCold - 1 : 0;
          }
        } else {
          _localColdCounts[kuponId] = prevCold + 1;
          if (currentVote == 'hot') {
            _localHotCounts[kuponId] = (prevHot > 0) ? prevHot - 1 : 0;
          }
        }
      }
    });

    // 300ms Debounced Firestore senkronizasyonu
    _couponVoteDebounceTimers[kuponId]?.cancel();
    _couponVoteDebounceTimers[kuponId] = Timer(const Duration(milliseconds: 300), () async {
      final target = _userVotes[kuponId];
      await _kuponService.setKuponVote(
        kuponId: kuponId,
        userId: userId,
        targetVoteType: target,
      );
    });
  }

  // --- 1. HERO BANNER ---
  Widget _buildHeroBanner(bool isDark, int totalActiveCoupons) {
    if (_hideHeroBanner) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Glowing Gradient Icon Badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF5000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.confirmation_number_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Güncel İndirim Kuponları',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YENİ',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Popüler mağazalardaki indirim kodları düzenli taranarak en güncel kuponlar kullanıma sunulmaktadır.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Dismiss Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _dismissHeroBanner,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. SECTION HEADER STRIP ---
  Widget _buildSectionHeader(int count, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Text(
              '$count Kupon',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTrustBadge(double basariOrani, bool isDark) {
    Color badgeColor;
    String badgeText;
    IconData icon;

    if (basariOrani >= 70) {
      badgeColor = const Color(0xFF16A34A);
      badgeText = '%${basariOrani.round()} Çalışıyor';
      icon = Icons.check_circle_rounded;
    } else if (basariOrani >= 50) {
      badgeColor = const Color(0xFFD97706);
      badgeText = '%${basariOrani.round()} Kısmi';
      icon = Icons.help_rounded;
    } else {
      badgeColor = const Color(0xFFDC2626);
      badgeText = '%${basariOrani.round()} Geçersiz';
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: badgeColor),
          const SizedBox(width: 3.5),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // --- MODERN CARD CONTAINER FOR COUPON ---
  Widget _buildCouponCard({
    required Kupon kupon,
    required bool isDark,
    required dynamic currentUser,
  }) {
    final isCopied = _copiedKuponIds.contains(kupon.id);
    final isInvalid = kupon.durum == 'gecersiz';
    final isExpired = kupon.isExpired;
    final isRecentlyRestored = _recentlyRestoredKuponIds.contains(kupon.id);

    if (currentUser != null && !_userVotes.containsKey(kupon.id)) {
      _userVotes[kupon.id] = null;
      _kuponService.getUserKuponVote(kuponId: kupon.id, userId: currentUser.uid).then((vote) {
        if (mounted) {
          setState(() {
            _userVotes[kupon.id] = vote;
          });
        }
      });
    }

    final userVote = _userVotes[kupon.id];
    final isHotSelected = userVote == 'hot';
    final isColdSelected = userVote == 'cold';

    _localHotCounts.putIfAbsent(kupon.id, () => kupon.sicakOySayisi);
    _localColdCounts.putIfAbsent(kupon.id, () => kupon.sogukOySayisi);

    final displayHot = _localHotCounts[kupon.id] ?? kupon.sicakOySayisi;
    final displayCold = _localColdCounts[kupon.id] ?? kupon.sogukOySayisi;

    final toplamOy = displayHot + displayCold;
    final guvenEsigineUlasti = toplamOy >= 3;
    double basariOrani = 0;
    if (guvenEsigineUlasti) {
      basariOrani = (displayHot / toplamOy) * 100;
    }

    final canManage = currentUser != null && (kupon.paylasanKullaniciId == currentUser.uid || _isAdmin);
    final hasUsername = kupon.kaynakTipi == 'topluluk' && kupon.paylasanKullaniciAdi.isNotEmpty;
    final isHighlighted = _highlightedKuponId != null && _highlightedKuponId == kupon.id;
    final isRecentlyUnlocked = _recentlyUnlockedKuponIds.contains(kupon.id);
    final isRadarGlowActive = isRecentlyUnlocked || isHighlighted;

    final cardContent = Opacity(
      opacity: (isInvalid || isExpired) ? 0.55 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isRadarGlowActive
              ? null
              : [
                  BoxShadow(
                    color: isRecentlyRestored
                        ? AppTheme.primary.withValues(alpha: isDark ? 0.45 : 0.25)
                        : Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
                    blurRadius: isRecentlyRestored ? 16 : 10,
                    spreadRadius: isRecentlyRestored ? 1.5 : 0,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: isRadarGlowActive
              ? Border.all(color: Colors.transparent, width: 1.2)
              : Border.all(
                  color: isRecentlyRestored
                      ? AppTheme.primary
                      : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  width: isRecentlyRestored ? 1.8 : 1.2,
                ),
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // TOP ROW: STORE LOGO + TITLES + VOUCHER CODE BOX
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Logo
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Image.asset(
                    _getStoreAsset(kupon.magazaAdi),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset('assets/store-icon.png', fit: BoxFit.contain);
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Center: Store Badge + Title + Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Name & Source Tag
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              kupon.magazaAdi,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (kupon.isExpired) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_off_outlined, size: 10, color: Color(0xFFDC2626)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Süresi Doldu',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (hasUsername) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '@${kupon.paylasanKullaniciAdi}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Title
                      Text(
                        kupon.baslik,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),

                      // Description
                      if (kupon.aciklama.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Builder(
                          builder: (context) {
                            final isExpanded = _expandedKuponIds.contains(kupon.id);
                            final isLongDescription = kupon.aciklama.length > 70 || kupon.aciklama.contains('\n');

                            return InkWell(
                              onTap: isLongDescription
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedKuponIds.remove(kupon.id);
                                        } else {
                                          _expandedKuponIds.add(kupon.id);
                                        }
                                      });
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      kupon.aciklama,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                        height: 1.35,
                                      ),
                                      maxLines: isExpanded ? null : 2,
                                      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                    ),
                                    if (isLongDescription) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isExpanded ? 'Daha Az Göster' : 'Devamını Göster',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            isExpanded
                                                ? Icons.keyboard_arrow_up_rounded
                                                : Icons.keyboard_arrow_down_rounded,
                                            size: 14,
                                            color: AppTheme.primary,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right: Voucher Code Box + Store Button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Voucher Button Box
                    Builder(
                      builder: (context) {
                        final isOwner = currentUser != null && kupon.kaynakTipi == 'topluluk' && kupon.paylasanKullaniciId == currentUser.uid;
                        final isUnlockedToday = CouponCreditService.instance.isUnlockedToday(kupon.id) || isOwner;
                        final hasCredits = CouponCreditService.instance.remainingCredits > 0;
                        final isGuest = currentUser == null;

                        Color boxBgColor;
                        Color boxBorderColor;

                        if (isCopied) {
                          boxBgColor = const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.12);
                          boxBorderColor = const Color(0xFF16A34A);
                        } else if (isUnlockedToday) {
                          boxBgColor = isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9);
                          boxBorderColor = isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1);
                        } else if (isGuest) {
                          boxBgColor = isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9);
                          boxBorderColor = isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1);
                        } else if (hasCredits) {
                          // Kilitli ama açma hakkı var
                          boxBgColor = AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.08);
                          boxBorderColor = AppTheme.primary.withValues(alpha: 0.50);
                        } else {
                          // Kilitli ve hakkı bitmiş (+2 video izleme durumu)
                          boxBgColor = const Color(0xFFFF6D00).withValues(alpha: isDark ? 0.18 : 0.08);
                          boxBorderColor = const Color(0xFFFF6D00).withValues(alpha: 0.60);
                        }

                        return InkWell(
                          onTap: () async {
                            // 1. Bugün zaten açılmış kupon (Üye veya misafir video izlemiş)
                            if (isUnlockedToday) {
                              _copyToClipboard(
                                kupon.id,
                                kupon.kuponKodu,
                                storeName: kupon.magazaAdi,
                                source: kupon.kaynakTipi,
                              );
                              return;
                            }

                            // 2. Misafir kullanıcı kilitli kupona tıklarsa -> Akıllı Hibrit Kapı
                            if (isGuest) {
                              _showGuestCouponHybridBottomSheet(context, kupon);
                            } else {
                              // 3. Giriş yapmış kullanıcı kilitli kupona tıklarsa -> Kredi kontrolü
                              _handleCouponCopyAction(kupon);
                            }
                          },
                          borderRadius: BorderRadius.circular(9),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                              color: boxBgColor,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: boxBorderColor,
                                width: 1.1,
                              ),
                            ),
                            child: isUnlockedToday
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        kupon.kuponKodu,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                          color: isCopied
                                              ? const Color(0xFF16A34A)
                                              : (isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                                          key: ValueKey<bool>(isCopied),
                                          size: 13,
                                          color: isCopied
                                              ? const Color(0xFF16A34A)
                                              : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  )
                                : isGuest
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ImageFiltered(
                                            imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                                            child: Text(
                                              kupon.kuponKodu.isNotEmpty ? kupon.kuponKodu : 'KUPON100',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11.5,
                                                letterSpacing: 0.5,
                                                color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.lock_rounded, size: 13, color: AppTheme.primary),
                                        ],
                                      )
                                    : hasCredits
                                        // Kilitli ancak kullanıcının hakkı var -> Tıklayınca 1 hakla açacak
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ImageFiltered(
                                                imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                                                child: Text(
                                                  kupon.kuponKodu.isNotEmpty ? kupon.kuponKodu : 'KUPON100',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 11.5,
                                                    letterSpacing: 0.5,
                                                    color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary,
                                                  borderRadius: BorderRadius.circular(4.5),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.confirmation_number_rounded, size: 9.5, color: Colors.white),
                                                    SizedBox(width: 2.5),
                                                    Text(
                                                      'Aç',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: -0.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        // Kilitli ve hakkı bitti -> Video izleyerek +2 hak kazanacak
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ImageFiltered(
                                                imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                                                child: Text(
                                                  kupon.kuponKodu.isNotEmpty ? kupon.kuponKodu : 'KUPON100',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 11.5,
                                                    letterSpacing: 0.5,
                                                    color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF6D00),
                                                  borderRadius: BorderRadius.circular(4.5),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.videocam_rounded, size: 10, color: Colors.white),
                                                    const SizedBox(width: 2.5),
                                                    Text(
                                                      '+${CouponCreditService.instance.rewardCreditsPerVideo} Hak',
                                                      style: const TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: -0.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                          ),
                        );
                      },
                    ),

                    // "Mağazaya Git" Button (Sadece geçerli bir mağaza varsa gösterilir)
                    if (_canOpenStore(kupon.magazaAdi)) ...[
                      const SizedBox(height: 5),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openStore(kupon.magazaAdi),
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.06),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Mağazaya Git',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(Icons.open_in_new_rounded, size: 10.5, color: AppTheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // BOTTOM ROW: VOTES + TRUST BADGE + HIDE + MANAGEMENT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Voting Buttons & Trust Badge & Hide Button
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _KuponVoteButton(
                        count: displayHot,
                        isSelected: isHotSelected,
                        isHot: true,
                        onTap: () => _handleVote(kupon, currentUser, 'hot'),
                        isDark: isDark,
                      ),
                      _KuponVoteButton(
                        count: displayCold,
                        isSelected: isColdSelected,
                        isHot: false,
                        onTap: () => _handleVote(kupon, currentUser, 'cold'),
                        isDark: isDark,
                      ),
                      if (guvenEsigineUlasti)
                        _buildTrustBadge(basariOrani, isDark),

                      // Hide Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _hideCoupon(kupon.id, reason: 'İlgilenmiyorum'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_off_outlined,
                                  size: 11.5,
                                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  'Gizle',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: Edit / Delete for Owner / Admin
                if (canManage) ...[
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KuponFormPage(
                                  userId: currentUser.uid,
                                  kupon: kupon,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _confirmDelete(kupon.id),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.16 : 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (isRecentlyUnlocked || isHighlighted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _NewlyUnlockedCardGlowWrapper(
          key: ValueKey('card_glow_${kupon.id}_${isHighlighted ? "highlight" : "unlocked"}'),
          isDark: isDark,
          child: cardContent,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: cardContent,
    );
  }

  // --- BOTKOLIK RADAR INFO BANNER ---
  Widget _buildRadarInfoBanner(bool isDark) {
    if (_hideRadarBanner) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _BotkolikRadarAnimatedBanner(
        isDark: isDark,
        onClose: () {
          HapticFeedback.lightImpact();
          setState(() => _hideRadarBanner = true);
        },
      ),
    );
  }

  Widget _buildTabHiddenBanner({
    required String tabName,
    required int count,
    required bool isDark,
    required VoidCallback onUnhide,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_off_outlined,
                size: 14,
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
              ),
              const SizedBox(width: 7),
              Text(
                'Bu sekmede $count kupon gizlendi',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onUnhide,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                'Tümünü Göster',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SKELETON LOADER FOR COUPONS ---
  Widget _buildCouponSkeleton(bool isDark) {
    final shimmerBase = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE2E8F0);
    final shimmerHighlight = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8FAFC);

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          height: 115,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required List<Kupon> list,
    required Set<String> tabHiddenIds,
    required String tabName,
    required bool isDark,
    required dynamic currentUser,
    required String emptyMsg,
    bool showRadarBanner = false,
    ScrollController? scrollController,
  }) {
    final showBanner = showRadarBanner && !_hideRadarBanner && currentUser != null;
    final hasHidden = tabHiddenIds.isNotEmpty;

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (showBanner) _buildRadarInfoBanner(isDark),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: 34,
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasHidden ? 'Gizlenen Kuponlar Mevcut' : 'Kupon Bulunamadı',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasHidden
                          ? 'Gizlediğiniz kuponlar nedeniyle bu sekmede görünür kupon bulunmuyor.'
                          : emptyMsg,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (hasHidden) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _unhideCoupons(tabHiddenIds, tabName: tabName),
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: Text('Bu Sekmedeki Gizlenenleri Göster (${tabHiddenIds.length})'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    int headerCount = 0;
    if (showBanner) headerCount++;
    if (hasHidden) headerCount++;

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 75),
      itemCount: list.length + headerCount,
      itemBuilder: (context, index) {
        int currentIndex = 0;

        if (showBanner) {
          if (index == currentIndex) {
            return _buildRadarInfoBanner(isDark);
          }
          currentIndex++;
        }

        if (hasHidden) {
          if (index == currentIndex) {
            return _buildTabHiddenBanner(
              tabName: tabName,
              count: tabHiddenIds.length,
              isDark: isDark,
              onUnhide: () => _unhideCoupons(tabHiddenIds, tabName: tabName),
            );
          }
          currentIndex++;
        }

        final kuponIndex = index - currentIndex;
        final kupon = list[kuponIndex];
        final isHiding = _animatingOutKuponIds.contains(kupon.id);
        final isRestored = _recentlyRestoredKuponIds.contains(kupon.id);

        return _AnimatedCouponItem(
          key: ValueKey<String>(kupon.id),
          kupon: kupon,
          isHiding: isHiding,
          isRestored: isRestored,
          child: _buildCouponCard(
            kupon: kupon,
            isDark: isDark,
            currentUser: currentUser,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = AuthService().currentUser;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'İndirim Kuponları',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Geri',
        ),
        actions: [
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: CouponCreditService.instance.creditsNotifier,
                  builder: (context, credits, _) {
                    final hasCredits = credits > 0;
                    return InkWell(
                      onTap: () => _showCreditInfoDialog(context, credits),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: hasCredits
                              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                              : const Color(0xFFFF6D00).withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasCredits
                                ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF60A5FA))
                                : const Color(0xFFFF6D00),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasCredits ? '🎟️ $credits Hak' : '🎟️ +${CouponCreditService.instance.rewardCreditsPerVideo} Hak Al',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: hasCredits
                                    ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                    : const Color(0xFFFF6D00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: InkWell(
                  onTap: () {
                    final freeCredits = CouponCreditService.instance.dailyFreeCredits;
                    showGuestLoginBottomSheet(
                      context,
                      title: 'Giriş Yap, Günlük $freeCredits Kuponu Ücretsiz Aç! 🎁',
                      message:
                          'FırsatKolik üyelerine her gün $freeCredits adet indirim kuponu açma hakkı tamamen ücretsiz verilir. Giriş yaparak anında haklarını al!',
                      primaryButtonText: '🚀 Giriş Yap & Haklarını Al',
                    ).then((loggedIn) {
                      if (loggedIn == true && mounted) {
                        _checkAdminStatus();
                        CouponCreditService.instance.initialize().then((_) {
                          if (mounted) setState(() {});
                        });
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: isDark ? 0.20 : 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.65),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🎁 ${CouponCreditService.instance.dailyFreeCredits} Hediye Hak',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
            ),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final isFirst = _tabController.index == 0;
                return TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                  unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            size: 16,
                            color: isFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Kupon Radarı',
                            style: TextStyle(
                              color: isFirst
                                  ? (isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A))
                                  : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                              fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 16,
                            color: !isFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Topluluk Kuponları',
                            style: TextStyle(
                              color: !isFirst
                                  ? (isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A))
                                  : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                              fontWeight: !isFirst ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Kupon>>(
            stream: _kuponlarStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildCouponSkeleton(isDark);
              }
              if (snapshot.hasError) {
                return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
              }

              final kuponlar = snapshot.data ?? [];

              final hiddenToplulukIds = kuponlar
                  .where((k) => k.kaynakTipi == 'topluluk' && _hiddenKuponIds.contains(k.id))
                  .map((k) => k.id)
                  .toSet();

              final hiddenRadarIds = kuponlar
                  .where((k) => k.kaynakTipi == 'web' && _hiddenKuponIds.contains(k.id))
                  .map((k) => k.id)
                  .toSet();

              final activeStores = kuponlar.map((k) => k.magazaAdi).toSet().toList();
              activeStores.sort((a, b) => _getStoreRank(a).compareTo(_getStoreRank(b)));
              final stores = ['Tümü', ...activeStores];

              if (!stores.contains(_selectedStoreFilter)) {
                _selectedStoreFilter = 'Tümü';
              }

              final filteredKuponlar = _selectedStoreFilter == 'Tümü'
                  ? kuponlar
                  : kuponlar.where((k) => k.magazaAdi == _selectedStoreFilter).toList();

              final visibleKuponlar = filteredKuponlar.where((k) => !_hiddenKuponIds.contains(k.id)).toList();

              final toplulukKuponlar = visibleKuponlar.where((k) => k.kaynakTipi == 'topluluk').toList();
              toplulukKuponlar.sort((a, b) => Kupon.compareKuponlar(a, b, _getStoreRank, isCommunity: true));

              final radarKuponlar = visibleKuponlar.where((k) => k.kaynakTipi == 'web' && k.durum == 'aktif').toList();
              radarKuponlar.sort((a, b) => Kupon.compareKuponlar(a, b, _getStoreRank, isCommunity: false));

              final currentTabCount = _tabController.index == 0 ? radarKuponlar.length : toplulukKuponlar.length;
              final currentTabTitle = _tabController.index == 0 ? 'Kupon Radarı' : 'Topluluk Kuponları';

              // Hedef kupona otomatik kaydırma (Highlight Kupon ID varsa)
              if (_highlightedKuponId != null && !_hasAutoScrolledToHighlight) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _hasAutoScrolledToHighlight) return;
                  final isCommunityTab = _tabController.index == 1;
                  final targetList = isCommunityTab ? toplulukKuponlar : radarKuponlar;
                  final targetCtrl = isCommunityTab ? _toplulukScrollController : _radarScrollController;
                  final targetIndex = targetList.indexWhere((k) => k.id == _highlightedKuponId);

                  if (targetIndex != -1 && targetCtrl.hasClients) {
                    _hasAutoScrolledToHighlight = true;
                    final headerOffset = (isCommunityTab
                            ? (hiddenToplulukIds.isNotEmpty ? 1 : 0)
                            : ((!_hideRadarBanner ? 1 : 0) + (hiddenRadarIds.isNotEmpty ? 1 : 0))) *
                        60.0;
                    final targetOffset = (headerOffset + (targetIndex * 155.0)).clamp(
                      0.0,
                      targetCtrl.position.maxScrollExtent,
                    );
                    targetCtrl.animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO BANNER
                  _buildHeroBanner(isDark, visibleKuponlar.length),

                  // 3. HORIZONTAL STORE FILTER CHIPS
                  if (stores.isNotEmpty) ...[
                    Container(
                      height: 33,
                      margin: const EdgeInsets.only(top: 6, bottom: 2),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: stores.length,
                        itemBuilder: (context, index) {
                          final store = stores[index];
                          final isSelected = _selectedStoreFilter == store;

                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedStoreFilter = store;
                                  });
                                },
                                borderRadius: BorderRadius.circular(9),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : (isDark ? AppTheme.darkSurface : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                                      width: isSelected ? 1.2 : 0.9,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.primary.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (store == 'Tümü') ...[
                                        Icon(
                                          Icons.apps_rounded,
                                          size: 14,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                                        ),
                                        const SizedBox(width: 6),
                                      ] else ...[
                                        Image.asset(
                                          _getStoreAsset(store),
                                          width: 14,
                                          height: 14,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 14),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        store,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155)),
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // 4. SECTION HEADER STRIP
                  if (visibleKuponlar.isNotEmpty)
                    _buildSectionHeader(currentTabCount, currentTabTitle, isDark),

                  // 5. TAB CONTENT
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildTabContent(
                          list: radarKuponlar,
                          tabHiddenIds: hiddenRadarIds,
                          tabName: 'Kupon Radarı',
                          isDark: isDark,
                          currentUser: currentUser,
                          emptyMsg: 'Kupon radarında şu an aktif kupon bulunamadı.',
                          showRadarBanner: true,
                          scrollController: _radarScrollController,
                        ),
                        _buildTabContent(
                          list: toplulukKuponlar,
                          tabHiddenIds: hiddenToplulukIds,
                          tabName: 'Topluluk Kuponları',
                          isDark: isDark,
                          currentUser: currentUser,
                          emptyMsg: 'Topluluk tarafından paylaşılan kupon bulunamadı.',
                          scrollController: _toplulukScrollController,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // 4. CUSTOM IN-PAGE FLOATING ANIMATED TOAST
          Positioned(
            left: 16,
            right: 16,
            bottom: 72,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              reverseDuration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _toastMessage == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey<String>(_toastMessage!),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: _toastBgColor ?? (isDark ? AppTheme.darkSurfaceElevated : const Color(0xFF0F172A)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(_toastIcon, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _toastMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_toastActionLabel != null && _toastAction != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _toastAction,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primary, width: 1),
                                ),
                                child: Text(
                                  _toastActionLabel!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _tabController.index == 1
            ? Container(
                key: const ValueKey('share_coupon_fab'),
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    final currentUser = AuthService().currentUser;
                    if (currentUser == null) {
                      showGuestLoginBottomSheet(
                        context,
                        title: 'Kupon Paylaşmak İçin Giriş Yap! 🎟️',
                        message: 'Topluluğa katkıda bulunmak ve indirim kuponunu paylaşmak için hemen giriş yap.',
                        primaryButtonText: '🚀 Google ile Giriş Yap',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KuponFormPage(userId: currentUser.uid),
                      ),
                    );
                  },
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Kupon Paylaş',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: -0.2),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('empty_fab')),
      ),
    );
  }
}

/// A smooth, high-frame-rate animated wrapper for coupon cards
/// supporting fluid entry (scale, fade, expand) and exit (scale down, fade out, collapse height)
class _AnimatedCouponItem extends StatefulWidget {
  final Kupon kupon;
  final bool isHiding;
  final bool isRestored;
  final Widget child;

  const _AnimatedCouponItem({
    super.key,
    required this.kupon,
    required this.isHiding,
    required this.isRestored,
    required this.child,
  });

  @override
  State<_AnimatedCouponItem> createState() => _AnimatedCouponItemState();
}

class _AnimatedCouponItemState extends State<_AnimatedCouponItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    if (widget.isRestored) {
      _controller.forward();
    } else if (widget.isHiding) {
      _controller.value = 1.0;
      _controller.reverse();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedCouponItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHiding && !oldWidget.isHiding) {
      _controller.reverse();
    } else if (!widget.isHiding && oldWidget.isHiding) {
      _controller.forward();
    } else if (widget.isRestored && !oldWidget.isRestored) {
      if (_controller.value < 1.0) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _sizeAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

class _KuponVoteButton extends StatefulWidget {
  final int count;
  final bool isSelected;
  final bool isHot;
  final VoidCallback onTap;
  final bool isDark;

  const _KuponVoteButton({
    required this.count,
    required this.isSelected,
    required this.isHot,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_KuponVoteButton> createState() => _KuponVoteButtonState();
}

class _KuponVoteButtonState extends State<_KuponVoteButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _scaleController.reverse().then((_) {
      if (mounted) _scaleController.forward();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isHot = widget.isHot;
    final isDark = widget.isDark;

    // Harmonious Matte Gradients (Light & Dark matching deal_thermometer)
    final hotGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF9A3412), Color(0xFF881337)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final coldGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF155E75), Color(0xFF083344)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final activeBorderColor = isHot
        ? (isDark
            ? const Color(0xFFFB923C).withValues(alpha: 0.40)
            : const Color(0xFFFDBA74).withValues(alpha: 0.85))
        : (isDark
            ? const Color(0xFF22D3EE).withValues(alpha: 0.50)
            : const Color(0xFF67E8F9).withValues(alpha: 0.90));

    final activeShadowColor = isHot
        ? (isDark
            ? const Color(0xFFEA580C).withValues(alpha: 0.22)
            : const Color(0xFFDC2626).withValues(alpha: 0.20))
        : (isDark
            ? const Color(0xFF06B6D4).withValues(alpha: 0.25)
            : const Color(0xFF0891B2).withValues(alpha: 0.22));

    return ScaleTransition(
      scale: _scaleController,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4.5),
            decoration: BoxDecoration(
              gradient: isSelected ? (isHot ? hotGradient : coldGradient) : null,
              color: isSelected
                  ? null
                  : (isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? activeBorderColor
                    : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.2 : 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? activeShadowColor
                      : Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
                  blurRadius: isSelected ? 6 : 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(
                    isHot
                        ? Icons.local_fire_department_rounded
                        : Icons.ac_unit_rounded,
                    size: 13.5,
                    color: isDark
                        ? (isHot ? const Color(0xFFFFEDD5) : const Color(0xFFE0F2FE))
                        : Colors.white,
                  )
                else
                  Text(
                    isHot ? '🔥' : '🥶',
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(width: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Text(
                    '${widget.count}',
                    key: ValueKey<int>(widget.count),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      color: isSelected
                          ? (isDark
                              ? (isHot ? const Color(0xFFFFEDD5) : const Color(0xFFE0F2FE))
                              : Colors.white)
                          : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🌟 BOTKOLIK RADAR ANIMATED BANNER (COUPONS RADAR VERIFICATION)
// ─────────────────────────────────────────────────────────────────────────────

class _BotkolikRadarAnimatedBanner extends StatefulWidget {
  final bool isDark;
  final VoidCallback onClose;

  const _BotkolikRadarAnimatedBanner({
    required this.isDark,
    required this.onClose,
  });

  @override
  State<_BotkolikRadarAnimatedBanner> createState() =>
      _BotkolikRadarAnimatedBannerState();
}

class _BotkolikRadarAnimatedBannerState
    extends State<_BotkolikRadarAnimatedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _shimmerAngleAnimation;
  late final Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    // 3.5 saniyelik akıcı ve göz alıcı mikro-animasyon
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Işıma / Gradient Parlaklık Eğrisi (Zarifçe parlar, döner ve son 1.5 saniyede ipeksi bir şekilde sönümlenir)
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 43,
      ),
    ]).animate(_controller);

    // Shimmer / Gradient rotasyon açısı
    _shimmerAngleAnimation = Tween<double>(begin: 0.0, end: 1.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    // Botkolik avatar hafif nabız (pulse) efekti
    _breatheAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.16)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.16, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.10)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.10, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = _glowAnimation.value;
        final angle = _shimmerAngleAnimation.value;
        final breathe = _breatheAnimation.value;

        // Canlı ve Zengin Gradient Renkleri (FırsatKolik Turuncu + Altın Amber + Parlak Mavi)
        final gradientColors = isDark
            ? [
                const Color(0xFFFF6B35),
                const Color(0xFFFBBF24),
                const Color(0xFF38BDF8),
                const Color(0xFFFF6B35),
              ]
            : [
                const Color(0xFFFF4500),
                const Color(0xFFF59E0B),
                const Color(0xFF0284C7),
                const Color(0xFFFF4500),
              ];

        // Sönümlenmiş durağan sınır rengi (Aydınlık modda sıcak ve belirgin şeftali tonu)
        final settledBorderColor = isDark
            ? AppTheme.primary.withValues(alpha: 0.25)
            : const Color(0xFFFFD5C0);

        // Dinamik Zemin Rengi
        final baseBgColor = isDark
            ? AppTheme.darkSurfaceElevated
            : Colors.white;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              // Taban yumuşak kart gölgesi
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: isDark ? 0.20 : 0.05 * (1.0 - 0.5 * glow)),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              // Animasyonlu canlı dış ışıma (glow)
              if (glow > 0.01) ...[
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFFFF6B35)
                          : const Color(0xFFFF5722))
                      .withValues(alpha: (isDark ? 0.22 : 0.28) * glow),
                  blurRadius: (isDark ? 12.0 : 15.0) * glow,
                  spreadRadius: (isDark ? 1.0 : 1.5) * glow,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7))
                      .withValues(alpha: (isDark ? 0.12 : 0.16) * glow),
                  blurRadius: 18 * glow,
                  offset: const Offset(0, 3),
                ),
              ],
            ],
          ),
          child: CustomPaint(
            painter: _RadarGradientBorderPainter(
              borderRadius: 14,
              borderWidth: 1.1 + (0.7 * glow),
              gradientColors: gradientColors,
              glowProgress: glow,
              rotationTurns: angle,
              settledBorderColor: settledBorderColor,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: baseBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Botkolik AI Avatar (Nefes Alma & Işıma Efekti)
                  Transform.scale(
                    scale: breathe,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: glow > 0.01
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.40 * glow),
                                  blurRadius: 8 * glow,
                                  spreadRadius: 1 * glow,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/botkolik.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.smart_toy_rounded,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),

                  // 2. Metin Alanı
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🌟 "Bot" + "kolik" + " Radar Doğrulaması" Tipografisi
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Bot',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                              const TextSpan(
                                text: 'kolik',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: AppTheme.primary,
                                ),
                              ),
                              TextSpan(
                                text: ' Radar Doğrulaması',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Bu sekmedeki kuponlar Botkolik Radarı tarafından e-ticaret sitelerinden taranır. Çalışıp çalışmadığını oylayarak topluluğa destek olabilirsiniz.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.38,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 3. Kapatma Butonu
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RadarGradientBorderPainter extends CustomPainter {
  final double borderRadius;
  final double borderWidth;
  final List<Color> gradientColors;
  final double glowProgress;
  final double rotationTurns;
  final Color settledBorderColor;

  _RadarGradientBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.gradientColors,
    required this.glowProgress,
    required this.rotationTurns,
    required this.settledBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Zemin Durağan Çerçeveyi Çiz (Sürekli ve Kesintisiz)
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = settledBorderColor;
    canvas.drawRRect(rrect, basePaint);

    // 2. Canlı Dönen Gradient Katmanı
    if (glowProgress > 0.001) {
      final activeColors = gradientColors
          .map((c) => c.withValues(alpha: c.a * glowProgress))
          .toList();

      final angle = rotationTurns * math.pi * 2;
      final gradient = SweepGradient(
        colors: activeColors,
        transform: GradientRotation(angle),
      );

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..shader = gradient.createShader(rect);

      canvas.drawRRect(rrect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarGradientBorderPainter oldDelegate) {
    return oldDelegate.glowProgress != glowProgress ||
        oldDelegate.rotationTurns != rotationTurns ||
        oldDelegate.settledBorderColor != settledBorderColor;
  }
}

/// Yeni açılan veya bildirimden vurgulanan kupon kartını Botkolik Radar tarzı dönen degrade çerçeve ve ışıma ile 3.5 saniye canlandırır
class _NewlyUnlockedCardGlowWrapper extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const _NewlyUnlockedCardGlowWrapper({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  State<_NewlyUnlockedCardGlowWrapper> createState() =>
      _NewlyUnlockedCardGlowWrapperState();
}

class _NewlyUnlockedCardGlowWrapperState
    extends State<_NewlyUnlockedCardGlowWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _shimmerAngleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40,
      ),
    ]).animate(_controller);

    _shimmerAngleAnimation = Tween<double>(begin: 0.0, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = _glowAnimation.value;
        final angle = _shimmerAngleAnimation.value;

        final gradientColors = isDark
            ? [
                const Color(0xFFFF6B35),
                const Color(0xFFFBBF24),
                const Color(0xFF38BDF8),
                const Color(0xFFFF6B35),
              ]
            : [
                const Color(0xFFFF4500),
                const Color(0xFFF59E0B),
                const Color(0xFF0284C7),
                const Color(0xFFFF4500),
              ];

        final settledBorderColor = isDark
            ? AppTheme.darkBorder
            : const Color(0xFFE2E8F0);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              if (glow > 0.01) ...[
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFFFF6B35)
                          : const Color(0xFFFF5722))
                      .withValues(alpha: (isDark ? 0.35 : 0.30) * glow),
                  blurRadius: (isDark ? 16.0 : 18.0) * glow,
                  spreadRadius: (isDark ? 1.5 : 2.0) * glow,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7))
                      .withValues(alpha: (isDark ? 0.20 : 0.22) * glow),
                  blurRadius: 22 * glow,
                  offset: const Offset(0, 3),
                ),
              ],
            ],
          ),
          child: CustomPaint(
            painter: _RadarGradientBorderPainter(
              borderRadius: 18,
              borderWidth: 1.4 + (1.2 * glow),
              gradientColors: gradientColors,
              glowProgress: glow,
              rotationTurns: angle,
              settledBorderColor: settledBorderColor,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

