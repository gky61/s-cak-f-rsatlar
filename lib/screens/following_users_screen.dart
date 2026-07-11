import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class FollowingUsersScreen extends StatefulWidget {
  const FollowingUsersScreen({super.key});

  @override
  State<FollowingUsersScreen> createState() => _FollowingUsersScreenState();
}

class _FollowingUsersScreenState extends State<FollowingUsersScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : const Color(0xFF1C1C0D);
    final textSub = isDark ? Colors.grey[400] : const Color(0xFF5C5C4F);

    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          title: const Text('Takip Ettiklerim'),
        ),
        body: const Center(
          child: Text('Kullanıcı bulunamadı'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Takip Ettiklerim',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _firestoreService.getFollowingUsersStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hata: ${snapshot.error}',
                    style: TextStyle(color: Colors.red[400]),
                  ),
                ],
              ),
            );
          }

          final followingUsers = snapshot.data ?? [];

          if (followingUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz kimseyi takip etmiyorsunuz',
                    style: TextStyle(
                      fontSize: 16,
                      color: textSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kullanıcıları takip ederek onların paylaşımlarını takip edebilirsiniz',
                    style: TextStyle(
                      fontSize: 14,
                      color: textSub?.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: followingUsers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = followingUsers[index];
              return _buildFollowingUserItem(
                user: user,
                isDark: isDark,
                primaryColor: primaryColor,
                textMain: textMain,
                textSub: textSub,
                surfaceColor: surfaceColor,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFollowingUserItem({
    required AppUser user,
    required bool isDark,
    required Color primaryColor,
    required Color textMain,
    required Color? textSub,
    required Color surfaceColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Kullanıcının profilini aç
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: user.uid),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Profil görseli
              GestureDetector(
                onTap: () {
                  // Profil görseline tıklayınca da profil açılır
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(userId: user.uid),
                    ),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: user.profileImageUrl.isNotEmpty
                        ? (user.profileImageUrl.startsWith('assets/')
                            ? Image.asset(
                                user.profileImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.person, size: 28, color: Colors.grey[400]);
                                },
                              )
                            : CachedNetworkImage(
                                imageUrl: user.profileImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (context, url, error) => Icon(Icons.person, size: 28, color: Colors.grey[400]),
                              ))
                        : Icon(Icons.person, size: 28, color: Colors.grey[400]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Kullanıcı bilgileri
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Kullanıcı adına tıklayınca da profil açılır
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: user.uid),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                      ),
                      if (user.username != user.displayName) ...[
                        const SizedBox(height: 4),
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Takipten çık butonu
              IconButton(
                icon: Icon(
                  Icons.person_remove,
                  color: Colors.red[400],
                  size: 24,
                ),
                onPressed: () => _unfollowUser(user),
                tooltip: 'Takipten Çık',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unfollowUser(AppUser user) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Takipten Çık'),
        content: Text('${user.displayName} kullanıcısını takipten çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Takipten Çık'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firestoreService.unfollowUser(currentUserId, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.displayName} takipten çıkarıldı'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        _log('Takipten çıkma hatası: $e');
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
  }
}




