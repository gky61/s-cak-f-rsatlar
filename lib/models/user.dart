import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String username;
  final String profileImageUrl;
  final List<String> followedCategories;
  final String? nickname;
  final int points;
  final int dealCount;
  final int totalLikes;

  AppUser({
    required this.uid,
    required this.username,
    required this.profileImageUrl,
    this.followedCategories = const [],
    this.nickname,
    this.points = 0,
    this.dealCount = 0,
    this.totalLikes = 0,
  });

  // displayName getter (nickname varsa nickname, yoksa username)
  String get displayName => nickname ?? username;

  // Güvenilirlik yıldızları (0-5 arası)
  int get trustStars {
    if (points < 10) return 0;
    if (points < 30) return 1;
    if (points < 60) return 2;
    if (points < 100) return 3;
    if (points < 200) return 4;
    return 5;
  }

  // Güvenilirlik seviyesi
  String get trustLevel {
    if (points < 10) return 'Yeni Üye';
    if (points < 30) return 'Başlangıç';
    if (points < 60) return 'Aktif';
    if (points < 100) return 'Güvenilir';
    if (points < 200) return 'Çok Güvenilir';
    return 'Uzman';
  }

  // copyWith metodu
  AppUser copyWith({
    String? uid,
    String? username,
    String? profileImageUrl,
    List<String>? followedCategories,
    String? nickname,
    int? points,
    int? dealCount,
    int? totalLikes,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      followedCategories: followedCategories ?? this.followedCategories,
      nickname: nickname ?? this.nickname,
      points: points ?? this.points,
      dealCount: dealCount ?? this.dealCount,
      totalLikes: totalLikes ?? this.totalLikes,
    );
  }

  // Firestore'dan AppUser oluşturma
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      followedCategories: List<String>.from(data['followedCategories'] ?? []),
      nickname: data['nickname'],
      points: data['points'] ?? 0,
      dealCount: data['dealCount'] ?? 0,
      totalLikes: data['totalLikes'] ?? 0,
    );
  }

  // AppUser'i Firestore'a yazmak için Map'e dönüştürme
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'followedCategories': followedCategories,
      if (nickname != null) 'nickname': nickname,
      'points': points,
      'dealCount': dealCount,
      'totalLikes': totalLikes,
    };
  }
}

