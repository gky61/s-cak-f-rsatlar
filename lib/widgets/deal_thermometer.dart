import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deal.dart';
import '../theme/app_theme.dart';

/// Modern, state-of-the-art interactive Thermometer and Community Voting Component
class DealThermometer extends StatefulWidget {
  final Deal deal;
  final int hotVotes;
  final int coldVotes;
  final bool hasVotedHot;
  final bool hasVotedCold;
  final Function(bool isHot) onVote;

  const DealThermometer({
    super.key,
    required this.deal,
    required this.hotVotes,
    required this.coldVotes,
    required this.hasVotedHot,
    required this.hasVotedCold,
    required this.onVote,
  });

  @override
  State<DealThermometer> createState() => _DealThermometerState();
}

class _DealThermometerState extends State<DealThermometer> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _flareController;
  late AnimationController _scoreBounceController;
  late AnimationController _hotScaleController;
  late AnimationController _coldScaleController;
  late AnimationController _feedbackController;

  String _feedbackText = '';
  Color _feedbackColor = AppTheme.primary;
  int _lastTotalVotes = 0;

  @override
  void initState() {
    super.initState();
    _lastTotalVotes = widget.hotVotes + widget.coldVotes;

    // 1. Ambient breathing pulse for glow & live indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // 2. Kinetic shimmer flare sweep along progress track
    _flareController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // 3. Score bounce spring
    _scoreBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );

    // 4. Button tactile scale controllers
    _hotScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );

    _coldScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );

    // 5. Floating feedback pill (+1 AL! / +1 GEÇ)
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void didUpdateWidget(DealThermometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTotalVotes = widget.hotVotes + widget.coldVotes;
    if (newTotalVotes != _lastTotalVotes) {
      _lastTotalVotes = newTotalVotes;
      _flareController.forward(from: 0.0);
      _scoreBounceController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flareController.dispose();
    _scoreBounceController.dispose();
    _hotScaleController.dispose();
    _coldScaleController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _triggerEnergyImpact({bool? isHot, bool isRemoval = false}) {
    _flareController.forward(from: 0.0);
    _scoreBounceController.forward(from: 0.0);

    if (isRemoval) {
      setState(() {
        _feedbackText = '-1 Geri Alındı';
        _feedbackColor = const Color(0xFF64748B);
      });
      _feedbackController.forward(from: 0.0);
    } else if (isHot != null) {
      setState(() {
        _feedbackText = isHot ? '+1 AL! 🔥' : '+1 GEÇ ❄️';
        _feedbackColor = isHot ? const Color(0xFFEA580C) : const Color(0xFF0891B2);
      });
      _feedbackController.forward(from: 0.0);
    }
  }

  void _onVoteTap(bool isHot) {
    HapticFeedback.lightImpact();

    if (isHot) {
      _hotScaleController.reverse().then((_) {
        if (mounted) _hotScaleController.forward();
      });
    } else {
      _coldScaleController.reverse().then((_) {
        if (mounted) _coldScaleController.forward();
      });
    }

    final bool isRemoval = isHot ? widget.hasVotedHot : widget.hasVotedCold;
    _triggerEnergyImpact(isHot: isHot, isRemoval: isRemoval);
    widget.onVote(isHot);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentHotVotes = widget.hotVotes;
    final currentColdVotes = widget.coldVotes;
    final totalVotes = currentHotVotes + currentColdVotes;
    final hotPercentage = totalVotes > 0 ? (currentHotVotes / totalVotes * 100).round() : 50;

    final isColdActive = widget.hasVotedCold;
    final isHotActive = widget.hasVotedHot;

    // ─── STATUS MESSAGE & CHIP BADGE ──────────────────────────────────
    (String, String, Color) getStatusDetails() {
      if (totalVotes == 0) {
        return ('🎯', 'İlk değerlendirmeyi sen yap!', const Color(0xFF6366F1));
      }
      if (hotPercentage >= 80) {
        return ('🔥', 'Efsane Fırsat • Bu fiyat kaçmaz!', const Color(0xFFDC2626));
      }
      if (hotPercentage >= 60) {
        return ('👍', 'Sıcak Bakılıyor • Topluluk sevdi', const Color(0xFFEA580C));
      }
      if (hotPercentage >= 40) {
        return ('⚖️', 'Kafa Kafaya • Karar senin', const Color(0xFFD97706));
      }
      if (hotPercentage >= 20) {
        return ('🧐', 'Pek Tutulmadı • Fiyat tartışılır', const Color(0xFF0284C7));
      }
      return ('❄️', 'Param cebimde kalsın • Zayıf fırsat', const Color(0xFF0891B2));
    }

    final (statusEmoji, statusText, statusAccent) = getStatusDetails();

    Color getThermometerScoreColor() {
      if (totalVotes == 0) return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      if (hotPercentage >= 70) return const Color(0xFFDC2626);
      if (hotPercentage >= 50) return const Color(0xFFEA580C);
      if (hotPercentage >= 35) return const Color(0xFFD97706);
      return const Color(0xFF0891B2);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _flareController,
        _scoreBounceController,
        _feedbackController,
      ]),
      builder: (context, child) {
        final pulseVal = _pulseController.value;
        final flareVal = _flareController.value;
        final scoreBounceVal = _scoreBounceController.value;
        final feedbackVal = _feedbackController.value;

        final scoreScale = 1.0 + (scoreBounceVal > 0 ? (1.0 - (scoreBounceVal - 0.5).abs() * 2) * 0.22 : 0.0);

        // ─── 1. ASYMMETRIC TEMPERATURE SPECTRUM GRADIENT ──────────────
        // Derece oranına (0° -> 100°) ve kullanıcının kişisel oylama katkısına göre hesaplanır:
        final Gradient outerGradient;
        final Gradient outerBorderGradient;
        final Color outerShadowColor;

        if (totalVotes == 0) {
          // Durum 0: Henüz hiç oy yok (Nötr Satin Yüzey)
          outerGradient = isDark
              ? const LinearGradient(
                  colors: [AppTheme.darkSurfaceElevated, AppTheme.darkSurface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Colors.white, Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                );

          outerBorderGradient = isDark
              ? const LinearGradient(
                  colors: [AppTheme.darkBorder, AppTheme.darkBorder],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFE2E8F0), Color(0xFFE2E8F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                );

          outerShadowColor = Colors.black.withValues(alpha: isDark ? 0.22 : 0.04);
        } else if (hotPercentage >= 75) {
          // Durum 1: Çok Sıcak / Efsane Fırsat (75° - 100°)
          // Kullanıcı da AL dediyse ("Supercharged Ember Mode" -> renkler ve parlaklık ekstra derinleşir!)
          outerGradient = isDark
              ? (isHotActive
                  ? const LinearGradient(
                      colors: [Color(0xFF14171C), Color(0xFF261811), Color(0xFF3B1A10)],
                      stops: [0.0, 0.40, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF14171C), Color(0xFF1F1612), Color(0xFF2E150D)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ))
              : (isHotActive
                  ? const LinearGradient(
                      colors: [Color(0xFFFFFDFB), Color(0xFFFFECE0), Color(0xFFFFD4BE)],
                      stops: [0.0, 0.40, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFFFDFB), Color(0xFFFFF4EC), Color(0xFFFFE6D6)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ));

          outerBorderGradient = isDark
              ? (isHotActive
                  ? const LinearGradient(
                      colors: [AppTheme.darkBorder, Color(0xFFB45309), Color(0xFFFF7A45)],
                      stops: [0.0, 0.40, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [AppTheme.darkBorder, Color(0xFF9A3412), Color(0xFFFF7A45)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ))
              : (isHotActive
                  ? const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Color(0xFFFDBA74), Color(0xFFDC2626)],
                      stops: [0.0, 0.40, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Color(0xFFFED7AA), Color(0xFFEA580C)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ));

          outerShadowColor = isHotActive
              ? (isDark ? const Color(0xFFFF5722).withValues(alpha: 0.38) : const Color(0xFFFF6B35).withValues(alpha: 0.22))
              : (isDark ? const Color(0xFFFF5722).withValues(alpha: 0.26) : const Color(0xFFFF6B35).withValues(alpha: 0.14));
        } else if (hotPercentage >= 58) {
          // Durum 2: Sıcak Bakılıyor (58° - 74°)
          outerGradient = isDark
              ? (isHotActive
                  ? const LinearGradient(
                      colors: [Color(0xFF14171C), Color(0xFF1F1813), Color(0xFF301D14)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF14171C), Color(0xFF1A1715), Color(0xFF261912)],
                      stops: [0.0, 0.50, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ))
              : (isHotActive
                  ? const LinearGradient(
                      colors: [Color(0xFFFFFDFB), Color(0xFFFFF1E6), Color(0xFFFFE0CC)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFFFDFB), Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                      stops: [0.0, 0.50, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ));

          outerBorderGradient = isDark
              ? (isHotActive
                  ? const LinearGradient(
                      colors: [AppTheme.darkBorder, Color(0xFF9A3412), Color(0xFFFB923C)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [AppTheme.darkBorder, Color(0xFF78350F), Color(0xFFFB923C)],
                      stops: [0.0, 0.50, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ))
              : (isHotActive
                  ? const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Color(0xFFFDBA74), Color(0xFFEA580C)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Color(0xFFFFEDD5), Color(0xFFF97316)],
                      stops: [0.0, 0.50, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ));

          outerShadowColor = isHotActive
              ? (isDark ? const Color(0xFFEA580C).withValues(alpha: 0.32) : const Color(0xFFF97316).withValues(alpha: 0.18))
              : (isDark ? const Color(0xFFEA580C).withValues(alpha: 0.22) : const Color(0xFFF97316).withValues(alpha: 0.12));
        } else if (hotPercentage >= 42) {
          // Durum 3: Kafa Kafaya / Dengeli (42° - 57°, örn %50)
          outerGradient = isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0B1E2D), Color(0xFF15181E), Color(0xFF241812)],
                  stops: [0.0, 0.50, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFEFF8FE), Color(0xFFFCFDFE), Color(0xFFFFF7ED)],
                  stops: [0.0, 0.50, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                );

          outerBorderGradient = isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0369A1), AppTheme.darkBorder, Color(0xFFC2410C)],
                  stops: [0.0, 0.50, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF7DD3FC), Color(0xFFE2E8F0), Color(0xFFFDBA74)],
                  stops: [0.0, 0.50, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                );

          outerShadowColor = (isHotActive || isColdActive)
              ? (isDark ? Colors.black.withValues(alpha: 0.32) : const Color(0xFFD97706).withValues(alpha: 0.16))
              : (isDark ? Colors.black.withValues(alpha: 0.22) : const Color(0xFFD97706).withValues(alpha: 0.10));
        } else if (hotPercentage >= 25) {
          // Durum 4: Soğuk / Tartışmalı (25° - 41°)
          outerGradient = isDark
              ? (isColdActive
                  ? const LinearGradient(
                      colors: [Color(0xFF0B2E47), Color(0xFF0E2230), Color(0xFF14171C)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF082236), Color(0xFF0F1B25), Color(0xFF14171C)],
                      stops: [0.0, 0.50, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ))
              : (isColdActive
                  ? const LinearGradient(
                      colors: [Color(0xFFBAE6FD), Color(0xFFE0F2FE), Color(0xFFFFFDFB)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF), Color(0xFFFFFDFB)],
                      stops: [0.0, 0.50, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ));

          outerBorderGradient = isDark
              ? (isColdActive
                  ? const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1), AppTheme.darkBorder],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF075985), AppTheme.darkBorder],
                      stops: [0.0, 0.50, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ))
              : (isColdActive
                  ? const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF7DD3FC), Color(0xFFE2E8F0)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFFBAE6FD), Color(0xFFE2E8F0)],
                      stops: [0.0, 0.50, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ));

          outerShadowColor = isColdActive
              ? (isDark ? const Color(0xFF0284C7).withValues(alpha: 0.32) : const Color(0xFF0284C7).withValues(alpha: 0.18))
              : (isDark ? const Color(0xFF0284C7).withValues(alpha: 0.22) : const Color(0xFF0284C7).withValues(alpha: 0.12));
        } else {
          // Durum 5: Çok Soğuk / Kutup Ayazı (0° - 24°)
          // Kullanıcı da GEÇ dediyse ("Supercharged Glacial Mode" -> kristal buz mavisi ekstra derinleşir ve parlar!)
          outerGradient = isDark
              ? (isColdActive
                  ? const LinearGradient(
                      colors: [Color(0xFF083344), Color(0xFF0A2B40), Color(0xFF14171C)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF08263D), Color(0xFF0B1D2B), Color(0xFF14171C)],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ))
              : (isColdActive
                  ? const LinearGradient(
                      colors: [Color(0xFFA5F3FC), Color(0xFFCFFAFE), Color(0xFFF8FAFC)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFBAE6FD), Color(0xFFE0F2FE), Color(0xFFF8FAFC)],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ));

          outerBorderGradient = isDark
              ? (isColdActive
                  ? const LinearGradient(
                      colors: [Color(0xFF22D3EE), Color(0xFF0891B2), AppTheme.darkBorder],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF22D3EE), Color(0xFF0369A1), AppTheme.darkBorder],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ))
              : (isColdActive
                  ? const LinearGradient(
                      colors: [Color(0xFF0891B2), Color(0xFF67E8F9), Color(0xFFE2E8F0)],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF7DD3FC), Color(0xFFE2E8F0)],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ));

          outerShadowColor = isColdActive
              ? (isDark ? const Color(0xFF06B6D4).withValues(alpha: 0.38) : const Color(0xFF0891B2).withValues(alpha: 0.22))
              : (isDark ? const Color(0xFF06B6D4).withValues(alpha: 0.26) : const Color(0xFF0891B2).withValues(alpha: 0.14));
        }

        final double outerBorderWidth = (isHotActive || isColdActive) ? 1.5 : 1.1;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(outerBorderWidth),
          decoration: BoxDecoration(
            gradient: outerBorderGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: outerShadowColor,
                blurRadius: (isHotActive || isColdActive) ? 18 : 10,
                offset: const Offset(0, 3.5),
              ),
            ],
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: outerGradient,
              borderRadius: BorderRadius.circular(18 - outerBorderWidth),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── 1. TOP STATUS PILL (CONSENSUS BADGE) ─────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Container(
                    key: ValueKey<String>(statusText),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? statusAccent.withValues(alpha: 0.18)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? statusAccent.withValues(alpha: 0.45)
                            : statusAccent.withValues(alpha: 0.38),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.20)
                              : statusAccent.withValues(alpha: 0.12),
                          blurRadius: 5,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statusEmoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 5.5),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : statusAccent,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ─── 2. MAIN INTERACTIVE VOTING ROW ───────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ─── SOĞUK TARAF (GEÇ) BUTONU ─────────────────────
                    ScaleTransition(
                      scale: _coldScaleController,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onVoteTap(false),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            width: 58,
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              gradient: isColdActive
                                  ? (isDark
                                      ? const LinearGradient(
                                          colors: [Color(0xFF155E75), Color(0xFF083344)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : const LinearGradient(
                                          colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ))
                                  : null,
                              color: isColdActive
                                  ? null
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: isColdActive
                                    ? (isDark
                                        ? const Color(0xFF22D3EE).withValues(alpha: 0.55)
                                        : const Color(0xFF67E8F9).withValues(alpha: 0.90))
                                    : (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFCBD5E1)),
                                width: isColdActive ? 1.3 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isColdActive
                                      ? (isDark
                                          ? const Color(0xFF06B6D4).withValues(alpha: 0.28)
                                          : const Color(0xFF0891B2).withValues(alpha: 0.24))
                                      : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                  blurRadius: isColdActive ? 7 : 3,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isColdActive)
                                  const Icon(
                                    Icons.ac_unit_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  )
                                else
                                  const Text(
                                    '🥶',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                const SizedBox(height: 2.5),
                                Text(
                                  'GEÇ',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: isColdActive
                                        ? (isDark ? const Color(0xFFE0F7FA) : Colors.white)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ─── CENTER: TEMPERATURE GAUGE & HERO METRICS ─────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Sıcaklık Hero Skoru & Floating Impact Feedback
                            Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Transform.scale(
                                  scale: scoreScale,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        totalVotes > 0 ? '$hotPercentage' : '—',
                                        style: TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w900,
                                          color: getThermometerScoreColor(),
                                          letterSpacing: -0.6,
                                          height: 1.0,
                                          shadows: totalVotes > 0 && (isHotActive || isColdActive)
                                              ? [
                                                  Shadow(
                                                    color: getThermometerScoreColor().withValues(alpha: 0.40 * pulseVal),
                                                    blurRadius: 10,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                      if (totalVotes > 0)
                                        Text(
                                          '°',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: getThermometerScoreColor(),
                                            height: 1.0,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Floating Energy Impact Bubble
                                if (feedbackVal > 0.0 && feedbackVal < 1.0)
                                  Positioned(
                                    top: -19.0 * feedbackVal,
                                    child: Opacity(
                                      opacity: (1.0 - feedbackVal).clamp(0.0, 1.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: _feedbackColor,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _feedbackColor.withValues(alpha: 0.45),
                                              blurRadius: 6,
                                              offset: const Offset(0, 1.5),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _feedbackText,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // 2. Continuous Spectral Thermal Progress Bar
                            Container(
                              height: 9,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                                  width: 0.6,
                                ),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final fillWidth = totalVotes > 0
                                      ? constraints.maxWidth * (hotPercentage / 100).clamp(0.0, 1.0)
                                      : constraints.maxWidth * 0.5;

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // 1. Ana Renk Barı (Continuous Thermal Spectrum)
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        width: fillWidth,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: totalVotes > 0
                                                ? (hotPercentage >= 70
                                                    ? const [Color(0xFFFF8E53), Color(0xFFFF5722), Color(0xFFDC2626)]
                                                    : (hotPercentage >= 40
                                                        ? const [Color(0xFF06B6D4), Color(0xFFF59E0B), Color(0xFFEA580C)]
                                                        : const [Color(0xFF0284C7), Color(0xFF06B6D4)]))
                                                : [Colors.grey.shade400, Colors.grey.shade400],
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: totalVotes > 0
                                              ? [
                                                  BoxShadow(
                                                    color: getThermometerScoreColor().withValues(alpha: 0.35),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),

                                      // 2. Kinetic Shimmer Flare Sweep
                                      if (flareVal > 0.0 && flareVal < 1.0 && fillWidth > 10)
                                        Positioned(
                                          left: (fillWidth + 30) * flareVal - 30,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 32,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.0),
                                                  Colors.white.withValues(alpha: 0.85),
                                                  Colors.white.withValues(alpha: 0.0),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 5.5),

                            // 3. Toplam Oy Sayısı & Consensus Subtitle
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                              child: Text(
                                '$totalVotes Değerlendirme',
                                key: ValueKey<int>(totalVotes),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── SICAK TARAF (AL!) BUTONU ─────────────────────
                    ScaleTransition(
                      scale: _hotScaleController,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onVoteTap(true),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            width: 58,
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              gradient: isHotActive
                                  ? (isDark
                                      ? const LinearGradient(
                                          colors: [Color(0xFF9A3412), Color(0xFF881337)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : const LinearGradient(
                                          colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ))
                                  : null,
                              color: isHotActive
                                  ? null
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: isHotActive
                                    ? (isDark
                                        ? const Color(0xFFFB923C).withValues(alpha: 0.55)
                                        : const Color(0xFFFDBA74).withValues(alpha: 0.90))
                                    : (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFCBD5E1)),
                                width: isHotActive ? 1.3 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isHotActive
                                      ? (isDark
                                          ? const Color(0xFFEA580C).withValues(alpha: 0.28)
                                          : const Color(0xFFDC2626).withValues(alpha: 0.24))
                                      : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                  blurRadius: isHotActive ? 7 : 3,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isHotActive)
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 17.5,
                                    color: Colors.white,
                                  )
                                else
                                  const Text(
                                    '🔥',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                const SizedBox(height: 2.5),
                                Text(
                                  'AL!',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: isHotActive
                                        ? (isDark ? const Color(0xFFFFEDD5) : Colors.white)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                    letterSpacing: 0.3,
                                  ),
                                ),
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
        );
      },
    );
  }
}
