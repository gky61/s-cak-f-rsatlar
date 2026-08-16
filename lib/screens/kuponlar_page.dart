import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/kupon.dart';
import '../services/kupon_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
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
  final Set<String> _expandedKuponIds = {}; // Açıklaması genişletilmiş kupon kartları
  final Set<String> _hiddenKuponIds = {}; // Kullanıcının gizlediği kuponlar
  final Map<String, String?> _userVotes = {};
  // Lokal oy sayaçları — stream'den gelen veriyi override eder (anında UI tepkisi)
  final Map<String, int> _localHotCounts = {};
  final Map<String, int> _localColdCounts = {};
  final Set<String> _votingInProgress = {}; // Spam click koruması
  bool _isAdmin = false;
  bool _hideRadarBanner = false; // Radar bilgi banner'ı kapatma durumu
  late Stream<List<Kupon>> _kuponlarStream;
  late TabController _tabController;
  String _selectedStoreFilter = 'Tümü';

  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _kuponlarStream = _kuponService.getKuponlarStream();
    _checkAdminStatus();
    _loadHiddenCoupons();
    _authSub = AuthService().authStateChanges.listen((user) {
      if (mounted) {
        _checkAdminStatus();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authSub?.cancel();
    super.dispose();
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
      builder: (context) => AlertDialog(
        title: const Text('Kuponu Sil'),
        content: const Text('Bu kuponu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _kuponService.deleteKupon(kuponId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kupon başarıyla silindi.'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Silme sırasında hata oluştu: $e'),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getStoreAsset(String storeName) {
    switch (storeName) {
      case 'Trendyol':
        return 'assets/trendyol.webp';
      case 'Hepsiburada':
        return 'assets/hepsiburada.webp';
      case 'N11':
        return 'assets/n11.webp';
      case 'Amazon':
        return 'assets/amazon.webp';
      case 'Pazarama':
        return 'assets/pazarama.webp';
      case 'MediaMarkt':
        return 'assets/mediamarkt.webp';
      case 'Teknosa':
        return 'assets/teknosa.webp';
      case 'Mavi':
        return 'assets/mavi.webp';
      case 'DeFacto':
        return 'assets/defacto.webp';
      case 'Zara':
        return 'assets/zara.webp';
      case 'Mango':
        return 'assets/mango.webp';
      case 'Beymen':
        return 'assets/beymen.webp';
      case 'PttAVM':
        return 'assets/pttavm.webp';
      case 'İncehesap':
        return 'assets/incehesap.webp';
      case 'Idefix':
      case 'İdefix':
      case 'idefix':
        return 'assets/idefix.webp';
      case 'Havit':
        return 'assets/havit.webp';
      case 'Migros':
        return 'assets/migros.webp';
      case 'Getir':
        return 'assets/getir.webp';
      case 'Boyner':
        return 'assets/boyner.webp';
      default:
        return 'assets/store-icon.png';
    }
  }

  // Mağaza popülerlik sıralaması:
  // Düşük değer = daha önce gösterilir
  // Grup 1 (0-99): Genel/Teknoloji mağazaları (en bilinen → en az bilinen)
  // Grup 2 (100-199): Yemek/Market sektörü
  // Grup 3 (200-299): Moda/Giyim sektörü
  // Grup 4 (999): Bilinmeyen mağazalar
  int _getStoreRank(String storeName) {
    switch (storeName) {
      // Genel / Teknoloji mağazaları (popülerlikle sıralı)
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
      // Yemek / Market sektörü
      case 'Getir': return 100;
      case 'Migros': return 101;
      // Moda / Giyim sektörü
      case 'Zara': return 200;
      case 'Mango': return 201;
      case 'DeFacto': return 202;
      case 'Mavi': return 203;
      case 'Beymen': return 204;
      default: return 99; // Bilinmeyen ama Diğer grubunda
    }
  }

  Future<void> _loadHiddenCoupons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('hidden_kupon_ids') ?? [];
      if (mounted) {
        setState(() {
          _hiddenKuponIds.addAll(list);
        });
      }
    } catch (_) {}
  }

  Future<void> _hideCoupon(String kuponId, {String? reason}) async {
    HapticFeedback.lightImpact();
    setState(() {
      _hiddenKuponIds.add(kuponId);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_kupon_ids', _hiddenKuponIds.toList());
    } catch (_) {}

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reason != null ? 'Kupon gizlendi ($reason).' : 'Kupon akışınızdan gizlendi.',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'GERİ AL',
          textColor: AppTheme.primary,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            _unhideCoupon(kuponId);
          },
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ),
    );

    // Otomatik kapanmayı garantiye al
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) {
        try {
          controller.close();
        } catch (_) {}
      }
    });
  }

  Future<void> _unhideCoupon(String kuponId) async {
    HapticFeedback.selectionClick();
    setState(() {
      _hiddenKuponIds.remove(kuponId);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_kupon_ids', _hiddenKuponIds.toList());
    } catch (_) {}
  }

  Future<void> _unhideCoupons(Set<String> idsToUnhide, {String? tabName}) async {
    HapticFeedback.selectionClick();
    setState(() {
      _hiddenKuponIds.removeAll(idsToUnhide);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_kupon_ids', _hiddenKuponIds.toList());
    } catch (_) {}
    if (mounted) {
      final msg = tabName != null
          ? '$tabName sekmesindeki gizlenen kuponlar tekrar görünür yapıldı.'
          : 'Seçili gizlenen kuponlar tekrar görünür yapıldı.';
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      final controller = messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) {
          try {
            controller.close();
          } catch (_) {}
        }
      });
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mağaza bağlantısı açılamadı: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String kuponId, String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() {
      _copiedKuponIds.add(kuponId);
    });

    // 2 saniye sonra geri al
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copiedKuponIds.remove(kuponId);
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$code" panoya kopyalandı!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
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

    // Spam click koruması
    if (_votingInProgress.contains(kuponId)) return;

    final userId = currentUser.uid;
    final currentVote = _userVotes[kuponId];

    // Mevcut lokal sayaçları oku (yoksa stream'deki değerleri kullan)
    final prevHot = _localHotCounts[kuponId];
    final prevCold = _localColdCounts[kuponId];

    // Optimistic UI update — anında sayaçları güncelle
    setState(() {
      _votingInProgress.add(kuponId);

      if (currentVote == voteType) {
        // Toggle: aynı oya tekrar basıldı → oyu geri al
        _userVotes[kuponId] = null;
        if (voteType == 'hot' && prevHot != null) {
          _localHotCounts[kuponId] = (prevHot > 0) ? prevHot - 1 : 0;
        } else if (voteType == 'cold' && prevCold != null) {
          _localColdCounts[kuponId] = (prevCold > 0) ? prevCold - 1 : 0;
        }
      } else {
        // Yeni oy veya oy değiştirme
        _userVotes[kuponId] = voteType;

        // Eski oyu düşür
        if (currentVote == 'hot' && prevHot != null) {
          _localHotCounts[kuponId] = (prevHot > 0) ? prevHot - 1 : 0;
        } else if (currentVote == 'cold' && prevCold != null) {
          _localColdCounts[kuponId] = (prevCold > 0) ? prevCold - 1 : 0;
        }

        // Yeni oyu artır
        if (voteType == 'hot') {
          _localHotCounts[kuponId] = (_localHotCounts[kuponId] ?? prevHot ?? 0) + 1;
        } else {
          _localColdCounts[kuponId] = (_localColdCounts[kuponId] ?? prevCold ?? 0) + 1;
        }
      }
    });

    // Firestore'a arka planda kaydet
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
      // Hata: önceki duruma geri dön
      setState(() {
        _userVotes[kuponId] = currentVote;
        if (prevHot != null) _localHotCounts[kuponId] = prevHot;
        if (prevCold != null) _localColdCounts[kuponId] = prevCold;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oy kaydedilirken bir hata oluştu.')),
      );
    }
  }

  Widget _buildVoteButton({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isSelected
          ? selectedColor.withValues(alpha: 0.15)
          : (isDark ? Colors.grey[900] : Colors.grey[100]),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? selectedColor
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadge(double basariOrani, bool isDark) {
    // Renk ve metin seçimi
    Color badgeColor;
    String badgeText;

    if (basariOrani >= 70) {
      badgeColor = Colors.green;
      badgeText = '✓ %${basariOrani.round()} Çalışıyor';
    } else if (basariOrani >= 50) {
      badgeColor = Colors.orange;
      badgeText = '~ %${basariOrani.round()} Çalışıyor';
    } else {
      badgeColor = Colors.redAccent;
      badgeText = '✗ %${basariOrani.round()} Çalışıyor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildCouponCard({
    required Kupon kupon,
    required bool isDark,
    required dynamic currentUser,
  }) {
    final isCopied = _copiedKuponIds.contains(kupon.id);
    final isInvalid = kupon.durum == 'gecersiz';

    // Lazy load user vote if not cached yet
    if (currentUser != null && !_userVotes.containsKey(kupon.id)) {
      _userVotes[kupon.id] = null; // Mark as loading placeholder
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

    // Lokal sayaçları başlat (ilk kez görülen kupon için stream değerlerini al)
    _localHotCounts.putIfAbsent(kupon.id, () => kupon.sicakOySayisi);
    _localColdCounts.putIfAbsent(kupon.id, () => kupon.sogukOySayisi);

    // UI'da gösterilecek değerler — lokal override varsa onu kullan
    final displayHot = _localHotCounts[kupon.id] ?? kupon.sicakOySayisi;
    final displayCold = _localColdCounts[kupon.id] ?? kupon.sogukOySayisi;

    // Güven Eşiği Algoritması (lokal sayaçlarla)
    final toplamOy = displayHot + displayCold;
    final guvenEsigineUlasti = toplamOy >= 3;
    double basariOrani = 0;
    if (guvenEsigineUlasti) {
      basariOrani = (displayHot / toplamOy) * 100;
    }

    final canManage = currentUser != null && (kupon.paylasanKullaniciId == currentUser.uid || _isAdmin);
    final hasUsername = kupon.kaynakTipi == 'topluluk' && kupon.paylasanKullaniciAdi.isNotEmpty;

    return Opacity(
      opacity: isInvalid ? 0.4 : 1.0,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
        color: isDark ? AppTheme.darkSurface : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Row: Logo + Info + Code Box ────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol Alan: Mağaza Logosu
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 46,
                      height: 46,
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      child: Image.asset(
                        _getStoreAsset(kupon.magazaAdi),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/store-icon.png',
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Orta Alan: Mağaza Adı, Başlık, Açıklama ve Kullanıcı Adı
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              kupon.magazaAdi,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            if (hasUsername) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '@${kupon.paylasanKullaniciAdi}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          kupon.baslik,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        if (kupon.aciklama.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final isExpanded = _expandedKuponIds.contains(kupon.id);
                              final isLongDescription = kupon.aciklama.length > 65 || kupon.aciklama.contains('\n');

                              return InkWell(
                                onTap: isLongDescription
                                    ? () {
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
                                splashColor: AppTheme.primary.withValues(alpha: 0.08),
                                highlightColor: Colors.transparent,
                                child: AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  alignment: Alignment.topLeft,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        kupon.aciklama,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                                          height: 1.35,
                                        ),
                                        maxLines: isExpanded ? null : 2,
                                        overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                      ),
                                      if (isLongDescription) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isExpanded ? 'Daha Az Göster' : 'Devamını Göster',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
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

                  // Sağ Alan: Kupon Kodu Kutusu + Mağazaya Git Butonu
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kupon Kodu Kutusu (Misafir kullanıcı için blurlu)
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
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCopied
                                ? AppTheme.success.withValues(alpha: 0.08)
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCopied
                                  ? AppTheme.success
                                  : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey[300]!),
                              width: 1.2,
                            ),
                          ),
                          child: currentUser == null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ImageFiltered(
                                      imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                                      child: Text(
                                        kupon.kuponKodu.isNotEmpty ? kupon.kuponKodu : 'CODE100',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          letterSpacing: 0.4,
                                          color: isDark ? Colors.white : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.lock_rounded,
                                      size: 14,
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      kupon.kuponKodu,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 0.4,
                                        color: isCopied
                                            ? AppTheme.success
                                            : (isDark ? Colors.white : AppTheme.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                                        key: ValueKey<bool>(isCopied),
                                        size: 15,
                                        color: isCopied
                                            ? AppTheme.success
                                            : (isDark ? Colors.grey[400] : AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Şık "Mağazaya Git" Butonu (Uygulama / Web sitesi açılır)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openStore(kupon.magazaAdi),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: isDark ? 0.14 : 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                                width: 1.0,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Mağazaya Git',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 11,
                                  color: AppTheme.primary,
                                ),
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

              // ── Bottom Row: Oylama Butonları + Güven Rozeti + Gizle + Yönetim ────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sol: Oylama Butonları, Rozet ve Gizle Butonu
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildVoteButton(
                          label: '🔥 $displayHot',
                          isSelected: isHotSelected,
                          selectedColor: Colors.redAccent,
                          onTap: () => _handleVote(kupon.id, currentUser, 'hot'),
                          isDark: isDark,
                        ),
                        _buildVoteButton(
                          label: '❄️ $displayCold',
                          isSelected: isColdSelected,
                          selectedColor: Colors.blueAccent,
                          onTap: () => _handleVote(kupon.id, currentUser, 'cold'),
                          isDark: isDark,
                        ),
                        if (guvenEsigineUlasti)
                          _buildTrustBadge(basariOrani, isDark),

                        // Gizle Butonu
                        Material(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => _hideCoupon(kupon.id, reason: 'İlgilenmiyorum'),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_off_outlined,
                                    size: 11,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Gizle',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                                      fontWeight: FontWeight.w500,
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

                  // Sağ: Düzenle / Sil Butonları (gerekli ise)
                  if (canManage) ...[
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Düzenle
                        Material(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
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
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey[300]!,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 11,
                                      color: isDark ? Colors.grey[300] : Colors.grey[600]),
                                  const SizedBox(width: 3),
                                  Text('Düzenle',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        // Sil
                        Material(
                          color: isDark ? Colors.redAccent.withValues(alpha: 0.12) : Colors.red[50],
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => _confirmDelete(kupon.id),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.redAccent.withValues(alpha: 0.35) : Colors.red[200]!,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.delete_outline_rounded, size: 11, color: Colors.redAccent),
                                  const SizedBox(width: 3),
                                  const Text('Sil',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.redAccent,
                                      )),
                                ],
                              ),
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
      ),
    );
  }

  Widget _buildRadarInfoBanner(bool isDark) {
    if (_hideRadarBanner) return const SizedBox.shrink();

    final bannerBg = isDark
        ? AppTheme.primary.withValues(alpha: 0.12)
        : const Color(0xFFEFF6FF); // Soft blue tint
    final borderColor = isDark
        ? AppTheme.primary.withValues(alpha: 0.3)
        : const Color(0xFFBFDBFE);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botkolik Avatarı
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/botkolik.webp',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                            text: ' Radar & Topluluk Doğrulaması',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _hideRadarBanner = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: isDark ? Colors.grey[300] : const Color(0xFF1E40AF),
                    ),
                    children: [
                      const TextSpan(
                        text: 'Bu sayfadaki kuponlar ',
                      ),
                      TextSpan(
                        text: '"Bot',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const TextSpan(
                        text: 'kolik"',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      const TextSpan(
                        text: ' radarıyla otomatik yakalanır. Çalışıp çalışmadıklarını ',
                      ),
                      const TextSpan(
                        text: '🔥',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: ' veya ',
                      ),
                      const TextSpan(
                        text: '❄️',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: ' butonlarıyla oylayarak topluluğa rehberlik edebilirsiniz.',
                      ),
                    ],
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
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
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
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 7),
              Text(
                'Bu sekmede $count kupon gizlendi',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                  fontWeight: FontWeight.w500,
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
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (showBanner) _buildRadarInfoBanner(isDark),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasHidden
                          ? 'Gizlediğiniz kuponlar nedeniyle bu sekmede görünür kupon bulunmuyor.'
                          : emptyMsg,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        return _buildCouponCard(
          kupon: list[kuponIndex],
          isDark: isDark,
          currentUser: currentUser,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = AuthService().currentUser;

    return StreamBuilder<List<Kupon>>(
      stream: _kuponlarStream,
      builder: (context, snapshot) {
        final kuponlar = snapshot.data ?? [];

        // Bu sekmelere göre izole gizlenen kupon kimlikleri
        final hiddenToplulukIds = kuponlar
            .where((k) => k.kaynakTipi == 'topluluk' && _hiddenKuponIds.contains(k.id))
            .map((k) => k.id)
            .toSet();

        final hiddenRadarIds = kuponlar
            .where((k) => k.kaynakTipi == 'web' && _hiddenKuponIds.contains(k.id))
            .map((k) => k.id)
            .toSet();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Kuponlar', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Topluluk Kuponları'),
                Tab(text: 'Kupon Radarı'),
              ],
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: () {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
            }

            if (kuponlar.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 80,
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz kupon paylaşılmamış.',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'İlk kuponu paylaşan sen ol!',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Extract unique active stores and sort by popularity rank
            final activeStores = kuponlar.map((k) => k.magazaAdi).toSet().toList();
            activeStores.sort((a, b) => _getStoreRank(a).compareTo(_getStoreRank(b)));
            final stores = ['Tümü', ...activeStores];

            if (!stores.contains(_selectedStoreFilter)) {
              _selectedStoreFilter = 'Tümü';
            }

            final filteredKuponlar = _selectedStoreFilter == 'Tümü'
                ? kuponlar
                : kuponlar.where((k) => k.magazaAdi == _selectedStoreFilter).toList();

            // Kullanıcının gizlediği kuponları filtrele
            final visibleKuponlar = filteredKuponlar.where((k) => !_hiddenKuponIds.contains(k.id)).toList();

            // Split into Community and Radar lists
            // Tab 1: Topluluk Kuponları (kaynakTipi == 'topluluk')
            // Profesyonel sıralama: Sıcak kuponlar en üstte (Wilson), normaller/yeniler ortada, geçersizler en altta.
            final toplulukKuponlar = visibleKuponlar.where((k) => k.kaynakTipi == 'topluluk').toList();
            toplulukKuponlar.sort((a, b) => Kupon.compareKuponlar(a, b, _getStoreRank));

            // Tab 2: Kupon Radarı (kaynakTipi == 'web' && durum == 'aktif')
            // Profesyonel sıralama: Sıcak kuponlar en üstte (Wilson), normaller/yeniler ortada.
            final radarKuponlar = visibleKuponlar.where((k) => k.kaynakTipi == 'web' && k.durum == 'aktif').toList();
            radarKuponlar.sort((a, b) => Kupon.compareKuponlar(a, b, _getStoreRank));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store ChoiceChips (applied to both tabs)
                Container(
                  height: 48,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: stores.length,
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      final isSelected = _selectedStoreFilter == store;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(store),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppTheme.textPrimary),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedStoreFilter = store;
                              });
                            }
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primary
                                  : (isDark ? Colors.transparent : Colors.grey[200]!),
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Tab lists
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabContent(
                        list: toplulukKuponlar,
                        tabHiddenIds: hiddenToplulukIds,
                        tabName: 'Topluluk Kuponları',
                        isDark: isDark,
                        currentUser: currentUser,
                        emptyMsg: 'Topluluk kuponu bulunamadı.',
                      ),
                      _buildTabContent(
                        list: radarKuponlar,
                        tabHiddenIds: hiddenRadarIds,
                        tabName: 'Kupon Radarı',
                        isDark: isDark,
                        currentUser: currentUser,
                        emptyMsg: 'Radar kuponu bulunamadı.',
                        showRadarBanner: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }(),
          floatingActionButton: FloatingActionButton(
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
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
