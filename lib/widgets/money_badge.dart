import 'package:flutter/material.dart';

/// Migros "Money ile" özel fırsat rozeti
class MoneyBadge extends StatelessWidget {
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;

  const MoneyBadge({
    super.key,
    this.fontSize = 11,
    this.iconSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD54F), // Canlı Altın/Sarı
            Color(0xFFFFB300), // Migros Money Kehribar Sarı
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFA000),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Money Coin Simgesi (Sarı Yuvarlak & Gülen Yüz / M)
          Container(
            width: iconSize + 3,
            height: iconSize + 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF212121),
              border: Border.all(
                color: const Color(0xFFFFD54F),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'M',
                style: TextStyle(
                  fontSize: iconSize * 0.65,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFD54F),
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Money ile',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1A1A1A),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Yardımcı metot: Fırsat bir Migros Money fırsatı mı?
  static bool isMoneyDeal(dynamic deal) {
    if (deal == null) return false;
    final store = (deal.store ?? '').toString().toLowerCase();
    if (!store.contains('migros')) return false;

    // Fiyat farkı veya priceLabel içinde MONEY bulunması
    final hasDiscount = deal.originalPrice != null && deal.originalPrice > deal.price;
    final hasMoneyLabel = deal.priceLabel != null && deal.priceLabel.toString().toUpperCase().contains('MONEY');

    return hasDiscount || hasMoneyLabel;
  }
}
