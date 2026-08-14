import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:app_settings/app_settings.dart';
import '../services/notification_service.dart';
import '../models/notification_preferences.dart';
import 'category_preferences_screen.dart';
import 'keyword_tracking_screen.dart';
import '../theme/app_theme.dart';

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
  
  String _systemPermissionStatus = 'authorized';
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
    }
  }

  Future<void> _checkSystemPermission() async {
    final status = await _notificationService.checkSystemPermissionStatus();
    if (mounted) {
      setState(() {
        _systemPermissionStatus = status;
      });
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: isFullyActive ? onTap : null,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : const Color(0xFF1C1C0D);
    final textSub = isDark ? Colors.grey[400] : const Color(0xFF5C5C4F);

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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System permission warning banner
                  if (_systemPermissionStatus == 'denied') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cihaz Bildirim İzinleri Kapalı',
                                  style: TextStyle(
                                    color: textMain,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fırsat bildirimlerini telefonunuza alabilmek için sistem ayarlarından bildirimleri aktif etmeniz gerekmektedir.',
                            style: TextStyle(
                              color: textSub,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                AppSettings.openAppSettings(type: AppSettingsType.notification);
                              },
                              icon: const Icon(Icons.settings, size: 18),
                              label: const Text('Ayarlara Git'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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
                      activeColor: primaryColor,
                      onChanged: (val) {
                        // STATE PRESERVATION: Only toggle pushMasterEnabled, keep all sub-channel states preserved!
                        _updatePrefs(_preferences.copyWith(pushMasterEnabled: val));
                      },
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
                          subtitle: 'Paylaşımlarınıza gelen yorumlar, yanıtlar ve etiketlemeler.',
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
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text('Sessiz Saatler'),
                                subtitle: const Text('Belirlediğiniz saat aralığında telefonunuza anlık sesli uyarı gelmez; bildirimler sessizce Bildirim Kutusu\'na kaydedilir.'),
                                value: _preferences.quietHoursEnabled,
                                activeColor: primaryColor,
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

