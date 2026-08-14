import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/deal.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import 'deal_detail_screen.dart';
import 'message_screen.dart';

/// Botkolik Profil Ekranı ("Veri Avcısı, Fırsat Mimarı - Otonom AI")
class BotkolikProfileScreen extends StatefulWidget {
  const BotkolikProfileScreen({super.key});

  @override
  State<BotkolikProfileScreen> createState() => _BotkolikProfileScreenState();
}

class _BotkolikProfileScreenState extends State<BotkolikProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'all';
  String _searchQuery = '';

  bool _isFollowing = false;
  bool _isFollowNotificationEnabled = false;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'name': 'Tümü', 'icon': Icons.grid_view_rounded},
    {'id': 'elektronik', 'name': 'Elektronik', 'icon': Icons.devices_other_rounded},
    {'id': 'supermarket', 'name': 'Süpermarket', 'icon': Icons.shopping_basket_rounded},
    {'id': 'moda', 'name': 'Moda & Giyim', 'icon': Icons.checkroom_rounded},
    {'id': 'ev_yasam', 'name': 'Ev & Yaşam', 'icon': Icons.chair_rounded},
    {'id': 'kozmetik', 'name': 'Kozmetik', 'icon': Icons.face_retouching_natural_rounded},
    {'id': 'spor_outdoor', 'name': 'Spor & Outdoor', 'icon': Icons.fitness_center_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadFollowStatus();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowStatus() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final isFollowing = await _firestoreService.isFollowing(currentUserId, 'botkolik');
      final isNotificationEnabled = await _firestoreService.isFollowNotificationEnabled(currentUserId, 'botkolik');
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isFollowNotificationEnabled = isNotificationEnabled;
        });
      }
    } catch (_) {}
  }

  void _showFloatingSnackBar(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(milliseconds: 2200),
        elevation: 4,
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      showGuestLoginBottomSheet(
        context,
        title: 'Botkolik\'i Takip Et',
        message: 'Botkolik\'in yakaladığı indirimlerden anında haberdar olmak için Giriş Yap! 🚀',
      );
      return;
    }

    HapticFeedback.selectionClick();
    final nextFollowing = !_isFollowing;
    final nextNotification = nextFollowing;

    setState(() {
      _isFollowing = nextFollowing;
      _isFollowNotificationEnabled = nextNotification;
    });

    _showFloatingSnackBar(
      nextFollowing
          ? 'Botkolik takip edildi. Anlık fırsat bildirimleri açık 🔔'
          : 'Botkolik takipten çıkarıldı 🔕',
      isSuccess: nextFollowing,
    );

    try {
      if (nextFollowing) {
        await _firestoreService.followUser(currentUserId, 'botkolik');
      } else {
        await _firestoreService.unfollowUser(currentUserId, 'botkolik');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = !nextFollowing;
          _isFollowNotificationEnabled = !nextFollowing;
        });
        _showFloatingSnackBar('İşlem başarısız oldu: $e', isSuccess: false);
      }
    }
  }

  Future<void> _toggleFollowNotification() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null || !_isFollowing) return;

    HapticFeedback.selectionClick();
    final nextNotification = !_isFollowNotificationEnabled;

    setState(() {
      _isFollowNotificationEnabled = nextNotification;
    });

    _showFloatingSnackBar(
      nextNotification
          ? 'Botkolik için anlık fırsat bildirimleri açıldı 🔔'
          : 'Botkolik için anlık bildirimler kapatıldı 🔕',
      isSuccess: nextNotification,
    );

    try {
      await _firestoreService.toggleFollowNotification(currentUserId, 'botkolik', nextNotification);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowNotificationEnabled = !nextNotification;
        });
        _showFloatingSnackBar('İşlem başarısız oldu: $e', isSuccess: false);
      }
    }
  }

  void _shareBotkolik() {
    HapticFeedback.lightImpact();
    Share.share(
      '⚡ Botkolik ile tanış! FırsatKolik\'in yorulmaz yapay zeka veri avcısı, internetteki en sıcak indirimleri anında yakalıyor. Sen de fırsatları kaçırma! 🚀\nhttps://firsatkolik.app',
      subject: 'Botkolik - Veri Avcısı, Fırsat Mimarı',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const cyberCyan = Color(0xFF00F0FF);
    const cyberPurple = Color(0xFF8B5CF6);

    final cardBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.92);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070A13) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. STATİK SİNAPS & VERİ MATRİSİ ARKA PLANI
          Positioned.fill(
            child: CustomPaint(
              painter: _BotkolikMatrixPainter(
                isDark: isDark,
                primaryCyan: cyberCyan,
                secondaryPurple: cyberPurple,
              ),
            ),
          ),

          // 2. ANA İÇERİK (Sliver Scroll)
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top App Bar
                SliverToBoxAdapter(
                  child: _buildTopBar(context, isDark),
                ),

                // Hero Identity & Integrated Actions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildHeroProfileCard(
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                // Botkolik Akıllı Özellikleri & Yetenekler Bölümü
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildFeaturesSection(
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // Keşfedilen Fırsatlar Başlığı ve Filtreler
                SliverToBoxAdapter(
                  child: _buildDealsHeaderAndFilters(
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Canlı Fırsatlar Listesi
                _buildLiveDealsStream(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Geri Butonu
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),

          // Canlı Sistem Durum Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                  : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.6 : 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF10B981),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'CANLI RADAR AKTİF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          // Paylaş Butonu
          InkWell(
            onTap: _shareBotkolik,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                Icons.share_rounded,
                size: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroProfileCard({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                // Avatar + Online Göstergesi
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // İnce Şık Dış Çerçeve
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00F0FF), Color(0xFF6366F1), AppTheme.primary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),

                      // İç Avatar Görseli
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/botkolik.webp',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Canlı Online Göstergesi
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 1.2,
                            ),
                          ),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Botkolik Başlık (Bot + kolik) & Rozetler
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Bot',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const TextSpan(
                            text: 'kolik',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0284C7),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                            : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.5 : 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'OTONOM AI',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6366F1),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Unvan
                Text(
                  '⚡ Veri Avcısı, Fırsat Mimarı',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(height: 10),

                // Biyografi / Açıklama
                Text(
                  'İnternetteki fiyat anomalilerini ve indirimleri 7/24 tarayarak en sıcak fırsatları anında FırsatKolik topluluğuna sunar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 16),

                // ─── AKSİYON ÇUBUĞU (Takip Et + Zil + Mesaj) ───
                Row(
                  children: [
                    // 1. Takip Butonu
                    Expanded(
                      flex: 1,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleFollow,
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeInOut,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isFollowing
                                  ? AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.10)
                                  : AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isFollowing
                                    ? AppTheme.primary.withValues(alpha: 0.7)
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                              boxShadow: [
                                if (!_isFollowing)
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.28),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2.5),
                                  ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isFollowing
                                      ? Icons.check_circle_rounded
                                      : Icons.person_add_rounded,
                                  size: 16,
                                  color: _isFollowing ? AppTheme.primary : Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isFollowing ? 'Takip Ediliyor' : 'Takip Et',
                                  style: TextStyle(
                                    color: _isFollowing ? AppTheme.primary : Colors.white,
                                    fontWeight: _isFollowing ? FontWeight.w700 : FontWeight.w800,
                                    fontSize: 12.5,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. Bildirim Zili
                    if (_isFollowing) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleFollowNotification,
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isFollowNotificationEnabled
                                  ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.12)
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isFollowNotificationEnabled
                                    ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                    : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1)),
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              _isFollowNotificationEnabled
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_off_outlined,
                              size: 18,
                              color: _isFollowNotificationEnabled
                                  ? const Color(0xFF10B981)
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 8),

                    // 3. Mesajlaşma Butonu (Botkolik Öneri & Geri Bildirim)
                    Expanded(
                      flex: 1,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final currentUser = _authService.currentUser;
                            if (currentUser == null) {
                              showGuestLoginBottomSheet(
                                context,
                                title: 'Giriş Yapın',
                                message: 'Botkolik ile mesajlaşmak, öneri veya geri bildirim göndermek için lütfen giriş yapın.',
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MessageScreen(
                                  otherUserId: 'botkolik',
                                  otherUserName: 'Botkolik',
                                  otherUserImageUrl: 'assets/botkolik.webp',
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.30),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 15,
                                  color: AppTheme.primary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Mesaj',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    final features = [
      {
        'title': 'Akıllı Link Analizi',
        'desc': 'Gönderdiğiniz bağlantıları anında tarayarak ürün detaylarını, güncel fiyatı ve detaylarını sizin için toplar.',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF00F0FF),
      },
      {
        'title': 'Sepet & Özel İndirim Hesaplama',
        'desc': 'Mağazaya özel sepetteki indirimleri, premium abonelik avantajlarını anında tespit eder ve net indirim oranını hesaplar.',
        'icon': Icons.shopping_bag_rounded,
        'color': const Color(0xFF6366F1),
      },
      {
        'title': 'Fiyat Anomalisi Tespiti',
        'desc': 'İnternet üzerindeki milisaniyelik fiyat dalgalanmalarını ve dev indirimleri anında yakalar.',
        'icon': Icons.candlestick_chart_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Flaş İndirim & Stok Radarı',
        'desc': 'Çok kısa süreli flaş indirimleri ve sınırlı stok seviyelerini takip eder, tükenmeden önce sizi haberdar eder.',
        'icon': Icons.flash_on_rounded,
        'color': AppTheme.primary,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BOTKOLİK NASIL ÇALIŞIR?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 4 Özellik Kartı
                ...features.asMap().entries.map((entry) {
                  final index = entry.key;
                  final feat = entry.value;
                  final color = feat['color'] as Color;
                  final isLast = index == features.length - 1;

                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 10.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFE2E8F0),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: isDark ? 0.15 : 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: isDark ? 0.35 : 0.20),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(feat['icon'] as IconData, size: 18, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  feat['title'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  feat['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    height: 1.4,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDealsHeaderAndFilters({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık & Arama Çubuğu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.dynamic_feed_rounded, size: 17, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'KEŞFEDİLEN FIRSATLAR',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Arama Kutusu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Botkolik fırsatlarında ara (iPhone, Dyson, Kahve...)...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Kategori Hapları (Pills)
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final catId = cat['id'] as String;
              final isSelected = _selectedCategory == catId;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = catId);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          size: 13,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat['name'] as String,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveDealsStream({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return StreamBuilder<List<Deal>>(
      stream: _firestoreService.getBotkolikDealsStream(
        categoryId: _selectedCategory == 'all' ? null : _selectedCategory,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 44,
                      color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bu kategoride henüz fırsat taranmadı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Botkolik web ağını taramaya devam ediyor...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        var deals = snapshot.data!;

        // Arama filtresi uygula
        if (_searchQuery.isNotEmpty) {
          deals = deals.where((d) {
            final titleMatch = d.title.toLowerCase().contains(_searchQuery);
            final storeMatch = d.store.toLowerCase().contains(_searchQuery);
            final descMatch = d.description.toLowerCase().contains(_searchQuery);
            return titleMatch || storeMatch || descMatch;
          }).toList();
        }

        if (deals.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
              child: Center(
                child: Text(
                  '"$_searchQuery" aramasıyla eşleşen Botkolik fırsatı bulunamadı.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final deal = deals[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: DealCard(
                    deal: deal,
                    viewMode: CardViewMode.horizontal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DealDetailScreen(dealId: deal.id),
                        ),
                      );
                    },
                  ),
                );
              },
              childCount: deals.length,
            ),
          ),
        );
      },
    );
  }
}

