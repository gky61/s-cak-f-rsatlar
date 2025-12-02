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
    _currentMainCategoryId = widget.selectedCategoryId;
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
    // Alt kategori seçildiğinde sadece state'i güncelle, modal'ı kapatma
    // Kullanıcı "Seçimi Onayla" butonuna basana kadar beklesin
  }

  void _confirmSelection() {
    if (_currentMainCategoryId != null) {
      widget.onCategorySelected(_currentMainCategoryId!, _selectedSubCategory);
      Navigator.pop(context); // Seçimi onayladıktan sonra modal'ı kapat
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainCategories = Category.categories.where((cat) => cat.id != 'tumu').toList();
    final currentCategory = _currentMainCategoryId != null
        ? Category.getById(_currentMainCategoryId!)
        : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Başlık ve Kapatma Butonu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Kategori Seç',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_currentMainCategoryId != null && currentCategory != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _currentMainCategoryId = null;
                      _selectedSubCategory = null;
                    }),
                    tooltip: 'Geri',
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
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

          // Onay Butonu (Alt kategori seçildiyse göster)
          if (_currentMainCategoryId != null && _selectedSubCategory != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
                color: Colors.grey[50],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Seçimi Onayla',
                    style: TextStyle(
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
        final isSelected = _currentMainCategoryId == category.id;

        return InkWell(
          onTap: () {
            if (category.subcategories.isEmpty) {
              // Alt kategori yoksa direkt seç
              widget.onCategorySelected(category.id, null);
              Navigator.pop(context);
            } else {
              // Alt kategori varsa alt kategorilere geç
              _selectMainCategory(category.id);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.grey[300]!,
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
                    color: isSelected ? AppTheme.primary : Colors.black87,
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
                      color: Colors.grey[600],
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
    return Column(
      children: [
        // Seçilen Ana Kategori Bilgisi
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.primary.withOpacity(0.1),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Alt kategorilerden birini seçin',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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
            itemCount: category.subcategories.length,
            itemBuilder: (context, index) {
              final subCategory = category.subcategories[index];
              final isSelected = _selectedSubCategory == subCategory;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.1)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primary
                        : Colors.grey[300]!,
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
                    color: isSelected ? AppTheme.primary : Colors.grey,
                  ),
                  title: Text(
                    subCategory,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? AppTheme.primary : Colors.black87,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check,
                          color: AppTheme.primary,
                        )
                      : null,
                  onTap: () => _selectSubCategory(subCategory),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

