import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Root repaint boundary key used to capture screen snapshots for theme transitions
final GlobalKey rootRepaintBoundaryKey = GlobalKey();

/// High-performance Telegram-style circular theme transition utility
class CircularThemeTransition {
  static bool _isTransitioning = false;

  static bool get isTransitioning => _isTransitioning;

  /// Starts a circular reveal animation.
  /// When transitioning Light -> Dark: Originates from [buttonKey] (top-right).
  /// When transitioning Dark -> Light: Originates from the opposite diagonal end (bottom-left) to create a reverse daybreak effect.
  static Future<void> animate({
    required BuildContext context,
    required GlobalKey buttonKey,
    required bool isCurrentlyDark,
    required Future<void> Function() onToggleTheme,
  }) async {
    if (_isTransitioning) return;

    try {
      final boundary = rootRepaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      final buttonBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;

      if (boundary == null || buttonBox == null || !buttonBox.hasSize) {
        // Graceful fallback if boundary or button context isn't ready
        await onToggleTheme();
        return;
      }

      _isTransitioning = true;
      HapticFeedback.mediumImpact();

      // 1. Calculate Button Center Offset in Global Coordinates
      final buttonPosition = buttonBox.localToGlobal(Offset.zero);
      final buttonSize = buttonBox.size;
      final buttonCenter = Offset(
        buttonPosition.dx + buttonSize.width / 2,
        buttonPosition.dy + buttonSize.height / 2,
      );

      // 2. Read screen metrics and overlay before async capture
      final mediaQuery = MediaQuery.of(context);
      final pixelRatio = mediaQuery.devicePixelRatio;
      final screenSize = mediaQuery.size;
      final overlay = Overlay.of(context);

      // 3. Determine Center Point:
      // If currently Light (switching to Dark): start from Button (top-right)
      // If currently Dark (switching to Light): start from Opposite Diagonal Corner (bottom-left)
      final Offset center = isCurrentlyDark
          ? Offset(
              math.max(16.0, screenSize.width - buttonCenter.dx),
              math.max(16.0, screenSize.height - buttonCenter.dy),
            )
          : buttonCenter;

      // 4. Capture screenshot of current screen before theme change
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      // 5. Calculate max radius to cover all corners from tap center
      final d1 = math.sqrt(math.pow(center.dx, 2) + math.pow(center.dy, 2));
      final d2 = math.sqrt(math.pow(screenSize.width - center.dx, 2) + math.pow(center.dy, 2));
      final d3 = math.sqrt(math.pow(center.dx, 2) + math.pow(screenSize.height - center.dy, 2));
      final d4 = math.sqrt(math.pow(screenSize.width - center.dx, 2) + math.pow(screenSize.height - center.dy, 2));
      final maxRadius = math.max(math.max(d1, d2), math.max(d3, d4)) + 40.0;

      // 6. Create and insert Overlay
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (overlayContext) => _CircularRevealOverlay(
          image: image,
          center: center,
          maxRadius: maxRadius,
          duration: const Duration(milliseconds: 480),
          onCompleted: () {
            try {
              overlayEntry.remove();
            } catch (_) {}
            image.dispose();
            _isTransitioning = false;
          },
        ),
      );

      overlay.insert(overlayEntry);

      // 7. Toggle the theme in background
      await onToggleTheme();
    } catch (e) {
      _isTransitioning = false;
      await onToggleTheme();
    }
  }
}

class _CircularRevealOverlay extends StatefulWidget {
  final ui.Image image;
  final Offset center;
  final double maxRadius;
  final Duration duration;
  final VoidCallback onCompleted;

  const _CircularRevealOverlay({
    required this.image,
    required this.center,
    required this.maxRadius,
    required this.duration,
    required this.onCompleted,
  });

  @override
  State<_CircularRevealOverlay> createState() => _CircularRevealOverlayState();
}

class _CircularRevealOverlayState extends State<_CircularRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _radiusAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _radiusAnimation = Tween<double>(begin: 0.0, end: widget.maxRadius).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _radiusAnimation,
          builder: (context, child) {
            return ClipPath(
              clipper: _InvertedCircleClipper(
                center: widget.center,
                radius: _radiusAnimation.value,
              ),
              child: RawImage(
                image: widget.image,
                fit: BoxFit.fill,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InvertedCircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _InvertedCircleClipper({
    required this.center,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant _InvertedCircleClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
