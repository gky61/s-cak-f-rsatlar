import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/user.dart';
import '../models/deal.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import 'deal_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Avatar seçenekleri
  static const List<String> avatarOptions = [
    'assets/iicon.jpg',
    'assets/kkpp.jpg',
    'assets/kullanıcı pp.jpg',
    'assets/kullanıcı profili.jpg',
  ];
  
  AppUser? _user;
  bool _isLoading = false;
  bool _isEditingNickname = false;
  final TextEditingController _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _user = AppUser.fromFirestore(doc);
          _nicknameController.text = _user?.nickname ?? '';
        });
      } else {
        // Kullanıcı yoksa oluştur
        final newUser = AppUser(
          uid: user.uid,
          username: user.displayName ?? user.email?.split('@')[0] ?? 'Kullanıcı',
          profileImageUrl: user.photoURL ?? '',
          points: 0,
          dealCount: 0,
          totalLikes: 0,
        );
        await _firestore.collection('users').doc(user.uid).set(newUser.toFirestore());
          setState(() {
          _user = newUser;
          _nicknameController.text = '';
          });
      }
    } catch (e) {
      print('Kullanıcı bilgisi yükleme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAvatarSelection() async {
    final selectedAvatar = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Avatar Seç',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: avatarOptions.map((avatarPath) {
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, avatarPath),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          avatarPath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.person, size: 50),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );

    if (selectedAvatar == null) return;

    setState(() => _isLoading = true);

    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // Firestore'da güncelle (asset path'i kaydet)
      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': selectedAvatar,
      });

      // Local state'i güncelle
      setState(() {
        _user = _user?.copyWith(profileImageUrl: selectedAvatar);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar seçildi ✅'),
            backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      print('Avatar güncelleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNickname() async {
    final newNickname = _nicknameController.text.trim();
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _isEditingNickname = false;
    });

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'nickname': newNickname,
      });

      setState(() {
        _user = _user?.copyWith(nickname: newNickname);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nickname güncellendi ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Nickname güncelleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
      // AuthWrapper otomatik olarak AuthScreen'e yönlendirecek
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading && _user == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: _user == null
          ? const Center(child: Text('Kullanıcı bilgisi yüklenemedi'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Avatar
                  GestureDetector(
                    onTap: _showAvatarSelection,
                        child: Stack(
                          children: [
                                  Container(
                          width: 120,
                          height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                              color: AppTheme.primary,
                              width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                          child: ClipOval(
                            child: _user!.profileImageUrl.isNotEmpty
                                ? (_user!.profileImageUrl.startsWith('assets/')
                                    ? Image.asset(
                                        _user!.profileImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Colors.grey[600],
                                              ),
                                          );
                                        },
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: _user!.profileImageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ))
                                : Container(
                                    color: Colors.grey[300],
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey[600],
                              ),
                            ),
                        ),
                      ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.face_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                  const SizedBox(height: 16),
                  // Username
                  Text(
                    _user!.username,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                                  ),
                  const SizedBox(height: 8),
                  // Nickname
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isEditingNickname) ...[
                        SizedBox(
                          width: 200,
                          child: TextField(
                                    controller: _nicknameController,
                            textAlign: TextAlign.center,
                                    style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                            autofocus: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: _saveNickname,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _isEditingNickname = false;
                              _nicknameController.text = _user?.nickname ?? '';
                            });
                          },
                        ),
                      ] else ...[
                        Text(
                          _user!.displayName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            setState(() {
                              _isEditingNickname = true;
                            });
                                    },
                        ),
                      ],
                    ],
                                  ),
                  const SizedBox(height: 16),
                  // Güvenilirlik Yıldızları ve Seviye
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.1),
                          AppTheme.secondary.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Yıldızlar
                        Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return Icon(
                              index < _user!.trustStars
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: index < _user!.trustStars
                                  ? Colors.amber
                                  : Colors.grey[400],
                              size: 28,
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        // Güvenilirlik Seviyesi
                                                Text(
                          _user!.trustLevel,
                                                  style: TextStyle(
                                                    fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                                                  ),
                                                ),
                        const SizedBox(height: 4),
                        // Puan
                        Text(
                          '${_user!.points} Puan',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  const SizedBox(height: 16),
                  // İstatistikler
                                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Paylaşım',
                            value: '${_user!.dealCount}',
                            color: AppTheme.primary,
                            isDark: isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                          child: _buildStatCard(
                            icon: Icons.favorite_rounded,
                            label: 'Beğeni',
                            value: '${_user!.totalLikes}',
                            color: Colors.red,
                            isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                  const SizedBox(height: 32),
                  // Kullanıcının Fırsatları
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Paylaştığım Fırsatlar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Fırsatlar Listesi
                                StreamBuilder<List<Deal>>(
                    stream: _firestoreService.getUserDealsStream(_user!.uid),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Hata: ${snapshot.error}'),
                                      );
                                    }
                                    
                                    final deals = snapshot.data ?? [];
                                    
                                    if (deals.isEmpty) {
                                      return Padding(
                          padding: const EdgeInsets.all(24.0),
                                          child: Column(
                                            children: [
                                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey[400],
                                              ),
                              const SizedBox(height: 16),
                                              Text(
                                'Henüz fırsat paylaşmadınız',
                                style: TextStyle(
                                                      color: Colors.grey[600],
                                  fontSize: 16,
                                                    ),
                                              ),
                                            ],
                                        ),
                                      );
                                    }
                                    
                      return ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 100),
                                      itemCount: deals.length,
                                      itemBuilder: (context, index) {
                                        return DealCard(
                                          deal: deals[index],
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                  builder: (_) => DealDetailScreen(dealId: deals[index].id),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                          ),
                          const SizedBox(height: 24),
                  // Çıkış Butonu
                                Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Çıkış Yap'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        ),
                                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
          width: 1.5,
        ),
                                                        boxShadow: [
                                                          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
      child: Column(
                                                        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
                                                          Text(
            value,
                                                            style: TextStyle(
              fontSize: 20,
                                                    fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                                  ),
                                            ),
          const SizedBox(height: 4),
                                            Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
            ),
    );
  }
}
