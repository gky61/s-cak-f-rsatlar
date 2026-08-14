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

class _DealThermometerState extends State<DealThermometer> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onVoteTap(bool isHot) {
    HapticFeedback.mediumImpact();
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
      if (hotPercentage >= 70) return Colors.redAccent;
      if (hotPercentage >= 50) return Colors.orangeAccent;
      if (hotPercentage >= 30) return Colors.amber;
      return Colors.cyan;
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseVal = _pulseController.value;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Eğlenceli mesaj
              Text(
                getMessage(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              
              // Termometre bar'ı
              Row(
                children: [
                  // Soğuk taraf (Geç)
                  GestureDetector(
                    onTap: () => _onVoteTap(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.hasVotedCold 
                            ? Colors.cyan[700]!.withValues(alpha: 0.85 + 0.1 * pulseVal) 
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.hasVotedCold 
                              ? Color.lerp(Colors.cyanAccent, Colors.white, pulseVal)!
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1)),
                          width: widget.hasVotedCold ? 1.5 : 1,
                        ),
                        boxShadow: widget.hasVotedCold
                            ? [
                                BoxShadow(
                                  color: Colors.cyan.withValues(alpha: 0.45 + 0.25 * pulseVal),
                                  blurRadius: 6 + 6 * pulseVal,
                                  spreadRadius: 1 + 1.5 * pulseVal,
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: widget.hasVotedCold 
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  )
                                : const BoxDecoration(),
                            child: Text(
                              '🥶',
                              style: TextStyle(
                                fontSize: 18,
                                shadows: widget.hasVotedCold 
                                    ? [
                                        const Shadow(color: Colors.white, blurRadius: 8),
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'GEÇ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: widget.hasVotedCold ? Colors.white : (isDark ? Colors.grey[400] : Colors.blue[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Termometre Orta Bar
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Skor gösterimi
                          Text(
                            totalVotes > 0 ? '$hotPercentage°' : '—',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: getThermometerColor(),
                              shadows: totalVotes > 0 ? [
                                Shadow(
                                  color: getThermometerColor().withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ] : [],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Bar
                          Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    // Doluluk
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 500),
                                      curve: Curves.easeOutCubic,
                                      width: constraints.maxWidth * (hotPercentage / 100),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Colors.amber, Colors.orange, Colors.red],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(alpha: 0.4),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Oy sayısı
                          Text(
                            '$totalVotes oy',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Sıcak taraf (Al!)
                  GestureDetector(
                    onTap: () => _onVoteTap(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.hasVotedHot 
                            ? Colors.deepOrange[600]!.withValues(alpha: 0.85 + 0.1 * pulseVal) 
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.hasVotedHot 
                              ? Color.lerp(Colors.orangeAccent, Colors.white, pulseVal)!
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1)),
                          width: widget.hasVotedHot ? 1.5 : 1,
                        ),
                        boxShadow: widget.hasVotedHot
                            ? [
                                BoxShadow(
                                  color: Colors.deepOrange.withValues(alpha: 0.45 + 0.25 * pulseVal),
                                  blurRadius: 6 + 6 * pulseVal,
                                  spreadRadius: 1 + 1.5 * pulseVal,
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: widget.hasVotedHot 
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  )
                                : const BoxDecoration(),
                            child: Text(
                              '🔥',
                              style: TextStyle(
                                fontSize: 18,
                                shadows: widget.hasVotedHot 
                                    ? [
                                        const Shadow(color: Colors.white, blurRadius: 8),
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AL!',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: widget.hasVotedHot ? Colors.white : Colors.red[400],
                            ),
                          ),
                        ],
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
