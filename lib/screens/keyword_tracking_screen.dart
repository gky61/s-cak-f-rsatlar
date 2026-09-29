import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons/settings_skeleton.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class KeywordTrackingScreen extends StatefulWidget {
  const KeywordTrackingScreen({super.key});

  @override
  State<KeywordTrackingScreen> createState() => _KeywordTrackingScreenState();
}

class _KeywordTrackingScreenState extends State<KeywordTrackingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _keywordController = TextEditingController();
  
  static const int maxKeywordLimit = 30;

  List<String> _watchKeywords = [];
  bool _isLoading = true;
  bool _isAdding = false;
  bool _isNavigatingToSearch = false;

  // Popüler / Hızlı Ekleme Önerileri
  final List<String> _popularSuggestions = [
    'iPhone',
    'PlayStation',
    'Süpermarket',
    'Kulaklık',
    'Laptop',
    'Kahve',
    'Ayakkabı',
    'Televizyon',
  ];

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords() async {
    try {
      final keywords = await _notificationService.getNotificationKeywords();
      if (mounted) {
        setState(() {
          _watchKeywords = keywords;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log('Anahtar kelime yükleme hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showGuestLoginPrompt() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = AppTheme.primary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSub = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.1),
        ),
        backgroundColor: surfaceColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Giriş Yapmalısınız',
                style: GoogleFonts.roboto(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Fırsat radarına anahtar kelime eklemek ve eşleşen fırsatlarda anlık bildirim alabilmek için hesabınıza giriş yapmanız gerekmektedir.',
          style: GoogleFonts.roboto(
            fontSize: 13.5,
            height: 1.45,
            color: textSub,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Daha Sonra',
              style: GoogleFonts.roboto(color: textSub, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Giriş Yap'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addKeyword([String? customKeyword]) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _showGuestLoginPrompt();
      return;
    }

    final keyword = (customKeyword ?? _keywordController.text).trim();
    if (keyword.isEmpty) {
      HapticFeedback.lightImpact();
      _showSnackBar('Lütfen bir anahtar kelime yazın', isWarning: true);
      return;
    }

    if (keyword.length < 2) {
      HapticFeedback.lightImpact();
      _showSnackBar('Anahtar kelime en az 2 karakter olmalıdır', isWarning: true);
      return;
    }

    if (keyword.length > 35) {
      HapticFeedback.lightImpact();
      _showSnackBar('Anahtar kelime en fazla 35 karakter olabilir', isWarning: true);
      return;
    }

    if (_watchKeywords.length >= maxKeywordLimit) {
      HapticFeedback.lightImpact();
      _showSnackBar('Maksimum $maxKeywordLimit anahtar kelime limitine ulaştınız', isWarning: true);
      return;
    }

    final normalized = _notificationService.normalizeKeyword(keyword);
    if (_watchKeywords.map((k) => _notificationService.normalizeKeyword(k)).contains(normalized)) {
      HapticFeedback.lightImpact();
      _showSnackBar('"$keyword" zaten takip listenizde ekli', isWarning: true);
      return;
    }

    setState(() => _isAdding = true);
    HapticFeedback.mediumImpact();

    try {
      await _notificationService.addKeywordSubscription(keyword);
      _notificationService.requestPermission();
      if (mounted) {
        setState(() {
          _watchKeywords.add(keyword);
          if (customKeyword == null) _keywordController.clear();
          _isAdding = false;
        });
        _showSnackBar('✅ "$keyword" takibe eklendi');
      }
    } catch (e) {
      _log('Anahtar kelime ekleme hatası: $e');
      if (mounted) {
        setState(() => _isAdding = false);
        _showSnackBar('Kelime eklenirken hata oluştu', isError: true);
      }
    }
  }

  Future<void> _removeKeyword(String keyword) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _showGuestLoginPrompt();
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      await _notificationService.removeKeywordSubscription(keyword);
      if (mounted) {
        setState(() {
          _watchKeywords.remove(keyword);
        });
        _showSnackBar('🗑️ "$keyword" takipten çıkarıldı');
      }
    } catch (e) {
      _log('Anahtar kelime çıkarma hatası: $e');
    }
  }

  Future<void> _clearAllKeywords() async {
    if (_watchKeywords.isEmpty) return;
    if (_auth.currentUser?.uid == null) {
      _showGuestLoginPrompt();
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSub = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: borderColor, width: 1.1),
          ),
          backgroundColor: surfaceColor,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: AppTheme.error, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Tümünü Sil?',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
            ],
          ),
          content: Text(
            'Takip ettiğiniz tüm anahtar kelimeler radardan silinecektir. Bu işlemi onaylıyor musunuz?',
            style: GoogleFonts.roboto(fontSize: 13.5, height: 1.45, color: textSub),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Vazgeç',
                style: GoogleFonts.roboto(color: textSub, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w700),
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    HapticFeedback.heavyImpact();
    final copyList = List<String>.from(_watchKeywords);
    for (final kw in copyList) {
      await _removeKeyword(kw);
    }
  }

  void _showSnackBar(String message, {bool isWarning = false, bool isError = false}) {
    Color bg = AppTheme.success;
    if (isWarning) bg = Colors.orange[800]!;
    if (isError) bg = AppTheme.error;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.roboto(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    Color textSubColor, {
    IconData? icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: textSubColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = AppTheme.primary;
    final backgroundColor = isDark ? AppTheme.darkBackground : AppTheme.background;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSub = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final isGuest = _auth.currentUser == null;
    final quotaRatio = (_watchKeywords.length / maxKeywordLimit).clamp(0.0, 1.0);

    Color quotaColor = primaryColor;
    if (_watchKeywords.length >= maxKeywordLimit) {
      quotaColor = AppTheme.error;
    } else if (_watchKeywords.length >= 22) {
      quotaColor = const Color(0xFFF59E0B);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Center(
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.1),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: textMain,
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar_rounded, size: 20, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'Fırsat Radarı',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: textMain,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          if (_watchKeywords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: InkWell(
                  onTap: _clearAllKeywords,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.1),
                    ),
                    child: Icon(
                      Icons.delete_sweep_rounded,
                      size: 18,
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const KeywordTrackingSkeleton()
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── GUEST USER PROMPT BANNER ───
                  if (isGuest) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.amber.withValues(alpha: 0.10) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.20),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lock_rounded, color: Colors.amber.shade800, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Misafir Modundasınız',
                                  style: GoogleFonts.roboto(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Canlı radar alarmlarını alabilmek için giriş yapmalısınız.',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey[300] : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _showGuestLoginPrompt,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Giriş Yap'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ─── 1. BİLGİ & İSTATİSTİK KARTI (Hero Status Card) ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: isDark ? 0.16 : 0.10),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: primaryColor.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.radar_rounded,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Canlı Fırsat Radarı',
                                      style: GoogleFonts.roboto(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: textMain,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: AppTheme.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '7/24 Otonom Dinleme',
                                          style: GoogleFonts.roboto(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Quota Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: quotaColor.withValues(alpha: isDark ? 0.18 : 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: quotaColor.withValues(alpha: 0.35), width: 1),
                              ),
                              child: Text(
                                '${_watchKeywords.length} / $maxKeywordLimit Hedef',
                                style: GoogleFonts.roboto(
                                  color: quotaColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Belirlediğin anahtar kelimeler yeni fırsat başlıklarında geçtiğinde cihazına anında özel sesli bildirim gelir.',
                          style: GoogleFonts.roboto(
                            color: textSub,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: quotaRatio,
                            minHeight: 5,
                            backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(quotaColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ─── 2. YENİ KELİME EKLEME BAR ───
                  _buildSectionHeader('YENİ RADAR HEDEFİ', textSub, icon: Icons.add_circle_outline_rounded),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 5, 6, 5),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: primaryColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _keywordController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addKeyword(),
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.roboto(
                              color: textMain,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Örn: iPhone 16, Dyson, Kahve...',
                              hintStyle: GoogleFonts.roboto(
                                color: textSub.withValues(alpha: 0.7),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (_keywordController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _keywordController.clear();
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.cancel_rounded, size: 18, color: textSub.withValues(alpha: 0.5)),
                            ),
                          ),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          onPressed: _isAdding ? null : () => _addKeyword(),
                          icon: _isAdding
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            _isAdding ? 'Ekleniyor' : 'Radara Al',
                            style: GoogleFonts.roboto(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ─── 3. POPÜLER HIZLI EKLEME ÖNERİLERİ ───
                  _buildSectionHeader('POPÜLER ARAMALAR', textSub, icon: Icons.trending_up_rounded),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularSuggestions.map((suggestion) {
                      final isAlreadyAdded = _watchKeywords
                          .map((k) => _notificationService.normalizeKeyword(k))
                          .contains(_notificationService.normalizeKeyword(suggestion));

                      return InkWell(
                        onTap: isAlreadyAdded ? null : () => _addKeyword(suggestion),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isAlreadyAdded
                                ? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9))
                                : surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isAlreadyAdded
                                  ? Colors.transparent
                                  : borderColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAlreadyAdded ? Icons.check_circle_rounded : Icons.add_rounded,
                                size: 14,
                                color: isAlreadyAdded ? AppTheme.success : primaryColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                suggestion,
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  fontWeight: isAlreadyAdded ? FontWeight.w500 : FontWeight.w700,
                                  color: isAlreadyAdded ? textSub.withValues(alpha: 0.7) : textMain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ─── 4. TAKİP EDİLEN KELİMELER LİSTESİ ───
                  _buildSectionHeader(
                    'AKTİF RADARLAR (${_watchKeywords.length})',
                    textSub,
                    icon: Icons.radar_rounded,
                    trailing: _watchKeywords.isNotEmpty
                        ? Text(
                            'Dokun ve Ara',
                            style: GoogleFonts.roboto(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          )
                        : null,
                  ),

                  if (_watchKeywords.isNotEmpty) ...[
                    // Info note
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: isDark ? 0.10 : 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.20), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 16, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mevcut fırsatları listelemek için herhangi bir kelimeye dokunun.',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: _watchKeywords.map((keyword) {
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? primaryColor.withValues(alpha: 0.14)
                                  : primaryColor.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
                                width: 1.1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (_isNavigatingToSearch) return;
                                    _isNavigatingToSearch = true;
                                    HapticFeedback.lightImpact();
                                    HomeScreen.searchKeyword(context, keyword);
                                  },
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.radar_rounded, size: 14, color: primaryColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          keyword,
                                          style: GoogleFonts.roboto(
                                            color: textMain,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 9,
                                          color: primaryColor.withValues(alpha: 0.7),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 18,
                                  width: 1,
                                  color: primaryColor.withValues(alpha: 0.25),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 4, left: 2),
                                  child: InkWell(
                                    onTap: () => _removeKeyword(keyword),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ] else
                    // Boş Durum (Empty State Visual)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.radar_rounded,
                              size: 40,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Henüz Takip Ettiğin Kelime Yok',
                            style: GoogleFonts.roboto(
                              color: textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'İlgilendiğin ürünleri radara ekle; yeni indirimler paylaşıldığında telefonuna anında bildirim gelsin.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              color: textSub,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
