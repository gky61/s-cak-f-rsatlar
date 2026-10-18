import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/deal.dart';
import '../../../services/auth_service.dart';
import '../../../services/deal_sync_service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/store_price_badge.dart';

/// Admin'lerin fırsat detayında tek tıkla fiyat, eski fiyat, indirim oranı
/// ve kampanya etiketini anında güncelleyebilmesini sağlayan ultra-hızlı modal sheet.
void showQuickPriceEditSheet({
  required BuildContext context,
  required Deal deal,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => _QuickPriceEditSheetContent(
      deal: deal,
      firestoreService: firestoreService,
      onDealUpdated: onDealUpdated,
    ),
  );
}

class _QuickPriceEditSheetContent extends StatefulWidget {
  final Deal deal;
  final FirestoreService firestoreService;
  final VoidCallback onDealUpdated;

  const _QuickPriceEditSheetContent({
    required this.deal,
    required this.firestoreService,
    required this.onDealUpdated,
  });

  @override
  State<_QuickPriceEditSheetContent> createState() => _QuickPriceEditSheetContentState();
}

class _QuickPriceEditSheetContentState extends State<_QuickPriceEditSheetContent> {
  late final TextEditingController _priceController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _priceLabelController;
  late final FocusNode _priceFocusNode;

  bool _hidePrice = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Genel kampanya öneri etiketleri (minimalist ve canlı fade efektli turuncu tasarım)
  static const List<String> _quickPromoSuggestions = [
    'Günün Fırsatı',
    '2. Ürüne %50',
    'Kuponla',
    'Sepette İndirimli',
    '3 Al 2 Öde',
  ];

  // Mağaza sadakat programı önerileri (kendilerine ait marka rozetleri)
  static const List<String> _quickLoyaltySuggestions = [
    'Prime ile',
    "Plus'a Özel",
    'Premium ile',
    'Money ile',
    'CarrefourSA Kart ile',
  ];

