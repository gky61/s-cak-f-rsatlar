import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/deal.dart';
import '../../../models/category.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/category_selector_widget.dart';
import '../../../widgets/store_price_badge.dart';
import 'category_selector.dart';
import '../../../services/affiliate/affiliate_service.dart';

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
  final cleanUrlController = TextEditingController(
    text: deal.displayUrl.isNotEmpty ? deal.displayUrl : Deal.cleanProductUrl(deal.link),
  );

  // Eğer mağaza affiliate destekliyorsa ve mevcut link henüz affiliate linkine dönüştürülmemişse (organik link ise),
  // düzenleme ekranı açıldığında otomatik olarak affiliate linke dönüştürerek hazır getir
  String initialAffiliateLink = deal.link;
  final effectiveSourceUrl = deal.displayUrl.isNotEmpty ? deal.displayUrl : deal.link;
  if (AffiliateService.isStoreSupported(deal.store) ||
      AffiliateService.isStoreSupported(deal.displayUrl) ||
      AffiliateService.isStoreSupported(deal.link)) {
    final adapter = AffiliateService.getAdapter(deal.link) ?? AffiliateService.getAdapter(effectiveSourceUrl);
    final isAlreadyAffiliate = adapter != null && adapter.isAlreadyAffiliate(Uri.tryParse(deal.link) ?? Uri());
    if (!isAlreadyAffiliate) {
      final autoConverted = AffiliateService.convertToAffiliateLink(effectiveSourceUrl);
      if (autoConverted != effectiveSourceUrl && autoConverted.isNotEmpty) {
        initialAffiliateLink = autoConverted;
      }
    }
  }
  final linkController = TextEditingController(text: initialAffiliateLink);
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

  final priceLabelController = TextEditingController(text: deal.priceLabel ?? '');

  final rValue = deal.ratingValue;
  final ratingValueController = TextEditingController(
    text: rValue != null ? rValue.toString() : '',
  );
  final rCount = deal.ratingCount;
  final ratingCountController = TextEditingController(
    text: rCount != null ? rCount.toString() : '',
  );

  final couponCodeController = TextEditingController(text: deal.couponCode ?? '');

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

          Future<String> resolveAndConvertToAffiliateLink(String originalUrl) {
            return AffiliateService.resolveAndConvertToAffiliate(originalUrl);
          }

          Future<void> handleConvertAffiliate() async {
            var currentUrl = cleanUrlController.text.trim();
            if (currentUrl.isEmpty) {
              currentUrl = linkController.text.trim();
            }
            if (currentUrl.isEmpty) {
              setSheetState(() => errorText = 'Dönüştürmek için önce geçerli bir URL girin.');
              return;
            }

            setSheetState(() {
              isConvertingLink = true;
              errorText = null;
            });

            try {
              // Temiz URL henüz yoksa veya affiliate ise unwrapped halini cleanUrl alanına koyalım
              final inputAdapter = AffiliateService.getAdapter(cleanUrlController.text);
              final isAffiliateInput = (inputAdapter != null && inputAdapter.isAlreadyAffiliate(Uri.tryParse(cleanUrlController.text) ?? Uri())) ||
                  cleanUrlController.text.contains('btrck.com') ||
                  cleanUrlController.text.contains('7t4g.adj.st') ||
                  cleanUrlController.text.contains('adj.st') ||
                  cleanUrlController.text.contains('tag=');
              if (cleanUrlController.text.trim().isEmpty || isAffiliateInput) {
                final unwrap = Deal.cleanProductUrl(currentUrl);
                if (unwrap.isNotEmpty && !unwrap.contains('btrck.com') && !unwrap.contains('7t4g.adj.st') && !unwrap.contains('tag=')) {
                  cleanUrlController.text = unwrap;
                  currentUrl = unwrap;
                }
              }

              final converted = await resolveAndConvertToAffiliateLink(currentUrl);
              setSheetState(() {
                linkController.text = converted;
                isConvertingLink = false;
              });

              if (sheetContext.mounted) {
                final resAdapter = AffiliateService.getAdapter(converted);
                final isAffiliateResult = resAdapter != null && resAdapter.isAlreadyAffiliate(Uri.tryParse(converted) ?? Uri());
                if (converted != currentUrl && isAffiliateResult) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Affiliate link başarıyla üretildi!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('ℹ️ Orijinal mağaza linki korundu (Şalter kapalı veya mağaza hazır değil).'),
                      backgroundColor: Colors.blueGrey,
                    ),
                  );
                }
              }
            } catch (e) {
              setSheetState(() {
                isConvertingLink = false;
                linkController.text = currentUrl;
              });
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('ℹ️ Dönüştürme başarısız oldu, orijinal link korundu.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
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

            final isSupported = AffiliateService.isStoreSupported(storeController.text.trim()) ||
                AffiliateService.isStoreSupported(deal.store) ||
                AffiliateService.isStoreSupported(cleanUrlController.text.trim()) ||
                AffiliateService.isStoreSupported(linkController.text.trim());

            String finalCleanUrl = cleanUrlController.text.trim();
            String finalLink = linkController.text.trim();

            if (!isSupported) {
              // Affiliate desteklenmeyen mağazalar: Standart tek URL modeli
              final singleUrl = finalCleanUrl.isNotEmpty ? finalCleanUrl : finalLink;
              final cleaned = singleUrl.isNotEmpty ? Deal.cleanProductUrl(singleUrl) : singleUrl;
              finalCleanUrl = cleaned;
              finalLink = cleaned;
            } else {
              // Affiliate desteklenen mağazalar (Teknosa, Hepsiburada, Amazon)
              // 1. Temiz URL boş ama link doluysa cleanUrl türet
              if (finalCleanUrl.isEmpty && finalLink.isNotEmpty) {
                finalCleanUrl = Deal.cleanProductUrl(finalLink);
                cleanUrlController.text = finalCleanUrl;
              }

              // 2. Link boşsa veya henüz affiliate linki değilse cleanUrl üzerinden affiliate üret
              final linkAdapter = AffiliateService.getAdapter(finalLink);
              final isFinalAffiliate = linkAdapter != null && linkAdapter.isAlreadyAffiliate(Uri.tryParse(finalLink) ?? Uri());
              if (finalLink.isEmpty || !isFinalAffiliate) {
                try {
                  final sourceForAffiliate = (finalCleanUrl.isNotEmpty &&
                          !finalCleanUrl.contains('btrck.com') &&
                          !finalCleanUrl.contains('7t4g.adj.st'))
                      ? finalCleanUrl
                      : finalLink;
                  final converted = await resolveAndConvertToAffiliateLink(sourceForAffiliate);
                  if (converted.isNotEmpty) {
                    finalLink = converted;
                  }
                } catch (_) {}
                linkController.text = finalLink;
              }
            }

            final updates = <String, dynamic>{
              'title': titleController.text.trim(),
              'description': descriptionController.text.trim(),
              'store': storeController.text.trim(),
              'brand': brandController.text.trim().isNotEmpty ? brandController.text.trim() : null,
              'category': Category.getNameById(selectedCategoryId),
              'subCategory': selectedSubCategory,
              'cleanUrl': finalCleanUrl.isNotEmpty ? finalCleanUrl : null,
              'link': finalLink,
              'url': finalLink,
              'imageUrl': imageUrlController.text.trim(),
              'price': price ?? 0.0,
              'originalPrice': (originalPrice ?? 0) > 0 ? originalPrice : null,
              'discountRate': (discountRate ?? 0) > 0 ? discountRate : null,
              'priceLabel': priceLabelController.text.trim().isNotEmpty ? priceLabelController.text.trim() : null,
              'ratingValue': parseDouble(ratingValueController.text),
              'ratingCount': parseInt(ratingCountController.text),
              'isEditorPick': isEditorPick,
              'isApproved': isApproved,
              'isExpired': isExpired,
              'hidePrice': isHidePrice,
              'isAmazonWarehouse': isAmazonWarehouse,
              'couponCode': couponCodeController.text.trim().isNotEmpty ? couponCodeController.text.trim().toUpperCase() : null,
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
          final isAffiliateSupported = AffiliateService.isStoreSupported(storeController.text.trim()) ||
              AffiliateService.isStoreSupported(deal.store) ||
              AffiliateService.isStoreSupported(cleanUrlController.text.trim()) ||
              AffiliateService.isStoreSupported(linkController.text.trim());

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
                            _buildStyledTextField(
                              context: context,
                              label: 'Kupon Kodu (Opsiyonel)',
                              controller: couponCodeController,
                              placeholder: 'Örn: İNDİRİM50',
                            ),
                            const SizedBox(height: 8),
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

                        // Section: Özel Fiyat & Rozet Yönetimi (priceLabel)
                        _buildSectionCard(
                          isDark: isDark,
                          title: 'Özel Fiyat & Rozet (priceLabel)',
                          icon: Icons.local_offer_rounded,
                          children: [
                            // Canlı Rozet Önizleme
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Önizleme: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (priceLabelController.text.trim().isNotEmpty) ...[
                                    StorePriceBadge(
                                      label: priceLabelController.text.trim(),
                                      store: storeController.text.trim(),
                                    ),
                                  ] else ...[
                                    Text(
                                      'Rozet Yok (Standart Ürün)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Hızlı Seçim Şablonları
                            Text(
                              'Hızlı Seçim Şablonları:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildBadgeChip(
                                  label: 'Prime Fırsatı',
                                  color: const Color(0xFFFF6000),
                                  isSelected: priceLabelController.text == 'Prime Fırsatı',
                                  onTap: () => setSheetState(() => priceLabelController.text = 'Prime Fırsatı'),
                                  isDark: isDark,
                                ),
                                _buildBadgeChip(
                                  label: "Plus'a Özel",
                                  color: const Color(0xFFF97316),
                                  isSelected: priceLabelController.text == "Plus'a Özel",
                                  onTap: () => setSheetState(() => priceLabelController.text = "Plus'a Özel"),
                                  isDark: isDark,
                                ),
                                _buildBadgeChip(
                                  label: 'Premium ile',
                                  color: const Color(0xFF8B5CF6),
                                  isSelected: priceLabelController.text == 'Premium ile',
                                  onTap: () => setSheetState(() => priceLabelController.text = 'Premium ile'),
                                  isDark: isDark,
                                ),
                                _buildBadgeChip(
                                  label: 'Plus ile',
                                  color: const Color(0xFF06B6D4),
                                  isSelected: priceLabelController.text == 'Plus ile',
                                  onTap: () => setSheetState(() => priceLabelController.text = 'Plus ile'),
                                  isDark: isDark,
                                ),
                                _buildBadgeChip(
                                  label: 'Money ile',
                                  color: const Color(0xFF10B981),
                                  isSelected: priceLabelController.text == 'Money ile',
                                  onTap: () => setSheetState(() => priceLabelController.text = 'Money ile'),
                                  isDark: isDark,
                                ),
                                _buildBadgeChip(
                                  label: '✕ Temizle',
                                  color: Colors.grey,
                                  isSelected: priceLabelController.text.isEmpty,
                                  onTap: () => setSheetState(() => priceLabelController.text = ''),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildStyledTextField(
                              context: context,
                              label: 'Özel Fiyat Etiketi / Metin (priceLabel)',
                              controller: priceLabelController,
                              placeholder: "Örn: Plus'a Özel, Prime Fırsatı, Sepette %20...",
                              onChanged: (_) => setSheetState(() {}),
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

                        // Section 4: Bağlantı veya Bağlantı & Affiliate (Çoklu Görünüm)
                        if (isAffiliateSupported)
                          _buildSectionCard(
                            isDark: isDark,
                            title: 'Bağlantı & Affiliate (Çoklu Görünüm)',
                            icon: Icons.link_rounded,
                            children: [
                              // 1. Orijinal Mağaza Linki (cleanUrl)
                              _buildStyledTextField(
                                context: context,
                                label: 'Orijinal Mağaza Linki (Temiz / Görünen Link)',
                                controller: cleanUrlController,
                                placeholder: 'https://www.teknosa.com/...',
                                keyboardType: TextInputType.url,
                                helperText: 'Kullanıcılara gösterilen, kopyalanan ve paylaşılan temiz ürün linki.',
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final urlStr = cleanUrlController.text.trim();
                                      if (urlStr.isNotEmpty) {
                                        final uri = Uri.tryParse(urlStr);
                                        if (uri != null && await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                                    label: const Text('Orijinal Linki Aç', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: isConvertingLink ? null : handleConvertAffiliate,
                                    icon: isConvertingLink
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.auto_fix_high_rounded, size: 18),
                                    label: Text(
                                      isConvertingLink ? 'Dönüştürülüyor...' : 'Orijinalden Affiliate Üret',
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
                                ],
                              ),
                              const SizedBox(height: 14),
                              Divider(height: 1, color: isDark ? AppTheme.darkBorder : Colors.grey[300]),
                              const SizedBox(height: 14),

                              // 2. Aktif Affiliate Linki (link)
                              _buildStyledTextField(
                                context: context,
                                label: 'Aktif Affiliate Linki (Mağazaya Git Butonunda Çalışan)',
                                controller: linkController,
                                placeholder: 'https://rdr.btrck.com/...',
                                keyboardType: TextInputType.url,
                                helperText: 'Kullanıcı mağazaya git butonuna bastığında komisyon kazanımı için açılır.',
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
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
                                    label: const Text('Affiliate Linki Test Et', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          _buildSectionCard(
                            isDark: isDark,
                            title: 'Bağlantı',
                            icon: Icons.link_rounded,
                            children: [
                              _buildStyledTextField(
                                context: context,
                                label: 'Ürün URL',
                                controller: cleanUrlController,
                                placeholder: 'https://...',
                                keyboardType: TextInputType.url,
                                helperText: 'Ürünün doğrudan mağaza linki.',
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final urlStr = cleanUrlController.text.trim().isNotEmpty
                                          ? cleanUrlController.text.trim()
                                          : linkController.text.trim();
                                      if (urlStr.isNotEmpty) {
                                        final uri = Uri.tryParse(urlStr);
                                        if (uri != null && await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
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
  String? helperText,
  int maxLines = 1,
  TextInputType keyboardType = TextInputType.text,
  ValueChanged<String>? onChanged,
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
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: placeholder,
            helperText: helperText,
            helperStyle: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            helperMaxLines: 2,
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

Widget _buildBadgeChip({
  required String label,
  required Color color,
  required bool isSelected,
  required VoidCallback onTap,
  required bool isDark,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: isDark ? 0.3 : 0.15)
            : (isDark ? AppTheme.darkSurfaceElevated : Colors.grey[100]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? color
              : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected
              ? (isDark ? Colors.white : color)
              : (isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
      ),
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
    child: Material(
      color: Colors.transparent,
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
    ),
  );
}
