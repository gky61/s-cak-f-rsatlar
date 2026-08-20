import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deal.dart';
import '../theme/app_theme.dart';

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

    // 1. Ambient breathing pulse for active button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 2. Flare / Shimmer sweep wave along the progress bar
    _flareController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // 3. Score bounce spring
    _scoreBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // 4. Hot & Cold button tap bounce
    _hotScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );

    _coldScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );

    // 5. Floating feedback micro-badge (+1 AL! / +1 GEÇ)
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(DealThermometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTotalVotes = widget.hotVotes + widget.coldVotes;
    if (newTotalVotes != _lastTotalVotes ||
        widget.hasVotedHot != oldWidget.hasVotedHot ||
        widget.hasVotedCold != oldWidget.hasVotedCold) {
      _lastTotalVotes = newTotalVotes;
      _triggerEnergyImpact(widget.hasVotedHot ? true : (widget.hasVotedCold ? false : null));
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

  void _triggerEnergyImpact(bool? isHot) {
    _flareController.forward(from: 0.0);
    _scoreBounceController.forward(from: 0.0);

    if (isHot != null) {
      setState(() {
        _feedbackText = isHot ? '+1 AL! 🔥' : '+1 GEÇ 🥶';
        _feedbackColor = isHot ? const Color(0xFFFF5722) : const Color(0xFF0284C7);
      });
      _feedbackController.forward(from: 0.0);
    }
  }

  void _onVoteTap(bool isHot) {
    HapticFeedback.lightImpact();

    // Trigger instant tactile button bounce
    if (isHot) {
      _hotScaleController.reverse().then((_) => _hotScaleController.forward());
    } else {
      _coldScaleController.reverse().then((_) => _coldScaleController.forward());
    }

    _triggerEnergyImpact(isHot);
    widget.onVote(isHot);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentHotVotes = widget.hotVotes;
    final currentColdVotes = widget.coldVotes;
    final totalVotes = currentHotVotes + currentColdVotes;

    final hotPercentage = totalVotes > 0 ? (currentHotVotes / totalVotes * 100).round() : 50;

    String getMessage() {
      if (totalVotes == 0) return 'İlk değerlendirmeyi sen yap! 🎯';
      if (hotPercentage >= 80) return 'EFSANE FIRSAT! Bu fiyat kaçmaz 🔥🚀';
      if (hotPercentage >= 60) return 'Sıcak Bakılıyor! Topluluk sevdi 👍';
      if (hotPercentage >= 40) return 'Kafa Kafaya! Karar senin ⚖️';
      if (hotPercentage >= 20) return 'Pek Tutulmadı! Fiyat tartışılır 🧐';
      return 'Param cebimde kalsın 💸';
    }

    Color getThermometerColor() {
      if (totalVotes == 0) return isDark ? Colors.grey[400]! : Colors.grey[600]!;
      if (hotPercentage >= 70) return const Color(0xFFFF5722);
      if (hotPercentage >= 50) return const Color(0xFFF59E0B);
      if (hotPercentage >= 30) return const Color(0xFFEAB308);
      return const Color(0xFF0284C7);
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

        // Bouncy score scale: 1.0 -> 1.25 -> 1.0
        final scoreScale = 1.0 + (scoreBounceVal > 0 ? (1.0 - (scoreBounceVal - 0.5).abs() * 2) * 0.22 : 0.0);

        // Cold (GEÇ) Styling
        final isColdActive = widget.hasVotedCold;

        // Hot (AL!) Styling
        final isHotActive = widget.hasVotedHot;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2.5),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Topluluk Mesajı (Animated Crossfade)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: Text(
                  getMessage(),
                  key: ValueKey<String>(getMessage()),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 11),

              // 2. Termometre Oylama Satırı
              Row(
                children: [
                  // ─── SOĞUK TARAF (GEÇ) BUTONU ───────────────────────
                  ScaleTransition(
                    scale: _coldScaleController,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onVoteTap(false),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: 54,
                          padding: const EdgeInsets.symmetric(vertical: 6.5),
                          decoration: BoxDecoration(
                            gradient: isColdActive
                                ? const LinearGradient(
                                    colors: [Color(0xFF0284C7), Color(0xFF0891B2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isColdActive
                                ? null
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isColdActive
                                  ? const Color(0xFF38BDF8)
                                  : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
                              width: isColdActive ? 1.3 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isColdActive
                                    ? const Color(0xFF0284C7).withValues(alpha: 0.35 + 0.15 * pulseVal)
                                    : Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                                blurRadius: isColdActive ? 8 : 3.5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🥶',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'GEÇ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: isColdActive
                                      ? Colors.white
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ─── TERMOMETRE ORTA BAR & DERECE ───────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sıcaklık Skoru & Floating Feedback Bubble
                          Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Derece Skoru (Spring Bounce Animasyonlu)
                              Transform.scale(
                                scale: scoreScale,
                                child: Text(
                                  totalVotes > 0 ? '$hotPercentage°' : '—',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: getThermometerColor(),
                                    letterSpacing: -0.5,
                                    shadows: totalVotes > 0 && (isHotActive || isColdActive)
                                        ? [
                                            Shadow(
                                              color: getThermometerColor().withValues(alpha: 0.45 * pulseVal),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),

                              // Floating "+1 AL! 🔥" / "+1 GEÇ 🥶" feedback pill
                              if (feedbackVal > 0.0 && feedbackVal < 1.0)
                                Positioned(
                                  top: -18.0 * feedbackVal,
                                  child: Opacity(
                                    opacity: (1.0 - feedbackVal).clamp(0.0, 1.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _feedbackColor,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _feedbackColor.withValues(alpha: 0.4),
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
                          const SizedBox(height: 5),

                          // İlerleme Çubuğu (Capsule Track + Dynamic Shimmer Flare)
                          Container(
                            height: 8.5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final fillWidth = totalVotes > 0
                                    ? constraints.maxWidth * (hotPercentage / 100).clamp(0.0, 1.0)
                                    : constraints.maxWidth * 0.5;

                                return Stack(
                                  children: [
                                    // 1. Ana Renk Barı (Smooth Width Animation)
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
                                                      ? const [Color(0xFF06B6D4), Color(0xFFF59E0B), Color(0xFFFF6B35)]
                                                      : const [Color(0xFF0284C7), Color(0xFF06B6D4)]))
                                              : [Colors.grey.shade400, Colors.grey.shade400],
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                        boxShadow: totalVotes > 0
                                            ? [
                                                BoxShadow(
                                                  color: getThermometerColor().withValues(alpha: 0.35),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),

                                    // 2. Kinetic Energy Shimmer Flare Sweep (Oylama anında geçen ışık dalgası)
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
                                                Colors.white.withValues(alpha: 0.8),
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
                          const SizedBox(height: 4.5),

                          // Toplam Oy Sayısı (Smooth Number Fade)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                            child: Text(
                              '$totalVotes oy',
                              key: ValueKey<int>(totalVotes),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── SICAK TARAF (AL!) BUTONU ───────────────────────
                  ScaleTransition(
                    scale: _hotScaleController,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onVoteTap(true),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: 54,
                          padding: const EdgeInsets.symmetric(vertical: 6.5),
                          decoration: BoxDecoration(
                            gradient: isHotActive
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isHotActive
                                ? null
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isHotActive
                                  ? const Color(0xFFFF8E53)
                                  : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
                              width: isHotActive ? 1.3 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isHotActive
                                    ? const Color(0xFFFF5722).withValues(alpha: 0.35 + 0.15 * pulseVal)
                                    : Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                                blurRadius: isHotActive ? 8 : 3.5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🔥',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'AL!',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: isHotActive
                                      ? Colors.white
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
        );
      },
    );
  }
}
