import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'message_screen.dart';
import 'profile_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUserId = _authService.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mesajlar'),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        ),
        body: const Center(
          child: Text('Mesajları görmek için giriş yapmalısınız'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        title: const Text('Mesajlar'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: StreamBuilder<List<Message>>(
        stream: _firestoreService.getUserMessagesStream(currentUserId),
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
                ],
              ),
            );
          }

          // Konuşmaları grupla (her kullanıcı ile son mesaj)
          final Map<String, Message> conversations = {};
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

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: conversationList.length,
            itemBuilder: (context, index) {
              final message = conversationList[index];
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

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MessageScreen(
                        otherUserId: otherUserId,
                        otherUserName: otherUserName,
                        otherUserImageUrl: otherUserImageUrl,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnread
                        ? (isDark
                            ? primaryColor.withValues(alpha: 0.15)
                            : primaryColor.withValues(alpha: 0.1))
                        : (isDark ? AppTheme.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipOval(
                        child: otherUserImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: otherUserImageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(strokeWidth: 2),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.person, size: 50),
                              )
                            : const Icon(Icons.person, size: 50),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    otherUserName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _formatTime(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message.text,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: isUnread
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
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
}

