import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:sicak_firsatlar/utils/asset_path_migration.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class AppUser {
  final String uid;
  final String username;
  final String profileImageUrl;
  final List<String> followedCategories;
  final List<String> watchKeywords; // Takip edilen anahtar kelimeler
  final List<String> following; // Takip edilen kullanıcılar (user ID'leri)
  final List<String> followersWithNotifications; // Bildirim almak isteyen takipçiler (user ID'leri)
  final String? nickname;
  final int points;
  final int dealCount;
  final int totalLikes;
  final List<String> badges; // Rozet listesi (örn: ['gold', 'top_reviewer', 'helpful'])
  final String? pinnedBadge; // Kullanıcının vitrinde/profilinde sabitlediği öncelikli rozet
  final bool isBot;

  AppUser({
    required this.uid,
    required this.username,
    required this.profileImageUrl,
    this.followedCategories = const [],
    this.watchKeywords = const [],
    this.following = const [],
    this.followersWithNotifications = const [],
    this.nickname,
    this.points = 0,
    this.dealCount = 0,
    this.totalLikes = 0,
    this.badges = const [],
    this.pinnedBadge,
    this.isBot = false,
  });

  // displayName getter (nickname varsa nickname, yoksa username, en son fallback 'Kullanıcı')
  String get displayName => (nickname != null && nickname!.trim().isNotEmpty)
      ? nickname!.trim()
      : (username.trim().isNotEmpty ? username.trim() : 'Kullanıcı');

  // Güvenilirlik yıldızları (0-9 arası)
  int get trustStars {
    if (points < 20) return 0;
    if (points < 50) return 1;
    if (points < 120) return 2;
    if (points < 250) return 3;
    if (points < 500) return 4;
    if (points < 1000) return 5;
    if (points < 2500) return 6;
    if (points < 5000) return 7;
    if (points < 10000) return 8;
    return 9;
  }

  // Güvenilirlik seviyesi ve Avcı Rütbesi
  String get trustLevel {
    if (points < 20) return 'Çaylak Avcı';
    if (points < 50) return 'Çırak Avcı';
    if (points < 120) return 'Aktif Avcı';
    if (points < 250) return 'Güvenilir Avcı';
    if (points < 500) return 'Kıdemli Avcı';
    if (points < 1000) return 'Uzman Avcı';
    if (points < 2500) return 'Üstat Avcı';
    if (points < 5000) return 'Efsanevi Avcı';
    if (points < 10000) return 'Kozmik Avcı';
    return 'Fırsat Lordu';
  }

  // Güvenilirlik seviyesi / Avcı Rütbesi İkonu
  IconData get trustIcon {
    if (points < 20) return Icons.shield_outlined;
    if (points < 50) return Icons.military_tech_outlined;
    if (points < 120) return Icons.bolt_rounded;
    if (points < 250) return Icons.shield_rounded;
    if (points < 500) return Icons.stars_rounded;
    if (points < 1000) return Icons.auto_awesome_rounded;
    if (points < 2500) return Icons.diamond_rounded;
    if (points < 5000) return Icons.workspace_premium_rounded;
    if (points < 10000) return Icons.flare_rounded;
    return Icons.military_tech_rounded;
  }

  // Güvenilirlik seviyesi / Avcı Rütbesi Vurgu Rengi
  Color get trustColor {
    if (points < 20) return const Color(0xFF94A3B8); // Çaylak (Slate)
    if (points < 50) return const Color(0xFF64748B); // Çırak (Steel)
    if (points < 120) return const Color(0xFF10B981); // Aktif (Emerald)
    if (points < 250) return const Color(0xFFD97706); // Güvenilir (Amber)
    if (points < 500) return const Color(0xFF3B82F6); // Kıdemli (Blue)
    if (points < 1000) return const Color(0xFF8B5CF6); // Uzman (Purple)
    if (points < 2500) return const Color(0xFF06B6D4); // Üstat (Cyan)
    if (points < 5000) return const Color(0xFFEC4899); // Efsanevi (Ruby/Pink)
    if (points < 10000) return const Color(0xFFF59E0B); // Kozmik (Gold)
    return const Color(0xFFEAB308); // Fırsat Lordu (Crown Gold)
  }

  // Güvenilirlik seviyesi / Avcı Rütbesi Emojisi
  String get trustEmoji {
    if (points < 20) return '🌱';
    if (points < 50) return '🏹';
    if (points < 120) return '⚡';
    if (points < 250) return '🛡️';
    if (points < 500) return '⭐';
    if (points < 1000) return '🔮';
    if (points < 2500) return '💎';
    if (points < 5000) return '🦅';
    if (points < 10000) return '🪐';
    return '👑';
  }

  // copyWith metodu
  AppUser copyWith({
    String? uid,
    String? username,
    String? profileImageUrl,
    List<String>? followedCategories,
    List<String>? watchKeywords,
    List<String>? following,
    List<String>? followersWithNotifications,
    String? nickname,
    int? points,
    int? dealCount,
    int? totalLikes,
    List<String>? badges,
    String? pinnedBadge,
    bool? isBot,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      followedCategories: followedCategories ?? this.followedCategories,
      watchKeywords: watchKeywords ?? this.watchKeywords,
      following: following ?? this.following,
      followersWithNotifications: followersWithNotifications ?? this.followersWithNotifications,
      nickname: nickname ?? this.nickname,
      points: points ?? this.points,
      dealCount: dealCount ?? this.dealCount,
      totalLikes: totalLikes ?? this.totalLikes,
      badges: badges ?? this.badges,
      pinnedBadge: pinnedBadge ?? this.pinnedBadge,
      isBot: isBot ?? this.isBot,
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
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();
            _log('✅ Badges parsed: ${badges.length} rozet - $badges');
          } else if (badgesData is String) {
            // Eğer string olarak saklanmışsa (eski veri)
            badges = [];
            _log('⚠️ Badges string formatında, boş liste döndürülüyor');
          }
        } else {
          _log('ℹ️ Badges data null');
        }
      } catch (e) {
        _log('❌ Badges parse hatası: $e');
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
        _log('FollowedCategories parse hatası: $e');
        followedCategories = [];
      }
      
      // watchKeywords alanını güvenli bir şekilde parse et
      List<String> watchKeywords = [];
      try {
        final keywordsData = data['watchKeywords'];
        if (keywordsData != null) {
          if (keywordsData is List) {
            watchKeywords = keywordsData
                .where((e) => e != null)
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      } catch (e) {
        _log('WatchKeywords parse hatası: $e');
        watchKeywords = [];
      }

      // following alanını güvenli bir şekilde parse et
      List<String> following = [];
      try {
        final followingData = data['following'];
        if (followingData != null && followingData is List) {
          following = followingData
              .where((e) => e != null)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (e) {
        _log('Following parse hatası: $e');
        following = [];
      }

      // followersWithNotifications alanını güvenli bir şekilde parse et
      List<String> followersWithNotifications = [];
      try {
        final followersData = data['followersWithNotifications'];
        if (followersData != null && followersData is List) {
          followersWithNotifications = followersData
              .where((e) => e != null)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (e) {
        _log('FollowersWithNotifications parse hatası: $e');
        followersWithNotifications = [];
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
        username: data['username']?.toString() ?? data['displayName']?.toString() ?? data['nickname']?.toString() ?? '',
        profileImageUrl: migrateAssetPath((data['profileImageUrl'] ?? data['photoURL'] ?? '').toString()),
        followedCategories: followedCategories,
        watchKeywords: watchKeywords,
        following: following,
        followersWithNotifications: followersWithNotifications,
        nickname: data['nickname']?.toString(),
        points: parseInt(data['points']),
        dealCount: parseInt(data['dealCount']),
        totalLikes: parseInt(data['totalLikes']),
        badges: badges,
        pinnedBadge: data['pinnedBadge']?.toString(),
        isBot: data['isBot'] == true,
      );
    } catch (e, stackTrace) {
      _log('❌ AppUser.fromFirestore hatası: $e');
      _log('Stack trace: $stackTrace');
      _log('Document ID: ${doc.id}');
      _log('Document data: ${doc.data()}');
      
      // Hata durumunda minimum bilgilerle kullanıcı oluştur
      final data = doc.data();
      final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};
      
      return AppUser(
        uid: doc.id,
        username: dataMap['username']?.toString() ?? dataMap['displayName']?.toString() ?? 'Kullanıcı',
        profileImageUrl: migrateAssetPath((dataMap['profileImageUrl'] ?? dataMap['photoURL'] ?? '').toString()),
        followedCategories: [],
        watchKeywords: [],
        following: [],
        followersWithNotifications: [],
        nickname: dataMap['nickname']?.toString(),
        points: 0,
        dealCount: 0,
        totalLikes: 0,
        badges: [],
        pinnedBadge: null,
        isBot: dataMap['isBot'] == true,
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
      'watchKeywords': watchKeywords,
      'following': following,
      'followersWithNotifications': followersWithNotifications,
      if (nickname != null) 'nickname': nickname,
      'points': points,
      'dealCount': dealCount,
      'totalLikes': totalLikes,
      'badges': badges,
      if (pinnedBadge != null) 'pinnedBadge': pinnedBadge,
      'isBot': isBot,
    };
  }
}
