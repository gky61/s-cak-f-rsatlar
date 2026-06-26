import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Admin -> User tek yönlü bildirim/mesaj modeli
class AdminToUserMessage {
  final String id;
  final String userId;
  final String adminId;
  final String adminName;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  AdminToUserMessage({
    required this.id,
    required this.userId,
    required this.adminId,
    required this.adminName,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.isRead,
  });

  factory AdminToUserMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    DateTime createdAt;
    try {
      final v = data['createdAt'];
      if (v is Timestamp) {
        createdAt = v.toDate();
      } else if (v is DateTime) {
        createdAt = v;
      } else if (v is String) {
        createdAt = DateTime.tryParse(v) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      _log('⚠️ AdminToUserMessage createdAt parse hatası: $e');
      createdAt = DateTime.now();
    }

    return AdminToUserMessage(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      adminId: (data['adminId'] ?? '').toString(),
      adminName: (data['adminName'] ?? 'Admin').toString(),
      title: (data['title'] ?? '').toString(),
      content: (data['content'] ?? '').toString(),
      createdAt: createdAt,
      isRead: data['isRead'] == true,
    );
  }
}






