import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deal.dart';

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

        // Cold (GEÇ) styling
        final isColdActive = widget.hasVotedCold;
        final coldBg = isColdActive
            ? (isDark
                ? const Color(0xFF0891B2).withValues(alpha: 0.25 + 0.08 * pulseVal)
                : const Color(0xFFE0F7FA).withValues(alpha: 0.95))
            : (isDark ? Colors.white.withValues(alpha: 0.035) : Colors.white);
        final coldBorder = isColdActive
            ? const Color(0xFF06B6D4).withValues(alpha: 0.7 + 0.3 * pulseVal)
            : (isDark ? Colors.white.withValues(alpha: 0.09) : const Color(0xFFE2E8F0));
        final coldTextColor = isColdActive
            ? const Color(0xFF0284C7)
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

        // Hot (AL!) styling
        final isHotActive = widget.hasVotedHot;
        final hotBg = isHotActive
            ? (isDark
                ? const Color(0xFFEA580C).withValues(alpha: 0.25 + 0.08 * pulseVal)
                : const Color(0xFFFFF1EB).withValues(alpha: 0.95))
            : (isDark ? Colors.white.withValues(alpha: 0.035) : Colors.white);
        final hotBorder = isHotActive
            ? const Color(0xFFFF5722).withValues(alpha: 0.7 + 0.3 * pulseVal)
            : (isDark ? Colors.white.withValues(alpha: 0.09) : const Color(0xFFE2E8F0));
        final hotTextColor = isHotActive
            ? const Color(0xFFEA580C)
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.035) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              width: 0.85,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Topluluk Mesajı
              Text(
                getMessage(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              
              // Termometre Oylama Satırı
              Row(
                children: [
                  // Soğuk taraf (Geç)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onVoteTap(false),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: coldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: coldBorder,
                            width: isColdActive ? 1.2 : 0.85,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isColdActive
                                  ? const Color(0xFF06B6D4).withValues(alpha: 0.25 + 0.1 * pulseVal)
                                  : Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                              blurRadius: isColdActive ? 6 : 3,
                              offset: const Offset(0, 1.5),
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
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: coldTextColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Termometre Orta Bar
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sıcaklık Skoru
                          Text(
                            totalVotes > 0 ? '$hotPercentage°' : '—',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: getThermometerColor(),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          // İlerleme Çubuğu (Capsule Track)
                          Container(
                            height: 6.5,
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.08) 
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 350),
                                      curve: Curves.easeOutCubic,
                                      width: totalVotes > 0 
                                          ? constraints.maxWidth * (hotPercentage / 100).clamp(0.0, 1.0)
                                          : constraints.maxWidth * 0.5,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: totalVotes > 0
                                              ? const [Color(0xFF06B6D4), Color(0xFFF59E0B), Color(0xFFEF4444)]
                                              : [Colors.grey.shade400, Colors.grey.shade400],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Toplam Oy Sayısı
                          Text(
                            '$totalVotes oy',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Sıcak taraf (Al!)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onVoteTap(true),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: hotBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hotBorder,
                            width: isHotActive ? 1.2 : 0.85,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isHotActive
                                  ? const Color(0xFFFF5722).withValues(alpha: 0.25 + 0.1 * pulseVal)
                                  : Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                              blurRadius: isHotActive ? 6 : 3,
                              offset: const Offset(0, 1.5),
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
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: hotTextColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
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
