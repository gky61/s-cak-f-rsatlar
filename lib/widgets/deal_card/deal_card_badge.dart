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
    // Canlı Alev Rengi: Sıcaklık 0 bile olsa her zaman göz alıcı Turuncu-Kırmızı (Canlı Alev)
    const Color flameColor = Color(0xFFFF5722); // Vibrant Flame Orange/Red
    
    // Yorum İkon Rengi: Kibar, nötr ve şık (Gündüz: Slate Navy, Gece: Soft Grey/Blue)
    final Color commentIconColor = isDark 
        ? const Color(0xFF94A3B8) 
        : const Color(0xFF64748B);

    // Metin Rengi: Yüksek okunabilirlik
    final Color textColor = isDark 
        ? const Color(0xFFF8FAFC) 
        : const Color(0xFF1E293B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
      decoration: BoxDecoration(
        // Kibar, yumuşak ve şık zemin (Gündüz: Beyaz hafif saydam, Gece: Koyu Neom)
        color: isDark 
            ? const Color(0xFF1E1E2D).withValues(alpha: 0.92) 
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.15) 
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Alev Göstergesi (Canlı Turuncu/Kırmızı)
          const Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: flameColor,
          ),
          const SizedBox(width: 2.5),
          Text(
            '${deal.hotVotes > 0 ? "+" : ""}${deal.hotVotes}',
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),

          // Kibar İnce Seperatör
          Container(
            width: 0.8,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 4.5),
            color: isDark 
                ? Colors.white.withValues(alpha: 0.2) 
                : Colors.black.withValues(alpha: 0.12),
          ),

          // Yorum Göstergesi (Zarif Outline İkon)
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
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
