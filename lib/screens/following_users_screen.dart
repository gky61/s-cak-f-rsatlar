import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/asset_path_migration.dart';
import '../widgets/skeletons/user_list_skeleton.dart';
import 'profile_screen.dart';
import 'message_screen.dart';

class FollowingUsersScreen extends StatefulWidget {
  const FollowingUsersScreen({super.key});

  @override
  State<FollowingUsersScreen> createState() => _FollowingUsersScreenState();
}

class _FollowingUsersScreenState extends State<FollowingUsersScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  late final Stream<List<AppUser>> _followingStream;
  late final Stream<Set<String>> _notificationSubsStream;

  String _searchQuery = '';

  // Local optimistic notification state cache for instantaneous UI response
  final Map<String, bool> _localNotificationState = {};

  @override
  void initState() {
    super.initState();
    final currentUid = _authService.currentUser?.uid;
    if (currentUid != null) {
      _followingStream = _firestoreService.getFollowingUsersStream(currentUid);
      _notificationSubsStream = _firestoreService.getFollowedNotificationUserIdsStream(currentUid);
    } else {
      _followingStream = const Stream.empty();
      _notificationSubsStream = const Stream.empty();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFloatingFeedback(String message, {bool isSuccess = true}) {
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
        duration: const Duration(milliseconds: 2200),
        elevation: 4,
      ),
    );
  }

  Future<void> _toggleNotification(String hunterUid, String hunterName, bool currentlyEnabled) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    final nextState = !currentlyEnabled;
    HapticFeedback.lightImpact();

    // Optimistic UI update
    setState(() {
      _localNotificationState[hunterUid] = nextState;
    });

    if (nextState) {
      _showFloatingFeedback('$hunterName yeni fırsat paylaştığında bildirim alacaksınız 🔔', isSuccess: true);
    } else {
      _showFloatingFeedback('$hunterName için anlık bildirimler kapatıldı 🔕', isSuccess: false);
    }

    try {
      await _firestoreService.toggleFollowNotification(currentUserId, hunterUid, nextState);
    } catch (e) {
      if (mounted) {
        setState(() {
          _localNotificationState[hunterUid] = currentlyEnabled;
        });
        _showFloatingFeedback('Ayar kaydedilemedi, lütfen tekrar deneyin.', isSuccess: false);
      }
    }
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
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Takipten Çık', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      try {
        await _firestoreService.unfollowUser(currentUserId, user.uid);
        _localNotificationState.remove(user.uid);
        _showFloatingFeedback('${user.displayName} takipten çıkarıldı', isSuccess: false);
      } catch (e) {
        _showFloatingFeedback('İşlem tamamlanamadı.', isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : AppTheme.textPrimary;
    final textSub = isDark ? Colors.grey[400] : AppTheme.textSecondary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
        appBar: AppBar(
          title: const Text('Takip Ettiklerim'),
          backgroundColor: surfaceColor,
          foregroundColor: textMain,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Kullanıcı oturumu bulunamadı'),
        ),
      );
    }

    return StreamBuilder<List<AppUser>>(
      stream: _followingStream,
      builder: (context, followingSnapshot) {
        final allFollowing = followingSnapshot.data ?? [];
        final totalCount = allFollowing.length;

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Takip Ettiklerim',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18.5, letterSpacing: -0.2),
                ),
                if (!followingSnapshot.hasError && followingSnapshot.connectionState != ConnectionState.waiting)
                  Text(
                    '$totalCount avcı takip ediliyor',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textSub),
                  ),
              ],
            ),
            backgroundColor: surfaceColor,
            foregroundColor: textMain,
            elevation: 0,
          ),
          body: Builder(
            builder: (context) {
              if (followingSnapshot.connectionState == ConnectionState.waiting) {
                return const UserListSkeleton();
              }

              if (followingSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 52, color: Colors.red[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Takip verileri yüklenirken bir sorun oluştu.',
                          style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return StreamBuilder<Set<String>>(
                stream: _notificationSubsStream,
                builder: (context, notifSnapshot) {
                  final activeNotifUids = notifSnapshot.data ?? <String>{};

                  final filteredUsers = allFollowing.where((u) {
                    if (_searchQuery.trim().isEmpty) return true;
                    final q = _searchQuery.toLowerCase();
                    return u.displayName.toLowerCase().contains(q) || u.username.toLowerCase().contains(q);
                  }).toList();

                  return Column(
                    children: [
                      // 1. ARAMA ÇUBUĞU
                      _buildSearchBar(
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        primaryColor: primaryColor,
                        textMain: textMain,
                        textSub: textSub,
                      ),

                      // 2. MİNİMALİST TAKİP EDİLEN SAYISI ŞERİDİ
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                        child: Row(
                          children: [
                            Text(
                              _searchQuery.isEmpty ? 'Takip Edilen Avcılar' : 'Arama Sonuçları',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textSub,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 0.8),
                              ),
                              child: Text(
                                '${filteredUsers.length} Avcı',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. AVCILAR LİSTESİ (Minimalist & Tek Satır Kartlar)
                      Expanded(
                        child: allFollowing.isEmpty
                            ? _buildEmptyFollowingState(
                                isDark: isDark,
                                textMain: textMain,
                                textSub: textSub,
                              )
                            : (filteredUsers.isEmpty && _searchQuery.isNotEmpty)
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        '"$_searchQuery" ile eşleşen takip edilen avcı bulunamadı.',
                                        style: TextStyle(color: textSub, fontSize: 13.5),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                                    itemCount: filteredUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = filteredUsers[index];
                                      final isNotifEnabled = _localNotificationState[user.uid] ?? activeNotifUids.contains(user.uid);

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _buildMinimalistHunterTile(
                                          user: user,
                                          isDark: isDark,
                                          primaryColor: primaryColor,
                                          surfaceColor: surfaceColor,
                                          borderColor: borderColor,
                                          textMain: textMain,
                                          textSub: textSub,
                                          isNotifEnabled: isNotifEnabled,
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ARAMA ÇUBUĞU
  // ===========================================================================
  Widget _buildSearchBar({
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color primaryColor,
    required Color textMain,
    required Color? textSub,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _searchQuery.isNotEmpty ? primaryColor.withValues(alpha: 0.6) : borderColor,
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Takip edilen avcılarda ara...',
            hintStyle: TextStyle(
              color: textSub?.withValues(alpha: 0.7),
              fontSize: 12.5,
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
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MİNİMALİST & TEK SATIR AVCI KARTI
  // ===========================================================================
  Widget _buildMinimalistHunterTile({
    required AppUser user,
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color borderColor,
    required Color textMain,
    required Color? textSub,
    required bool isNotifEnabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 1. SOL: AVATAR & KULLANICI BİLGİLERİ (Dokununca Profil Açar)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid)),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      // Avatar & Trust Ring
                      Stack(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [user.trustColor, user.trustColor.withValues(alpha: 0.4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: ClipOval(
                              child: Builder(
                                builder: (context) {
                                  final avatarUrl = migrateAssetPath(user.profileImageUrl);
                                  if (avatarUrl.isNotEmpty) {
                                    if (avatarUrl.startsWith('assets/')) {
                                      return Image.asset(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(Icons.person, size: 20, color: Colors.grey[400]),
                                      );
                                    }
                                    return CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey[300]),
                                      errorWidget: (_, __, ___) => Icon(Icons.person, size: 20, color: Colors.grey[400]),
                                    );
                                  }
                                  return Icon(Icons.person, size: 20, color: Colors.grey[400]);
                                },
                              ),
                            ),
                          ),
                          // Güvenilirlik Emojisi Rozeti
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: user.trustColor, width: 1.2),
                              ),
                              child: Text(
                                user.trustEmoji,
                                style: const TextStyle(fontSize: 9.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 11),

                      // İsim & @kullanıcıadı • Rütbe
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.displayName,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: textMain,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.isBot) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      'BOT',
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2.5),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '@${user.username}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSub,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: textSub?.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    user.trustLevel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: user.trustColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 2. SAĞ: AYNI HİZADA MİNİMALİST İKON BUTONLARI (Zil, Sohbet, Takipten Çık)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔔 BİLDİRİM ZİLİ (İkon Buton)
                _buildActionIconButton(
                  icon: isNotifEnabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  iconColor: isNotifEnabled ? const Color(0xFF10B981) : (textSub ?? Colors.grey),
                  bgColor: isNotifEnabled
                      ? const Color(0xFF10B981).withValues(alpha: 0.14)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                  borderColor: isNotifEnabled
                      ? const Color(0xFF10B981).withValues(alpha: 0.35)
                      : borderColor,
                  tooltip: isNotifEnabled ? 'Bildirimleri Kapat' : 'Bildirimleri Aç',
                  onTap: () => _toggleNotification(user.uid, user.displayName, isNotifEnabled),
                ),
                const SizedBox(width: 6),

                // 💬 SOHBET (İkon Buton)
                _buildActionIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: primaryColor,
                  bgColor: primaryColor.withValues(alpha: 0.10),
                  borderColor: primaryColor.withValues(alpha: 0.25),
                  tooltip: 'Mesaj Gönder',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessageScreen(
                          otherUserId: user.uid,
                          otherUserName: user.username,
                          otherUserImageUrl: user.profileImageUrl,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // 🚫 TAKİPTEN ÇIK (İkon Buton)
                _buildActionIconButton(
                  icon: Icons.person_remove_outlined,
                  iconColor: const Color(0xFFEF5350),
                  bgColor: isDark ? const Color(0xFF381B1B) : const Color(0xFFFFEBEE),
                  borderColor: const Color(0xFFEF5350).withValues(alpha: 0.25),
                  tooltip: 'Takipten Çık',
                  onTap: () => _unfollowUser(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MİNİMALİST AKSİYON İKON BUTONU (Eşit Boyut: 35x35)
  // ===========================================================================
  Widget _buildActionIconButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Center(
              child: Icon(icon, size: 16.5, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BOŞ DURUM WIDGET'I
  // ===========================================================================
  Widget _buildEmptyFollowingState({
    required bool isDark,
    required Color textMain,
    required Color? textSub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline_rounded, size: 48, color: textSub),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz Takip Ettiğiniz Avcı Yok',
              style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Fırsat avcılarının profillerini ziyaret ederek onları takip edebilir ve yeni paylaşımlarından anında haberdar olabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSub, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
