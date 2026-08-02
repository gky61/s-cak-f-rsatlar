import 'package:flutter/material.dart';
import '../models/deal.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import 'deal_detail_screen.dart';

class PopularDealsScreen extends StatefulWidget {
  const PopularDealsScreen({super.key});

  @override
  State<PopularDealsScreen> createState() => _PopularDealsScreenState();
}

class _PopularDealsScreenState extends State<PopularDealsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  late CardViewMode _viewMode;
  late Stream<List<Deal>> _popularDealsStream;

  @override
  void initState() {
    super.initState();
    _viewMode = _themeService.viewMode;
    _themeService.addListener(_onThemeChanged);
    _popularDealsStream = _firestoreService.getPopularDeals();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _viewMode = _themeService.viewMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.whatshot_rounded, color: Colors.orange[700], size: 22),
            const SizedBox(width: 6),
            Text(
              'Popüler Fırsatlar',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
        actions: [
          // Grid / List View Toggle
          Container(
            margin: const EdgeInsets.only(right: 12),
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggle(
                  icon: Icons.grid_view_rounded,
                  isSelected: _viewMode == CardViewMode.vertical,
                  onTap: () => _themeService.setViewMode(CardViewMode.vertical),
                  isDark: isDark,
                ),
                _buildViewToggle(
                  icon: Icons.view_agenda_rounded,
                  isSelected: _viewMode == CardViewMode.horizontal,
                  onTap: () => _themeService.setViewMode(CardViewMode.horizontal),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Deal>>(
        stream: _popularDealsStream,
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

          final deals = List<Deal>.from(snapshot.data ?? []);
          // Sıralama zaten firestore_service'te popularityScore ile yapılıyor

          if (deals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.whatshot_rounded,
                    size: 64,
                    color: Colors.orange[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz popüler bir fırsat yok',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Topluluk tarafından sıcak bakılan (AL!)\npopüler fırsatlar burada gösterilecek',
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _popularDealsStream = _firestoreService.getPopularDeals();
              });
            },
            color: primaryColor,
            child: _viewMode == CardViewMode.vertical
                ? GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.63,
                    ),
                    itemCount: deals.length,
                    itemBuilder: (context, index) {
                      final deal = deals[index];
                      return DealCard(
                        key: ValueKey('pop_deal_${deal.id}'),
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
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: deals.length,
                    itemBuilder: (context, index) {
                      final deal = deals[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DealCard(
                          key: ValueKey('pop_deal_list_${deal.id}'),
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
                  ),
          );
        },
      ),
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF1A1A2E))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.35)
                  : const Color(0xFFB0B0B0)),
        ),
      ),
    );
  }

  Widget _buildLoadingGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.63,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return DealCardSkeleton(viewMode: _viewMode);
      },
    );
  }
}
