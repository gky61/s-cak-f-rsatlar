import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _KuponlarPageState extends State<KuponlarPage> {
  final KuponService _kuponService = KuponService();
  final Set<String> _copiedKuponIds = {};
  final Set<String> _expandedKuponIds = {}; // Açıklaması genişletilmiş kupon kartları
  final Map<String, String?> _userVotes = {};
  // Lokal oy sayaçları — stream'den gelen veriyi override eder (anında UI tepkisi)
  final Map<String, int> _localHotCounts = {};
  final Map<String, int> _localColdCounts = {};
  final Set<String> _votingInProgress = {}; // Spam click koruması
  bool _isAdmin = false;
  late Stream<List<Kupon>> _kuponlarStream;
  String _selectedStoreFilter = 'Tümü';

  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _kuponlarStream = _kuponService.getKuponlarStream();
    _checkAdminStatus();
    _authSub = AuthService().authStateChanges.listen((user) {
      if (mounted) {
        _checkAdminStatus();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
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
          ? selectedColor.withOpacity(0.15)
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

                  // Sağ Alan: Kupon Kodu Kutusu (Misafir kullanıcı için blurlu)
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
                ],
              ),

              const SizedBox(height: 10),

              // ── Bottom Row: Oylama Butonları + Güven Rozeti + Yönetim ────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sol: Oylama Butonları ve Rozet
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

  Widget _buildTabContent({
    required List<Kupon> list,
    required bool isDark,
    required dynamic currentUser,
    required String emptyMsg,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          emptyMsg,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildCouponCard(
          kupon: list[index],
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kuponlar', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: TabBar(
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
        body: StreamBuilder<List<Kupon>>(
          stream: _kuponlarStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
            }

            final kuponlar = snapshot.data ?? [];
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

            // Split into Community and Radar lists
            // Tab 1: Topluluk Kuponları (kaynakTipi == 'topluluk')
            // Profesyonel sıralama: Sıcak kuponlar en üstte (Wilson), normaller/yeniler ortada, geçersizler en altta.
            final toplulukKuponlar = filteredKuponlar.where((k) => k.kaynakTipi == 'topluluk').toList();
            toplulukKuponlar.sort((a, b) => Kupon.compareKuponlar(a, b, _getStoreRank));

            // Tab 2: Kupon Radarı (kaynakTipi == 'web' && durum == 'aktif')
            // Profesyonel sıralama: Sıcak kuponlar en üstte (Wilson), normaller/yeniler ortada.
            final radarKuponlar = filteredKuponlar.where((k) => k.kaynakTipi == 'web' && k.durum == 'aktif').toList();
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
                    children: [
                      _buildTabContent(
                        list: toplulukKuponlar,
                        isDark: isDark,
                        currentUser: currentUser,
                        emptyMsg: 'Topluluk kuponu bulunamadı.',
                      ),
                      _buildTabContent(
                        list: radarKuponlar,
                        isDark: isDark,
                        currentUser: currentUser,
                        emptyMsg: 'Radar kuponu bulunamadı.',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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
      ),
    );
  }
}

// Container padding extension helper
extension on EdgeInsets {
  EdgeInsets py(double value) => copyWith(top: value, bottom: value);
}
