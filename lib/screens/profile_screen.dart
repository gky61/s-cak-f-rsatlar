import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../utils/badge_helper.dart';
import '../utils/asset_path_migration.dart';
import 'guest_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'category_preferences_screen.dart';
import 'admin_screen.dart';
import 'keyword_tracking_screen.dart';
import 'badges_screen.dart';
import 'support_hub_screen.dart';
import '../widgets/report_dialog.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import 'message_screen.dart';
import 'messages_list_screen.dart';
import 'following_users_screen.dart';
import 'user_deals_screen.dart';
import 'botkolik_profile_screen.dart';
import '../models/deal.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import '../widgets/skeletons/profile_skeleton.dart';
import 'deal_detail_screen.dart';
import 'package:flutter/services.dart';
import '../utils/circular_theme_transition.dart';
import '../widgets/morphing_sun_moon_button.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class ProfileScreen extends StatefulWidget {
  final String? userId; // Belirli bir kullanıcının profilini görüntülemek için
  final bool isRootTab;
  
  const ProfileScreen({super.key, this.userId, this.isRootTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  final GlobalKey _themeButtonKey = GlobalKey();
  
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
    _themeService.addListener(_onThemeChanged);
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

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _messageCountSubscription?.cancel();
    _adminMessageCountSubscription?.cancel();
    _userDataSubscription?.cancel();
    super.dispose();
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
      final cleanImageUrl = migrateAssetPath(imageUrl);
      // 1. Firebase Auth'daki photoURL'yi güncelle (sadece kendi profilini güncellerken)
      if (_isOwnProfile && targetUserId == user.uid) {
        try {
          await user.updatePhotoURL(cleanImageUrl);
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
        'profileImageUrl': cleanImageUrl,
        'photoURL': cleanImageUrl,
      }, SetOptions(merge: true));

      _log('✅ Profil resmi Firestore\'a kaydedildi: $cleanImageUrl (userId: $targetUserId)');

      // 3. CachedNetworkImage cache'ini temizle (eski resmi göstermesin)
      if (cleanImageUrl.isNotEmpty && !cleanImageUrl.startsWith('assets/')) {
        try {
          await CachedNetworkImage.evictFromCache(cleanImageUrl);
          _log('✅ Cache temizlendi');
        } catch (e) {
          _log('⚠️ Cache temizleme hatası: $e');
        }
      }

      // 4. State'i direkt güncelle (Firestore'dan tekrar okumaya gerek yok)
      if (_user != null) {
        setState(() {
          _user = AppUser(
            uid: _user!.uid,
            username: _user!.username,
            profileImageUrl: cleanImageUrl,
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

  @override
  Widget build(BuildContext context) {
    if (widget.userId == 'botkolik' || (widget.userId != null && widget.userId!.startsWith('telegram_'))) {
      return const BotkolikProfileScreen();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    const primaryColor = AppTheme.primary;
    final accentBlue = isDark ? const Color(0xFF38BDF8) : const Color(0xFF004E92);
    final textMain = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final textSub = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    // Misafir (Giriş yapmamış kullanıcı) kendi profiline bakıyorsa:
    if (_isOwnProfile && _authService.currentUser == null) {
      return GuestProfileScreen(
        isRootTab: widget.isRootTab,
        onLoginSuccess: () {
          _checkIfOwnProfile();
          _checkAdminStatus();
          _loadUserData();
          if (_isOwnProfile) {
            _loadUnreadMessageCount();
            _loadUnreadAdminMessageCount();
          }
        },
      );
    }

    if (_isLoading && _user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const SafeArea(
          child: ProfileSkeleton(),
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

                const SizedBox(height: 12),

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
                      onBadgeTap: (u) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BadgesScreen(
                              user: u,
                              isOwnProfile: false,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Bento Quick Shortcuts (Sadece kendi profilinde)
                if (_isOwnProfile) ...[
                  const SizedBox(height: 12),
                  _buildBentoQuickActions(
                    context,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    accentBlue: accentBlue,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textMain: textMain,
                    textSub: textSub,
                  ),
                  const SizedBox(height: 14),
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

                // Settings Sections (Sadece kendi profilinde)
                if (_isOwnProfile) ...[
                  _buildAccountSettingsSection(
                    context,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    accentBlue: accentBlue,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textMain: textMain,
                    textSub: textSub,
                  ),
                ],

                SizedBox(height: widget.isRootTab ? 16 : (_isOwnProfile ? 100 : 40)), // Bottom nav padding
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

          // Bottom Navigation Bar (Sadece kendi profilinde ve bağımsız açıldığında)
          if (_isOwnProfile && !widget.isRootTab)
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
    final trustLevel = user?.trustLevel ?? 'Çaylak Avcı';
    final trustIcon = user?.trustIcon ?? Icons.shield_outlined;
    final trustColor = user?.trustColor ?? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
    final points = user?.points ?? 0;
    final dealCount = user?.dealCount ?? 0;
    final totalLikes = user?.totalLikes ?? 0;
    final followingCount = user?.following.length ?? 0;
    final isVerified = user?.badges.contains('verified') ?? false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 56, 16, 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
                  width: 92,
                  height: 92,
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
                    child: Builder(
                      builder: (context) {
                        final avatarUrl = migrateAssetPath(user?.profileImageUrl ?? '');
                        if (avatarUrl.isNotEmpty) {
                          if (avatarUrl.startsWith('assets/')) {
                            return Image.asset(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.person_rounded, size: 46, color: textSub),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) =>
                                Icon(Icons.person_rounded, size: 46, color: textSub),
                          );
                        }
                        return Icon(Icons.person_rounded, size: 46, color: textSub);
                      },
                    ),
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

          const SizedBox(height: 10),

          // Name with dynamic trust badge & edit icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Dynamic Trust / Rank Badge Icon
              Tooltip(
                message: '$trustLevel ($points Puan)',
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: trustColor.withValues(alpha: isDark ? 0.22 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: trustColor.withValues(alpha: isDark ? 0.45 : 0.30),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    trustIcon,
                    size: 13.5,
                    color: trustColor,
                  ),
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

          const SizedBox(height: 10),

          // Trust Level & Pinned Badge Row (Tıklanabilir Başarım Kısayolları - Yüksek Kontrast & Prestijli Tasarım)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              // Trust Level / Reputation Pill Badge (Prestijli & Yüksek Kontrastlı Tasarım)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (user == null) return;
                    HapticFeedback.selectionClick();
                    final updatedUser = await Navigator.push<AppUser>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BadgesScreen(
                          user: user,
                          isOwnProfile: _isOwnProfile,
                        ),
                      ),
                    );
                    if (updatedUser != null && mounted) {
                      setState(() {
                        _user = updatedUser;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trustIcon,
                          size: 14,
                          color: trustColor,
                        ),
                        const SizedBox(width: 5.5),
                        Text(
                          trustLevel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3.5,
                          height: 3.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: textSub.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$points P',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: textSub.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Pinned Badge Pill (If user selected one)
              if (user?.pinnedBadge != null) ...[
                Builder(builder: (context) {
                  final pinnedBadge = BadgeHelper.getBadgeInfo(user!.pinnedBadge!);
                  if (pinnedBadge == null) return const SizedBox.shrink();
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final updatedUser = await Navigator.push<AppUser>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BadgesScreen(
                              user: user,
                              isOwnProfile: _isOwnProfile,
                            ),
                          ),
                        );
                        if (updatedUser != null && mounted) {
                          setState(() {
                            _user = updatedUser;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: pinnedBadge.color.withValues(alpha: isDark ? 0.20 : 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: pinnedBadge.color.withValues(alpha: isDark ? 0.50 : 0.35),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(pinnedBadge.iconData, size: 13.5, color: pinnedBadge.color),
                            const SizedBox(width: 5),
                            Text(
                              pinnedBadge.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : textMain,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // 🌟 HERO ENTEGRE 4'LÜ MİNİMALİST EMOJİLİ İSTATİSTİK ŞERİDİ 🌟
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildHeroStatItem(
                  emoji: '🏷️',
                  value: '$dealCount',
                  label: 'Fırsat',
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () {
                    final uid = widget.userId ?? _authService.currentUser?.uid;
                    if (uid != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserDealsScreen(
                            userId: uid,
                            username: _user?.username ?? '',
                            isOwnProfile: _isOwnProfile,
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildHeroStatDivider(isDark),
                _buildHeroStatItem(
                  emoji: '🎯',
                  value: '$points',
                  label: 'Puan',
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () async {
                    if (user == null) return;
                    HapticFeedback.selectionClick();
                    final updatedUser = await Navigator.push<AppUser>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BadgesScreen(
                          user: user,
                          isOwnProfile: _isOwnProfile,
                        ),
                      ),
                    );
                    if (updatedUser != null && mounted) {
                      setState(() => _user = updatedUser);
                    }
                  },
                ),
                _buildHeroStatDivider(isDark),
                _buildHeroStatItem(
                  emoji: '🔥',
                  value: '$totalLikes',
                  label: 'Sıcaklık',
                  textMain: textMain,
                  textSub: textSub,
                ),
                _buildHeroStatDivider(isDark),
                _buildHeroStatItem(
                  emoji: '👥',
                  value: '$followingCount',
                  label: 'Takip',
                  textMain: textMain,
                  textSub: textSub,
                  onTap: _isOwnProfile
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FollowingUsersScreen(),
                            ),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem({
    required String emoji,
    required String value,
    required String label,
    required Color textMain,
    required Color textSub,
    VoidCallback? onTap,
  }) {
    final itemContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 13, height: 1.15),
            ),
            const SizedBox(width: 3.5),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: textMain,
                letterSpacing: -0.3,
                height: 1.15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2.5),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: textSub,
            height: 1.15,
          ),
        ),
      ],
    );

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: itemContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 18,
      color: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.08),
    );
  }

  // 4. BENTO QUICK SHORTCUTS GRID (COMPACT INLINE)
  Widget _buildBentoQuickActions(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color accentBlue,
    required Color surfaceColor,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    final unreadTotal = _unreadMessageCount + _unreadAdminMessageCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  context,
                  title: 'Mesajlarım',
                  subtitle: unreadTotal > 0 ? '$unreadTotal yeni mesaj' : 'Özel ve anlık sohbetler',
                  icon: Icons.chat_bubble_rounded,
                  iconColor: isDark ? const Color(0xFF60A5FA) : Colors.blue.shade600,
                  iconBg: Colors.blue.withValues(alpha: isDark ? 0.20 : 0.12),
                  badgeCount: unreadTotal,
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MessagesListScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBentoCard(
                  context,
                  title: 'Kelime Takibi',
                  subtitle: 'Anahtar kelime bildirimleri',
                  icon: Icons.radar_rounded,
                  iconColor: isDark ? const Color(0xFFFB923C) : Colors.orange.shade600,
                  iconBg: Colors.orange.withValues(alpha: isDark ? 0.20 : 0.12),
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const KeywordTrackingScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  context,
                  title: 'Fırsatlarım',
                  subtitle: 'Son 30 güne ait aktif fırsatlar',
                  icon: Icons.local_offer_rounded,
                  iconColor: isDark ? const Color(0xFF2DD4BF) : Colors.teal.shade600,
                  iconBg: Colors.teal.withValues(alpha: isDark ? 0.20 : 0.12),
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () {
                    final currentUserId = _authService.currentUser?.uid;
                    if (currentUserId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserDealsScreen(
                            userId: currentUserId,
                            username: _user?.username ?? '',
                            isOwnProfile: true,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBentoCard(
                  context,
                  title: 'Kategori Takibi',
                  subtitle: 'İlgi alanları & bildirimler',
                  icon: Icons.dashboard_customize_rounded,
                  iconColor: isDark ? const Color(0xFFC084FC) : Colors.purple.shade600,
                  iconBg: Colors.purple.withValues(alpha: isDark ? 0.20 : 0.12),
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoryPreferencesScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    int badgeCount = 0,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: [Icon] + [Title] + [Badge or Arrow]
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(icon, color: iconColor, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: textMain,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: textSub.withValues(alpha: 0.4),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),

                // Bottom: Subtitle / Description under the icon+title row
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textSub,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 6. ACCOUNT & PREFERENCES SECTION (Kompakt & Sade 3 Satırlık Kart)
  Widget _buildAccountSettingsSection(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color accentBlue,
    required Color surfaceColor,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('HESAP & TERCİHLER', textSub),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. Bildirim Tercihleri
                _buildSettingItem(
                  icon: Icons.notifications_active_rounded,
                  title: 'Bildirim Tercihleri',
                  subtitle: 'Ses, titreşim ve kategori alarmları',
                  iconBgColor: (isDark ? accentBlue : primaryColor).withValues(alpha: isDark ? 0.18 : 0.10),
                  iconColor: isDark ? accentBlue : primaryColor,
                  trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                  isDark: isDark,
                  textMain: textMain,
                  textSub: textSub,
                ),
                _buildDivider(isDark, borderColor),
                // 2. Takip Ettiğim Avcılar
                _buildSettingItem(
                  icon: Icons.people_alt_rounded,
                  title: 'Takip Ettiğim Avcılar',
                  subtitle: 'Takip listeniz ve paylaşımları',
                  iconBgColor: Colors.purple.withValues(alpha: isDark ? 0.18 : 0.10),
                  iconColor: isDark ? const Color(0xFFC084FC) : Colors.purple.shade600,
                  trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FollowingUsersScreen(),
                      ),
                    );
                  },
                  isDark: isDark,
                  textMain: textMain,
                  textSub: textSub,
                ),
                _buildDivider(isDark, borderColor),
                // 3. 🌟 HESAP, YARDIM & DESTEK MERKEZİ 🌟
                _buildSettingItem(
                  icon: Icons.tune_rounded,
                  title: 'Hesap, Yardım & Destek',
                  subtitle: 'Rozetler, rehber, iletişim ve güvenlik',
                  iconBgColor: Colors.blue.withValues(alpha: isDark ? 0.18 : 0.10),
                  iconColor: isDark ? const Color(0xFF60A5FA) : Colors.blue.shade600,
                  trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final updatedUser = await Navigator.push<AppUser>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupportHubScreen(
                          user: _user,
                          isOwnProfile: _isOwnProfile,
                        ),
                      ),
                    );
                    if (updatedUser != null && mounted) {
                      setState(() => _user = updatedUser);
                    }
                  },
                  isDark: isDark,
                  textMain: textMain,
                  textSub: textSub,
                ),
                if (_isAdmin) ...[
                  _buildDivider(isDark, borderColor),
                  _buildSettingItem(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Yönetici Kontrol Paneli',
                    subtitle: 'Botkolik ve içerik yönetimi',
                    iconBgColor: Colors.amber.withValues(alpha: isDark ? 0.18 : 0.10),
                    iconColor: isDark ? const Color(0xFFFBBF24) : Colors.amber.shade800,
                    trailing: Icon(Icons.chevron_right_rounded, color: textSub),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminScreen(),
                        ),
                      );
                    },
                    isDark: isDark,
                    textMain: textMain,
                    textSub: textSub,
                  ),
                ],
              ],
            ),
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
              return const Column(
                children: [
                  DealCardSkeleton(viewMode: CardViewMode.horizontal),
                  SizedBox(height: 12),
                  DealCardSkeleton(viewMode: CardViewMode.horizontal),
                ],
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
            if (!widget.isRootTab && Navigator.canPop(context))
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
              )
            else
              const SizedBox(width: 34),

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

            // Right Actions (Theme Switcher Button & Optional More Options)
            if (!_isOwnProfile && _user != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThemeToggleButton(context, isDark: isDark, textMain: textMain),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showProfileOptionsModal(_user!),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.more_horiz_rounded, size: 18, color: textMain),
                      ),
                    ),
                  ),
                ],
              )
            else
              _buildThemeToggleButton(context, isDark: isDark, textMain: textMain),
          ],
        ),
      ),
    );
  }

  // Quick Moon / Sun theme toggle button with Telegram-style circular transition
  Widget _buildThemeToggleButton(
    BuildContext context, {
    required bool isDark,
    required Color textMain,
  }) {
    return MorphingSunMoonButton(
      buttonKey: _themeButtonKey,
      isDark: isDark,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      onTap: () {
        CircularThemeTransition.animate(
          context: context,
          buttonKey: _themeButtonKey,
          isCurrentlyDark: isDark,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
          onToggleTheme: () => _themeService.toggleTheme(),
        );
      },
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
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required Widget trailing,
    VoidCallback? onTap,
    required bool isDark,
    Color? textMain,
    Color? textSub,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textMain ?? (isDark ? Colors.white : Colors.black87),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textSub ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark, [Color? borderColor]) {
    return Divider(
      height: 1,
      indent: 68,
      color: borderColor ?? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
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
        backgroundColor: isSuccess ? AppTheme.accent : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showProfileOptionsModal(AppUser user) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      showGuestLoginBottomSheet(context, title: 'İşlem Yap', message: 'Kullanıcıyı şikayet etmek veya engellemek için Giriş Yap! 🚀');
      return;
    }

    final isBlocked = await _firestoreService.isUserBlockedForChat(currentUserId, user.uid);
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              if (_isAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                  title: const Text('Rozet Yönet', style: TextStyle(fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBadgeDialog(user);
                  },
                ),
                const Divider(),
              ],
              ListTile(
                leading: Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded, color: Colors.orange),
                title: Text(
                  isBlocked ? 'Engeli Kaldır' : 'Kullanıcıyı Engelle 🚫',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (isBlocked) {
                    await _firestoreService.unblockUserForChat(currentUserId, user.uid);
                    if (mounted) {
                      _showFloatingSnackBar('Engelleme kaldırıldı', isSuccess: true);
                    }
                  } else {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Kullanıcıyı Engelle'),
                        content: Text('${user.username} kullanıcısını engellemek istediğinize emin misiniz? Engellenen kullanıcılar size mesaj gönderemez.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Engelle'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await _firestoreService.blockUserForChat(currentUserId, user.uid);
                      if (mounted) {
                        _showFloatingSnackBar('Kullanıcı engellendi', isSuccess: true);
                      }
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: const Text(
                  'Kullanıcıyı Şikayet Et',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  showReportDialog(
                    context,
                    reportedId: user.uid,
                    type: 'user',
                    targetAuthor: user.nickname ?? user.username,
                    targetAuthorId: user.uid,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
        NotificationService().requestPermission();
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
      if (nextNotification) {
        NotificationService().requestPermission();
      }
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
