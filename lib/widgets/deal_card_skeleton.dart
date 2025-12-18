import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sicak_firsatlar/theme/app_theme.dart';
import 'package:sicak_firsatlar/services/theme_service.dart';

class DealCardSkeleton extends StatelessWidget {
  final CardViewMode viewMode;

  const DealCardSkeleton({
    super.key,
    this.viewMode = CardViewMode.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (viewMode == CardViewMode.horizontal) {
      return _buildHorizontalSkeleton(context, isDark);
    } else {
      return _buildVerticalSkeleton(context, isDark);
    }
  }

  Widget _buildVerticalSkeleton(BuildContext context, bool isDark) {
    final cardBackgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.05);
    
    return Container(
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: 1,
          ),
      ),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Görsel Skeleton
              Shimmer.fromColors(
                baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: AspectRatio(
              aspectRatio: 1.0,
                child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                  ),
                ),
              ),
          // İçerik Skeleton
              Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  // Mağaza
                  Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                    child: Container(
                      width: 60,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Başlık
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                          child: Container(
                          width: double.infinity,
                          height: 10,
                            decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: 80,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Fiyat
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                          child: Container(
                      width: 50,
                      height: 12,
                            decoration: BoxDecoration(
                        color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSkeleton(BuildContext context, bool isDark) {
    final cardBackgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : Colors.black.withValues(alpha: 0.05);

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Görsel Skeleton
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Container(
              width: 112,
              height: 112,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // İçerik Skeleton
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kategori & Mağaza
                  Row(
                    children: [
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      child: Container(
                          width: 60,
                          height: 10,
                        decoration: BoxDecoration(
                            color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      child: Container(
                          width: 50,
                          height: 10,
                        decoration: BoxDecoration(
                            color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      ),
                    ],
                    ),
                  const SizedBox(height: 12),
                  // Başlık
                  Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                    child: Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                          child: Container(
                      width: 150,
                      height: 14,
                            decoration: BoxDecoration(
                        color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const Spacer(),
                  // Fiyat & Buton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                          child: Container(
                          width: 80,
                            height: 20,
                            decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: 70,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }
}
