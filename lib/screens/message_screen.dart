import 'package:flutter/material.dart';
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
  final Set<String> _markedAsRead = {}; // Zaten okundu olarak işaretlenen mesajlar

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Mesajları okundu olarak işaretle
  Future<void> _markMessagesAsRead(List<Message> messages) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    // Alıcı mesajları okundu olarak işaretle
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
        const SnackBar(
          content: Text('Mesaj göndermek için giriş yapmalısınız'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
        ),
      );
    }

    if (mounted) {
      setState(() => _isSending = false);
      // Mesaj gönderildikten sonra en alta scroll yap
      Future.delayed(const Duration(milliseconds: 300), () {
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
              backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
              appBar: AppBar(
                title: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: widget.otherUserId),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      ClipOval(
                        child: _buildAvatar(otherUserImageUrl, 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          otherUserName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
              ),
              body: Column(
        children: [
          // Mesaj listesi
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
                    child: Text('Hata: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                // Mesajları okundu olarak işaretle
                if (messages.isNotEmpty) {
                  _markMessagesAsRead(messages);
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz mesaj yok',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'İlk mesajınızı gönderin!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    final showDate = index == 0 ||
                        messages[index - 1].createdAt.difference(message.createdAt).inDays != 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDate)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDate(message.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        Row(
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
                                      builder: (context) => ProfileScreen(userId: message.senderId),
                                    ),
                                  );
                                },
                                child: ClipOval(
                                  child: _buildAvatar(otherUserImageUrl, 32),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? primaryColor
                                      : (isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[200]),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.text,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isMe
                                            ? Colors.white
                                            : (isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(message.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white70
                                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(userId: message.senderId),
                                    ),
                                  );
                                },
                                child: ClipOval(
                                  child: _buildAvatar(currentUserImageUrl, 32),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Mesaj gönderme alanı
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey[400]!,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
              ),
            );
          }
        );
      }
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
      return Icon(Icons.person, size: size);
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: size),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (context, url) => SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) => Icon(Icons.person, size: size),
    );
  }
}

