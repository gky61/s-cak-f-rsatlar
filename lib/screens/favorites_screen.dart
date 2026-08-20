import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/deal.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import 'category_preferences_screen.dart';
import 'deal_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  late TabController _tabController;

  // Cached streams to prevent re-listening/recreating on rebuilds
  Stream<List<Deal>>? _myFavoritesStream;
  Stream<List<Deal>>? _followedCategoriesStream;
  String? _cachedUserId;
  StreamSubscription? _authSub;

  int _favoriteFilterIndex = 0; // 0: Tümü, 1: Aktif, 2: Süresi Dolanlar

  late ScrollController _myFavoritesScrollController;
  late ScrollController _followedCategoriesScrollController;
  bool _showBanner = true;
  bool _showCleanupButton = true;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _myFavoritesScrollController = ScrollController();
    _followedCategoriesScrollController = ScrollController();

    _myFavoritesScrollController.addListener(_scrollListener);
    _followedCategoriesScrollController.addListener(_scrollListener);

    _tabController.addListener(_tabListener);

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _initializeStreams(user?.uid);
        setState(() {});
      }
    });
  }

  void _scrollListener() {
    double offset = 0;
    if (_tabController.index == 0 && _myFavoritesScrollController.hasClients) {
      offset = _myFavoritesScrollController.offset;
    } else if (_tabController.index == 1 && _followedCategoriesScrollController.hasClients) {
      offset = _followedCategoriesScrollController.offset;
    }

    // 15px scroll sonrası banner ve temizle butonu durum kontrolü
    bool showBannerNow = _showBanner;
    if (offset > 15) {
      showBannerNow = false;
    }
    bool showCleanupNow = offset <= 15;

    // 800px scroll sonrası yukarı fırlatma butonu kontrolü
    bool showScrollToTopNow = offset > 800;

    if (showBannerNow != _showBanner || showCleanupNow != _showCleanupButton || showScrollToTopNow != _showScrollToTop) {
      setState(() {
        _showBanner = showBannerNow;
        _showCleanupButton = showCleanupNow;
        _showScrollToTop = showScrollToTopNow;
      });
    }
  }

  void _tabListener() {
    if (!_tabController.indexIsChanging) {
      HapticFeedback.selectionClick();
      double offset = 0;
      if (_tabController.index == 0 && _myFavoritesScrollController.hasClients) {
        offset = _myFavoritesScrollController.offset;
      } else if (_tabController.index == 1 && _followedCategoriesScrollController.hasClients) {
        offset = _followedCategoriesScrollController.offset;
      }

      setState(() {
        _showBanner = true;
        _showCleanupButton = offset <= 15;
        _showScrollToTop = offset > 800;
      });
    }
  }

  void _initializeStreams(String? userId) {
    if (userId == null) {
      _myFavoritesStream = null;
      _followedCategoriesStream = null;
      _cachedUserId = null;
      return;
    }
    if (_cachedUserId != userId) {
      _cachedUserId = userId;
      _myFavoritesStream = _firestoreService.getFavoriteDeals(userId);
      _followedCategoriesStream = _firestoreService.getFollowedCategoriesDeals(userId);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tabController.removeListener(_tabListener);
    _tabController.dispose();
    _myFavoritesScrollController.removeListener(_scrollListener);
    _myFavoritesScrollController.dispose();
    _followedCategoriesScrollController.removeListener(_scrollListener);
    _followedCategoriesScrollController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar({
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);
    final currentUser = FirebaseAuth.instance.currentUser;

    _initializeStreams(currentUser?.uid);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Kaydedilenler',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: textColor,
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
                  unselectedLabelColor: secondaryTextColor,
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
                            Icons.bookmark_rounded,
                            size: 16,
                            color: isFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Kaydettiklerim',
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
                            Icons.category_rounded,
                            size: 16,
                            color: !isFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Favori Kategorilerim',
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Kaydettiklerim Tab
          _buildMyFavorites(currentUser, isDark),
          // 2. Favori Kategorilerim Tab
          _buildFollowedCategories(currentUser, isDark),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              heroTag: 'favorites_scroll_to_top',
              mini: true,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                final controller = _tabController.index == 0
                    ? _myFavoritesScrollController
                    : _followedCategoriesScrollController;
                if (controller.hasClients) {
                  controller.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 24),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildMyFavorites(User? currentUser, bool isDark) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    if (currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark_border_rounded,
                  size: 36,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kaydedilenler İçin Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kaydettiğiniz fırsatları görmek ve listenize yeni fırsatlar eklemek için giriş yapmalısınız.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showGuestLoginBottomSheet(
                    context,
                    title: 'Fırsatları Kaydetmek İçin Giriş Yap! 🔖',
                    message: 'Beğendiğin fırsatları arşivine eklemek ve dilediğin zaman ulaşmak için hızlıca giriş yap.',
                    primaryButtonText: '🚀 Google ile Giriş Yap',
                    onLoginSuccess: () => setState(() {}),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'Giriş Yap',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<Deal>>(
      stream: _myFavoritesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid(isDark);
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 14),
                Text(
                  'Bir hata oluştu',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }

        final deals = snapshot.data ?? [];

        if (deals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bookmark_border_rounded,
                    size: 34,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz kaydettiğiniz fırsat yok',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kaydettiğiniz fırsatlar burada düzenli olarak listelenir',
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          );
        }

        final totalCount = deals.length;
        final activeDeals = deals.where((d) => !d.isExpired).toList();
        final expiredDeals = deals.where((d) => d.isExpired).toList();
        final activeCount = activeDeals.length;
        final expiredCount = expiredDeals.length;

        List<Deal> displayedDeals = deals;
        if (_favoriteFilterIndex == 1) {
          displayedDeals = activeDeals;
        } else if (_favoriteFilterIndex == 2) {
          displayedDeals = expiredDeals;
        }

        return Column(
          children: [
            // 30 gün bilgilendirme mesajı
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.025),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14.5,
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '30 günden eski fırsatlar otomatik olarak listeden kaldırılır.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _showBanner ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
            ),

            // Filtre Çipleri & Temizle Barı
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Tümü ($totalCount)',
                      icon: Icons.grid_view_rounded,
                      isSelected: _favoriteFilterIndex == 0,
                      isDark: isDark,
                      selectedColor: AppTheme.primary,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _favoriteFilterIndex = 0);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Aktif ($activeCount)',
                      icon: Icons.local_fire_department_rounded,
                      isSelected: _favoriteFilterIndex == 1,
                      isDark: isDark,
                      selectedColor: const Color(0xFF10B981),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _favoriteFilterIndex = 1);
                      },
                    ),
                  ),
                  if (expiredCount > 0) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildFilterChip(
                        label: 'Süresi Dolan ($expiredCount)',
                        icon: Icons.hourglass_bottom_rounded,
                        isSelected: _favoriteFilterIndex == 2,
                        isDark: isDark,
                        selectedColor: const Color(0xFFEF4444),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _favoriteFilterIndex = 2);
                        },
                      ),
                    ),
                  ],

                  // Temizle Butonu
                  if (totalCount > 0) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showClearFavoritesBottomSheet(
                            context,
                            currentUser,
                            deals,
                            expiredDeals,
                            isDark,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_delete_outlined,
                                color: Color(0xFFDC2626),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Temizle',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: displayedDeals.isEmpty
                  ? _buildEmptyFilteredState(isDark)
                  : _buildDealGrid(displayedDeals, isDark, _myFavoritesScrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor
                : (isDark ? AppTheme.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              width: 1.0,
            ),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : secondaryTextColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isSelected ? Colors.white : textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearFavoritesBottomSheet(
    BuildContext context,
    User currentUser,
    List<Deal> allDeals,
    List<Deal> expiredDeals,
    bool isDark,
  ) {
    final totalCount = allDeals.length;
    final expiredCount = expiredDeals.length;
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tutamaç Çizgisi
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Başlık & Açıklama
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_delete_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kayıtları Temizle',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Listenizden kaldırmak istediğiniz seçeneği belirleyin',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Seçenek 1: Süresi Dolanları Temizle (Varsa)
                if (expiredCount > 0) ...[
                  _buildClearOptionTile(
                    title: 'Süresi Dolanları Temizle ($expiredCount İlan)',
                    subtitle: 'Yalnızca süresi dolmuş fırsatları kaldırır. Aktif fırsatlarınız korunur.',
                    icon: Icons.hourglass_bottom_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () async {
                      Navigator.pop(bottomSheetContext);
                      for (var d in expiredDeals) {
                        await _firestoreService.removeFromFavorites(currentUser.uid, d.id);
                      }
                      if (mounted) {
                        setState(() {
                          if (_favoriteFilterIndex == 2) {
                            _favoriteFilterIndex = 0;
                          }
                        });
                        _showCustomSnackBar(
                          message: '$expiredCount adet süresi dolan kayıt temizlendi',
                          icon: Icons.check_circle_rounded,
                          backgroundColor: const Color(0xFF10B981),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Seçenek 2: Tümünü Temizle
                _buildClearOptionTile(
                  title: 'Tüm Kayıtları Temizle ($totalCount İlan)',
                  subtitle: 'Aktif ve süresi dolan tüm kayıtlı fırsatları listenizden kalıcı olarak siler.',
                  icon: Icons.delete_forever_rounded,
                  iconColor: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    for (var d in allDeals) {
                      await _firestoreService.removeFromFavorites(currentUser.uid, d.id);
                    }
                    if (mounted) {
                      setState(() {
                        _favoriteFilterIndex = 0;
                      });
                      _showCustomSnackBar(
                        message: '$totalCount adet kayıtlı fırsat temizlendi',
                        icon: Icons.delete_sweep_rounded,
                        backgroundColor: const Color(0xFFEF4444),
                      );
                    }
                  },
                ),
                const SizedBox(height: 14),

                // İptal Butonu
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Vazgeç',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClearOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2.5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredState(bool isDark) {
    String title = 'Fırsat Bulunamadı';
    String message = 'Bu filtreye uygun kayıtlı fırsatınız bulunmuyor.';
    IconData icon = Icons.inbox_rounded;

    if (_favoriteFilterIndex == 1) {
      title = 'Aktif Fırsat Bulunmuyor';
      message = 'Kaydettiğiniz tüm fırsatların süresi dolmuş. \'Süresi Dolanlar\' filtresinden inceleyebilirsiniz.';
      icon = Icons.hourglass_bottom_rounded;
    } else if (_favoriteFilterIndex == 2) {
      title = 'Süresi Dolan Fırsat Yok 🎉';
      message = 'Kaydettiğiniz tüm fırsatlar hala güncel ve aktif!';
      icon = Icons.check_circle_outline_rounded;
    }

    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _favoriteFilterIndex = 0);
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tüm Kayıtları Göster'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealGrid(List<Deal> deals, bool isDark, ScrollController scrollController) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          setState(() {
            _myFavoritesStream = _firestoreService.getFavoriteDeals(currentUser.uid);
            _followedCategoriesStream = _firestoreService.getFollowedCategoriesDeals(currentUser.uid);
          });
        }
      },
      child: GridView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.61,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: deals.length,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return DealCard(
            deal: deal,
            viewMode: CardViewMode.vertical,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DealDetailScreen(dealId: deal.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFollowedCategories(User? currentUser, bool isDark) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    if (currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.category_outlined,
                  size: 36,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Favori Kategoriler İçin Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Takip ettiğiniz özel kategorilerin anlık fırsat akışını görmek için giriş yapmalısınız.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showGuestLoginBottomSheet(
                    context,
                    title: 'Kategorileri Takip Etmek İçin Giriş Yap! 🏷️',
                    message: 'İlgilendiğin kategorileri takibe almak ve özel akışını oluşturmak için giriş yap.',
                    primaryButtonText: '🚀 Google ile Giriş Yap',
                    onLoginSuccess: () => setState(() {}),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'Giriş Yap',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<Deal>>(
      stream: _followedCategoriesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid(isDark);
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 14),
                Text(
                  'Bir hata oluştu',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }

        final deals = snapshot.data ?? [];

        if (deals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.category_outlined,
                    size: 34,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz Fırsat Bulunamadı',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Takip ettiğiniz kategorilerde son 48 saatte paylaşılan yeni bir fırsat bulunmuyor veya henüz kategori seçmediniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategoryPreferencesScreen(),
                      ),
                    ).then((_) {
                      setState(() {
                        _followedCategoriesStream = _firestoreService.getFollowedCategoriesDeals(currentUser.uid);
                      });
                    });
                  },
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Kategorileri Yönet & Takip Et',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 16,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${deals.length} Fırsat',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategoryPreferencesScreen(),
                          ),
                        ).then((_) {
                          setState(() {
                            _followedCategoriesStream = _firestoreService.getFollowedCategoriesDeals(currentUser.uid);
                          });
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 14,
                              color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Kategorileri Düzenle',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _showCleanupButton ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
            ),
            Expanded(
              child: _buildDealGrid(deals, isDark, _followedCategoriesScrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.61,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const DealCardSkeleton(viewMode: CardViewMode.vertical);
      },
    );
  }
}
