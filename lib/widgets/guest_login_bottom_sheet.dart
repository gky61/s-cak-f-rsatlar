import 'package:flutter/material.dart';
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
      primaryButtonText: primaryButtonText ?? '🚀 Google ile Giriş Yap',
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

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

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
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tutamaç çizgisi
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

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

          // Google ile Tek Tıkla Giriş Butonu
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.primaryButtonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
