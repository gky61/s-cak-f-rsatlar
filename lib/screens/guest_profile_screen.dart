import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../utils/circular_theme_transition.dart';
import 'faq_screen.dart';
import 'privacy_policy_screen.dart';
import 'category_preferences_screen.dart';

/// Misafir (oturum açmamış) kullanıcılar için modern, modüler ve zengin profil ekranı.
class GuestProfileScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const GuestProfileScreen({
    super.key,
    this.onLoginSuccess,
  });

  @override
  State<GuestProfileScreen> createState() => _GuestProfileScreenState();
}

class _GuestProfileScreenState extends State<GuestProfileScreen> {
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final GlobalKey _themeButtonKey = GlobalKey();
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    HapticFeedback.mediumImpact();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        final name = user.displayName.isNotEmpty ? user.displayName : user.username;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hoş geldiniz, $name! 🎉'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Giriş yapılamadı. Lütfen tekrar deneyin.';
        if (!e.toString().contains('iptal')) {
          errorMsg = e.toString().replaceAll('AuthException: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // FırsatKolik Renk Paleti:
    // Açık Mod: Temiz yumuşak beyaz/gri (#F8FAFC), Beyaz kartlar, Canlı FırsatKolik turuncusu ve Okyanus Mavisi
    // Karanlık Mod: Derin gece mavisi/slate zemin (#0F172A), Slate-Navy kart yüzeyi (#1E293B),
    // Göz yormayan sıcak koyu turuncu (#EA580C) ve yumuşak buz mavisi (#38BDF8)
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final primaryColor = isDark ? const Color(0xFFEA580C) : const Color(0xFFFF6B35);
    final accentBlue = isDark ? const Color(0xFF38BDF8) : const Color(0xFF004E92);
    final textMain = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. Hero Karşılama ve Hızlı Giriş Kartı
                _buildHeroCard(
                  context,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  accentBlue: accentBlue,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMain: textMain,
                  textSub: textSub,
                ),

                const SizedBox(height: 18),

                // 2. Notched Fieldset: Topluluk Ayrıcalıkları
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildPerksSection(
                    context,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    accentBlue: accentBlue,
                    surfaceColor: surfaceColor,
                    backgroundColor: backgroundColor,
                    borderColor: borderColor,
                    textMain: textMain,
                    textSub: textSub,
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Notched Fieldset: Uygulama & Tercihler
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSettingsSection(
                    context,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    accentBlue: accentBlue,
                    surfaceColor: surfaceColor,
                    backgroundColor: backgroundColor,
                    borderColor: borderColor,
                    textMain: textMain,
                    textSub: textSub,
                  ),
                ),

                const SizedBox(height: 110), // Bottom nav padding
              ],
            ),
          ),

          // Custom Floating App Bar
          _buildCustomAppBar(
            context,
            isDark: isDark,
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textMain: textMain,
            accentBlue: accentBlue,
          ),

          // Bottom Navigation Bar
          _buildBottomNav(
            context,
            isDark: isDark,
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            activeColor: isDark ? accentBlue : primaryColor,
          ),
        ],
      ),
    );
  }

  // 1. HERO CARD
  Widget _buildHeroCard(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color accentBlue,
    required Color surfaceColor,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 64, 20, 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: Border(
          bottom: BorderSide(
            color: borderColor,
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Minimalist Avatar Container (Neutral Slate / Modern Silver)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.person_rounded,
              size: 42,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 16),

          // Title (HomeScreen Brand Wordmark: "Fırsat" + "kolik" in primary orange)
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Fırsat',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                    letterSpacing: -0.8,
                  ),
                ),
                const TextSpan(
                  text: 'kolik',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: -0.8,
                  ),
                ),
                TextSpan(
                  text: '\'e Hoş Geldin! ✨',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'En sıcak fırsatları yakalamak, indirimleri oylamak ve avcı rozetleri kazanmak için hemen katılın.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textSub,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 20),

          // Primary Action: Google Sign In Button (Koyu, sıcak, göz yormayan tonlar)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSigningIn ? null : _handleGoogleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: isDark ? 2 : 1,
                shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isSigningIn
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.g_mobiledata_rounded, size: 30),
                        SizedBox(width: 4),
                        Text(
                          'Google ile Hızlı Giriş Yap',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. PERKS SECTION
  Widget _buildPerksSection(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color accentBlue,
    required Color surfaceColor,
    required Color backgroundColor,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.025),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Kuponlar
              _buildPerkItem(
                icon: Icons.confirmation_number_rounded,
                iconColor: isDark ? const Color(0xFFC084FC) : Colors.purple.shade600,
                iconBg: Colors.purple.withValues(alpha: isDark ? 0.16 : 0.10),
                title: 'Özel Kupon Radarı & Paylaşımı',
                description: 'Amazon, Trendyol ve 20+ mağazaya ait en sıcak kuponları keşfet, kendi kuponunu paylaş.',
                textMain: textMain,
                textSub: textSub,
              ),
              _buildDivider(isDark, borderColor),
              // 2. Fırsat Paylaşımı
              _buildPerkItem(
                icon: Icons.add_circle_outline_rounded,
                iconColor: isDark ? const Color(0xFF2DD4BF) : Colors.teal.shade600,
                iconBg: Colors.teal.withValues(alpha: isDark ? 0.16 : 0.10),
                title: 'Fırsat Paylaşımı & Avcı Rozetleri',
                description: 'Yakaladığın indirimleri anında paylaş, puan topla ve efsanevi fırsat avcısı rozetlerini kazan.',
                textMain: textMain,
                textSub: textSub,
              ),
              _buildDivider(isDark, borderColor),
              // 3. Sıcak/Soğuk Oylama
              _buildPerkItem(
                icon: Icons.local_fire_department_rounded,
                iconColor: isDark ? const Color(0xFFFB923C) : Colors.orange.shade600,
                iconBg: Colors.orange.withValues(alpha: isDark ? 0.16 : 0.10),
                title: 'Sıcak & Soğuk Oylama',
                description: 'Fırsatları oylayarak akışı şekillendir; süresi dolan veya tükenen fırsatları topluluğa bildir.',
                textMain: textMain,
                textSub: textSub,
              ),
              _buildDivider(isDark, borderColor),
              // 4. Kelime Radarı
              _buildPerkItem(
                icon: Icons.notifications_active_rounded,
                iconColor: isDark ? const Color(0xFF38BDF8) : accentBlue,
                iconBg: (isDark ? const Color(0xFF38BDF8) : accentBlue).withValues(alpha: isDark ? 0.16 : 0.10),
                title: 'Kelime & Kategori Radarı',
                description: 'Aradığın ürün (örn: iPhone, Dyson, PS5) indirime girdiği an telefonuna anlık bildirim al.',
                textMain: textMain,
                textSub: textSub,
              ),
              _buildDivider(isDark, borderColor),
              // 5. Kişiselleştirilmiş Akış
              _buildPerkItem(
                icon: Icons.dashboard_customize_rounded,
                iconColor: isDark ? const Color(0xFFF472B6) : Colors.pink.shade600,
                iconBg: Colors.pink.withValues(alpha: isDark ? 0.16 : 0.10),
                title: 'Kişiselleştirilmiş Akış & Kategori Seçimi',
                description: 'İlgilendiğin kategorileri belirle, anasayfa akışını sadece senin seveceğin fırsatlarla donat.',
                textMain: textMain,
                textSub: textSub,
              ),
              _buildDivider(isDark, borderColor),
              // 6. Topluluk Yorumları
              _buildPerkItem(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: isDark ? const Color(0xFF60A5FA) : Colors.blue.shade600,
                iconBg: Colors.blue.withValues(alpha: isDark ? 0.16 : 0.10),
                title: 'Topluluk Yorumları & Sohbet',
                description: 'Fırsat yorumlarına göz at, diğer fırsat avcılarıyla sohbet et ve en iyi alışveriş tüyolarını kap.',
                textMain: textMain,
                textSub: textSub,
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars_rounded,
                  size: 14,
                  color: isDark ? accentBlue : primaryColor,
                ),
                const SizedBox(width: 5),
                Text(
                  'TOPLULUK AYRICALIKLARI',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerkItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String description,
    required Color textMain,
    required Color textSub,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: textSub,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. SETTINGS SECTION
  Widget _buildSettingsSection(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color accentBlue,
    required Color surfaceColor,
    required Color backgroundColor,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.025),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // FAQ
              _buildSettingItem(
                icon: Icons.help_outline_rounded,
                title: 'Sıkça Sorulan Sorular',
                iconBgColor: Colors.purple.withValues(alpha: isDark ? 0.16 : 0.12),
                iconColor: isDark ? const Color(0xFFC084FC) : Colors.purple,
                trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FAQScreen()),
                  );
                },
                isDark: isDark,
              ),
              _buildDivider(isDark, borderColor),
              // Privacy Policy
              _buildSettingItem(
                icon: Icons.shield_outlined,
                title: 'Gizlilik Politikası',
                iconBgColor: Colors.teal.withValues(alpha: isDark ? 0.16 : 0.12),
                iconColor: isDark ? const Color(0xFF2DD4BF) : Colors.teal,
                trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
                isDark: isDark,
              ),
              _buildDivider(isDark, borderColor),
              // Contact
              _buildSettingItem(
                icon: Icons.alternate_email_rounded,
                title: 'Bize Ulaşın',
                iconBgColor: Colors.orange.withValues(alpha: isDark ? 0.16 : 0.12),
                iconColor: isDark ? const Color(0xFFFB923C) : Colors.orange,
                trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                onTap: () async {
                  const email = 'kolikfirsat@gmail.com';
                  final uri = Uri.parse('mailto:$email');
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('E-posta uygulaması açılamadı. Lütfen $email adresine yazın.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                isDark: isDark,
              ),
              _buildDivider(isDark, borderColor),
              // Rate App
              _buildSettingItem(
                icon: Icons.star_outline_rounded,
                title: 'Uygulamayı Değerlendir',
                iconBgColor: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.12),
                iconColor: isDark ? const Color(0xFFFBBF24) : Colors.amber[800]!,
                trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                onTap: () async {
                  const packageName = 'com.sicakfirsatlar.sicak_firsatlar';
                  final marketUrl = Uri.parse('market://details?id=$packageName');
                  final playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
                  try {
                    if (await canLaunchUrl(marketUrl)) {
                      await launchUrl(marketUrl, mode: LaunchMode.externalApplication);
                    } else if (await canLaunchUrl(playStoreUrl)) {
                      await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
                    }
                  } catch (_) {}
                },
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              // App Version
              Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Fırsat',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textSub.withValues(alpha: 0.8),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const TextSpan(
                        text: 'kolik',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: ' v1.2.4 (Build 302)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textSub.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 14,
                  color: isDark ? accentBlue : primaryColor,
                ),
                const SizedBox(width: 5),
                Text(
                  'UYGULAMA & BİLGİLER',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required Color iconColor,
    required Widget trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark, Color borderColor) {
    return Divider(
      height: 1,
      indent: 68,
      color: borderColor.withValues(alpha: isDark ? 0.6 : 0.8),
    );
  }

  // FLOATING APP BAR
  Widget _buildCustomAppBar(
    BuildContext context, {
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textMain,
    required Color accentBlue,
  }) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.90),
          border: Border(
            bottom: BorderSide(
              color: borderColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              'Profilim',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textMain,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            InkWell(
              key: _themeButtonKey,
              onTap: () {
                CircularThemeTransition.animate(
                  context: context,
                  buttonKey: _themeButtonKey,
                  isCurrentlyDark: isDark,
                  onToggleTheme: () => _themeService.toggleTheme(),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155).withValues(alpha: 0.6)
                      : Colors.indigo.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF475569)
                        : Colors.indigo.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    key: ValueKey<bool>(isDark),
                    size: 18,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BOTTOM NAVIGATION BAR
  Widget _buildBottomNav(
    BuildContext context, {
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color activeColor,
  }) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(
              color: borderColor,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  icon: Icons.home_outlined,
                  label: 'Anasayfa',
                  isSelected: false,
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                  activeColor: activeColor,
                ),
                _buildBottomNavItem(
                  icon: Icons.category_outlined,
                  label: 'Kategoriler',
                  isSelected: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryPreferencesScreen(),
                      ),
                    );
                  },
                  isDark: isDark,
                  activeColor: activeColor,
                ),
                _buildBottomNavItem(
                  icon: Icons.person_rounded,
                  label: 'Profilim',
                  isSelected: true,
                  onTap: () {},
                  isDark: isDark,
                  activeColor: activeColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Container(
                  width: 28,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: isDark ? 0.3 : 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 7),
              Icon(
                icon,
                color: isSelected ? activeColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
