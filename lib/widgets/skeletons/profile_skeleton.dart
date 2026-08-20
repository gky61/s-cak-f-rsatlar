import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../deal_card_skeleton.dart';
import 'shimmer_box.dart';

/// Profil Ekranı Yükleme Skeleton'ı
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // 1. Hero Header Kartı Skeleton
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              children: [
                // Avatar
                const ShimmerBox.circular(size: 88),
                const SizedBox(height: 14),

                // İsim & Kullanıcı Adı
                const ShimmerBox(width: 160, height: 20, borderRadius: 6),
                const SizedBox(height: 6),
                const ShimmerBox(width: 100, height: 13, borderRadius: 4),
                const SizedBox(height: 12),

                // Seviye Rozeti
                const ShimmerBox(width: 120, height: 26, borderRadius: 12),
                const SizedBox(height: 20),

                // İstatistikler (3 Kart)
                Row(
                  children: List.generate(
                    3,
                    (index) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: index < 2 ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: const Column(
                          children: [
                            ShimmerBox(width: 32, height: 18, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 50, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Sekme Başlıkları Skeleton
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ShimmerBox(width: 90, height: 34, borderRadius: 10),
                SizedBox(width: 8),
                ShimmerBox(width: 90, height: 34, borderRadius: 10),
                SizedBox(width: 8),
                ShimmerBox(width: 90, height: 34, borderRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Fırsatlar Grid Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.61,
              ),
              itemCount: 4,
              itemBuilder: (context, index) => const DealCardSkeleton(viewMode: CardViewMode.vertical),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
