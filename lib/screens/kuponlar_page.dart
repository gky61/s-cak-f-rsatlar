import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import '../models/kupon.dart';
import '../services/kupon_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/store_asset_helper.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import 'kupon_form_page.dart';

class KuponlarPage extends StatefulWidget {
  const KuponlarPage({super.key});

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
  final Map<String, Timer> _hideTimers = {};
  final Map<String, String?> _userVotes = {};
  final Map<String, int> _localHotCounts = {};
  final Map<String, int> _localColdCounts = {};
  final Set<String> _votingInProgress = {};
  bool _isAdmin = false;
  bool _hideRadarBanner = false;
  bool _hideHeroBanner = false;
  late Stream<List<Kupon>> _kuponlarStream;
  late TabController _tabController;
  String _selectedStoreFilter = 'Tümü';

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
    _tabController = TabController(length: 2, vsync: this);
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
    _loadHeroBannerPreference();
    _authSub = AuthService().authStateChanges.listen((user) {
      if (mounted) {
        _checkAdminStatus();
        _loadHiddenCoupons();
        _userVotes.clear();
        _localHotCounts.clear();
        _localColdCounts.clear();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    for (final timer in _hideTimers.values) {
      timer.cancel();
    }
    _hideTimers.clear();
    _tabController.dispose();
    _authSub?.cancel();
    super.dispose();
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

  Future<void> _loadHeroBannerPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hideHeroBanner = prefs.getBool('hide_kuponlar_hero_banner') ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _dismissHeroBanner() async {
    HapticFeedback.lightImpact();
    setState(() {
      _hideHeroBanner = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hide_kuponlar_hero_banner', true);
    } catch (_) {}
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
    if (clean.contains('gaming.gen')) return 'https://www.gaming.gen.tr';
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

  Future<void> _openStore(String storeName) async {
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

  void _copyToClipboard(String kuponId, String code) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: code));
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

    _showToast(
      message: '"$code" kodu panoya kopyalandı! 🎉',
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF15803D),
      duration: const Duration(milliseconds: 1800),
    );
  }

  Future<void> _handleVote(String kuponId, dynamic currentUser, String voteType) async {
    if (currentUser == null) {
      final loggedIn = await showGuestLoginBottomSheet(
        context,
        title: 'Bu Kuponu Oylamak İçin Giriş Yap! 🔥',
        message: 'Topluluğa yön vermek ve kuponun çalışıp çalışmadığını bildirmek için hızlıca giriş yapabilirsin.',
        primaryButtonText: '🚀 Google ile Giriş Yap',
      );
      if (loggedIn == true && mounted) {
        setState(() {});
        final freshUser = AuthService().currentUser;
        if (freshUser != null) {
          _handleVote(kuponId, freshUser, voteType);
        }
      }
      return;
    }

    if (_votingInProgress.contains(kuponId)) return;

    HapticFeedback.lightImpact();
    final userId = currentUser.uid;
    final currentVote = _userVotes[kuponId];

    final prevHot = _localHotCounts[kuponId];
    final prevCold = _localColdCounts[kuponId];

    setState(() {
      _votingInProgress.add(kuponId);

      if (currentVote == voteType) {
        _userVotes[kuponId] = null;
        if (voteType == 'hot' && prevHot != null) {
          _localHotCounts[kuponId] = (prevHot > 0) ? prevHot - 1 : 0;
        } else if (voteType == 'cold' && prevCold != null) {
          _localColdCounts[kuponId] = (prevCold > 0) ? prevCold - 1 : 0;
        }
      } else {
        _userVotes[kuponId] = voteType;

        if (currentVote == 'hot' && prevHot != null) {
          _localHotCounts[kuponId] = (prevHot > 0) ? prevHot - 1 : 0;
        } else if (currentVote == 'cold' && prevCold != null) {
          _localColdCounts[kuponId] = (prevCold > 0) ? prevCold - 1 : 0;
        }

        if (voteType == 'hot') {
          _localHotCounts[kuponId] = (_localHotCounts[kuponId] ?? prevHot ?? 0) + 1;
        } else {
          _localColdCounts[kuponId] = (_localColdCounts[kuponId] ?? prevCold ?? 0) + 1;
        }
      }
    });

    final success = await _kuponService.voteKupon(
      kuponId: kuponId,
      userId: userId,
      voteType: voteType,
    );

    if (mounted) {
      setState(() {
        _votingInProgress.remove(kuponId);
      });
    }

    if (!success && mounted) {
      setState(() {
        _userVotes[kuponId] = currentVote;
        if (prevHot != null) _localHotCounts[kuponId] = prevHot;
        if (prevCold != null) _localColdCounts[kuponId] = prevCold;
      });
      _showToast(
        message: 'Oy kaydedilirken bir hata oluştu.',
        icon: Icons.error_outline_rounded,
        backgroundColor: const Color(0xFFDC2626),
      );
    }
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

  Widget _buildVoteButton({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.8)
                  : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.1 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? selectedColor
                  : (isDark ? const Color(0xFFD4D4D8) : const Color(0xFF475569)),
            ),
          ),
        ),
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

    return Opacity(
      opacity: isInvalid ? 0.5 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: isRecentlyRestored
                  ? AppTheme.primary.withValues(alpha: isDark ? 0.45 : 0.25)
                  : Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
              blurRadius: isRecentlyRestored ? 16 : 10,
              spreadRadius: isRecentlyRestored ? 1.5 : 0,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
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
                    InkWell(
                      onTap: () async {
                        if (currentUser == null) {
                          final loggedIn = await showGuestLoginBottomSheet(
                            context,
                            title: 'Kupon Kodunu Açmak İçin Giriş Yap! 🎟️',
                            message: 'Sana özel tanımlanan indirim kodunu kopyalamak ve hemen kullanmak için Google ile tek tıkla giriş yap.',
                            primaryButtonText: '🚀 Google ile Giriş Yap',
                          );
                          if (loggedIn == true && mounted) {
                            _checkAdminStatus();
                            setState(() {});
                            _copyToClipboard(kupon.id, kupon.kuponKodu);
                          }
                        } else {
                          _copyToClipboard(kupon.id, kupon.kuponKodu);
                        }
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCopied
                              ? const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.12)
                              : (isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isCopied
                                ? const Color(0xFF16A34A)
                                : (isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
                            width: 1.1,
                          ),
                        ),
                        child: currentUser == null
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
                            : Row(
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
                              ),
                      ),
                    ),

                    const SizedBox(height: 5),

                    // "Mağazaya Git" Button
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
                      _buildVoteButton(
                        label: '🔥 $displayHot',
                        isSelected: isHotSelected,
                        selectedColor: const Color(0xFFEF4444),
                        onTap: () => _handleVote(kupon.id, currentUser, 'hot'),
                        isDark: isDark,
                      ),
                      _buildVoteButton(
                        label: '❄️ $displayCold',
                        isSelected: isColdSelected,
                        selectedColor: const Color(0xFF38BDF8),
                        onTap: () => _handleVote(kupon.id, currentUser, 'cold'),
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
  }

  // --- BOTKOLIK RADAR INFO BANNER ---
  Widget _buildRadarInfoBanner(bool isDark) {
    if (_hideRadarBanner) return const SizedBox.shrink();

    final bannerBg = isDark
        ? AppTheme.darkSurfaceElevated
        : const Color(0xFFEFF6FF);
    final borderColor = isDark
        ? AppTheme.primary.withValues(alpha: 0.3)
        : const Color(0xFFBFDBFE);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset('assets/botkolik.webp', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Bot',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const TextSpan(
                            text: 'kolik',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          TextSpan(
                            text: ' Radar Doğrulaması',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _hideRadarBanner = true);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Bu sekmedeki kuponlar Botkolik Radarı tarafından e-ticaret sitelerinden taranır. Çalışıp çalışmadığını oylayarak topluluğa destek olabilirsiniz.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                            Icons.groups_rounded,
                            size: 16,
                            color: isFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Topluluk Kuponları',
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
                            Icons.radar_rounded,
                            size: 16,
                            color: !isFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Kupon Radarı',
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
              toplulukKuponlar.sort((a, b) => Kupon.compareKuponlar(a, b, _getStoreRank));

              final radarKuponlar = visibleKuponlar.where((k) => k.kaynakTipi == 'web' && k.durum == 'aktif').toList();
              radarKuponlar.sort((a, b) => Kupon.compareKuponlar(a, b, _getStoreRank));

              final currentTabCount = _tabController.index == 0 ? toplulukKuponlar.length : radarKuponlar.length;
              final currentTabTitle = _tabController.index == 0 ? 'Topluluk Kuponları' : 'Kupon Radarı';

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
                          list: toplulukKuponlar,
                          tabHiddenIds: hiddenToplulukIds,
                          tabName: 'Topluluk Kuponları',
                          isDark: isDark,
                          currentUser: currentUser,
                          emptyMsg: 'Topluluk tarafından paylaşılan kupon bulunamadı.',
                        ),
                        _buildTabContent(
                          list: radarKuponlar,
                          tabHiddenIds: hiddenRadarIds,
                          tabName: 'Kupon Radarı',
                          isDark: isDark,
                          currentUser: currentUser,
                          emptyMsg: 'Kupon radarında şu an aktif kupon bulunamadı.',
                          showRadarBanner: true,
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
        child: _tabController.index == 0
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
