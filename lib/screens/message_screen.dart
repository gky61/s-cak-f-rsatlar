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
import 'profile_screen.dart';

class MessageScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserImageUrl;

  const MessageScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImageUrl,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isSending = false;
  final Set<String> _markedAsRead = {};

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead(List<Message> messages) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    for (final message in messages) {
      if (message.receiverId == currentUserId && 
          !message.isRead && 
          !_markedAsRead.contains(message.id)) {
        _markedAsRead.add(message.id);
        await _firestoreService.markMessageAsRead(message.id);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mesaj göndermek için giriş yapmalısınız'),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isSending = true);
    _messageController.clear();

    final messageId = await _firestoreService.sendMessage(
      senderId: currentUserId,
      receiverId: widget.otherUserId,
      text: text,
    );

    if (messageId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj gönderilemedi. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) {
      setState(() => _isSending = false);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUserId = _authService.currentUser?.uid;
    final textMain = isDark ? Colors.white : AppTheme.textPrimary;
    final textSub = isDark ? Colors.grey[400] : AppTheme.textSecondary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
      builder: (context, currentUserSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(),
          builder: (context, otherUserSnapshot) {
            String currentUserImageUrl = _authService.currentUser?.photoURL ?? '';
            if (currentUserSnapshot.hasData && currentUserSnapshot.data!.exists) {
              currentUserImageUrl = migrateAssetPath(currentUserSnapshot.data!.data()?['profileImageUrl'] ?? currentUserImageUrl);
            }

            String otherUserImageUrl = widget.otherUserImageUrl;
            String otherUserName = widget.otherUserName;
            if (otherUserSnapshot.hasData && otherUserSnapshot.data!.exists) {
              otherUserImageUrl = migrateAssetPath(otherUserSnapshot.data!.data()?['profileImageUrl'] ?? otherUserImageUrl);
              otherUserName = otherUserSnapshot.data!.data()?['username'] ?? otherUserSnapshot.data!.data()?['displayName'] ?? otherUserName;
            }

            return Scaffold(
              backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
              appBar: AppBar(
                backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                foregroundColor: textMain,
                elevation: 0,
                titleSpacing: 0,
                title: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.otherUserId)),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: ClipOval(
                            child: _buildAvatar(otherUserImageUrl, 38),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                otherUserName,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Üye Profili',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSub,
                                      fontWeight: FontWeight.w500,
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
              body: Column(
                children: [
                  // Mesaj Listesi
                  Expanded(
                    child: StreamBuilder<List<Message>>(
                      stream: currentUserId != null
                          ? _firestoreService.getConversationStream(currentUserId, widget.otherUserId)
                          : Stream.value([]),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Hata: ${snapshot.error}', style: TextStyle(color: Colors.red[400])),
                          );
                        }

                        final messages = snapshot.data ?? [];
                        if (messages.isNotEmpty) {
                          _markMessagesAsRead(messages);
                        }

                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.chat_outlined, size: 48, color: primaryColor),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Sohbete Başlayın',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aşağıdaki mesaj kutusundan ilk mesajınızı gönderin.',
                                  style: TextStyle(fontSize: 13, color: textSub),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe = message.senderId == currentUserId;
                            final showDate = index == 0 ||
                                messages[index - 1].createdAt.difference(message.createdAt).inDays != 0;

                            return Column(
                              children: [
                                if (showDate)
                                  Center(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDate(message.createdAt),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!isMe) ...[
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ProfileScreen(userId: message.senderId),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(shape: BoxShape.circle),
                                            child: ClipOval(child: _buildAvatar(otherUserImageUrl, 28)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? primaryColor
                                                : (isDark ? Colors.grey[800] : Colors.white),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(18),
                                              topRight: const Radius.circular(18),
                                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                                              bottomRight: Radius.circular(isMe ? 4 : 18),
                                            ),
                                            border: isMe
                                                ? null
                                                : Border.all(
                                                    color: isDark
                                                        ? Colors.white.withValues(alpha: 0.08)
                                                        : Colors.black.withValues(alpha: 0.06),
                                                    width: 1,
                                                  ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                message.text,
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  height: 1.35,
                                                  color: isMe
                                                      ? Colors.white
                                                      : (isDark ? Colors.white : AppTheme.textPrimary),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _formatTime(message.createdAt),
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w500,
                                                      color: isMe
                                                          ? Colors.white.withValues(alpha: 0.75)
                                                          : textSub,
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      message.isRead
                                                          ? Icons.done_all_rounded
                                                          : Icons.check_rounded,
                                                      size: 14,
                                                      color: Colors.white.withValues(alpha: 0.85),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isMe) const SizedBox(width: 4),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Mesaj Gönderme Çubuğu
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF1F3F5),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _messageController,
                                maxLines: 4,
                                minLines: 1,
                                textCapitalization: TextCapitalization.sentences,
                                style: TextStyle(color: textMain, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Bir mesaj yazın...',
                                  hintStyle: TextStyle(color: textSub?.withValues(alpha: 0.7), fontSize: 13.5),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _isSending ? null : _sendMessage,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: _isSending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Bugün';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Dün';
    } else {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    }
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'tr_TR').format(date);
  }

  Widget _buildAvatar(String imageUrl, double size) {
    if (imageUrl.isEmpty) {
      return Icon(Icons.person, size: size * 0.6, color: Colors.grey[400]);
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
