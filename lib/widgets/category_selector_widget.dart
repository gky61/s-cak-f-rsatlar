import 'package:flutter/material.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

class CategorySelectorWidget extends StatefulWidget {
  final String? selectedCategoryId;
  final String? selectedSubCategory;
  final Function(String categoryId, String? subCategory) onCategorySelected;

  const CategorySelectorWidget({
    super.key,
    this.selectedCategoryId,
    this.selectedSubCategory,
    required this.onCategorySelected,
  });

  @override
  State<CategorySelectorWidget> createState() => _CategorySelectorWidgetState();
}

class _CategorySelectorWidgetState extends State<CategorySelectorWidget> {
  String? _currentMainCategoryId;
  String? _selectedSubCategory;

  @override
  void initState() {
    super.initState();
    if (widget.selectedCategoryId != null && widget.selectedCategoryId != 'tumu') {
      _currentMainCategoryId = widget.selectedCategoryId;
    } else {
      _currentMainCategoryId = null;
    }
    _selectedSubCategory = widget.selectedSubCategory;
  }

  void _selectMainCategory(String categoryId) {
    setState(() {
      _currentMainCategoryId = categoryId;
      _selectedSubCategory = null; // Ana kategori değişince alt kategoriyi sıfırla
    });
  }

  void _selectSubCategory(String subCategory) {
    setState(() {
      _selectedSubCategory = subCategory;
    });
  }

  void _confirmSelection() {
    if (_currentMainCategoryId != null) {
      widget.onCategorySelected(_currentMainCategoryId!, _selectedSubCategory);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
    final textColor = isDark ? AppTheme.darkTextPrimary : Colors.black87;
    final borderColor = isDark ? AppTheme.darkBorder : Colors.grey[200]!;
    final bottomBarColor = isDark ? AppTheme.darkSurfaceElevated : Colors.grey[50];

    final mainCategories = Category.categories.where((cat) => cat.id != 'tumu').toList();
    final currentCategory = _currentMainCategoryId != null
        ? Category.getById(_currentMainCategoryId!)
        : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Başlık ve Kapatma/Geri Butonu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                if (_currentMainCategoryId != null && currentCategory != null) ...[
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => setState(() {
                      _currentMainCategoryId = null;
                      _selectedSubCategory = null;
                    }),
                    tooltip: 'Geri',
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _currentMainCategoryId == null ? 'Kategori Seç' : currentCategory?.name ?? 'Kategori Seç',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // İçerik
          Expanded(
            child: _currentMainCategoryId == null
                ? _buildMainCategories(mainCategories)
                : _buildSubCategories(currentCategory!),
          ),

          // Onay Butonu (Ana kategori seçildiyse göster)
          if (_currentMainCategoryId != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: borderColor),
                ),
                color: bottomBarColor,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selectedSubCategory != null 
                        ? 'Seçimi Onayla: ${currentCategory?.name ?? ""} > $_selectedSubCategory'
                        : 'Seçimi Onayla: ${currentCategory?.name ?? ""}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainCategories(List<Category> categories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkSurfaceElevated : Colors.grey[50];
    final textColor = isDark ? AppTheme.darkTextPrimary : Colors.black87;
    final subTextColor = isDark ? AppTheme.darkTextSecondary : Colors.grey[600];
    final borderColor = isDark ? AppTheme.darkBorder : Colors.grey[300]!;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = widget.selectedCategoryId == category.id;

        return InkWell(
          onTap: () {
            if (category.subcategories.isEmpty) {
              widget.onCategorySelected(category.id, null);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            } else {
              _selectMainCategory(category.id);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : borderColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  category.icon,
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Theme.of(context).colorScheme.primary : textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category.subcategories.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${category.subcategories.length} alt kategori',
                    style: TextStyle(
                      fontSize: 10,
                      color: subTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubCategories(Category category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkSurfaceElevated : Colors.white;
    final textColor = isDark ? AppTheme.darkTextPrimary : Colors.black87;
    final subTextColor = isDark ? AppTheme.darkTextSecondary : Colors.grey[600];
    final borderColor = isDark ? AppTheme.darkBorder : Colors.grey[300]!;

    return Column(
      children: [
        // Seçilen Ana Kategori Bilgisi
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: Row(
            children: [
              Text(
                category.icon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Alt kategorilerden birini seçin',
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Alt Kategoriler Listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: category.subcategories.length + 1, // +1 for "Tümü" option
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedSubCategory == null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                      : cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? Colors.grey[700] : Colors.grey),
                    ),
                    title: Text(
                      'Tümü (${category.name})',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Theme.of(context).colorScheme.primary : textColor,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedSubCategory = null;
                      });
                      widget.onCategorySelected(category.id, null);
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              }
              
              final subCategory = category.subcategories[index - 1];
              final isSelected = _selectedSubCategory == subCategory;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? Colors.grey[700] : Colors.grey),
                  ),
                  title: Text(
                    subCategory,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Theme.of(context).colorScheme.primary : textColor,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    _selectSubCategory(subCategory);
                    widget.onCategorySelected(category.id, subCategory);
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

