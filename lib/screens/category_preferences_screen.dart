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

  // 'tumu' hariç kategoriler
  List<Category> get _filteredCategories => 
      Category.categories.where((c) => c.id != 'tumu').toList();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final followedCategories = await _notificationService.getFollowedCategories();
      final followedSubCategories = await _notificationService.getFollowedSubCategories();

      setState(() {
        // Ana kategorileri yükle
        for (final category in _filteredCategories) {
          _categoryStates[category.id] = followedCategories.contains(category.id);
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

  Future<void> _toggleCategory(String categoryId, bool value) async {
    setState(() => _categoryStates[categoryId] = value);

    try {
      if (value) {
        await _notificationService.subscribeToCategory(categoryId);
      } else {
        await _notificationService.unsubscribeFromCategory(categoryId);
        // Ana kategori kapatılınca alt kategorileri de kapat
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
        return Icons.devices;
      case 'moda':
        return Icons.checkroom;
      case 'ev_yasam':
        return Icons.home;
      case 'market':
        return Icons.shopping_cart;
      case 'seyahat':
        return Icons.flight;
      case 'eglence':
        return Icons.movie;
      case 'spor':
        return Icons.fitness_center;
      case 'saglik':
        return Icons.favorite;
      case 'egitim':
        return Icons.school;
      case 'otomotiv':
        return Icons.directions_car;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'elektronik':
        return Colors.blue;
      case 'moda':
        return Colors.pink;
      case 'ev_yasam':
        return Colors.orange;
      case 'market':
        return Colors.green;
      case 'seyahat':
        return Colors.purple;
      case 'eglence':
        return Colors.red;
      case 'spor':
        return Colors.teal;
      case 'saglik':
        return Colors.redAccent;
      case 'egitim':
        return Colors.indigo;
      case 'otomotiv':
        return Colors.blueGrey;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final secondaryTextColor = isDark ? Colors.grey[400] : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Favori Kategoriler',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Bilgi kartı
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Seçtiğiniz kategorilerde yeni fırsat paylaşıldığında bildirim alırsınız.',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Kategoriler
                ..._filteredCategories.map((category) {
                  final isExpanded = _categoryStates[category.id] == true;
                  final categoryColor = _getCategoryColor(category.id);
                  final selectedSubCount = _subCategoryStates[category.id]?.length ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Ana kategori
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
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
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: selectedSubCount > 0
                              ? Text(
                                  '$selectedSubCount alt kategori seçili',
                                  style: TextStyle(
                                    color: categoryColor,
                                    fontSize: 12,
                                  ),
                                )
                              : Text(
                                  '${category.subcategories.length} alt kategori',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                          trailing: Switch.adaptive(
                            value: isExpanded,
                            onChanged: (value) => _toggleCategory(category.id, value),
                            activeColor: categoryColor,
                          ),
                        ),

                        // Alt kategoriler
                        if (isExpanded && category.subcategories.isNotEmpty) ...[
                          Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.grey[200],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
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
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (value) => _toggleSubCategory(category.id, subCat, value),
                                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                  selectedColor: categoryColor,
                                  checkmarkColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

