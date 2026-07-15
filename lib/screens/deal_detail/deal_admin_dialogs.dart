import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../models/deal.dart';
import '../../models/category.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_selector_widget.dart';
import '../../widgets/description_text_editing_controller.dart';
import 'deal_link_utils.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Admin'e özel tüm düzenleme formlarını, onaylama akışlarını ve diyalogları içerir.
class DealAdminDialogs {
  DealAdminDialogs._();

  /// Admin düzenleme bottom sheet'ini gösterir.
  static void showAdminEditSheet({
    required BuildContext context,
    required Deal deal,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) {
    final titleController = TextEditingController(text: deal.title);
    final descriptionController = DescriptionTextEditingController(text: deal.description);
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
      text: deal.discountRate != null ? deal.discountRate!.toString() : '',
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
              if (price == null || price <= 0) {
                setSheetState(() => errorText = 'Lütfen geçerli bir fiyat girin.');
                return;
              }

              final originalPrice = parseDouble(originalPriceController.text);
              final discountRate = int.tryParse(discountController.text.trim());

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
                'price': price,
                'originalPrice': (originalPrice ?? 0) > 0 ? originalPrice : null,
                'discountRate': (discountRate ?? 0) > 0 ? discountRate : null,
                'isEditorPick': isEditorPick,
                'isApproved': isApproved,
                'isExpired': isExpired,
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

  /// Admin text field widget'ı.
  static Widget _buildAdminTextField(
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

  /// Kategori gösterim helper'ı.
  static String getCategoryDisplayText(String categoryId, String? subCategory) {
    final category = Category.getById(categoryId);
    if (subCategory != null) {
      return '${category.icon} ${category.name} > $subCategory';
    }
    return '${category.icon} ${category.name}';
  }

  /// Deal için kategori gösterim helper'ı.
  static String getCategoryDisplayTextForDeal(Deal deal) {
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

  /// Onaylama akışını başlatan wrapper.
  static Future<void> confirmApproval({
    required BuildContext context,
    required String dealId,
    required Deal? currentDeal,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) async {
    await showApproveOptions(
      context: context,
      dealId: dealId,
      currentDeal: currentDeal,
      firestoreService: firestoreService,
      onDealUpdated: onDealUpdated,
    );
  }

  /// Onaylama seçenekleri dialog'u.
  static Future<void> showApproveOptions({
    required BuildContext context,
    required String dealId,
    required Deal? currentDeal,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) async {
    final option = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
        title: const Text('Onaylama Seçeneği'),
        content: const Text('Bu fırsatı nasıl onaylamak istersiniz?'),
          actions: [
            TextButton(
            onPressed: () => Navigator.pop(context, 'normal'),
            child: const Text('Normal Onayla'),
            ),
            TextButton(
            onPressed: () => Navigator.pop(context, 'editor'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange[700],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 18),
                SizedBox(width: 4),
                Text('Editörün Seçimi'),
              ],
            ),
            ),
          ],
        ),
      );

    if (option == null || !context.mounted) return;

    if (option == 'normal') {
      await _approveDeal(
        context: context,
        dealId: dealId,
        currentDeal: currentDeal,
        firestoreService: firestoreService,
        onDealUpdated: onDealUpdated,
        isEditorPick: false,
      );
    } else if (option == 'editor') {
      await _approveDeal(
        context: context,
        dealId: dealId,
        currentDeal: currentDeal,
        firestoreService: firestoreService,
        onDealUpdated: onDealUpdated,
        isEditorPick: true,
      );
    }
  }

  /// Fırsatı onaylama.
  static Future<void> _approveDeal({
    required BuildContext context,
    required String dealId,
    required Deal? currentDeal,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
    bool isEditorPick = false,
  }) async {
    await firestoreService.updateDeal(dealId, {
      'isApproved': true,
      'isEditorPick': isEditorPick,
    });
    
    if (currentDeal != null) {
      try {
        final notificationService = NotificationService();
        await notificationService.checkKeywordsAndNotify(
          dealId,
          currentDeal.title,
          currentDeal.description,
        );
        _log('✅ Anahtar kelime kontrolü yapıldı: ${currentDeal.title}');

        if (currentDeal.isUserSubmitted && currentDeal.postedBy.isNotEmpty) {
          _log('ℹ️ Takip bildirimi Cloud Function tarafından gönderilecek: ${currentDeal.postedBy}');
        }
      } catch (e) {
        _log('❌ Anahtar kelime kontrolü hatası: $e');
      }
    }
    
    onDealUpdated();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditorPick
                ? 'Fırsat Editörün Seçimi olarak onaylandı ⭐'
                : 'Fırsat Onaylandı ✅',
          ),
          backgroundColor: isEditorPick ? Colors.orange[700] : Colors.green,
        ),
      );
    }
  }

  /// Yayından kaldırma.
  static Future<void> unpublishDeal({
    required BuildContext context,
    required String dealId,
    required FirestoreService firestoreService,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fırsatı Kaldır'),
        content: const Text('Bu fırsatı kaldırmak istediğinize emin misiniz?\n\nFırsat "Süresi Bitenler" bölümüne taşınacak.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Evet, Kaldır'),
            ),
          ],
        ),
      );

    if (confirm != true || !context.mounted) return;

    await firestoreService.updateDeal(dealId, {'isExpired': true});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat kaldırıldı ve süresi bitenler bölümüne taşındı ⚠️'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  /// Kategori seçici bottom sheet.
  static Future<void> showCategorySelector({
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kategori Seç',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
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

  /// Fırsatı reddetme.
  static Future<void> rejectDeal({
    required BuildContext context,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
        title: const Text('Fırsatı Reddet'),
        content: const Text('Bu fırsatı reddetmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Reddet'),
            ),
          ],
        ),
      );

    if (confirm != true || !context.mounted) return;

    await firestoreService.updateDeal(dealId, {'isExpired': true});
    onDealUpdated();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fırsat Reddedildi ❌'), backgroundColor: Colors.red),
      );
    }
  }

  /// Silme onay dialog'u.
  static Future<void> showDeleteDialog({
    required BuildContext context,
    required Deal deal,
    required FirestoreService firestoreService,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fırsatı Sil'),
        content: Text('Bu fırsatı kalıcı olarak silmek istediğinize emin misiniz?\n\n"${deal.title}"\n\nBu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final success = await firestoreService.deleteDeal(deal.id);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fırsat silindi 🗑️'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silme işlemi başarısız ❌'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Admin detay düzenleme dialog'u.
  static Future<void> showAdminEditDialog({
    required BuildContext context,
    required Deal deal,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) async {
    final titleController = TextEditingController(text: deal.title);
    final descriptionController = DescriptionTextEditingController(text: deal.description);
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
    final linkController = TextEditingController(text: deal.link);

    String? selectedCategoryId;
    String? selectedSubCategory = deal.subCategory;
    
    final normalizedDealCategory = deal.category.toLowerCase().trim();

    for (final cat in Category.categories) {
      if (cat.id.toLowerCase() == normalizedDealCategory) {
        selectedCategoryId = cat.id;
        break;
      }
    }

    if (selectedCategoryId == null) {
      for (final cat in Category.categories) {
        if (cat.name.toLowerCase() == normalizedDealCategory) {
          selectedCategoryId = cat.id;
          break;
        }
      }
    }

    if (selectedCategoryId == null) {
      if (normalizedDealCategory.contains('giyim') || normalizedDealCategory.contains('moda')) {
        selectedCategoryId = 'moda';
      } else if (normalizedDealCategory.contains('ev') || normalizedDealCategory.contains('yasam')) {
        selectedCategoryId = 'ev_yasam';
      } else if (normalizedDealCategory.contains('bebek') || normalizedDealCategory.contains('anne')) {
        selectedCategoryId = 'anne_bebek';
      } else if (normalizedDealCategory.contains('kozmetik') || normalizedDealCategory.contains('bakim')) {
        selectedCategoryId = 'kozmetik';
      } else if (normalizedDealCategory.contains('spor')) {
        selectedCategoryId = 'spor_outdoor';
      } else if (normalizedDealCategory.contains('market') && !normalizedDealCategory.contains('yapi')) {
        selectedCategoryId = 'supermarket';
      } else if (normalizedDealCategory.contains('yapi') || normalizedDealCategory.contains('oto')) {
        selectedCategoryId = 'yapi_oto';
      } else if (normalizedDealCategory.contains('kitap') || normalizedDealCategory.contains('hobi')) {
        selectedCategoryId = 'kitap_hobi';
      } else if (normalizedDealCategory.contains('elektronik') || normalizedDealCategory.contains('telefon') || normalizedDealCategory.contains('bilgisayar')) {
        selectedCategoryId = 'elektronik';
      }
    }

    if (selectedCategoryId == null) {
       final hasDiger = Category.categories.any((c) => c.id == 'diger');
       selectedCategoryId = hasDiger ? 'diger' : 'elektronik';
    }
    
    if (selectedSubCategory != null && selectedCategoryId != null) {
      final category = Category.categories.firstWhere(
        (cat) => cat.id == selectedCategoryId,
        orElse: () => Category.categories.first,
      );
      if (!category.subcategories.contains(selectedSubCategory)) {
        selectedSubCategory = null;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: Text(
            'Ürün Bilgilerini Düzenle',
            style: TextStyle(color: textColor),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Başlık',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Fiyat (₺)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: originalPriceController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Eski Fiyat (₺)',
                            border: const OutlineInputBorder(),
                            hintText: 'Opsiyonel',
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Link alanı ve Affiliate Link'e Dönüştür butonu
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.link, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Ürün Linki',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: linkController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Ürün URL',
                            border: const OutlineInputBorder(),
                            hintText: 'https://...',
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                            prefixIcon: Icon(Icons.link, color: textColor.withValues(alpha: 0.6)),
                            suffixIcon: linkController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        linkController.clear();
                                      });
                                    },
                                    tooltip: 'Linki Temizle',
                                  )
                                : null,
                          ),
                          keyboardType: TextInputType.url,
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final currentUrl = linkController.text.trim();
                              if (currentUrl.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Lütfen önce bir URL girin'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
      return;
    }

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              try {
                                String urlToConvert = currentUrl;

                                if (urlToConvert.contains('hb.biz') ||
                                    urlToConvert.contains('app.hb.biz')) {
                                  try {
                                    final resolvedUrl = await DealLinkUtils.resolveShortLink(urlToConvert);
                                    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                                      urlToConvert = resolvedUrl;
                                      _log('✅ Kısa link çözüldü: $urlToConvert');
                                    }
                                  } catch (e) {
                                    _log('⚠️ Kısa link çözülemedi: $e');
                                  }
                                }

                                final convertedUrl = DealLinkUtils.convertToAffiliateLink(urlToConvert);

                                if (context.mounted) {
                                  Navigator.pop(context);

                                  if (convertedUrl != urlToConvert) {
                                    setState(() {
                                      linkController.text = convertedUrl;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Affiliate link\'e dönüştürüldü!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    final store = DealLinkUtils.detectStoreFromUrl(urlToConvert);
                                    if (store == 'Bilinmeyen') {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('⚠️ Bu mağaza desteklenmiyor'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'ℹ️ Link zaten affiliate link veya $store için affiliate ID yapılandırılmamış'),
                                          backgroundColor: Colors.blue,
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ Hata: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.swap_horiz, size: 20),
                            label: const Text(
                              'Affiliate Link\'e Dönüştür',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: Category.categories
                        .where((cat) => cat.id != 'tumu')
                        .map((category) => DropdownMenuItem(
                              value: category.id,
                              child: Text('${category.icon} ${category.name}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategoryId = value;
                        selectedSubCategory = null;
                      });
                    },
                  ),
                  if (selectedCategoryId != null) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: selectedSubCategory,
                      decoration: const InputDecoration(
                        labelText: 'Alt Kategori',
                        border: OutlineInputBorder(),
                        hintText: 'Opsiyonel',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Alt kategori seçiniz (opsiyonel)'),
                        ),
                        ...Category.categories
                            .firstWhere((cat) => cat.id == selectedCategoryId)
                            .subcategories
                            .map((sub) => DropdownMenuItem(
                                  value: sub,
                                  child: Text(sub),
                                )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedSubCategory = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Başlık boş olamaz')),
                  );
                  return;
                }

                final price = double.tryParse(priceController.text.replaceAll(',', '.'));
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir fiyat giriniz')),
                  );
                  return;
                }

                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kategori seçiniz')),
                  );
                  return;
                }

                final updates = <String, dynamic>{
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': price,
                  'category': Category.getById(selectedCategoryId!).name,
                  'link': linkController.text.trim(),
                };

                final originalPrice = originalPriceController.text.trim();
                if (originalPrice.isNotEmpty) {
                  final origPrice = double.tryParse(originalPrice.replaceAll(',', '.'));
                  if (origPrice != null && origPrice > price) {
                    updates['originalPrice'] = origPrice;
                    final discountRate = ((origPrice - price) / origPrice * 100).round();
                    updates['discountRate'] = discountRate;
                  } else {
                    updates['originalPrice'] = null;
                    updates['discountRate'] = null;
                  }
                } else {
                  updates['originalPrice'] = null;
                  updates['discountRate'] = null;
                }

                if (selectedSubCategory != null && selectedSubCategory!.isNotEmpty) {
                  updates['subCategory'] = selectedSubCategory;
                } else {
                  updates['subCategory'] = null;
                }

                final success = await firestoreService.updateDeal(dealId, updates);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    onDealUpdated();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ürün bilgileri güncellendi ✅'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  /// Fiyat düzenleme dialog'u.
  static Future<void> showPriceEditDialog({
    required BuildContext context,
    required Deal deal,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) async {
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text(
          'Fiyat Düzenle',
          style: TextStyle(color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Güncel Fiyat (₺)',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: originalPriceController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Eski Fiyat (₺)',
                border: const OutlineInputBorder(),
                hintText: 'Opsiyonel',
                filled: true,
                fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text.replaceAll(',', '.'));
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Geçerli bir fiyat giriniz')),
                );
                return;
              }

              final updates = <String, dynamic>{'price': price};

              final originalPrice = originalPriceController.text.trim();
              if (originalPrice.isNotEmpty) {
                final origPrice = double.tryParse(originalPrice.replaceAll(',', '.'));
                if (origPrice != null && origPrice > price) {
                  updates['originalPrice'] = origPrice;
                  final discountRate = ((origPrice - price) / origPrice * 100).round();
                  updates['discountRate'] = discountRate;
                } else {
                  updates['originalPrice'] = null;
                  updates['discountRate'] = null;
                }
              } else {
                updates['originalPrice'] = null;
                updates['discountRate'] = null;
              }

              final success = await firestoreService.updateDeal(dealId, updates);
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  onDealUpdated();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fiyat güncellendi ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  /// Açıklama düzenleme dialog'u.
  static Future<void> showEditDescriptionDialog({
    required BuildContext context,
    required Deal deal,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) async {
    final descriptionController = DescriptionTextEditingController(text: deal.description);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text(
          'Açıklama Düzenle',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: descriptionController,
          autofocus: true,
          maxLines: 6,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Ürün açıklamasını girin',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800]!.withValues(alpha: 0.3) : Colors.grey[50],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newDescription = descriptionController.text.trim();
              
              final success = await firestoreService.updateDeal(
                dealId,
                {'description': newDescription},
              );
              
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  onDealUpdated();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Açıklama güncellendi ✅'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Kategori düzenleme dialog'u.
  static Future<void> showCategoryEditDialog({
    required BuildContext context,
    required Deal deal,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) async {
    String resolvedId = Category.normalizeCategoryId(deal.category);
    String? selectedCategoryId = resolvedId != 'tumu' ? resolvedId : null;
    String? selectedSubCategory = deal.subCategory;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Kategori Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: Category.categories
                    .where((cat) => cat.id != 'tumu')
                    .map((category) => DropdownMenuItem(
                          value: category.id,
                          child: Text('${category.icon} ${category.name}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategoryId = value;
                    selectedSubCategory = null;
                  });
                },
              ),
              if (selectedCategoryId != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: selectedSubCategory,
                  decoration: const InputDecoration(
                    labelText: 'Alt Kategori',
                    border: OutlineInputBorder(),
                    hintText: 'Opsiyonel',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Alt kategori seçiniz (opsiyonel)'),
                    ),
                    ...Category.categories
                        .firstWhere((cat) => cat.id == selectedCategoryId)
                        .subcategories
                        .map((sub) => DropdownMenuItem(
                              value: sub,
                              child: Text(sub),
                            )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedSubCategory = value;
                    });
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kategori seçiniz')),
                  );
                  return;
                }

                final updates = <String, dynamic>{
                  'category': Category.getById(selectedCategoryId!).name,
                };

                if (selectedSubCategory != null && selectedSubCategory!.isNotEmpty) {
                  updates['subCategory'] = selectedSubCategory;
                } else {
                  updates['subCategory'] = null;
                }

                final success = await firestoreService.updateDeal(dealId, updates);
                if (context.mounted) {
                  Navigator.pop(context);
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
                        content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
