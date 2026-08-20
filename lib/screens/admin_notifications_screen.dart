import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons/notification_list_skeleton.dart';
import 'deal_detail_screen.dart';
import 'message_screen.dart';

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

  Future<void> _openNotification(Map<String, dynamic> item) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    // Okundu işaretle
    if (!(item['read'] as bool)) {
      await _firestoreService.markNotificationAsRead(currentUserId, item['id'] as String);
    }

    final type = item['type'] as String;
    final dealId = item['dealId'] as String;
    final commentId = item['commentId'] as String;

    if (type == 'deal') {
      if (dealId.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(dealId: dealId),
          ),
        );
      }
    } else if (type == 'comment_reply') {
      if (dealId.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(
              dealId: dealId,
              scrollToCommentId: commentId.isNotEmpty ? commentId : null,
            ),
          ),
        );
      }
    } else if (type == 'admin_message') {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MessageScreen(
              otherUserId: 'admin',
              otherUserName: 'FırsatKolik Yönetim',
              otherUserImageUrl: 'assets/logo.webp',
              isAdminMessage: true,
            ),
          ),
        );
      }
    } else {
      // Genel duyuru / marketing / manual_notification için dialog göster
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(item['title'] as String),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTime(item['createdAt'] as DateTime),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(item['body'] as String),
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
          if (currentUserId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => _showDeleteAllDialog(context, currentUserId),
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getUserNotificationsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const NotificationListSkeleton();
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final allItems = snapshot.data ?? [];
        
        // Tab filtrelemesi
        final items = allItems.where((item) {
          final type = item['type'] as String;
          if (_selectedTab == 'admin') {
            return type == 'admin_message' || type == 'admin' || type == 'marketing' || type == 'manual_notification';
          } else if (_selectedTab == 'replies') {
            return type == 'comment_reply' || type == 'comment';
          }
          return true;
        }).toList();

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedTab == 'admin' 
                      ? Icons.campaign_outlined 
                      : (_selectedTab == 'replies' ? Icons.comment_outlined : Icons.notifications_none),
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedTab == 'admin'
                      ? 'Henüz admin bildirimi yok'
                      : (_selectedTab == 'replies' ? 'Henüz yorum cevabı bildirimi yok' : 'Henüz bildirim yok'),
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
            final isUnread = !(item['read'] as bool);
            final type = item['type'] as String;
            
            // İkon ve renk belirleme
            IconData icon = Icons.notifications;
            Color iconColor = Colors.orange;
            Color iconBg = isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange[50]!;

            if (type == 'comment_reply' || type == 'comment') {
              icon = Icons.reply_rounded;
              iconColor = Colors.green;
              iconBg = isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50]!;
            } else if (type == 'admin_message' || type == 'admin' || type == 'marketing' || type == 'manual_notification') {
              icon = Icons.campaign;
              iconColor = Colors.blue;
              iconBg = isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50]!;
            }

            final notifId = item['id'] as String;

            return Dismissible(
              key: Key(notifId),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF5350), Color(0xFFD32F2F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Sil',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
              onDismissed: (direction) async {
                final notifTitle = item['title'] as String? ?? 'Bildirim';

                // Firestore'dan tamamen sil
                await _firestoreService.deleteNotification(currentUserId, notifId);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"$notifTitle" silindi'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              child: InkWell(
                onTap: () => _openNotification(item),
                onLongPress: () => _showDeleteNotificationDialog(context, currentUserId, item),
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
                          color: iconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor),
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
                                    item['title'] as String,
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
                                  DateFormat('HH:mm').format(item['createdAt'] as DateTime),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (item['dealTitle'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2.0),
                                child: Text(
                                  item['dealTitle'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Text(
                              item['body'] as String,
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteNotificationDialog(
    BuildContext context,
    String userId,
    Map<String, dynamic> item,
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
        await _firestoreService.deleteNotification(userId, item['id'] as String);
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
        content: const Text('Tüm bildirimleri silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await _firestoreService.deleteAllNotifications(userId);
        
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tüm bildirimler silindi'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}
