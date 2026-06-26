import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../models/admin_to_user_message.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'deal_detail_screen.dart';
import '../main.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedTab = 'all'; // 'all', 'admin', 'replies'

  String _formatDateTime(DateTime dt) {
    try {
      return DateFormat('d MMMM yyyy • HH:mm', 'tr_TR').format(dt);
    } catch (_) {
      return DateFormat('d MMM yyyy • HH:mm').format(dt);
    }
  }

  Future<void> _openMessage(AdminToUserMessage msg) async {
    // Okundu işaretle (sessiz)
    if (!msg.isRead) {
      await _firestoreService.markAdminToUserMessageAsRead(msg.id);
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(msg.title.isEmpty ? 'Bildirim' : msg.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDateTime(msg.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text(msg.content),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = _authService.currentUser?.uid;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: currentUserId != null 
                ? _combineNotificationStreams(currentUserId)
                : Stream.value([]),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty || currentUserId == null) {
                return const SizedBox.shrink();
              }
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => _showDeleteAllDialog(context, currentUserId!),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  tooltip: 'Tümünü Sil',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark 
                        ? Colors.white.withValues(alpha: 0.05) 
                        : Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.1) 
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: currentUserId == null
          ? const Center(child: Text('Bildirimleri görmek için giriş yapmalısınız'))
          : Column(
              children: [
                // Tab bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton('all', 'Tümü', isDark, primaryColor),
                      ),
                      Expanded(
                        child: _buildTabButton('admin', 'Admin', isDark, primaryColor),
                      ),
                      Expanded(
                        child: _buildTabButton('replies', 'Yorumlar', isDark, primaryColor),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _buildNotificationsContent(currentUserId, isDark, primaryColor),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton(String tab, String label, bool isDark, Color primaryColor) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsContent(String currentUserId, bool isDark, Color primaryColor) {
    if (_selectedTab == 'admin') {
      return _buildAdminNotifications(currentUserId, isDark);
    } else if (_selectedTab == 'replies') {
      return _buildCommentReplyNotifications(currentUserId, isDark, primaryColor);
    } else {
      // Tümü - hem admin hem yorum cevapları
      return _buildAllNotifications(currentUserId, isDark, primaryColor);
    }
  }

  Widget _buildAdminNotifications(String currentUserId, bool isDark) {
    return StreamBuilder<List<AdminToUserMessage>>(
              stream: _firestoreService.getAdminToUserMessagesStream(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }

                final items = snapshot.data ?? const <AdminToUserMessage>[];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz bildirim yok',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final msg = items[index];
                    final isUnread = !msg.isRead;
                    return InkWell(
                      onTap: () => _openMessage(msg),
                      onLongPress: () => _showDeleteDialog(context, msg),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUnread
                              ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F6FF))
                              : (isDark ? AppTheme.darkSurface : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.blueGrey[800] : Colors.blue[50])!,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.campaign,
                                color: isDark ? Colors.white : Colors.blue[700],
                              ),
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
                                          msg.title.isEmpty ? 'Bildirim' : msg.title,
                                          style: TextStyle(
                                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                            fontSize: 15,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('HH:mm').format(msg.createdAt),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    ),
                                  ),
                                  // Admin adı liste görünümünde gösterilmiyor (gereksiz kalabalık yapıyor)
                                ],
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 10),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
  }

  Widget _buildCommentReplyNotifications(String currentUserId, bool isDark, Color primaryColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getCommentReplyNotificationsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.comment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Henüz yorum cevabı bildirimi yok',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final notification = items[index];
            final isUnread = !(notification['read'] as bool);
            final replyUserName = notification['replyUserName'] as String;
            final dealTitle = notification['dealTitle'] as String;
            final replyText = notification['replyText'] as String;
            final createdAt = notification['createdAt'] as DateTime;
            final dealId = notification['dealId'] as String;
            final commentId = notification['commentId'] as String;
            
            return InkWell(
              onTap: () async {
                // Okundu işaretle
                if (isUnread) {
                  await _firestoreService.markCommentReplyNotificationAsRead(
                    currentUserId,
                    notification['id'] as String,
                  );
                }
                // Deal detay ekranına git
                if (mounted) {
                  final navigator = navigatorKey.currentState;
                  if (navigator != null) {
                    navigator.push(
                      MaterialPageRoute(
                        builder: (context) => DealDetailScreen(
                          dealId: dealId,
                          scrollToCommentId: commentId,
                        ),
                      ),
                    );
                  }
                }
              },
              onLongPress: () => _showDeleteCommentReplyDialog(context, currentUserId, notification),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUnread
                      ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F6FF))
                      : (isDark ? AppTheme.darkSurface : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.green[900] : Colors.green[50])!,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.reply_rounded,
                        color: isDark ? Colors.green[300] : Colors.green[700],
                      ),
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
                                  '$replyUserName yorumunuza cevap verdi',
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('HH:mm').format(createdAt),
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dealTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replyText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAllNotifications(String currentUserId, bool isDark, Color primaryColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _combineNotificationStreams(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Henüz bildirim yok',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final type = item['type'] as String;
            final isUnread = !(item['read'] as bool);
            
            if (type == 'admin') {
              final msg = item['data'] as AdminToUserMessage;
              return _buildAdminNotificationItem(msg, isUnread, isDark);
            } else {
              final notification = item['data'] as Map<String, dynamic>;
              return _buildCommentReplyNotificationItem(
                notification,
                isUnread,
                isDark,
                primaryColor,
                currentUserId,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAdminNotificationItem(AdminToUserMessage msg, bool isUnread, bool isDark) {
    return InkWell(
      onTap: () => _openMessage(msg),
      onLongPress: () => _showDeleteDialog(context, msg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F6FF))
              : (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isDark ? Colors.blueGrey[800] : Colors.blue[50])!,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.campaign,
                color: isDark ? Colors.white : Colors.blue[700],
              ),
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
                          msg.title.isEmpty ? 'Bildirim' : msg.title,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('HH:mm').format(msg.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 10),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentReplyNotificationItem(
    Map<String, dynamic> notification,
    bool isUnread,
    bool isDark,
    Color primaryColor,
    String currentUserId,
  ) {
    final replyUserName = notification['replyUserName'] as String;
    final dealTitle = notification['dealTitle'] as String;
    final replyText = notification['replyText'] as String;
    final createdAt = notification['createdAt'] as DateTime;
    final dealId = notification['dealId'] as String;
    final commentId = notification['commentId'] as String;
    
    return InkWell(
      onTap: () async {
        if (isUnread) {
          await _firestoreService.markCommentReplyNotificationAsRead(
            currentUserId,
            notification['id'] as String,
          );
        }
        if (mounted) {
          final navigator = navigatorKey.currentState;
          if (navigator != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (context) => DealDetailScreen(
                  dealId: dealId,
                  scrollToCommentId: commentId,
                ),
              ),
            );
          }
        }
      },
      onLongPress: () => _showDeleteCommentReplyDialog(context, currentUserId, notification),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F6FF))
              : (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isDark ? Colors.green[900] : Colors.green[50])!,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.reply_rounded,
                color: isDark ? Colors.green[300] : Colors.green[700],
              ),
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
                          '$replyUserName yorumunuza cevap verdi',
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('HH:mm').format(createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dealTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replyText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 10),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _combineNotificationStreams(String userId) {
    StreamController<List<Map<String, dynamic>>>? controller;
    StreamSubscription? adminSub;
    StreamSubscription? replySub;
    
    List<Map<String, dynamic>> adminItems = [];
    List<Map<String, dynamic>> replyItems = [];
    
    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        adminSub = _firestoreService.getAdminToUserMessagesStream(userId).listen((msgs) {
          adminItems = msgs.map((m) => {
            'type': 'admin',
            'id': m.id,
            'title': m.title.isEmpty ? 'Bildirim' : m.title,
            'content': m.content,
            'createdAt': m.createdAt,
            'read': m.isRead,
            'data': m,
          }).toList();
          _emitCombined(controller!, adminItems, replyItems);
        });
        
        replySub = _firestoreService.getCommentReplyNotificationsStream(userId).listen((notifs) {
          replyItems = notifs.map((n) => {
            'type': 'comment_reply',
            'id': n['id'] as String,
            'title': '${n['replyUserName']} yorumunuza cevap verdi',
            'content': '${n['dealTitle']}: ${n['replyText']}',
            'createdAt': n['createdAt'] as DateTime,
            'read': n['read'] as bool,
            'data': n,
          }).toList();
          _emitCombined(controller!, adminItems, replyItems);
        });
      },
      onCancel: () {
        adminSub?.cancel();
        replySub?.cancel();
        controller?.close();
      },
    );
    
    return controller.stream;
  }

  void _emitCombined(
    StreamController<List<Map<String, dynamic>>> controller,
    List<Map<String, dynamic>> adminItems,
    List<Map<String, dynamic>> replyItems,
  ) {
    final all = <Map<String, dynamic>>[];
    all.addAll(adminItems);
    all.addAll(replyItems);
    
    all.sort((a, b) {
      final aDate = a['createdAt'] as DateTime;
      final bDate = b['createdAt'] as DateTime;
      return bDate.compareTo(aDate);
    });
    
    if (!controller.isClosed) {
      controller.add(all);
    }
  }

  Future<void> _showDeleteCommentReplyDialog(
    BuildContext context,
    String userId,
    Map<String, dynamic> notification,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bildirimi Sil'),
        content: const Text('Bu bildirimi silmek istediğinize emin misiniz?'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firestoreService.deleteCommentReplyNotification(
          userId,
          notification['id'] as String,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim silindi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, AdminToUserMessage msg) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bildirimi Sil'),
        content: const Text('Bu bildirimi silmek istediğinize emin misiniz?'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firestoreService.deleteAdminToUserMessage(msg.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim silindi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteAllDialog(BuildContext context, String userId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tümünü Sil'),
        content: Text(
          _selectedTab == 'admin'
              ? 'Tüm admin bildirimlerini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'
              : _selectedTab == 'replies'
                  ? 'Tüm yorum cevabı bildirimlerini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'
                  : 'Tüm bildirimleri (admin + yorum cevapları) silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Tümünü Sil',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Loading göster
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        int totalDeleted = 0;
        
        // Seçili tab'a göre silme işlemi
        if (_selectedTab == 'admin') {
          totalDeleted = await _firestoreService.deleteAllAdminToUserMessages(userId);
        } else if (_selectedTab == 'replies') {
          totalDeleted = await _firestoreService.deleteAllCommentReplyNotifications(userId);
        } else {
          // Tümü - hem admin hem yorum cevapları
          final adminDeleted = await _firestoreService.deleteAllAdminToUserMessages(userId);
          final replyDeleted = await _firestoreService.deleteAllCommentReplyNotifications(userId);
          totalDeleted = adminDeleted + replyDeleted;
        }
        
        if (mounted) {
          Navigator.pop(context); // Loading dialog'u kapat
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                totalDeleted > 0 
                    ? '$totalDeleted bildirim silindi'
                    : 'Silinecek bildirim bulunamadı',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Loading dialog'u kapat
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme hatası: ${e.toString().length > 50 ? e.toString().substring(0, 50) + "..." : e}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}


