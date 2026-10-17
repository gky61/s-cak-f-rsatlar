import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../models/conversation.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/asset_path_migration.dart';
import '../theme/app_theme.dart';
import '../services/app_badge_service.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../widgets/skeletons/chat_list_skeleton.dart';
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

  Stream<List<Conversation>> _conversationsStream = const Stream.empty();
  StreamSubscription? _authSub;
  String _searchQuery = '';
  final Set<String> _mutedUserIds = {};

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: uid, forceSync: true);
    if (uid != null) {
      _conversationsStream = _getUnifiedConversationsStream(uid);
      _loadMutedUsers();
    } else {
      _conversationsStream = const Stream.empty();
    }

    _authSub = _authService.authStateChanges.listen((user) {
      if (!mounted) return;
      if (user != null) {
        setState(() {
          _conversationsStream = _getUnifiedConversationsStream(user.uid);
        });
        _loadMutedUsers();
      } else {
        setState(() {
          _conversationsStream = const Stream.empty();
          _mutedUserIds.clear();
        });
      }
    });
  }

  /// FS-MSG-01 & FS-MSG-03: Gelen kutusu için tekil, soket sızıntısı yapmayan akış.
  /// conversations koleksiyonundan N+1 okuma olmadan dinler; eski veriler varsa
  /// tek seferlik statik sorgu ile dönüştürür ve sürekli dinleyici açmaz.
  Stream<List<Conversation>> _getUnifiedConversationsStream(String uid) {
    late StreamController<List<Conversation>> controller;
    StreamSubscription? convSub;
    bool checkedLegacyMigration = false;

    controller = StreamController<List<Conversation>>(
      onListen: () {
        convSub = _firestoreService.getConversationsStream(uid).listen(
          (conversations) async {
            if (conversations.isNotEmpty) {
              if (!controller.isClosed) controller.add(conversations);
            } else {
              // conversations koleksiyonu henüz boşsa, tek seferlik legacy mesaj kontrolü yap
              if (!checkedLegacyMigration) {
                checkedLegacyMigration = true;
                try {
                  final snap = await FirebaseFirestore.instance
                      .collection('messages')
                      .where('participants', arrayContains: uid)
                      .orderBy('createdAt', descending: true)
                      .limit(60)
                      .get();

                  if (snap.docs.isNotEmpty) {
                    final messages = snap.docs.map((d) => Message.fromFirestore(d)).toList();
                    final migrated = _convertMessagesToConversations(messages, uid);
                    if (!controller.isClosed) {
                      controller.add(migrated);
                      return;
                    }
                  }
                } catch (_) {}
              }
              if (!controller.isClosed) controller.add([]);
            }
          },
          onError: (_) {
            if (!controller.isClosed) controller.add([]);
          },
        );
      },
      onCancel: () {
        convSub?.cancel();
      },
    );

    return controller.stream;
  }

  List<Conversation> _convertMessagesToConversations(List<Message> messages, String currentUserId) {
    final Map<String, Message> latestByOther = {};
    final Map<String, int> unreads = {};

    for (final msg in messages) {
      final otherUid = msg.senderId == currentUserId ? msg.receiverId : msg.senderId;
      if (!unreads.containsKey(otherUid)) unreads[otherUid] = 0;
      if (!msg.isRead && msg.receiverId == currentUserId) {
        unreads[otherUid] = (unreads[otherUid] ?? 0) + 1;
      }
      if (!latestByOther.containsKey(otherUid) || latestByOther[otherUid]!.createdAt.isBefore(msg.createdAt)) {
        latestByOther[otherUid] = msg;
      }
    }

    final list = latestByOther.entries.map((e) {
      final otherUid = e.key;
      final msg = e.value;
      final otherName = msg.senderId == currentUserId ? msg.receiverName : msg.senderName;
      final otherAvatar = msg.senderId == currentUserId ? msg.receiverImageUrl : msg.senderImageUrl;
      return Conversation(
        id: Conversation.computeConversationId(currentUserId, otherUid),
        participants: [currentUserId, otherUid],
        lastMessageText: msg.text,
        lastMessageSenderId: msg.senderId,
        lastMessageSenderName: msg.senderName,
        lastMessageCreatedAt: msg.createdAt,
        lastMessageIsRead: msg.isRead,
        lastMessageDealId: msg.dealId,
        lastMessageDealTitle: msg.dealTitle,
        updatedAt: msg.createdAt,
        unreadCounts: {currentUserId: unreads[otherUid] ?? 0},
        participantDetails: {
          otherUid: ConversationParticipant(name: otherName, avatar: otherAvatar),
        },
      );
    }).toList();

    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
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
    _authSub?.cancel();
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
                  onPressed: () async {
                    final loggedIn = await showGuestLoginBottomSheet(
                      context,
                      title: 'Mesajlar',
                      message: 'Kullanıcılarla iletişime geçmek ve özel fırsat detaylarını konuşmak için Google ile Giriş Yap! 🚀',
                    );
                    if (loggedIn == true && mounted) {
                      final uid = _authService.currentUser?.uid;
                      if (uid != null) {
                        setState(() {
                          _conversationsStream = _getUnifiedConversationsStream(uid);
                        });
                        _loadMutedUsers();
                      }
                    }
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
      body: StreamBuilder<List<Conversation>>(
        stream: _conversationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ChatListSkeleton();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 52, color: Colors.red[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Mesajlar yüklenirken bir sorun oluştu.',
                      style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final conversationList = snapshot.data ?? [];

          final filteredList = conversationList.where((conv) {
            if (_searchQuery.trim().isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            final otherName = conv.getOtherUserName(currentUserId).toLowerCase();
            final lastText = conv.lastMessageText.toLowerCase();
            return otherName.contains(q) || lastText.contains(q);
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

              // Dinamik Sohbet Listesi (FS-MSG-03: Sıfır N+1 Dinleyici Maliyeti)
              Expanded(
                child: filteredList.isNotEmpty
                    ? ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filteredList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final conv = filteredList[index];
                          final otherUserId = conv.getOtherUserId(currentUserId);
                          final displayName = conv.getOtherUserName(currentUserId);
                          final profileImageUrl = conv.getOtherUserAvatar(currentUserId);
                          final unreadCount = conv.getUnreadCount(currentUserId);
                          final isUnread = unreadCount > 0;
                          final isMuted = _mutedUserIds.contains(otherUserId);
                          final isDeleted = conv.participantDetails[otherUserId]?.isDeleted == true;

                          return _buildSwipeableConversationCard(
                            context: context,
                            conversation: conv,
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
    required Conversation conversation,
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
    final isSystemAdmin = otherUserId == 'admin' || conversation.id.startsWith('admin_');
    final cardDisplayName = isSystemAdmin ? 'FırsatKolik Yönetim' : (otherUserId == 'botkolik' ? 'Botkolik' : displayName);

    return Dismissible(
      key: Key('conv_${otherUserId}_${conversation.id}'),
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
        return await _showDeleteDialog(context, conversation, cardDisplayName);
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
                    otherUserId: otherUserId,
                    otherUserName: cardDisplayName,
                    otherUserImageUrl: isSystemAdmin
                        ? 'assets/logo.webp'
                        : (otherUserId == 'botkolik' ? 'assets/botkolik.webp' : profileImageUrl),
                    isAdminMessage: isSystemAdmin,
                  ),
                ),
              );
            },
            onLongPress: () => _showConversationActionsModal(conversation, otherUserId, cardDisplayName, isMuted, isUnread),
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
                          child: isSystemAdmin
                              ? Container(
                                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  child: Icon(Icons.shield_outlined, color: primaryColor, size: 22),
                                )
                              : (otherUserId == 'botkolik'
                                  ? Image.asset('assets/botkolik.webp', width: 48, height: 48, fit: BoxFit.cover)
                                  : _buildAvatar(profileImageUrl, 48, isDeleted: isDeleted)),
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
                                  if (isSystemAdmin) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.verified_user_rounded, color: primaryColor, size: 14),
                                  ],
                                  if (otherUserId == 'botkolik') ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.smart_toy_rounded, color: primaryColor, size: 14),
                                  ],
                                  if (isMuted) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.notifications_off_outlined, size: 13, color: textSub),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              _formatTime(conversation.lastMessageCreatedAt),
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
                                conversation.lastMessageText,
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
    Conversation conversation,
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
                    AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: currentUserId, forceSync: true);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Sohbeti Sil', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  _showDeleteDialog(context, conversation, userName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteDialog(BuildContext context, Conversation conversation, String userName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherUserId = conversation.getOtherUserId(_authService.currentUser?.uid ?? '');
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
          '$userName ile olan konuşma geçmişinizi silmek istediğinize emin misiniz?',
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
        final currentUserId = _authService.currentUser!.uid;
        if (conversation.id.startsWith('admin_') || otherUserId == 'admin') {
          try {
            await _firestoreService.deleteAllAdminToUserMessages(currentUserId);
          } catch (_) {}
        }
        await _firestoreService.clearConversationForUser(currentUserId, otherUserId);

        messenger.showSnackBar(
          SnackBar(
            content: Text('🗑️ $userName ile olan sohbet temizlendi'),
            backgroundColor: Colors.orange[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
        return true;
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Sohbet silinirken bir sorun oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
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
    final cleanUrl = migrateAssetPath(imageUrl);
    if (isDeleted || cleanUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
      );
    }
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[300],
          child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: cleanUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[300]),
      errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.6, color: Colors.grey[400]),
    );
  }
}
