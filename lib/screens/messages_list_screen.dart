import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/asset_path_migration.dart';
import '../theme/app_theme.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import 'message_screen.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  late final Stream<List<Message>> _messagesStream;
  String _searchQuery = '';
  final Set<String> _mutedUserIds = {};

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _messagesStream = _firestoreService.getUserMessagesStream(uid);
      _loadMutedUsers();
    } else {
      _messagesStream = const Stream.empty();
      // Misafir kullanıcı için bir sonraki frame'de login bottom sheet aç
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showGuestLoginBottomSheet(
            context,
            title: 'Mesajlar',
            message: 'Kullanıcılarla iletişime geçmek ve özel fırsat detaylarını konuşmak için Google ile Giriş Yap! 🚀',
          );
        }
      });
    }
  }

  Future<void> _loadMutedUsers() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final list = List<String>.from(doc.data()?['mutedConversations'] ?? []);
        setState(() {
          _mutedUserIds.addAll(list);
        });
      }
    } catch (_) {}
  }

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
          title: const Text('Mesajlar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          foregroundColor: textMain,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.forum_outlined, size: 54, color: primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mesajlaşmaya Başlayın',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textMain),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fırsat paylaşan üyelerle doğrudan sohbet etmek için giriş yapmalısınız.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: textSub, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    showGuestLoginBottomSheet(
                      context,
                      title: 'Mesajlar',
                      message: 'Kullanıcılarla iletişime geçmek ve özel fırsat detaylarını konuşmak için Google ile Giriş Yap! 🚀',
                    );
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Giriş Yap / Kaydol', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Mesajlar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: textMain,
        elevation: 0,
      ),
      body: StreamBuilder<List<Message>>(
        stream: _messagesStream,
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

          final messages = snapshot.data ?? [];

          // Konuşmaları grupla (her kullanıcı ile son mesaj) ve okunmamış sayılarını hesapla
          final Map<String, Message> conversations = {};
          final Map<String, int> unreadCounts = {};

          for (var message in messages) {
            final otherUserId = message.senderId == currentUserId
                ? message.receiverId
                : message.senderId;
            final otherUserName = message.senderId == currentUserId
                ? message.receiverName
                : message.senderName;
            final otherUserImageUrl = message.senderId == currentUserId
                ? message.receiverImageUrl
                : message.senderImageUrl;

            // Okunmamış sayısını artır
            if (!message.isRead && message.receiverId == currentUserId) {
              unreadCounts[otherUserId] = (unreadCounts[otherUserId] ?? 0) + 1;
            }

            if (!conversations.containsKey(otherUserId) ||
                conversations[otherUserId]!.createdAt.isBefore(message.createdAt)) {
              conversations[otherUserId] = message.copyWith(
                receiverName: otherUserName,
                receiverImageUrl: otherUserImageUrl,
              );
            }
          }

          final conversationList = conversations.values.toList();
          conversationList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final filteredList = conversationList.where((msg) {
            if (_searchQuery.trim().isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return msg.receiverName.toLowerCase().contains(q) ||
                msg.senderName.toLowerCase().contains(q) ||
                msg.text.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              // Arama Barı
              if (conversationList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty
                            ? primaryColor.withValues(alpha: 0.6)
                            : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                      style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Mesajlarda veya kişilerde ara...',
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
                ),

              // Dinamik Sohbet Listesi
              Expanded(
                child: filteredList.isNotEmpty
                    ? ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filteredList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final message = filteredList[index];
                          final otherUserId = message.senderId == currentUserId
                              ? message.receiverId
                              : message.senderId;
                          final otherUserName = message.senderId == currentUserId
                              ? message.receiverName
                              : message.senderName;
                          final otherUserImageUrl = message.senderId == currentUserId
                              ? message.receiverImageUrl
                              : message.senderImageUrl;
                          final unreadCount = unreadCounts[otherUserId] ?? 0;
                          final isUnread = unreadCount > 0;
                          final isMuted = _mutedUserIds.contains(otherUserId);

                          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
                            builder: (context, userSnapshot) {
                              String displayName = otherUserName;
                              String profileImageUrl = otherUserImageUrl;
                              bool isDeleted = false;

                              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                final userData = userSnapshot.data!.data();
                                displayName = userData?['username'] ?? userData?['displayName'] ?? otherUserName;
                                profileImageUrl = migrateAssetPath(userData?['profileImageUrl'] ?? otherUserImageUrl);
                              } else if (userSnapshot.connectionState == ConnectionState.active &&
                                  (!userSnapshot.hasData || !userSnapshot.data!.exists) &&
                                  !message.isAdminMessage) {
                                isDeleted = true;
                                displayName = 'Silinmiş Kullanıcı';
                                profileImageUrl = '';
                              }

                              return _buildSwipeableConversationCard(
                                context: context,
                                message: message,
                                otherUserId: otherUserId,
                                displayName: displayName,
                                profileImageUrl: profileImageUrl,
                                isUnread: isUnread,
                                unreadCount: unreadCount,
                                isMuted: isMuted,
                                isDeleted: isDeleted,
                                isDark: isDark,
                                primaryColor: primaryColor,
                                textMain: textMain,
                                textSub: textSub,
                                surfaceColor: surfaceColor,
                              );
                            },
                          );
                        },
                      )
                    : (conversationList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.forum_outlined, size: 48, color: primaryColor),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Henüz mesajlaşmanız bulunmuyor',
                                    style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Fırsat paylaşımları altındaki satıcı ve üyelerle iletişime geçerek sohbet başlatabilirsiniz.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: textSub, fontSize: 13, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                '"$_searchQuery" ile eşleşen mesaj veya sohbet bulunamadı',
                                style: TextStyle(color: textSub, fontSize: 13.5),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSwipeableConversationCard({
    required BuildContext context,
    required Message message,
    required String otherUserId,
    required String displayName,
    required String profileImageUrl,
    required bool isUnread,
    required int unreadCount,
    required bool isMuted,
    required bool isDeleted,
    required bool isDark,
    required Color primaryColor,
    required Color textMain,
    required Color? textSub,
    required Color surfaceColor,
  }) {
    final isAdmin = message.isAdminMessage;
    final cardDisplayName = isAdmin ? 'FırsatKolik Yönetim' : displayName;

    return Dismissible(
      key: Key('conv_${otherUserId}_${message.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            SizedBox(width: 6),
            Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteDialog(context, message, cardDisplayName);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark ? primaryColor.withValues(alpha: 0.14) : primaryColor.withValues(alpha: 0.07))
              : surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? primaryColor.withValues(alpha: 0.4)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
                MaterialPageRoute(
                  builder: (_) => MessageScreen(
                    otherUserId: isAdmin ? 'admin' : otherUserId,
                    otherUserName: cardDisplayName,
                    otherUserImageUrl: isAdmin ? 'assets/logo.webp' : profileImageUrl,
                    isAdminMessage: isAdmin,
                  ),
                ),
              );
            },
            onLongPress: () => _showConversationActionsModal(message, otherUserId, cardDisplayName, isMuted, isUnread),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: EdgeInsets.all(isUnread ? 2 : 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isUnread
                              ? LinearGradient(
                                  colors: [primaryColor, primaryColor.withValues(alpha: 0.6)],
                                )
                              : null,
                        ),
                        child: ClipOval(
                          child: isAdmin
                              ? Container(
                                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  child: Icon(Icons.shield_outlined, color: primaryColor, size: 22),
                                )
                              : _buildAvatar(profileImageUrl, 48, isDeleted: isDeleted),
                        ),
                      ),
                      if (isUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: surfaceColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Kullanıcı Adı & Son Mesaj
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      cardDisplayName,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                        color: textMain,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.verified_user_rounded, color: primaryColor, size: 14),
                                  ],
                                  if (isMuted) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.notifications_off_outlined, size: 13, color: textSub),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                color: isUnread ? primaryColor : textSub,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                message.text,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                                  color: isUnread ? (isDark ? Colors.white : AppTheme.textPrimary) : textSub,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  void _showConversationActionsModal(
    Message message,
    String otherUserId,
    String userName,
    bool isMuted,
    bool isUnread,
  ) {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : Colors.white,
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
              ListTile(
                leading: Icon(isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                title: Text(isMuted ? 'Bildirimleri Aç' : 'Sessize Al 🔕'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _firestoreService.toggleMuteConversation(currentUserId, otherUserId, !isMuted);
                  setState(() {
                    if (isMuted) {
                      _mutedUserIds.remove(otherUserId);
                    } else {
                      _mutedUserIds.add(otherUserId);
                    }
                  });
                },
              ),
              if (isUnread)
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined, color: Colors.blue),
                  title: const Text('Okundu Olarak İşaretle'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _firestoreService.markConversationAsRead(currentUserId, otherUserId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Sohbeti Sil', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  _showDeleteDialog(context, message, userName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteDialog(BuildContext context, Message message, String userName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350)),
            SizedBox(width: 10),
            Text('Sohbeti Sil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '$userName ile olan tüm konuşma geçmişinizi silmek istediğinize emin misiniz?',
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
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      HapticFeedback.mediumImpact();
      try {
        if (message.isAdminMessage) {
          await _firestoreService.deleteAdminToUserMessage(message.id);
        } else {
          final currentUserId = _authService.currentUser!.uid;
          final messages = await _firestoreService.getUserMessagesStream(currentUserId).first;
          final otherUserId = message.senderId == currentUserId
              ? message.receiverId
              : message.senderId;

          final conversationMessages = messages.where((m) =>
            !m.isAdminMessage &&
            ((m.senderId == currentUserId && m.receiverId == otherUserId) ||
            (m.receiverId == currentUserId && m.senderId == otherUserId))
          ).toList();

          for (var msg in conversationMessages) {
            await _firestoreService.softDeleteMessageForUser(msg.id, currentUserId);
          }
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text('🗑️ $userName ile olan sohbet silindi'),
            backgroundColor: Colors.orange[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
        return true;
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
        return false;
      }
    }
    return false;
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return DateFormat('HH:mm', 'tr_TR').format(date);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Dün';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE', 'tr_TR').format(date);
    } else {
      return DateFormat('d MMM', 'tr_TR').format(date);
    }
  }

  Widget _buildAvatar(String imageUrl, double size, {bool isDeleted = false}) {
    if (isDeleted || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
      );
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, width: size, height: size, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[300]),
      errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.6, color: Colors.grey[400]),
    );
  }
}
