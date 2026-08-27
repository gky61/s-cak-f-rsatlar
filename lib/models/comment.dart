import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sicak_firsatlar/utils/asset_path_migration.dart';

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
  final String? replyToUserName; // Cevap verilen kullanıcı adı
  final String? quotedCommentText; // Alıntılanan yorum metni
  final List<String> userBadges; // Kullanıcının rozetleri (yorum anındaki)
  final String? userPinnedBadge; // Kullanıcının vitrine sabitlediği rozet
  final Map<String, String> reactions; // userId -> emoji (ör: {'uid1': '❤️', 'uid2': '🔥'})

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
    this.replyToUserName,
    this.quotedCommentText,
    this.userBadges = const [],
    this.userPinnedBadge,
    this.reactions = const {},
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
      userProfileImageUrl: migrateAssetPath(data['userProfileImageUrl'] ?? ''),
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentCommentId: data['parentCommentId'],
      replyToUserName: data['replyToUserName'],
      quotedCommentText: data['quotedCommentText'],
      userBadges: List<String>.from(data['userBadges'] ?? []),
      userPinnedBadge: data['userPinnedBadge']?.toString() ?? data['pinnedBadge']?.toString(),
      reactions: (data['reactions'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
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
      'userBadges': userBadges,
    };
    if (userPinnedBadge != null && userPinnedBadge!.isNotEmpty) {
      map['userPinnedBadge'] = userPinnedBadge!;
    }
    if (parentCommentId != null) {
      map['parentCommentId'] = parentCommentId!;
    }
    if (replyToUserName != null) {
      map['replyToUserName'] = replyToUserName!;
    }
    if (quotedCommentText != null) {
      map['quotedCommentText'] = quotedCommentText!;
    }
    if (reactions.isNotEmpty) {
      map['reactions'] = reactions;
    }
    return map;
  }

  Comment copyWith({
    String? id,
    String? dealId,
    String? userId,
    String? userName,
    String? userEmail,
    String? userProfileImageUrl,
    String? text,
    DateTime? createdAt,
    String? parentCommentId,
    String? replyToUserName,
    String? quotedCommentText,
    List<String>? userBadges,
    String? userPinnedBadge,
    Map<String, String>? reactions,
  }) {
    return Comment(
      id: id ?? this.id,
      dealId: dealId ?? this.dealId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyToUserName: replyToUserName ?? this.replyToUserName,
      quotedCommentText: quotedCommentText ?? this.quotedCommentText,
      userBadges: userBadges ?? this.userBadges,
      userPinnedBadge: userPinnedBadge ?? this.userPinnedBadge,
      reactions: reactions ?? this.reactions,
    );
  }
}


