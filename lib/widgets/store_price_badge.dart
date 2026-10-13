import 'package:flutter/material.dart';
import '../models/deal.dart';
import 'amazon_prime_badge.dart';
import 'hepsiburada_premium_badge.dart';
import 'idefix_premium_badge.dart';
import 'migros_money_badge.dart';
import 'pazarama_plus_badge.dart';
import 'trendyol_plus_badge.dart';

/// Tüm mağazalar ve özel fiyat etiketleri (priceLabel) için merkezi, modern Mor-Turuncu rozet bileşeni.
class StorePriceBadge extends StatelessWidget {
  final Deal? deal;
  final String? label;
  final String? store;
  final bool compact;
  final double compactSize;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  const StorePriceBadge({
    super.key,
    this.deal,
    this.label,
    this.store,
    this.compact = false,
    this.compactSize = 13.0,
    this.fontSize = 10.0,
    this.iconSize = 13.0,
    this.padding,
    this.borderRadius,
  });

  static const LinearGradient badgeGradient = LinearGradient(
    colors: [
      Color(0xFFFF6000), // Canlı Turuncu
      Color(0xFF8B5CF6), // Mor
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient moneyGradient = LinearGradient(
    colors: [
      Color(0xFFFFD000), // Yoğun, parlak ve canlı sarı
      Color(0xFFFF9500), // Zengin ve derin turuncu-sarı/amber
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// FırsatKolik imza canlı geçişli turuncu degrade (Fiyatı Güncelle butonundaki gibi fade efektli)
  static const LinearGradient promoGradient = LinearGradient(
    colors: [
      Color(0xFFFF6B35), // Sıcak Turuncu
      Color(0xFFFF8E53), // Canlı Açık Turuncu
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Fırsatın herhangi bir özel rozeti veya fiyat etiketi var mı?
  static bool hasBadge({Deal? deal, String? label, String? store}) {
    final effectiveLabel = (label ?? deal?.priceLabel)?.trim();
    if (effectiveLabel != null && effectiveLabel.isNotEmpty) {
      return true;
    }
    if (deal != null) {
      return AmazonPrimeBadge.isAmazonPrimeDeal(deal) ||
          TrendyolPlusBadge.isTrendyolPlusDeal(deal) ||
          HepsiburadaPremiumBadge.isHepsiburadaPremiumDeal(deal) ||
          PazaramaPlusBadge.isPazaramaPlusDeal(deal) ||
          MigrosMoneyBadge.isMigrosMoneyDeal(deal) ||
          IdefixPremiumBadge.isIdefixPremiumDeal(deal);
    }
    return false;
  }

  String get effectiveLabel {
    if (label != null && label!.trim().isNotEmpty) {
      return label!.trim();
    }
    if (deal?.priceLabel != null && deal!.priceLabel!.trim().isNotEmpty) {
      return deal!.priceLabel!.trim();
    }
    if (deal != null) {
      if (AmazonPrimeBadge.isAmazonPrimeDeal(deal)) return 'Prime Fırsatı';
      if (TrendyolPlusBadge.isTrendyolPlusDeal(deal)) return "Plus'a Özel";
      if (HepsiburadaPremiumBadge.isHepsiburadaPremiumDeal(deal)) return 'Premium ile';
      if (PazaramaPlusBadge.isPazaramaPlusDeal(deal)) return 'Plus ile';
      if (MigrosMoneyBadge.isMigrosMoneyDeal(deal)) return 'Money ile';
      if (IdefixPremiumBadge.isIdefixPremiumDeal(deal)) return "Premium'a Özel";
    }
    return '';
  }

  String get effectiveStore {
    return (store ?? deal?.store ?? '').toLowerCase();
  }

  bool get isMoney {
    final lblUpper = effectiveLabel.toUpperCase();
    // Eğer özel bir etiket varsa ve etiket içinde MONEY geçmiyorsa ASLA Money rozeti olamaz!
    if (lblUpper.isNotEmpty) {
      return lblUpper.contains('MONEY');
    }
    final strLower = effectiveStore;
    return strLower.contains('migros') && (deal != null && MigrosMoneyBadge.isMigrosMoneyDeal(deal));
  }

  bool get isPrime {
    final lblUpper = effectiveLabel.toUpperCase();
    // Eğer özel bir etiket varsa ve etiket içinde PRIME geçmiyorsa ASLA Prime rozeti olamaz!
    if (lblUpper.isNotEmpty) {
      return lblUpper.contains('PRIME');
    }
    return deal != null && AmazonPrimeBadge.isAmazonPrimeDeal(deal);
  }

  bool get isPremium {
    final lblUpper = effectiveLabel.toUpperCase();
    // Eğer özel bir etiket varsa ve etiket içinde PREMIUM geçmiyorsa ASLA Premium rozeti olamaz!
    if (lblUpper.isNotEmpty) {
      return lblUpper.contains('PREMIUM');
    }
    return deal != null &&
        (HepsiburadaPremiumBadge.isHepsiburadaPremiumDeal(deal) || IdefixPremiumBadge.isIdefixPremiumDeal(deal));
  }

  bool get isPlus {
    final lblUpper = effectiveLabel.toUpperCase();
    // Eğer özel bir etiket varsa ve etiket içinde PLUS geçmiyorsa ASLA Plus rozeti olamaz!
    if (lblUpper.isNotEmpty) {
      return lblUpper.contains('PLUS');
    }
    return deal != null &&
        (TrendyolPlusBadge.isTrendyolPlusDeal(deal) || PazaramaPlusBadge.isPazaramaPlusDeal(deal));
  }

  /// Prime, Premium, Plus veya Money gibi özel üyelik/sadakat programı mı?
  bool get isLoyaltyBadge => isMoney || isPrime || isPremium || isPlus;

  String get emblem {
    if (isMoney) return 'M';
    if (isPlus) return '+';
    if (isPrime || isPremium) return 'P';
    return '';
  }

  /// Genel kampanya etiketleri için minimalist sembol
  static IconData getPromoIcon(String labelText) {
    final upper = labelText.toUpperCase();
    if (upper.contains('KUPON')) return Icons.confirmation_number_rounded;
    if (upper.contains('SEPET')) return Icons.shopping_bag_rounded;
    if (upper.contains('GÜN') || upper.contains('GUN')) return Icons.local_fire_department_rounded;
    if (upper.contains('%') || upper.contains('ÜRÜN') || upper.contains('URUN')) return Icons.discount_rounded;
    if (upper.contains('FLAŞ') || upper.contains('FLAS') || upper.contains('ŞOK') || upper.contains('SOK')) return Icons.bolt_rounded;
    return Icons.local_offer_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasBadge(deal: deal, label: label, store: store)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMoneyBadge = isMoney;
    final emblemText = emblem;
    final labelText = effectiveLabel;

    // 1. Kartlar için Satıcı Yanı Mikro Minimalist Kompakt İkon (Anasayfa Kartları)
    if (compact) {
      if (isMoneyBadge) {
        return Container(
          width: compactSize,
          height: compactSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                blurRadius: 1.5,
                offset: const Offset(0, 0.5),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/money.webp',
              width: compactSize,
              height: compactSize,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFF59E0B),
                child: Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: compactSize * 0.58,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (isLoyaltyBadge) {
        return Container(
          width: compactSize,
          height: compactSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: badgeGradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6000).withValues(alpha: 0.25),
                blurRadius: 1.5,
                offset: const Offset(0, 0.5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              emblemText,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: compactSize * (emblemText == '+' ? 0.72 : 0.62),
                height: 1.0,
              ),
            ),
          ),
        );
      }

      // Genel Kampanya Etiketleri (Günün Fırsatı, Kuponla, 2. Ürüne %50 vb.)
      return Container(
        width: compactSize,
        height: compactSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: promoGradient,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
              blurRadius: 1.5,
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            getPromoIcon(labelText),
            size: compactSize * 0.65,
            color: Colors.white,
          ),
        ),
      );
    }

    // 2. Fırsat Detay Sayfası için Şık & Minimalist Mikro Kapsül Tasarım
    if (isMoneyBadge) {
      return Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
        decoration: BoxDecoration(
          gradient: moneyGradient,
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFE066),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9500).withValues(alpha: 0.38),
              blurRadius: 5,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 0.8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/money.webp',
                  width: iconSize + 1,
                  height: iconSize + 1,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: iconSize + 1,
                    height: iconSize + 1,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF141414),
                    ),
                    child: Center(
                      child: Text(
                        'M',
                        style: TextStyle(
                          color: const Color(0xFFFFD000),
                          fontWeight: FontWeight.w900,
                          fontSize: iconSize * 0.58,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              labelText,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isDark ? FontWeight.w900 : FontWeight.w600,
                color: isDark ? const Color(0xFF141414) : const Color(0xFF2D1E05),
                letterSpacing: 0.0,
                height: 1.1,
              ),
            ),
          ],
        ),
      );
    }

    if (isLoyaltyBadge) {
      return Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A1C36) : const Color(0xFFF5F0FF),
          borderRadius: borderRadius ?? BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF9333EA).withValues(alpha: isDark ? 0.35 : 0.25),
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: badgeGradient,
              ),
              child: Center(
                child: Text(
                  emblemText,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: iconSize * (emblemText == '+' ? 0.72 : 0.62),
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4.5),
            Text(
              labelText,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8),
                letterSpacing: 0.1,
                height: 1.1,
              ),
            ),
          ],
        ),
      );
    }

    // 3. Genel Kampanya & Fırsat Etiketleri (Günün Fırsatı, 2. Ürüne %50, Kuponla, Sepette İndirimli vb.)
    // "Fiyatı Güncelle" butonundaki gibi geçişli fade degrade efektli, statik minimalist ve canlı tasarım
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: promoGradient,
        borderRadius: borderRadius ?? BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: isDark ? 0.35 : 0.22),
            blurRadius: 4,
            offset: const Offset(0, 1.2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            getPromoIcon(labelText),
            size: iconSize * 0.88,
            color: Colors.white,
          ),
          const SizedBox(width: 4.5),
          Text(
            labelText,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.1,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
