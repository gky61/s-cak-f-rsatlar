import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/comment.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'content_moderation_service.dart';
import 'message_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  Future<bool> addComment({
    required String dealId,
    required String userId,
    required String userName,
    required String userEmail,
    required String text,
    String? parentCommentId,
    String? replyToUserName,
    String? userProfileImageUrl,
    List<String>? userBadges,
  }) async {
    try {
      final isAdmin = await _authService.isAdmin();
      
      if (!isAdmin) {
        final doc = await _firestore.collection('settings').doc('app').get();
        final isSharingEnabled = doc.data()?['commentSharingEnabled'] ?? true;
        if (!isSharingEnabled) throw Exception('Yorum yapma özelliği geçici olarak kapalı.');
        
        final banDoc = await _firestore.collection('commentBannedUsers').doc(userId).get();
        if (banDoc.exists) throw Exception('Yorum yapma yetkiniz kaldırılmış.');
      }

      final moderationResult = ContentModerationService.moderateComment(text);
      if (!moderationResult.isSafe) {
        final messageService = MessageService();
        await messageService.createModerationMessage(
          type: 'comment',
          userId: userId,
          userName: userName,
          content: text,
          dealId: dealId,
          reason: moderationResult.reason ?? 'Uygunsuz yorum',
        );
        throw Exception('İçerik uygunsuz: ${moderationResult.reason}');
      }

      final batch = _firestore.batch();
      final commentRef = _firestore.collection('deals').doc(dealId).collection('comments').doc();
      
      final comment = Comment(
        id: commentRef.id,
        dealId: dealId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userProfileImageUrl: userProfileImageUrl ?? '',
        text: text,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
        replyToUserName: replyToUserName,
        userBadges: userBadges ?? [],
      );

      batch.set(commentRef, comment.toFirestore());
      batch.update(_firestore.collection('deals').doc(dealId), {
        'commentCount': FieldValue.increment(1),
      });

      await batch.commit();

      if (parentCommentId != null) {
        _sendReplyNotification(dealId, parentCommentId, commentRef.id, userName, text);
      }

      return true;
    } catch (e) {
      _log('Yorum ekleme hatası: $e');
      rethrow;
    }
  }

  Future<void> _sendReplyNotification(String dealId, String parentCommentId, String replyId, String userName, String text) async {
    try {
      final parentDoc = await _firestore.collection('deals').doc(dealId).collection('comments').doc(parentCommentId).get();
      if (!parentDoc.exists) return;
      
      final parentUserId = parentDoc.data()?['userId'];
      final currentUserId = _authService.currentUser?.uid;
      
      if (parentUserId != null && parentUserId != currentUserId) {
        final dealDoc = await _firestore.collection('deals').doc(dealId).get();
        final dealTitle = dealDoc.data()?['title'] ?? 'Fırsat';
        
        final notificationService = NotificationService();
        await notificationService.sendCommentReplyNotification(
          recipientUserId: parentUserId,
          dealId: dealId,
          dealTitle: dealTitle,
          commentId: replyId,
          parentCommentId: parentCommentId,
          replyUserName: userName,
          replyText: text,
        );
      }
    } catch (e) {
      _log('Bildirim hatası: $e');
    }
  }

  Stream<List<Comment>> getCommentsStream(String dealId) {
    return _firestore
        .collection('deals')
        .doc(dealId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => Comment.fromFirestore(d)).toList());
  }

  Future<bool> deleteComment(String commentId, String dealId) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('deals').doc(dealId).collection('comments').doc(commentId));
      batch.update(_firestore.collection('deals').doc(dealId), {'commentCount': FieldValue.increment(-1)});
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  // EKLENDİ: Yorum Cevabı Bildirimleri
  Stream<List<Map<String, dynamic>>> getCommentReplyNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: 'comment_reply')
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'dealId': data['dealId'] as String? ?? '',
          'dealTitle': data['dealTitle'] as String? ?? 'Fırsat',
          'commentId': data['commentId'] as String? ?? '',
          'parentCommentId': data['parentCommentId'] as String? ?? '',
          'replyUserName': data['replyUserName'] as String? ?? 'Birisi',
          'replyText': data['replyText'] as String? ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'read': data['read'] as bool? ?? false,
        };
      }).toList();
      
      notifications.sort((a, b) {
        final aDate = a['createdAt'] as DateTime;
        final bDate = b['createdAt'] as DateTime;
        return bDate.compareTo(aDate);
      });
      return notifications;
    });
  }

  Future<void> markCommentReplyNotificationAsRead(String userId, String notificationId) async {
    await _firestore.collection('users').doc(userId).collection('notifications').doc(notificationId).update({'read': true});
  }

  Future<void> deleteCommentReplyNotification(String userId, String notificationId) async {
    await _firestore.collection('users').doc(userId).collection('notifications').doc(notificationId).delete();
  }

  Future<int> deleteAllCommentReplyNotifications(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).collection('notifications').where('type', isEqualTo: 'comment_reply').get();
    if (snapshot.docs.isEmpty) return 0;
    
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snapshot.docs.length;
  }
}
