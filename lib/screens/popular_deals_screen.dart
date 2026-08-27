import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deal.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import 'deal_detail_screen.dart';

class PopularDealsScreen extends StatefulWidget {
  final bool isRootTab;

  const PopularDealsScreen({
    super.key,
    this.isRootTab = false,
  });

  @override
  State<PopularDealsScreen> createState() => _PopularDealsScreenState();
}

class _PopularDealsScreenState extends State<PopularDealsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  late CardViewMode _viewMode;
  late Stream<List<Deal>> _popularDealsStream;
  late ScrollController _scrollController;
  final ScrollController _categoryScrollController = ScrollController();
  bool _showScrollToTop = false;
  String _selectedCategory = 'tumu';

  @override
  void initState() {
    super.initState();
    _viewMode = _themeService.viewMode;
    _themeService.addListener(_onThemeChanged);
    _popularDealsStream = _firestoreService.getPopularDeals();
    _scrollController = ScrollController()..addListener(_scrollListener);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final shouldShow = offset > 800;
    if (shouldShow != _showScrollToTop && mounted) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _viewMode = _themeService.viewMode;
      });
    }
  }

  List<Deal> _filterDealsByCategory(List<Deal> deals) {
    if (_selectedCategory == 'tumu') return deals;

    final targetId = _selectedCategory.toLowerCase();
    return deals.where((deal) {
      final dealCat = deal.category.trim().toLowerCase();
      final normalizedId = Category.normalizeCategoryId(dealCat);
      return dealCat == targetId || normalizedId == targetId;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isRootTab,
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.whatshot_rounded, color: Color(0xFFFF6B35), size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Popüler Fırsatlar',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
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
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1.0),
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
      body: Column(
        children: [
          // ─── Kategori Filtreleri (HomeScreen Tasarım Standardı) ────
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                controller: _categoryScrollController,
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: Category.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = Category.categories[index];
                  final isSelected = _selectedCategory == category.id;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedCategory = category.id;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                          if (category.id == 'tumu') ...[
                            Icon(
                              Icons.apps_rounded,
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppTheme.darkTextSecondary
                                      : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                          ] else if (category.icon.isNotEmpty) ...[
                            Text(
                              category.icon,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            category.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? const Color(0xFFE4E4E7)
                                      : const Color(0xFF334155)),
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ─── 48 Saatlik Algoritma Bilgilendirme Şeridi (FavoritesScreen Standardı) ────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
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
                  const Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Son 48 saatin en yüksek ilgi gören canlı trendleri',
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

          // ─── Fırsatlar Akışı ────
          Expanded(
            child: StreamBuilder<List<Deal>>(
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
                          Icons.error_outline_rounded,
                          size: 56,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Popüler fırsatlar yüklenemedi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final rawDeals = List<Deal>.from(snapshot.data ?? []);
                final deals = _filterDealsByCategory(rawDeals);

                if (deals.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withValues(alpha: isDark ? 0.15 : 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.whatshot_rounded,
                              size: 48,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCategory == 'tumu'
                                ? 'Henüz popüler fırsat yok'
                                : 'Bu kategoride son 48 saatte popüler fırsat bulunamadı',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Topluluk tarafından sıcak oylanan (AL!) ve canlı olan fırsatlar otomatik olarak burada listelenir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _popularDealsStream = _firestoreService.getPopularDeals();
                    });
                  },
                  color: primaryColor,
                  child: _viewMode == CardViewMode.vertical
                      ? GridView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.61,
                          ),
                          itemCount: deals.length,
                          itemBuilder: (context, index) {
                            final deal = deals[index];
                            return DealCard(
                              key: ValueKey('pop_deal_${deal.id}_v'),
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
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.all(16),
                          itemCount: deals.length,
                          itemBuilder: (context, index) {
                            final deal = deals[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DealCard(
                                key: ValueKey('pop_deal_${deal.id}_h'),
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
          ),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              heroTag: 'popular_scroll_to_top',
              onPressed: () {
                HapticFeedback.lightImpact();
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  );
                }
              },
              backgroundColor: primaryColor,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 15,
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF0F172A))
              : (isDark ? Colors.grey[500] : Colors.grey[400]),
        ),
      ),
    );
  }

  Widget _buildLoadingGrid(bool isDark) {
    if (_viewMode == CardViewMode.horizontal) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const DealCardSkeleton(viewMode: CardViewMode.horizontal),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.61,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const DealCardSkeleton(viewMode: CardViewMode.vertical);
      },
    );
  }
}
