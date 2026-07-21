import 'package:flutter/material.dart';
import '../../../models/deal.dart';
import '../../../models/category.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/category_selector_widget.dart';

/// Kategori gösterim helper'ı.
String getCategoryDisplayText(String categoryId, String? subCategory) {
  final category = Category.getById(categoryId);
  if (subCategory != null) {
    return '${category.icon} ${category.name} > $subCategory';
  }
  return '${category.icon} ${category.name}';
}

/// Deal için kategori gösterim helper'ı.
String getCategoryDisplayTextForDeal(Deal deal) {
  final categoryValue = deal.category.trim();
  final normalizedValue = categoryValue.toLowerCase();
  
  for (final cat in Category.categories) {
    if (cat.id.toLowerCase() == normalizedValue && cat.id != 'tumu') {
      if (deal.subCategory != null && deal.subCategory!.isNotEmpty) {
        return '${cat.icon} ${cat.name} > ${deal.subCategory}';
      }
      return '${cat.icon} ${cat.name}';
    }
  }
  
  for (final cat in Category.categories) {
    if (cat.name.toLowerCase() == normalizedValue && cat.id != 'tumu') {
      if (deal.subCategory != null && deal.subCategory!.isNotEmpty) {
        return '${cat.icon} ${cat.name} > ${deal.subCategory}';
      }
      return '${cat.icon} ${cat.name}';
    }
  }
  
  return '🔥 Tümü';
}

/// Kategori seçici bottom sheet.
Future<void> showCategorySelector({
  required BuildContext context,
  required Deal deal,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  String initialCategoryId = Category.normalizeCategoryId(deal.category);
  if (initialCategoryId == 'tumu') {
    initialCategoryId = 'elektronik';
  }
  String selectedCategoryId = initialCategoryId;
  String? selectedSubCategory = deal.subCategory;

  final result = await showModalBottomSheet<Map<String, String?>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CategorySelectorWidget(
                    selectedCategoryId: selectedCategoryId,
                    selectedSubCategory: selectedSubCategory,
                    onCategorySelected: (categoryId, subCategory) {
                      setSheetState(() {
                        selectedCategoryId = categoryId;
                        selectedSubCategory = subCategory;
                      });
                      Navigator.pop(context, {
                        'categoryId': categoryId,
                        'subCategory': subCategory,
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  if (result != null && context.mounted) {
    final categoryId = result['categoryId']!;
    final subCategory = result['subCategory'];
    final categoryName = Category.getNameById(categoryId) ?? deal.category;

    final success = await firestoreService.updateDeal(deal.id, {
      'category': categoryName,
      'subCategory': subCategory,
    });

    if (context.mounted) {
      if (success) {
        onDealUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori güncellendi ✅'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori güncellenirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
