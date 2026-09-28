import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';
import '../services/ad_manager_service.dart';
import '../services/analytics_service.dart';
import '../screens/kuponlar_page.dart';
import 'ad_native_widget.dart';
import '../firebase_options.dart';

/// FırsatKolik — Akış İçi Sponsorlu / Yerel Reklam Kartı (Native Ad Card)
///
/// Faz 3.3 kapsamında hem Grid (2 sütun dikey) hem de List (yatay tek sütun)
/// modlarında Google AdMob Native Ads Advanced formatını kullanır.
/// Reklam dolmadığında (No-fill) veya ağ hatasında yüksek dönüşümlü
/// Kuponlar Keşif Kartı'na (House Promo Fallback) sorunsuz geçiş yapar.
class AdDealCard extends StatelessWidget {
  final CardViewMode viewMode;
  final String? adUnitId;
  final String placement;

  const AdDealCard({
    super.key,
    required this.viewMode,
    this.adUnitId,
    this.placement = 'home',
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdManagerService.instance,
      builder: (context, _) {
        final adManager = AdManagerService.instance;
        if (!adManager.isAdsEnabled) {
          return const SizedBox.shrink();
        }

        // Native reklam şalteri kontrolü (Genel, Kuponlar, Aktüel veya Native kapatılmışsa fallback veya shrink)
        if (!adManager.nativeEnabled ||
            (placement == 'kuponlar' && !adManager.nativeCouponsEnabled) ||
            (placement == 'aktuel' && !adManager.nativeAktuelEnabled)) {
          return _buildHousePromoCard(context);
        }

        return AdNativeWidget(
          key: ValueKey('ad_native_widget_${placement}_${viewMode.name}_${adUnitId ?? "default"}'),
          viewMode: viewMode,
          adUnitId: adUnitId ?? DefaultFirebaseOptions.nativeAdUnitId,
          placement: placement == 'kuponlar'
              ? 'kuponlar_list'
              : (placement == 'aktuel'
                  ? 'aktuel_grid'
                  : (viewMode == CardViewMode.horizontal ? 'home_list' : 'home_grid')),
          fallbackBuilder: (ctx) => _buildHousePromoCard(ctx),
        );
      },
    );
  }

  /// Reklam yüklenemediğinde veya şalter kapalıyken gösterilen %100 uyumlu İç Keşif Kartı (House Promo)
  Widget _buildHousePromoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (viewMode == CardViewMode.vertical) {
      // ─── 2 Sütunlu Grid İçin Dikey Keşif Kartı ───
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
                'placement': 'home_grid_vertical_fallback',
              });
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KuponlarPage()),
              );
            },
            child: Stack(
              children: [
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
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
      // ─── Liste Modu İçin Yatay Keşif Kartı (Horizontal House Promo) ───
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 124,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (placement == 'kuponlar') {
                AnalyticsService.instance.logCustomEvent('sponsored_deal_card_click', {
                  'placement': 'kuponlar_list_horizontal_fallback',
                });
                Navigator.of(context).pop();
              } else if (placement == 'aktuel') {
                AnalyticsService.instance.logCustomEvent('sponsored_deal_card_click', {
                  'placement': 'aktuel_grid_horizontal_fallback',
                });
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else {
                AnalyticsService.instance.logCustomEvent('sponsored_deal_card_click', {
                  'placement': 'home_list_horizontal_fallback',
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KuponlarPage()),
                );
              }
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: isDark
                            ? [
                                AppTheme.darkSurface,
                                primaryColor.withValues(alpha: 0.10),
                              ]
                            : [
                                Colors.white,
                                primaryColor.withValues(alpha: 0.05),
                              ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Sol İkon Kutusu
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            (placement == 'kuponlar' || placement == 'aktuel')
                                ? Icons.local_fire_department_rounded
                                : Icons.confirmation_number_rounded,
                            color: primaryColor,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Orta Bilgi Alanı
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.stars_rounded, size: 10, color: Colors.white),
                                      SizedBox(width: 3),
                                      Text(
                                        'Sponsorlu',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (placement == 'kuponlar' || placement == 'aktuel') ? 'Günün Fırsatı' : 'Özel Fırsat',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              (placement == 'kuponlar' || placement == 'aktuel')
                                  ? 'Günün En Sıcak Fırsatları!'
                                  : 'İndirim Kuponlarını Kaçırma!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (placement == 'kuponlar' || placement == 'aktuel')
                                  ? 'Topluluğun oyladığı kaçırılmayacak günün indirimleri'
                                  : 'Yüzlerce mağazada geçerli güncel kupon kodları',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Sağ Buton
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (placement == 'kuponlar' || placement == 'aktuel') ? 'Fırsatlar' : 'Kuponlar',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                          ],
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
    }
  }
}
