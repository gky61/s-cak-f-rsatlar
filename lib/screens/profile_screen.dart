import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/badge_helper.dart';
import '../models/category.dart';
import 'notification_settings_screen.dart';
import 'keyword_tracking_screen.dart';
import 'auth_screen.dart';
// import 'edit_profile_screen.dart'; // Dosya bulunamadı, geçici olarak yorum satırı
import 'privacy_policy_screen.dart';
import 'faq_screen.dart';
import 'category_preferences_screen.dart';
import '../widgets/report_dialog.dart';
import 'message_screen.dart';
import 'messages_list_screen.dart';
import 'admin_notifications_screen.dart';
import 'following_users_screen.dart';
import 'user_deals_screen.dart';
import '../models/deal.dart';
import '../widgets/deal_card.dart';
import 'deal_detail_screen.dart';
import 'package:flutter/services.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class ProfileScreen extends StatefulWidget {
  final String? userId; // Belirli bir kullanıcının profilini görüntülemek için
  
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  
  AppUser? _user;
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _isOwnProfile = true;
  int _unreadMessageCount = 0;
  int _unreadAdminMessageCount = 0;
  bool _isFollowing = false;
  bool _isFollowNotificationEnabled = false;
  StreamSubscription? _messageCountSubscription;
  StreamSubscription? _adminMessageCountSubscription;
  StreamSubscription? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _checkIfOwnProfile();
    _checkAdminStatus();
    _loadUserData();
    if (_isOwnProfile) {
      _loadUnreadMessageCount();
      _loadUnreadAdminMessageCount();
    } else {
      _loadFollowStatus();
    }
  }

  Future<void> _loadFollowStatus() async {
    final currentUserId = _authService.currentUser?.uid;
    final targetUserId = widget.userId;
    if (currentUserId == null || targetUserId == null) {
      _log('⚠️ _loadFollowStatus: currentUserId veya targetUserId null');
      return;
    }

    try {
      _log('📋 _loadFollowStatus çağrıldı: currentUserId=$currentUserId, targetUserId=$targetUserId');
      final isFollowing = await _firestoreService.isFollowing(currentUserId, targetUserId);
      final isNotificationEnabled = await _firestoreService.isFollowNotificationEnabled(currentUserId, targetUserId);
      
      _log('📋 _loadFollowStatus sonucu: isFollowing=$isFollowing, isNotificationEnabled=$isNotificationEnabled');
      
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isFollowNotificationEnabled = isNotificationEnabled;
        });
        _log('✅ UI güncellendi: _isFollowing=$_isFollowing');
      }
    } catch (e) {
      _log('❌ Takip durumu yükleme hatası: $e');
    }
  }

  Future<void> _loadUnreadMessageCount() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    final count = await _firestoreService.getUnreadMessageCount(currentUserId);
    if (mounted) {
      setState(() {
        _unreadMessageCount = count;
      });
    }

    // Stream ile sürekli güncelle (mesajlar okunduğunda otomatik güncellenir)
    _messageCountSubscription?.cancel();
    _messageCountSubscription = _firestoreService.getUserMessagesStream(currentUserId).listen((messages) {
      if (mounted) {
        final unreadCount = messages
            .where((m) => m.receiverId == currentUserId && !m.isRead)
            .length;
        setState(() {
          _unreadMessageCount = unreadCount;
        });
      }
    });
  }

  Future<void> _loadUnreadAdminMessageCount() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    final count = await _firestoreService.getUnreadAdminToUserMessageCount(currentUserId);
    if (mounted) {
      setState(() {
        _unreadAdminMessageCount = count;
      });
    }

    _adminMessageCountSubscription?.cancel();
    _adminMessageCountSubscription =
        _firestoreService.getAdminToUserMessagesStream(currentUserId).listen((messages) {
      if (!mounted) return;
      final unreadCount = messages.where((m) => !m.isRead).length;
      setState(() {
        _unreadAdminMessageCount = unreadCount;
      });
    });
  }

  @override
  void dispose() {
    _messageCountSubscription?.cancel();
    _adminMessageCountSubscription?.cancel();
    _userDataSubscription?.cancel();
    super.dispose();
  }

  void _checkIfOwnProfile() {
    final currentUserId = _authService.currentUser?.uid;
    _isOwnProfile = widget.userId == null || widget.userId == currentUserId;
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _loadUserData() async {
    final targetUserId = widget.userId ?? _authService.currentUser?.uid;
    if (targetUserId == null) return;

    setState(() => _isLoading = true);
    
    // Önceki subscription'ı iptal et
    _userDataSubscription?.cancel();
    
    // Real-time listener ekle (rozet güncellemeleri için)
    _userDataSubscription = _firestore
        .collection('users')
        .doc(targetUserId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        try {
          if (mounted) {
            setState(() {
              _user = AppUser.fromFirestore(doc);
              _isLoading = false;
            });
          }
        } catch (parseError) {
          _log('Kullanıcı verisi parse hatası: $parseError');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        // Eğer kendi profilimizse yeni kullanıcı oluştur
        if (_isOwnProfile) {
          final currentUser = _authService.currentUser;
          if (currentUser != null) {
            final newUser = AppUser(
              uid: currentUser.uid,
              username: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Kullanıcı',
              profileImageUrl: currentUser.photoURL ?? '',
              points: 0,
              dealCount: 0,
              totalLikes: 0,
              badges: [],
            );
            _firestore.collection('users').doc(currentUser.uid).set(newUser.toFirestore(), SetOptions(merge: true));
            if (mounted) {
              setState(() {
                _user = newUser;
                _isLoading = false;
              });
            }
          }
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }, onError: (error) {
      _log('Kullanıcı verisi dinleme hatası: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
    
    // İlk yükleme için de bir kez get() yap (hızlı başlangıç için)
    try {
      final doc = await _firestore.collection('users').doc(targetUserId).get();
      if (doc.exists) {
        try {
          if (mounted) {
            setState(() {
              _user = AppUser.fromFirestore(doc);
              _isLoading = false;
            });
          }
        } catch (parseError) {
          _log('Kullanıcı verisi parse hatası: $parseError');
          // Parse hatası durumunda varsayılan kullanıcı oluştur
          if (_isOwnProfile) {
            final currentUser = _authService.currentUser;
            if (currentUser != null) {
              final newUser = AppUser(
                uid: currentUser.uid,
                username: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Kullanıcı',
                profileImageUrl: currentUser.photoURL ?? '',
                points: 0,
                dealCount: 0,
                totalLikes: 0,
                badges: [],
              );
              await _firestore.collection('users').doc(currentUser.uid).set(newUser.toFirestore(), SetOptions(merge: true));
              if (mounted) {
                setState(() {
                  _user = newUser;
                  _isLoading = false;
                });
              }
            }
          } else if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        // Eğer kendi profilimizse yeni kullanıcı oluştur, değilse sadece göster
        if (_isOwnProfile) {
          final currentUser = _authService.currentUser;
          if (currentUser != null) {
            final newUser = AppUser(
              uid: currentUser.uid,
              username: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Kullanıcı',
              profileImageUrl: currentUser.photoURL ?? '',
              points: 0,
              dealCount: 0,
              totalLikes: 0,
              badges: [],
            );
            await _firestore.collection('users').doc(currentUser.uid).set(newUser.toFirestore(), SetOptions(merge: true));
            if (mounted) {
              setState(() {
                _user = newUser;
                _isLoading = false;
              });
            }
          }
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      _log('Kullanıcı bilgisi yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kullanıcı bilgileri yüklenirken hata: ${e.toString().length > 50 ? e.toString().substring(0, 50) + "..." : e}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
      setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _showProfileImagePicker(BuildContext context) async {
    // Kullanıcı kendi profilini görüntülüyorsa veya admin ise profil fotoğrafı değiştirilebilir
    if (!_isOwnProfile && !_isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sadece kendi profil fotoğrafınızı değiştirebilirsiniz'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Assets klasöründeki profil resimleri
    final List<String> profileImages = [
      'assets/kullanıcı pp.webp',
      'assets/kkpp.webp',
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;
        
        return AlertDialog(
          title: const Text('Profil Resmi Seç'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Kaldır" seçeneği
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Profil Resmini Kaldır'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateProfileImage('');
                  },
                ),
                const Divider(),
                // Görselleri grid olarak göster
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: profileImages.length,
                  itemBuilder: (context, index) {
                    final imagePath = profileImages[index];
                    
                    return InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await _updateProfileImage(imagePath);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: _user?.profileImageUrl == imagePath
                              ? Border.all(color: primaryColor, width: 3)
                              : Border.all(color: Colors.grey[300]!, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.person),
                                  );
                                },
                              ),
                            ),
                            if (_user?.profileImageUrl == imagePath)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateProfileImage(String imageUrl) async {
    final user = _authService.currentUser;
    if (user == null) return;

    // Kullanıcı kendi profilini görüntülüyorsa veya admin ise profil fotoğrafı değiştirilebilir
    if (!_isOwnProfile && !_isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sadece kendi profil fotoğrafınızı değiştirebilirsiniz'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Hangi kullanıcının profil fotoğrafını güncelleyeceğiz?
    final targetUserId = _isOwnProfile ? user.uid : widget.userId;
    if (targetUserId == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Firebase Auth'daki photoURL'yi güncelle (sadece kendi profilini güncellerken)
      if (_isOwnProfile && targetUserId == user.uid) {
        try {
          await user.updatePhotoURL(imageUrl);
          await user.reload();
          _log('✅ Firebase Auth photoURL güncellendi');
        } catch (authError) {
          _log('⚠️ Firebase Auth photoURL güncelleme hatası: $authError');
        }
      }

      // 2. Firestore'a kaydet (merge: true ile güvenli kayıt)
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .set({
        'profileImageUrl': imageUrl,
      }, SetOptions(merge: true));

      _log('✅ Profil resmi Firestore\'a kaydedildi: $imageUrl (userId: $targetUserId)');

      // 3. CachedNetworkImage cache'ini temizle (eski resmi göstermesin)
      try {
        await CachedNetworkImage.evictFromCache(imageUrl);
        _log('✅ Cache temizlendi');
      } catch (e) {
        _log('⚠️ Cache temizleme hatası: $e');
      }

      // 4. State'i direkt güncelle (Firestore'dan tekrar okumaya gerek yok)
      if (_user != null) {
        setState(() {
          _user = AppUser(
            uid: _user!.uid,
            username: _user!.username,
            profileImageUrl: imageUrl,
            followedCategories: _user!.followedCategories,
            watchKeywords: _user!.watchKeywords,
            nickname: _user!.nickname,
            points: _user!.points,
            dealCount: _user!.dealCount,
            totalLikes: _user!.totalLikes,
            badges: _user!.badges,
          );
        });
      } else {
        // Eğer _user null ise, Firestore'dan tekrar yükle
        await _loadUserData();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil resmi güncellendi ✅'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _log('❌ Profil resmi güncelleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditUsernameDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textController = TextEditingController(text: _user?.username ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: Text(
            'Kullanıcı Adını Düzenle',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLength: 30,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Kullanıcı adınızı girin',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 2,
                ),
              ),
              counterStyle: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final newUsername = textController.text.trim();
                if (newUsername.isNotEmpty && newUsername != _user?.username) {
                  Navigator.pop(context, newUsername);
                } else {
                  Navigator.pop(context);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
              child: const Text(
                'Kaydet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _updateUsername(result);
    }
  }

  Future<void> _updateUsername(String newUsername) async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Firebase Auth'daki displayName'i güncelle
      try {
        await user.updateDisplayName(newUsername);
        await user.reload();
        // Güncellenmiş kullanıcıyı yeniden al
        final updatedUser = _authService.currentUser;
        _log('✅ Firebase Auth displayName güncellendi: ${updatedUser?.displayName}');
      } catch (authError) {
        _log('⚠️ Firebase Auth displayName güncelleme hatası: $authError');
      }

      // 2. Firestore'daki username ve nickname'i güncelle
      // Not: nickname alanı da güncellenmeli, aksi halde eski değer görünür
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'username': newUsername,
        'nickname': newUsername, // nickname'i de aynı değerle güncelle
      }, SetOptions(merge: true));

      _log('✅ Firestore username ve nickname güncellendi: $newUsername');

      // 3. Kullanıcı verilerini yeniden yükle
      await _loadUserData();

      // 4. State'i force refresh için bir gecikme ekle
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı adı güncellendi ✅'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _log('Kullanıcı adı güncelleme hatası: $e');
      if (mounted) {
        // Hata mesajını daha kullanıcı dostu hale getir
        String errorMessage = 'Kullanıcı adı güncellenirken bir hata oluştu';
        if (e.toString().contains('PigeonUserInfo')) {
          errorMessage = 'Kullanıcı adı güncellendi, ancak bazı bilgiler güncellenemedi. Lütfen uygulamayı yeniden başlatın.';
        } else if (e.toString().length < 100) {
          errorMessage = 'Hata: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Çıkış yap
      await _authService.signOut();
      
      // Tüm navigasyon stack'ini temizle ve giriş ekranına yönlendir
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabımı Sil'),
        content: const Text(
            'Hesabınızı ve tüm verilerinizi kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _authService.deleteAccount();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  String _getUserLevel() {
    if (_user == null) return 'Seviye 1';
    final points = _user!.points;
    if (points < 100) return 'Seviye 1';
    if (points < 500) return 'Seviye 2';
    if (points < 1000) return 'Seviye 3';
    if (points < 2000) return 'Seviye 4';
    return 'Seviye 5';
  }

  String _getUserBadge() {
    if (_user == null) return 'Yeni Üye';
    final points = _user!.points;
    if (points < 50) return 'Yeni Üye';
    if (points < 200) return 'Fırsat Avcısı';
    if (points < 500) return 'Fırsat Uzmanı';
    if (points < 1000) return 'Fırsat Masterı';
    return 'Fırsat Kralı';
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF23220F) : const Color(0xFFF8F8F5);
    final surfaceColor = isDark ? const Color(0xFF2E2D15) : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : const Color(0xFF1C1C0D);
    final textSub = isDark ? Colors.grey[400] : const Color(0xFF5C5C4F);

    if (_isLoading && _user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 80), // App bar space
                
                // Profile Header Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                      // Avatar with Gradient Ring
                      Stack(
                        alignment: Alignment.center,
                          children: [
                          // Gradient Ring
                                  Container(
                          width: 120,
                          height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  Colors.orange.shade300,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          // Avatar
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: backgroundColor,
                              border: Border.all(color: backgroundColor, width: 4),
                                    ),
                          child: ClipOval(
                              child: _user?.profileImageUrl != null && _user!.profileImageUrl.isNotEmpty
                                  ? (_user!.profileImageUrl.startsWith('assets/')
                                      ? Image.asset(
                                          _user!.profileImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(Icons.person, size: 56, color: Colors.grey[400]);
                                          },
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: _user!.profileImageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[300],
                                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          ),
                                          errorWidget: (context, url, error) => Icon(Icons.person, size: 56, color: Colors.grey[400]),
                                        ))
                                  : Icon(Icons.person, size: 56, color: Colors.grey[400]),
                            ),
                        ),
                          // Edit Button - Sadece kendi profili ise görünür
                        if (_isOwnProfile)
                        Positioned(
                            bottom: 2,
                            right: 2,
                          child: GestureDetector(
                            onTap: () => _showProfileImagePicker(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: backgroundColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit, size: 16, color: Colors.black),
                            ),
                          ),
                        ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Name & Email
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _isOwnProfile ? () => _showEditUsernameDialog(context) : null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                      Text(
                        _user?.username ?? 'Kullanıcı',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                                    if (_isOwnProfile) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: textSub,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Mesaj gönderme butonu (başka kullanıcının profilinde)
                              if (!_isOwnProfile) ...[
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(Icons.message, color: primaryColor),
                                  onPressed: () => _navigateToMessageScreen(),
                                  tooltip: 'Mesaj Gönder',
                                ),
                              ],
                              // Takip et butonu (başka kullanıcının profilinde)
                              if (!_isOwnProfile) ...[
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(
                                    _isFollowing ? Icons.person_remove : Icons.person_add,
                                    color: _isFollowing ? Colors.grey : primaryColor,
                                  ),
                                  onPressed: () => _toggleFollow(),
                                  tooltip: _isFollowing ? 'Takipten Çık' : 'Takip Et',
                                ),
                              ],
                              // Admin rozet verme butonu
                              if (_isAdmin && !_isOwnProfile) ...[
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(Icons.workspace_premium, color: primaryColor),
                                  onPressed: () => _showBadgeDialog(_user!),
                                  tooltip: 'Rozet Ver',
                                ),
                              ],
                            ],
                          ),
                          // Takip bildirim butonu (takip ediliyorsa)
                          if (!_isOwnProfile && _isFollowing) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _toggleFollowNotification(),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isFollowNotificationEnabled 
                                      ? primaryColor.withValues(alpha: 0.1)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _isFollowNotificationEnabled 
                                        ? primaryColor 
                                        : Colors.grey[400]!,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isFollowNotificationEnabled 
                                          ? Icons.notifications_active 
                                          : Icons.notifications_off,
                                      size: 16,
                                      color: _isFollowNotificationEnabled 
                                          ? primaryColor 
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isFollowNotificationEnabled 
                                          ? 'Bildirimler Açık' 
                                          : 'Bildirimler Kapalı',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _isFollowNotificationEnabled 
                                            ? primaryColor 
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Rozetler (kullanıcı adının altında)
                          if (_user?.badges != null && _user!.badges.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                _log('🔍 Profil ekranında rozetler gösteriliyor: ${_user!.badges}');
                                final badgeInfos = BadgeHelper.getBadgeInfos(_user!.badges);
                                _log('🔍 BadgeHelper.getBadgeInfos sonucu: ${badgeInfos.length} rozet');
                                return Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.center,
                                  children: badgeInfos
                                      .map((badge) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: badge.color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: badge.color.withValues(alpha: 0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              badge.icon,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              badge.name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: badge.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Puan ve paylaşım sayısı gösterimi (daha kibar tasarım)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.08),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: isDark ? Colors.amber[300] : Colors.amber[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_user?.points ?? 0} Puan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textSub,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSub?.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_user?.dealCount ?? 0} Paylaşım',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textSub,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_isOwnProfile) ...[
                      const SizedBox(height: 4),
                      Text(
                        _authService.currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textSub,
                        ),
                            ),
                      ],
                                          ],
                                        ),
                                      ),

                // Settings Section (sadece kendi profilinde)
                if (_isOwnProfile) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('AYARLAR', textSub!),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                    ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Notifications
                        _buildSettingItem(
                          icon: Icons.notifications,
                          title: 'Bildirim Ayarları',
                          iconBgColor: primaryColor.withValues(alpha: 0.2),
                          iconColor: isDark ? Colors.yellow[200]! : Colors.yellow[800]!,
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationSettingsScreen(),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Paylaştığım Fırsatlar
                        _buildSettingItem(
                          icon: Icons.local_offer,
                          title: 'Paylaştığım Fırsatlar',
                          iconBgColor: primaryColor.withValues(alpha: 0.1),
                          iconColor: primaryColor,
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                          onTap: () {
                            final currentUserId = _authService.currentUser?.uid;
                            if (currentUserId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserDealsScreen(
                                    userId: currentUserId,
                                    username: _user?.username ?? '',
                                    isOwnProfile: true,
                                  ),
                                ),
                              );
                            }
                          },
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Takip Ettiklerim
                        _buildSettingItem(
                          icon: Icons.person_add,
                          title: 'Takip Ettiklerim',
                          iconBgColor: Colors.pink.withValues(alpha: 0.2),
                          iconColor: Colors.pink,
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FollowingUsersScreen(),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Mesajlar
                        _buildSettingItem(
                          icon: Icons.message,
                          title: 'Mesajlar',
                          iconBgColor: Colors.blue.withValues(alpha: 0.2),
                          iconColor: Colors.blue,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_unreadMessageCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _unreadMessageCount > 99 ? '99+' : _unreadMessageCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Icon(Icons.chevron_right, color: Colors.grey[400]),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MessagesListScreen(),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Anahtar Kelime Takibi
                        _buildSettingItem(
                          icon: Icons.search,
                          title: 'Anahtar Kelime Takibi',
                          iconBgColor: Colors.teal.withValues(alpha: 0.2),
                          iconColor: Colors.teal,
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const KeywordTrackingScreen(),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Dark Mode
                        _buildSettingItem(
                          icon: isDark ? Icons.dark_mode : Icons.light_mode,
                          title: 'Karanlık Mod',
                          iconBgColor: isDark ? Colors.indigo.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                          iconColor: isDark ? Colors.indigo[300]! : Colors.amber[700]!,
                          trailing: Switch(
                            value: _themeService.isDarkMode,
                            onChanged: (value) {
                              _themeService.toggleTheme();
                            },
                            activeColor: primaryColor,
                            activeTrackColor: primaryColor.withValues(alpha: 0.5),
                          ),
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Privacy
                        _buildSettingItem(
                          icon: Icons.security,
                          title: 'Gizlilik',
                          iconBgColor: Colors.blue.withValues(alpha: 0.1),
                          iconColor: Colors.blue,
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                                  ),
                ),
                ], // Ayarlar bölümü sonu

                // Support Section (sadece kendi profilinde)
                if (_isOwnProfile) ...[
                const SizedBox(height: 24),
                  _buildSectionHeader('DESTEK', textSub!),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                      ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // FAQ
                        _buildSettingItem(
                          icon: Icons.help,
                          title: 'Sıkça Sorulan Sorular',
                          iconBgColor: Colors.green.withValues(alpha: 0.1),
                          iconColor: Colors.green,
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FAQScreen(),
                              ),
                            );
                          },
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Contact
                        _buildSettingItem(
                          icon: Icons.mail,
                          title: 'Bize Ulaşın',
                          iconBgColor: Colors.orange.withValues(alpha: 0.1),
                          iconColor: Colors.orange,
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                          onTap: () async {
                            final email = 'kolikfirsat@gmail.com';
                            final uri = Uri.parse('mailto:$email');
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('E-posta uygulaması açılamadı. Lütfen $email adresine manuel olarak e-posta gönderin.'),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('E-posta açılırken hata: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Rate App
                        _buildSettingItem(
                          icon: Icons.star,
                          title: 'Uygulamayı Değerlendir',
                          iconBgColor: primaryColor.withValues(alpha: 0.1),
                          iconColor: Colors.yellow[800]!,
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                          onTap: () async {
                            // Play Store'a yönlendir
                            // Not: Uygulama yayınlandığında gerçek paket adı ile değiştirilmeli
                            const packageName = 'com.sicakfirsatlar.sicak_firsatlar';
                            final playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
                            final marketUrl = Uri.parse('market://details?id=$packageName');
                            
                            try {
                              // Önce market:// protokolünü dene (Play Store uygulaması açılır)
                              if (await canLaunchUrl(marketUrl)) {
                                await launchUrl(marketUrl, mode: LaunchMode.externalApplication);
                              } else if (await canLaunchUrl(playStoreUrl)) {
                                // Play Store uygulaması yoksa web'de aç
                                await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Play Store açılamadı'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              _log('Play Store açılırken hata: $e');
                            }
                          },
                          isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                ),
                ], // DESTEK bölümü sonu

                // Logout Button (sadece kendi profilinde)
                if (_isOwnProfile) ...[
                                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Çıkış Yap'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: Colors.red.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.red.withValues(alpha: 0.1)),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                                        ),
                                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton.icon(
                          onPressed: _deleteAccount,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Hesabımı Sil'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: Colors.red.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.red.withValues(alpha: 0.1)),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                                        ),
                                      ),
                      const SizedBox(height: 16),
                      Text(
                        'v1.2.4 (Build 302)',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                ],
                if (!_isOwnProfile && _user != null) ...[
                  _buildLastDealsSection(context, _user!.uid),
                ],
                SizedBox(height: _isOwnProfile ? 100 : 24), // Bottom nav padding
              ],
            ),
          ),
          
          // Custom App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              color: backgroundColor.withValues(alpha: 0.95),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Text(
                        _isOwnProfile ? 'Profilim' : (_user?.username ?? 'Profil'),
                        textAlign: TextAlign.center,
                          style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                          ),
                    ),
                  ),


                    // Profil İşlemleri Menüsü (Raporla, Admin işlemleri vb.)
                    if (!_isOwnProfile && _user != null)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: textMain),
                        onSelected: (value) {
                          if (value == 'badge') {
                            _showBadgeDialog(_user!);
                          } else if (value == 'block') {
                            _blockUser(_user!);
                          } else if (value == 'report') {
                            showReportDialog(
                              context,
                              reportedId: _user!.uid,
                              type: 'user',
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          if (_isAdmin) ...[
                            const PopupMenuItem(
                              value: 'badge',
                              child: Row(
                                children: [
                                  Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                                  SizedBox(width: 8),
                                  Text('Rozet Yönet'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'block',
                              child: Row(
                                children: [
                                  Icon(Icons.block, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Kullanıcıyı Engelle'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                          ],
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Kullanıcıyı Raporla'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (!(_isAdmin && !_isOwnProfile && _user != null))
                    const SizedBox(width: 48), // Balancing spacer
                  ],
                ),
              ),
            ),
          ),

          // Bottom Navigation Bar (HTML Tasarımı)
          if (_isOwnProfile)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.98),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                          child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBottomNavItem(
                        icon: Icons.home_outlined,
                        label: 'Anasayfa',
                        isSelected: false,
                        onTap: () => Navigator.pop(context),
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      _buildBottomNavItem(
                        icon: Icons.category_outlined,
                        label: 'Kategoriler',
                        isSelected: false,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CategoryPreferencesScreen(),
                            ),
                          );
                        },
                        isDark: isDark,
                        primaryColor: primaryColor,
                                              ),
                      _buildBottomNavItem(
                        icon: Icons.person,
                        label: 'Profilim',
                        isSelected: true,
                        onTap: () {},
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
                                                    ),
                                              ),
                                            ],
                                        ),
                                      );
                                    }
                                    
  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Tüm alanı dokunulabilir yap
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Dokunma alanını genişlet
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            if (isSelected)
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 8),
            Icon(
              icon,
              color: isSelected 
                  ? (isDark ? primaryColor : Colors.black) 
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected 
                    ? (isDark ? primaryColor : Colors.black) 
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
                                    
  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required Color iconColor,
    required Widget trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
      padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                                                      decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[200] : Colors.black,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 64,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
    );
  }

  Future<void> _showBadgeDialog(AppUser user) async {
    if (!_isAdmin) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final TextEditingController badgeController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: Text(
            '${user.username} - Rozet Yönetimi',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mevcut Rozetler:',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.badges.map((badgeId) {
                      final badge = BadgeHelper.getBadgeInfo(badgeId);
                      if (badge == null) return const SizedBox.shrink();
                      return Chip(
                        avatar: Text(badge.icon),
                        label: Text(badge.name),
                        backgroundColor: badge.color.withValues(alpha: 0.2),
                        deleteIcon: Icon(Icons.close, size: 16, color: badge.color),
                        onDeleted: () => _removeBadge(user.uid, badgeId),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yeni Rozet Ekle:',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: badgeController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Rozet adı girin (örn: VIP, Moderatör)',
                      hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _addBadge(user.uid, value.trim());
                        badgeController.clear();
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final badgeName = badgeController.text.trim();
                        if (badgeName.isNotEmpty) {
                          _addBadge(user.uid, badgeName);
                          badgeController.clear();
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Rozet Ekle'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Önceden Tanımlı Rozetler:',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BadgeHelper.getAllBadgeIds()
                        .where((badgeId) => !user.badges.contains(badgeId))
                        .map((badgeId) {
                      final badge = BadgeHelper.getBadgeInfo(badgeId)!;
                      return ActionChip(
                        avatar: Text(badge.icon),
                        label: Text(badge.name),
                        backgroundColor: badge.color.withValues(alpha: 0.1),
                        onPressed: () => _addBadge(user.uid, badgeId),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                badgeController.dispose();
                Navigator.pop(context);
              },
              child: Text(
                'Kapat',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
    badgeController.dispose();
  }

  Future<void> _addBadge(String userId, String badgeId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      
      if (userDoc.exists) {
        final currentBadges = List<String>.from(userDoc.data()?['badges'] ?? []);
        if (!currentBadges.contains(badgeId)) {
          currentBadges.add(badgeId);
          await userRef.update({'badges': currentBadges});
          
          // Kullanıcı verilerini yeniden yükle
          await _loadUserData();
          
          if (mounted) {
            Navigator.pop(context); // Dialog'u kapat
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rozet eklendi ✅'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      _log('Rozet ekleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeBadge(String userId, String badgeId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      
      if (userDoc.exists) {
        final currentBadges = List<String>.from(userDoc.data()?['badges'] ?? []);
        currentBadges.remove(badgeId);
        await userRef.update({'badges': currentBadges});
        
        // Kullanıcı verilerini yeniden yükle
        await _loadUserData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rozet kaldırıldı ✅'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _log('Rozet kaldırma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUser(AppUser user) async {
    if (!_isAdmin) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Engelle'),
        content: Text('${user.username} kullanıcısını engellemek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _firestoreService.blockUser(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Kullanıcı engellendi' : 'Kullanıcı engellenirken hata oluştu'),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
        if (success) {
          Navigator.pop(context); // Profil sayfasından çık
        }
      }
    }
  }

  // Mesaj ekranına yönlendir
  void _navigateToMessageScreen() {
    if (_user == null) return;
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageScreen(
          otherUserId: _user!.uid,
          otherUserName: _user!.username,
          otherUserImageUrl: _user!.profileImageUrl,
        ),
      ),
    );
  }

  // Takip et/Takipten çık
  Future<void> _toggleFollow() async {
    final currentUserId = _authService.currentUser?.uid;
    final targetUserId = widget.userId;
    if (currentUserId == null || targetUserId == null) return;

    try {
      if (_isFollowing) {
        // Takipten çık
        await _firestoreService.unfollowUser(currentUserId, targetUserId);
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _isFollowNotificationEnabled = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Takipten çıkıldı'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        // Takip et
        await _firestoreService.followUser(currentUserId, targetUserId);
        if (mounted) {
          setState(() {
            _isFollowing = true;
            _isFollowNotificationEnabled = true; // Takip edildiğinde bildirimler aktif olarak başlar
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Takip edildi ✅ Bildirimler aktif'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _log('Takip toggle hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Takip bildirimlerini aç/kapat
  Future<void> _toggleFollowNotification() async {
    final currentUserId = _authService.currentUser?.uid;
    final targetUserId = widget.userId;
    if (currentUserId == null || targetUserId == null || !_isFollowing) return;

    try {
      final newValue = !_isFollowNotificationEnabled;
      await _firestoreService.toggleFollowNotification(currentUserId, targetUserId, newValue);
      
      if (mounted) {
        setState(() {
          _isFollowNotificationEnabled = newValue;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'Bildirimler açıldı ✅' : 'Bildirimler kapatıldı'),
            backgroundColor: newValue ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _log('Takip bildirim toggle hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }


  Widget _buildLastDealsSection(BuildContext context, String userId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSub = isDark ? Colors.grey[400] : const Color(0xFF5C5C4F);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionHeader('SON PAYLAŞILAN FIRSATLAR', textSub!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<List<Deal>>(
            stream: _firestoreService.getUserLastDealsStream(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: Center(
                    child: Text(
                      'Fırsatlar yüklenirken bir hata oluştu',
                      style: TextStyle(color: textSub),
                    ),
                  ),
                );
              }

              final deals = snapshot.data ?? [];

              if (deals.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: Center(
                    child: Text(
                      'Henüz hiçbir fırsat paylaşılmadı.',
                      style: TextStyle(color: textSub, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: deals.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final deal = deals[index];
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: DealCard(
                      deal: deal,
                      viewMode: CardViewMode.horizontal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DealDetailScreen(dealId: deal.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
