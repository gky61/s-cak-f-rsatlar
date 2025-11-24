import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String dealId;
  final String userId;
  final String userName;
  final String userEmail;
  final String text;
  final DateTime createdAt;
  final String? parentCommentId; // Ana yorum ID'si (cevap ise)
  final String? replyToUserName; // Cevap verilen kullanıcı adı

  Comment({
    required this.id,
    required this.dealId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.text,
    required this.createdAt,
    this.parentCommentId,
    this.replyToUserName,
  });

  // Firestore'dan Comment oluşturma
  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      dealId: data['dealId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentCommentId: data['parentCommentId'],
      replyToUserName: data['replyToUserName'],
    );
  }

  // Comment'i Firestore'a yazmak için Map'e dönüştürme
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'dealId': dealId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (parentCommentId != null) {
      map['parentCommentId'] = parentCommentId!;
    }
    if (replyToUserName != null) {
      map['replyToUserName'] = replyToUserName!;
    }
    return map;
  }
}


