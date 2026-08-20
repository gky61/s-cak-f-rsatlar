import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shimmer_box.dart';

/// Yorumlar Yükleme Skeleton'ı
class CommentsSkeleton extends StatelessWidget {
  final int itemCount;

  const CommentsSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Satır: Avatar + Kullanıcı Adı + Zaman
              const Row(
                children: [
                  ShimmerBox.circular(size: 34),
                  SizedBox(width: 10),
                  ShimmerBox(width: 100, height: 13, borderRadius: 4),
                  SizedBox(width: 8),
                  ShimmerBox(width: 40, height: 18, borderRadius: 6),
                  Spacer(),
                  ShimmerBox(width: 40, height: 11, borderRadius: 4),
                ],
              ),
              const SizedBox(height: 10),

              // Yorum Metni
              const ShimmerBox(
                width: double.infinity,
                height: 12,
                borderRadius: 4,
              ),
              const SizedBox(height: 6),
              ShimmerBox(
                width: index.isEven ? 220 : 160,
                height: 12,
                borderRadius: 4,
              ),
              const SizedBox(height: 10),

              // Reaksiyon Satırı
              const Row(
                children: [
                  ShimmerBox(width: 50, height: 22, borderRadius: 8),
                  SizedBox(width: 10),
                  ShimmerBox(width: 50, height: 22, borderRadius: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
