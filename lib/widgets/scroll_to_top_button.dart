import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// FırsatKolik standartlarında minimalist, modern ve akıcı
/// "Yukarı Kaydır" (Scroll to Top) butonu.
///
/// Tasarım Standartları:
/// - iOS & Modern Web standartlarında Frosted Glass (BackdropFilter) yüzey.
/// - Açık/Koyu tema duyarlı (Slate-800 / Pure White ikon ve ince çerçeve).
/// - Dokunmatik mikro-etkileşim (0.90 basma küçülmesi + hafif haptik geri bildirim).
/// - Akıcı Scale & Fade animasyonu (Curves.easeOutBack ile pop-in).
/// - Dokunulduğunda hafif FırsatKolik turuncusu vurgu kenarlığı.
/// - Ergonomik 48x48dp dokunma hedefi (WCAG 2.2 uyumlu), 42x42dp zarif gövde.
class ScrollToTopButton extends StatefulWidget {
  final bool isVisible;
  final ScrollController? scrollController;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  /// Tüm uygulamada tutarlı yukarı kaydırma tetikleme eşiği (pixel).
  static const double defaultThreshold = 700.0;

  const ScrollToTopButton({
    super.key,
    required this.isVisible,
    this.scrollController,
    this.onPressed,
    this.tooltip = 'Yukarı Kaydır',
    this.size = 42.0,
  });

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  bool _isPressed = false;

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else if (widget.scrollController != null && widget.scrollController!.hasClients) {
      widget.scrollController!.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Renk paleti: FırsatKolik tasarım sistemi ile %100 uyumlu
    final bgColor = isDark
        ? const Color(0xFF1E2024).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.92);

    final borderColor = _isPressed
        ? AppTheme.primary.withValues(alpha: 0.70)
        : (isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE2E8F0));

    final iconColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF1E293B);

    final shadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 6,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ];

    return AnimatedScale(
      scale: widget.isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 260),
      curve: widget.isVisible ? Curves.easeOutBack : Curves.easeInCubic,
      child: AnimatedOpacity(
        opacity: widget.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        child: IgnorePointer(
          ignoring: !widget.isVisible,
          child: Semantics(
            button: true,
            label: widget.tooltip,
            child: Tooltip(
              message: widget.tooltip,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _isPressed = true),
                onTapUp: (_) {
                  setState(() => _isPressed = false);
                  _handleTap();
                },
                onTapCancel: () => setState(() => _isPressed = false),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: AnimatedScale(
                      scale: _isPressed ? 0.90 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: shadows,
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bgColor,
                                border: Border.all(
                                  color: borderColor,
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 22,
                                  color: iconColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
