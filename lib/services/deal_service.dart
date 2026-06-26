import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/deal.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'content_moderation_service.dart';
import 'user_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class DealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Deals koleksiyonunu dinleme
  Stream<List<Deal>> getDealsStream() {
    return _firestore
        .collection('deals')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(days: 180));
      
      return snapshot.docs
          .map((doc) {
            try {
              return Deal.fromFirestore(doc);
            } catch (e) {
              _log('❌ Deal parse hatası (doc.id: ${doc.id}): $e');
              return null;
            }
          })
          .where((deal) {
            if (deal == null) return false;
            if (deal.isApproved != true) return false;
            if (deal.isExpired == true) return false;
            if (deal.createdAt.isBefore(cutoffTime)) return false;
            return true;
          })
          .cast<Deal>()
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  // Pagination ile deal'leri getir
  Future<List<Deal>> getDealsPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? category,
    String? subCategory,
  }) async {
    try {
      Query query = _firestore
          .collection('deals')
          .where('isApproved', isEqualTo: true);

      if (category != null && category != 'tumu') {
        query = query.where('category', isEqualTo: category);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(days: 180));
      
      return snapshot.docs
          .map((doc) => Deal.fromFirestore(doc))
          .where((deal) {
            if (deal.isExpired) return false;
            if (deal.createdAt.isBefore(cutoffTime)) return false;
            return true;
          })
          .toList();
    } catch (e) {
      _log('Pagination hatası: $e');
      return [];
    }
  }

  // Onay bekleyen deal'leri dinleme
  Stream<List<Deal>> getPendingDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: false)
        .where('isUserSubmitted', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs
          .map((doc) {
            try { return Deal.fromFirestore(doc); } catch (e) { return null; }
          })
          .where((deal) => deal != null)
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Kullanıcıların paylaştığı onay bekleyen deal'leri dinleme
  Stream<List<Deal>> getUserSubmittedPendingDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .where('isUserSubmitted', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs
          .map((doc) {
            try { return Deal.fromFirestore(doc); } catch (e) { return null; }
          })
          .where((deal) => deal != null && deal!.isApproved != true)
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Yayınlanmış (onaylanmış) deal'leri dinleme
  Stream<List<Deal>> getApprovedDealsStream() {
    return _firestore
        .collection('deals')
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs
          .map((doc) {
            try { return Deal.fromFirestore(doc); } catch (e) { return null; }
          })
          .where((deal) => deal != null && deal!.isApproved == true && deal.isExpired != true)
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Süresi bitmiş deal'leri getir
  Stream<List<Deal>> getExpiredDealsStream() {
    return _firestore
        .collection('deals')
        .where('isExpired', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  Future<Deal?> getDeal(String dealId) async {
    try {
      final doc = await _firestore.collection('deals').doc(dealId).get();
      if (doc.exists) {
        return Deal.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _log('Deal getirme hatası: $e');
      return null;
    }
  }

  // Yeni deal oluşturma
  Future<String?> createDeal({
    required String title,
    required String description,
    required double price,
    required String store,
    required String category,
    String? subCategory,
    required String imageUrl,
    required String url,
    required String userId,
  }) async {
    try {
      final isAdmin = await _authService.isAdmin();
      
      if (!isAdmin) {
        final isSharingEnabled = await isDealSharingEnabled();
        if (!isSharingEnabled) {
          throw Exception('Şu anda yeni fırsat paylaşımı yapılamıyor.');
        }
        
        final dealBanDoc = await _firestore.collection('dealBannedUsers').doc(userId).get();
        if (dealBanDoc.exists) {
          throw Exception('Paylaşım yapma yetkiniz kaldırılmış.');
        }
      }
      
      final moderationResult = ContentModerationService.moderateContent(
        title: title,
        description: description,
      );
      
      if (!moderationResult.isSafe) {
        throw Exception(moderationResult.reason ?? 'İçerik uygunsuz');
      }
      
      final deal = Deal(
        id: '',
        title: title,
        description: description,
        price: price,
        store: store,
        category: category,
        subCategory: subCategory,
        link: url,
        imageUrl: imageUrl,
        postedBy: userId,
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        createdAt: DateTime.now(),
        isEditorPick: false,
        isApproved: false,
        isUserSubmitted: true,
      );
      
      final docRef = await _firestore.collection('deals').add(deal.toFirestore());
      
      // Kullanıcı puanını artır (UserService kullanımı)
      final userService = UserService();
      await userService.incrementUserPoints(userId, points: 5, dealCount: 1);
      
      // Anahtar kelime kontrolü
      Future.delayed(Duration.zero, () async {
        try {
          final notificationService = NotificationService();
          await notificationService.checkKeywordsAndNotify(docRef.id, title, description);
        } catch (e) {
          _log('❌ Anahtar kelime kontrolü hatası: $e');
        }
      });
      
      return docRef.id;
    } catch (e) {
      _log('Deal oluşturma hatası: $e');
      rethrow;
    }
  }

  Future<bool> updateDeal(String dealId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('deals').doc(dealId).update(updates);
      return true;
    } catch (e) {
      _log('Deal güncelleme hatası: $e');
      return false;
    }
  }

  Future<bool> deleteDeal(String dealId) async {
    try {
      await _firestore.collection('deals').doc(dealId).delete();
      return true;
    } catch (e) {
      _log('Deal silme hatası: $e');
      return false;
    }
  }

  // Vote İşlemleri
  Future<bool> addHotVote(String dealId, String userId) async {
    try {
      final batch = _firestore.batch();
      final voteRef = _firestore.collection('deals').doc(dealId).collection('votes').doc(userId);
      
      final voteDoc = await voteRef.get();
      if (voteDoc.exists) {
        final currentType = voteDoc.data()?['type'] as String?;
        if (currentType == 'cold') {
          batch.update(_firestore.collection('deals').doc(dealId), {'coldVotes': FieldValue.increment(-1)});
        } else if (currentType == 'hot') {
          return true;
        }
      }
      
      batch.set(voteRef, {'type': 'hot'}, SetOptions(merge: true));
      batch.update(_firestore.collection('deals').doc(dealId), {'hotVotes': FieldValue.increment(1)});
      await batch.commit();
      
      // Deal sahibine puan ver
      final deal = await getDeal(dealId);
      if (deal != null && !voteDoc.exists) {
        final userService = UserService();
        await userService.incrementUserPoints(deal.postedBy, points: 2, totalLikes: 1);
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addColdVote(String dealId, String userId) async {
    try {
      final batch = _firestore.batch();
      final voteRef = _firestore.collection('deals').doc(dealId).collection('votes').doc(userId);
      
      final voteDoc = await voteRef.get();
      if (voteDoc.exists) {
        final currentType = voteDoc.data()?['type'] as String?;
        if (currentType == 'hot') {
          batch.update(_firestore.collection('deals').doc(dealId), {'hotVotes': FieldValue.increment(-1)});
        } else if (currentType == 'cold') {
          return true;
        }
      }
      
      batch.set(voteRef, {'type': 'cold'}, SetOptions(merge: true));
      batch.update(_firestore.collection('deals').doc(dealId), {'coldVotes': FieldValue.increment(1)});
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addExpiredVote(String dealId, String userId) async {
    try {
      final batch = _firestore.batch();
      final voteRef = _firestore.collection('deals').doc(dealId).collection('votes').doc(userId);
      
      final voteDoc = await voteRef.get();
      if (voteDoc.exists) {
        if (voteDoc.data()?['type'] == 'expired') return true;
        // Önceki oyları temizle mantığı buraya eklenebilir
      }
      
      batch.set(voteRef, {'type': 'expired'}, SetOptions(merge: true));
      batch.update(_firestore.collection('deals').doc(dealId), {'expiredVotes': FieldValue.increment(1)});
      await batch.commit();
      
      // Otomatik expire kontrolü
      final dealDoc = await _firestore.collection('deals').doc(dealId).get();
      if (dealDoc.exists) {
        if ((dealDoc.data()?['expiredVotes'] ?? 0) >= 15) {
          await updateDeal(dealId, {'isExpired': true});
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getUserVote(String dealId, String userId) async {
    try {
      final doc = await _firestore.collection('deals').doc(dealId).collection('votes').doc(userId).get();
      return doc.data()?['type'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Fırsatı bitir/başlat
  Future<bool> markDealAsExpired(String dealId) async => updateDeal(dealId, {'isExpired': true});
  Future<bool> unexpireDeal(String dealId) async => updateDeal(dealId, {'isExpired': false});

  // Deal paylaşım ayarları
  Future<bool> isDealSharingEnabled() async {
    try {
      final doc = await _firestore.collection('settings').doc('app').get();
      return doc.data()?['dealSharingEnabled'] ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<bool> setDealSharingEnabled(bool enabled) async {
    try {
      await _firestore.collection('settings').doc('app').set({
        'dealSharingEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }
}
