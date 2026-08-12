import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/asset_path_migration.dart';
import '../theme/app_theme.dart';
import 'message_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

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

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _messagesStream = _firestoreService.getUserMessagesStream(uid);
    } else {
      _messagesStream = const Stream.empty();
    }
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
          title: const Text('Mesajlar'),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          foregroundColor: textMain,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Mesajları görmek için giriş yapmalısınız'),
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

          // Konuşmaları grupla (her kullanıcı ile son mesaj)
          final Map<String, Message> conversations = {};
          int totalUnreadCount = 0;

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

            if (!message.isRead && message.receiverId == currentUserId) {
              totalUnreadCount++;
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
              // Sabit Header & Arama Barı
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    // Header Kartı
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
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
                        borderRadius: BorderRadius.circular(18),
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
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sohbet Kutusu',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: textMain,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: totalUnreadCount > 0 ? primaryColor : Colors.grey[600],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  totalUnreadCount > 0
                                      ? '$totalUnreadCount Okunmadı'
                                      : '${conversationList.length} Sohbet',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Diğer üyelerle fırsatlar hakkında özel sohbetleriniz ve yöneticilerden gelen resmi mesajlar burada güvenle saklanır.',
                            style: TextStyle(
                              color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mesaj Arama Barı (Klavye asla kapanmaz)
                    if (conversationList.isNotEmpty)
                      Container(
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
                            setState(() {
                              _searchQuery = val;
                            });
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
                  ],
                ),
              ),

              // Dinamik Sohbet Listesi
              Expanded(
                child: filteredList.isNotEmpty
                    ? ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filteredList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                          final isUnread = !message.isRead && message.receiverId == currentUserId;

                          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
                            builder: (context, userSnapshot) {
                              String displayName = otherUserName;
                              String profileImageUrl = otherUserImageUrl;

                              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                final userData = userSnapshot.data!.data();
                                displayName = userData?['username'] ?? userData?['displayName'] ?? otherUserName;
                                profileImageUrl = migrateAssetPath(userData?['profileImageUrl'] ?? otherUserImageUrl);
                              }

                              return _buildConversationCard(
                                context: context,
                                message: message,
                                otherUserId: otherUserId,
                                displayName: displayName,
                                profileImageUrl: profileImageUrl,
                                isUnread: isUnread,
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
                        ? SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.forum_outlined, size: 44, color: primaryColor),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Henüz mesajlaşmanız bulunmuyor',
                                      style: TextStyle(color: textMain, fontSize: 15.5, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Fırsat paylaşımları altındaki satıcı ve üyelerle iletişime geçerek sohbet başlatabilirsiniz.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: textSub, fontSize: 12.5, height: 1.4),
                                    ),
                                  ],
                                ),
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

  Widget _buildConversationCard({
    required BuildContext context,
    required Message message,
    required String otherUserId,
    required String displayName,
    required String profileImageUrl,
    required bool isUnread,
    required bool isDark,
    required Color primaryColor,
    required Color textMain,
    required Color? textSub,
    required Color surfaceColor,
  }) {
    final isAdmin = message.isAdminMessage;
    final cardDisplayName = isAdmin ? 'FırsatKolik Yönetim' : displayName;

    return Container(
      decoration: BoxDecoration(
        color: isUnread
            ? (isDark
                ? primaryColor.withValues(alpha: 0.16)
                : primaryColor.withValues(alpha: 0.08))
            : surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? primaryColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          width: isUnread ? 1.5 : 1,
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
              MaterialPageRoute(
                builder: (_) => MessageScreen(
                  otherUserId: isAdmin ? 'admin' : otherUserId,
                  otherUserName: cardDisplayName,
                  otherUserImageUrl: profileImageUrl,
                  isAdminMessage: isAdmin,
                ),
              ),
            );
          },
          onLongPress: () => _showDeleteDialog(context, message, cardDisplayName),
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
                                colors: [primaryColor, primaryColor.withValues(alpha: 0.5)],
                              )
                            : null,
                      ),
                      child: ClipOval(
                        child: isAdmin
                            ? Container(
                                color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                child: Icon(Icons.shield_outlined, color: primaryColor, size: 22),
                              )
                            : _buildAvatar(profileImageUrl, 48),
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
                            border: Border.all(color: surfaceColor, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Mesaj İletişim Detayları
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.verified_user_rounded, color: primaryColor, size: 14),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                              color: isUnread ? primaryColor : textSub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                          color: isUnread ? textMain : textSub,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String imageUrl, double size) {
    if (imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('assets/')) {
        return Image.asset(imageUrl, width: size, height: size, fit: BoxFit.cover);
      } else {
        return CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.grey[300]),
          errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.5, color: Colors.grey[400]),
        );
      }
    }
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.person, size: size * 0.5, color: Colors.grey[600]),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return DateFormat('HH:mm', 'tr_TR').format(date);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Dün';
    } else {
      return DateFormat('d MMM', 'tr_TR').format(date);
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, Message message, String userName) async {
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
            Text('Konuşmayı Sil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('$userName ile olan tüm konuşma geçmişinizi silmek istediğinize emin misiniz?'),
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

    if (confirmed == true && mounted) {
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
            await _firestoreService.deleteUserMessage(msg.id);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ $userName ile olan sohbet silindi'),
              backgroundColor: Colors.orange[800],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          );
        }
      } catch (e) {
        _log('Sohbet silme hatası: $e');
      }
    }
  }
}
