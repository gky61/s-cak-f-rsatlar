import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'category_preferences_screen.dart';

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
  bool _commentReplyNotifications = true;
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
      
      // Yorum bildirimleri durumunu yükle
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        _commentReplyNotifications = await _notificationService.getCommentReplyNotificationsEnabled(userId);
        
        // Anahtar kelimeleri yükle
        final firestoreService = FirestoreService();
        _watchKeywords = await firestoreService.getUserWatchKeywords(userId);
      }
    } catch (e) {
      _log('Bildirim ayarları yükleme hatası: $e');
      // Hata durumunda varsayılan değerler (genel bildirimler kapalı)
      _generalNotifications = false;
      _commentReplyNotifications = false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleGeneralNotifications(bool value) async {
    if (_isLoading) return; // Çift tıklama koruması
    
    // Optimistic UI update - Önce UI'ı anında güncelle
    setState(() {
      _generalNotifications = value;
      // Genel bildirimler kapatıldığında yorum bildirimleri de kapatılır
      // (ama kullanıcı tekrar açabilir)
      if (!value) {
        _commentReplyNotifications = false;
      }
    });
    
    // Arka planda Firestore'a kaydet
    try {
      // Genel bildirim ayarını kaydet
      await _notificationService.setGeneralNotifications(value);
      
      // Genel bildirimler kapatıldığında yorum bildirimlerini de kapat
      // (ama kullanıcı tekrar açabilir)
      final userId = _auth.currentUser?.uid;
      if (!value && userId != null) {
        await _notificationService.setCommentReplyNotificationsEnabled(userId, false);
        // UI'da da güncelle
        if (mounted) {
          setState(() {
            _commentReplyNotifications = false;
          });
        }
      }
      
      // Genel bildirimler açıldığında:
      // - all_deals topic'ine abone ol (Cloud Functions zaten all_deals'e gönderiyor)
      // Genel bildirimler kapatıldığında:
      // - all_deals topic'inden çık (setGeneralNotifications zaten yapıyor)
      
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

  Future<void> _toggleCommentReplyNotifications(bool value) async {
    if (_isLoading) return; // Çift tıklama koruması
    
    // Optimistic UI update - Önce UI'ı anında güncelle
    setState(() {
      _commentReplyNotifications = value;
    });
    
    // Arka planda Firestore'a kaydet
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _notificationService.setCommentReplyNotificationsEnabled(userId, value);
      }
      
      // Başarılı - UI zaten güncellendi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value 
                ? 'Yorum bildirimleri açıldı ✅' 
                : 'Yorum bildirimleri kapatıldı. Profilde görünmeye devam edecek.'),
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
      _log('Yorum bildirim ayarı kaydetme hatası: $e');
      // Hata durumunda mevcut durumu yeniden yükle
      if (mounted) {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          final currentValue = await _notificationService.getCommentReplyNotificationsEnabled(userId);
          setState(() {
            _commentReplyNotifications = currentValue;
          });
        }
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
      body: _isLoading
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

            // Comment Reply Notifications
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
                        Icons.comment,
                        color: isDark ? Colors.blue[200] : Colors.blue[700],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yorum Bildirimleri',
                            style: TextStyle(
                              color: textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _generalNotifications 
                                ? 'Yorumlarınıza gelen cevaplar için telefon bildirimi'
                                : 'Telefon bildirimi kapalı, sadece profilde görünecek',
                            style: TextStyle(
                              color: textSub,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _commentReplyNotifications,
                      onChanged: _isLoading 
                          ? null 
                          : (value) => _toggleCommentReplyNotifications(value),
                      activeColor: primaryColor,
                      activeTrackColor: primaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Kategoriler Butonu
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategoryPreferencesScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
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
                            Icons.category,
                            color: isDark ? Colors.purple[200] : Colors.purple[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kategoriler',
                                style: TextStyle(
                                  color: textMain,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kategorileri görüntüle ve filtrele',
                                style: TextStyle(
                                  color: textSub,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: textSub,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
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
}





