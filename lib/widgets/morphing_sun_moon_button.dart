import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Ultra-minimalist, fluid Morphing Sun-to-Moon icon button.
/// Continuous single-canvas vector metamorphosis:
/// - Light Mode: Iconic Black Moon crescent pointing diagonally top-left (sola yukarı doğru).
/// - Dark Mode: Crisp White Sun with 8 radiating micro-rays.
/// - Transition: Visible fluid 180° spin where rays retract/expand and the crescent shadow carves the body.
class MorphingSunMoonButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;
  final GlobalKey? buttonKey;
  final double size;
  final Duration duration;
  final Curve curve;
  final Color? sunColor;
  final Color? moonColor;
  final String? tooltip;

  const MorphingSunMoonButton({
    super.key,
    required this.isDark,
    required this.onTap,
    this.buttonKey,
    this.size = 40.0,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeInOutCubic,
    this.sunColor,
    this.moonColor,
    this.tooltip,
  });

  @override
  State<MorphingSunMoonButton> createState() => _MorphingSunMoonButtonState();
}

class _MorphingSunMoonButtonState extends State<MorphingSunMoonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 0.0 = Sun (White, in Dark mode)
    // 1.0 = Moon (Black, in Light mode)
    final initialValue = widget.isDark ? 0.0 : 1.0;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: initialValue,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
  }

  @override
  void didUpdateWidget(covariant MorphingSunMoonButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      if (widget.isDark) {
        // Switching to Dark mode: Icon morphs from Black Moon (1.0) to White Sun (0.0)
        _controller.animateTo(0.0, duration: widget.duration, curve: widget.curve);
      } else {
        // Switching to Light mode: Icon morphs from White Sun (0.0) to Black Moon (1.0)
        _controller.animateTo(1.0, duration: widget.duration, curve: widget.curve);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sunC = widget.sunColor ?? const Color(0xFFFFFFFF);
    final moonC = widget.moonColor ?? const Color(0xFF0F172A);

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: widget.tooltip ??
            (widget.isDark ? 'Aydınlık Moda Geç' : 'Karanlık Moda Geç'),
        child: InkWell(
          key: widget.buttonKey,
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.size / 2),
          splashColor: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          highlightColor: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(22, 22),
                    painter: _MorphingSunMoonPainter(
                      progress: _animation.value,
                      sunColor: sunC,
                      moonColor: moonC,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that renders continuous vector metamorphosis between Sun and Moon.
/// 0.0 = Crisp White Sun with 8 radiating micro-rays
/// 1.0 = Crisp Black Crescent Moon pointing diagonally top-left
class _MorphingSunMoonPainter extends CustomPainter {
  final double progress; // 0.0 = Sun, 1.0 = Moon
  final Color sunColor;
  final Color moonColor;

  _MorphingSunMoonPainter({
    required this.progress,
    required this.sunColor,
    required this.moonColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);

    // 1. Dynamic color interpolation (White in Dark mode <-> Black in Light mode)
    final bodyColor = Color.lerp(sunColor, moonColor, progress)!;
    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Body radius scales between Sun core (0.25) and Moon crescent (0.36)
    final bodyRadius = ui.lerpDouble(minDim * 0.25, minDim * 0.36, progress)!;

    // 2. Global Spin Rotation for the entire metamorphosis (0 -> 180 degrees)
    final spinAngle = progress * math.pi;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spinAngle);
    canvas.translate(-center.dx, -center.dy);

    // 3. Draw Central Body Path (Sun full sphere -> Crescent Moon pointing diagonally top-left)
    final mainCirclePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: bodyRadius));

    Path finalBodyPath;
    if (progress > 0.001) {
      // In local coordinates (pre-spin):
      // Mask circle slides into (+0.16 * minDim, +0.16 * minDim)
      // When rotated by spinAngle (pi = 180°), it lands precisely pointing diagonally top-left!
      final startOffsetX = minDim * 0.60;
      final startOffsetY = minDim * 0.60;
      final endOffsetX = minDim * 0.16;
      final endOffsetY = minDim * 0.16;

      final currentOffsetX = ui.lerpDouble(startOffsetX, endOffsetX, progress)!;
      final currentOffsetY = ui.lerpDouble(startOffsetY, endOffsetY, progress)!;
      final maskRadius = ui.lerpDouble(bodyRadius * 0.82, bodyRadius * 0.86, progress)!;

      final maskPath = Path()
        ..addOval(Rect.fromCircle(
          center: center + Offset(currentOffsetX, currentOffsetY),
          radius: maskRadius,
        ));

      finalBodyPath = Path.combine(PathOperation.difference, mainCirclePath, maskPath);
    } else {
      finalBodyPath = mainCirclePath;
    }

    canvas.drawPath(finalBodyPath, bodyPaint);

    // 4. Draw Sun Micro-Rays (8 rays around center, retracting/fading as progress -> 1.0)
    final rayOpacity = (1.0 - progress * 1.5).clamp(0.0, 1.0);
    if (rayOpacity > 0.005) {
      final rayPaint = Paint()
        ..color = sunColor.withValues(alpha: rayOpacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.3, minDim * 0.08 * (1.0 - progress * 0.4))
        ..isAntiAlias = true;

      final rayStartDist = bodyRadius + minDim * 0.08;
      final rayLength = (minDim * 0.12) * (1.0 - progress);
      final rayEndDist = rayStartDist + rayLength;

      const rayCount = 8;
      for (int i = 0; i < rayCount; i++) {
        final angle = (i * 2 * math.pi / rayCount);
        final x1 = center.dx + rayStartDist * math.cos(angle);
        final y1 = center.dy + rayStartDist * math.sin(angle);
        final x2 = center.dx + rayEndDist * math.cos(angle);
        final y2 = center.dy + rayEndDist * math.sin(angle);

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), rayPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MorphingSunMoonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.sunColor != sunColor ||
        oldDelegate.moonColor != moonColor;
  }
}
