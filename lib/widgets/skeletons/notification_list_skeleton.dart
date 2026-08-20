import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shimmer_box.dart';

/// Bildirimler Listesi Yükleme Skeleton'ı
class NotificationListSkeleton extends StatelessWidget {
  final int itemCount;

  const NotificationListSkeleton({
    super.key,
    this.itemCount = 6,
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
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bildirim İkonu
              ShimmerBox.circular(size: 38),
              SizedBox(width: 12),

              // Bildirim İçeriği
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 130, height: 14, borderRadius: 4),
                        ShimmerBox(width: 40, height: 11, borderRadius: 4),
                      ],
                    ),
                    SizedBox(height: 6),
                    ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                    SizedBox(height: 4),
                    ShimmerBox(width: 160, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
