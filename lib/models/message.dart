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

  // Fırsat referansı (Deal Context)
  final String? dealId;
  final String? dealTitle;
  final String? dealImageUrl;
  final String? dealPrice;
  final String? dealStore;

  // Alıntılama / Yanıtlama (Reply / Quote)
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToText;

  // Soft deletion ("Benden Sil")
  final List<String> deletedBy;

  // Optimistic UI ve durum kontrolü ('sending', 'sent', 'failed')
  final String status;

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
    this.dealId,
    this.dealTitle,
    this.dealImageUrl,
    this.dealPrice,
    this.dealStore,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToText,
    this.deletedBy = const [],
    this.status = 'sent',
  });

  // Firestore'dan Message oluşturma
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = (doc.data() as Map<String, dynamic>?) ?? {};
    
    // createdAt parse et
    DateTime createdAt;
    try {
      final createdAtValue = data['createdAt'];
      if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else if (createdAtValue is String) {
        createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      _log('⚠️ Message createdAt parse hatası: $e');
      createdAt = DateTime.now();
    }

    // deletedBy listesini güvenli parse et
    List<String> deletedBy = [];
    if (data['deletedBy'] is List) {
      deletedBy = (data['deletedBy'] as List)
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
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
      dealId: data['dealId'] as String?,
      dealTitle: data['dealTitle'] as String?,
      dealImageUrl: data['dealImageUrl'] != null ? migrateAssetPath(data['dealImageUrl']) : null,
      dealPrice: data['dealPrice'] as String?,
      dealStore: data['dealStore'] as String?,
      replyToMessageId: data['replyToMessageId'] as String?,
      replyToSenderName: data['replyToSenderName'] as String?,
      replyToText: data['replyToText'] as String?,
      deletedBy: deletedBy,
      status: 'sent',
    );
  }

  // adminToUserMessages koleksiyonundan Message dönüştürme
  factory Message.fromAdminFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime createdAt;
    try {
      final createdAtValue = data['createdAt'];
      if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else if (createdAtValue is String) {
        createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
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
      senderImageUrl: 'assets/logo.webp',
      receiverId: data['userId'] ?? '',
      receiverName: '',
      receiverImageUrl: '',
      text: fullText,
      createdAt: createdAt,
      isRead: data['isRead'] ?? false,
      isReadByAdmin: true,
      isAdminMessage: true,
      status: 'sent',
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
      if (dealId != null) 'dealId': dealId,
      if (dealTitle != null) 'dealTitle': dealTitle,
      if (dealImageUrl != null) 'dealImageUrl': dealImageUrl,
      if (dealPrice != null) 'dealPrice': dealPrice,
      if (dealStore != null) 'dealStore': dealStore,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      if (replyToText != null) 'replyToText': replyToText,
      if (deletedBy.isNotEmpty) 'deletedBy': deletedBy,
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
    String? dealId,
    String? dealTitle,
    String? dealImageUrl,
    String? dealPrice,
    String? dealStore,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToText,
    List<String>? deletedBy,
    String? status,
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
      dealId: dealId ?? this.dealId,
      dealTitle: dealTitle ?? this.dealTitle,
      dealImageUrl: dealImageUrl ?? this.dealImageUrl,
      dealPrice: dealPrice ?? this.dealPrice,
      dealStore: dealStore ?? this.dealStore,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToText: replyToText ?? this.replyToText,
      deletedBy: deletedBy ?? this.deletedBy,
      status: status ?? this.status,
    );
  }
}
