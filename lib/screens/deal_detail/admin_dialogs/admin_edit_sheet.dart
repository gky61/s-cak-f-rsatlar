import 'package:flutter/material.dart';
import '../../../models/deal.dart';
import '../../../models/category.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/category_selector_widget.dart';
import 'category_selector.dart';

void showAdminEditSheet({
  required BuildContext context,
  required Deal deal,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) {
  final titleController = TextEditingController(text: deal.title);
  final descriptionController = TextEditingController(text: deal.description);
  final storeController = TextEditingController(text: deal.store);
  final linkController = TextEditingController(text: deal.link);
  final priceController = TextEditingController(
    text: deal.price == deal.price.toInt()
        ? deal.price.toInt().toString()
        : deal.price.toStringAsFixed(2),
  );
  final originalPriceController = TextEditingController(
    text: deal.originalPrice != null
        ? (deal.originalPrice == deal.originalPrice!.toInt()
            ? deal.originalPrice!.toInt().toString()
            : deal.originalPrice!.toStringAsFixed(2))
        : '',
  );
  final discountController = TextEditingController(
    text: deal.effectiveDiscountRate != null ? deal.effectiveDiscountRate!.toString() : '',
  );

  String initialCategoryId = Category.normalizeCategoryId(deal.category);
  if (initialCategoryId == 'tumu') {
    initialCategoryId = 'elektronik';
  }

  String selectedCategoryId = initialCategoryId;
  String? selectedSubCategory = deal.subCategory;
  bool isEditorPick = deal.isEditorPick;
  bool isApproved = deal.isApproved ?? false;
  bool isExpired = deal.isExpired;
  bool isHidePrice = deal.hidePrice;
  bool isSaving = false;
  String? errorText;

  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> handleSave() async {
            double? parseDouble(String input) {
              final cleaned = input.replaceAll(RegExp('[^0-9,\\.]'), '').replaceAll(',', '.');
              if (cleaned.isEmpty) return null;
              return double.tryParse(cleaned);
            }

            final price = parseDouble(priceController.text);
            if (!isHidePrice && (price == null || price <= 0)) {
              setSheetState(() => errorText = 'Lütfen geçerli bir fiyat girin.');
              return;
            }

            final originalPrice = parseDouble(originalPriceController.text);
            var discountRate = int.tryParse(discountController.text.trim());
            if (discountRate == null && originalPrice != null && originalPrice > price && price > 0) {
              discountRate = (((originalPrice - price) / originalPrice) * 100).round();
            }

            setSheetState(() {
              isSaving = true;
              errorText = null;
            });

            final updates = {
              'title': titleController.text.trim(),
              'description': descriptionController.text.trim(),
              'store': storeController.text.trim(),
              'category': selectedCategoryId,
              'subCategory': selectedSubCategory,
              'link': linkController.text.trim(),
              'price': price ?? 0.0,
              'originalPrice': (originalPrice ?? 0) > 0 ? originalPrice : null,
              'discountRate': (discountRate ?? 0) > 0 ? discountRate : null,
              'isEditorPick': isEditorPick,
              'isApproved': isApproved,
              'isExpired': isExpired,
              'hidePrice': isHidePrice,
            };

            final success = await firestoreService.updateDeal(deal.id, updates);

            if (success) {
              onDealUpdated();
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fırsat bilgileri güncellendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              setSheetState(() {
                isSaving = false;
                errorText = 'Güncelleme sırasında hata oluştu. Tekrar deneyin.';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 24,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fırsatı Düzenle',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildAdminTextField(context, 'Başlık', titleController),
                      _buildAdminTextField(context, 'Açıklama', descriptionController, maxLines: 3),
                      _buildAdminTextField(context, 'Mağaza', storeController),
                      // Kategori Seçimi
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kategori',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (selectorContext) {
                                    return CategorySelectorWidget(
                                      selectedCategoryId: selectedCategoryId,
                                      selectedSubCategory: selectedSubCategory,
                                      onCategorySelected: (categoryId, subCategory) {
                                        setSheetState(() {
                                          selectedCategoryId = categoryId;
                                          selectedSubCategory = subCategory;
                                        });
                                      },
                                    );
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.category,
                                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        getCategoryDisplayText(selectedCategoryId, selectedSubCategory),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildAdminTextField(context, 'Bağlantı', linkController),
                      Row(
                        children: [
                          Expanded(child: _buildAdminTextField(context, 'Fiyat', priceController, keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildAdminTextField(context, 'Eski Fiyat', originalPriceController, keyboardType: TextInputType.number)),
                        ],
                      ),
                      _buildAdminTextField(context, 'İndirim Oranı (%)', discountController, keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isHidePrice,
                        title: const Text('Fiyatı Gizle (Kampanya / Fiyatsız Fırsat)'),
                        subtitle: const Text('Aktif edilirse kartlarda ve detay sayfasında fiyat gösterilmez'),
                        activeColor: Colors.orange[700],
                        onChanged: (val) => setSheetState(() => isHidePrice = val),
                      ),
                      SwitchListTile(
                        value: isEditorPick,
                        title: const Text('Editörün Seçimi'),
                        onChanged: (val) => setSheetState(() => isEditorPick = val),
                      ),
                      SwitchListTile(
                        value: isApproved,
                        title: const Text('Onaylı Fırsat'),
                        onChanged: (val) => setSheetState(() => isApproved = val),
                      ),
                      SwitchListTile(
                        value: isExpired,
                        title: const Text('Fırsat Bitti'),
                        onChanged: (val) => setSheetState(() => isExpired = val),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: isSaving ? null : handleSave,
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildAdminTextField(
  BuildContext context,
  String label,
  TextEditingController controller, {
  int maxLines = 1,
  TextInputType keyboardType = TextInputType.text,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primaryColor = Theme.of(context).colorScheme.primary;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
      ],
    ),
  );
}
