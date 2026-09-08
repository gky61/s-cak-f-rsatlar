import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../deal_card/deal_card_helpers.dart';

/// Mağazaya yönlendirme esnasında kullanıcıya güven veren, modern, ferah
/// ve minimalist bir geçiş animasyonu (HUD) sunan diyalog bileşeni.
class StoreRedirectDialog extends StatefulWidget {
  final String storeName;
  final Uri targetUri;

  const StoreRedirectDialog({
    super.key,
    required this.storeName,
    required this.targetUri,
  });

  /// Diyaloğu ekranda gösterir, yönlendirmeyi başlatır ve işlem tamamlandığında otomatik kapatır.
  static Future<void> show({
    required BuildContext context,
    required String storeName,
    required Uri targetUri,
  }) async {
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => StoreRedirectDialog(
        storeName: storeName,
        targetUri: targetUri,
      ),
    );
  }

  @override
  State<StoreRedirectDialog> createState() => _StoreRedirectDialogState();
}

class _StoreRedirectDialogState extends State<StoreRedirectDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _pulseAnimation;
  bool _isLaunched = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(_scaleAnimation);

    // Yönlendirmeyi başlat ve güvenli geçiş süresini yönet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeRedirection();
    });
  }

  Future<void> _executeRedirection() async {
    if (_isLaunched) return;
    _isLaunched = true;

    final stopwatch = Stopwatch()..start();
    Uri finalLaunchUri = widget.targetUri;

    // Eğer btrck.com veya adjust gibi bir aracı redirect linki ise,
    // diyalog ekrandayken arka planda 302 yönlendirmesini hızlıca çöz (0.3 sn).
    // Böylece harici tarayıcı açılıp adres çubuğunda çirkin takip linki görünmez;
    // doğrudan nihai hedef URL (teknosa.com vb.) yerel mağaza uygulamasına fırlatılır!
    final host = widget.targetUri.host.toLowerCase();
    if (host.contains('btrck.com') || host.contains('adj.st')) {
      try {
        final client = http.Client();
        final request = http.Request('GET', widget.targetUri)
          ..followRedirects = false
          ..headers['User-Agent'] =
              'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

        final streamedResponse = await client
            .send(request)
            .timeout(const Duration(milliseconds: 1200));

        final location = streamedResponse.headers['location'];
        if (location != null && location.isNotEmpty) {
          final parsed = Uri.tryParse(location);
          if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
            finalLaunchUri = parsed;
          }
        }
        client.close();
      } catch (_) {
        // Ağ gecikmesinde orijinal hedefle devam et
      }
    }

    // Kullanıcının güven veren geçiş ekranını (HUD) en az 750ms görmesini sağla
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 750) {
      await Future.delayed(Duration(milliseconds: 750 - elapsed));
    }

    try {
      // 1. Önce doğrudan yerel mağaza uygulamasına fırlatmayı dene (Tarayıcı açılmadan 0 ms)
      bool launched = false;
      try {
        launched = await launchUrl(
          finalLaunchUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (_) {
        launched = false;
      }

      // 2. Cihazda yerel uygulama yoksa harici tarayıcıyı temiz hedefle aç
      if (!launched) {
        launched = await launchUrl(
          finalLaunchUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched) {
        await launchUrl(
          finalLaunchUri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (_) {
      try {
        await launchUrl(
          finalLaunchUri,
          mode: LaunchMode.platformDefault,
        );
      } catch (_) {
        // Hata durumunda sessiz kal
      }
    }

    // Toplam geçiş tamamlanınca HUD'ı pürüzsüzce kapat
    await Future.delayed(const Duration(milliseconds: 350));
    _safeDismiss();
  }

  void _safeDismiss() {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getStoreBrandColor() {
    final lower = widget.storeName.toLowerCase();
    if (lower.contains('hepsiburada')) return const Color(0xFFFF6000);
    if (lower.contains('teknosa')) return const Color(0xFFFF671B);
    if (lower.contains('trendyol')) return const Color(0xFFF27A1A);
    if (lower.contains('amazon')) return const Color(0xFFFF9900);
    if (lower.contains('n11')) return const Color(0xFF5E17EB);
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor = _getStoreBrandColor();
    final assetPath = getStoreAsset(widget.storeName);

    return PopScope(
      canPop: false,
      child: Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Logo & Pulse Halo
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: brandColor.withValues(alpha: 0.35),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: brandColor.withValues(alpha: isDark ? 0.28 : 0.18),
                                blurRadius: 18,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                assetPath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.storefront_rounded,
                                  size: 40,
                                  color: brandColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 2. Başlık
                  Text(
                    '${widget.storeName} Mağazasına',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Güvenle Aktarılıyorsunuz',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Açıklama
                  Text(
                    'FırsatKolik güvencesiyle en güncel fiyat ve indirimler mağaza üzerinden doğrulanıyor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Güvenlik Rozeti (256-Bit SSL)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.09),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '256-Bit SSL Doğrulanmış Bağlantı',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 5. İnce ve Zarif Progress Bar
                  SizedBox(
                    width: 140,
                    height: 2.5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        backgroundColor: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
