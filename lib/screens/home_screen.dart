import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import '../models/category.dart';
import '../models/deal.dart';
import '../theme/app_theme.dart';
import 'deal_detail_screen.dart';
import 'submit_deal_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final ThemeService _themeService = ThemeService();
  
  String _selectedCategory = 'tumu';
  String? _selectedSubCategory;
  bool _isAdmin = false;
  bool _isCategoryMenuExpanded = false;
  Set<String> _followedCategories = {};
  Set<String> _followedSubCategories = {};
  bool _isGeneralNotificationsEnabled = true;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  
  // Görüntüleme modu: 'list', 'grid', 'compact'
  String _viewMode = 'list';

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _notificationService.requestPermission();
    _notificationService.setupNotificationListeners();
    _cleanupExpiredDeals();
    _loadFollowedCategories();
    // Theme service listener ekle
    _themeService.addListener(_onThemeChanged);
    // Scroll listener ekle
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // 150 piksel aşağı kaydırıldıysa veya en alta yakınsa butonu göster
    final shouldShow = offset > 150 || (maxScroll > 0 && offset > maxScroll * 0.1);
    
    // Sadece değişiklik olduğunda setState çağır
    if (shouldShow != _showScrollToTop && mounted) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowedCategories() async {
    final categories = await _notificationService.getFollowedCategories();
    final subCategories = await _notificationService.getFollowedSubCategories();
    final generalEnabled = await _notificationService.getGeneralNotificationsEnabled();
    if (mounted) {
      setState(() {
        _followedCategories = categories.toSet();
        _followedSubCategories = subCategories.toSet();
        _isGeneralNotificationsEnabled = generalEnabled;
      });
    }
  }

  Future<void> _toggleGeneralNotification() async {
    final newValue = !_isGeneralNotificationsEnabled;
    try {
      await _notificationService.setGeneralNotifications(newValue);
      if (mounted) {
        setState(() => _isGeneralNotificationsEnabled = newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue ? 'Tüm bildirimler açıldı' : 'Tüm bildirimler kapatıldı',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDeal(Deal deal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fırsatı Sil'),
        content: Text('"${deal.title}" fırsatını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _firestoreService.deleteDeal(deal.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fırsat silindi'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fırsat silinirken hata oluştu'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleCategoryNotification(String categoryId) async {
    try {
      if (_followedCategories.contains(categoryId)) {
        await _notificationService.unsubscribeFromCategory(categoryId);
      } else {
        await _notificationService.subscribeToCategory(categoryId);
      }
      await _loadFollowedCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _followedCategories.contains(categoryId)
                  ? 'Bildirim açıldı'
                  : 'Bildirim kapatıldı',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleSubCategoryNotification(String categoryId, String subCategory) async {
    try {
      final subCategoryKey = '$categoryId:$subCategory';
      if (_followedSubCategories.contains(subCategoryKey)) {
        await _notificationService.unsubscribeFromSubCategory(categoryId, subCategory);
      } else {
        await _notificationService.subscribeToSubCategory(categoryId, subCategory);
      }
      await _loadFollowedCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _followedSubCategories.contains(subCategoryKey)
                  ? 'Bildirim açıldı'
                  : 'Bildirim kapatıldı',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Expired deal'leri temizle (gün bittiğinde sil)
  Future<void> _cleanupExpiredDeals() async {
    try {
      await _firestoreService.cleanupExpiredDeals();
    } catch (e) {
      // Sessizce hata yok say, kullanıcıyı rahatsız etme
      print('Temizleme hatası: $e');
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: InkWell(
          onTap: () {
            setState(() {
              _isCategoryMenuExpanded = !_isCategoryMenuExpanded;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'FIRSATKOLİK 🔥',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isCategoryMenuExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.arrow_drop_down, size: 20),
              ),
            ],
          ),
        ),
        centerTitle: false,
        actions: [
          // Görüntüleme Modu Seçici
          PopupMenuButton<String>(
            icon: Icon(
              _viewMode == 'list' 
                  ? Icons.view_list_rounded
                  : _viewMode == 'grid'
                      ? Icons.grid_view_rounded
                      : _viewMode == 'compact'
                          ? Icons.view_compact_rounded
                          : Icons.view_agenda_rounded,
            ),
            onSelected: (value) {
              setState(() {
                _viewMode = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'list',
                child: Row(
                  children: [
                    Icon(
                      Icons.view_list_rounded,
                      size: 20,
                      color: _viewMode == 'list' ? AppTheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Liste'),
                    if (_viewMode == 'list')
                      const Spacer(),
                    if (_viewMode == 'list')
                      Icon(Icons.check, size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'grid',
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 20,
                      color: _viewMode == 'grid' ? AppTheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Grid'),
                    if (_viewMode == 'grid')
                      const Spacer(),
                    if (_viewMode == 'grid')
                      Icon(Icons.check, size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'compact',
                child: Row(
                  children: [
                    Icon(
                      Icons.view_compact_rounded,
                      size: 20,
                      color: _viewMode == 'compact' ? AppTheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Kompakt'),
                    if (_viewMode == 'compact')
                      const Spacer(),
                    if (_viewMode == 'compact')
                      Icon(Icons.check, size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'small_list',
                child: Row(
                  children: [
                    Icon(
                      Icons.view_agenda_rounded,
                      size: 20,
                      color: _viewMode == 'small_list' ? AppTheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Küçük Liste'),
                    if (_viewMode == 'small_list')
                      const Spacer(),
                    if (_viewMode == 'small_list')
                      Icon(Icons.check, size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
          // Karanlık Mod Toggle - Şık animasyonlu
          _buildThemeToggleButton(),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.error),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
        children: [
          // Ana Kategoriler (Yatay Kaydırmalı Chip'ler)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: Category.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = Category.categories[index];
                final isSelected = _selectedCategory == category.id && _selectedSubCategory == null;
                
                return FilterChip(
                  label: Text(
                    '${category.icon} ${category.name}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() {
                    _selectedCategory = category.id;
                    _selectedSubCategory = null;
                  }),
                  backgroundColor: Colors.white,
                  selectedColor: AppTheme.primary,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: isSelected ? 2 : 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                );
              },
            ),
          ),

          // Açılır Kategori Menüsü
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isCategoryMenuExpanded ? null : 0,
            child: _isCategoryMenuExpanded
                ? Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Tümü seçeneği
                          _buildCategoryItem(
                            Category.categories[0],
                            null,
                            isSelected: _selectedCategory == 'tumu' && _selectedSubCategory == null,
                            showNotification: true,
                          ),
                          const Divider(height: 1),
                          // Ana kategoriler
                          ...Category.categories
                              .where((cat) => cat.id != 'tumu')
                              .map((category) => _buildExpandableCategory(category))
                              .toList(),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Seçili kategori gösterimi (menü kapalıyken)
          if (!_isCategoryMenuExpanded && (_selectedCategory != 'tumu' || _selectedSubCategory != null))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getSelectedCategoryText(),
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTheme.primary,
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'tumu';
                        _selectedSubCategory = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Liste
          Expanded(
            child: StreamBuilder<List<Deal>>(
              stream: _firestoreService.getDealsStream(),
              builder: (context, snapshot) {
                // StreamBuilder'ı optimize et - sadece gerekli durumlarda rebuild
                // Hata durumu
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Bir hata oluştu: ${snapshot.error}',
                          style: TextStyle(color: Colors.red[500], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Yeniden Dene'),
                        ),
                      ],
                    ),
                  );
                }

                // Veri yoksa boş liste kullan - connectionState kontrolünü kaldırdık
                // Çünkü StreamBuilder sürekli rebuild yapıyor ve yazılar kayboluyor
                final deals = snapshot.data ?? [];
                
                // Yükleniyor durumu - Sadece ilk yüklemede skeleton göster
                if (deals.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemCount: 8, // 8 adet skeleton kart göster
                    itemBuilder: (context, index) {
                      return const DealCardSkeleton();
                    },
                  );
                }
                
                // Filtreleme (İstemci tarafında)
                final filteredDeals = _selectedCategory == 'tumu'
                    ? deals
                    : deals.where((d) {
                        final categoryMatch = d.category == Category.getNameById(_selectedCategory);
                        if (_selectedSubCategory != null) {
                          return categoryMatch && d.subCategory == _selectedSubCategory;
                        }
                        return categoryMatch;
                      }).toList();

                if (filteredDeals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz fırsat yok',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // Stream'i yeniden başlatmak için setState yeterli
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: _buildDealList(filteredDeals),
                );
              },
            ),
          ),
            ],
          ),
          // Yukarı Çık Butonu - Sağ alt köşede, FAB'ın üstünde
          Positioned(
            right: 16,
            bottom: 120, // FAB'ın üstünde, daha fazla mesafe ile
            child: AnimatedOpacity(
              opacity: _showScrollToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showScrollToTop,
                child: FloatingActionButton(
                  heroTag: "scroll_to_top_fab",
                  mini: true,
                  onPressed: _scrollToTop,
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "add_deal_fab",
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitDealScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Fırsat Ekle'),
      ),
    );
  }

  Widget _buildDealList(List<Deal> deals) {
    if (_viewMode == 'grid') {
      return GridView.builder(
        controller: _scrollController,
        key: ValueKey('deal_grid_${_selectedCategory}_$_viewMode'),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: deals.length,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return RepaintBoundary(
            key: ValueKey('deal_card_boundary_${deal.id}'),
            child: DealCard(
              key: ValueKey('deal_card_${deal.id}'),
              deal: deal,
              viewMode: 'grid',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DealDetailScreen(dealId: deal.id),
                ),
              ),
            ),
          );
        },
      );
    } else if (_viewMode == 'compact') {
      return ListView.builder(
        controller: _scrollController,
        key: ValueKey('deal_list_compact_${_selectedCategory}_$_viewMode'),
        padding: const EdgeInsets.only(bottom: 80, top: 8),
        itemCount: deals.length,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return RepaintBoundary(
            key: ValueKey('deal_card_boundary_${deal.id}'),
            child: DealCard(
              key: ValueKey('deal_card_${deal.id}'),
              deal: deal,
              viewMode: 'compact',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DealDetailScreen(dealId: deal.id),
                ),
              ),
            ),
          );
        },
      );
    } else if (_viewMode == 'small_list') {
      // Küçük liste görünümü
      return ListView.builder(
        controller: _scrollController,
        key: ValueKey('deal_small_list_${_selectedCategory}_$_viewMode'),
        padding: const EdgeInsets.only(bottom: 80, top: 8),
        itemCount: deals.length,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return RepaintBoundary(
            key: ValueKey('deal_card_boundary_${deal.id}'),
            child: DealCard(
              key: ValueKey('deal_card_${deal.id}'),
              deal: deal,
              viewMode: 'small_list',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DealDetailScreen(dealId: deal.id),
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Liste görünümü (varsayılan)
      return ListView.builder(
        controller: _scrollController,
        key: ValueKey('deal_list_${_selectedCategory}_$_viewMode'),
        padding: const EdgeInsets.only(bottom: 80, top: 8),
        itemCount: deals.length,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return RepaintBoundary(
            key: ValueKey('deal_card_boundary_${deal.id}'),
            child: DealCard(
              key: ValueKey('deal_card_${deal.id}'),
              deal: deal,
              viewMode: 'list',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DealDetailScreen(dealId: deal.id),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  String _getSelectedCategoryText() {
    if (_selectedCategory == 'tumu') return 'Tümü';
    final category = Category.getById(_selectedCategory);
    if (_selectedSubCategory != null) {
      return '${category.icon} ${category.name} > $_selectedSubCategory';
    }
    return '${category.icon} ${category.name}';
  }

  Widget _buildCategoryItem(Category category, String? subCategory, {required bool isSelected, bool showNotification = true}) {
    final isNotificationEnabled = category.id == 'tumu'
        ? _isGeneralNotificationsEnabled
        : subCategory == null
            ? _followedCategories.contains(category.id)
            : _followedSubCategories.contains('${category.id}:$subCategory');

    return InkWell(
      onTap: () {
        setState(() {
          if (subCategory != null) {
            _selectedCategory = category.id;
            _selectedSubCategory = subCategory;
          } else {
            _selectedCategory = category.id;
            _selectedSubCategory = null;
          }
          _isCategoryMenuExpanded = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
        child: Row(
          children: [
            if (subCategory == null) ...[
              Text(
                category.icon,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
            ] else ...[
              const SizedBox(width: 32),
              const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                subCategory ?? category.name,
                style: TextStyle(
                  fontSize: subCategory != null ? 14 : 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : Colors.black87,
                ),
              ),
            ),
            // Bildirim butonu (Tümü kategorisi için gösterilmez)
            if (showNotification)
              IconButton(
                icon: Icon(
                  isNotificationEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                  color: isNotificationEnabled ? AppTheme.primary : Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  if (category.id == 'tumu') {
                    _toggleGeneralNotification();
                  } else if (subCategory == null) {
                    _toggleCategoryNotification(category.id);
                  } else {
                    _toggleSubCategoryNotification(category.id, subCategory);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: isNotificationEnabled ? 'Bildirimleri Kapat' : 'Bildirimleri Aç',
              ),
            if (showNotification) const SizedBox(width: 8),
            if (isSelected)
              Icon(Icons.check, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableCategory(Category category) {
    final isMainCategorySelected = _selectedCategory == category.id && _selectedSubCategory == null;
    final isExpanded = _selectedCategory == category.id;
    final isNotificationEnabled = _followedCategories.contains(category.id);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (category.subcategories.isEmpty) {
                // Alt kategori yoksa direkt seç
                _selectedCategory = category.id;
                _selectedSubCategory = null;
                _isCategoryMenuExpanded = false;
              } else {
                // Alt kategori varsa expand/collapse yap
                if (_selectedCategory == category.id && _selectedSubCategory == null) {
                  _selectedCategory = 'tumu';
                  _selectedSubCategory = null;
                } else {
                  _selectedCategory = category.id;
                  _selectedSubCategory = null;
                }
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isMainCategorySelected
                ? AppTheme.primary.withOpacity(0.1)
                : Colors.transparent,
            child: Row(
              children: [
                Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isMainCategorySelected ? FontWeight.bold : FontWeight.w500,
                      color: isMainCategorySelected ? AppTheme.primary : Colors.black87,
                    ),
                  ),
                ),
                // Bildirim butonu
                IconButton(
                  icon: Icon(
                    isNotificationEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                    color: isNotificationEnabled ? AppTheme.primary : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () => _toggleCategoryNotification(category.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: isNotificationEnabled ? 'Bildirimleri Kapat' : 'Bildirimleri Aç',
                ),
                const SizedBox(width: 8),
                if (category.subcategories.isNotEmpty)
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ),
                if (isMainCategorySelected)
                  const SizedBox(width: 8),
                if (isMainCategorySelected)
                  Icon(Icons.check, color: AppTheme.primary, size: 20),
              ],
            ),
          ),
        ),
        // Alt kategoriler
        if (isExpanded && category.subcategories.isNotEmpty)
          ...category.subcategories.map((sub) {
            final isSubSelected = _selectedCategory == category.id && _selectedSubCategory == sub;
            return _buildCategoryItem(category, sub, isSelected: isSubSelected);
          }).toList(),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildThemeToggleButton() {
    final isDark = _themeService.isDarkMode;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: 48,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Haptic feedback ekle
            HapticFeedback.lightImpact();
            _themeService.toggleTheme();
          },
          child: Stack(
            children: [
              // Arka plan animasyonu
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                left: isDark ? 20 : 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // İkonlar
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: Tween<double>(begin: 0.5, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    key: ValueKey<bool>(isDark),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        isDark
                            ? 'assets/Hacker Cat  - Logo Design.jpg'
                            : 'assets/gündüz.jpg',
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Hata durumunda varsayılan ikon göster
                          return Icon(
                            Icons.light_mode_rounded,
                            size: 18,
                            color: isDark ? Colors.white : Colors.orange,
                          );
                        },
                      ),
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
}
