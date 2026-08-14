import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/category.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class CategoryPreferencesScreen extends StatefulWidget {
  const CategoryPreferencesScreen({super.key});

  @override
  State<CategoryPreferencesScreen> createState() => _CategoryPreferencesScreenState();
}

class _CategoryPreferencesScreenState extends State<CategoryPreferencesScreen> {
  final NotificationService _notificationService = NotificationService();
  final Map<String, bool> _categoryStates = {};
  final Map<String, Set<String>> _subCategoryStates = {};
  bool _isLoading = true;
  bool _isProcessingBulk = false;

  // 'tumu' hariç kategoriler
  List<Category> get _filteredCategories => 
      Category.categories.where((c) => c.id != 'tumu').toList();

  int get _activeCategoryCount =>
      _categoryStates.values.where((v) => v == true).length;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final followedCategories = await _notificationService.getFollowedCategories();
      final followedSubCategories = await _notificationService.getFollowedSubCategories();
      final hasDoc = await _notificationService.hasCategorySubscriptionsDoc();

      setState(() {
        // Eğer veritabanında daha önce hiç kayıt oluşturulmamışsa varsayılan olarak HEPSİ AÇIK gelsin
        final shouldDefaultAll = !hasDoc && followedCategories.isEmpty;

        for (final category in _filteredCategories) {
          _categoryStates[category.id] = shouldDefaultAll || followedCategories.contains(category.id);
          _subCategoryStates[category.id] = {};
        }

        // Alt kategorileri yükle
        for (final subCatKey in followedSubCategories) {
          final parts = subCatKey.split(':');
          if (parts.length == 2) {
            final categoryId = parts[0];
            final subCategoryId = parts[1];
            _subCategoryStates[categoryId]?.add(subCategoryId);
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      _log('Kategori tercihleri yüklenirken hata: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectAllCategories() async {
    if (_isProcessingBulk) return;
    setState(() {
      _isProcessingBulk = true;
      for (final cat in _filteredCategories) {
        _categoryStates[cat.id] = true;
      }
    });

    try {
      for (final cat in _filteredCategories) {
        await _notificationService.subscribeToCategory(cat.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Tüm kategoriler takip listenize eklendi', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _log('Tümünü seçme hatası: $e');
    } finally {
      if (mounted) setState(() => _isProcessingBulk = false);
    }
  }

  Future<void> _clearAllCategories() async {
    if (_isProcessingBulk) return;
    setState(() {
      _isProcessingBulk = true;
      for (final cat in _filteredCategories) {
        _categoryStates[cat.id] = false;
        _subCategoryStates[cat.id]?.clear();
      }
    });

    try {
      for (final cat in _filteredCategories) {
        await _notificationService.unsubscribeFromCategory(cat.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Tüm kategori takipleri temizlendi', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _log('Seçimleri temizleme hatası: $e');
    } finally {
      if (mounted) setState(() => _isProcessingBulk = false);
    }
  }

  Future<void> _toggleCategory(String categoryId, bool value) async {
    setState(() => _categoryStates[categoryId] = value);

    try {
      if (value) {
        await _notificationService.subscribeToCategory(categoryId);
      } else {
        await _notificationService.unsubscribeFromCategory(categoryId);
        final category = _filteredCategories.firstWhere((c) => c.id == categoryId);
        for (final subCat in category.subcategories) {
          if (_subCategoryStates[categoryId]?.contains(subCat) == true) {
            await _notificationService.unsubscribeFromSubCategory(categoryId, subCat);
            _subCategoryStates[categoryId]?.remove(subCat);
          }
        }
        setState(() {});
      }
    } catch (e) {
      _log('Kategori değiştirme hatası: $e');
      setState(() => _categoryStates[categoryId] = !value);
    }
  }

  Future<void> _toggleSubCategory(String categoryId, String subCategoryId, bool value) async {
    setState(() {
      if (value) {
        _subCategoryStates[categoryId]?.add(subCategoryId);
      } else {
        _subCategoryStates[categoryId]?.remove(subCategoryId);
      }
    });

    try {
      if (value) {
        await _notificationService.subscribeToSubCategory(categoryId, subCategoryId);
      } else {
        await _notificationService.unsubscribeFromSubCategory(categoryId, subCategoryId);
      }
    } catch (e) {
      _log('Alt kategori değiştirme hatası: $e');
      setState(() {
        if (value) {
          _subCategoryStates[categoryId]?.remove(subCategoryId);
        } else {
          _subCategoryStates[categoryId]?.add(subCategoryId);
        }
      });
    }
  }

  IconData _getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'elektronik':
        return Icons.devices_rounded;
      case 'moda':
        return Icons.checkroom_rounded;
      case 'ev_yasam':
        return Icons.home_rounded;
      case 'anne_bebek':
        return Icons.child_care_rounded;
      case 'kozmetik':
        return Icons.face_rounded;
      case 'spor_outdoor':
        return Icons.directions_run_rounded;
      case 'supermarket':
        return Icons.shopping_cart_rounded;
      case 'yapi_oto':
        return Icons.construction_rounded;
      case 'kitap_hobi':
        return Icons.menu_book_rounded;
      case 'dijital_hizmetler':
        return Icons.language_rounded;
      case 'finans_kampanyalar':
        return Icons.credit_card_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'elektronik':
        return const Color(0xFF2196F3);
      case 'moda':
        return const Color(0xFFE91E63);
      case 'ev_yasam':
        return const Color(0xFFFF9800);
      case 'anne_bebek':
        return const Color(0xFF9C27B0);
      case 'kozmetik':
        return const Color(0xFFFF4081);
      case 'spor_outdoor':
        return const Color(0xFF009688);
      case 'supermarket':
        return const Color(0xFF4CAF50);
      case 'yapi_oto':
        return const Color(0xFF607D8B);
      case 'kitap_hobi':
        return const Color(0xFF3F51B5);
      case 'dijital_hizmetler':
        return const Color(0xFF00BCD4);
      case 'finans_kampanyalar':
        return const Color(0xFFFFC107);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8F9FA);
    final cardColor = isDark ? AppTheme.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final secondaryTextColor = isDark ? Colors.grey[400] : AppTheme.textSecondary;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Takip Edilen Kategorilerim',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Üst Modern Bilgi Banner'ı & Sayaç
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.interests_rounded,
                              color: primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Kategorileri Kişiselleştir',
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '$_activeCategoryCount / ${_filteredCategories.length} Seçili',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Kategorileri takip ederek size uygun fırsatları kolayca keşfedebilirsiniz. Bildirimleriniz açık ise bu kategorilerden anlık bildirim alırsınız.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Minimalist & Akıllı Aksiyon Barı (Tümünü Seç / Temizle)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'KATEGORİ LİSTESİ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: secondaryTextColor,
                        ),
                      ),
                      Row(
                        children: [
                          // Tümünü Seç Butonu (Varsayılan Şeffaf -> Tıklanınca/Seçilince Yeşil)
                          InkWell(
                            onTap: _isProcessingBulk ? null : _selectAllCategories,
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                              decoration: BoxDecoration(
                                color: (_activeCategoryCount == _filteredCategories.length && _filteredCategories.isNotEmpty)
                                    ? (isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (_activeCategoryCount == _filteredCategories.length && _filteredCategories.isNotEmpty)
                                      ? const Color(0xFF4CAF50)
                                      : (isDark ? Colors.white24 : Colors.grey[300]!),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isProcessingBulk && _activeCategoryCount != 0) ...[
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)),
                                    ),
                                    const SizedBox(width: 6),
                                  ] else ...[
                                    Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: (_activeCategoryCount == _filteredCategories.length && _filteredCategories.isNotEmpty)
                                          ? const Color(0xFF2E7D32)
                                          : secondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'Tümünü Seç',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: (_activeCategoryCount == _filteredCategories.length && _filteredCategories.isNotEmpty)
                                          ? const Color(0xFF2E7D32)
                                          : secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Seçimleri Temizle Butonu (Varsayılan Şeffaf -> Tıklanınca/Temizlenince Kırmızı)
                          InkWell(
                            onTap: _isProcessingBulk ? null : _clearAllCategories,
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                              decoration: BoxDecoration(
                                color: _activeCategoryCount == 0
                                    ? (isDark ? const Color(0xFF381B1B) : const Color(0xFFFFEBEE))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _activeCategoryCount == 0
                                      ? const Color(0xFFEF5350)
                                      : (isDark ? Colors.white24 : Colors.grey[300]!),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isProcessingBulk && _activeCategoryCount == 0) ...[
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC62828)),
                                    ),
                                    const SizedBox(width: 6),
                                  ] else ...[
                                    Icon(
                                      Icons.deselect_rounded,
                                      size: 14,
                                      color: _activeCategoryCount == 0
                                          ? const Color(0xFFC62828)
                                          : secondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'Temizle',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: _activeCategoryCount == 0
                                          ? const Color(0xFFC62828)
                                          : secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Modern Kategori Listesi
                ..._filteredCategories.map((category) {
                  final isExpanded = _categoryStates[category.id] == true;
                  final categoryColor = _getCategoryColor(category.id);
                  final selectedSubCount = _subCategoryStates[category.id]?.length ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isExpanded
                            ? categoryColor.withValues(alpha: isDark ? 0.45 : 0.35)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1)),
                        width: isExpanded ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isExpanded
                              ? categoryColor.withValues(alpha: isDark ? 0.15 : 0.06)
                              : Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Ana Kategori Satırı
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _getCategoryIcon(category.id),
                              color: categoryColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: selectedSubCount > 0
                                ? Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: categoryColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$selectedSubCount alt kategori seçili',
                                          style: TextStyle(
                                            color: categoryColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    '${category.subcategories.length} alt kategori',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                          trailing: Switch.adaptive(
                            value: isExpanded,
                            onChanged: (value) => _toggleCategory(category.id, value),
                            activeColor: categoryColor,
                          ),
                        ),

                        // Alt Kategoriler (Çipler)
                        if (isExpanded && category.subcategories.isNotEmpty) ...[
                          Divider(
                            height: 1,
                            thickness: 0.8,
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: category.subcategories.map((subCat) {
                                final isSelected = _subCategoryStates[category.id]?.contains(subCat) == true;
                                return FilterChip(
                                  label: Text(
                                    subCat,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : textColor,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (value) => _toggleSubCategory(category.id, subCat, value),
                                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                                  selectedColor: categoryColor,
                                  checkmarkColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.transparent
                                        : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1)),
                                    width: 0.8,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
