import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shimmer_box.dart';

/// Fırsat Detay Ekranı Yükleme Skeleton'ı
class DealDetailSkeleton extends StatelessWidget {
  const DealDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Görsel Alanı Skeleton
          Container(
            width: double.infinity,
            height: 280,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: const Center(
              child: ShimmerBox(
                width: 140,
                height: 140,
                borderRadius: 16,
              ),
            ),
          ),

          // 2. İçerik Alanı
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mağaza & Kategori Rozetleri
                const Row(
                  children: [
                    ShimmerBox(width: 80, height: 26, borderRadius: 8),
                    SizedBox(width: 8),
                    ShimmerBox(width: 100, height: 26, borderRadius: 8),
                    Spacer(),
                    ShimmerBox(width: 50, height: 26, borderRadius: 8),
                  ],
                ),
                const SizedBox(height: 14),

                // Başlık Satırları
                const ShimmerBox(width: double.infinity, height: 18, borderRadius: 4),
                const SizedBox(height: 8),
                const ShimmerBox(width: 220, height: 18, borderRadius: 4),
                const SizedBox(height: 18),

                // Fiyat ve İndirim Satırı
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShimmerBox(width: 130, height: 28, borderRadius: 6),
                    SizedBox(width: 10),
                    ShimmerBox(width: 70, height: 18, borderRadius: 4),
                    Spacer(),
                    ShimmerBox(width: 60, height: 26, borderRadius: 8),
                  ],
                ),
                const SizedBox(height: 20),

                // Termometre Oylama Çubuğu
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: const Row(
                    children: [
                      ShimmerBox.circular(size: 36),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 90, height: 12, borderRadius: 4),
                            SizedBox(height: 6),
                            ShimmerBox(width: double.infinity, height: 8, borderRadius: 4),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      ShimmerBox.circular(size: 36),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Butonlar Satırı
                const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ShimmerBox(height: 48, borderRadius: 14),
                    ),
                    SizedBox(width: 10),
                    ShimmerBox(width: 48, height: 48, borderRadius: 14),
                    SizedBox(width: 10),
                    ShimmerBox(width: 48, height: 48, borderRadius: 14),
                  ],
                ),
                const SizedBox(height: 20),

                // Paylaşan Kullanıcı Satırı
                const Row(
                  children: [
                    ShimmerBox.circular(size: 40),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 110, height: 14, borderRadius: 4),
                        SizedBox(height: 5),
                        ShimmerBox(width: 70, height: 11, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Açıklama Notched Kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 12),
                      ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 180, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
