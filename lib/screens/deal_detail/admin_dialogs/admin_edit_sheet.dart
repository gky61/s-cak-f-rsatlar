import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/deal.dart';
import '../../../models/category.dart';
import '../../../services/firestore_service.dart';
import '../../../services/link_preview_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/category_selector_widget.dart';
import 'category_selector.dart';

/// Topluluk ve Admin ortamlarında Fırsat Düzenleme Modal Sheet'ini açan merkezi fonksiyon.
void showAdminEditSheet({
  required BuildContext context,
  required Deal deal,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) {
  final titleController = TextEditingController(text: deal.title);
  final descriptionController = TextEditingController(text: deal.description);
  final storeController = TextEditingController(text: deal.store);
  final brandController = TextEditingController(text: deal.brand ?? '');
  final linkController = TextEditingController(text: deal.link);
  final imageUrlController = TextEditingController(text: deal.imageUrl);
  
  final priceController = TextEditingController(
    text: deal.price == deal.price.toInt()
        ? deal.price.toInt().toString()
        : deal.price.toStringAsFixed(2),
  );
  final origP = deal.originalPrice;
  final originalPriceController = TextEditingController(
    text: origP != null
        ? (origP == origP.toInt()
            ? origP.toInt().toString()
            : origP.toStringAsFixed(2))
        : '',
  );
  final effDisc = deal.effectiveDiscountRate;
  final discountController = TextEditingController(
    text: effDisc != null ? effDisc.toString() : '',
  );

  final rValue = deal.ratingValue;
  final ratingValueController = TextEditingController(
    text: rValue != null ? rValue.toString() : '',
  );
  final rCount = deal.ratingCount;
  final ratingCountController = TextEditingController(
    text: rCount != null ? rCount.toString() : '',
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
  bool isAmazonWarehouse = deal.isAmazonWarehouse;
  bool isSaving = false;
  bool isConvertingLink = false;
  String? errorText;

  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          double? parseDouble(String input) {
            final cleaned = input.replaceAll(RegExp('[^0-9,\\.]'), '').replaceAll(',', '.');
            if (cleaned.isEmpty) return null;
            return double.tryParse(cleaned);
          }

          int? parseInt(String input) {
            final cleaned = input.replaceAll(RegExp('[^0-9]'), '');
            if (cleaned.isEmpty) return null;
            return int.tryParse(cleaned);
          }

          String convertToAffiliateLink(String originalUrl) {
            if (originalUrl.isEmpty) return originalUrl;
            try {
              final uri = Uri.parse(originalUrl);
              final hostname = uri.host.toLowerCase();

              // Hepsiburada LinkGelir
              if (hostname.contains('hepsiburada.com')) {
                final newQueryParams = Map<String, String>.from(uri.queryParameters);
                newQueryParams['utm_source'] = 'linkgelir';
                newQueryParams['utm_medium'] = 'referral';
                newQueryParams['utm_campaign'] = 'urun_paylasim';
                return uri.replace(queryParameters: newQueryParams).toString();
              }
            } catch (_) {}
            return originalUrl;
          }

          Future<void> handleConvertAffiliate() async {
            final currentUrl = linkController.text.trim();
            if (currentUrl.isEmpty) {
              setSheetState(() => errorText = 'Dönüştürmek için önce bir URL girin.');
              return;
            }

            setSheetState(() {
              isConvertingLink = true;
              errorText = null;
            });

            try {
              String urlToConvert = currentUrl;
              if (urlToConvert.contains('hb.biz') || urlToConvert.contains('app.hb.biz')) {
                try {
                  final linkPreviewService = LinkPreviewService();
                  final resolved = await linkPreviewService.resolveUrlRedirects(urlToConvert);
                  if (resolved.isNotEmpty) urlToConvert = resolved;
                } catch (_) {}
              }

              final converted = convertToAffiliateLink(urlToConvert);
              setSheetState(() {
                linkController.text = converted;
                isConvertingLink = false;
              });

              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Affiliate link güncellendi!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              setSheetState(() {
                isConvertingLink = false;
                errorText = 'Link dönüştürme hatası: $e';
              });
            }
          }

          Future<void> handleSave() async {
            if (titleController.text.trim().isEmpty) {
              setSheetState(() => errorText = 'Lütfen fırsat başlığı girin.');
              return;
            }

            final price = parseDouble(priceController.text);
            if (!isHidePrice && (price == null || price <= 0)) {
              setSheetState(() => errorText = 'Lütfen geçerli bir fiyat girin veya Fiyatı Gizle seçeneğini açın.');
              return;
            }

            final originalPrice = parseDouble(originalPriceController.text);
            var discountRate = parseInt(discountController.text);
            if (discountRate == null && originalPrice != null && price != null && originalPrice > price && price > 0) {
              discountRate = (((originalPrice - price) / originalPrice) * 100).round();
            }

            setSheetState(() {
              isSaving = true;
              errorText = null;
            });

            final updates = <String, dynamic>{
              'title': titleController.text.trim(),
              'description': descriptionController.text.trim(),
              'store': storeController.text.trim(),
              'brand': brandController.text.trim().isNotEmpty ? brandController.text.trim() : null,
              'category': Category.getNameById(selectedCategoryId),
              'subCategory': selectedSubCategory,
              'link': linkController.text.trim(),
              'imageUrl': imageUrlController.text.trim(),
              'price': price ?? 0.0,
              'originalPrice': (originalPrice ?? 0) > 0 ? originalPrice : null,
              'discountRate': (discountRate ?? 0) > 0 ? discountRate : null,
              'ratingValue': parseDouble(ratingValueController.text),
              'ratingCount': parseInt(ratingCountController.text),
              'isEditorPick': isEditorPick,
              'isApproved': isApproved,
              'isExpired': isExpired,
              'hidePrice': isHidePrice,
              'isAmazonWarehouse': isAmazonWarehouse,
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
                    content: Text('✨ Fırsat bilgileri başarıyla güncellendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              setSheetState(() {
                isSaving = false;
                errorText = 'Güncelleme sırasında bir hata oluştu. Tekrar deneyin.';
              });
            }
          }

          final mediaQuery = MediaQuery.of(context);
          final keyboardHeight = mediaQuery.viewInsets.bottom;
          final maxSheetHeight = mediaQuery.size.height * 0.88;

          return Container(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Indicator & Header Bar
                Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 8, left: 20, right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Fırsatı Düzenle',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            tooltip: 'Kapat',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Form Scroll Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, keyboardHeight + 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section 1: Temel Bilgiler
                        _buildSectionCard(
                          isDark: isDark,
                          title: 'Temel Bilgiler',
                          icon: Icons.title_rounded,
                          children: [
                            _buildStyledTextField(
                              context: context,
                              label: 'Başlık *',
                              controller: titleController,
                              placeholder: 'Ürün veya kampanya başlığı',
                            ),
                            _buildStyledTextField(
                              context: context,
                              label: 'Açıklama',
                              controller: descriptionController,
                              placeholder: 'Fırsat detayları ve kupon kodları',
                              maxLines: 3,
                            ),
                            _buildStyledTextField(
                              context: context,
                              label: 'Görsel URL',
                              controller: imageUrlController,
                              placeholder: 'https://...',
                              keyboardType: TextInputType.url,
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Section 2: Fiyatlandırma & Kampanya
                        _buildSectionCard(
                          isDark: isDark,
                          title: 'Fiyatlandırma & Kampanya',
                          icon: Icons.sell_rounded,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStyledTextField(
                                    context: context,
                                    label: 'Fiyat (₺)',
                                    controller: priceController,
                                    placeholder: '0.00',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStyledTextField(
                                    context: context,
                                    label: 'Eski Fiyat (₺)',
                                    controller: originalPriceController,
                                    placeholder: 'Opsiyonel',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                              ],
                            ),
                            _buildStyledTextField(
                              context: context,
                              label: 'İndirim Oranı (%)',
                              controller: discountController,
                              placeholder: 'Örn: 25 (Otomatik hesaplanır)',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 4),
                            _buildSwitchTile(
                              isDark: isDark,
                              value: isHidePrice,
                              title: 'Fiyatı Gizle (Kampanya / Fiyatsız Paylaşım)',
                              subtitle: 'Aktif edilirse kartlarda ve detay sayfasında fiyat gizlenir',
                              activeColor: Colors.blue,
                              icon: Icons.visibility_off_rounded,
                              onChanged: (val) => setSheetState(() => isHidePrice = val),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Section 3: Mağaza & Derecelendirme
                        _buildSectionCard(
                          isDark: isDark,
                          title: 'Mağaza & Derecelendirme',
                          icon: Icons.storefront_rounded,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStyledTextField(
                                    context: context,
                                    label: 'Mağaza',
                                    controller: storeController,
                                    placeholder: 'Örn: Trendyol',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStyledTextField(
                                    context: context,
                                    label: 'Marka',
                                    controller: brandController,
                                    placeholder: 'Örn: Apple',
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStyledTextField(
                                    context: context,
                                    label: 'Rating Puanı',
                                    controller: ratingValueController,
                                    placeholder: 'Örn: 4.8',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStyledTextField(
                                    context: context,
                                    label: 'Oy Sayısı',
                                    controller: ratingCountController,
                                    placeholder: 'Örn: 1173',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Section 4: Bağlantı & Affiliate
                        _buildSectionCard(
                          isDark: isDark,
                          title: 'Bağlantı & Affiliate',
                          icon: Icons.link_rounded,
                          children: [
                            _buildStyledTextField(
                              context: context,
                              label: 'Ürün URL',
                              controller: linkController,
                              placeholder: 'https://...',
                              keyboardType: TextInputType.url,
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: isConvertingLink ? null : handleConvertAffiliate,
                                  icon: isConvertingLink
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.swap_horiz_rounded, size: 18),
                                  label: Text(
                                    isConvertingLink ? 'Dönüştürülüyor...' : 'Affiliate Linke Dönüştür',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final urlStr = linkController.text.trim();
                                    if (urlStr.isNotEmpty) {
                                      final uri = Uri.tryParse(urlStr);
                                      if (uri != null && await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: const Text('Linki Test Et', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Section 5: Kategori Seçimi
                        _buildSectionCard(
                          isDark: isDark,
                          title: 'Kategori',
                          icon: Icons.category_rounded,
                          children: [
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
                                  color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.grid_view_rounded,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        getCategoryDisplayText(selectedCategoryId, selectedSubCategory),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Section 6: Özellikler & Rozetler
                        _buildSectionCard(
                          isDark: isDark,
                          title: 'Özellikler & Durum',
                          icon: Icons.tune_rounded,
                          children: [
                            _buildSwitchTile(
                              isDark: isDark,
                              value: isAmazonWarehouse,
                              title: 'Amazon Depo Ürünü',
                              subtitle: 'Depo fırsat rozeti ekler',
                              activeColor: const Color(0xFFD97706),
                              icon: Icons.inventory_2_rounded,
                              onChanged: (val) => setSheetState(() => isAmazonWarehouse = val),
                            ),
                            _buildSwitchTile(
                              isDark: isDark,
                              value: isEditorPick,
                              title: 'Editörün Seçimi',
                              subtitle: 'Öne çıkan editör rozeti gösterir',
                              activeColor: const Color(0xFFF57C00),
                              icon: Icons.star_rounded,
                              onChanged: (val) => setSheetState(() => isEditorPick = val),
                            ),
                            _buildSwitchTile(
                              isDark: isDark,
                              value: isApproved,
                              title: 'Onaylı Fırsat',
                              subtitle: 'Yayında görüntülenir',
                              activeColor: Colors.green,
                              icon: Icons.check_circle_rounded,
                              onChanged: (val) => setSheetState(() => isApproved = val),
                            ),
                            _buildSwitchTile(
                              isDark: isDark,
                              value: isExpired,
                              title: 'Fırsat Bitti (Pasif)',
                              subtitle: 'Süresi bitenler sekmesine alır',
                              activeColor: const Color(0xFFE53935),
                              icon: Icons.timer_off_rounded,
                              onChanged: (val) => setSheetState(() => isExpired = val),
                            ),
                          ],
                        ),

                        if (errorText != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    errorText ?? '',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Fixed Bottom Save Action
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : handleSave,
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              )
                            : const Icon(Icons.save_rounded, size: 20),
                        label: Text(
                          isSaving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildSectionCard({
  required bool isDark,
  required String title,
  required IconData icon,
  required List<Widget> children,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[50],
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

Widget _buildStyledTextField({
  required BuildContext context,
  required String label,
  required TextEditingController controller,
  String placeholder = '',
  int maxLines = 1,
  TextInputType keyboardType = TextInputType.text,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primaryColor = Theme.of(context).colorScheme.primary;

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: placeholder,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurface : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSwitchTile({
  required bool isDark,
  required bool value,
  required String title,
  required String subtitle,
  required Color activeColor,
  required IconData icon,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: value ? activeColor.withValues(alpha: 0.08) : (isDark ? AppTheme.darkSurface : Colors.white),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: value ? activeColor.withValues(alpha: 0.3) : (isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),
      ),
    ),
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      activeColor: activeColor,
      title: Row(
        children: [
          Icon(icon, size: 18, color: value ? activeColor : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: value ? (isDark ? Colors.white : Colors.black87) : (isDark ? AppTheme.darkTextPrimary : Colors.black87),
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 26),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
          ),
        ),
      ),
    ),
  );
}
