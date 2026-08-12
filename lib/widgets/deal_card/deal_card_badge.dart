import 'package:flutter/material.dart';
import '../../models/deal.dart';

class DealCardBadge extends StatelessWidget {
  final Deal deal;
  final bool isDark;

  const DealCardBadge({
    super.key,
    required this.deal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Açık Modda Kart Fiyat Etiketinin Rengi (0xFFFFF3E0 & 0xFFE65100)
    // Gece Modunda Koyu Şık Neom
    final Color backgroundColor = isDark 
        ? const Color(0xFF1E1E2D).withValues(alpha: 0.95) 
        : const Color(0xFFFFF3E0); // Fiyat etiketiyle birebir aynı soft orange zemin

    final Color borderColor = isDark 
        ? const Color(0xFF33354A) 
        : const Color(0xFFFFB74D).withValues(alpha: 0.5);

    final Color flameColor = isDark 
        ? const Color(0xFFFF5722) 
        : const Color(0xFFE65100); // Fiyat etiketinin derin turuncu tonu

    final Color commentIconColor = isDark 
        ? const Color(0xFF94A3B8) 
        : const Color(0xFFE65100).withValues(alpha: 0.85);

    final Color textColor = isDark 
        ? const Color(0xFFF8FAFC) 
        : const Color(0xFFE65100);

    final Color separatorColor = isDark 
        ? Colors.white.withValues(alpha: 0.2) 
        : const Color(0xFFFFB74D).withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8), // Fiyat etiketine uygun kavis
        border: Border.all(
          color: borderColor,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Alev Göstergesi
          Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: flameColor,
          ),
          const SizedBox(width: 2.5),
          Text(
            '${deal.hotVotes}',
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),

          // Seperatör Çizgi
          Container(
            width: 0.8,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 4.5),
            color: separatorColor,
          ),

          // Yorum Göstergesi
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 11.5,
            color: commentIconColor,
          ),
          const SizedBox(width: 2.5),
          Text(
            '${deal.commentCount}',
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
