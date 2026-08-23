import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/category.dart';
import '../models/notification_preferences.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons/settings_skeleton.dart';
import 'auth_screen.dart';
import 'notification_settings_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class CategoryPreferencesScreen extends StatefulWidget {
  const CategoryPreferencesScreen({super.key});

  @override
  State<CategoryPreferencesScreen> createState() => _CategoryPreferencesScreenState();
}

class _CategoryPreferencesScreenState extends State<CategoryPreferencesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final Map<String, bool> _categoryStates = {};
  final Map<String, Set<String>> _subCategoryStates = {};
  NotificationPreferences? _notificationPreferences;
  bool _isLoading = true;
  bool _isProcessingBulk = false;

  // 'tumu' hariç kategoriler
  List<Category> get _filteredCategories =>
      Category.categories.where((c) => c.id != 'tumu').toList();

  int get _activeCategoryCount =>
      _categoryStates.values.where((v) => v == true).length;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _showCustomSnackBar({
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
      ),
    );
  }

  void _showGuestLoginPrompt() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Giriş Yapmalısınız',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'Kategori tercihlerinizi kaydetmek ve seçtiğiniz kategorilerde anlık bildirim alabilmek için lütfen hesabınıza giriş yapın.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Daha Sonra'),
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
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPreferences() async {
    try {
      final followedCategories = await _notificationService.getFollowedCategories();
      final followedSubCategories = await _notificationService.getFollowedSubCategories();
      final prefs = await _notificationService.getNotificationPreferences();

      if (mounted) {
        setState(() {
          _notificationPreferences = prefs;
          for (final category in _filteredCategories) {
            _categoryStates[category.id] = followedCategories.contains(category.id);
            _subCategoryStates[category.id] = {};
          }

          // Alt kategorileri yükle
          for (final subCatKey in followedSubCategories) {
            final parts = subCatKey.split(':');
            if (parts.length == 2) {
              final categoryId = parts[0];
              final subCategoryId = parts[1];
              _subCategoryStates[categoryId]?.add(subCategoryId);
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      _log('Kategori tercihleri yüklenirken hata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectAllCategories() async {
    if (_isProcessingBulk) return;
    if (_auth.currentUser?.uid == null) {
      _showGuestLoginPrompt();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessingBulk = true;
      for (final cat in _filteredCategories) {
        _categoryStates[cat.id] = true;
      }
    });

    try {
      for (final cat in _filteredCategories) {
        await _notificationService.subscribeToCategory(cat.id);
      }
      _notificationService.requestPermission();
      if (mounted) {
        _showCustomSnackBar(
          message: 'Tüm kategoriler takip listenize eklendi',
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFF10B981),
        );
      }
    } catch (e) {
      _log('Tümünü seçme hatası: $e');
    } finally {
      if (mounted) setState(() => _isProcessingBulk = false);
    }
  }

  Future<void> _clearAllCategories() async {
    if (_isProcessingBulk) return;
    if (_auth.currentUser?.uid == null) {
      _showGuestLoginPrompt();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessingBulk = true;
      for (final cat in _filteredCategories) {
        _categoryStates[cat.id] = false;
        _subCategoryStates[cat.id]?.clear();
      }
    });

    try {
      for (final cat in _filteredCategories) {
        await _notificationService.unsubscribeFromCategory(cat.id);
      }
      if (mounted) {
        _showCustomSnackBar(
          message: 'Tüm kategori takipleri temizlendi',
          icon: Icons.remove_circle_outline_rounded,
          backgroundColor: const Color(0xFFEF4444),
        );
      }
    } catch (e) {
      _log('Seçimleri temizleme hatası: $e');
    } finally {
      if (mounted) setState(() => _isProcessingBulk = false);
    }
  }

  Future<void> _toggleCategory(String categoryId, bool value) async {
    if (_auth.currentUser?.uid == null) {
      _showGuestLoginPrompt();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _categoryStates[categoryId] = value);

    try {
      if (value) {
        await _notificationService.subscribeToCategory(categoryId);
        _notificationService.requestPermission();
      } else {
        await _notificationService.unsubscribeFromCategory(categoryId);
        final category = _filteredCategories.firstWhere((c) => c.id == categoryId);
        for (final subCat in category.subcategories) {
          if (_subCategoryStates[categoryId]?.contains(subCat) == true) {
            await _notificationService.unsubscribeFromSubCategory(categoryId, subCat);
            _subCategoryStates[categoryId]?.remove(subCat);
          }
        }
        setState(() {});
      }
    } catch (e) {
      _log('Kategori değiştirme hatası: $e');
      setState(() => _categoryStates[categoryId] = !value);
    }
  }

  Future<void> _toggleSubCategory(String categoryId, String subCategoryId, bool value) async {
    if (_auth.currentUser?.uid == null) {
      _showGuestLoginPrompt();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      if (value) {
        _subCategoryStates[categoryId]?.add(subCategoryId);
      } else {
        _subCategoryStates[categoryId]?.remove(subCategoryId);
      }
    });

    try {
      if (value) {
        await _notificationService.subscribeToSubCategory(categoryId, subCategoryId);
      } else {
        await _notificationService.unsubscribeFromSubCategory(categoryId, subCategoryId);
      }
    } catch (e) {
      _log('Alt kategori değiştirme hatası: $e');
      setState(() {
        if (value) {
          _subCategoryStates[categoryId]?.remove(subCategoryId);
        } else {
          _subCategoryStates[categoryId]?.add(subCategoryId);
        }
      });
    }
  }

  IconData _getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'elektronik':
        return Icons.devices_rounded;
      case 'moda':
        return Icons.checkroom_rounded;
      case 'ev_yasam':
        return Icons.home_rounded;
      case 'anne_bebek':
        return Icons.child_care_rounded;
      case 'kozmetik':
        return Icons.face_rounded;
      case 'spor_outdoor':
        return Icons.directions_run_rounded;
      case 'supermarket':
        return Icons.shopping_cart_rounded;
      case 'yapi_oto':
        return Icons.construction_rounded;
      case 'kitap_hobi':
        return Icons.menu_book_rounded;
      case 'dijital_hizmetler':
        return Icons.language_rounded;
      case 'finans_kampanyalar':
        return Icons.credit_card_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'elektronik':
        return const Color(0xFF2196F3);
      case 'moda':
        return const Color(0xFFE91E63);
      case 'ev_yasam':
        return const Color(0xFFFF9800);
      case 'anne_bebek':
        return const Color(0xFF9C27B0);
      case 'kozmetik':
        return const Color(0xFFFF4081);
      case 'spor_outdoor':
        return const Color(0xFF009688);
      case 'supermarket':
        return const Color(0xFF4CAF50);
      case 'yapi_oto':
        return const Color(0xFF607D8B);
      case 'kitap_hobi':
        return const Color(0xFF3F51B5);
      case 'dijital_hizmetler':
        return const Color(0xFF00BCD4);
      case 'finans_kampanyalar':
        return const Color(0xFFFFC107);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final cardColor = isDark ? AppTheme.darkSurface : Colors.white;
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Takip Edilen Kategorilerim',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: textColor,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        foregroundColor: textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: textColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Geri',
        ),
      ),
      body: _isLoading
          ? const CategoryPreferencesSkeleton()
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ─── GUEST USER PROMPT BANNER ───
                if (_auth.currentUser == null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.amber.withValues(alpha: 0.12) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.5),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Misafir modundasınız. Kategori tercihlerinizin kaydedilmesi için giriş yapın.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _showGuestLoginPrompt,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade800,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_notificationPreferences != null &&
                    (!_notificationPreferences!.pushMasterEnabled ||
                        !_notificationPreferences!.categoryNotificationsEnabled)) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.amber.withValues(alpha: 0.12) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.5),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_off_outlined, color: Colors.amber.shade800, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kategori Bildirimleriniz Kapalı',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tercihleriniz kaydedildi ancak telefonunuza bildirim gelebilmesi için Bildirim Ayarlarından kategori bildirimlerini açmanız gerekir.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                            ).then((_) => _loadPreferences());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('Aç'),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1. Üst Modern Bilgi Banner'ı & Sayaç
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: borderColor,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: isDark ? 0.12 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.interests_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Kategorileri Kişiselleştir',
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$_activeCategoryCount / ${_filteredCategories.length} Seçili',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Kategorileri takip ederek size uygun fırsatları kolayca keşfedebilirsiniz. Bildirimleriniz açık ise anlık bildirim alırsınız.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const NotificationSettingsScreen(
                                          highlightChannel: 'category',
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkSurface : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.notifications_active_outlined,
                                          size: 14,
                                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Bildirim Ayarlarına Git',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 13,
                                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Minimalist & Akıllı Aksiyon Barı (Tümünü Seç / Temizle)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'KATEGORİ LİSTESİ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: secondaryTextColor,
                        ),
                      ),
                      Row(
                        children: [
                          // Tümünü Seç Butonu
                          InkWell(
                            onTap: _isProcessingBulk ? null : _selectAllCategories,
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: (_activeCategoryCount == _filteredCategories.length && _filteredCategories.isNotEmpty)
                                    ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12)
                                    : (isDark ? AppTheme.darkSurface : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (_activeCategoryCount == _filteredCategories.length && _filteredCategories.isNotEmpty)
                                      ? const Color(0xFF10B981)
                                      : borderColor,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isProcessingBulk && _activeCategoryCount != 0) ...[
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                                    ),
                                    const SizedBox(width: 6),
                                  ] else ...[
                                    Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: (_activeCategoryCount == _filteredCategories.length && _filteredCategories.isNotEmpty)
                                          ? const Color(0xFF10B981)
                                          : secondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'Tümünü Seç',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: (_activeCategoryCount == _filteredCategories.length && _filteredCategories.isNotEmpty)
                                          ? const Color(0xFF10B981)
                                          : secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Seçimleri Temizle Butonu
                          InkWell(
                            onTap: _isProcessingBulk ? null : _clearAllCategories,
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: _activeCategoryCount == 0
                                    ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12)
                                    : (isDark ? AppTheme.darkSurface : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _activeCategoryCount == 0
                                      ? const Color(0xFFEF4444)
                                      : borderColor,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isProcessingBulk && _activeCategoryCount == 0) ...[
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                                    ),
                                    const SizedBox(width: 6),
                                  ] else ...[
                                    Icon(
                                      Icons.deselect_rounded,
                                      size: 14,
                                      color: _activeCategoryCount == 0
                                          ? const Color(0xFFEF4444)
                                          : secondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'Temizle',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: _activeCategoryCount == 0
                                          ? const Color(0xFFEF4444)
                                          : secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Modern Kategori Listesi
                ..._filteredCategories.map((category) {
                  final isExpanded = _categoryStates[category.id] == true;
                  final categoryColor = _getCategoryColor(category.id);
                  final selectedSubCount = _subCategoryStates[category.id]?.length ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isExpanded
                            ? categoryColor.withValues(alpha: isDark ? 0.5 : 0.4)
                            : borderColor,
                        width: isExpanded ? 1.4 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isExpanded
                              ? categoryColor.withValues(alpha: isDark ? 0.12 : 0.05)
                              : Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Ana Kategori Satırı
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _getCategoryIcon(category.id),
                                color: categoryColor,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              category.name,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: selectedSubCount > 0
                                  ? Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: categoryColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$selectedSubCount alt kategori seçili',
                                            style: TextStyle(
                                              color: categoryColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '${category.subcategories.length} alt kategori',
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                            trailing: Switch.adaptive(
                              value: isExpanded,
                              onChanged: (value) => _toggleCategory(category.id, value),
                              // ignore: deprecated_member_use
                              activeColor: categoryColor,
                              activeTrackColor: categoryColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),

                        // Alt Kategoriler (Çipler)
                        if (isExpanded && category.subcategories.isNotEmpty) ...[
                          Divider(
                            height: 1,
                            thickness: 1.0,
                            color: isDark ? AppTheme.darkBorder : const Color(0xFFF1F5F9),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: category.subcategories.map((subCat) {
                                final isSelected = _subCategoryStates[category.id]?.contains(subCat) == true;
                                return FilterChip(
                                  label: Text(
                                    subCat,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : textColor,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (value) => _toggleSubCategory(category.id, subCat, value),
                                  backgroundColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                                  selectedColor: categoryColor,
                                  checkmarkColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.transparent
                                        : borderColor,
                                    width: 0.8,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
