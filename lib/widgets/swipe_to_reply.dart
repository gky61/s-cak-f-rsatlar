import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WhatsApp ve Telegram tarzında, sağa kaydırarak hızlı yanıtlama (Swipe to Reply) bileşeni.
/// 
/// Tüm ekran boyunca kaymak yerine, sönümlü / elastik bir dirençle (max 65px) hareket eder,
/// eşik aşıldığında (38px) haptic titreşim verir ve bırakıldığında yay gibi geri yerine oturur.
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final double triggerThreshold;
  final double maxDragOffset;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.iconColor,
    this.iconBackgroundColor,
    this.triggerThreshold = 38.0,
    this.maxDragOffset = 65.0,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta == null) return;

    // Sadece sağa doğru elastik çekmeye izin ver (%55 sönümleme)
    double nextOffset = _dragOffset + (details.primaryDelta! * 0.55);
    if (nextOffset < 0) nextOffset = 0;
    if (nextOffset > widget.maxDragOffset) nextOffset = widget.maxDragOffset;

    if (nextOffset >= widget.triggerThreshold && !_hasTriggeredHaptic) {
      _hasTriggeredHaptic = true;
      HapticFeedback.mediumImpact();
    } else if (nextOffset < widget.triggerThreshold && _hasTriggeredHaptic) {
      _hasTriggeredHaptic = false;
    }

    setState(() {
      _dragOffset = nextOffset;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset >= widget.triggerThreshold) {
      widget.onReply();
    }
    _animateBack();
  }

  void _onHorizontalDragCancel() {
    _animateBack();
  }

  void _animateBack() {
    _hasTriggeredHaptic = false;
    _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.iconColor ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final progress = (_dragOffset / widget.triggerThreshold).clamp(0.0, 1.0);
    final isTriggered = _dragOffset >= widget.triggerThreshold;

    return Stack(
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      children: [
        // Sol arkada beliren WhatsApp tarzı yuvarlak yanıtla rozeti
        if (_dragOffset > 0)
          Positioned(
            left: 8 + (_dragOffset * 0.18),
            child: Transform.scale(
              scale: progress,
              child: Opacity(
                opacity: progress,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isTriggered
                        ? primaryColor
                        : (widget.iconBackgroundColor ??
                            (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : primaryColor.withValues(alpha: 0.14))),
                    shape: BoxShape.circle,
                    boxShadow: isTriggered
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    color: isTriggered ? Colors.white : primaryColor,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),

        // Kaydırılan mesaj / yorum içeriği
        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onHorizontalDragCancel: _onHorizontalDragCancel,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
