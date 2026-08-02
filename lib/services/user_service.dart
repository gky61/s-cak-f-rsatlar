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

  Future<void> addLastSharedDeal(String userId, {
    required String dealId,
    required String title,
    required double price,
    required String store,
    required String link,
  }) async {
    try {
      final userDocRef = _firestore.collection('users').doc(userId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDocRef);
        List<dynamic> list = [];
        if (snapshot.exists) {
          final data = snapshot.data();
          list = List.from(data?['sonPaylasilanFirsatlar'] ?? []);
        }
        
        // Mükerrer eklemeyi önle
        list.removeWhere((item) => item['firsatId'] == dealId);
        
        list.insert(0, {
          'firsatId': dealId,
          'baslik': title,
          'fiyat': price.toString(),
          'link': link,
          'magazaAdi': store,
          'paylasilmaTarihi': Timestamp.now(),
        });
        
        if (list.length > 5) {
          list = list.sublist(0, 5);
        }
        
        transaction.set(userDocRef, {
          'sonPaylasilanFirsatlar': list,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      _log('addLastSharedDeal hatası: $e');
    }
  }

  // Favori İşlemleri
  Future<bool> isFavorite(String userId, String dealId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).collection('favorites').doc(dealId).get();
      return doc.exists;
    } catch (e) { return false; }
  }

  Future<bool> addToFavorites(String userId, String dealId, {String? title, double? price, String? store, String? link}) async {
    try {
      String finalTitle = title ?? '';
      double finalPrice = price ?? 0.0;
      String finalStore = store ?? '';
      String finalLink = link ?? '';

      if (finalTitle.isEmpty || finalLink.isEmpty) {
        final doc = await _firestore.collection('deals').doc(dealId).get();
        if (doc.exists) {
          finalTitle = doc.data()?['title'] ?? '';
          finalPrice = (doc.data()?['price'] as num?)?.toDouble() ?? 0.0;
          finalStore = doc.data()?['store'] ?? '';
          finalLink = doc.data()?['link'] ?? doc.data()?['url'] ?? '';
        }
      }

      await _firestore.collection('users').doc(userId).collection('favorites').doc(dealId).set({
        'favoriId': dealId,
        'firsatId': dealId,
        'baslik': finalTitle,
        'fiyat': finalPrice.toString(),
        'link': finalLink,
        'magazaAdi': finalStore,
        'savedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
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
        .snapshots()
        .asyncMap((snapshot) async {
      final now = DateTime.now();
      final docs = snapshot.docs.toList();
      
      // Saf Kronoloji: Kullanıcının favoriye kaydettiği tarihe göre sırala (savedAt DESC)
      docs.sort((a, b) {
        final aTime = (a.data()['savedAt'] ?? a.data()['eklenmeTarihi']) as Timestamp?;
        final bTime = (b.data()['savedAt'] ?? b.data()['eklenmeTarihi']) as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      final deals = await Future.wait(docs.map((doc) async {
        final data = doc.data();
        final dealId = doc.id;
        final dealDoc = await _firestore.collection('deals').doc(dealId).get();
        
        if (dealDoc.exists) {
          // Canlı Durum Güncellemesi: Firestore'daki güncel stok/fırsat durumunu yansıt
          return Deal.fromFirestore(dealDoc);
        } else {
          // İlan silinmişse yedek süresi doldu verisi oluştur
          final baslik = data['baslik'] ?? data['title'] ?? 'Süresi Dolan Fırsat';
          final fiyatStr = data['fiyat']?.toString() ?? '0';
          final fiyat = double.tryParse(fiyatStr) ?? 0.0;
          final store = data['magazaAdi'] ?? data['store'] ?? 'Mağaza';
          final link = data['link'] ?? '';
          final addedAtTimestamp = (data['savedAt'] ?? data['eklenmeTarihi']) as Timestamp?;
          final addedAt = addedAtTimestamp?.toDate() ?? now;
          
          return Deal(
            id: dealId,
            title: baslik,
            description: 'Bu fırsatın süresi dolmuştur.',
            price: fiyat,
            store: store,
            category: 'tumu',
            link: link,
            imageUrl: '',
            hotVotes: 0,
            coldVotes: 0,
            commentCount: 0,
            postedBy: '',
            createdAt: addedAt,
            isEditorPick: false,
            isApproved: true,
            isExpired: true,
            isUserSubmitted: false,
          );
        }
      }));
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

      // Ayrıca yazar bildirim aboneliğini sil
      final sanitizedKey = followingId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
      final subId = '${followerId}_author_$sanitizedKey';
      await _firestore.collection('notificationSubscriptions').doc(subId).delete();
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
      final sanitizedKey = followingId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
      final subId = '${followerId}_author_$sanitizedKey';
      final doc = await _firestore.collection('notificationSubscriptions').doc(subId).get();
      return doc.exists && (doc.data()?['enabled'] ?? false);
    } catch (e) { return false; }
  }

  // EKLENDİ: Takip bildirim aç/kapa
  Future<void> toggleFollowNotification(String followerId, String followingId, bool enable) async {
    try {
      final sanitizedKey = followingId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
      final subId = '${followerId}_author_$sanitizedKey';
      if (enable) {
        await _firestore.collection('notificationSubscriptions').doc(subId).set({
          'uid': followerId,
          'type': 'author',
          'key': followingId,
          'displayValue': followingId,
          'normalizedValue': followingId.toLowerCase(),
          'includeDescendants': true,
          'enabled': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('notificationSubscriptions').doc(subId).delete();
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
