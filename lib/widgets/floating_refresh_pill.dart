import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dünya Standartlarında Cam Efektli (Glassmorphic) Yüzen Yenileme / Bildirim Hapı (Floating Refresh Pill)
///
/// Akışta gezinirken kullanıcı okuma deneyimini ve scroll pozisyonunu ASLA bozmadan (Anti-Jank / Content-Jumping Kalkanı),
/// arka planda taze fırsat veya yeni veri geldiğinde ekranın üst kısmında akıcı bir animasyonla belirir.
/// Kullanıcı butona dokunduğunda hafif haptic titreşim verir ve listeyi yumuşakça tepeye fırlatır.
class FloatingRefreshPill extends StatelessWidget {
  final bool isVisible;
  final String text;
  final VoidCallback onTap;
  final IconData icon;
  final Color? primaryColor;
  final Color? gradientColor;

  const FloatingRefreshPill({
    super.key,
    required this.isVisible,
    required this.text,
    required this.onTap,
    this.icon = Icons.auto_awesome_rounded,
    this.primaryColor,
    this.gradientColor,
  });

  @override
  Widget build(BuildContext context) {
    final themePrimary = primaryColor ?? Theme.of(context).colorScheme.primary;
    final secondaryGradient = gradientColor ?? const Color(0xFFFF6A00);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      offset: isVisible ? Offset.zero : const Offset(0, -1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isVisible ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !isVisible,
          child: Center(
            child: Material(
              color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themePrimary,
                      secondaryGradient,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: themePrimary.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
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
