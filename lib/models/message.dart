import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:sicak_firsatlar/utils/asset_path_migration.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderImageUrl;
  final String receiverId;
  final String receiverName;
  final String receiverImageUrl;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  final bool isReadByAdmin;
  final bool isAdminMessage;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderImageUrl,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImageUrl,
    required this.text,
    required this.createdAt,
    this.isRead = false,
    this.isReadByAdmin = false,
    this.isAdminMessage = false,
  });

  // Firestore'dan Message oluşturma
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // createdAt'i parse et
    DateTime createdAt;
    try {
      final createdAtValue = data['createdAt'];
      if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else if (createdAtValue is String) {
        createdAt = DateTime.parse(createdAtValue);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      _log('⚠️ Message createdAt parse hatası: $e');
      createdAt = DateTime.now();
    }
    
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderImageUrl: migrateAssetPath(data['senderImageUrl'] ?? ''),
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverImageUrl: migrateAssetPath(data['receiverImageUrl'] ?? ''),
      text: data['text'] ?? '',
      createdAt: createdAt,
      isRead: data['isRead'] ?? false,
      isReadByAdmin: data['isReadByAdmin'] ?? false,
      isAdminMessage: data['isAdminMessage'] ?? false,
    );
  }

  // adminToUserMessages koleksiyonundan Message dönüştürme
  factory Message.fromAdminFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    DateTime createdAt;
    try {
      final createdAtValue = data['createdAt'];
      if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else if (createdAtValue is String) {
        createdAt = DateTime.parse(createdAtValue);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    final title = data['title'] ?? '';
    final content = data['content'] ?? '';
    final fullText = title.isNotEmpty ? '$title\n\n$content' : content;
    final adminName = data['adminName'] ?? 'FırsatKolik Yönetim';

    return Message(
      id: doc.id,
      senderId: data['adminId'] ?? 'admin',
      senderName: adminName,
      senderImageUrl: 'assets/images/app_icon.png',
      receiverId: data['userId'] ?? '',
      receiverName: '',
      receiverImageUrl: '',
      text: fullText,
      createdAt: createdAt,
      isRead: data['isRead'] ?? false,
      isReadByAdmin: true,
      isAdminMessage: true,
    );
  }

  // Message'i Firestore'a yazmak için Map'e dönüştürme
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImageUrl': receiverImageUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'isReadByAdmin': isReadByAdmin,
    };
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderImageUrl,
    String? receiverId,
    String? receiverName,
    String? receiverImageUrl,
    String? text,
    DateTime? createdAt,
    bool? isRead,
    bool? isReadByAdmin,
    bool? isAdminMessage,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderImageUrl: senderImageUrl ?? this.senderImageUrl,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverImageUrl: receiverImageUrl ?? this.receiverImageUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isReadByAdmin: isReadByAdmin ?? this.isReadByAdmin,
      isAdminMessage: isAdminMessage ?? this.isAdminMessage,
    );
  }
}






