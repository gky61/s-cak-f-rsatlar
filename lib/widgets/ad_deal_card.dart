import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';
import '../services/ad_manager_service.dart';
import '../services/analytics_service.dart';
import '../screens/kuponlar_page.dart';
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdManagerService.instance,
      builder: (context, _) {
        if (!AdManagerService.instance.isAdsEnabled) {
          return const SizedBox.shrink();
        }
        if (viewMode == CardViewMode.vertical && !AdManagerService.instance.nativeEnabled) {
          return const SizedBox.shrink();
        }
        if (viewMode == CardViewMode.horizontal && !AdManagerService.instance.bannerEnabled) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

    if (viewMode == CardViewMode.vertical) {
      // 2 Sütunlu Grid İçin %100 AdMob Uyumlu Sponsorlu / Keşif Kartı
      // (Google AdMob politikası gereği 300x250 banner'lar 160px hücreye küçültülerek ZORLANAMAZ)
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              AnalyticsService.instance.logCustomEvent('sponsored_deal_card_click', {
                'placement': 'home_grid_vertical',
              });
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KuponlarPage()),
              );
            },
            child: Stack(
              children: [
                // Arka plan gradient deseni
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                AppTheme.darkSurface,
                                primaryColor.withValues(alpha: 0.12),
                              ]
                            : [
                                Colors.white,
                                primaryColor.withValues(alpha: 0.05),
                              ],
                      ),
                    ),
                  ),
                ),

                // İçerik
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst İkon & Rozet
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_offer_rounded,
                              color: primaryColor,
                              size: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars_rounded, size: 11, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'Sponsorlu',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Başlık
                      Text(
                        'İndirim Kuponlarını Kaçırma!',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Açıklama
                      Text(
                        'Seçkin mağazalardaki anlık indirim kodlarını hemen incele.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),

                      // Buton
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'Kuponları Gör',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Horizontal card: Liste modunda standart 320x100 Large Banner veya 320x50
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 124,
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
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Reklam - Ortalanmış ve un-scaled
              Center(
                child: AdBannerWidget(
                  adUnitId: adUnitId ?? DefaultFirebaseOptions.bannerAdUnitId,
                  adSize: AdSize.largeBanner, // 320x100
                ),
              ),

              // Reklam etiketi (sağ üst)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'Reklam',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  },
);
  }
}
