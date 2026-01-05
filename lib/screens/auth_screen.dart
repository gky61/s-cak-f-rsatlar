import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'admin_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isSignUp = false; // Kayıt ol / Giriş yap modu
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    // Mobil platformda otomatik Google Sign-In başlat
    if (!kIsWeb) {
      // Kısa bir gecikme ile Google Sign-In'i başlat (ekran render olsun)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isLoading) {
            _signInWithGoogle();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogleWeb() async {
    if (_isLoading) return; // Double-tap koruması
    
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        final isAdmin = await _authService.isAdmin();
        if (isAdmin) {
          _showSuccess('Admin paneline yönlendiriliyorsunuz...');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminScreen()),
            );
          }
        } else {
          await _authService.signOut();
          _showError('Bu hesap admin yetkisine sahip değil.');
        }
      }
    } on AuthException catch (e) {
      if (mounted && !e.message.contains('iptal')) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Beklenmeyen bir hata oluştu.';
        if (e.toString().contains('People API')) {
          errorMessage = 'People API etkinleştirilmeli. Email/Şifre ile giriş yapın.';
        } else if (e.toString().contains('popup')) {
          errorMessage = 'Popup engelleyiciyi kapatıp tekrar deneyin.';
        }
        _showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return; // Double-tap koruması
    
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        // Başarılı giriş
        _showSuccess('Hoş geldiniz, ${user.username}!');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
      // user == null ise kullanıcı iptal etti, hata gösterme
    } on AuthException catch (e) {
      // Kullanıcı dostu hata mesajı
      if (mounted && !e.message.contains('iptal')) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithEmailPassword() async {
    if (_isLoading) return; // Double-tap koruması
    
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        // Kayıt ol
        final user = await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
        );
        
        if (user != null && mounted) {
          _showSuccess('Kayıt başarılı! Şimdi admin yetkisi için bekleyin.');
          setState(() {
            _isSignUp = false;
            _usernameController.clear();
          });
        }
      } else {
        // Giriş yap
        final user = await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        if (user != null) {
          final isAdmin = await _authService.isAdmin();
          if (isAdmin) {
            if (mounted) {
              _showSuccess('Admin paneline yönlendiriliyorsunuz...');
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                );
              }
            }
          } else {
            if (mounted) {
              await _authService.signOut();
              _showError('Bu hesap admin yetkisine sahip değil.');
            }
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Beklenmeyen bir hata oluştu.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (_isLoading) return; // Double-tap koruması
    
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithApple();
      if (user != null && mounted) {
        _showSuccess('Hoş geldiniz, ${user.username}!');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted && !e.message.contains('iptal')) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.');
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
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35).withValues(alpha: 0.1),
              isDark ? AppTheme.darkBackground : Colors.white,
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
                  
                  // Web için sadece Email/Şifre (Google Sign-In web'de çalışmıyor)
                  if (kIsWeb) ...[
                    Text(
                      'Admin Girişi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Kayıt ol / Giriş yap toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isSignUp = false),
                          child: Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: _isSignUp ? FontWeight.normal : FontWeight.bold,
                              color: _isSignUp ? Colors.grey : const Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                        Text(
                          ' / ',
                          style: TextStyle(color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _isSignUp = true),
                          child: Text(
                            'Kayıt Ol',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: _isSignUp ? FontWeight.bold : FontWeight.normal,
                              color: _isSignUp ? const Color(0xFFFF6B35) : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildEmailPasswordForm(isDark, textColor),
                  ] else ...[
                    // Mobil için Google ile Giriş Butonu
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
                    if (defaultTargetPlatform == TargetPlatform.iOS)
                      _buildSocialButton(
                        onPressed: _isLoading ? null : _signInWithApple,
                        icon: Icons.apple,
                        label: 'Apple ile Devam Et',
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        borderColor: Colors.black,
                      ),
                  ],
                  
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

  Widget _buildEmailPasswordForm(bool isDark, Color textColor) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isSignUp) ...[
            TextFormField(
              controller: _usernameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Kullanıcı Adı',
                prefixIcon: const Icon(Icons.person_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kullanıcı adı gerekli';
                }
                if (value.length < 3) {
                  return 'Kullanıcı adı en az 3 karakter olmalı';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email gerekli';
              }
              if (!value.contains('@')) {
                return 'Geçerli bir email adresi girin';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Şifre gerekli';
              }
              if (value.length < 6) {
                return 'Şifre en az 6 karakter olmalı';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signInWithEmailPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isSignUp ? 'Kayıt Ol' : 'Giriş Yap',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isSignUp 
                ? 'Kayıt olduktan sonra Firebase Console\'dan bu kullanıcıyı admin yapın'
                : 'Web üzerinden sadece admin kullanıcılar giriş yapabilir',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
