import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUser = FirebaseAuth.instance.currentUser;

    _initializeStreams(currentUser?.uid);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        title: Text(
          'Kaydedilenler',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.05),
                  width: 2,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              labelColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              isScrollable: false,
              tabs: const [
                Tab(text: 'Kaydettiklerim'),
                Tab(text: 'Favori Kategorilerim'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Kaydettiklerim
          _buildMyFavorites(currentUser, isDark),
          // Favori Kategorilerim
          _buildFollowedCategories(currentUser, isDark, primaryColor),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              heroTag: 'favorites_scroll_to_top',
              mini: true,
              onPressed: () {
                final controller = _tabController.index == 0 
                    ? _myFavoritesScrollController 
                    : _followedCategoriesScrollController;
                if (controller.hasClients) {
                  controller.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  );
                }
              },
              backgroundColor: primaryColor,
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.black),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildMyFavorites(User? currentUser, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    if (currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bookmark_border,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Kaydedilenler İçin Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kaydettiğiniz fırsatları görmek ve listenize yeni fırsatlar eklemek için giriş yapmalısınız.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
                  Icons.error_outline,
                  size: 64,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Bir hata oluştu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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
                Icon(
                  Icons.bookmark_border,
                  size: 64,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz kaydettiğiniz fırsat yok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kaydettiğiniz fırsatlar burada görünecek',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
            // 30 gün bilgilendirme mesajı (Kaydırınca gizlenir, tab değişince geri gelir)
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.amber.withValues(alpha: 0.08)
                        : Colors.amber.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '30 günden eski fırsatlar otomatik olarak kalıcı silinir.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.amber[200] : Colors.amber[800],
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

            // Filtre Çipleri & Temizle Barı (Ekrana Tam Oturan Dengeli ve Ferah Tasarım)
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
                      selectedColor: primaryColor,
                      onTap: () => setState(() => _favoriteFilterIndex = 0),
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
                      onTap: () => setState(() => _favoriteFilterIndex = 1),
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
                        onTap: () => setState(() => _favoriteFilterIndex = 2),
                      ),
                    ),
                  ],

                  // Temizle Butonu
                  if (totalCount > 0) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showClearFavoritesBottomSheet(
                          context,
                          currentUser,
                          deals,
                          expiredDeals,
                          isDark,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_delete_outlined,
                                color: Colors.redAccent,
                                size: 13,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Temizle',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
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
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppTheme.darkTextPrimary : const Color(0xFF334155)),
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
    final messenger = ScaffoldMessenger.of(context);
    final totalCount = allDeals.length;
    final expiredCount = expiredDeals.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
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
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Başlık & Açıklama
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_delete_rounded,
                        color: Colors.redAccent,
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
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Listenizden kaldırmak istediğiniz seçeneği belirleyin',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
                    subtitle: 'Yalnızca süresi dolmuş veya tükenmiş fırsatları kaldırır. Aktif fırsatlarınız korunur.',
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
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('$expiredCount adet süresi dolan kayıt temizlendi'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
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
                  iconColor: Colors.redAccent,
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
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('$totalCount adet kayıtlı fırsat temizlendi'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
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
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Vazgeç',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              width: 1,
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
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2.5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
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
      message = 'Kaydettiğiniz tüm fırsatların süresi dolmuş. \'Süresi Dolanlar\' filtresinden arşive bakabilirsiniz.';
      icon = Icons.hourglass_bottom_rounded;
    } else if (_favoriteFilterIndex == 2) {
      title = 'Süresi Dolan Fırsat Yok 🎉';
      message = 'Kaydettiğiniz tüm fırsatlar hala güncel ve aktif!';
      icon = Icons.check_circle_outline_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: isDark ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => setState(() => _favoriteFilterIndex = 0),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tüm Kayıtları Göster'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealGrid(List<Deal> deals, bool isDark, ScrollController scrollController) {
    return RefreshIndicator(
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
        padding: const EdgeInsets.all(16),
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

  Widget _buildFollowedCategories(User? currentUser, bool isDark, Color primaryColor) {
    if (currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category_outlined,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Favori Kategoriler İçin Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Takip ettiğiniz özel kategorilerin anlık akışını görmek için giriş yapmalısınız.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
                  Icons.error_outline,
                  size: 64,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Bir hata oluştu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz takip ettiğiniz kategori yok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'İlgi duyduğunuz kategorileri takip ederek\nfırsatlarını burada görebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
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
                    'Kategorileri Seç & Takip Et',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 16,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${deals.length} Fırsat',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
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
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 15,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Kategorileri Düzenle',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
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



