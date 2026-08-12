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
import '../theme/app_theme.dart';
import '../utils/badge_helper.dart';
import 'notification_settings_screen.dart';
import 'auth_screen.dart';
// import 'edit_profile_screen.dart'; // Dosya bulunamadı, geçici olarak yorum satırı
import 'privacy_policy_screen.dart';
import 'faq_screen.dart';
import 'category_preferences_screen.dart';
import '../widgets/report_dialog.dart';
import 'message_screen.dart';
import 'messages_list_screen.dart';
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
  Stream<List<Deal>>? _userDealsStream;

  @override
  void initState() {
    super.initState();
    _checkIfOwnProfile();
    _checkAdminStatus();
    _loadUserData();
    
    final dealsUserId = widget.userId ?? _authService.currentUser?.uid;
    if (dealsUserId != null) {
      _userDealsStream = _firestoreService.getUserDealsStream(dealsUserId, limit: 5);
    }
    
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
            content: Text('Kullanıcı bilgileri yüklenirken hata: ${e.toString().length > 50 ? "${e.toString().substring(0, 50)}..." : e}'),
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
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_isLoading && _user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Top Header Hero Card
                _buildHeroHeader(
                  context,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  surfaceColor: surfaceColor,
                  backgroundColor: backgroundColor,
                  textMain: textMain,
                  textSub: textSub,
                ),

                const SizedBox(height: 16),

                // Action Buttons Bar (Sadece başka bir kullanıcının profili ise)
                if (!_isOwnProfile && _user != null && _authService.currentUser != null && widget.userId != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _OtherUserActionBarWidget(
                      currentUserId: _authService.currentUser!.uid,
                      targetUserId: widget.userId!,
                      user: _user!,
                      initialIsFollowing: _isFollowing,
                      initialIsFollowNotificationEnabled: _isFollowNotificationEnabled,
                      isAdmin: _isAdmin,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      onMessageTap: _navigateToMessageScreen,
                      onBadgeTap: (u) => _showBadgeDialog(u),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4-Column Stats Matrix Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsMatrix(
                    context,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    surfaceColor: surfaceColor,
                    textMain: textMain,
                    textSub: textSub,
                  ),
                ),

                const SizedBox(height: 20),

                // Badges Showcase (Kazanılan Rozetler)
                if (_user?.badges != null && _user!.badges.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildBadgesSection(
                      context,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      textSub: textSub,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // If Other User's Profile: Shared Deals Feed
                if (!_isOwnProfile && _user != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildUserDealsSection(
                      context,
                      userId: _user!.uid,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      textMain: textMain,
                      textSub: textSub,
                    ),
                  ),
                ],

                // Settings Section (sadece kendi profilinde)
                if (_isOwnProfile) ...[
                  const SizedBox(height: 12),
                  _buildSectionHeader('HESAP & BİLDİRİMLER', textSub),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Notifications
                          _buildSettingItem(
                            icon: Icons.notifications_rounded,
                            title: 'Bildirim Ayarları',
                            iconBgColor: primaryColor.withValues(alpha: 0.15),
                            iconColor: primaryColor,
                            trailing: Icon(Icons.chevron_right_rounded, color: textSub),
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
                            icon: Icons.local_offer_rounded,
                            title: 'Paylaştığım Fırsatlar',
                            iconBgColor: Colors.orange.withValues(alpha: 0.15),
                            iconColor: Colors.orange,
                            trailing: Icon(Icons.chevron_right_rounded, color: textSub),
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
                            icon: Icons.people_alt_rounded,
                            title: 'Takip Ettiklerim',
                            iconBgColor: Colors.purple.withValues(alpha: 0.15),
                            iconColor: Colors.purple,
                            trailing: Icon(Icons.chevron_right_rounded, color: textSub),
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
                            icon: Icons.chat_bubble_rounded,
                            title: 'Mesajlar',
                            iconBgColor: Colors.blue.withValues(alpha: 0.15),
                            iconColor: Colors.blue,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if ((_unreadMessageCount + _unreadAdminMessageCount) > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (_unreadMessageCount + _unreadAdminMessageCount) > 99
                                          ? '99+'
                                          : (_unreadMessageCount + _unreadAdminMessageCount).toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Icon(Icons.chevron_right_rounded, color: textSub),
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
                          // Dark Mode
                          _buildSettingItem(
                            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            title: 'Karanlık Mod',
                            iconBgColor: isDark ? Colors.indigo.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                            iconColor: isDark ? Colors.indigo[300]! : Colors.amber[700]!,
                            trailing: Switch(
                              value: _themeService.isDarkMode,
                              onChanged: (value) {
                                _themeService.toggleTheme();
                              },
                              activeThumbColor: primaryColor,
                              activeTrackColor: primaryColor.withValues(alpha: 0.5),
                            ),
                            isDark: isDark,
                          ),
                          _buildDivider(isDark),
                          // Privacy
                          _buildSettingItem(
                            icon: Icons.shield_rounded,
                            title: 'Gizlilik Politikası',
                            iconBgColor: Colors.teal.withValues(alpha: 0.15),
                            iconColor: Colors.teal,
                            trailing: Icon(Icons.chevron_right_rounded, color: textSub),
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

                  const SizedBox(height: 24),
                  _buildSectionHeader('DESTEK & İLETİŞİM', textSub),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          // FAQ
                          _buildSettingItem(
                            icon: Icons.help_outline_rounded,
                            title: 'Sıkça Sorulan Sorular',
                            iconBgColor: Colors.purple.withValues(alpha: 0.15),
                            iconColor: Colors.purple,
                            trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FAQScreen(),
                                ),
                              );
                            },
                            isDark: isDark,
                          ),
                          _buildDivider(isDark),
                          // Contact
                          _buildSettingItem(
                            icon: Icons.alternate_email_rounded,
                            title: 'Bize Ulaşın',
                            iconBgColor: Colors.orange.withValues(alpha: 0.15),
                            iconColor: Colors.orange,
                            trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                            onTap: () async {
                              const email = 'kolikfirsat@gmail.com';
                              final uri = Uri.parse('mailto:$email');
                              try {
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('E-posta uygulaması açılamadı. Lütfen $email adresine manuel olarak e-posta gönderin.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
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
                            icon: Icons.star_outline_rounded,
                            title: 'Uygulamayı Değerlendir',
                            iconBgColor: Colors.amber.withValues(alpha: 0.15),
                            iconColor: Colors.amber[800]!,
                            trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                            onTap: () async {
                              const packageName = 'com.sicakfirsatlar.sicak_firsatlar';
                              final playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
                              final marketUrl = Uri.parse('market://details?id=$packageName');
                              
                              try {
                                if (await canLaunchUrl(marketUrl)) {
                                  await launchUrl(marketUrl, mode: LaunchMode.externalApplication);
                                } else if (await canLaunchUrl(playStoreUrl)) {
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

                  // Logout & Delete Account
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Çıkış Yap'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              backgroundColor: Colors.red.withValues(alpha: 0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.red.withValues(alpha: 0.15)),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton.icon(
                            onPressed: _deleteAccount,
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('Hesabımı Sil'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'FırsatKolik v1.2.4 (Build 302)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSub.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: _isOwnProfile ? 100 : 40), // Bottom nav padding
              ],
            ),
          ),
          
          // Floating Glassmorphic App Bar
          _buildCustomAppBar(
            context,
            isDark: isDark,
            backgroundColor: backgroundColor,
            surfaceColor: surfaceColor,
            textMain: textMain,
            primaryColor: primaryColor,
          ),

          // Bottom Navigation Bar (Sadece kendi profilinde)
          if (_isOwnProfile)
            _buildBottomNav(
              context,
              isDark: isDark,
              surfaceColor: surfaceColor,
              primaryColor: primaryColor,
            ),
        ],
      ),
    );
  }

  // 1. HERO HEADER WITH COVER GRADIENT & GLOWING AVATAR
  Widget _buildHeroHeader(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color backgroundColor,
    required Color textMain,
    required Color textSub,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;
    final user = _user;
    final username = user?.username ?? 'Kullanıcı';
    final displayName = user?.displayName ?? username;
    final trustLevel = user?.trustLevel ?? 'Yeni Üye';
    final points = user?.points ?? 0;
    final isVerified = user?.badges.contains('verified') ?? false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 64, 20, 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner Avatar with Clean Border
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: surfaceColor,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: (user?.profileImageUrl != null && user!.profileImageUrl.isNotEmpty)
                        ? (user.profileImageUrl.startsWith('assets/')
                            ? Image.asset(
                                user.profileImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.person_rounded, size: 48, color: textSub),
                              )
                            : CachedNetworkImage(
                                imageUrl: user.profileImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.person_rounded, size: 48, color: textSub),
                              ))
                        : Icon(Icons.person_rounded, size: 48, color: textSub),
                  ),
                ),
                // Edit Button (Own Profile)
                if (_isOwnProfile)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showProfileImagePicker(context),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: surfaceColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                // Verified Badge Indicator (Other user)
                if (!_isOwnProfile && isVerified)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4),
                        shape: BoxShape.circle,
                        border: Border.all(color: surfaceColor, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

                const SizedBox(height: 12),

                // Name with edit or verified icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isOwnProfile) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _showEditUsernameDialog(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(Icons.edit_rounded, size: 15, color: primaryColor),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 3),

                // Username handle (@username)
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: textSub,
                  ),
                ),

                if (_isOwnProfile && _authService.currentUser?.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _authService.currentUser!.email!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: textSub.withValues(alpha: 0.8),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Trust Level / Reputation Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? primaryColor.withValues(alpha: 0.12)
                        : primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        trustLevel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: textSub.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$points Puan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  // 3. STATS MATRIX (4-COLUMN CARD)
  Widget _buildStatsMatrix(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
  }) {
    final user = _user;
    final dealCount = user?.dealCount ?? 0;
    final points = user?.points ?? 0;
    final totalLikes = user?.totalLikes ?? 0;
    final followingCount = user?.following.length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSingleStat(
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.orange.shade600,
            iconBg: Colors.orange.withValues(alpha: 0.12),
            value: '$dealCount',
            label: 'Fırsat',
            textMain: textMain,
            textSub: textSub,
          ),
          _buildStatDivider(isDark),
          _buildSingleStat(
            icon: Icons.star_rounded,
            iconColor: Colors.amber.shade700,
            iconBg: Colors.amber.withValues(alpha: 0.12),
            value: '$points',
            label: 'Puan',
            textMain: textMain,
            textSub: textSub,
          ),
          _buildStatDivider(isDark),
          _buildSingleStat(
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            iconBg: Colors.redAccent.withValues(alpha: 0.12),
            value: '$totalLikes',
            label: 'Beğeni',
            textMain: textMain,
            textSub: textSub,
          ),
          _buildStatDivider(isDark),
          _buildSingleStat(
            icon: Icons.people_alt_rounded,
            iconColor: Colors.blue.shade600,
            iconBg: Colors.blue.withValues(alpha: 0.12),
            value: '$followingCount',
            label: 'Takip',
            textMain: textMain,
            textSub: textSub,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleStat({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required Color textMain,
    required Color textSub,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textMain,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: textSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
    );
  }

  // 4. BADGES SHOWCASE SECTION
  Widget _buildBadgesSection(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
  }) {
    final badgeInfos = BadgeHelper.getBadgeInfos(_user!.badges);
    if (badgeInfos.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded, size: 16, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                'KAZANILAN ROZETLER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: textSub,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${badgeInfos.length}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badgeInfos.map((badge) {
              return InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) => Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(badge.icon, style: const TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            badge.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            badge.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: textSub,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: badge.color.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: badge.color.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(badge.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        badge.name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: badge.color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 5. USER DEALS FEED SECTION
  Widget _buildUserDealsSection(
    BuildContext context, {
    required String userId,
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.local_offer_outlined, size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  'PAYLAŞILAN FIRSATLAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: textSub,
                  ),
                ),
              ],
            ),
            if ((_user?.dealCount ?? 0) > 0)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserDealsScreen(
                        userId: userId,
                        username: _user?.username ?? '',
                        isOwnProfile: false,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'Tümü',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: primaryColor),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Deal>>(
          stream: _userDealsStream ?? _firestoreService.getUserDealsStream(userId, limit: 5),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'Fırsatlar yüklenirken bir sorun oluştu.',
                    style: TextStyle(color: textSub, fontSize: 13),
                  ),
                ),
              );
            }

            final deals = snapshot.data ?? [];

            if (deals.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 32,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz Paylaşılan Fırsat Yok',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu kullanıcının paylaştığı fırsatlar burada listelenecektir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textSub,
                      ),
                    ),
                  ],
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
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
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
      ],
    );
  }

  // 6. CUSTOM FLOATING GLASS APP BAR
  Widget _buildCustomAppBar(
    BuildContext context, {
    required bool isDark,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color textMain,
    required Color primaryColor,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 6, bottom: 8, left: 16, right: 16),
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.85),
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Glass Back Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: textMain,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Text(
                _isOwnProfile ? 'Profilim' : (_user?.username ?? 'Kullanıcı Profili'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // More Options (Report, Block, Badge for Admin)
            if (!_isOwnProfile && _user != null)
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.more_horiz_rounded, size: 18, color: textMain),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: surfaceColor,
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
                          Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                          SizedBox(width: 10),
                          Text('Rozet Yönet', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, color: Colors.red, size: 20),
                          SizedBox(width: 10),
                          Text('Kullanıcıyı Engelle', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                        SizedBox(width: 10),
                        Text('Kullanıcıyı Bildir', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              )
            else
              const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }

  // 7. BOTTOM NAVIGATION BAR
  Widget _buildBottomNav(
    BuildContext context, {
    required bool isDark,
    required Color surfaceColor,
    required Color primaryColor,
  }) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
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
                  icon: Icons.person_rounded,
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Container(
                  width: 28,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 7),
              Icon(
                icon,
                color: isSelected 
                    ? (isDark ? primaryColor : primaryColor) 
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected 
                      ? (isDark ? primaryColor : primaryColor) 
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[200] : Colors.black87,
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
      indent: 68,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        borderRadius: BorderRadius.circular(12),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Rozet Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
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
}

// ---------------------------------------------------------------------------
// ISOLATED ACTION BAR WIDGET (FOLLOW / MESSAGE / NOTIFICATION / BADGE)
// Only this widget rebuilds when user toggles follow or notification bell!
// ---------------------------------------------------------------------------
class _OtherUserActionBarWidget extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final AppUser user;
  final bool initialIsFollowing;
  final bool initialIsFollowNotificationEnabled;
  final bool isAdmin;
  final bool isDark;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textMain;
  final VoidCallback onMessageTap;
  final Function(AppUser) onBadgeTap;

  const _OtherUserActionBarWidget({
    required this.currentUserId,
    required this.targetUserId,
    required this.user,
    required this.initialIsFollowing,
    required this.initialIsFollowNotificationEnabled,
    required this.isAdmin,
    required this.isDark,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textMain,
    required this.onMessageTap,
    required this.onBadgeTap,
  });

  @override
  State<_OtherUserActionBarWidget> createState() => _OtherUserActionBarWidgetState();
}

