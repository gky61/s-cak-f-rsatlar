import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/user.dart';
import '../models/deal.dart';
import '../utils/badge_helper.dart';

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

  /// Kullanıcının başarımlarını otomatik denetler ve yeni rozetleri Firestore'a atomik olarak kaydeder
  Future<List<String>> checkAndAwardBadges(String userId, {AppUser? user}) async {
    try {
      AppUser? currentUser = user;
      if (currentUser == null) {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (!doc.exists) return [];
        currentUser = AppUser.fromFirestore(doc);
      }

      final eligibleBadges = BadgeHelper.evaluateEligibleBadges(currentUser);
      final newBadges = eligibleBadges.where((id) => !currentUser!.badges.contains(id)).toList();

      if (newBadges.isNotEmpty) {
        await _firestore.collection('users').doc(userId).set({
          'badges': FieldValue.arrayUnion(newBadges),
        }, SetOptions(merge: true));

        _log('🎉 Kullanıcıya yeni rozetler tanımlandı: $newBadges');
      }

      return newBadges;
    } catch (e) {
      _log('Rozet kontrol ve ödüllendirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının profilde ve yorumlarda öne çıkacak vitrin rozetini günceller
  Future<bool> setPinnedBadge(String userId, String? badgeId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'pinnedBadge': badgeId,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      _log('Vitrin rozeti güncelleme hatası: $e');
      return false;
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

  Future<bool> addToFavorites(String userId, String dealId, {String? title, double? price, String? store, String? link, String? imageUrl}) async {
    try {
      String finalTitle = title?.trim() ?? '';
      double finalPrice = price ?? 0.0;
      String finalStore = store?.trim() ?? '';
      String finalLink = link?.trim() ?? '';
      String finalImageUrl = imageUrl?.trim() ?? '';

      // Eğer parametrelerden herhangi biri eksikse, ana deals dokümanından çekip eksiksiz snapshot oluştur
      if (finalTitle.isEmpty || finalLink.isEmpty || finalImageUrl.isEmpty || finalStore.isEmpty || finalPrice == 0.0) {
        final doc = await _firestore.collection('deals').doc(dealId).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (finalTitle.isEmpty) finalTitle = (data['title'] ?? data['baslik'] ?? '').toString();
            if (finalPrice == 0.0) finalPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
            if (finalStore.isEmpty) finalStore = (data['store'] ?? data['magazaAdi'] ?? '').toString();
            if (finalLink.isEmpty) finalLink = (data['link'] ?? data['url'] ?? '').toString();
            if (finalImageUrl.isEmpty) finalImageUrl = (data['imageUrl'] ?? data['image_url'] ?? data['gorselUrl'] ?? '').toString();
          }
        }
      }

      await _firestore.collection('users').doc(userId).collection('favorites').doc(dealId).set({
        'favoriId': dealId,
        'firsatId': dealId,
        'baslik': finalTitle,
        'fiyat': finalPrice.toString(),
        'link': finalLink,
        'magazaAdi': finalStore,
        'imageUrl': finalImageUrl,
        'savedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
        final savedImageUrl = (data['imageUrl'] ?? data['gorselUrl'] ?? data['image_url'])?.toString() ?? '';
        final addedAtTimestamp = (data['savedAt'] ?? data['eklenmeTarihi']) as Timestamp?;
        final addedAt = addedAtTimestamp?.toDate() ?? now;
        
        if (dealDoc.exists) {
          final deal = Deal.fromFirestore(dealDoc);
          // Favoriler alt dokümanında imageUrl eksikse arka planda doldur (snapshot tamamlama)
          if (savedImageUrl.isEmpty && deal.imageUrl.isNotEmpty) {
            _firestore.collection('users').doc(userId).collection('favorites').doc(dealId).set({
              'imageUrl': deal.imageUrl,
            }, SetOptions(merge: true)).catchError((_) {});
          }
          return deal;
        } else {
          // İlan 30 günden eski ve veritabanından kalıcı silinmişse + görseli de yoksa yetim kaydı arka planda temizle
          if (savedImageUrl.isEmpty && now.difference(addedAt).inDays >= 30) {
            _firestore.collection('users').doc(userId).collection('favorites').doc(dealId).delete().catchError((_) {});
          }

          // İlan silinmişse yedek süresi doldu verisi oluştur
          final baslik = data['baslik'] ?? data['title'] ?? 'Süresi Dolan Fırsat';
          final fiyatStr = data['fiyat']?.toString() ?? '0';
          final fiyat = double.tryParse(fiyatStr) ?? 0.0;
          final store = data['magazaAdi'] ?? data['store'] ?? 'Mağaza';
          final link = data['link'] ?? '';
          
          return Deal(
            id: dealId,
            title: baslik,
            description: 'Bu fırsatın süresi dolmuştur.',
            price: fiyat,
            store: store,
            category: 'tumu',
            link: link,
            imageUrl: savedImageUrl,
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
      batch.set(_firestore.collection('users').doc(followerId), {
        'following': FieldValue.arrayUnion([followingId]),
      }, SetOptions(merge: true));

      if (followingId != 'botkolik' && !followingId.startsWith('telegram_')) {
        batch.set(_firestore.collection('users').doc(followingId), {
          'followersWithNotifications': FieldValue.arrayUnion([followerId]),
        }, SetOptions(merge: true));
      }
      await batch.commit();

      // Takip edilen yazar için anlık bildirim aboneliğini otomatik oluştur
      final sanitizedKey = followingId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
      final subId = '${followerId}_author_$sanitizedKey';
      await _firestore.collection('notificationSubscriptions').doc(subId).set({
        'uid': followerId,
        'type': 'author',
        'key': followingId,
        'displayValue': followingId == 'botkolik' ? 'Botkolik' : followingId,
        'normalizedValue': followingId.toLowerCase(),
        'includeDescendants': true,
        'enabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _log('Takip hatası: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(followerId), {
        'following': FieldValue.arrayRemove([followingId]),
      }, SetOptions(merge: true));

      if (followingId != 'botkolik' && !followingId.startsWith('telegram_')) {
        batch.set(_firestore.collection('users').doc(followingId), {
          'followersWithNotifications': FieldValue.arrayRemove([followerId]),
        }, SetOptions(merge: true));
      }
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
