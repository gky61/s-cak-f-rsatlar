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
  final List<String> badges; // Rozet listesi (örn: ['gold', 'top_reviewer', 'helpful'])

  AppUser({
    required this.uid,
    required this.username,
    required this.profileImageUrl,
    this.followedCategories = const [],
    this.nickname,
    this.points = 0,
    this.dealCount = 0,
    this.totalLikes = 0,
    this.badges = const [],
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
    List<String>? badges,
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
      badges: badges ?? this.badges,
    );
  }

  // Firestore'dan AppUser oluşturma
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Firestore data is null or not a Map');
      }
      
      // badges alanını güvenli bir şekilde parse et
      List<String> badges = [];
      try {
        final badgesData = data['badges'];
        if (badgesData != null) {
          if (badgesData is List) {
            // List<Object?> veya List<dynamic> olabilir, güvenli şekilde String'e çevir
            badges = badgesData
                .where((e) => e != null)
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList();
          } else if (badgesData is String) {
            // Eğer string olarak saklanmışsa (eski veri)
            badges = [];
          }
        }
      } catch (e) {
        print('Badges parse hatası: $e');
        badges = [];
      }
      
      // followedCategories alanını güvenli bir şekilde parse et
      List<String> followedCategories = [];
      try {
        final categoriesData = data['followedCategories'];
        if (categoriesData != null) {
          if (categoriesData is List) {
            // List<Object?> veya List<dynamic> olabilir, güvenli şekilde String'e çevir
            followedCategories = categoriesData
                .where((e) => e != null)
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList();
          } else if (categoriesData is String) {
            // Eğer string olarak saklanmışsa (eski veri)
            followedCategories = [];
          }
        }
      } catch (e) {
        print('FollowedCategories parse hatası: $e');
        followedCategories = [];
      }
      
      // Sayısal alanları güvenli bir şekilde parse et
      int parseInt(dynamic value, {int defaultValue = 0}) {
        if (value == null) return defaultValue;
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value);
          return parsed ?? defaultValue;
        }
        return defaultValue;
      }
      
      return AppUser(
        uid: doc.id,
        username: data['username']?.toString() ?? '',
        profileImageUrl: data['profileImageUrl']?.toString() ?? '',
        followedCategories: followedCategories,
        nickname: data['nickname']?.toString(),
        points: parseInt(data['points']),
        dealCount: parseInt(data['dealCount']),
        totalLikes: parseInt(data['totalLikes']),
        badges: badges,
      );
    } catch (e, stackTrace) {
      print('❌ AppUser.fromFirestore hatası: $e');
      print('Stack trace: $stackTrace');
      print('Document ID: ${doc.id}');
      print('Document data: ${doc.data()}');
      
      // Hata durumunda minimum bilgilerle kullanıcı oluştur
      final data = doc.data();
      final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};
      
      return AppUser(
        uid: doc.id,
        username: dataMap['username']?.toString() ?? 'Kullanıcı',
        profileImageUrl: dataMap['profileImageUrl']?.toString() ?? '',
        followedCategories: [],
        nickname: dataMap['nickname']?.toString(),
        points: 0,
        dealCount: 0,
        totalLikes: 0,
        badges: [],
      );
    }
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
      'badges': badges,
    };
  }
}

