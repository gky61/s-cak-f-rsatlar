import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shimmer_box.dart';

/// Kullanıcı Listesi Yükleme Skeleton'ı (Takip Edilenler / Admin Kullanıcılar)
class UserListSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const UserListSkeleton({
    super.key,
    this.itemCount = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return ListView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: const Row(
            children: [
              // Avatar
              ShimmerBox.circular(size: 44),
              SizedBox(width: 12),

              // İsim ve Kullanıcı Adı
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: 80, height: 11, borderRadius: 4),
                  ],
                ),
              ),

              // Buton Pill
              ShimmerBox(width: 76, height: 32, borderRadius: 10),
            ],
          ),
        );
      },
    );
  }
}
