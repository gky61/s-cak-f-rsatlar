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

  /// Starts a circular reveal / collapse animation.
  /// When transitioning Light -> Dark: Expanding circle originating from [buttonKey] (top-right Moon).
  /// When transitioning Dark -> Light: Collapsing "black hole / vortex" shrinking directly into [buttonKey] (top-right Sun).
  static Future<void> animate({
    required BuildContext context,
    required GlobalKey buttonKey,
    required bool isCurrentlyDark,
    required Future<void> Function() onToggleTheme,
    Duration duration = const Duration(milliseconds: 800),
    Curve curve = Curves.easeInOutCubic,
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
      final pixelRatio = math.min(mediaQuery.devicePixelRatio, 2.0);
      final screenSize = mediaQuery.size;
      final overlay = Overlay.of(context);

      // 3. Center point is ALWAYS buttonCenter (Sun or Moon icon)
      final Offset center = buttonCenter;

      // 4. Capture screenshot of current screen before theme change
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      // 5. Calculate max radius to cover all corners from buttonCenter
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
          isCollapsing: isCurrentlyDark,
          duration: duration,
          curve: curve,
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
  final bool isCollapsing;
  final Duration duration;
  final Curve curve;
  final VoidCallback onCompleted;

  const _CircularRevealOverlay({
    required this.image,
    required this.center,
    required this.maxRadius,
    required this.isCollapsing,
    required this.duration,
    required this.curve,
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

    if (widget.isCollapsing) {
      // Dark -> Light: Start from full radius and shrink down to 0 at button center (Black hole effect)
      _radiusAnimation = Tween<double>(begin: widget.maxRadius, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: widget.curve,
        ),
      );
    } else {
      // Light -> Dark: Start from 0 and expand to max radius from button center (Expanding reveal)
      _radiusAnimation = Tween<double>(begin: 0.0, end: widget.maxRadius).animate(
        CurvedAnimation(
          parent: _controller,
          curve: widget.curve,
        ),
      );
    }

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
          child: RepaintBoundary(
            child: RawImage(
              image: widget.image,
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          builder: (context, child) {
            return ClipPath(
              clipper: widget.isCollapsing
                  ? _NormalCircleClipper(
                      center: widget.center,
                      radius: _radiusAnimation.value,
                    )
                  : _InvertedCircleClipper(
                      center: widget.center,
                      radius: _radiusAnimation.value,
                    ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Normal circle clipper for collapsing mode (Dark -> Light)
/// Keeps only the circle area, revealing the new light theme outside as it shrinks into center
class _NormalCircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _NormalCircleClipper({
    required this.center,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: math.max(0.0, radius)));
    return path;
  }

  @override
  bool shouldReclip(covariant _NormalCircleClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}

/// Inverted circle clipper for expanding reveal mode (Light -> Dark)
/// Cuts a circular hole in the rectangle, revealing the new dark theme inside as it expands from center
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
      ..addOval(Rect.fromCircle(center: center, radius: math.max(0.0, radius)))
      ..fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant _InvertedCircleClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
