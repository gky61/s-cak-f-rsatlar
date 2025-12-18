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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Beğendiklerim'),
                Tab(text: 'En Çok Beğenilenler'),
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
      stream: _firestoreService.getFavoriteDeals(currentUser.uid),
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

        return _buildDealGrid(deals, isDark);
      },
    );
  }

  Widget _buildMostLiked(bool isDark) {
    return StreamBuilder<List<Deal>>(
      stream: _firestoreService.getMostLikedDeals(minLikes: 25),
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
          childAspectRatio: 0.65,
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

  Widget _buildLoadingGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
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
