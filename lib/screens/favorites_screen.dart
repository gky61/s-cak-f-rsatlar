import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/deal.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../widgets/scroll_to_top_button.dart';
import 'category_preferences_screen.dart';
import 'deal_detail_screen.dart';
import '../services/ad_manager_service.dart';
import '../widgets/ad_deal_card.dart';
import '../widgets/app_snack_bar.dart';

class FavoritesScreen extends StatefulWidget {
  final bool isRootTab;

  const FavoritesScreen({
    super.key,
    this.isRootTab = false,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  late TabController _tabController;

  // Cached streams to prevent re-listening/recreating on rebuilds
  Stream<List<Deal>>? _myFavoritesStream;
  String? _cachedUserId;
  StreamSubscription? _authSub;

  // FS-18: Followed Categories SWR & Pagination State
  List<Deal> _followedDealsList = [];
  DocumentSnapshot? _lastFollowedDocument;
  bool _isLoadingFollowed = false;
  bool _isFirstLoadFollowed = true;
  bool _hasMoreFollowed = true;
  String? _followedErrorMessage;

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
    _themeService.addListener(_onThemeChanged);

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _initializeStreams(user?.uid);
        setState(() {});
      }
    });
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
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

    // 700px scroll sonrası yukarı fırlatma butonu kontrolü
    bool showScrollToTopNow = offset > ScrollToTopButton.defaultThreshold;

    if (showBannerNow != _showBanner || showCleanupNow != _showCleanupButton || showScrollToTopNow != _showScrollToTop) {
      setState(() {
        _showBanner = showBannerNow;
        _showCleanupButton = showCleanupNow;
        _showScrollToTop = showScrollToTopNow;
      });
    }

    // FS-18: Takip edilen kategoriler sonsuz kaydırma tetikleyicisi
    if (_tabController.index == 1 && _followedCategoriesScrollController.hasClients) {
      if (_followedCategoriesScrollController.offset >=
          _followedCategoriesScrollController.position.maxScrollExtent - 350) {
        _loadMoreFollowed();
      }
    }
  }

  void _tabListener() {
    if (!_tabController.indexIsChanging) {
      HapticFeedback.selectionClick();
      double offset = 0;
      if (_tabController.index == 0 && _myFavoritesScrollController.hasClients) {
        offset = _myFavoritesScrollController.offset;
      } else if (_tabController.index == 1) {
        if (_followedCategoriesScrollController.hasClients) {
          offset = _followedCategoriesScrollController.offset;
        }
        if (_followedDealsList.isEmpty && !_isLoadingFollowed) {
          _loadFollowedFirstPage();
        }
      }

      setState(() {
        _showBanner = true;
        _showCleanupButton = offset <= 15;
        _showScrollToTop = offset > ScrollToTopButton.defaultThreshold;
      });
    }
  }

  void _initializeStreams(String? userId) {
    if (userId == null) {
      _myFavoritesStream = null;
      _cachedUserId = null;
      _followedDealsList = [];
      _lastFollowedDocument = null;
      return;
    }
    if (_cachedUserId != userId) {
      _cachedUserId = userId;
      _myFavoritesStream = _firestoreService.getFavoriteDeals(userId);
      _loadFollowedFirstPage();
    }
  }

  /// FS-18: Followed Categories SWR + Cache-First ilk yükleme
  Future<void> _loadFollowedFirstPage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    setState(() {
      _isLoadingFollowed = true;
      _followedErrorMessage = null;
    });

    try {
      // 1. Aşama: Cache-First (0ms yerel önbellekten açılış)
      try {
        final cacheResult = await _firestoreService.getFollowedCategoriesDealsPaginated(
          userId: user.uid,
          limit: 45,
          source: Source.cache,
        );
        if (mounted && cacheResult.deals.isNotEmpty) {
          setState(() {
            _followedDealsList = cacheResult.deals;
            _lastFollowedDocument = cacheResult.lastDocument;
            _hasMoreFollowed = cacheResult.hasMore;
            _isFirstLoadFollowed = false;
          });
        }
      } catch (_) {}

      // 2. Aşama: SWR Server Revalidation (Sunucudan taze doğrula)
      final serverResult = await _firestoreService.getFollowedCategoriesDealsPaginated(
        userId: user.uid,
        limit: 45,
        source: Source.server,
      );

      if (mounted) {
        setState(() {
          _followedDealsList = serverResult.deals;
          _lastFollowedDocument = serverResult.lastDocument;
          _hasMoreFollowed = serverResult.hasMore;
          _isLoadingFollowed = false;
          _isFirstLoadFollowed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFollowed = false;
          _isFirstLoadFollowed = false;
          if (_followedDealsList.isEmpty) {
            _followedErrorMessage = 'Fırsatlar yüklenemedi';
          }
        });
      }
    }
  }

  /// FS-18: Sonsuz kaydırma - Takip edilen kategoriler sonraki sayfa
  Future<void> _loadMoreFollowed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isLoadingFollowed || !_hasMoreFollowed || _lastFollowedDocument == null || !mounted) return;

    setState(() {
      _isLoadingFollowed = true;
    });

    try {
      final result = await _firestoreService.getFollowedCategoriesDealsPaginated(
        userId: user.uid,
        limit: 30,
        lastDocument: _lastFollowedDocument,
        source: Source.serverAndCache,
      );

      if (mounted) {
        final existingIds = _followedDealsList.map((d) => d.id).toSet();
        final newDeals = result.deals.where((d) => !existingIds.contains(d.id)).toList();

        setState(() {
          _followedDealsList.addAll(newDeals);
          _lastFollowedDocument = result.lastDocument;
          _hasMoreFollowed = result.hasMore && newDeals.isNotEmpty;
          _isLoadingFollowed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingFollowed = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _themeService.removeListener(_onThemeChanged);
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

    AppSnackBar.show(
      context: context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);
    final currentUser = FirebaseAuth.instance.currentUser;

    _initializeStreams(currentUser?.uid);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isRootTab,
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
      floatingActionButton: ScrollToTopButton(
        isVisible: _showScrollToTop,
        onPressed: () {
          final controller = _tabController.index == 0
              ? _myFavoritesScrollController
              : _followedCategoriesScrollController;
          if (controller.hasClients) {
            controller.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          }
        },
      ),
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
        final activeDeals = deals.where((d) => !d.isArchived).toList();
        final expiredDeals = deals.where((d) => d.isArchived).toList();
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
          });
          await _loadFollowedFirstPage();
        }
      },
      child: GridView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.635,
          crossAxisSpacing: 12,
          mainAxisSpacing: 11,
        ),
        itemCount: deals.length,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return RepaintBoundary(
            key: ValueKey('fav_deal_boundary_${deal.id}'),
            child: DealCard(
              key: ValueKey('fav_deal_${deal.id}_v'),
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
            ),
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

    if (_isFirstLoadFollowed && _isLoadingFollowed && _followedDealsList.isEmpty) {
      return _buildLoadingGrid(isDark);
    }

    if (_followedErrorMessage != null && _followedDealsList.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadFollowedFirstPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
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
                  _followedErrorMessage ?? 'Bir hata oluştu',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _loadFollowedFirstPage();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Tekrar Dene',
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
          ),
        ),
      );
    }

    final deals = _followedDealsList;

    if (deals.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadFollowedFirstPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
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
                      _loadFollowedFirstPage();
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
          ),
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
                      _loadFollowedFirstPage();
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
          child: _buildFollowedCategoriesDealGrid(deals, isDark, _followedCategoriesScrollController),
        ),
      ],
    );
  }

  /// Favori Kategorilerim (Takip Edilenler) sekmesi için AdMob destekli dinamik Grid.
  /// Anasayfa ve Popüler Fırsatlar ile birebir aynı mimaride:
  /// 2 sütunlu ürün grid'i her [chunkSize] üründe bir bölünerek araya tam genişlikte
  /// 124dp yatay Native Reklam kartı (TemplateType.small) yerleştirilir.
  /// Reklam kapalıysa veya eşiğin altındaysa temiz ızgara (_buildDealGrid) kullanılır.
  Widget _buildFollowedCategoriesDealGrid(
    List<Deal> deals,
    bool isDark,
    ScrollController scrollController,
  ) {
    return ListenableBuilder(
      listenable: AdManagerService.instance,
      builder: (context, _) {
        final adManager = AdManagerService.instance;
        final bool isAdEnabled = adManager.isAdsEnabled &&
            adManager.nativeEnabled &&
            adManager.nativeFollowedCategoriesEnabled;
        final int chunkSize = (adManager.nativeFollowedCategoriesInterval >= 4 &&
                adManager.nativeFollowedCategoriesInterval <= 20)
            ? adManager.nativeFollowedCategoriesInterval
            : 6;

        // Eşik koruması: Reklam kapalıysa veya ilan sayısı chunk boyutundan azsa standart temiz grid göster
        if (!isAdEnabled || deals.length < chunkSize) {
          return _buildDealGrid(deals, isDark, scrollController);
        }

        final int totalChunks = (deals.length / chunkSize).ceil();
        final List<Widget> slivers = [];

        for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
          final startIndex = chunkIndex * chunkSize;
          final endIndex = (startIndex + chunkSize > deals.length)
              ? deals.length
              : startIndex + chunkSize;
          final chunkDeals = deals.sublist(startIndex, endIndex);
          final isLastChunk = chunkIndex == totalChunks - 1;

          // 1. Ürün Grid Bölümü (2 Sütunlu)
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                chunkIndex == 0 ? 12 : 6,
                16,
                (isLastChunk && chunkDeals.length < chunkSize) ? 24 : 6,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.635,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 11,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) {
                    final deal = chunkDeals[idx];
                    return RepaintBoundary(
                      key: ValueKey('fav_cat_deal_grid_boundary_${deal.id}'),
                      child: DealCard(
                        key: ValueKey('fav_cat_deal_${deal.id}_v'),
                        deal: deal,
                        viewMode: CardViewMode.vertical,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => DealDetailScreen(dealId: deal.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: chunkDeals.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                ),
              ),
            ),
          );

          // 2. Tam Genişlikte Yatay Native Reklam (Her chunkSize üründen sonra)
          if (chunkDeals.length == chunkSize) {
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, isLastChunk ? 24 : 6),
                sliver: SliverToBoxAdapter(
                  child: AdDealCard(
                    key: ValueKey('ad_card_fav_cat_grid_$chunkIndex'),
                    viewMode: CardViewMode.horizontal,
                    placement: 'favorite_categories',
                  ),
                ),
              ),
            );
          }
        }

        if (_isLoadingFollowed && !_isFirstLoadFollowed) {
          slivers.add(
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _loadFollowedFirstPage,
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: slivers,
          ),
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
        childAspectRatio: 0.635,
        crossAxisSpacing: 12,
        mainAxisSpacing: 11,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const DealCardSkeleton(viewMode: CardViewMode.vertical);
      },
    );
  }
}
