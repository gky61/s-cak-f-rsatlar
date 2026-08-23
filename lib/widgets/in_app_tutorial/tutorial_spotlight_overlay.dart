import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/in_app_tutorial_service.dart';
import 'tutorial_tooltip_card.dart';

/// Minimalist, ultra yumuşak geçişli, şekil morflamalı (Shape Morphing) Spotlight Overlay katmanı
class TutorialSpotlightOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onDismiss;

  const TutorialSpotlightOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onDismiss,
  });

  /// Turu herhangi bir ekranda modal overlay olarak başlatan statik metod
  static Future<void> show({
    required BuildContext context,
    required List<TutorialStep> steps,
    VoidCallback? onComplete,
    VoidCallback? onDismiss,
  }) async {
    final overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (ctx) => TutorialSpotlightOverlay(
        steps: steps,
        onComplete: () {
          overlayEntry.remove();
          InAppTutorialService().markTutorialCompleted();
          onComplete?.call();
        },
        onDismiss: () {
          overlayEntry.remove();
          InAppTutorialService().markTutorialCompleted();
          onDismiss?.call();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  @override
  State<TutorialSpotlightOverlay> createState() => _TutorialSpotlightOverlayState();
}

class _TutorialSpotlightOverlayState extends State<TutorialSpotlightOverlay>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Rect _currentRect = Rect.zero;
  Rect _previousRect = Rect.zero;
  double _currentRadius = 14.0;
  double _previousRadius = 14.0;
  Color _currentColor = const Color(0xFFF97316);
  Color _previousColor = const Color(0xFFF97316);

  late AnimationController _pulseController;
  late AnimationController _transitionController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _transitionAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Sakin ve dingin nefes alma animasyonu (2400 ms)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    // 2. İpeksi akışkanlıkta koordinat & şekil morflama animasyonu (480 ms)
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOutCubic,
    );

    // İlk frame sonrası koordinatı hesapla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateCurrentRect(isInitial: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  double _getEffectiveRadius(TutorialStep step, Rect rect) {
    if (step.isCircle) {
      return math.min(rect.width, rect.height) / 2.0;
    }
    return step.borderRadius;
  }

  /// Hedef widget'ın ekran üzerindeki mutlak koordinatlarını ve morflama yarıçapını hesaplar
  void _calculateCurrentRect({bool isInitial = false}) {
    if (_currentIndex >= widget.steps.length) return;

    final step = widget.steps[_currentIndex];
    final key = step.targetKey;
    final renderObject = key.currentContext?.findRenderObject();

    if (renderObject is RenderBox && renderObject.hasSize) {
      final size = renderObject.size;
      final position = renderObject.localToGlobal(Offset.zero);
      final padding = step.padding;

      final targetRect = Rect.fromLTWH(
        position.dx - padding.left,
        position.dy - padding.top,
        size.width + padding.horizontal,
        size.height + padding.vertical,
      );

      final effectiveRadius = _getEffectiveRadius(step, targetRect);

      if (isInitial) {
        setState(() {
          _currentRect = targetRect;
          _previousRect = targetRect;
          _currentRadius = effectiveRadius;
          _previousRadius = effectiveRadius;
          _currentColor = step.accentColor;
          _previousColor = step.accentColor;
        });
      } else {
        setState(() {
          _previousRect = _currentRect;
          _currentRect = targetRect;
          _previousRadius = _currentRadius;
          _currentRadius = effectiveRadius;
          _previousColor = _currentColor;
          _currentColor = step.accentColor;
        });
        _transitionController.forward(from: 0.0);
      }
    } else {
      final screenSize = MediaQuery.of(context).size;
      final defaultRect = Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height * 0.25),
        width: 140,
        height: 56,
      );
      final defaultRadius = _getEffectiveRadius(step, defaultRect);

      setState(() {
        _currentRect = defaultRect;
        _previousRect = defaultRect;
        _currentRadius = defaultRadius;
        _previousRadius = defaultRadius;
        _currentColor = step.accentColor;
        _previousColor = step.accentColor;
      });
    }
  }

  void _goToNextStep() {
    if (_currentIndex < widget.steps.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _calculateCurrentRect();
    } else {
      widget.onComplete();
    }
  }

  void _goToPreviousStep() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _calculateCurrentRect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = widget.steps[_currentIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onDismiss();
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseAnimation,
          _transitionAnimation,
        ]),
        builder: (context, child) {
          final progress = _transitionAnimation.value;
          final animatedRect = Rect.lerp(
                _previousRect,
                _currentRect,
                progress,
              ) ??
              _currentRect;

          final animatedRadius = ui.lerpDouble(
                _previousRadius,
                _currentRadius,
                progress,
              ) ??
              _currentRadius;

          final animatedColor = Color.lerp(
                _previousColor,
                _currentColor,
                progress,
              ) ??
              _currentColor;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Kadife derinliğinde mat karartma ve morflanan odaklama kesiği
              GestureDetector(
                onTap: _goToNextStep,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! > 180) {
                      _goToPreviousStep();
                    } else if (details.primaryVelocity! < -180) {
                      _goToNextStep();
                    }
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: CustomPaint(
                  painter: _MorphingSpotlightPainter(
                    targetRect: animatedRect,
                    borderRadius: animatedRadius,
                    pulseProgress: _pulseAnimation.value,
                    accentColor: animatedColor,
                  ),
                ),
              ),

              // 2. Akıcı şekilde süzülen (Animated Position) minimalist bilgi kartı
              if (_currentRect != Rect.zero)
                TutorialTooltipCard(
                  step: currentStep,
                  currentIndex: _currentIndex,
                  totalSteps: widget.steps.length,
                  targetRect: _currentRect,
                  onNext: _goToNextStep,
                  onPrevious: _goToPreviousStep,
                  onSkip: widget.onDismiss,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Şekil morflamalı (Shape Morphing) ve kadife tonlu akışkan Canvas Painter
class _MorphingSpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double borderRadius;
  final double pulseProgress;
  final Color accentColor;

  _MorphingSpotlightPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.pulseProgress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targetRect == Rect.zero) return;

    final fullScreenRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fullScreenPath = Path()..addRect(fullScreenRect);

    // Morflanan kesik yolu (Kesintisiz RRect morflaması)
    final clampedRadius = math.min(
      borderRadius,
      math.min(targetRect.width, targetRect.height) / 2.0,
    );

    final targetPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          targetRect,
          Radius.circular(clampedRadius),
        ),
      );

    // Karartma yolu = Tam Ekran - Hedef Kesiği
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      targetPath,
    );

    // 1. Kadife mat siyah arka plan (%78 opaklık)
    final backgroundPaint = Paint()
      ..color = const Color(0xFF020617).withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, backgroundPaint);

    // 2. Hedef etrafında sakin, göz yormayan pastel ışık halesi (Ambient Halo)
    final auraExpansion = 1.5 + (pulseProgress * 2.0);
    final auraOpacity = 0.08 + (pulseProgress * 0.12);

    final auraPaint = Paint()
      ..color = accentColor.withValues(alpha: auraOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 + (pulseProgress * 1.0)
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 3.5 + (pulseProgress * 2.5));

    final auraRect = targetRect.inflate(auraExpansion);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        auraRect,
        Radius.circular(clampedRadius + auraExpansion),
      ),
      auraPaint,
    );

    // 3. Hedefe ince ve zarif sınır çizgisi
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        targetRect,
        Radius.circular(clampedRadius),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MorphingSpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.accentColor != accentColor;
  }
}