  @override
  void initState() {
    super.initState();
    _hidePrice = widget.deal.hidePrice;

    final initialPriceText = widget.deal.price > 0
        ? PriceFormatUtil.formatForInput(widget.deal.price)
        : '';
    _priceController = TextEditingController(text: initialPriceText);

    final initialOrigText = widget.deal.originalPrice != null && widget.deal.originalPrice! > 0
        ? PriceFormatUtil.formatForInput(widget.deal.originalPrice)
        : '';
    _originalPriceController = TextEditingController(text: initialOrigText);

    _priceLabelController = TextEditingController(text: widget.deal.priceLabel ?? '');

    _priceFocusNode = FocusNode();

    // Dinleyici ekleyerek anlık indirim oranı hesaplaması ve canlı önizleme
    _priceController.addListener(_onPriceInputsChanged);
    _originalPriceController.addListener(_onPriceInputsChanged);

    // Otomatik odaklanma ve tüm metni seçme (tek tıkla direkt yeni fiyat yazabilme)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _priceFocusNode.requestFocus();
        if (_priceController.text.isNotEmpty) {
          _priceController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _priceController.text.length,
          );
        }
      }
    });
  }

  void _onPriceInputsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_onPriceInputsChanged);
    _originalPriceController.removeListener(_onPriceInputsChanged);
    _priceController.dispose();
    _originalPriceController.dispose();
    _priceLabelController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  double? get _parsedPrice => PriceFormatUtil.parse(_priceController.text);
  double? get _parsedOriginalPrice => PriceFormatUtil.parse(_originalPriceController.text);

  int? get _calculatedDiscountRate {
    final curr = _parsedPrice;
    final orig = _parsedOriginalPrice;
    if (curr == null || orig == null) return null;
    return PriceFormatUtil.calculateDiscountRate(orig, curr);
  }

  double? get _calculatedSavings {
    final curr = _parsedPrice;
    final orig = _parsedOriginalPrice;
    if (curr == null || orig == null || orig <= curr) return null;
    return orig - curr;
  }

  void _applyQuickDiscount(int percentage) {
    HapticFeedback.lightImpact();
    final orig = _parsedOriginalPrice ?? _parsedPrice;
    if (orig == null || orig <= 0) return;

    // Eğer eski fiyat boşsa, şu anki fiyatı eski fiyata taşı
    if (_parsedOriginalPrice == null || _parsedOriginalPrice! <= 0) {
      _originalPriceController.text = PriceFormatUtil.formatForInput(orig);
    }

    final newPrice = orig * (1 - (percentage / 100));
    _priceController.text = PriceFormatUtil.formatForInput(newPrice);
    _priceController.selection = TextSelection.collapsed(offset: _priceController.text.length);
  }

  void _applyRounding(String ending) {
    HapticFeedback.lightImpact();
    final curr = _parsedPrice;
    if (curr == null || curr <= 0) return;

    double rounded;
    if (ending == '.90') {
      rounded = curr.floor() + 0.90;
    } else if (ending == '.00') {
      rounded = curr.roundToDouble();
    } else {
      rounded = curr;
    }

    _priceController.text = PriceFormatUtil.formatForInput(rounded);
    _priceController.selection = TextSelection.collapsed(offset: _priceController.text.length);
  }

  Future<void> _handleSave() async {
    // Güvenlik Kalkanı: Admin kontrolü
    final isAdmin = await AuthService().isAdmin();
    if (!isAdmin) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Bu işlemi yapmaya yetkiniz bulunmamaktadır.';
        });
      }
      return;
    }

    final currentPrice = _parsedPrice;
    if (!_hidePrice && (currentPrice == null || currentPrice <= 0)) {
      setState(() {
        _errorMessage = 'Lütfen geçerli bir satış fiyatı girin veya "Fiyatı Gizle" seçeneğini işaretleyin.';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    final origPrice = _parsedOriginalPrice;
    final discountRate = _calculatedDiscountRate;
    final label = _priceLabelController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updates = <String, dynamic>{
        'price': currentPrice ?? 0.0,
        'originalPrice': (origPrice != null && origPrice > 0) ? origPrice : null,
        'discountRate': (discountRate != null && discountRate > 0) ? discountRate : null,
        'priceLabel': label.isNotEmpty ? label : null,
        'hidePrice': _hidePrice,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final success = await widget.firestoreService.updateDeal(widget.deal.id, updates);

      if (success) {
        // İstemci tarafı yerel reaktif senkronizasyon (FS-09 Kalkanı)
        final updatedDeal = widget.deal.copyWith(
          price: currentPrice ?? 0.0,
          originalPrice: origPrice,
          discountRate: discountRate,
          priceLabel: label.isNotEmpty ? label : null,
          hidePrice: _hidePrice,
        );
        DealSyncService.instance.notifyDealUpdated(updatedDeal);

        widget.onDealUpdated();

        if (mounted) {
          Navigator.of(context).pop();
        }

        // Haptic ve başarı bildirimi
        HapticFeedback.mediumImpact();
        if (mounted) {
          final formattedPrice = PriceFormatUtil.format(currentPrice ?? 0.0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _hidePrice
                          ? '⚡ Fiyat başarıyla gizlendi'
                          : '⚡ Fiyat başarıyla güncellendi: $formattedPrice',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorMessage = 'Fiyat güncellenirken bir hata oluştu. Lütfen tekrar deneyin.';
          });
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Bağlantı hatası: $e';
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = AppTheme.primary;
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    final isPending = widget.deal.isApproved == false;

    final discountRate = _calculatedDiscountRate;
    final savings = _calculatedSavings;

    return Container(
      padding: EdgeInsets.only(bottom: keyboardBottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Sürükleme Çubuğu
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Başlık & Admin Rozeti & Kapat Butonu
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Hızlı Fiyat Güncelle',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'ADMİN',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD97706),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPending
                              ? '⏳ Onay bekleyen fırsat için anında fiyat revizyonu'
                              : 'Tek tıkla anında fiyatı ve indirimi güncelle',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Fırsat Özet Kartı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.deal.store.isNotEmpty ? widget.deal.store : 'Mağaza',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.deal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Onayda',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Fiyat Giriş Alanları (Satış Fiyatı & Eski Fiyat yan yana)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Satış Fiyatı (Ana Fiyat)
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Satış Fiyatı',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const Text(
                              ' *',
                              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _priceController,
                          focusNode: _priceFocusNode,
                          enabled: !_hidePrice && !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            TurkishCurrencyInputFormatter(),
                          ],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _hidePrice
                                ? Colors.grey
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            letterSpacing: -0.3,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12, right: 6),
                              child: Center(
                                widthFactor: 1.0,
                                child: Text(
                                  '₺',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _hidePrice ? Colors.grey : primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            suffixIcon: _priceController.text.isNotEmpty && !_hidePrice
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () => _priceController.clear(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : null,
                            hintText: '0,00',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: primaryColor, width: 1.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 2. Eski / Normal Fiyat (Orijinal)
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eski Fiyat (Opsiyonel)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _originalPriceController,
                          enabled: !_hidePrice && !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            TurkishCurrencyInputFormatter(),
                          ],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _hidePrice
                                ? Colors.grey
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12, right: 6),
                              child: Center(
                                widthFactor: 1.0,
                                child: Text(
                                  '₺',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            suffixIcon: _originalPriceController.text.isNotEmpty && !_hidePrice
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () => _originalPriceController.clear(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : null,
                            hintText: '0,00',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: primaryColor, width: 1.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Canlı İndirim Kartı & Tasarruf Önizlemesi
              if (!_hidePrice && discountRate != null && discountRate > 0) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '%$discountRate İNDİRİM',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (savings != null && savings > 0)
                        Text(
                          'Tasarruf: ₺${PriceFormatUtil.format(savings, includeSymbol: false)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                          ),
                        ),
                      const Spacer(),
                      const Icon(Icons.check_rounded, size: 16, color: Color(0xFFEF4444)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Hızlı İndirim Seçenekleri (Preset Chips)
              if (!_hidePrice) ...[
                Row(
                  children: [
                    Text(
                      'Hızlı İndirim:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildQuickActionChip(
                              label: '-%10',
                              isDark: isDark,
                              onTap: () => _applyQuickDiscount(10),
                            ),
                            _buildQuickActionChip(
                              label: '-%20',
                              isDark: isDark,
                              onTap: () => _applyQuickDiscount(20),
                            ),
                            _buildQuickActionChip(
                              label: '-%30',
                              isDark: isDark,
                              onTap: () => _applyQuickDiscount(30),
                            ),
                            _buildQuickActionChip(
                              label: '-%50',
                              isDark: isDark,
                              onTap: () => _applyQuickDiscount(50),
                            ),
                            _buildQuickActionChip(
                              label: '.90 Yap',
                              isDark: isDark,
                              onTap: () => _applyRounding('.90'),
                            ),
                            _buildQuickActionChip(
                              label: '.00 Yap',
                              isDark: isDark,
                              onTap: () => _applyRounding('.00'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Fiyat Etiketi / Kampanya Notu (priceLabel)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fiyat Notu / Kampanya Etiketi (Opsiyonel)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _priceLabelController,
                    enabled: !_isSaving,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      hintText: 'Örn: Sepette İndirimli, Kuponla, Prime ile...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                      ),
                      suffixIcon: _priceLabelController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _priceLabelController.clear();
                                setState(() {});
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryColor, width: 1.8),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  // Canlı Rozet Önizlemesi
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Canlı Görünüm:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_priceLabelController.text.trim().isNotEmpty) ...[
                          StorePriceBadge(
                            label: _priceLabelController.text.trim(),
                            store: widget.deal.store,
                          ),
                        ] else ...[
                          Text(
                            'Rozet Yok (Standart Fiyat)',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (_priceLabelController.text.trim().isNotEmpty)
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _priceLabelController.clear();
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                '✕ Temizle',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 1. Grup: Genel Kampanyalar
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFFFF6B35)),
                      const SizedBox(width: 4),
                      Text(
                        'Genel Kampanyalar (Canlı Turuncu Fade):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _quickPromoSuggestions.map((label) {
                        return _buildPromoChip(label: label, isDark: isDark);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 2. Grup: Mağaza Sadakat Rozetleri
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 4),
                      Text(
                        'Mağaza Sadakat Rozetleri:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _quickLoyaltySuggestions.map((label) {
                        return _buildLoyaltyChip(label: label, isDark: isDark);
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Fiyatı Gizle Seçeneği (Switch)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    value: _hidePrice,
                    onChanged: _isSaving
                        ? null
                        : (val) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _hidePrice = val;
                            });
                          },
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    activeThumbColor: primaryColor,
                    title: Row(
                      children: [
                        Icon(
                          Icons.visibility_off_rounded,
                          size: 16,
                          color: _hidePrice ? primaryColor : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fiyatı Gizle (Kampanya Linki)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Sepet indirimi veya dinamik fiyatlı kampanyalarda fiyat yerine linke yönlendirir.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),

              // Hata Mesajı
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Aksiyon Butonları
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Vazgeç',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSaving
                              ? [Colors.grey[600]!, Colors.grey[700]!]
                              : const [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isSaving
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Fiyatı Güncelle',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip({
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4.5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromoChip({
    required String label,
    required bool isDark,
  }) {
    final isSelected = _priceLabelController.text.trim() == label;
    final promoIcon = StorePriceBadge.getPromoIcon(label);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            if (isSelected) {
              _priceLabelController.clear();
            } else {
              _priceLabelController.text = label;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: isSelected ? StorePriceBadge.promoGradient : null,
            color: isSelected
                ? null
                : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF6B35)
                  : const Color(0xFFFF8E53).withValues(alpha: isDark ? 0.35 : 0.25),
              width: isSelected ? 1.2 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.28),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                promoIcon,
                size: 12.5,
                color: isSelected ? Colors.white : const Color(0xFFFF6B35),
              ),
              const SizedBox(width: 4.5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoyaltyChip({
    required String label,
    required bool isDark,
  }) {
    final isSelected = _priceLabelController.text.trim() == label;
    Color brandColor = const Color(0xFF8B5CF6);
    String emblem = 'P';
    if (label.contains('Money')) {
      brandColor = const Color(0xFFF59E0B);
      emblem = 'M';
    } else if (label.contains('Plus')) {
      brandColor = const Color(0xFF06B6D4);
      emblem = '+';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            if (isSelected) {
              _priceLabelController.clear();
            } else {
              _priceLabelController.text = label;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? brandColor.withValues(alpha: isDark ? 0.28 : 0.15)
                : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? brandColor
                  : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 13.5,
                height: 13.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandColor,
                ),
                child: Center(
                  child: Text(
                    emblem,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4.5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? (isDark ? Colors.white : brandColor)
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
