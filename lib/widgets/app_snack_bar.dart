import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

/// Flutter'ın Material SnackBar'ı dahili olarak Hero animasyonu kullanır ve
/// Hero tag'ini `<SnackBar Hero tag - ${widget.content}>` şeklinde widget'ın toString'inden türetir.
/// [UniqueSnackBarContent], her oluşturulduğunda benzersiz bir kimlik üreterek
/// toString() çıktısının daima tekil olmasını sağlar.
class UniqueSnackBarContent extends StatelessWidget {
  final Widget child;
  final String _uniqueHeroTag;

  static int _snackCounter = 0;

  UniqueSnackBarContent({
    super.key,
    required this.child,
  }) : _uniqueHeroTag = 'snack_${DateTime.now().microsecondsSinceEpoch}_${_snackCounter++}';

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return _uniqueHeroTag;
  }

  @override
  Widget build(BuildContext context) => child;
}

/// Tüm uygulama genelinde rota geçişleri, pop/push operasyonları ve iç içe Scaffold'lardan
/// tamamen bağımsız, Hero çakışması imkansız, modern ve akıcı bildirim kartı (Overlay Toast).
///
/// Flutter'ın yerleşik Material SnackBar bileşeni arka planda hardcoded Hero(tag: '<SnackBar Hero tag...>')
/// kullandığından, rota geçişlerinde veya sayfa kapatıldığında (pop) `ScaffoldMessenger` üzerinden
/// fırlatılan ölümcül `There are multiple heroes that share the same tag within a subtree`
/// hatasını kökten ve mimari düzeyde engeller.
class AppSnackBar {
  AppSnackBar._();

  static OverlayEntry? _currentEntry;

  /// Güvenli, tekil ve modern FırsatKolik bildirim gösterici (Overlay Toast).
  static void show({
    BuildContext? context,
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    bool useRootMessenger = false,
  }) {
    hide();

    OverlayState? overlayState;
    if (context != null && context.mounted) {
      overlayState = Overlay.maybeOf(context);
    }
    overlayState ??= navigatorKey.currentState?.overlay;

    if (overlayState == null) return;

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _AppToastWidget(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
        onDismiss: () {
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }

  /// Mevcut bildirimi anında ve güvenle kapatır.
  static void hide() {
    if (_currentEntry != null) {
      try {
        _currentEntry!.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }

  /// Sayfa kapatıldıktan (Navigator.pop) hemen sonra alttaki ekranda
  /// güvenle bildirim göstermek için kullanılan metod.
  /// Overlay doğrudan kök gezgin üzerinden açıldığı için sayfa geçiş animasyonlarından etkilenmez.
  static void showPostPop({
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      show(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
      );
    });
  }
}

class _AppToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Duration duration;
  final SnackBarAction? action;
  final VoidCallback onDismiss;

  const _AppToastWidget({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.duration,
    this.action,
    required this.onDismiss,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _controller.forward();

    _autoDismissTimer = Timer(widget.duration, () {
      _dismissWithAnimation();
    });
  }

  void _dismissWithAnimation() {
    _autoDismissTimer?.cancel();
    if (mounted) {
      _controller.reverse().then((_) {
        if (mounted) {
          widget.onDismiss();
        }
      });
    } else {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;

    return Positioned(
      bottom: bottomInset + (bottomPadding > 0 ? bottomPadding + 8 : 20),
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Dismissible(
            key: const Key('app_snack_bar_dismissible'),
            direction: DismissDirection.down,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (widget.action != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          widget.action!.onPressed();
                          _dismissWithAnimation();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          widget.action!.label,
                          style: TextStyle(
                            color: widget.action!.textColor ?? Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
