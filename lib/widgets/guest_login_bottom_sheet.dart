import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Misafir kullanıcılar kısıtlı bir özelliğe tıkladığında açılan şık ve kullanıcı dostu giriş penceresi
Future<bool?> showGuestLoginBottomSheet(
  BuildContext context, {
  required String title,
  required String message,
  String? primaryButtonText,
  VoidCallback? onLoginSuccess,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GuestLoginBottomSheet(
      title: title,
      message: message,
      primaryButtonText: primaryButtonText ?? 'Google ile Giriş Yap',
      onLoginSuccess: onLoginSuccess,
    ),
  );
}

class GuestLoginBottomSheet extends StatefulWidget {
  final String title;
  final String message;
  final String primaryButtonText;
  final VoidCallback? onLoginSuccess;

  const GuestLoginBottomSheet({
    super.key,
    required this.title,
    required this.message,
    required this.primaryButtonText,
    this.onLoginSuccess,
  });

  @override
  State<GuestLoginBottomSheet> createState() => _GuestLoginBottomSheetState();
}

class _GuestLoginBottomSheetState extends State<GuestLoginBottomSheet> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isLoadingApple = false;

  Future<void> _handleAppleSignIn() async {
    if (_isLoading || _isLoadingApple) return;

    setState(() {
      _isLoadingApple = true;
    });

    try {
      final user = await _authService.signInWithApple();
      if (user != null && mounted) {
        Navigator.of(context).pop(true);
        widget.onLoginSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hoş geldiniz, ${user.username}! 🍎'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Apple ile giriş yapılamadı. Lütfen tekrar deneyin.';
        final errStr = e.toString();
        if (!errStr.contains('iptal') && !errStr.contains('canceled') && !errStr.contains('cancelled')) {
          errorMsg = errStr.replaceAll('AuthException: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApple = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading || _isLoadingApple) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.of(context).pop(true);
        widget.onLoginSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hoş geldiniz, ${user.username}! 🎉'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Giriş yapılamadı. Lütfen tekrar deneyin.';
        final errStr = e.toString();
        if (!errStr.contains('iptal') && !errStr.contains('canceled') && !errStr.contains('cancelled')) {
          errorMsg = errStr.replaceAll('AuthException: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Çekme çubuğu (Drag Handle)
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // İkon ve Başlık
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 32,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Başlık
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Açıklama mesajı
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 28),

          // Apple ile Giriş Butonu (sadece iOS)
          if (defaultTargetPlatform == TargetPlatform.iOS) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isLoading || _isLoadingApple) ? null : _handleAppleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoadingApple
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.apple, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Apple ile Giriş Yap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Google ile Giriş Butonu
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_isLoading || _isLoadingApple) ? null : _handleGoogleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: (defaultTargetPlatform == TargetPlatform.iOS)
                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                    : AppTheme.primary,
                foregroundColor: (defaultTargetPlatform == TargetPlatform.iOS)
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : Colors.white,
                elevation: 2,
                side: (defaultTargetPlatform == TargetPlatform.iOS)
                    ? BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      )
                    : BorderSide.none,
                shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          (defaultTargetPlatform == TargetPlatform.iOS)
                              ? (isDark ? Colors.white : AppTheme.primary)
                              : Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.g_mobiledata_rounded, size: 30),
                        const SizedBox(width: 6),
                        Text(
                          widget.primaryButtonText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: (defaultTargetPlatform == TargetPlatform.iOS)
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
