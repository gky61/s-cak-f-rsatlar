import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _generalNotifications = true;
  final Map<String, bool> _categoryNotifications = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() => _isLoading = true);
    try {
      // Genel bildirim durumunu yükle
      _generalNotifications = await _notificationService.getGeneralNotificationsEnabled();
      
      // Kategori bildirim durumlarını yükle
      final followedCategories = await _notificationService.getFollowedCategories();
      for (var category in Category.categories) {
        if (category.id != 'tumu') {
          _categoryNotifications[category.id] = followedCategories.contains(category.id);
        }
      }
    } catch (e) {
      print('Bildirim ayarları yükleme hatası: $e');
      // Varsayılan değerler
      for (var category in Category.categories) {
        if (category.id != 'tumu') {
          _categoryNotifications[category.id] = true;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleGeneralNotifications(bool value) {
    setState(() {
      _generalNotifications = value;
      // Tüm bildirimler kapatılırken kategorileri kapatma - kullanıcı istediği kategoriyi açabilir
    });
  }

  void _toggleCategoryNotification(String categoryId, bool value) {
    setState(() {
      _categoryNotifications[categoryId] = value;
      // Kategori bildirimleri genel bildirimlerden bağımsız çalışabilir
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF23220F) : const Color(0xFFF8F8F5);
    final surfaceColor = isDark ? const Color(0xFF2E2D15) : Colors.white;
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark ? Colors.yellow[200] : Colors.yellow[800],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'İlgilendiğiniz kategorilerden yeni fırsatlar geldiğinde bildirim alın.',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // General Notifications
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.notifications_active,
                        color: isDark ? Colors.yellow[200] : Colors.yellow[800],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tüm Bildirimler',
                            style: TextStyle(
                              color: textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ana bildirim kontrolü',
                            style: TextStyle(
                              color: textSub,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _generalNotifications,
                      onChanged: _toggleGeneralNotifications,
                      activeColor: primaryColor,
                      activeTrackColor: primaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Notifications Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'KATEGORİLER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textSub,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Category Notifications List
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: Category.categories.where((c) => c.id != 'tumu').length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 76,
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.05),
                ),
                itemBuilder: (context, index) {
                  final category = Category.categories.where((c) => c.id != 'tumu').toList()[index];
                  final isEnabled = _categoryNotifications[category.id] ?? false;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Category Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category.id).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              category.icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Category Name
                        Expanded(
                          child: Text(
                            category.name,
                            style: TextStyle(
                              color: textMain,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Switch
                        Switch(
                          value: isEnabled,
                          onChanged: (value) => _toggleCategoryNotification(category.id, value),
                          activeColor: primaryColor,
                          activeTrackColor: primaryColor.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveNotificationSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Kaydet'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNotificationSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Genel bildirimleri kaydet
      await _notificationService.setGeneralNotifications(_generalNotifications);
      
      // Kategori bildirimlerini kaydet
      for (var entry in _categoryNotifications.entries) {
        final categoryId = entry.key;
        final isEnabled = entry.value;
        
        if (isEnabled) {
          await _notificationService.subscribeToCategory(categoryId);
        } else {
          await _notificationService.unsubscribeFromCategory(categoryId);
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim ayarları kaydedildi ✅'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'elektronik':
        return Colors.blue;
      case 'moda':
        return Colors.pink;
      case 'ev_yasam':
        return Colors.orange;
      case 'anne_bebek':
        return Colors.purple;
      case 'kozmetik':
        return Colors.pink[300]!;
      case 'spor_outdoor':
        return Colors.green;
      case 'supermarket':
        return Colors.red;
      case 'yapi_oto':
        return Colors.brown;
      case 'kitap_hobi':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}




