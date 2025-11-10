import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String username;
  final String profileImageUrl;
  final List<String> followedCategories;

  AppUser({
    required this.uid,
    required this.username,
    required this.profileImageUrl,
    this.followedCategories = const [],
  });

  // Firestore'dan AppUser oluşturma
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      followedCategories: List<String>.from(data['followedCategories'] ?? []),
    );
  }

  // AppUser'i Firestore'a yazmak için Map'e dönüştürme
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'followedCategories': followedCategories,
    };
  }
}

