import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/privacy_policy_screen.dart';

/// E-posta ile giriş, kayıt ve şifre sıfırlama işlemlerini sunan modern modal penceresi
Future<bool?> showEmailAuthBottomSheet(
  BuildContext context, {
  VoidCallback? onLoginSuccess,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => EmailAuthBottomSheet(
      onLoginSuccess: onLoginSuccess,
    ),
  );
}

enum _AuthMode { signIn, signUp, forgotPassword }

class EmailAuthBottomSheet extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const EmailAuthBottomSheet({
    super.key,
    this.onLoginSuccess,
  });

  @override
  State<EmailAuthBottomSheet> createState() => _EmailAuthBottomSheetState();
}

class _EmailAuthBottomSheetState extends State<EmailAuthBottomSheet> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  _AuthMode _mode = _AuthMode.signIn;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  // FS-AUTH-10: Şifre sıfırlama için 60s cooldown ticker'ı
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    if (_mode == _AuthMode.forgotPassword) {
      final email = _emailController.text.trim();
      final remaining = AuthService.getPasswordResetCooldownRemaining(email);
      if (remaining != _cooldownSeconds) {
        _startCooldownTimer(remaining);
      }
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    if (seconds <= 0) {
      if (_cooldownSeconds != 0 && mounted) {
        setState(() => _cooldownSeconds = 0);
      }
      return;
    }
    if (mounted) {
      setState(() => _cooldownSeconds = seconds);
    }
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  void _clearInlineMessages() {
    if (_errorMessage != null || _successMessage != null) {
      setState(() {
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }

  void _switchMode(_AuthMode newMode) {
    if (_isLoading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = newMode;
      _errorMessage = null;
      _successMessage = null;
      _formKey.currentState?.reset();
    });

    // FS-AUTH-10: Şifremi unuttum moduna geçildiğinde mevcut e-posta için kalan süreyi kontrol et
    if (newMode == _AuthMode.forgotPassword) {
      final email = _emailController.text.trim();
      final remaining = AuthService.getPasswordResetCooldownRemaining(email);
      if (remaining > 0) {
        _startCooldownTimer(remaining);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    
    // Klavyeyi pürüzsüzce kapat
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    try {
      if (_mode == _AuthMode.forgotPassword) {
        await _authService.sendPasswordResetEmail(email: email);
        _startCooldownTimer(AuthService.passwordResetCooldown.inSeconds);
        if (mounted) {
          setState(() {
            _successMessage = 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi. Lütfen gelen kutunuzu kontrol edin.';
          });
          _showSnackBar(
            'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.',
            isError: false,
          );
        }
      } else if (_mode == _AuthMode.signUp) {
        final user = await _authService.signUpWithEmail(
          email: email,
          password: password,
          username: username,
        );
        if (user != null && mounted) {
          final displayName = user.displayName.isNotEmpty ? user.displayName : user.username;
          _showSnackBar('Aramıza hoş geldiniz, $displayName! 🎉', isError: false);
          Navigator.of(context).pop(true);
          widget.onLoginSuccess?.call();
        }
      } else {
        // Giriş Yap
        final user = await _authService.signInWithEmail(
          email: email,
          password: password,
        );
        if (user != null && mounted) {
          final displayName = user.displayName.isNotEmpty ? user.displayName : user.username;
          _showSnackBar('Tekrar hoş geldiniz, $displayName! 👋', isError: false);
          Navigator.of(context).pop(true);
          widget.onLoginSuccess?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('AuthException: ', '').replaceAll('Exception: ', '').trim();
        setState(() {
          _errorMessage = msg;
        });
        _showSnackBar(msg, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final textMain = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final textSub = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Başlık & İkon & Kapatma Butonu
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _mode == _AuthMode.forgotPassword
                            ? Icons.lock_reset_rounded
                            : (_mode == _AuthMode.signUp ? Icons.person_add_rounded : Icons.alternate_email_rounded),
                        size: 24,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mode == _AuthMode.forgotPassword
                                ? 'Şifremi Unuttum'
                                : (_mode == _AuthMode.signUp ? 'Yeni Hesap Oluştur' : 'E-posta ile Giriş Yap'),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _mode == _AuthMode.forgotPassword
                                ? 'Sıfırlama bağlantısı e-posta adresinize gönderilir'
                                : (_mode == _AuthMode.signUp
                                    ? 'Fırsat avcıları topluluğuna hemen katılın'
                                    : 'Hesabınıza güvenle erişim sağlayın'),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: textSub, size: 22),
                      splashRadius: 20,
                      tooltip: 'Kapat',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Giriş / Kayıt Segment Switcher (Şifremi unuttum modunda değilken)
                if (_mode != _AuthMode.forgotPassword) ...[
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: inputBorder, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _switchMode(_AuthMode.signIn),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: _mode == _AuthMode.signIn
                                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: _mode == _AuthMode.signIn
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1.5),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Giriş Yap',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _mode == _AuthMode.signIn ? FontWeight.w700 : FontWeight.w600,
                                  color: _mode == _AuthMode.signIn ? AppTheme.primary : textSub,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _switchMode(_AuthMode.signUp),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: _mode == _AuthMode.signUp
                                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: _mode == _AuthMode.signUp
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1.5),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Kayıt Ol',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _mode == _AuthMode.signUp ? FontWeight.w700 : FontWeight.w600,
                                  color: _mode == _AuthMode.signUp ? AppTheme.primary : textSub,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // 1. Kullanıcı Adı (Yalnızca Kayıt Olurken)
                if (_mode == _AuthMode.signUp) ...[
                  TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_emailFocus);
                    },
                    onChanged: (_) => _clearInlineMessages(),
                    style: TextStyle(color: textMain, fontSize: 15),
                    decoration: _buildInputDecoration(
                      labelText: 'Kullanıcı Adı',
                      hintText: 'Örn: firsatavcisi',
                      prefixIcon: Icons.badge_outlined,
                      inputBg: inputBg,
                      inputBorder: inputBorder,
                      isDark: isDark,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Lütfen bir kullanıcı adı belirleyin.';
                      }
                      if (val.trim().length < 3) {
                        return 'Kullanıcı adı en az 3 karakter olmalıdır.';
                      }
                      if (val.trim().length > 30) {
                        return 'Kullanıcı adı en fazla 30 karakter olabilir.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // 2. E-posta Alanı (Tüm modlarda)
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: _mode == _AuthMode.forgotPassword ? TextInputAction.done : TextInputAction.next,
                  onFieldSubmitted: (_) {
                    if (_mode == _AuthMode.forgotPassword) {
                      _handleSubmit();
                    } else {
                      FocusScope.of(context).requestFocus(_passwordFocus);
                    }
                  },
                  onChanged: (_) => _clearInlineMessages(),
                  style: TextStyle(color: textMain, fontSize: 15),
                  decoration: _buildInputDecoration(
                    labelText: 'E-posta Adresi',
                    hintText: 'ornek@firsatkolik.app',
                    prefixIcon: Icons.alternate_email_rounded,
                    inputBg: inputBg,
                    inputBorder: inputBorder,
                    isDark: isDark,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Lütfen e-posta adresinizi girin.';
                    }
                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(val.trim())) {
                      return 'Lütfen geçerli bir e-posta adresi yazın.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. Şifre Alanı (Giriş ve Kayıt modlarında)
                if (_mode != _AuthMode.forgotPassword) ...[
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    autofillHints: [
                      _mode == _AuthMode.signUp ? AutofillHints.newPassword : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    onChanged: (_) => _clearInlineMessages(),
                    style: TextStyle(color: textMain, fontSize: 15),
                    decoration: _buildInputDecoration(
                      labelText: 'Şifre',
                      hintText: 'En az 6 karakter',
                      prefixIcon: Icons.lock_outline_rounded,
                      inputBg: inputBg,
                      inputBorder: inputBorder,
                      isDark: isDark,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: textSub,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Lütfen şifrenizi girin.';
                      }
                      if (val.length < 6) {
                        return 'Şifre en az 6 karakter olmalıdır.';
                      }
                      return null;
                    },
                  ),
                ],

                // Şifremi Unuttum Butonu (Sadece Giriş modunda)
                if (_mode == _AuthMode.signIn) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => _switchMode(_AuthMode.forgotPassword),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Şifremi Unuttum',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(height: 6),

                // Inline Hata / Başarı Banner'ı
                if (_errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.35), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_successMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.35), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: AppTheme.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Ana Aksiyon Butonu
                Builder(
                  builder: (context) {
                    final isForgotMode = _mode == _AuthMode.forgotPassword;
                    final isCooldownActive = isForgotMode && _cooldownSeconds > 0;
                    final isButtonDisabled = _isLoading || isCooldownActive;

                    String buttonText;
                    if (isForgotMode) {
                      buttonText = isCooldownActive
                          ? 'Tekrar Gönder ($_cooldownSeconds sn)'
                          : 'Sıfırlama Bağlantısı Gönder';
                    } else if (_mode == _AuthMode.signUp) {
                      buttonText = 'Kayıt Ol ve Başla';
                    } else {
                      buttonText = 'Giriş Yap';
                    }

                    return SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isButtonDisabled ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCooldownActive
                              ? (isDark ? Colors.white12 : Colors.black12)
                              : AppTheme.primary,
                          foregroundColor: isCooldownActive
                              ? (isDark ? Colors.white54 : Colors.black54)
                              : Colors.white,
                          disabledBackgroundColor: isCooldownActive
                              ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                              : (isDark ? Colors.white10 : Colors.black12),
                          disabledForegroundColor: isCooldownActive
                              ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                              : (isDark ? Colors.white38 : Colors.black38),
                          elevation: isCooldownActive ? 0 : 2,
                          shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isCooldownActive) ...[
                                    const Icon(Icons.timer_outlined, size: 18),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    buttonText,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: isCooldownActive
                                          ? (isDark ? Colors.white60 : Colors.black54)
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),

                // Şifremi unuttum modundayken "Giriş Yap'a Dön" butonu
                if (_mode == _AuthMode.forgotPassword) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _isLoading ? null : () => _switchMode(_AuthMode.signIn),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'Giriş Yap ekranına geri dön',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: textSub,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Yasal Metin & Gizlilik Sözleşmesi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                      );
                    },
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(fontSize: 11.5, color: textSub.withValues(alpha: 0.8), height: 1.35),
                        children: const [
                          TextSpan(text: 'Devam ederek '),
                          TextSpan(
                            text: 'Kullanım Koşulları ve Gizlilik Politikası',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: '\'nı kabul etmiş sayılırsınız.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    required Color inputBg,
    required Color inputBorder,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13.5, color: isDark ? Colors.white30 : Colors.black26),
      labelStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF475569)),
      prefixIcon: Icon(prefixIcon, size: 20, color: AppTheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: inputBorder, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: inputBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.8),
      ),
    );
  }
}
