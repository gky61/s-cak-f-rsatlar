import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

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
  
  List<String> _watchKeywords = [];
  bool _isLoading = true;
  bool _isAdding = false;
  bool _showInfoBanner = true;

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
    _loadBannerState();
    _loadKeywords();
  }

  Future<void> _loadBannerState() async {
    final prefs = await SharedPreferences.getInstance();
    final isDismissed = prefs.getBool('keyword_info_banner_dismissed') ?? false;
    if (mounted && isDismissed) {
      setState(() {
        _showInfoBanner = false;
      });
    }
  }

  Future<void> _dismissBanner() async {
    setState(() {
      _showInfoBanner = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keyword_info_banner_dismissed', true);
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

  Future<void> _addKeyword([String? customKeyword]) async {
    final keyword = (customKeyword ?? _keywordController.text).trim();
    if (keyword.isEmpty) {
      HapticFeedback.lightImpact();
      _showSnackBar('Lütfen bir anahtar kelime yazın', isWarning: true);
      return;
    }

    final normalized = _notificationService.normalizeKeyword(keyword);
    if (_watchKeywords.map((k) => _notificationService.normalizeKeyword(k)).contains(normalized)) {
      HapticFeedback.lightImpact();
      _showSnackBar('"$keyword" zaten takip listenizde ekli', isWarning: true);
      return;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isAdding = true);
    HapticFeedback.mediumImpact();

    try {
      await _notificationService.addKeywordSubscription(keyword);
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
    if (userId == null) return;

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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF5350)),
              const SizedBox(width: 10),
              const Text('Tümünü Sil?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Takip ettiğiniz tüm anahtar kelimeler silinecektir. Emin misiniz?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    Color bg = const Color(0xFF2E7D32);
    if (isWarning) bg = Colors.orange[800]!;
    if (isError) bg = const Color(0xFFC62828);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : AppTheme.textPrimary;
    final textSub = isDark ? Colors.grey[400] : AppTheme.textSecondary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Anahtar Kelime Takibi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: textMain,
        elevation: 0,
        actions: [
          if (_watchKeywords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: InkWell(
                  onTap: _clearAllKeywords,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF381B1B) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFEF5350).withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFC62828)),
                        SizedBox(width: 4),
                        Text(
                          'Temizle',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── 1. BİLGİ & İSTATİSTİK KARTI (Kullanıcı dilerse çarpı ile kapatabilir) ───
                  if (_showInfoBanner) ...[
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 16, 36, 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      primaryColor.withValues(alpha: 0.20),
                                      primaryColor.withValues(alpha: 0.08),
                                    ]
                                  : [
                                      primaryColor.withValues(alpha: 0.12),
                                      primaryColor.withValues(alpha: 0.04),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.notifications_active_rounded,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Canlı İndirim Takibi',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: textMain,
                                          ),
                                        ),
                                        // Takip Edilen Kelime Rozeti
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${_watchKeywords.length} Kelime Takipte',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Eklediğiniz anahtar kelimeler yeni paylaşılan fırsat başlıklarında geçtiğinde özel bildirim alırsınız.',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Net Belirgin Kapatma Çarpısı (Sağ Üst Köşede)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: _dismissBanner,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── 2. YENİ KELİME EKLEME BAR ───
                  Text(
                    'YENİ KELİME EKLE',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Icon(Icons.search_rounded, color: textSub, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _keywordController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addKeyword(),
                            style: TextStyle(
                              color: textMain,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Örn: iPhone, kahve, robot süpürge...',
                              hintStyle: TextStyle(
                                color: textSub?.withValues(alpha: 0.7),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isAdding ? null : () => _addKeyword(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isAdding
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, size: 18),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ekle',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── 3. POPÜLER HIZLI EKLEME ÖNERİLERİ ───
                  Text(
                    'POPÜLER ARAMALAR',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: textSub,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularSuggestions.map((suggestion) {
                      final isAlreadyAdded = _watchKeywords
                          .map((k) => _notificationService.normalizeKeyword(k))
                          .contains(_notificationService.normalizeKeyword(suggestion));

                      return InkWell(
                        onTap: isAlreadyAdded ? null : () => _addKeyword(suggestion),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isAlreadyAdded
                                ? (isDark ? Colors.white10 : Colors.grey[200])
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isAlreadyAdded
                                  ? Colors.transparent
                                  : (isDark ? Colors.white24 : Colors.grey[300]!),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAlreadyAdded ? Icons.check_rounded : Icons.add_rounded,
                                size: 14,
                                color: isAlreadyAdded
                                    ? Colors.grey
                                    : primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                suggestion,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isAlreadyAdded ? FontWeight.w500 : FontWeight.w700,
                                  color: isAlreadyAdded ? Colors.grey : textMain,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TAKİP ETTİĞİNİZ KELİMELER',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '${_watchKeywords.length} kelime',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_watchKeywords.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: _watchKeywords.map((keyword) {
                          return Container(
                            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? primaryColor.withValues(alpha: 0.15)
                                  : primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  keyword,
                                  style: TextStyle(
                                    color: textMain,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _removeKeyword(keyword),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF5350).withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Color(0xFFEF5350),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  else
                    // Boş Durum (Empty State Visual)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.label_off_rounded,
                              size: 48,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz takip edilen kelime yok',
                            style: TextStyle(
                              color: textMain,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Yukarıdaki arama çubuğundan veya popüler önerilerden kelime ekleyerek başlayın.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
