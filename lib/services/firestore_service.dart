import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deal.dart';
import '../models/comment.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Deals koleksiyonunu createdAt'e göre sıralayarak dinleme
  // SADECE ONAYLANMIŞ fırsatları getirir (biten fırsatlar da gösterilir, kırmızı çizgili)
  Stream<List<Deal>> getDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
      // Client-side'da tarihe göre sırala (index gerektirmez)
      // Önce bitmeyenler, sonra bitenler
      deals.sort((a, b) {
        // Önce bitmeyenler
        if (!a.isExpired && b.isExpired) return -1;
        if (a.isExpired && !b.isExpired) return 1;
        // Aynı durumdaysa tarihe göre sırala
        return b.createdAt.compareTo(a.createdAt);
      });
      return deals;
    });
  }

  // Tüm deal'leri getir (admin kullanıcılar için)
  Stream<List<Deal>> getAllDealsStream() {
    return _firestore
        .collection('deals')
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
      // Client-side'da tarihe göre sırala (index gerektirmez)
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Süresi bitmiş (isExpired: true) tüm deal'leri getir (admin için)
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

  // Onay bekleyen deal'leri dinleme
  Stream<List<Deal>> getPendingDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
      // Client-side'da tarihe göre sırala (index gerektirmez)
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Tek bir deal getirme
  Future<Deal?> getDeal(String dealId) async {
    try {
      final doc = await _firestore.collection('deals').doc(dealId).get();
      if (doc.exists) {
        return Deal.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Deal getirme hatası: $e');
      return null;
    }
  }

  // Yeni deal ekleme
  Future<String?> addDeal(Deal deal) async {
    try {
      final docRef = await _firestore.collection('deals').add(deal.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Deal ekleme hatası: $e');
      return null;
    }
  }

  // Yeni deal oluşturma (parametrelerle)
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
      final deal = Deal(
        id: '', // Firestore otomatik ID oluşturacak
        title: title,
        price: price,
        store: store,
        category: category,
        subCategory: subCategory,
        link: url, // Deal modelinde 'link' kullanılıyor
        imageUrl: imageUrl,
        postedBy: userId, // Deal modelinde 'postedBy' kullanılıyor
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        createdAt: DateTime.now(),
        isEditorPick: false,
      );
      
      final docRef = await _firestore.collection('deals').add(deal.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Deal oluşturma hatası: $e');
      return null;
    }
  }

  // Deal güncelleme
  Future<bool> updateDeal(String dealId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('deals').doc(dealId).update(updates);
      return true;
    } catch (e) {
      print('Deal güncelleme hatası: $e');
      return false;
    }
  }

  // Kullanıcının oyunu getir
  Future<String?> getUserVote(String dealId, String userId) async {
    try {
      final voteDoc = await _firestore
          .collection('deals')
          .doc(dealId)
          .collection('votes')
          .doc(userId)
          .get();
      
      if (voteDoc.exists) {
        return voteDoc.data()?['type'] as String?; // 'hot' veya 'cold'
      }
      return null;
    } catch (e) {
      print('Kullanıcı oyu getirme hatası: $e');
      return null;
    }
  }

  // Hot vote ekleme
  Future<bool> addHotVote(String dealId, String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Önceki oyu kontrol et ve güncelle
      final voteRef = _firestore
          .collection('deals')
          .doc(dealId)
          .collection('votes')
          .doc(userId);
      
      final voteDoc = await voteRef.get();
      if (voteDoc.exists) {
        final currentType = voteDoc.data()?['type'] as String?;
        if (currentType == 'cold') {
          // Cold vote'u azalt
          batch.update(_firestore.collection('deals').doc(dealId), {
            'coldVotes': FieldValue.increment(-1),
          });
        } else if (currentType == 'hot') {
          // Zaten hot vote vermiş
          return true;
        }
      }
      
      // Hot vote ekle/güncelle
      batch.set(voteRef, {'type': 'hot'}, SetOptions(merge: true));
      batch.update(_firestore.collection('deals').doc(dealId), {
        'hotVotes': FieldValue.increment(1),
      });
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Hot vote ekleme hatası: $e');
      return false;
    }
  }

  // Cold vote ekleme
  Future<bool> addColdVote(String dealId, String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Önceki oyu kontrol et ve güncelle
      final voteRef = _firestore
          .collection('deals')
          .doc(dealId)
          .collection('votes')
          .doc(userId);
      
      final voteDoc = await voteRef.get();
      if (voteDoc.exists) {
        final currentType = voteDoc.data()?['type'] as String?;
        if (currentType == 'hot') {
          // Hot vote'u azalt
          batch.update(_firestore.collection('deals').doc(dealId), {
            'hotVotes': FieldValue.increment(-1),
          });
        } else if (currentType == 'cold') {
          // Zaten cold vote vermiş
          return true;
        }
      }
      
      // Cold vote ekle/güncelle
      batch.set(voteRef, {'type': 'cold'}, SetOptions(merge: true));
      batch.update(_firestore.collection('deals').doc(dealId), {
        'coldVotes': FieldValue.increment(1),
      });
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Cold vote ekleme hatası: $e');
      return false;
    }
  }

  // Favori kontrolü
  Future<bool> isFavorite(String userId, String dealId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(dealId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Favori kontrolü hatası: $e');
      return false;
    }
  }

  // Favorilere ekle
  Future<bool> addToFavorites(String userId, String dealId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(dealId)
          .set({'addedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      print('Favori ekleme hatası: $e');
      return false;
    }
  }

  // Favorilerden çıkar
  Future<bool> removeFromFavorites(String userId, String dealId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(dealId)
          .delete();
      return true;
    } catch (e) {
      print('Favori çıkarma hatası: $e');
      return false;
    }
  }

  // Deal'i bitmiş olarak işaretle
  Future<bool> markDealAsExpired(String dealId) async {
    try {
      await _firestore.collection('deals').doc(dealId).update({
        'isExpired': true,
      });
      return true;
    } catch (e) {
      print('Deal bitirme hatası: $e');
      return false;
    }
  }

  // Kullanıcı engellenmiş mi kontrolü
  Future<bool> isUserBlocked(String userId) async {
    try {
      final doc = await _firestore.collection('blockedUsers').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print('Kullanıcı engel kontrolü hatası: $e');
      return false;
    }
  }

  // Yorum ekleme
  Future<bool> addComment({
    required String dealId,
    required String userId,
    required String userName,
    required String userEmail,
    required String text,
    String? parentCommentId,
    String? replyToUserName,
  }) async {
    try {
      final batch = _firestore.batch();
      
      // Yorum ekle
      final commentRef = _firestore
          .collection('deals')
          .doc(dealId)
          .collection('comments')
          .doc();
      
      final comment = Comment(
        id: commentRef.id,
        dealId: dealId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        text: text,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
        replyToUserName: replyToUserName,
      );
      
      batch.set(commentRef, comment.toFirestore());
      
      // Comment count'u artır
      batch.update(_firestore.collection('deals').doc(dealId), {
        'commentCount': FieldValue.increment(1),
      });
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Yorum ekleme hatası: $e');
      return false;
    }
  }

  // Yorumları dinleme
  Stream<List<Comment>> getCommentsStream(String dealId) {
    return _firestore
        .collection('deals')
        .doc(dealId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
    });
  }

  // Yorum silme
  Future<bool> deleteComment(String commentId, String dealId) async {
    try {
      final batch = _firestore.batch();
      
      // Yorumu sil
      batch.delete(
        _firestore
            .collection('deals')
            .doc(dealId)
            .collection('comments')
            .doc(commentId),
      );
      
      // Comment count'u azalt
      batch.update(_firestore.collection('deals').doc(dealId), {
        'commentCount': FieldValue.increment(-1),
      });
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Yorum silme hatası: $e');
      return false;
    }
  }

  // Kullanıcı engelleme
  Future<bool> blockUser(String userId) async {
    try {
      await _firestore.collection('blockedUsers').doc(userId).set({
        'blockedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Kullanıcı engelleme hatası: $e');
      return false;
    }
  }

  // Fırsatı tekrar aktif etme (süresi bitmişlikten çıkarma)
  Future<bool> unexpireDeal(String dealId) async {
    try {
      await _firestore.collection('deals').doc(dealId).update({
        'isExpired': false,
      });
      return true;
    } catch (e) {
      print('Deal aktif etme hatası: $e');
      return false;
    }
  }

  // Expired deal'leri kontrol et ve sil (gün bittiğinde çağrılacak)
  // Client-side'da filtreleme yaparak index gerektirmez
  Future<void> cleanupExpiredDeals() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      
      // isExpired: true olan deal'leri bul (index gerektirmemesi için orderBy yok)
      final expiredDeals = await _firestore
          .collection('deals')
          .where('isExpired', isEqualTo: true)
          .get();
      
      final batch = _firestore.batch();
      int deletedCount = 0;
      
      for (var doc in expiredDeals.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        // Eğer createdAt dün öncesinden ise sil
        if (createdAt != null && createdAt.isBefore(yesterday)) {
          batch.delete(doc.reference);
          deletedCount++;
          
          // Batch limiti 500
          if (deletedCount % 500 == 0) {
            await batch.commit();
          }
        }
      }
      
      // Kalan işlemleri commit et
      if (deletedCount % 500 != 0 && deletedCount > 0) {
        await batch.commit();
      }
      
      if (deletedCount > 0) {
        print('✅ $deletedCount expired deal temizlendi');
      }
    } catch (e) {
      print('❌ Expired deal temizleme hatası: $e');
    }
  }
}