class _OtherUserActionBarWidgetState extends State<_OtherUserActionBarWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  late bool _isFollowing;
  late bool _isFollowNotificationEnabled;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing;
    _isFollowNotificationEnabled = widget.initialIsFollowNotificationEnabled;
  }

  @override
  void didUpdateWidget(covariant _OtherUserActionBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsFollowing != widget.initialIsFollowing) {
      _isFollowing = widget.initialIsFollowing;
    }
    if (oldWidget.initialIsFollowNotificationEnabled != widget.initialIsFollowNotificationEnabled) {
      _isFollowNotificationEnabled = widget.initialIsFollowNotificationEnabled;
    }
  }

  void _showFloatingSnackBar(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFF97316),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(milliseconds: 2000),
        elevation: 4,
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final nextFollowing = !_isFollowing;
    final nextNotification = nextFollowing ? true : false;

    // Instant optimistic local update - only this widget updates
    setState(() {
      _isFollowing = nextFollowing;
      _isFollowNotificationEnabled = nextNotification;
    });

    if (nextFollowing) {
      _showFloatingSnackBar('${widget.user.username} takip edildi. Anlık bildirimler açık 🔔', isSuccess: true);
    } else {
      _showFloatingSnackBar('Takipten çıkıldı', isSuccess: false);
    }

    try {
      if (nextFollowing) {
        await _firestoreService.followUser(widget.currentUserId, widget.targetUserId);
      } else {
        await _firestoreService.unfollowUser(widget.currentUserId, widget.targetUserId);
      }
    } catch (e) {
      // Revert upon error
      if (mounted) {
        setState(() {
          _isFollowing = !nextFollowing;
          _isFollowNotificationEnabled = !nextFollowing;
        });
        _showFloatingSnackBar('İşlem başarısız oldu: $e', isSuccess: false);
      }
    }
  }

  Future<void> _toggleFollowNotification() async {
    if (!_isFollowing) return;
    final nextNotification = !_isFollowNotificationEnabled;

    // Instant optimistic local update - only this widget updates
    setState(() {
      _isFollowNotificationEnabled = nextNotification;
    });

    if (nextNotification) {
      _showFloatingSnackBar('${widget.user.username} yeni bir fırsat paylaştığında anlık bildirim alacaksınız 🔔', isSuccess: true);
    } else {
      _showFloatingSnackBar('Bu kullanıcı için anlık bildirimler kapatıldı 🔕', isSuccess: false);
    }

    try {
      await _firestoreService.toggleFollowNotification(
        widget.currentUserId,
        widget.targetUserId,
        nextNotification,
      );
    } catch (e) {
      // Revert upon error
      if (mounted) {
        setState(() {
          _isFollowNotificationEnabled = !nextNotification;
        });
        _showFloatingSnackBar('İşlem başarısız oldu: $e', isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBadges = widget.user.badges.isNotEmpty;

    return Row(
      children: [
        // Takip Et / Takip Ediliyor Butonu (Expanded)
        Expanded(
          flex: 3,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _toggleFollow();
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                height: 42,
                decoration: BoxDecoration(
                  color: _isFollowing
                      ? widget.primaryColor.withValues(alpha: widget.isDark ? 0.16 : 0.10)
                      : widget.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isFollowing
                        ? widget.primaryColor.withValues(alpha: 0.7)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (!_isFollowing)
                      BoxShadow(
                        color: widget.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    else
                      BoxShadow(
                        color: widget.primaryColor.withValues(alpha: widget.isDark ? 0.08 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isFollowing
                          ? Icons.check_circle_rounded
                          : Icons.person_add_rounded,
                      size: 16,
                      color: _isFollowing ? widget.primaryColor : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isFollowing ? 'Takip Ediliyor' : 'Takip Et',
                      style: TextStyle(
                        color: _isFollowing ? widget.primaryColor : Colors.white,
                        fontWeight: _isFollowing ? FontWeight.w600 : FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Mesaj Gönder Butonu
        Expanded(
          flex: 2,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onMessageTap();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: widget.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isDark ? 0.15 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 15,
                      color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Mesaj',
                      style: TextStyle(
                        color: widget.textMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bildirim Zili (Sadece takip ediliyorsa)
        if (_isFollowing) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _toggleFollowNotification();
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _isFollowNotificationEnabled
                      ? Colors.amber.withValues(alpha: widget.isDark ? 0.22 : 0.15)
                      : widget.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isFollowNotificationEnabled
                        ? Colors.amber.shade600
                        : (widget.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08)),
                    width: _isFollowNotificationEnabled ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    if (_isFollowNotificationEnabled)
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withValues(alpha: widget.isDark ? 0.15 : 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Icon(
                  _isFollowNotificationEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  size: 18,
                  color: _isFollowNotificationEnabled
                      ? Colors.amber.shade500
                      : (widget.isDark ? Colors.grey[500] : Colors.grey[400]),
                ),
              ),
            ),
          ),
        ],

        // Admin Rozet Yönet Butonu (Sadece Admin için)
        if (widget.isAdmin) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onBadgeTap(widget.user),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: hasBadges
                      ? Colors.amber.withValues(alpha: widget.isDark ? 0.18 : 0.12)
                      : widget.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasBadges
                        ? Colors.amber.withValues(alpha: 0.6)
                        : (widget.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08)),
                    width: hasBadges ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    if (hasBadges)
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Icon(
                  hasBadges
                      ? Icons.workspace_premium_rounded
                      : Icons.workspace_premium_outlined,
                  size: 19,
                  color: hasBadges
                      ? Colors.amber.shade600
                      : (widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
