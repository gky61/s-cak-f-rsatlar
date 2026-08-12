import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : AppTheme.textPrimary;
    final textSub = isDark ? Colors.grey[400] : AppTheme.textSecondary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;

    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
        appBar: AppBar(
          title: const Text('Takip Ettiklerim'),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          foregroundColor: textMain,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Kullanıcı oturumu bulunamadı'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Takip Ettiklerim',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: textMain,
        elevation: 0,
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
                  Icon(Icons.error_outline_rounded, size: 52, color: Colors.red[400]),
                  const SizedBox(height: 12),
                  Text('Hata: ${snapshot.error}', style: TextStyle(color: Colors.red[400])),
                ],
              ),
            );
          }

          final allFollowing = snapshot.data ?? [];
          final filteredUsers = allFollowing.where((u) {
            if (_searchQuery.trim().isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return u.displayName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q);
          }).toList();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. BİLGİ VE TOPLAM SAYI KARTI (Glassmorphic Header) ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              primaryColor.withValues(alpha: 0.20),
                              primaryColor.withValues(alpha: 0.08),
                            ]
                          : [
                              primaryColor.withValues(alpha: 0.12),
                              primaryColor.withValues(alpha: 0.04),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.people_alt_rounded,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Favori Yayıncılar',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textMain,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${allFollowing.length} Takip Edilen',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Takip ettiğiniz kullanıcıların paylaştığı sıcak fırsatlar ve kuponlar anasayfanızda öncelikli gösterilir ve anında bildirim alırsınız.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─── 2. KULLANICI ARAMA BAR ───
                if (allFollowing.isNotEmpty) ...[
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty
                            ? primaryColor.withValues(alpha: 0.6)
                            : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06)),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Takip ettiklerinde kullanıcı ara...',
                        hintStyle: TextStyle(
                          color: textSub?.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSub),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.close_rounded, size: 16),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ─── 3. TAKİP EDİLENLER LİSTESİ ───
                if (filteredUsers.isNotEmpty) ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return _buildFollowingUserCard(
                        user: user,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        textMain: textMain,
                        textSub: textSub,
                        surfaceColor: surfaceColor,
                      );
                    },
                  ),
                ] else if (allFollowing.isEmpty) ...[
                  // BOŞ DURUM (Hiç kimse takip edilmiyor)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_add_rounded, size: 48, color: primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz kimseyi takip etmiyorsunuz',
                          style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Toplulukta beğendiğiniz kullanıcıların profilinden onları takip ederek paylaşımlarını kaçırmayın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSub, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // ARAMA SONUCU BULUNAMADI
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        '"$_searchQuery" ile eşleşen takip edilen kullanıcı bulunamadı',
                        style: TextStyle(color: textSub, fontSize: 13.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowingUserCard({
    required AppUser user,
    required bool isDark,
    required Color primaryColor,
    required Color textMain,
    required Color? textSub,
    required Color surfaceColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withValues(alpha: 0.5)],
                    ),
                  ),
                  child: ClipOval(
                    child: user.profileImageUrl.isNotEmpty
                        ? (user.profileImageUrl.startsWith('assets/')
                            ? Image.asset(user.profileImageUrl, fit: BoxFit.cover)
                            : CachedNetworkImage(
                                imageUrl: user.profileImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey[300]),
                                errorWidget: (_, __, ___) => Icon(Icons.person, size: 24, color: Colors.grey[400]),
                              ))
                        : Icon(Icons.person, size: 24, color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(width: 12),

                // İsim & Kullanıcı Adı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Takipten Çık Kapsül Buton
                InkWell(
                  onTap: () => _unfollowUser(user),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF381B1B) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFEF5350).withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.person_remove_rounded, size: 14, color: Color(0xFFC62828)),
                        SizedBox(width: 4),
                        Text(
                          'Takipten Çık',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unfollowUser(AppUser user) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: Color(0xFFEF5350)),
            SizedBox(width: 10),
            Text('Takipten Çık', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '${user.displayName} kullanıcısını takipten çıkarmak istediğinize emin misiniz?',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Takipten Çık'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      try {
        await _firestoreService.unfollowUser(currentUserId, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ ${user.displayName} takipten çıkarıldı'),
              backgroundColor: Colors.orange[800],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          );
        }
      } catch (e) {
        _log('Takipten çıkma hatası: $e');
      }
    }
  }
}
