import 'package:flutter/material.dart';

/// Pazarama "Plus ile" özel fırsat rozeti (Mor-Turuncu Minimalist Tasarım)
class PazaramaPlusBadge extends StatelessWidget {
  final bool compact;
  final double compactSize;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  const PazaramaPlusBadge({
    super.key,
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
          child: Icon(
            Icons.add,
            size: compactSize * 0.65,
            color: Colors.white,
          ),
        ),
      );
    }

    // 2. Fırsat Detay Sayfası için Şık & Minimalist Mikro Kapsül Tasarım
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
              child: Icon(
                Icons.add,
                size: iconSize * 0.65,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4.5),
          Text(
            'Plus ile',
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

  /// Yardımcı metot: Fırsat bir Pazarama Plus fırsatı mı?
  static bool isPazaramaPlusDeal(dynamic deal) {
    if (deal == null) return false;
    final store = (deal.store ?? '').toString().toLowerCase();
    if (!store.contains('pazarama')) return false;

    // priceLabel içinde PLUS bulunması
    final hasPlusLabel = deal.priceLabel != null &&
        deal.priceLabel.toString().toUpperCase().contains('PLUS');

    return hasPlusLabel;
  }
}
