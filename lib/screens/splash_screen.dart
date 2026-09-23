import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

/// Dünya Standartlarında Tekil Tuval (Single-Canvas) Açılış Ekranı.
///
/// Native OS Splash ekranı ile Flutter ekranı arasında piksel piksel görsel süreklilik sağlar.
/// Cihaz temasına göre Açık (Saf Beyaz) veya Koyu (OLED Saf Siyah) zemin üzerine
/// merkezdeki FırsatKolik amblemini kesintisiz taşır ve akıcı bir çözünme (dissolve)
/// animasyonu ile ana sayfayı açığa çıkarır.
class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({
    super.key,
    required this.child,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _exitController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  late Animation<double> _exitFadeAnimation;
  late Animation<double> _exitScaleAnimation;

  bool _isFinished = false;

  @override
  void initState() {
    super.initState();

    // 1. Giriş mikro-animasyonları (Logo hafif nefes alma ve tipografi belirmesi)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Çıkış geçişi (Ana sayfayı açığa çıkaran yumuşak çözünme ve derinlik)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeOutCubic,
      ),
    );

    // 3. İlk kare çizilir çizilmez native splash'i kaldır ve akışı başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _startSplashSequence();
    });
  }

  void _startSplashSequence() async {
    if (!mounted) return;
    _entranceController.forward();

    // Markanın algılanması ve prestijli sunum için ideal süre (~1350ms)
    await Future.delayed(const Duration(milliseconds: 1350));
    if (!mounted) return;

    // Çıkış çözünmesini (dissolve reveal) başlat
    await _exitController.forward();
    if (!mounted) return;

    setState(() {
      _isFinished = true;
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return widget.child;
    }

    final isDark = ThemeService().isDarkMode;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: backgroundColor,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(
        children: [
          // Alt katman: Ana sayfa (Çözünme esnasında hazır bekler)
          widget.child,

          // Üst katman: Dikişsiz Geçiş Yapan Splash Tuvali
          FadeTransition(
            opacity: _exitFadeAnimation,
            child: ScaleTransition(
              scale: _exitScaleAnimation,
              child: Scaffold(
                backgroundColor: backgroundColor,
                body: SafeArea(
                  child: AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, _) {
                      return Stack(
                        children: [
                          // Merkez Logo ve Tipografi Bloğu (Native splash ile tam örtüşen dikey aks)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Fırsatkolik Ateş Amblemi (Native splash ile birebir aynı boyut ve konum)
                                Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primary.withValues(
                                            alpha: isDark ? 0.30 : 0.14,
                                          ),
                                          blurRadius: isDark ? 48 : 28,
                                          spreadRadius: isDark ? 14 : 4,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      isDark
                                          ? 'assets/branding_flame_dark.png'
                                          : 'assets/branding_flame_light.png',
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // Marka Tipografisi (Fırsatkolik - Akıllı Fırsat Radarı)
                                SlideTransition(
                                  position: _textSlideAnimation,
                                  child: FadeTransition(
                                    opacity: _textFadeAnimation,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.roboto(
                                              fontSize: 27,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.6,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'Fırsat',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const TextSpan(
                                                text: 'kolik',
                                                style: TextStyle(
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'AKILLI FIRSAT RADARI',
                                          style: GoogleFonts.roboto(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 3.2,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Alt Bilgi Rozeti (Footer Branding)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 20,
                            child: FadeTransition(
                              opacity: _textFadeAnimation,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 14,
                                    color: AppTheme.primary.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "TÜRKİYE'NİN EN SICAK FIRSATLARI",
                                    style: GoogleFonts.roboto(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.4,
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


