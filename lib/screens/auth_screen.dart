import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../services/auth_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (mounted) {
        _showError('Google ile giriş yapılamadı');
      }
    } catch (e) {
      if (mounted) {
        _showError('Bir hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithApple();
      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (mounted) {
        _showError('Apple ile giriş yapılamadı');
      }
    } catch (e) {
      if (mounted) {
        _showError('Bir hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35).withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo ve Başlık
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'FIRSATKOLİK',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En iyi fırsatları keşfedin ve paylaşın',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Google ile Giriş Butonu
                  _buildSocialButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Icons.g_mobiledata,
                    label: 'Google ile Devam Et',
                    backgroundColor: Colors.white,
                    textColor: Colors.black87,
                    borderColor: Colors.grey[300]!,
                  ),
                  const SizedBox(height: 16),
                  
                  // Apple ile Giriş Butonu (sadece iOS)
                  if (Platform.isIOS)
                    _buildSocialButton(
                      onPressed: _isLoading ? null : _signInWithApple,
                      icon: Icons.apple,
                      label: 'Apple ile Devam Et',
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                      borderColor: Colors.black,
                    ),
                  
                  if (_isLoading) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  Text(
                    'Giriş yaparak fırsat paylaşabilir ve\noy verebilirsiniz',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
