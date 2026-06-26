import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/user.dart';
import '../models/deal.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> incrementUserPoints(String userId, {int points = 0, int dealCount = 0, int totalLikes = 0}) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'points': FieldValue.increment(points),
        'dealCount': FieldValue.increment(dealCount),
        'totalLikes': FieldValue.increment(totalLikes),
      }, SetOptions(merge: true));
    } catch (e) {
      _log('Puan güncelleme hatası: $e');
    }
  }

  // Favori İşlemleri
  Future<bool> isFavorite(String userId, String dealId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).collection('favorites').doc(dealId).get();
      return doc.exists;
    } catch (e) { return false; }
  }

  Future<bool> addToFavorites(String userId, String dealId) async {
    try {
      await _firestore.collection('users').doc(userId).collection('favorites').doc(dealId).set({
        'addedAt': FieldValue.serverTimestamp()
      });
      return true;
    } catch (e) { return false; }
  }

  Future<bool> removeFromFavorites(String userId, String dealId) async {
    try {
      await _firestore.collection('users').doc(userId).collection('favorites').doc(dealId).delete();
      return true;
    } catch (e) { return false; }
  }

  Stream<List<Deal>> getFavoriteDeals(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Deal> deals = [];
      for (var doc in snapshot.docs) {
        final dealDoc = await _firestore.collection('deals').doc(doc.id).get();
        if (dealDoc.exists) deals.add(Deal.fromFirestore(dealDoc));
      }
      return deals;
    });
  }

  // Takip İşlemleri
  Future<void> followUser(String followerId, String followingId) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(followerId), {
        'following': FieldValue.arrayUnion([followingId]),
      });
      batch.update(_firestore.collection('users').doc(followingId), {
        'followersWithNotifications': FieldValue.arrayUnion([followerId]),
      });
      await batch.commit();
    } catch (e) {
      _log('Takip hatası: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(followerId), {
        'following': FieldValue.arrayRemove([followingId]),
      });
      batch.update(_firestore.collection('users').doc(followingId), {
        'followersWithNotifications': FieldValue.arrayRemove([followerId]),
      });
      await batch.commit();
    } catch (e) {
      _log('Takipten çıkma hatası: $e');
      rethrow;
    }
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final doc = await _firestore.collection('users').doc(followerId).get();
      final following = List<String>.from(doc.data()?['following'] ?? []);
      return following.contains(followingId);
    } catch (e) { return false; }
  }

  // EKLENDİ: Takip bildirim kontrolü
  Future<bool> isFollowNotificationEnabled(String followerId, String followingId) async {
    try {
      final doc = await _firestore.collection('users').doc(followingId).get();
      if (!doc.exists) return false;
      final followersWithNotifications = List<String>.from(doc.data()?['followersWithNotifications'] ?? []);
      return followersWithNotifications.contains(followerId);
    } catch (e) { return false; }
  }

  // EKLENDİ: Takip bildirim aç/kapa
  Future<void> toggleFollowNotification(String followerId, String followingId, bool enable) async {
    try {
      final followingRef = _firestore.collection('users').doc(followingId);
      if (enable) {
        await followingRef.update({'followersWithNotifications': FieldValue.arrayUnion([followerId])});
      } else {
        await followingRef.update({'followersWithNotifications': FieldValue.arrayRemove([followerId])});
      }
    } catch (e) { rethrow; }
  }

  Stream<List<AppUser>> getFollowingUsersStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists) return [];
      final followingIds = List<String>.from(userDoc.data()?['following'] ?? []);
      if (followingIds.isEmpty) return [];
      
      final snapshots = await Future.wait(followingIds.map((id) => _firestore.collection('users').doc(id).get()));
      return snapshots
          .where((s) => s.exists)
          .map((s) => AppUser.fromFirestore(s))
          .toList();
    });
  }

  // Anahtar Kelime Takibi
  Future<List<String>> getUserWatchKeywords(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return List<String>.from(doc.data()?['watchKeywords'] ?? []);
    } catch (e) { return []; }
  }

  Future<void> addWatchKeyword(String userId, String keyword) async {
    await _firestore.collection('users').doc(userId).update({
      'watchKeywords': FieldValue.arrayUnion([keyword]),
    });
  }

  Future<void> removeWatchKeyword(String userId, String keyword) async {
    await _firestore.collection('users').doc(userId).update({
      'watchKeywords': FieldValue.arrayRemove([keyword]),
    });
  }

  Future<bool> isUserBlocked(String userId) async {
    final doc = await _firestore.collection('blockedUsers').doc(userId).get();
    return doc.exists;
  }

  Future<bool> blockUser(String userId) async {
    try {
      await _firestore.collection('blockedUsers').doc(userId).set({'blockedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (e) { return false; }
  }
}
