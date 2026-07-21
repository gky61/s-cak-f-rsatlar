import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/deal.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
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
  Stream<List<Deal>>? _mostLikedStream;
  Stream<List<Deal>>? _followedCategoriesStream;
  String? _cachedUserId;

  @override
  void initState() {
    super.initState();
    // İlk açılışta "Beğendiklerim" sekmesini göster
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    // En Çok Beğenilenler genel bir stream olduğundan burada başlatabiliriz
    _mostLikedStream = _firestoreService.getMostLikedDeals(minLikes: 25);
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
    _tabController.dispose();
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
          'Beğenilenler',
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
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              isScrollable: false,
              tabs: const [
                Tab(text: 'Beğendiklerim'),
                Tab(text: 'En Çok Beğenilenler'),
                Tab(text: 'Favori Kategorilerim'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Beğendiklerim
          _buildMyFavorites(currentUser, isDark),
          // En Çok Beğenilenler (25+)
          _buildMostLiked(isDark),
          // Favori Kategorilerim
          _buildFollowedCategories(currentUser, isDark),
        ],
      ),
    );
  }

  Widget _buildMyFavorites(User? currentUser, bool isDark) {
    if (currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Giriş yapmalısınız',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Beğendiğiniz fırsatları görmek için\ngiriş yapın',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ],
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
                  Icons.favorite_border,
                  size: 64,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz beğendiğiniz fırsat yok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Beğendiğiniz fırsatlar burada görünecek',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final hasExpired = deals.any((d) => d.isExpired);

        return Column(
          children: [
            if (hasExpired)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Temizle'),
                            content: const Text('Süresi dolmuş tüm favori ilanları listenizden kaldırmak istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Temizle'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final expiredDeals = deals.where((d) => d.isExpired).toList();
                          for (var d in expiredDeals) {
                            await _firestoreService.removeFromFavorites(currentUser.uid, d.id);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Süresi dolan favoriler temizlendi')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                      label: const Text(
                        'Süresi Dolanları Temizle',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildDealGrid(deals, isDark),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMostLiked(bool isDark) {
    return StreamBuilder<List<Deal>>(
      stream: _mostLikedStream,
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
                  Icons.local_fire_department_outlined,
                  size: 64,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz çok beğenilen fırsat yok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '25+ beğeni alan fırsatlar burada görünecek',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildDealGrid(deals, isDark);
      },
    );
  }

  Widget _buildDealGrid(List<Deal> deals, bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.63,
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

  Widget _buildFollowedCategories(User? currentUser, bool isDark) {
    if (currentUser == null) {
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
              'Giriş yapmalısınız',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Takip ettiğiniz kategorilerin fırsatlarını\ngörmek için giriş yapın',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ],
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
                  'Kategori bildirimlerini açtığınız\nkategorilerin fırsatları burada görünecek',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildDealGrid(deals, isDark);
      },
    );
  }

  Widget _buildLoadingGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.63,
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



