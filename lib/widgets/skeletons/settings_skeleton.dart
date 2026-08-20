import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shimmer_box.dart';

/// Kategori Tercihleri Sayfası Yükleme Skeleton'ı
class CategoryPreferencesSkeleton extends StatelessWidget {
  const CategoryPreferencesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Bilgi Banner'ı
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 160, height: 16, borderRadius: 4),
              SizedBox(height: 8),
              ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
              SizedBox(height: 5),
              ShimmerBox(width: 200, height: 12, borderRadius: 4),
            ],
          ),
        ),

        // 2. Kategori Kartları
        ...List.generate(
          6,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: const Row(
              children: [
                ShimmerBox.circular(size: 38),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 5),
                      ShimmerBox(width: 80, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
                ShimmerBox(width: 44, height: 26, borderRadius: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Anahtar Kelime Takip Sayfası Yükleme Skeleton'ı
class KeywordTrackingSkeleton extends StatelessWidget {
  const KeywordTrackingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Bilgi Kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 150, height: 16, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                SizedBox(height: 5),
                ShimmerBox(width: 180, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Input Alanı
          const ShimmerBox(width: double.infinity, height: 50, borderRadius: 14),
          const SizedBox(height: 20),

          // 3. Başlık
          const ShimmerBox(width: 130, height: 14, borderRadius: 4),
          const SizedBox(height: 12),

          // 4. Kelime Kartları
          ...List.generate(
            4,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: const Row(
                children: [
                  ShimmerBox.circular(size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: ShimmerBox(width: 100, height: 14, borderRadius: 4),
                  ),
                  ShimmerBox.circular(size: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bildirim Ayarları Sayfası Yükleme Skeleton'ı
class NotificationSettingsSkeleton extends StatelessWidget {
  const NotificationSettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 1. Grup Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              children: List.generate(
                3,
                (index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ShimmerBox.circular(size: 34),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 130, height: 14, borderRadius: 4),
                            SizedBox(height: 5),
                            ShimmerBox(width: 180, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      ShimmerBox(width: 44, height: 26, borderRadius: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. İkinci Grup Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              children: List.generate(
                2,
                (index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ShimmerBox.circular(size: 34),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 110, height: 14, borderRadius: 4),
                            SizedBox(height: 5),
                            ShimmerBox(width: 160, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      ShimmerBox(width: 44, height: 26, borderRadius: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
