import 'package:flutter/material.dart';
import '../../models/deal.dart';
import '../../theme/app_theme.dart';

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
    // Uygulama bütünlüğüne uygun canlı renk tanımları
    // Alev Rengi: Uygulamanın ana Vibrant Orange rengi (0xFFFF6B35) veya Canlı Alev Turuncusu (0xFFFF5200)
    final bool isHot = deal.hotVotes > 0;
    final Color flameColor = isHot 
        ? AppTheme.primary 
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
    
    // Yorum İkon Rengi: Uygulama Secondary Mavi (0xFF004E92) / Canlı Safir Mavi (0xFF2563EB)
    final Color commentIconColor = isDark 
        ? const Color(0xFF60A5FA) 
        : AppTheme.secondary;

    // Metin Rengi: Yüksek kontrast ve belirginlik
    final Color textColor = isDark 
        ? Colors.white 
        : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // Belirgin, tok ve yüksek opaklıkta zemin (Gece: Koyu Neom | Gündüz: Saf Beyaz)
        color: isDark 
            ? const Color(0xFF1E1E2D).withValues(alpha: 0.95) 
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark 
              ? const Color(0xFF33354A) 
              : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.4) 
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Alev / Hotness Göstergesi (Canlı Uygulama Alev Rengi)
          Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: flameColor,
          ),
          const SizedBox(width: 3),
          Text(
            '${deal.hotVotes > 0 ? "+" : ""}${deal.hotVotes}',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),

          // Canlı ve Belirgin Ayırıcı Çizgi
          Container(
            width: 1,
            height: 11,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF475569) 
                  : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          // Yorum Göstergesi (Canlı Mavi / Secondary)
          Icon(
            Icons.chat_bubble_rounded,
            size: 12,
            color: commentIconColor,
          ),
          const SizedBox(width: 3),
          Text(
            '${deal.commentCount}',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
