import 'package:flutter/material.dart';

/// Migros "Money ile" özel fırsat rozeti (Mor-Turuncu Minimalist Tasarım)
class MigrosMoneyBadge extends StatelessWidget {
  final bool compact;
  final double compactSize;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  const MigrosMoneyBadge({
    super.key,
    this.compact = false,
    this.compactSize = 13.0,
    this.fontSize = 10.0,
    this.iconSize = 13.0,
    this.padding,
    this.borderRadius,
  });

  static const LinearGradient moneyGradient = LinearGradient(
    colors: [
      Color(0xFFFFD000), // Yoğun, parlak ve canlı sarı
      Color(0xFFFF9500), // Zengin ve derin turuncu-sarı/amber
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Kartlar için Satıcı Yanı Mikro Minimalist Kompakt İkon
    if (compact) {
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

    // 2. Fırsat Detay Sayfası için Şık & Doygun Sarı-Altın Mikro Kapsül Tasarım
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
            'Money ile',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isDark ? FontWeight.w900 : FontWeight.w700,
              color: isDark ? const Color(0xFF141414) : const Color(0xFF2D1E05),
              letterSpacing: 0.0,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Yardımcı metot: Fırsat bir Migros Money fırsatı mı?
  static bool isMigrosMoneyDeal(dynamic deal) {
    if (deal == null) return false;
    final store = (deal.store ?? '').toString().toLowerCase();
    if (!store.contains('migros')) return false;

    // Fiyat farkı veya priceLabel içinde MONEY bulunması
    final hasDiscount = deal.originalPrice != null && deal.originalPrice > deal.price;
    final hasMoneyLabel = deal.priceLabel != null && deal.priceLabel.toString().toUpperCase().contains('MONEY');

    return hasDiscount || hasMoneyLabel;
  }
}
