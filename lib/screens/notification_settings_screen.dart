import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/category.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _generalNotifications = true;
  final Map<String, bool> _categoryNotifications = {};
  List<String> _watchKeywords = [];
  final TextEditingController _keywordController = TextEditingController();
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
      
      // Anahtar kelimeleri yükle
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final firestoreService = FirestoreService();
        _watchKeywords = await firestoreService.getUserWatchKeywords(userId);
      }
    } catch (e) {
      _log('Bildirim ayarları yükleme hatası: $e');
      // Hata durumunda varsayılan değerler (genel bildirimler kapalı, kategoriler kapalı)
      _generalNotifications = false;
      for (var category in Category.categories) {
        if (category.id != 'tumu') {
          _categoryNotifications[category.id] = false;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleGeneralNotifications(bool value) async {
    if (_isLoading) return; // Çift tıklama koruması
    
    // Optimistic UI update - Önce UI'ı anında güncelle
    final categories = Category.categories.where((c) => c.id != 'tumu').toList();
    setState(() {
      _generalNotifications = value;
      // Genel bildirimler açıldığında tüm kategorileri aç
      if (value) {
        for (var category in categories) {
          _categoryNotifications[category.id] = true;
        }
      }
      // Genel bildirimler kapatıldığında kategori toggle'ları olduğu gibi kalır
      // Kullanıcı istediği kategorileri açık tutabilir
    });
    
    // Arka planda Firestore'a kaydet
    try {
      // Genel bildirim ayarını kaydet
      await _notificationService.setGeneralNotifications(value);
      
      // Genel bildirimler açıldığında:
      // - Tüm kategori topic'lerinden çık (çift bildirim önlemek için)
      // - Sadece all_deals topic'ine abone ol (Cloud Functions zaten all_deals'e gönderiyor)
      if (value) {
        // Önce tüm kategori topic'lerinden çık (çift bildirim önlemek için)
        final categories = Category.categories.where((c) => c.id != 'tumu').toList();
        final unsubscribeFutures = <Future>[];
        for (var category in categories) {
          unsubscribeFutures.add(_notificationService.unsubscribeFromCategory(category.id));
        }
        await Future.wait(unsubscribeFutures);
        _log('✅ Tüm kategori topic\'lerinden çıkıldı (genel bildirimler açık)');
      } else {
        // Genel bildirimler kapatıldığında:
        // - all_deals topic'inden çık (setGeneralNotifications zaten yapıyor)
        // - Kullanıcının seçtiği kategori topic'lerine abone ol
        await _notificationService.resubscribeToTopics();
      }
      
      // Başarılı - UI zaten güncellendi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value 
                ? 'Tüm bildirimler açıldı ✅' 
                : 'Tüm bildirimler kapatıldı. İstediğiniz kategorileri açabilirsiniz.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      _log('Bildirim ayarı kaydetme hatası: $e');
      // Hata durumunda mevcut durumu yeniden yükle
      if (mounted) {
        await _loadNotificationSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleCategoryNotification(String categoryId, bool value) async {
    // Kullanıcı genel bildirimler kapalıyken de istediği kategorileri açabilir
    // Sadece o kategoriden bildirim alır
    
    // Optimistic UI update - Önce UI'ı anında güncelle
    setState(() {
      _categoryNotifications[categoryId] = value;
    });
    
    // Arka planda Firestore'a kaydet (snackbar gösterme, sadece sessizce kaydet)
    try {
      if (value) {
        await _notificationService.subscribeToCategory(categoryId);
      } else {
        await _notificationService.unsubscribeFromCategory(categoryId);
      }
      // Başarılı - UI zaten güncellendi, snackbar gösterme (çok fazla bildirim olur)
    } catch (e) {
      _log('Kategori bildirim ayarı kaydetme hatası: $e');
      // Hata durumunda mevcut durumu yeniden yükle
      if (mounted) {
        final followedCategories = await _notificationService.getFollowedCategories();
        setState(() {
          _categoryNotifications[categoryId] = followedCategories.contains(categoryId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
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
      body: _isLoading && _categoryNotifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      onChanged: _isLoading ? null : _toggleGeneralNotifications,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: TextStyle(
                                  color: textMain,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!_generalNotifications && isEnabled) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Sadece bu kategoriden bildirim alınıyor',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Switch - Her zaman aktif (genel bildirimler kapalıyken de kategori açılabilir)
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

            // Anahtar Kelime Takibi Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'ANAHTAR KELİME TAKİBİ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textSub,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Anahtar Kelime Bilgi Kartı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Belirli kelimeleri takip edin. Bu kelimeleri içeren fırsatlar paylaşıldığında bildirim alın.',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Anahtar Kelime Ekleme
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keywordController,
                          decoration: InputDecoration(
                            hintText: 'Kelime girin (örn: iPhone, laptop)',
                            hintStyle: TextStyle(color: textSub, fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.1) 
                                    : Colors.black.withValues(alpha: 0.1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.1) 
                                    : Colors.black.withValues(alpha: 0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: TextStyle(color: textMain, fontSize: 14),
                          onSubmitted: (value) => _addKeyword(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addKeyword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                              color: textMain,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          deleteIcon: Icon(
                            Icons.close,
                            size: 18,
                            color: textMain,
                          ),
                          onDeleted: () => _removeKeyword(keyword),
                          backgroundColor: isDark 
                              ? Colors.white.withValues(alpha: 0.1) 
                              : Colors.black.withValues(alpha: 0.05),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _addKeyword() async {
    final keyword = _keywordController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen bir kelime girin'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    if (_watchKeywords.contains(keyword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bu kelime zaten ekli'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final firestoreService = FirestoreService();
      await firestoreService.addWatchKeyword(userId, keyword);
      
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
            duration: const Duration(seconds: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      _log('Kelime ekleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeKeyword(String keyword) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final firestoreService = FirestoreService();
      await firestoreService.removeWatchKeyword(userId, keyword);
      
      setState(() {
        _watchKeywords.remove(keyword);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$keyword" kelimesi çıkarıldı'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      _log('Kelime çıkarma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
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





