import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/comment.dart';
import 'auth_service.dart';
import 'content_moderation_service.dart';
import 'message_service.dart';
import '../utils/asset_path_migration.dart';
import 'system_log_service.dart';

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
    String? quotedCommentText,
    String? userProfileImageUrl,
    List<String>? userBadges,
    String? userPinnedBadge,
  }) async {
    try {
      // Yorum engeli kontrolü: Admin dahil kimse yorum yasağındayken yorum yapamaz
      final banDoc = await _firestore.collection('commentBannedUsers').doc(userId).get();
      if (banDoc.exists) throw Exception('Yorum yapma izniniz kısıtlanmıştır. Topluluk kurallarına uyum nedeniyle yorum yazamazsınız.');

      final isAdmin = await _authService.isAdmin();
      
      if (!isAdmin) {
        final doc = await _firestore.collection('settings').doc('app').get();
        final isSharingEnabled = doc.data()?['commentSharingEnabled'] ?? true;
        if (!isSharingEnabled) throw Exception('Yorum yapma özelliği geçici olarak kapalı.');
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
        userProfileImageUrl: userProfileImageUrl != null ? migrateAssetPath(userProfileImageUrl) : '',
        text: text,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
        replyToUserName: replyToUserName,
        quotedCommentText: quotedCommentText,
        userBadges: userBadges ?? [],
        userPinnedBadge: userPinnedBadge,
      );

      batch.set(commentRef, comment.toFirestore());
      batch.update(_firestore.collection('deals').doc(dealId), {
        'commentCount': FieldValue.increment(1),
      });

      await batch.commit();

      // Not: Yorum yanıt bildirimleri Cloud Function (onCommentCreated) tarafından 
      // Firestore ve FCM üzerinden sunucu tarafında otonom ve yetkili şekilde gönderilmektedir.

      return true;
    } catch (e, stack) {
      _log('Yorum ekleme hatası: $e');
      final isPerm = (e is FirebaseException && e.code == 'permission-denied') || e.toString().contains('permission-denied');
      final isBanned = e.toString().contains('Topluluk kurallarına uyum') || e.toString().contains('İçerik uygunsuz');
      if (!isBanned) {
        SystemLogService.instance.logError(
          category: 'comment',
          errorType: isPerm ? 'CommentPermissionDenied' : 'CommentSubmitException',
          message: 'Yorum eklenemedi (deal: $dealId): $e',
          stack: stack,
          severity: SystemErrorSeverity.error,
          metadata: {'dealId': dealId, 'userId': userId},
        );
      }
      if (isPerm) {
        throw Exception('Yorum yapma izniniz kısıtlanmıştır veya bu işlem için yetkiniz bulunmamaktadır.');
      }
      rethrow;
    }
  }

  Stream<List<Comment>> getCommentsStream(String dealId) {
    return _firestore
        .collection('deals')
        .doc(dealId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(150)
        .snapshots()
        .map((s) => s.docs.map((d) => Comment.fromFirestore(d)).toList());
  }

  Future<bool> deleteComment(String commentId, String dealId) async {
    try {
      final dealRef = _firestore.collection('deals').doc(dealId);
      final commentRef = dealRef.collection('comments').doc(commentId);

      return await _firestore.runTransaction((transaction) async {
        final dealDoc = await transaction.get(dealRef);
        final currentCount = dealDoc.exists ? ((dealDoc.data()?['commentCount'] as num?)?.toInt() ?? 0) : 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;

        transaction.delete(commentRef);
        if (dealDoc.exists) {
          transaction.update(dealRef, {
            'commentCount': newCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return true;
      });
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
        .limit(50)
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
          'read': data['read'] == true || data['read'] == 'true',
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
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('type', isEqualTo: 'comment_reply')
        .limit(400)
        .get();
    if (snapshot.docs.isEmpty) return 0;
    
    for (var i = 0; i < snapshot.docs.length; i += 400) {
      final end = (i + 400 > snapshot.docs.length) ? snapshot.docs.length : i + 400;
      final chunk = snapshot.docs.sublist(i, end);
      final batch = _firestore.batch();
      for (var doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return snapshot.docs.length;
  }

  /// Yorum için emoji tepkisini aç/kapat (Toggle)
  Future<void> toggleCommentReaction({
    required String dealId,
    required String commentId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final docRef = _firestore
          .collection('deals')
          .doc(dealId)
          .collection('comments')
          .doc(commentId);

      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data();
      final currentReactions = Map<String, dynamic>.from(data?['reactions'] ?? {});
      final currentEmoji = currentReactions[userId];

      if (currentEmoji == emoji) {
        // Toggle off - emoji kaldır
        await docRef.update({
          'reactions.$userId': FieldValue.delete(),
        });
      } else {
        // Yeni emoji ekle veya güncelle
        await docRef.update({
          'reactions.$userId': emoji,
        });
      }
    } catch (e) {
      _log('Yorum tepki değiştirme hatası: $e');
      rethrow;
    }
  }
}
