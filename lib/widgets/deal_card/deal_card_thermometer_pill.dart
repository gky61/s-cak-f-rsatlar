import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/deal.dart';

/// Fırsat detayındaki DealThermometer bileşeninin modern, termal ve canlı
/// oylama hissiyatını kart vitrinine taşıyan ultra-modern, minimalist cam kapsül (HUD Pill).
class DealCardThermometerPill extends StatefulWidget {
  final Deal deal;
  final bool isDark;
  final bool compact;

  const DealCardThermometerPill({
    super.key,
    required this.deal,
    required this.isDark,
    this.compact = false,
  });

  @override
  State<DealCardThermometerPill> createState() => _DealCardThermometerPillState();
}

class _DealCardThermometerPillState extends State<DealCardThermometerPill>
    with SingleTickerProviderStateMixin {
  bool _showBreakdown = false;
  Timer? _revertTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Sıcaklık aurası için zarif, canlı nefes alan mikro nabız animasyonu
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _revertTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _revertTimer?.cancel();

    setState(() {
      _showBreakdown = true;
    });

    _revertTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showBreakdown = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deals')
          .doc(widget.deal.id)
          .snapshots(),
      builder: (context, snapshot) {
        int hotVotes = widget.deal.hotVotes;
        int coldVotes = widget.deal.coldVotes;

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            hotVotes = (data['hotVotes'] as num?)?.toInt() ?? widget.deal.hotVotes;
            coldVotes = (data['coldVotes'] as num?)?.toInt() ?? widget.deal.coldVotes;
          }
        }

        final int totalVotes = hotVotes + coldVotes;
        if (totalVotes == 0) return const SizedBox.shrink();

        final int hotPercentage = (hotVotes / totalVotes * 100).round().clamp(0, 100);

        // ─── TERMAL SKALA & DİNAMİK TASARIM PALETİ ──────────────────────────
        final Color primaryAccent;
        final Color secondaryAccent;
        final List<Color> iconGradient;
        final IconData iconData;
        final Color glowColor;

        if (hotPercentage >= 75) {
          // Efsane / Çok Sıcak (75° - 100°)
          primaryAccent = const Color(0xFFFF3D00); // Yoğun Alev Kırmızısı
          secondaryAccent = const Color(0xFFFF9100); // Parlak Kehribar
          iconGradient = const [Color(0xFFFF7A00), Color(0xFFDD2C00)];
          iconData = Icons.local_fire_department_rounded;
          glowColor = const Color(0xFFFF3D00);
        } else if (hotPercentage >= 58) {
          // Sıcak Bakılıyor (58° - 74°)
          primaryAccent = const Color(0xFFFF6D00); // Sıcak Turuncu
          secondaryAccent = const Color(0xFFFFAB00); // Güneş Sarısı
          iconGradient = const [Color(0xFFFF9E1B), Color(0xFFE65100)];
          iconData = Icons.local_fire_department_rounded;
          glowColor = const Color(0xFFFF6D00);
        } else if (hotPercentage >= 42) {
          // Kafa Kafaya / Dengeli (42° - 57°)
          primaryAccent = const Color(0xFFF59E0B); // Denge Kehribarı
          secondaryAccent = const Color(0xFF0EA5E9); // Gökyüzü Mavisi
          iconGradient = const [Color(0xFFF59E0B), Color(0xFF0284C7)];
          iconData = Icons.balance_rounded;
          glowColor = const Color(0xFFF59E0B);
        } else if (hotPercentage >= 25) {
          // Soğuk / Tartışmalı (25° - 41°)
          primaryAccent = const Color(0xFF0284C7); // Okyanus Mavisi
          secondaryAccent = const Color(0xFF38BDF8); // Açık Buzul
          iconGradient = const [Color(0xFF38BDF8), Color(0xFF0284C7)];
          iconData = Icons.ac_unit_rounded;
          glowColor = const Color(0xFF0284C7);
        } else {
          // Kutup Ayazı / Çok Soğuk (0° - 24°)
          primaryAccent = const Color(0xFF06B6D4); // Polar Cyan
          secondaryAccent = const Color(0xFF67E8F9); // Kristal Buz
          iconGradient = const [Color(0xFF67E8F9), Color(0xFF0891B2)];
          iconData = Icons.ac_unit_rounded;
          glowColor = const Color(0xFF06B6D4);
        }

        // Cam efektli zemin ve sınır renkleri
        final Color pillBackground = isDark
            ? const Color(0xFF0C0E14).withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.90);

        final Color pillBorderColor = isDark
            ? primaryAccent.withValues(alpha: 0.38)
            : primaryAccent.withValues(alpha: 0.30);

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulse = _pulseController.value;

            return GestureDetector(
              onTap: _handleTap,
              behavior: HitTestBehavior.opaque,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 5.5 : 7,
                      vertical: widget.compact ? 2.5 : 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: pillBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: pillBorderColor,
                        width: 0.9,
                      ),
                      boxShadow: [
                        // Nefes alan renkli termal aura
                        BoxShadow(
                          color: glowColor.withValues(
                            alpha: isDark ? (0.22 + 0.14 * pulse) : (0.14 + 0.10 * pulse),
                          ),
                          blurRadius: 7 + (3 * pulse),
                          spreadRadius: 0.2,
                          offset: const Offset(0, 1.5),
                        ),
                        // Kontrast derinlik gölgesi
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _showBreakdown
                            // ─── DOKUNULDUĞUNDA: ŞIK OY DAĞILIM PANELLİ ──────────
                            ? Row(
                                key: const ValueKey('breakdown'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Sıcak Oylar
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: widget.compact ? 9.5 : 11,
                                        color: const Color(0xFFFF5722),
                                      ),
                                      const SizedBox(width: 1.5),
                                      Text(
                                        '$hotVotes',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          fontSize: widget.compact ? 8.5 : 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Ayrıcı Çizgi
                                  Container(
                                    width: 1,
                                    height: widget.compact ? 7 : 8,
                                    margin: EdgeInsets.symmetric(horizontal: widget.compact ? 3.5 : 5),
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : Colors.black.withValues(alpha: 0.15),
                                  ),
                                  // Soğuk Oylar
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.ac_unit_rounded,
                                        size: widget.compact ? 9 : 10,
                                        color: const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 1.5),
                                      Text(
                                        '$coldVotes',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          fontSize: widget.compact ? 8.5 : 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            // ─── VARSAYILAN: MİKRO TERMOMETRE VE DERECE KAPSÜLÜ ──
                            : Row(
                                key: const ValueKey('gauge'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 1. Parlayan Dairesel İkon Ampulü (Bulb)
                                  Container(
                                    width: widget.compact ? 13 : 15,
                                    height: widget.compact ? 13 : 15,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: iconGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryAccent.withValues(alpha: 0.45),
                                          blurRadius: 3.5,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        iconData,
                                        size: widget.compact ? 8 : 9.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: widget.compact ? 3.5 : 4.5),

                                  // 2. Derece Tipografisi (Hero Degree)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$hotPercentage',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          fontSize: widget.compact ? 9.5 : 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                          height: 1.1,
                                        ),
                                      ),
                                      Text(
                                        '°',
                                        style: TextStyle(
                                          color: primaryAccent,
                                          fontSize: widget.compact ? 9.5 : 10.5,
                                          fontWeight: FontWeight.w900,
                                          height: 0.9,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: widget.compact ? 4 : 5),

                                  // 3. Mikro Termometre Cıva Tüpü (Glass Mercury Tube)
                                  Container(
                                    width: widget.compact ? 15 : 20,
                                    height: widget.compact ? 3 : 3.5,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : Colors.black.withValues(alpha: 0.04),
                                        width: 0.5,
                                      ),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: (hotPercentage / 100).clamp(0.08, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          gradient: LinearGradient(
                                            colors: [
                                              secondaryAccent,
                                              primaryAccent,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryAccent.withValues(alpha: 0.65),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
