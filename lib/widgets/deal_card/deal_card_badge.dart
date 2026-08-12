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
    // Açık Modda Kartın Gövde Rengi (0xFFF1F5F9 - Hafif Kırık Beyaz)
    // Gece Modunda Koyu Şık Neom
    final Color backgroundColor = isDark 
        ? const Color(0xFF1E1E2D).withValues(alpha: 0.95) 
        : const Color(0xFFF1F5F9); // Kart gövdesindeki kırık beyaz zemin

    final Color borderColor = isDark 
        ? const Color(0xFF33354A) 
        : const Color(0xFFCBD5E1);

    const Color flameColor = Color(0xFFFF5722); // Canlı Alev Turuncusu

    final Color commentIconColor = isDark 
        ? const Color(0xFF94A3B8) 
        : const Color(0xFF64748B);

    final Color textColor = isDark 
        ? const Color(0xFFF8FAFC) 
        : const Color(0xFF1E293B);

    final Color separatorColor = isDark 
        ? Colors.white.withValues(alpha: 0.2) 
        : const Color(0xFFCBD5E1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Alev Göstergesi (Canlı Turuncu)
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
