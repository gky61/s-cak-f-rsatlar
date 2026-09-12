import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModerationAlarm {
  final String id;
  final String type; // 'deal', 'comment'
  final String userId;
  final String userName;
  final String content;
  final String? dealId;
  final String? commentId;
  final String reason;
  final bool isRead;
  final DateTime createdAt;

  AdminModerationAlarm({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    required this.content,
    this.dealId,
    this.commentId,
    required this.reason,
    required this.isRead,
    required this.createdAt,
  });

  factory AdminModerationAlarm.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AdminModerationAlarm(
      id: doc.id,
      type: data['type'] as String? ?? 'unknown',
      userId: data['userId'] as String? ?? 'unknown',
      userName: data['userName'] as String? ?? 'Bilinmeyen Kullanıcı',
      content: data['content'] as String? ?? '',
      dealId: data['dealId'] as String?,
      commentId: data['commentId'] as String?,
      reason: data['reason'] as String? ?? 'Uygunsuz içerik tespit edildi',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'userId': userId,
      'userName': userName,
      'content': content,
      'dealId': dealId,
      'commentId': commentId,
      'reason': reason,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
