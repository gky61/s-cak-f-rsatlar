import 'dart:ui';
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
    // Alev rengi: Pozitifse canlı turuncu-kırmızı gradient hissi
    final bool isHot = deal.hotVotes > 0;
    final Color flameColor = isHot 
        ? const Color(0xFFFF5252) 
        : (isDark ? Colors.grey[400]! : Colors.grey[600]!);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1E1E2C).withOpacity(0.75) 
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.15) 
                  : Colors.black.withOpacity(0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? Colors.black.withOpacity(0.3) 
                    : Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Alev / Hotness Göstergesi
              Icon(
                Icons.local_fire_department_rounded,
                size: 13,
                color: flameColor,
              ),
              const SizedBox(width: 3),
              Text(
                '${deal.hotVotes > 0 ? "+" : ""}${deal.hotVotes}',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),

              // Zarif Ayırıcı Çizgi
              Container(
                width: 1,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.2) 
                      : Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),

              // Yorum Göstergesi
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 12,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 3),
              Text(
                '${deal.commentCount}',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