/// Static Neural Matrix / Glowing Synaptic Mesh CustomPainter
class _BotkolikMatrixPainter extends CustomPainter {
  final bool isDark;
  final Color primaryCyan;
  final Color secondaryPurple;

  _BotkolikMatrixPainter({
    required this.isDark,
    required this.primaryCyan,
    required this.secondaryPurple,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final nodePaint = Paint()..style = PaintingStyle.fill;

    // Sabit, zarif 12 sinaps düğümü (hareketsiz & kararlı)
    final nodes = <Offset>[
      Offset(size.width * 0.15, size.height * 0.08),
      Offset(size.width * 0.45, size.height * 0.05),
      Offset(size.width * 0.82, size.height * 0.10),
      Offset(size.width * 0.28, size.height * 0.22),
      Offset(size.width * 0.70, size.height * 0.20),
      Offset(size.width * 0.10, size.height * 0.38),
      Offset(size.width * 0.50, size.height * 0.35),
      Offset(size.width * 0.90, size.height * 0.42),
      Offset(size.width * 0.35, size.height * 0.52),
      Offset(size.width * 0.75, size.height * 0.58),
      Offset(size.width * 0.18, size.height * 0.70),
      Offset(size.width * 0.85, size.height * 0.75),
    ];

    // Bağlantı çizgileri
    final maxDist = size.width * 0.48;
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dist = (nodes[i] - nodes[j]).distance;
        if (dist < maxDist) {
          final alphaFactor = (1.0 - (dist / maxDist)).clamp(0.0, 1.0);
          final lineAlpha = isDark ? (alphaFactor * 0.18) : (alphaFactor * 0.08);

          basePaint.color = (i % 2 == 0 ? primaryCyan : secondaryPurple).withValues(alpha: lineAlpha);
          canvas.drawLine(nodes[i], nodes[j], basePaint);
        }
      }
    }

    // Düğümler
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final nodeAlpha = isDark ? 0.35 : 0.20;
      nodePaint.color = (i % 2 == 0 ? primaryCyan : secondaryPurple).withValues(alpha: nodeAlpha);
      canvas.drawCircle(node, 2.5, nodePaint);

      // Sabit ince dış halka
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = (i % 2 == 0 ? primaryCyan : secondaryPurple).withValues(alpha: nodeAlpha * 0.4);
      canvas.drawCircle(node, 5.0, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BotkolikMatrixPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
