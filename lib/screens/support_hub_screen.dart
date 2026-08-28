import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/in_app_tutorial_service.dart';
import '../theme/app_theme.dart';
import '../utils/badge_helper.dart';
import 'auth_screen.dart';
import 'badges_screen.dart';
import 'faq_screen.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';

class SupportHubScreen extends StatefulWidget {
  final AppUser? user;
  final bool isOwnProfile;

  const SupportHubScreen({
    super.key,
    this.user,
    this.isOwnProfile = true,
  });

  @override
  State<SupportHubScreen> createState() => _SupportHubScreenState();
}

class _SupportHubScreenState extends State<SupportHubScreen> {
  final AuthService _authService = AuthService();
  late AppUser? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  Future<void> _signOut() async {
    final email = _authService.currentUser?.email;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final textSub = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Çıkış Yap',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email != null && email.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email_rounded, size: 14, color: textSub),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              email != null && email.isNotEmpty
                  ? 'Bu hesaptan çıkış yapmak istediğinize emin misiniz? Dilediğiniz zaman tekrar giriş yapabilirsiniz.'
                  : 'Çıkış yapmak istediğinize emin misiniz?',
              style: TextStyle(
                fontSize: 13.5,
                color: textSub,
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Text(
                    'Vazgeç',
                    style: TextStyle(
                      color: textSub,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Çıkış Yap',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final email = _authService.currentUser?.email;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final textSub = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade400, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hesabı Kalıcı Olarak Sil',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email != null && email.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: isDark ? 0.35 : 0.20),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email_rounded, size: 14, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              'Bu işlem GERİ ALINAMAZ. Paylaştığınız tüm fırsatlar, yorumlar, avcı puanlarınız ve rozetleriniz kalıcı olarak silinecektir.',
              style: TextStyle(
                fontSize: 13,
                color: textSub,
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      color: textSub,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Kalıcı Olarak Sil',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _authService.deleteAccount();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hesap silinirken hata oluştu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final textSub = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: textMain,
            ),
            onPressed: () => Navigator.pop(context, _currentUser),
          ),
          title: Text(
            'Hesap, Yardım & Destek',
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: textMain,
              letterSpacing: -0.3,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: borderColor,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Grup: REHBER & BAŞARIMLAR
                    _buildHubGroupHeader('REHBER & BAŞARIMLAR', textSub),
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildHubItem(
                            icon: Icons.military_tech_rounded,
                            title: 'Avcı Başarımları & Rozetler',
                            subtitle: '${_currentUser?.badges.length ?? 0} / ${BadgeHelper.badges.length} Rozet Kazanıldı',
                            iconBgColor: Colors.amber.withValues(alpha: isDark ? 0.20 : 0.12),
                            iconColor: isDark ? const Color(0xFFFBBF24) : Colors.amber.shade800,
                            isDark: isDark,
                            textMain: textMain,
                            textSub: textSub,
                            onTap: () async {
                              if (_currentUser == null) return;
                              final updatedUser = await Navigator.push<AppUser>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BadgesScreen(
                                    user: _currentUser!,
                                    isOwnProfile: widget.isOwnProfile,
                                  ),
                                ),
                              );
                              if (updatedUser != null && mounted) {
                                setState(() {
                                  _currentUser = updatedUser;
                                });
                              }
                            },
                          ),
                          _buildDivider(isDark, borderColor),
                          _buildHubItem(
                            icon: Icons.explore_rounded,
                            title: 'Uygulama Turu (Nasıl Kullanılır?)',
                            subtitle: '8 adımda tüm avantajları keşfet',
                            iconBgColor: const Color(0xFFFF6B35).withValues(alpha: isDark ? 0.20 : 0.12),
                            iconColor: const Color(0xFFFF6B35),
                            isDark: isDark,
                            textMain: textMain,
                            textSub: textSub,
                            onTap: () async {
                              await InAppTutorialService().resetTutorial();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const HomeScreen(startTutorial: true),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                          _buildDivider(isDark, borderColor),
                          _buildHubItem(
                            icon: Icons.help_outline_rounded,
                            title: 'Sıkça Sorulan Sorular',
                            subtitle: 'Fırsatlar, kuponlar ve oylama rehberi',
                            iconBgColor: Colors.blue.withValues(alpha: isDark ? 0.20 : 0.12),
                            iconColor: isDark ? const Color(0xFF60A5FA) : Colors.blue.shade600,
                            isDark: isDark,
                            textMain: textMain,
                            textSub: textSub,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FAQScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. Grup: İLETİŞİM & GERİ BİLDİRİM
                    _buildHubGroupHeader('İLETİŞİM & GERİ BİLDİRİM', textSub),
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildHubItem(
                            icon: Icons.alternate_email_rounded,
                            title: 'Bize Ulaşın & Geri Bildirim',
                            subtitle: 'kolikfirsat@gmail.com',
                            iconBgColor: Colors.orange.withValues(alpha: isDark ? 0.20 : 0.12),
                            iconColor: isDark ? const Color(0xFFFB923C) : Colors.orange.shade600,
                            isDark: isDark,
                            textMain: textMain,
                            textSub: textSub,
                            onTap: () async {
                              const email = 'kolikfirsat@gmail.com';
                              final uri = Uri.parse('mailto:$email');
                              try {
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              } catch (_) {}
                            },
                          ),
                          _buildDivider(isDark, borderColor),
                          _buildHubItem(
                            icon: Icons.star_rounded,
                            title: 'Uygulamayı Değerlendir',
                            subtitle: 'Google Play & App Store',
                            iconBgColor: Colors.amber.withValues(alpha: isDark ? 0.20 : 0.12),
                            iconColor: isDark ? const Color(0xFFFBBF24) : Colors.amber.shade800,
                            isDark: isDark,
                            textMain: textMain,
                            textSub: textSub,
                            onTap: () async {
                              const packageName = 'com.sicakfirsatlar.sicak_firsatlar';
                              final playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
                              final marketUrl = Uri.parse('market://details?id=$packageName');
                              try {
                                if (await canLaunchUrl(marketUrl)) {
                                  await launchUrl(marketUrl, mode: LaunchMode.externalApplication);
                                } else if (await canLaunchUrl(playStoreUrl)) {
                                  await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
                                }
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3. Grup: YASAL BİLGİLER
                    _buildHubGroupHeader('YASAL BİLGİLER', textSub),
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _buildHubItem(
                        icon: Icons.shield_outlined,
                        title: 'Gizlilik Politikası & KVKK',
                        subtitle: 'Şeffaflık, çerezler ve kullanıcı hakları',
                        iconBgColor: Colors.teal.withValues(alpha: isDark ? 0.20 : 0.12),
                        iconColor: isDark ? const Color(0xFF2DD4BF) : Colors.teal.shade600,
                        isDark: isDark,
                        textMain: textMain,
                        textSub: textSub,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 4. Grup: OTURUM & GÜVENLİK
                    _buildHubGroupHeader('OTURUM & GÜVENLİK', textSub),
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildHubItem(
                            icon: Icons.logout_rounded,
                            title: 'Çıkış Yap',
                            subtitle: _authService.currentUser?.email != null &&
                                    _authService.currentUser!.email!.isNotEmpty
                                ? '${_authService.currentUser!.email} oturumunu kapat'
                                : 'Oturumunuzu güvenle sonlandırın',
                            iconBgColor: Colors.red.withValues(alpha: isDark ? 0.18 : 0.10),
                            iconColor: Colors.red.shade400,
                            isDark: isDark,
                            textMain: isDark ? const Color(0xFFF87171) : Colors.red.shade600,
                            textSub: textSub,
                            onTap: _signOut,
                          ),
                          _buildDivider(isDark, borderColor),
                          _buildHubItem(
                            icon: Icons.delete_outline_rounded,
                            title: 'Hesabımı Kalıcı Olarak Sil',
                            subtitle: _authService.currentUser?.email != null &&
                                    _authService.currentUser!.email!.isNotEmpty
                                ? '${_authService.currentUser!.email} ve tüm verileri sil'
                                : 'Hesabınızı ve tüm verilerinizi silin',
                            iconBgColor: Colors.red.withValues(alpha: isDark ? 0.12 : 0.06),
                            iconColor: Colors.red.shade400,
                            isDark: isDark,
                            textMain: isDark ? const Color(0xFFF87171) : Colors.red.shade700,
                            textSub: textSub,
                            onTap: _deleteAccount,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Footer Badge
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'FırsatKolik v1.2.4 (Build 302)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textSub,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Türkiye\'nin En Sıcak Fırsat Topluluğu 🔥',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textSub.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHubGroupHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: color.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _buildHubItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required bool isDark,
    required Color textMain,
    required Color textSub,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 19),
                ),
              ),
              const SizedBox(width: 13),
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
                    const SizedBox(height: 2.5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: textSub.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark, Color borderColor) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 64,
      endIndent: 14,
      color: borderColor,
    );
  }
}
