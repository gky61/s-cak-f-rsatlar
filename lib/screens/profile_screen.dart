import 'package:flutter/material.dart';
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
import 'package:flutter/services.dart';

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
  bool _notificationsEnabled = true;
  bool _isAdmin = false;
  bool _isOwnProfile = true;

  @override
  void initState() {
    super.initState();
    _checkIfOwnProfile();
    _checkAdminStatus();
    _loadUserData();
    if (_isOwnProfile) {
      _loadNotificationSettings();
    }
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

    setState(() => _isLoading = true);
    
    try {
      final doc = await _firestore.collection('users').doc(targetUserId).get();
      if (doc.exists) {
        setState(() {
          _user = AppUser.fromFirestore(doc);
        });
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
            await _firestore.collection('users').doc(currentUser.uid).set(newUser.toFirestore());
            setState(() {
              _user = newUser;
            });
          }
        }
      }
    } catch (e) {
      print('Kullanıcı bilgisi yükleme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_authService.currentUser?.uid)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
      setState(() {
          _notificationsEnabled = userDoc.data()!['generalNotificationsEnabled'] ?? true;
        });
      }
    } catch (e) {
      print('Bildirim ayarları yükleme hatası: $e');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      await _firestore
          .collection('users')
          .doc(_authService.currentUser?.uid)
          .set({
        'generalNotificationsEnabled': value,
      }, SetOptions(merge: true));

      setState(() {
        _notificationsEnabled = value;
      });
    } catch (e) {
      print('Bildirim ayarı güncelleme hatası: $e');
    }
  }

  Future<void> _showProfileImagePicker(BuildContext context) async {
    // Assets klasöründeki profil resimleri
    final List<String> profileImages = [
      'assets/kullanıcı pp.jpg',
      'assets/kkpp.jpg',
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

    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'profileImageUrl': imageUrl,
      }, SetOptions(merge: true));

      await _loadUserData();

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
      print('Profil resmi güncelleme hatası: $e');
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
      // Firestore'daki username'i güncelle
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'username': newUsername,
      }, SetOptions(merge: true));

      // Firebase Auth'daki displayName'i de güncelle (yorumlarda görünmesi için)
      await user.updateDisplayName(newUsername);
      await user.reload();

      await _loadUserData();

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
      print('Kullanıcı adı güncelleme hatası: $e');
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
      await _authService.signOut();
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

  Future<void> _openTelegramChannel() async {
    const url = 'https://t.me/your_channel'; // TODO: Gerçek Telegram kanal URL'i
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                          // Edit Button
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
                          // Rozetler (kullanıcı adının altında)
                          if (_user?.badges != null && _user!.badges.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: BadgeHelper.getBadgeInfos(_user!.badges)
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
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Puan gösterimi
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withValues(alpha: 0.2),
                                  Colors.orange.shade300.withValues(alpha: 0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.stars_rounded,
                                  size: 16,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_user?.points ?? 0} Puan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
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
                      if (_isOwnProfile) ...[
                        const SizedBox(height: 20),
                        // Edit Profile Button
                        SizedBox(
                          width: 200,
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: () => _showProfileImagePicker(context),
                            icon: const Icon(Icons.manage_accounts, size: 18),
                            label: const Text('Profili Düzenle'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textMain,
                              backgroundColor: surfaceColor,
                              side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                                          ],
                                        ),
                                      ),

                // Settings Section (sadece kendi profilinde)
                if (_isOwnProfile) ...[
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
                          title: 'Bildirimler',
                          iconBgColor: primaryColor.withValues(alpha: 0.2),
                          iconColor: isDark ? Colors.yellow[200]! : Colors.yellow[800]!,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                    children: [
                              Switch(
                                value: _notificationsEnabled,
                                onChanged: _toggleNotifications,
                                activeColor: primaryColor,
                                activeTrackColor: primaryColor.withValues(alpha: 0.5),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey[400]),
                            ],
                          ),
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
                            // TODO: Privacy page
                          },
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        // Language
                        _buildSettingItem(
                          icon: Icons.language,
                          title: 'Dil Seçeneği',
                          iconBgColor: Colors.purple.withValues(alpha: 0.1),
                          iconColor: Colors.purple,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Türkçe', style: TextStyle(fontSize: 12, color: textSub, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, color: Colors.grey[400]),
                            ],
                          ),
                          onTap: () {
                            // TODO: Language selection
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
                            // TODO: FAQ page
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
                          onTap: () {
                            // TODO: Contact page
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
                          onTap: () {
                            // TODO: Rate app
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
                const SizedBox(height: 100), // Bottom nav padding
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
                    // Admin menü butonu (sadece admin ve başka kullanıcı profili görüntülenirken)
                    if (_isAdmin && !_isOwnProfile && _user != null)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: textMain),
                        onSelected: (value) {
                          if (value == 'badge') {
                            _showBadgeDialog(_user!);
                          } else if (value == 'block') {
                            _blockUser(_user!);
                          }
                        },
                        itemBuilder: (context) => [
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
                          // TODO: Kategoriler
                          Navigator.pop(context);
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
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                'Rozet Ekle:',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Kapat',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
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
      print('Rozet ekleme hatası: $e');
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
      print('Rozet kaldırma hatası: $e');
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
}