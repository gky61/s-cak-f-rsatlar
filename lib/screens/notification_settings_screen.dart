import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_settings/app_settings.dart';
import '../services/notification_service.dart';
import '../models/notification_preferences.dart';
import 'category_preferences_screen.dart';
import '../theme/app_theme.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  NotificationPreferences _preferences = NotificationPreferences.defaultPreferences();
  List<String> _watchKeywords = [];
  final TextEditingController _keywordController = TextEditingController();
  
  String _systemPermissionStatus = 'authorized';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keywordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, check system permission status again
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
      final keywords = await _notificationService.getNotificationKeywords();
      
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _watchKeywords = keywords;
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

  Future<void> _updatePrefs(NotificationPreferences newPrefs) async {
    setState(() {
      _preferences = newPrefs;
    });
    try {
      await _notificationService.updateNotificationPreferences(newPrefs);
    } catch (e) {
      _log('Error updating preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllSettings();
      }
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
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

      final updatedPrefs = NotificationPreferences(
        pushMasterEnabled: _preferences.pushMasterEnabled,
        dealNotificationsEnabled: _preferences.dealNotificationsEnabled,
        communityNotificationsEnabled: _preferences.communityNotificationsEnabled,
        submissionStatusNotificationsEnabled: _preferences.submissionStatusNotificationsEnabled,
        marketingNotificationsEnabled: _preferences.marketingNotificationsEnabled,
        categoryNotificationsEnabled: _preferences.categoryNotificationsEnabled,
        keywordNotificationsEnabled: _preferences.keywordNotificationsEnabled,
        quietHoursEnabled: _preferences.quietHoursEnabled,
        quietHoursStart: isStart ? newTime : _preferences.quietHoursStart,
        quietHoursEnd: isStart ? _preferences.quietHoursEnd : newTime,
        timezone: _preferences.timezone,
        updatedAt: DateTime.now(),
      );

      _updatePrefs(updatedPrefs);
    }
  }

  Future<void> _addKeyword() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir kelime girin'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final normalized = _notificationService.normalizeKeyword(keyword);
    if (_watchKeywords.map((k) => _notificationService.normalizeKeyword(k)).contains(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu kelime zaten ekli'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await _notificationService.addKeywordSubscription(keyword);
      setState(() {
        _watchKeywords.add(keyword);
        _keywordController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$keyword" kelimesi eklendi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _log('Keyword add error: $e');
    }
  }

  Future<void> _removeKeyword(String keyword) async {
    try {
      await _notificationService.removeKeywordSubscription(keyword);
      setState(() {
        _watchKeywords.remove(keyword);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$keyword" kelimesi çıkarıldı'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _log('Keyword remove error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : const Color(0xFF1C1C0D);
    final textSub = isDark ? Colors.grey[400] : const Color(0xFF5C5C4F);

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

                  // Master Toggle: Cihaz Bildirimleri
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
                        _updatePrefs(NotificationPreferences(
                          pushMasterEnabled: val,
                          dealNotificationsEnabled: _preferences.dealNotificationsEnabled,
                          communityNotificationsEnabled: _preferences.communityNotificationsEnabled,
                          submissionStatusNotificationsEnabled: _preferences.submissionStatusNotificationsEnabled,
                          marketingNotificationsEnabled: _preferences.marketingNotificationsEnabled,
                          categoryNotificationsEnabled: _preferences.categoryNotificationsEnabled,
                          keywordNotificationsEnabled: _preferences.keywordNotificationsEnabled,
                          quietHoursEnabled: _preferences.quietHoursEnabled,
                          quietHoursStart: _preferences.quietHoursStart,
                          quietHoursEnd: _preferences.quietHoursEnd,
                          timezone: _preferences.timezone,
                          updatedAt: DateTime.now(),
                        ));
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

                  // Notification Groups
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
                        SwitchListTile(
                          title: const Text('Takip Edilen Yazar Bildirimleri'),
                          subtitle: const Text('Profillerinden bildirimlerini (zilini) açtığınız usta avcıların paylaştığı yeni fırsatlar.'),
                          value: _preferences.dealNotificationsEnabled,
                          activeColor: primaryColor,
                          onChanged: _preferences.pushMasterEnabled
                              ? (val) {
                                  _updatePrefs(NotificationPreferences(
                                    pushMasterEnabled: _preferences.pushMasterEnabled,
                                    dealNotificationsEnabled: val,
                                    communityNotificationsEnabled: _preferences.communityNotificationsEnabled,
                                    submissionStatusNotificationsEnabled: _preferences.submissionStatusNotificationsEnabled,
                                    marketingNotificationsEnabled: _preferences.marketingNotificationsEnabled,
                                    categoryNotificationsEnabled: _preferences.categoryNotificationsEnabled,
                                    keywordNotificationsEnabled: _preferences.keywordNotificationsEnabled,
                                    quietHoursEnabled: _preferences.quietHoursEnabled,
                                    quietHoursStart: _preferences.quietHoursStart,
                                    quietHoursEnd: _preferences.quietHoursEnd,
                                    timezone: _preferences.timezone,
                                    updatedAt: DateTime.now(),
                                  ));
                                }
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Topluluk Bildirimleri'),
                          subtitle: const Text('Paylaşımlarınıza gelen yorumlar, yanıtlar ve etiketlemeler.'),
                          value: _preferences.communityNotificationsEnabled,
                          activeColor: primaryColor,
                          onChanged: _preferences.pushMasterEnabled
                              ? (val) {
                                  _updatePrefs(NotificationPreferences(
                                    pushMasterEnabled: _preferences.pushMasterEnabled,
                                    dealNotificationsEnabled: _preferences.dealNotificationsEnabled,
                                    communityNotificationsEnabled: val,
                                    submissionStatusNotificationsEnabled: _preferences.submissionStatusNotificationsEnabled,
                                    marketingNotificationsEnabled: _preferences.marketingNotificationsEnabled,
                                    categoryNotificationsEnabled: _preferences.categoryNotificationsEnabled,
                                    keywordNotificationsEnabled: _preferences.keywordNotificationsEnabled,
                                    quietHoursEnabled: _preferences.quietHoursEnabled,
                                    quietHoursStart: _preferences.quietHoursStart,
                                    quietHoursEnd: _preferences.quietHoursEnd,
                                    timezone: _preferences.timezone,
                                    updatedAt: DateTime.now(),
                                  ));
                                }
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Paylaşım Durumu Bildirimleri'),
                          subtitle: const Text('Paylaştığınız fırsatların onaylanma, reddedilme veya yayından kaldırılma durumları.'),
                          value: _preferences.submissionStatusNotificationsEnabled,
                          activeColor: primaryColor,
                          onChanged: _preferences.pushMasterEnabled
                              ? (val) {
                                  _updatePrefs(NotificationPreferences(
                                    pushMasterEnabled: _preferences.pushMasterEnabled,
                                    dealNotificationsEnabled: _preferences.dealNotificationsEnabled,
                                    communityNotificationsEnabled: _preferences.communityNotificationsEnabled,
                                    submissionStatusNotificationsEnabled: val,
                                    marketingNotificationsEnabled: _preferences.marketingNotificationsEnabled,
                                    categoryNotificationsEnabled: _preferences.categoryNotificationsEnabled,
                                    keywordNotificationsEnabled: _preferences.keywordNotificationsEnabled,
                                    quietHoursEnabled: _preferences.quietHoursEnabled,
                                    quietHoursStart: _preferences.quietHoursStart,
                                    quietHoursEnd: _preferences.quietHoursEnd,
                                    timezone: _preferences.timezone,
                                    updatedAt: DateTime.now(),
                                  ));
                                }
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Kampanya Bildirimleri'),
                          subtitle: const Text('Özel kampanyalar, hediye çekleri ve önemli sistem duyuruları'),
                          value: _preferences.marketingNotificationsEnabled,
                          activeColor: primaryColor,
                          onChanged: _preferences.pushMasterEnabled
                              ? (val) {
                                  _updatePrefs(NotificationPreferences(
                                    pushMasterEnabled: _preferences.pushMasterEnabled,
                                    dealNotificationsEnabled: _preferences.dealNotificationsEnabled,
                                    communityNotificationsEnabled: _preferences.communityNotificationsEnabled,
                                    submissionStatusNotificationsEnabled: _preferences.submissionStatusNotificationsEnabled,
                                    marketingNotificationsEnabled: val,
                                    categoryNotificationsEnabled: _preferences.categoryNotificationsEnabled,
                                    keywordNotificationsEnabled: _preferences.keywordNotificationsEnabled,
                                    quietHoursEnabled: _preferences.quietHoursEnabled,
                                    quietHoursStart: _preferences.quietHoursStart,
                                    quietHoursEnd: _preferences.quietHoursEnd,
                                    timezone: _preferences.timezone,
                                    updatedAt: DateTime.now(),
                                  ));
                                }
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Kategori Bildirimleri'),
                          subtitle: const Text('Takip ettiğiniz alışveriş kategorilerine eklenen yeni fırsatlar'),
                          value: _preferences.categoryNotificationsEnabled,
                          activeColor: primaryColor,
                          onChanged: _preferences.pushMasterEnabled
                              ? (val) {
                                  _updatePrefs(NotificationPreferences(
                                    pushMasterEnabled: _preferences.pushMasterEnabled,
                                    dealNotificationsEnabled: _preferences.dealNotificationsEnabled,
                                    communityNotificationsEnabled: _preferences.communityNotificationsEnabled,
                                    submissionStatusNotificationsEnabled: _preferences.submissionStatusNotificationsEnabled,
                                    marketingNotificationsEnabled: _preferences.marketingNotificationsEnabled,
                                    categoryNotificationsEnabled: val,
                                    keywordNotificationsEnabled: _preferences.keywordNotificationsEnabled,
                                    quietHoursEnabled: _preferences.quietHoursEnabled,
                                    quietHoursStart: _preferences.quietHoursStart,
                                    quietHoursEnd: _preferences.quietHoursEnd,
                                    timezone: _preferences.timezone,
                                    updatedAt: DateTime.now(),
                                  ));
                                }
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Anahtar Kelime Takibi Bildirimleri'),
                          subtitle: const Text('Takip listenizdeki kelimeleri içeren yeni fırsatlardan haberdar olun'),
                          value: _preferences.keywordNotificationsEnabled,
                          activeColor: primaryColor,
                          onChanged: _preferences.pushMasterEnabled
                              ? (val) {
                                  _updatePrefs(NotificationPreferences(
                                    pushMasterEnabled: _preferences.pushMasterEnabled,
                                    dealNotificationsEnabled: _preferences.dealNotificationsEnabled,
                                    communityNotificationsEnabled: _preferences.communityNotificationsEnabled,
                                    submissionStatusNotificationsEnabled: _preferences.submissionStatusNotificationsEnabled,
                                    marketingNotificationsEnabled: _preferences.marketingNotificationsEnabled,
                                    categoryNotificationsEnabled: _preferences.categoryNotificationsEnabled,
                                    keywordNotificationsEnabled: val,
                                    quietHoursEnabled: _preferences.quietHoursEnabled,
                                    quietHoursStart: _preferences.quietHoursStart,
                                    quietHoursEnd: _preferences.quietHoursEnd,
                                    timezone: _preferences.timezone,
                                    updatedAt: DateTime.now(),
                                  ));
                                }
                              : null,
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
                        SwitchListTile(
                          title: const Text('Sessiz Saatler'),
                          subtitle: const Text('Belirlediğiniz saat aralığında telefonunuza anlık sesli uyarı gelmez; bildirimler sessizce Bildirim Kutusu\'na kaydedilir.'),
                          value: _preferences.quietHoursEnabled,
                          activeColor: primaryColor,
                          onChanged: _preferences.pushMasterEnabled
                              ? (val) {
                                  _updatePrefs(NotificationPreferences(
                                    pushMasterEnabled: _preferences.pushMasterEnabled,
                                    dealNotificationsEnabled: _preferences.dealNotificationsEnabled,
                                    communityNotificationsEnabled: _preferences.communityNotificationsEnabled,
                                    submissionStatusNotificationsEnabled: _preferences.submissionStatusNotificationsEnabled,
                                    marketingNotificationsEnabled: _preferences.marketingNotificationsEnabled,
                                    categoryNotificationsEnabled: _preferences.categoryNotificationsEnabled,
                                    keywordNotificationsEnabled: _preferences.keywordNotificationsEnabled,
                                    quietHoursEnabled: val,
                                    quietHoursStart: _preferences.quietHoursStart,
                                    quietHoursEnd: _preferences.quietHoursEnd,
                                    timezone: _preferences.timezone,
                                    updatedAt: DateTime.now(),
                                  ));
                                }
                              : null,
                        ),
                        if (_preferences.quietHoursEnabled && _preferences.pushMasterEnabled) ...[
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
                  const SizedBox(height: 24),

                  // Categories Button
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
                    child: ListTile(
                      leading: Icon(Icons.category, color: primaryColor),
                      title: const Text(
                        'Kategoriler',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Tercih ettiğiniz fırsat kategorilerini seçin'),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: _preferences.pushMasterEnabled ? null : Colors.grey,
                      ),
                      onTap: _preferences.pushMasterEnabled
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CategoryPreferencesScreen(),
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Keywords Section
                  Text(
                    'TAKİP EDİLEN ANAHTAR KELİMELER',
                    style: TextStyle(
                      color: textSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(16),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _keywordController,
                                enabled: _preferences.pushMasterEnabled,
                                decoration: InputDecoration(
                                  hintText: 'Kelime girin (örn: Dyson, Laptop)',
                                  hintStyle: TextStyle(color: textSub, fontSize: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: TextStyle(color: textMain, fontSize: 14),
                                onSubmitted: _preferences.pushMasterEnabled ? (_) => _addKeyword() : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _preferences.pushMasterEnabled ? _addKeyword : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        if (_watchKeywords.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _watchKeywords.map((keyword) {
                              return Chip(
                                label: Text(
                                  keyword,
                                  style: TextStyle(
                                    color: _preferences.pushMasterEnabled 
                                        ? textMain 
                                        : textMain.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                                deleteIcon: Icon(
                                  Icons.close, 
                                  size: 18, 
                                  color: _preferences.pushMasterEnabled ? textMain : Colors.grey,
                                ),
                                onDeleted: _preferences.pushMasterEnabled ? () => _removeKeyword(keyword) : null,
                                backgroundColor: isDark 
                                    ? Colors.white.withValues(alpha: 0.1) 
                                    : Colors.black.withValues(alpha: 0.05),
                                side: BorderSide.none,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
