import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deal.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import '../widgets/scroll_to_top_button.dart';
import '../widgets/ad_deal_card.dart';
import '../services/ad_manager_service.dart';
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
  late ScrollController _scrollController;
  final ScrollController _categoryScrollController = ScrollController();
  bool _showScrollToTop = false;
  String _selectedCategory = 'tumu';

  // FS-18: SWR, Pagination & Cache-First State
  List<Deal> _dealsList = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _isFirstLoad = true;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewMode = _themeService.viewMode;
    _themeService.addListener(_onThemeChanged);
    _scrollController = ScrollController()..addListener(_scrollListener);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  /// SWR + Cache-First ilk yükleme
  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Aşama: Cache-First (0 milisaniye yerel önbellekten anında açılış)
      try {
        final cacheResult = await _firestoreService.getPopularDealsPaginated(
          limit: 45,
          source: Source.cache,
        );
        if (mounted && cacheResult.deals.isNotEmpty) {
          setState(() {
            _dealsList = cacheResult.deals;
            _lastDocument = cacheResult.lastDocument;
            _hasMore = cacheResult.hasMore;
            _isFirstLoad = false;
          });
        }
      } catch (_) {
        // Önbellek boşsa sessizce sunucu aşamasına geç
      }

      // 2. Aşama: Stale-While-Revalidate (Sunucudan taze doğrula)
      final serverResult = await _firestoreService.getPopularDealsPaginated(
        limit: 45,
        source: Source.server,
      );

      if (mounted) {
        setState(() {
          _dealsList = serverResult.deals;
          _lastDocument = serverResult.lastDocument;
          _hasMore = serverResult.hasMore;
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
          if (_dealsList.isEmpty) {
            _errorMessage = 'Popüler fırsatlar yüklenemedi';
          }
        });
      }
    }
  }

  /// Sonsuz kaydırma: Bir sonraki sayfayı getir
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore || _lastDocument == null || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _firestoreService.getPopularDealsPaginated(
        limit: 30,
        lastDocument: _lastDocument,
        source: Source.serverAndCache,
      );

      if (mounted) {
        final existingIds = _dealsList.map((d) => d.id).toSet();
        final newDeals = result.deals.where((d) => !existingIds.contains(d.id)).toList();

        setState(() {
          _dealsList.addAll(newDeals);
          _lastDocument = result.lastDocument;
          _hasMore = result.hasMore;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final shouldShow = offset > ScrollToTopButton.defaultThreshold;
    if (shouldShow != _showScrollToTop && mounted) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }

    // Ekran sonuna 350px kala sonraki sayfayı tetikle
    if (offset >= _scrollController.position.maxScrollExtent - 350) {
      _loadMore();
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

  /// Reklam pozisyonlarını hesapla (5-6-5-6-5-6 pattern)
  /// Pattern: İlk reklam 5 deal'den sonra, ikinci 6 deal'den sonra, üçüncü 5 deal'den sonra, vs.
  List<int> _calculateAdPositions(int dealCount) {
    List<int> positions = [];
    int currentPosition = 5; // İlk reklam 5 deal'den sonra
    int patternIndex = 0;

    while (currentPosition < dealCount) {
      positions.add(currentPosition);
      int interval = (patternIndex % 2 == 0) ? 6 : 5;
      currentPosition += interval + 1;
      patternIndex++;
    }

    return positions;
  }

  /// 2 sütunlu dikey Grid görünümünde her 6 üründe bir (3 satırda bir)
  /// iki sütunun arasını boydan boya kaplayan tam genişlikte yatay Native Reklam kartı yerleştirir.
  List<Widget> _buildGridWithHorizontalAdsSlivers({
    required BuildContext context,
    required List<Deal> dealsToShow,
    required bool isDark,
    required bool showAds,
    required int chunkSize,
  }) {
    final List<Widget> slivers = [];
    final int totalChunks = (dealsToShow.length / chunkSize).ceil();

    for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      final startIndex = chunkIndex * chunkSize;
      final endIndex = (startIndex + chunkSize > dealsToShow.length)
          ? dealsToShow.length
          : startIndex + chunkSize;
      final chunkDeals = dealsToShow.sublist(startIndex, endIndex);
      final isLastChunk = chunkIndex == totalChunks - 1;

      // 1. Ürün Grid Bölümü (2 Sütunlu)
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            12,
            chunkIndex == 0 ? 8 : 4,
            12,
            (isLastChunk && (!showAds || chunkDeals.length < chunkSize)) ? 24 : 4,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 11,
              childAspectRatio: 0.635,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, idx) {
                final deal = chunkDeals[idx];
                return RepaintBoundary(
                  key: ValueKey('pop_deal_grid_boundary_${deal.id}'),
                  child: DealCard(
                    key: ValueKey('pop_deal_${deal.id}_v'),
                    deal: deal,
                    viewMode: CardViewMode.vertical,
                    onTap: () {
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
      if (showAds && chunkDeals.length == chunkSize) {
        slivers.add(
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, isLastChunk ? 24 : 6),
            sliver: SliverToBoxAdapter(
              child: AdDealCard(
                key: ValueKey('ad_card_popular_grid_$chunkIndex'),
                viewMode: CardViewMode.horizontal,
                placement: 'popular',
              ),
            ),
          ),
        );
      }
    }

    return slivers;
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
            child: _buildDealsContent(context, isDark, primaryColor),
          ),
        ],
      ),
      floatingActionButton: ScrollToTopButton(
        isVisible: _showScrollToTop,
        scrollController: _scrollController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildDealsContent(BuildContext context, bool isDark, Color primaryColor) {
    if (_isFirstLoad && _isLoading && _dealsList.isEmpty) {
      return _buildLoadingGrid(isDark);
    }

    if (_errorMessage != null && _dealsList.isEmpty) {
      return Center(
        child: Padding(
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
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadFirstPage,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    final deals = _filterDealsByCategory(_dealsList);

    if (deals.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await _loadFirstPage();
        },
        color: primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
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
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await _loadFirstPage();
      },
      color: primaryColor,
      child: ListenableBuilder(
        listenable: AdManagerService.instance,
        builder: (context, _) {
          final adManager = AdManagerService.instance;
          final bool showAds = adManager.isAdsEnabled &&
              adManager.nativeEnabled &&
              adManager.nativePopularEnabled;
          final int chunkSize = (adManager.nativePopularInterval >= 4 &&
                  adManager.nativePopularInterval <= 20)
              ? adManager.nativePopularInterval
              : 6;

          if (_viewMode == CardViewMode.vertical) {
            if (!showAds || deals.length < chunkSize) {
              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 11,
                        childAspectRatio: 0.635,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final deal = deals[index];
                          return RepaintBoundary(
                            key: ValueKey('pop_deal_grid_boundary_${deal.id}'),
                            child: DealCard(
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
                            ),
                          );
                        },
                        childCount: deals.length,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),
                  if (_isLoading && !_isFirstLoad)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ),
                ],
              );
            } else {
              final slivers = _buildGridWithHorizontalAdsSlivers(
                context: context,
                dealsToShow: deals,
                isDark: isDark,
                showAds: showAds,
                chunkSize: chunkSize,
              );
              if (_isLoading && !_isFirstLoad) {
                slivers.add(
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                  ),
                );
              }
              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: slivers,
              );
            }
          } else {
            // Liste Modu (5-6-5-6 pattern)
            final List<int> adPositions = showAds ? _calculateAdPositions(deals.length) : const [];
            final int adCount = adPositions.length;
            final bool showBottomSpinner = _isLoading && !_isFirstLoad;
            final int totalItemCount = deals.length + adCount + (showBottomSpinner ? 1 : 0);

            return ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: true,
              addSemanticIndexes: false,
              itemCount: totalItemCount,
              itemBuilder: (context, index) {
                if (showBottomSpinner && index == totalItemCount - 1) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  );
                }

                int passedAds = 0;
                for (int i = 0; i < adPositions.length; i++) {
                  final adPosition = adPositions[i];
                  if (index == adPosition) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdDealCard(
                        key: ValueKey('ad_card_popular_horizontal_$i'),
                        viewMode: CardViewMode.horizontal,
                        placement: 'popular',
                      ),
                    );
                  }
                  if (index > adPosition) {
                    passedAds++;
                  }
                }

                final actualIndex = index - passedAds;
                if (actualIndex >= deals.length || actualIndex < 0) {
                  return const SizedBox.shrink();
                }
                final deal = deals[actualIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RepaintBoundary(
                    key: ValueKey('pop_deal_list_boundary_${deal.id}'),
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
                  ),
                );
              },
            );
          }
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
        mainAxisSpacing: 11,
        childAspectRatio: 0.635,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const DealCardSkeleton(viewMode: CardViewMode.vertical);
      },
    );
  }
}
