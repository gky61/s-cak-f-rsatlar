import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';
import 'ad_banner_widget.dart';
import '../firebase_options.dart';


class AdDealCard extends StatelessWidget {
  final CardViewMode viewMode;
  final String? adUnitId;

  const AdDealCard({
    super.key,
    required this.viewMode,
    this.adUnitId,
  });


  // Reklam boyutunu belirle - Standart AdMob boyutları kullan
  AdSize _getAdSize(CardViewMode mode) {
    if (mode == CardViewMode.vertical) {
      // Vertical mod için Medium Rectangle (300x250) - Kartlara uyumlu
      return AdSize.mediumRectangle;
    } else {
      // Horizontal mod için Large Banner (320x100) - Liste görünümüne uyumlu
      return AdSize.largeBanner;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final adSize = _getAdSize(viewMode);

    if (viewMode == CardViewMode.vertical) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F5F0),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Reklam - Kartın tamamını kaplar, merkeze hizalı
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white, // Reklam arka planı
                child: AdBannerWidget(
                  adUnitId: adUnitId ?? DefaultFirebaseOptions.bannerAdUnitId,
                  adSize: adSize, // Standart AdMob reklam boyutu
                ),

              ),
              // Reklam etiketi (üstte, sağ üst köşede)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.ads_click,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reklam',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Horizontal card
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F5F0),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Reklam - Kartın tamamını kaplar, merkeze hizalı
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white, // Reklam arka planı
                child: AdBannerWidget(
                  adUnitId: adUnitId ?? DefaultFirebaseOptions.bannerAdUnitId,
                  adSize: adSize, // Standart AdMob reklam boyutu
                ),

              ),
              // Reklam etiketi (üstte, sağ üst köşede)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.ads_click,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reklam',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
