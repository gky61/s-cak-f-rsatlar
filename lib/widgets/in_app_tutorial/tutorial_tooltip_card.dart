import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/in_app_tutorial_service.dart';

/// Ultra minimalist, kompakt, ferah ve ekranda akıcı süzülen Spotlight Bilgi Kartı
class TutorialTooltipCard extends StatelessWidget {
  final TutorialStep step;
  final int currentIndex;
  final int totalSteps;
  final Rect targetRect;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  const TutorialTooltipCard({
    super.key,
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.targetRect,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isLastStep = currentIndex == totalSteps - 1;

    // Hedefin dikey konumuna göre tek bir mutlak dikey koordinat hesaplama
    final double targetCenterY = targetRect.center.dy;
    final bool isBottomNavStep = targetRect.bottom > (screenSize.height - 120.0);
    final bool placeBelow = !isBottomNavStep && (targetCenterY < (screenSize.height * 0.48));
    const double cardEstimatedHeight = 184.0;

    double calculatedTop;
    if (isBottomNavStep) {
      // Bottom navigation adımları (Kaydedilenler, Popüler, Fırsat Paylaş) için kart konumu
      // ekranın ortasında %100 SABİT kalsın; alt bara ve focus çemberine ferah/güvenli mesafede durur.
      calculatedTop = screenSize.height - mediaQuery.padding.bottom - cardEstimatedHeight - 96.0;
    } else if (placeBelow) {
      calculatedTop = targetRect.bottom + 16.0;
    } else {
      calculatedTop = targetRect.top - cardEstimatedHeight - 24.0;
    }

    final double finalTop = calculatedTop.clamp(
      mediaQuery.padding.top + 16.0,
      screenSize.height - mediaQuery.padding.bottom - cardEstimatedHeight - 24.0,
    );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
      top: finalTop,
      left: 18.0,
      right: 18.0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: Container(
            key: ValueKey('compact_showcase_card_${step.id}'),
            constraints: const BoxConstraints(minHeight: 184.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: step.accentColor.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 1. ZARİF SEGMENTLİ İLERLEME ÇUBUĞU ──
                      Row(
                        children: List.generate(totalSteps, (index) {
                          final isActive = index == currentIndex;
                          final isCompleted = index < currentIndex;

                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOutCubic,
                              margin: EdgeInsets.only(
                                right: index < totalSteps - 1 ? 4.0 : 0,
                              ),
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? step.accentColor
                                    : (isCompleted
                                        ? Colors.white.withValues(alpha: 0.40)
                                        : Colors.white.withValues(alpha: 0.10)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),

                      // ── 2. ÜST BAR: Kategori Rozeti & Kapat Butonu ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Kategori Etiketi
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: step.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  step.icon,
                                  size: 12,
                                  color: step.accentColor,
                                ),
                                const SizedBox(width: 4.5),
                                Text(
                                  step.categoryTag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: step.accentColor,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Turu Geç Butonu (Minimalist)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onSkip();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7.5,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Turu Geç',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.60),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 2.5),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.60),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── 3. BAŞLIK ──
                      Text(
                        step.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // ── 4. AÇIKLAMA (Sabit Yükseklik Alanı - Boyut Değişimini Önler) ──
                      SizedBox(
                        height: 38.0,
                        child: Text(
                          step.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFCBD5E1),
                            height: 1.36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── 5. ALT AKSİYON BAR (Kompakt Geri & Şık Devam Butonu) ──
                      Row(
                        children: [
                          // Minimalist Kompakt Geri Butonu
                          if (currentIndex > 0) ...[
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onPrevious();
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Devam Et / Keşfe Başla Butonu (Minimalist & Yumuşak)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onNext();
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: step.accentColor,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: step.accentColor.withValues(alpha: 0.22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        step.buttonText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      if (!isLastStep) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
