import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String dealId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userProfileImageUrl; // Kullanıcı profil resmi
  final String text;
  final DateTime createdAt;
  final String? parentCommentId; // Ana yorum ID'si (cevap ise)
  final String? replyToCommentId; // Cevap verilen yorum ID'si (cevaba cevap için)
  final String? replyToUserName; // Cevap verilen kullanıcı adı
  final int likeCount; // Beğeni sayısı
  final List<String> likedByUsers; // Beğenen kullanıcı ID'leri

  Comment({
    required this.id,
    required this.dealId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userProfileImageUrl = '', // Boş olabilir
    required this.text,
    required this.createdAt,
    this.parentCommentId,
    this.replyToCommentId, // Cevaba cevap için
    this.replyToUserName,
    this.likeCount = 0,
    this.likedByUsers = const [],
  });

  // Firestore'dan Comment oluşturma
  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // likedByUsers listesini parse et
    List<String> likedByUsers = [];
    if (data['likedByUsers'] != null) {
      if (data['likedByUsers'] is List) {
        likedByUsers = List<String>.from(data['likedByUsers']);
      }
    }
    
    return Comment(
      id: doc.id,
      dealId: data['dealId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userProfileImageUrl: data['userProfileImageUrl'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentCommentId: data['parentCommentId'],
      replyToCommentId: data['replyToCommentId'],
      replyToUserName: data['replyToUserName'],
      likeCount: (data['likeCount'] ?? 0) is int ? (data['likeCount'] ?? 0) : ((data['likeCount'] ?? 0) as num).toInt(),
      likedByUsers: likedByUsers,
    );
  }

  // Comment'i Firestore'a yazmak için Map'e dönüştürme
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'dealId': dealId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userProfileImageUrl': userProfileImageUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'likedByUsers': likedByUsers,
    };
    if (parentCommentId != null) {
      map['parentCommentId'] = parentCommentId!;
    }
    if (replyToCommentId != null) {
      map['replyToCommentId'] = replyToCommentId!;
    }
    if (replyToUserName != null) {
      map['replyToUserName'] = replyToUserName!;
    }
    return map;
  }
}


