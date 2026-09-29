import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:app_settings/app_settings.dart';
import '../services/notification_service.dart';
import '../models/notification_preferences.dart';
import 'category_preferences_screen.dart';
import 'keyword_tracking_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons/settings_skeleton.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class NotificationSettingsScreen extends StatefulWidget {
  final String? highlightChannel;

  const NotificationSettingsScreen({
    super.key,
    this.highlightChannel,
  });

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  
  NotificationPreferences _preferences = NotificationPreferences.defaultPreferences();
  
  String _systemPermissionStatus = 'checking';
  bool _isLoading = true;
  int _followedCategoryCount = 0;

  final GlobalKey _categoryTileKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _isCategoryHighlighted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllSettings();

    if (widget.highlightChannel == 'category') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        if (_categoryTileKey.currentContext != null) {
          Scrollable.ensureVisible(
            _categoryTileKey.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            alignment: 0.35,
          );
        }
        setState(() {
          _isCategoryHighlighted = true;
        });
        await Future.delayed(const Duration(milliseconds: 3000));
        if (mounted) {
          setState(() {
            _isCategoryHighlighted = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSystemPermission();
      // iOS bazen ayar değişimini OS seviyesinde 300ms gecikmeli yansıtabilir; garanti çift kontrol:
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _checkSystemPermission();
      });
    }
  }

  Future<void> _checkSystemPermission() async {
    final status = await _notificationService.checkSystemPermissionStatus();
    if (mounted) {
      setState(() {
        _systemPermissionStatus = status;
      });
      if (status == 'authorized') {
        _notificationService.saveFCMToken();
      }
    }
  }

  Future<void> _loadAllSettings() async {
    setState(() => _isLoading = true);
    try {
      await _checkSystemPermission();
      
      final prefs = await _notificationService.getNotificationPreferences();
      final followedCats = await _notificationService.getFollowedCategories();
      
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _followedCategoryCount = followedCats.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDisabledSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2C2C2C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updatePrefs(NotificationPreferences newPrefs) async {
    final oldPrefs = _preferences;
    setState(() {
      _preferences = newPrefs;
    });
    try {
      await _notificationService.updateNotificationPreferences(newPrefs);
    } catch (e) {
      _log('Error updating preferences: $e');
      if (mounted) {
        setState(() {
          _preferences = oldPrefs;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ayarlarınız güncellenemedi, lütfen bağlantınızı kontrol edin.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    if (!_preferences.pushMasterEnabled) {
      _showDisabledSnackbar('Bu ayarı değiştirmek için önce yukarıdan Telefon Bildirimleri\'ni açmalısınız.');
      return;
    }

    final initialTimeStr = isStart ? _preferences.quietHoursStart : _preferences.quietHoursEnd;
    final parts = initialTimeStr.split(':');
    final initialHour = parts.length == 2 ? int.tryParse(parts[0]) ?? 0 : 0;
    final initialMinute = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final newTime = '$hourStr:$minuteStr';

      _updatePrefs(_preferences.copyWith(
        quietHoursStart: isStart ? newTime : _preferences.quietHoursStart,
        quietHoursEnd: isStart ? _preferences.quietHoursEnd : newTime,
      ));
    }
  }

  Widget _buildChannelTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Key? key,
    bool isHighlighted = false,
  }) {
    final isMasterOn = _preferences.pushMasterEnabled;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tile = AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isHighlighted
            ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(
                color: primaryColor.withValues(alpha: isDark ? 0.8 : 0.6),
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
              color: isHighlighted ? primaryColor : null,
            ),
          ),
          subtitle: Text(subtitle),
          value: value,
          activeThumbColor: primaryColor,
          onChanged: isMasterOn ? onChanged : null,
        ),
      ),
    );

    if (!isMasterOn) {
      return Opacity(
        opacity: 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showDisabledSnackbar(
            'Bu ayarı değiştirmek için önce yukarıdan Telefon Bildirimleri\'ni açmalısınız.',
          ),
          child: IgnorePointer(child: tile),
        ),
      );
    }
    return tile;
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool channelEnabled,
    required String channelName,
    required VoidCallback onTap,
    String? trailingBadge,
  }) {
    final isMasterOn = _preferences.pushMasterEnabled;
    final isFullyActive = isMasterOn && channelEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final card = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.05) 
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: isFullyActive ? primaryColor : Colors.grey),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingBadge != null && trailingBadge.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFullyActive ? primaryColor : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trailingBadge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
          ],
        ),
          onTap: isFullyActive ? onTap : null,
        ),
      ),
    );

    if (!isFullyActive) {
      final String warningMessage = !isMasterOn
          ? 'Bu ayarı değiştirmek için önce yukarıdan Telefon Bildirimleri\'ni açmalısınız.'
          : 'Bu ayarı değiştirmek için önce $channelName\'ni açmalısınız.';

      return Opacity(
        opacity: 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showDisabledSnackbar(warningMessage),
          child: IgnorePointer(child: card),
        ),
      );
    }

    return card;
  }

  Widget _buildSystemPermissionBanner({
    required BuildContext context,
    required Color textMain,
    required Color? textSub,
  }) {
    // Sistem bildirimi açık veya henüz ilk yükleme kontrolünde ise gizle
    if (_systemPermissionStatus == 'authorized' || _systemPermissionStatus == 'checking') {
      return const SizedBox.shrink();
    }

    final isDenied = _systemPermissionStatus == 'denied';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Reddedilmiş durum (denied): Kırmızı tonlar
    // Henüz sorulmamış/onaylanmamış durum (notDetermined - iOS): Apple HIG uyumlu dikkat çekici amber/turuncu tonlar
    final Color accentColor = isDenied
        ? Colors.red
        : (isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00));

    final Color backgroundColor = isDenied
        ? Colors.red.withValues(alpha: isDark ? 0.15 : 0.08)
        : (isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.15) : const Color(0xFFFFF3E0));

    final Color borderColor = isDenied
        ? Colors.red.withValues(alpha: isDark ? 0.35 : 0.25)
        : (isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.35) : const Color(0xFFFFE0B2));

    final String title = isDenied
        ? 'Cihaz Bildirim İzinleri Kapalı'
        : 'Bildirim İzinleri Aktif Değil';

    final String description = isDenied
        ? 'Fırsat bildirimlerini telefonunuza alabilmek için sistem ayarlarından bildirimleri aktif etmeniz gerekmektedir.'
        : 'Sıcak indirimleri, kuponları ve anlık fırsatları kaçırmamak için bildirim izinlerini etkinleştirin.';

    final IconData iconData = isDenied
        ? Icons.warning_amber_rounded
        : Icons.notification_important_outlined;

    final IconData buttonIcon = isDenied
        ? Icons.settings
        : Icons.notifications_active_outlined;

    final String buttonLabel = isDenied
        ? 'Ayarlara Git'
        : 'Bildirimleri Aç';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                iconData,
                color: accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: textSub,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (isDenied) {
                  await AppSettings.openAppSettings(type: AppSettingsType.notification);
                } else {
                  await _notificationService.requestPermission();
                  await _checkSystemPermission();
                }
              },
              icon: Icon(buttonIcon, size: 18),
              label: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDenied ? Colors.red : primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final Color textMain = isDark ? Colors.white : const Color(0xFF1C1C0D);
    final Color textSub = isDark ? (Colors.grey[400] ?? Colors.grey) : const Color(0xFF5C5C4F);

    final isMasterOn = _preferences.pushMasterEnabled;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bildirim Ayarları',
          style: TextStyle(
            color: textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const NotificationSettingsSkeleton()
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System permission warning banner (Apple HIG & Android adaptive)
                  _buildSystemPermissionBanner(
                    context: context,
                    textMain: textMain,
                    textSub: textSub,
                  ),

                  // Katman 1: Master Switch (Telefon Bildirimleri)
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.05) 
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        title: Text(
                          'Telefon Bildirimleri',
                          style: TextStyle(
                            color: textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Kapatıldığında telefonunuza hiçbir anlık uyarı gelmez; ancak tüm bildirimleri uygulama içindeki Bildirim Kutusu\'ndan takip edebilirsiniz.',
                          style: TextStyle(color: textSub, fontSize: 12),
                        ),
                        value: _preferences.pushMasterEnabled,
                        activeThumbColor: primaryColor,
                        onChanged: (val) async {
                          if (val) {
                            await _notificationService.requestPermission();
                            await _checkSystemPermission();
                          }
                          // STATE PRESERVATION: Only toggle pushMasterEnabled, keep all sub-channel states preserved!
                          _updatePrefs(_preferences.copyWith(pushMasterEnabled: val));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'BİLDİRİM KANALLARI',
                    style: TextStyle(
                      color: textSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Katman 2: Notification Groups (Channels)
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.05) 
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildChannelTile(
                          title: 'Takip Edilen Yazar Bildirimleri',
                          subtitle: 'Profillerinden bildirimlerini (zilini) açtığınız usta avcıların paylaştığı yeni fırsatlar.',
                          value: _preferences.dealNotificationsEnabled,
                          onChanged: (val) {
                            _updatePrefs(_preferences.copyWith(dealNotificationsEnabled: val));
                          },
                        ),
                        const Divider(height: 1),
                        _buildChannelTile(
                          title: 'Topluluk Bildirimleri',
                          subtitle: 'Topluluk tarafından paylaşılan yeni indirim kuponları, paylaşımlarınıza gelen yorumlar ve yanıtlar.',
                          value: _preferences.communityNotificationsEnabled,
                          onChanged: (val) {
                            _updatePrefs(_preferences.copyWith(communityNotificationsEnabled: val));
                          },
                        ),
                        const Divider(height: 1),
                        _buildChannelTile(
                          title: 'Kampanya Bildirimleri',
                          subtitle: 'Özel kampanyalar, hediye çekleri ve önemli sistem duyuruları',
                          value: _preferences.marketingNotificationsEnabled,
                          onChanged: (val) {
                            _updatePrefs(_preferences.copyWith(marketingNotificationsEnabled: val));
                          },
                        ),
                        const Divider(height: 1),
                        _buildChannelTile(
                          key: _categoryTileKey,
                          isHighlighted: _isCategoryHighlighted,
                          title: 'Kategori Bildirimleri',
                          subtitle: 'Takip ettiğiniz alışveriş kategorilerine eklenen yeni fırsatlar',
                          value: _preferences.categoryNotificationsEnabled,
                          onChanged: (val) {
                            _updatePrefs(_preferences.copyWith(categoryNotificationsEnabled: val));
                          },
                        ),
                        const Divider(height: 1),
                        _buildChannelTile(
                          title: 'Anahtar Kelime Takibi Bildirimleri',
                          subtitle: 'Takip listenizdeki kelimeleri içeren yeni fırsatlardan haberdar olun',
                          value: _preferences.keywordNotificationsEnabled,
                          onChanged: (val) {
                            _updatePrefs(_preferences.copyWith(keywordNotificationsEnabled: val));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'SESSİZ SAATLER',
                    style: TextStyle(
                      color: textSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quiet Hours
                  Opacity(
                    opacity: isMasterOn ? 1.0 : 0.5,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: !isMasterOn
                          ? () => _showDisabledSnackbar(
                              'Bu ayarı değiştirmek için önce yukarıdan Telefon Bildirimleri\'ni açmalısınız.')
                          : null,
                      child: IgnorePointer(
                        ignoring: !isMasterOn,
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.05) 
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Sessiz Saatler'),
                                  subtitle: const Text('Belirlediğiniz saat aralığında telefonunuza anlık sesli uyarı gelmez; bildirimler sessizce Bildirim Kutusu\'na kaydedilir.'),
                                  value: _preferences.quietHoursEnabled,
                                  activeThumbColor: primaryColor,
                                  onChanged: (val) {
                                    _updatePrefs(_preferences.copyWith(quietHoursEnabled: val));
                                  },
                                ),
                                if (_preferences.quietHoursEnabled) ...[
                                  const Divider(height: 1),
                                  ListTile(
                                    title: const Text('Başlangıç Saati'),
                                    trailing: Text(
                                      _preferences.quietHoursStart,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    onTap: () => _selectTime(context, true),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    title: const Text('Bitiş Saati'),
                                    trailing: Text(
                                      _preferences.quietHoursEnd,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    onTap: () => _selectTime(context, false),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'BİLDİRİM TERCİHLERİ / DETAYLARI',
                    style: TextStyle(
                      color: textSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Katman 3: Detay Tercih Satırları (Chevron >)
                  _buildDetailTile(
                    icon: Icons.interests_rounded,
                    title: 'Takip Edilen Kategoriler',
                    subtitle: _followedCategoryCount > 0
                        ? '$_followedCategoryCount kategori takip ediliyor'
                        : 'Henüz kategori seçilmedi. Düzenlemek için dokunun',
                    channelEnabled: _preferences.categoryNotificationsEnabled,
                    channelName: 'Kategori Bildirimleri',
                    trailingBadge: _followedCategoryCount > 0 ? '$_followedCategoryCount' : null,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategoryPreferencesScreen(),
                        ),
                      );
                      final cats = await _notificationService.getFollowedCategories();
                      if (mounted) {
                        setState(() => _followedCategoryCount = cats.length);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDetailTile(
                    icon: Icons.label_important_outline,
                    title: 'Anahtar Kelimeler',
                    subtitle: 'Takip ettiğiniz özel ürün kelimelerini yönetin',
                    channelEnabled: _preferences.keywordNotificationsEnabled,
                    channelName: 'Anahtar Kelime Takibi Bildirimleri',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KeywordTrackingScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

