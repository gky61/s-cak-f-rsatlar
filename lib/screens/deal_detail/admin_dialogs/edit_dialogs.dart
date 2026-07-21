import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../../models/deal.dart';
import '../../../models/category.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_theme.dart';
import '../deal_link_utils.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Admin detay düzenleme dialog'u.
Future<void> showAdminEditDialog({
  required BuildContext context,
  required Deal deal,
  required String dealId,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  final titleController = TextEditingController(text: deal.title);
  final descriptionController = TextEditingController(text: deal.description);
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
Future<void> showPriceEditDialog({
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
Future<void> showEditDescriptionDialog({
  required BuildContext context,
  required Deal deal,
  required String dealId,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  final descriptionController = TextEditingController(text: deal.description);
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
Future<void> showCategoryEditDialog({
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
