import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import '../models/deal.dart';
import '../models/comment.dart';
import '../models/message.dart';
import 'notification_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Deals koleksiyonunu createdAt'e göre sıralayarak dinleme
  // SADECE ONAYLANMIŞ ve BİTMEMİŞ fırsatları getirir (isExpired: false)
  // Ayrıca 24 saatten eski deal'ları da filtreler
  Stream<List<Deal>> getDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24));
      
      // Client-side'da filtrele: sadece bitmemiş ve 24 saatten yeni deal'ları göster
      final deals = snapshot.docs
          .map((doc) => Deal.fromFirestore(doc))
          .where((deal) {
            // isExpired: false olanları filtrele
            if (deal.isExpired) return false;
            // 24 saatten eski deal'ları filtrele
            if (deal.createdAt.isBefore(cutoffTime)) return false;
            return true;
          })
          .toList();
      // Tarihe göre sırala (yeni önce)
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Pagination ile deal'leri getir (infinite scroll için)
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

      // Kategori filtresi varsa ekle
      if (category != null && category != 'tumu') {
        // Firestore'da category string olarak saklanıyor, Category.getNameById kullan
        final categoryName = category; // Burada category zaten name olarak gelmeli
        query = query.where('category', isEqualTo: categoryName);
      }

      // Sıralama ve limit
      query = query.orderBy('createdAt', descending: true).limit(limit);

      // Son dokümandan devam et (pagination)
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24));
      
      // Client-side'da filtrele: sadece bitmemiş ve 24 saatten yeni deal'ları göster
      final deals = snapshot.docs
          .map((doc) => Deal.fromFirestore(doc))
          .where((deal) {
            // isExpired: false olanları filtrele
            if (deal.isExpired) return false;
            // 24 saatten eski deal'ları filtrele
            if (deal.createdAt.isBefore(cutoffTime)) return false;
            return true;
          })
          .toList();
      
      // Zaten Firestore'da tarihe göre sıralı
      return deals;
    } catch (e) {
      _log('Pagination hatası: $e');
      return [];
    }
  }

  // İlk sayfa deal'lerini getir (refresh için)
  Future<List<Deal>> getInitialDeals({int limit = 20}) async {
    return getDealsPaginated(limit: limit);
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

  // Onay bekleyen deal'leri dinleme (sadece bot fırsatları)
  // isUserSubmitted alanı olmayan veya false olan fırsatlar bot fırsatıdır
  Stream<List<Deal>> getPendingDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      // Client-side'da filtrele: isUserSubmitted false veya yok olanlar (bot fırsatları)
      final deals = snapshot.docs
          .map((doc) => Deal.fromFirestore(doc))
          .where((deal) => !deal.isUserSubmitted) // isUserSubmitted false veya yok
          .toList();
      // Client-side'da tarihe göre sırala (index gerektirmez)
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
      final deals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
      // Client-side'da tarihe göre sırala (index gerektirmez)
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Yayınlanmış (onaylanmış) deal'leri dinleme (admin için)
  Stream<List<Deal>> getApprovedDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
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
      _log('Deal getirme hatası: $e');
      return null;
    }
  }

  // Yeni deal ekleme
  Future<String?> addDeal(Deal deal) async {
    try {
      final docRef = await _firestore.collection('deals').add(deal.toFirestore());
      return docRef.id;
    } catch (e) {
      _log('Deal ekleme hatası: $e');
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
      _log('📝 createDeal çağrıldı:');
      _log('   Başlık: $title');
      _log('   Açıklama: ${description.isEmpty ? "BOŞ" : description}');
      _log('   Kategori: $category');
      _log('   Alt Kategori: ${subCategory ?? "YOK"}');
      _log('   Fiyat: $price');
      _log('   Mağaza: $store');
      
      final deal = Deal(
        id: '', // Firestore otomatik ID oluşturacak
        title: title,
        description: description, // Açıklama eklendi
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
        isUserSubmitted: true, // Kullanıcı tarafından paylaşıldı
      );
      
      final dealData = deal.toFirestore();
      _log('📦 Firestore\'a kaydedilecek veri:');
      _log('   category: ${dealData['category']}');
      _log('   subCategory: ${dealData['subCategory'] ?? "YOK"}');
      _log('   description: ${dealData['description'] ?? "YOK"}');
      
      final docRef = await _firestore.collection('deals').add(dealData);
      
      // Kullanıcının puanını artır (her paylaşım 5 puan)
      await _incrementUserPoints(userId, points: 5, dealCount: 1);
      
      // Anahtar kelime kontrolü yap ve bildirim gönder (async olarak arka planda)
      _checkKeywordsForDeal(docRef.id, title, description);
      
      // NOT: Takip bildirimi sadece admin deal'i onayladıktan sonra gönderilecek
      // Burada gönderilmiyor çünkü deal henüz onaylanmamış
      
      return docRef.id;
    } catch (e) {
      _log('Deal oluşturma hatası: $e');
      return null;
    }
  }

  // Anahtar kelime kontrolü (arka planda çalışır)
  void _checkKeywordsForDeal(String dealId, String title, String description) {
    Future.delayed(Duration.zero, () async {
      try {
        final notificationService = NotificationService();
        await notificationService.checkKeywordsAndNotify(dealId, title, description);
      } catch (e) {
        _log('❌ Anahtar kelime kontrolü hatası: $e');
      }
    });
  }

  // Kullanıcı puanını artır
  Future<void> _incrementUserPoints(String userId, {int points = 0, int dealCount = 0, int totalLikes = 0}) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.set({
        'points': FieldValue.increment(points),
        'dealCount': FieldValue.increment(dealCount),
        'totalLikes': FieldValue.increment(totalLikes),
      }, SetOptions(merge: true));
    } catch (e) {
      _log('Kullanıcı puanı güncelleme hatası: $e');
    }
  }

  // Deal güncelleme
  Future<bool> updateDeal(String dealId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('deals').doc(dealId).update(updates);
      return true;
    } catch (e) {
      _log('Deal güncelleme hatası: $e');
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
        return voteDoc.data()?['type'] as String?; // 'hot', 'cold' veya 'expired'
      }
      return null;
    } catch (e) {
      _log('Kullanıcı oyu getirme hatası: $e');
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
      
      // Deal sahibinin puanını artır (her hot vote 2 puan)
      final deal = await getDeal(dealId);
      if (deal != null && !voteDoc.exists) {
        // Sadece yeni beğeni ise puan ver (daha önce beğenmişse puan verme)
        await _incrementUserPoints(deal.postedBy, points: 2, totalLikes: 1);
      }
      
      return true;
    } catch (e) {
      _log('Hot vote ekleme hatası: $e');
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
      _log('Cold vote ekleme hatası: $e');
      return false;
    }
  }

  // Expired vote ekleme (fırsat bitti bildirimi)
  Future<bool> addExpiredVote(String dealId, String userId) async {
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
        if (currentType == 'expired') {
          // Zaten expired vote vermiş
          return true;
        }
        // Önceki oyu temizle (hot veya cold olsun)
        if (currentType == 'hot') {
          batch.update(_firestore.collection('deals').doc(dealId), {
            'hotVotes': FieldValue.increment(-1),
          });
        } else if (currentType == 'cold') {
          batch.update(_firestore.collection('deals').doc(dealId), {
            'coldVotes': FieldValue.increment(-1),
          });
        }
      }
      
      // Expired vote ekle/güncelle
      batch.set(voteRef, {'type': 'expired'}, SetOptions(merge: true));
      batch.update(_firestore.collection('deals').doc(dealId), {
        'expiredVotes': FieldValue.increment(1),
      });
      
      await batch.commit();
      
      // ExpiredVotes sayısını kontrol et - 15'e ulaştıysa otomatik olarak isExpired: true yap
      final dealDoc = await _firestore.collection('deals').doc(dealId).get();
      if (dealDoc.exists) {
        final dealData = dealDoc.data();
        final currentExpiredVotes = (dealData?['expiredVotes'] ?? 0) as int;
        if (currentExpiredVotes >= 15) {
          await _firestore.collection('deals').doc(dealId).update({
            'isExpired': true,
          });
        }
      }
      
      return true;
    } catch (e) {
      _log('Expired vote ekleme hatası: $e');
      return false;
    }
  }

  // Hot vote geri alma (beğeniyi geri alma)
  Future<bool> removeHotVote(String dealId, String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Kullanıcının vote'unu kontrol et
      final voteRef = _firestore
          .collection('deals')
          .doc(dealId)
          .collection('votes')
          .doc(userId);
      
      final voteDoc = await voteRef.get();
      if (!voteDoc.exists) {
        // Vote yoksa işlem yapma
        return true;
      }
      
      final currentType = voteDoc.data()?['type'] as String?;
      if (currentType != 'hot') {
        // Hot vote değilse işlem yapma
        return true;
      }
      
      // Hot vote'u sil ve sayıyı azalt
      batch.delete(voteRef);
      batch.update(_firestore.collection('deals').doc(dealId), {
        'hotVotes': FieldValue.increment(-1),
      });
      
      await batch.commit();
      
      // Deal sahibinin puanını azalt (beğeni geri alındı)
      final deal = await getDeal(dealId);
      if (deal != null) {
        await _incrementUserPoints(deal.postedBy, points: -2, totalLikes: -1);
      }
      
      return true;
    } catch (e) {
      _log('Hot vote geri alma hatası: $e');
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
      _log('Favori kontrolü hatası: $e');
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
      _log('Favori ekleme hatası: $e');
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
      _log('Favori çıkarma hatası: $e');
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
      _log('Deal bitirme hatası: $e');
      return false;
    }
  }

  // Kullanıcı engellenmiş mi kontrolü
  Future<bool> isUserBlocked(String userId) async {
    try {
      final doc = await _firestore.collection('blockedUsers').doc(userId).get();
      return doc.exists;
    } catch (e) {
      _log('Kullanıcı engel kontrolü hatası: $e');
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
    String? userProfileImageUrl,
    List<String>? userBadges,
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
        userProfileImageUrl: userProfileImageUrl ?? '',
        text: text,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
        replyToUserName: replyToUserName,
        userBadges: userBadges ?? [],
      );
      
      batch.set(commentRef, comment.toFirestore());
      
      // Comment count'u artır
      batch.update(_firestore.collection('deals').doc(dealId), {
        'commentCount': FieldValue.increment(1),
      });
      
      await batch.commit();
      return true;
    } catch (e) {
      _log('Yorum ekleme hatası: $e');
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
      _log('Yorum silme hatası: $e');
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
      _log('Kullanıcı engelleme hatası: $e');
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
      _log('Deal aktif etme hatası: $e');
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
        _log('✅ $deletedCount expired deal temizlendi');
      }
    } catch (e) {
      _log('❌ Expired deal temizleme hatası: $e');
    }
  }

  // Kullanıcının paylaştığı fırsatları getir
  Stream<List<Deal>> getUserDealsStream(String userId) {
    return _firestore
        .collection('deals')
        .where('postedBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
      // Client-side'da tarihe göre sırala (index gerektirmez)
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Deal silme (admin için)
  Future<bool> deleteDeal(String dealId) async {
    try {
      // Deal'i sil
      await _firestore.collection('deals').doc(dealId).delete();
      
      // Alt koleksiyonları da sil (comments, votes, favorites)
      // Not: Firestore'da alt koleksiyonlar otomatik silinmez, manuel silmek gerekir
      // Ancak performans için şimdilik sadece deal'i siliyoruz
      // İsterseniz Cloud Function ile alt koleksiyonları da temizleyebilirsiniz
      
      return true;
    } catch (e) {
      _log('Deal silme hatası: $e');
      return false;
    }
  }

  // Kullanıcının favori deal'lerini getir
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
        try {
          final dealId = doc.id;
          final dealDoc = await _firestore.collection('deals').doc(dealId).get();
          if (dealDoc.exists) {
            deals.add(Deal.fromFirestore(dealDoc));
          }
        } catch (e) {
          _log('Favori deal getirme hatası: $e');
        }
      }
      return deals;
    });
  }

  // En çok beğenilen deal'leri getir (25+ beğeni)
  Stream<List<Deal>> getMostLikedDeals({int minLikes = 25}) {
    // Client-side filtreleme ile index gerektirmez
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      try {
      final deals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
        // Client-side'da filtrele ve sırala
        final filteredDeals = deals.where((deal) => 
        !deal.isExpired && 
        deal.hotVotes >= minLikes
        ).toList();
        
        // hotVotes'e göre sırala (yüksekten düşüğe)
        filteredDeals.sort((a, b) => b.hotVotes.compareTo(a.hotVotes));
        
        // En fazla 50 deal döndür
        return filteredDeals.take(50).toList();
      } catch (e) {
        _log('getMostLikedDeals hatası: $e');
        return [];
      }
    });
  }

  // Kullanıcının takip ettiği kategorilerin fırsatlarını getir
  Stream<List<Deal>> getFollowedCategoriesDeals(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      try {
        if (!userDoc.exists) return [];
        
        final userData = userDoc.data();
        final followedCategories = List<String>.from(userData?['followedCategories'] ?? []);
        
        if (followedCategories.isEmpty) return [];
        
        // Tüm onaylanmış fırsatları getir
        final dealsSnapshot = await _firestore
            .collection('deals')
            .where('isApproved', isEqualTo: true)
            .get();
        
        final allDeals = dealsSnapshot.docs
            .map((doc) => Deal.fromFirestore(doc))
            .toList();
        
        // Takip edilen kategorilere ait fırsatları filtrele
        final filteredDeals = allDeals.where((deal) {
          if (deal.isExpired) return false;
          // Kategori eşleşmesi (case-insensitive)
          return followedCategories.any((categoryId) =>
            deal.category.toLowerCase() == categoryId.toLowerCase()
          );
        }).toList();
        
        // Tarihe göre sırala (yeni önce)
        filteredDeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return filteredDeals;
      } catch (e) {
        _log('getFollowedCategoriesDeals hatası: $e');
        return [];
      }
    });
  }

  // 24 saatten eski onaylanmış deal'ları otomatik sil
  // Her gün sadece bir kez çalışması için kontrol mekanizması ile
  Future<void> deleteOldDeals() async {
    try {
      // Son temizlik zamanını kontrol et (gereksiz çalışmaları önlemek için)
      final lastCleanupDoc = await _firestore.collection('system').doc('lastCleanup').get();
      final lastCleanupTime = lastCleanupDoc.data()?['timestamp'] as Timestamp?;
      
      // Eğer son temizlik 12 saatten daha yakın bir zamanda yapıldıysa, tekrar çalıştırma
      if (lastCleanupTime != null) {
        final timeSinceLastCleanup = DateTime.now().difference(lastCleanupTime.toDate());
        if (timeSinceLastCleanup.inHours < 12) {
          _log('⚠️ Temizlik zaten son 12 saat içinde yapıldı, atlanıyor');
          return;
        }
      }

      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24));
      
      // 24 saatten eski onaylanmış deal'ları bul
      // NOT: Composite index gerektirmemesi için sadece isApproved filtresi kullanıyoruz
      // createdAt filtresini client-side'da yapıyoruz
      final snapshot = await _firestore
          .collection('deals')
          .where('isApproved', isEqualTo: true)
          .get();
      
      // Client-side'da 24 saatten eski deal'ları filtrele
      final oldDeals = snapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isBefore(cutoffTime);
      }).toList();

      // Her birini sil (batch limit 500)
      int deletedCount = 0;
      WriteBatch batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        deletedCount++;
        
        // Batch limit (500) kontrolü
        if (deletedCount % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch(); // Yeni batch oluştur
        }
      }
      
      // Kalan işlemleri commit et
      if (deletedCount % 500 != 0 && deletedCount > 0) {
      await batch.commit();
      }
      
      // Son temizlik zamanını güncelle
      await _firestore.collection('system').doc('lastCleanup').set({
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _log('✅ $deletedCount eski deal silindi');
    } catch (e) {
      _log('❌ Eski deal\'lar silinirken hata: $e');
    }
  }

  // 24 saat içinde onaylanmayan deal'leri otomatik sil
  Future<void> deleteUnapprovedDealsAfter24Hours() async {
    try {
      // Son temizlik zamanını kontrol et (gereksiz çalışmaları önlemek için)
      final lastCleanupDoc = await _firestore.collection('system').doc('lastPendingCleanup').get();
      final lastCleanupTime = lastCleanupDoc.data()?['timestamp'] as Timestamp?;
      
      // Eğer son temizlik 1 saatten daha yakın bir zamanda yapıldıysa, tekrar çalıştırma
      if (lastCleanupTime != null) {
        final timeSinceLastCleanup = DateTime.now().difference(lastCleanupTime.toDate());
        if (timeSinceLastCleanup.inHours < 1) {
          _log('⚠️ Onay bekleyen deal temizliği zaten son 1 saat içinde yapıldı, atlanıyor');
          return;
        }
      }

      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24));
      
      // 24 saatten eski ve onaylanmamış deal'leri bul
      // NOT: Composite index gerektirmemesi için sadece isApproved ve isExpired filtreleri kullanıyoruz
      // createdAt filtresini client-side'da yapıyoruz
      final snapshot = await _firestore
          .collection('deals')
          .where('isApproved', isEqualTo: false)
          .where('isExpired', isEqualTo: false)
          .get();
      
      // Client-side'da 24 saatten eski deal'ları filtrele
      final oldDeals = snapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isBefore(cutoffTime);
      }).toList();

      if (oldDeals.isEmpty) {
        _log('✅ 24 saatten eski onay bekleyen deal yok');
        // Yine de son temizlik zamanını güncelle
        await _firestore.collection('system').doc('lastPendingCleanup').set({
          'timestamp': Timestamp.now(),
        });
        return;
      }

      // Her birini sil (batch limit 500)
      int deletedCount = 0;
      WriteBatch batch = _firestore.batch();
      
      for (var doc in oldDeals) {
        batch.delete(doc.reference);
        deletedCount++;
        
        // Batch limit (500) kontrolü
        if (deletedCount % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch(); // Yeni batch oluştur
        }
      }
      
      // Kalan işlemleri commit et
      if (deletedCount % 500 != 0 && deletedCount > 0) {
        await batch.commit();
      }
      
      // Son temizlik zamanını güncelle
      await _firestore.collection('system').doc('lastPendingCleanup').set({
        'timestamp': Timestamp.now(),
      });
      
      _log('✅ 24 saatten eski onay bekleyen deal\'lar silindi: $deletedCount adet');
    } catch (e) {
      _log('❌ Onay bekleyen deal\'ları temizleme hatası: $e');
    }
  }

  // Deal paylaşım durumunu kontrol et
  Future<bool> isDealSharingEnabled() async {
    try {
      final doc = await _firestore.collection('settings').doc('app').get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['dealSharingEnabled'] ?? true; // Default: true
      }
      return true; // Varsayılan olarak paylaşım açık
    } catch (e) {
      _log('Deal paylaşım durumu kontrol hatası: $e');
      return true; // Hata durumunda paylaşım açık
    }
  }

  // Deal paylaşım durumunu değiştir (admin için)
  Future<bool> setDealSharingEnabled(bool enabled) async {
    try {
      await _firestore.collection('settings').doc('app').set({
        'dealSharingEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      _log('Deal paylaşım durumu güncelleme hatası: $e');
      return false;
    }
  }

  // Deal paylaşım durumunu dinle (Stream)
  Stream<bool> dealSharingEnabledStream() {
    return _firestore
        .collection('settings')
        .doc('app')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data()!['dealSharingEnabled'] ?? true;
      }
      return true; // Varsayılan olarak paylaşım açık
    });
  }

  // Kullanıcının takip ettiği anahtar kelimeleri getir
  Future<List<String>> getUserWatchKeywords(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      if (data == null) return [];
      
      final keywords = data['watchKeywords'];
      if (keywords is List) {
        return keywords.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      _log('❌ getUserWatchKeywords hatası: $e');
      return [];
    }
  }

  // Kullanıcının takip ettiği anahtar kelimeleri güncelle
  Future<void> updateUserWatchKeywords(String userId, List<String> keywords) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'watchKeywords': keywords,
      });
      _log('✅ Anahtar kelimeler güncellendi: $keywords');
    } catch (e) {
      _log('❌ updateUserWatchKeywords hatası: $e');
      rethrow;
    }
  }

  // Anahtar kelime ekle
  Future<void> addWatchKeyword(String userId, String keyword) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'watchKeywords': FieldValue.arrayUnion([keyword]),
      });
      _log('✅ Anahtar kelime eklendi: $keyword');
    } catch (e) {
      _log('❌ addWatchKeyword hatası: $e');
      rethrow;
    }
  }

  // Anahtar kelime çıkar
  Future<void> removeWatchKeyword(String userId, String keyword) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'watchKeywords': FieldValue.arrayRemove([keyword]),
      });
      _log('✅ Anahtar kelime çıkarıldı: $keyword');
    } catch (e) {
      _log('❌ removeWatchKeyword hatası: $e');
      rethrow;
    }
  }

  // ========== MESAJLAŞMA SİSTEMİ ==========

  // Mesaj gönder
  Future<String?> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    try {
      // Gönderen ve alıcı bilgilerini al
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      
      if (!senderDoc.exists || !receiverDoc.exists) {
        _log('❌ Gönderen veya alıcı bulunamadı');
        return null;
      }

      final senderData = senderDoc.data() as Map<String, dynamic>;
      final receiverData = receiverDoc.data() as Map<String, dynamic>;

      final message = Message(
        id: '', // Firestore otomatik ID oluşturacak
        senderId: senderId,
        senderName: senderData['username'] ?? 'Kullanıcı',
        senderImageUrl: senderData['profileImageUrl'] ?? '',
        receiverId: receiverId,
        receiverName: receiverData['username'] ?? 'Kullanıcı',
        receiverImageUrl: receiverData['profileImageUrl'] ?? '',
        text: text.trim(),
        createdAt: DateTime.now(),
        isRead: false,
        isReadByAdmin: false,
      );

      final docRef = await _firestore.collection('messages').add(message.toFirestore());
      
      // Bildirim gönder (NotificationService üzerinden)
      try {
        final notificationService = NotificationService();
        await notificationService.sendMessageNotification(
          receiverId: receiverId,
          senderName: message.senderName,
          messageText: text,
          messageId: docRef.id,
        );
      } catch (e) {
        _log('⚠️ Mesaj bildirimi gönderilemedi: $e');
      }

      return docRef.id;
    } catch (e) {
      _log('❌ Mesaj gönderme hatası: $e');
      return null;
    }
  }

  // Kullanıcının mesajlarını getir (gönderdiği ve aldığı)
  Stream<List<Message>> getUserMessagesStream(String userId) {
    // Hem gönderilen hem alınan mesajları stream olarak dinle
    final senderStream = _firestore
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .snapshots();
    
    final receiverStream = _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .snapshots();

    // İki stream'i birleştir - her birinde değişiklik olduğunda güncelle
    return Stream.multi((controller) {
      List<Message>? senderMessages;
      List<Message>? receiverMessages;

      void emitIfReady() {
        if (senderMessages != null && receiverMessages != null) {
          final allMessages = <Message>[...senderMessages!, ...receiverMessages!];
          // Tarihe göre sırala (yeni önce)
          allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          controller.add(allMessages);
        }
      }

      final senderSub = senderStream.listen(
        (snapshot) {
          senderMessages = snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
          emitIfReady();
        },
        onError: controller.addError,
      );

      final receiverSub = receiverStream.listen(
        (snapshot) {
          receiverMessages = snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
          emitIfReady();
        },
        onError: controller.addError,
      );

      controller.onCancel = () {
        senderSub.cancel();
        receiverSub.cancel();
      };
    });
  }

  // İki kullanıcı arasındaki konuşmayı getir
  Stream<List<Message>> getConversationStream(String userId1, String userId2) {
    // Firestore'da whereIn + orderBy composite index gerektirdiği için
    // orderBy olmadan sorgu yapıp client-side'da sıralama yapıyoruz
    return _firestore
        .collection('messages')
        .where('senderId', whereIn: [userId1, userId2])
        .snapshots()
        .asyncMap((senderSnapshot) async {
      // Alıcı tarafından da kontrol et (orderBy olmadan)
      final receiverSnapshot = await _firestore
          .collection('messages')
          .where('receiverId', whereIn: [userId1, userId2])
          .get();

      final allMessages = <Message>[];
      final messageIds = <String>{};
      
      // Gönderilen mesajlar (senderId kontrolü yapıldı, receiverId kontrolü client-side)
      for (var doc in senderSnapshot.docs) {
        final message = Message.fromFirestore(doc);
        // Her iki kullanıcı da mesajın senderId veya receiverId'si olmalı
        if ((message.senderId == userId1 || message.senderId == userId2) &&
            (message.receiverId == userId1 || message.receiverId == userId2) &&
            !messageIds.contains(message.id)) {
          allMessages.add(message);
          messageIds.add(message.id);
        }
      }
      
      // Alınan mesajlar (receiverId kontrolü yapıldı, senderId kontrolü client-side)
      for (var doc in receiverSnapshot.docs) {
        final message = Message.fromFirestore(doc);
        // Her iki kullanıcı da mesajın senderId veya receiverId'si olmalı
        if ((message.senderId == userId1 || message.senderId == userId2) &&
            (message.receiverId == userId1 || message.receiverId == userId2) &&
            !messageIds.contains(message.id)) {
          allMessages.add(message);
          messageIds.add(message.id);
        }
      }
      
      // Tarihe göre sırala (eski önce - chat için)
      allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      return allMessages;
    });
  }

  // Mesajı okundu olarak işaretle
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'isRead': true,
      });
    } catch (e) {
      _log('❌ Mesaj okundu işaretleme hatası: $e');
    }
  }

  // Tüm mesajları getir (admin için)
  Stream<List<Message>> getAllMessagesStream() {
    return _firestore
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();
    });
  }

  // Mesajı admin tarafından okundu olarak işaretle
  Future<void> markMessageAsReadByAdmin(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'isReadByAdmin': true,
      });
    } catch (e) {
      _log('❌ Mesaj admin okundu işaretleme hatası: $e');
    }
  }

  // Okunmamış mesaj sayısını getir
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      _log('❌ Okunmamış mesaj sayısı alma hatası: $e');
      return 0;
    }
  }

  // ========== TAKİP SİSTEMİ ==========

  // Kullanıcıyı takip et
  Future<void> followUser(String followerId, String followingId) async {
    try {
      final batch = _firestore.batch();
      
      // Takip eden kullanıcının following listesine ekle
      final followerRef = _firestore.collection('users').doc(followerId);
      batch.update(followerRef, {
        'following': FieldValue.arrayUnion([followingId]),
      });
      
      // Takip edilen kullanıcının followersWithNotifications listesine ekle (bildirim aktif olarak başlar)
      final followingRef = _firestore.collection('users').doc(followingId);
      batch.update(followingRef, {
        'followersWithNotifications': FieldValue.arrayUnion([followerId]),
      });
      
      await batch.commit();
      _log('✅ Kullanıcı takip edildi: $followerId -> $followingId');
      
      // Güncelleme sonrası kontrol et
      final verifyDoc = await followingRef.get();
      final verifyData = verifyDoc.data();
      final verifyList = List<String>.from(verifyData?['followersWithNotifications'] ?? []);
      _log('🔍 followUser SONRA: followersWithNotifications=${verifyList.length} kişi, içerik=$verifyList');
      
      if (!verifyList.contains(followerId)) {
        _log('⚠️ UYARI: followersWithNotifications listesine eklenemedi!');
      }
    } catch (e) {
      _log('❌ Kullanıcı takip hatası: $e');
      rethrow;
    }
  }

  // Kullanıcıyı takipten çık
  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      final batch = _firestore.batch();
      
      // Takip eden kullanıcının following listesinden çıkar
      final followerRef = _firestore.collection('users').doc(followerId);
      batch.update(followerRef, {
        'following': FieldValue.arrayRemove([followingId]),
      });
      
      // Takip edilen kullanıcının followersWithNotifications listesinden çıkar
      final followingRef = _firestore.collection('users').doc(followingId);
      batch.update(followingRef, {
        'followersWithNotifications': FieldValue.arrayRemove([followerId]),
      });
      
      await batch.commit();
      _log('✅ Kullanıcı takipten çıkarıldı: $followerId -> $followingId');
    } catch (e) {
      _log('❌ Kullanıcı takipten çıkma hatası: $e');
      rethrow;
    }
  }

  // Takip bildirimlerini aç/kapat
  Future<void> toggleFollowNotification(String followerId, String followingId, bool enable) async {
    try {
      final followingRef = _firestore.collection('users').doc(followingId);
      
      // Önce mevcut durumu kontrol et
      final beforeDoc = await followingRef.get();
      final beforeData = beforeDoc.data();
      final beforeList = List<String>.from(beforeData?['followersWithNotifications'] ?? []);
      _log('🔍 toggleFollowNotification ÖNCE: followersWithNotifications=${beforeList.length} kişi, içerik=$beforeList');
      
      if (enable) {
        // Bildirimleri aç
        await followingRef.update({
          'followersWithNotifications': FieldValue.arrayUnion([followerId]),
        });
        _log('✅ Takip bildirimleri açıldı: $followerId -> $followingId');
        
        // Güncelleme sonrası kontrol et
        final afterDoc = await followingRef.get();
        final afterData = afterDoc.data();
        final afterList = List<String>.from(afterData?['followersWithNotifications'] ?? []);
        _log('🔍 toggleFollowNotification SONRA: followersWithNotifications=${afterList.length} kişi, içerik=$afterList');
        
        if (!afterList.contains(followerId)) {
          _log('⚠️ UYARI: followersWithNotifications listesine eklenemedi!');
        }
      } else {
        // Bildirimleri kapat
        await followingRef.update({
          'followersWithNotifications': FieldValue.arrayRemove([followerId]),
        });
        _log('✅ Takip bildirimleri kapatıldı: $followerId -> $followingId');
        
        // Güncelleme sonrası kontrol et
        final afterDoc = await followingRef.get();
        final afterData = afterDoc.data();
        final afterList = List<String>.from(afterData?['followersWithNotifications'] ?? []);
        _log('🔍 toggleFollowNotification SONRA: followersWithNotifications=${afterList.length} kişi, içerik=$afterList');
      }
    } catch (e) {
      _log('❌ Takip bildirim toggle hatası: $e');
      rethrow;
    }
  }

  // Kullanıcının takip edip etmediğini kontrol et
  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final doc = await _firestore.collection('users').doc(followerId).get();
      if (!doc.exists) {
        _log('⚠️ Kullanıcı dokümanı bulunamadı: $followerId');
        return false;
      }
      
      final data = doc.data();
      final following = List<String>.from(data?['following'] ?? []);
      _log('🔍 isFollowing kontrolü: followerId=$followerId, followingId=$followingId, following listesi uzunluğu=${following.length}');
      if (following.isNotEmpty) {
        _log('📋 Following listesi: ${following.join(", ")}');
      }
      final result = following.contains(followingId);
      _log('${result ? "✅" : "❌"} Takip durumu: $result');
      return result;
    } catch (e) {
      _log('❌ Takip kontrol hatası: $e');
      return false;
    }
  }

  // Kullanıcının takip bildirimlerinin açık olup olmadığını kontrol et
  Future<bool> isFollowNotificationEnabled(String followerId, String followingId) async {
    try {
      final doc = await _firestore.collection('users').doc(followingId).get();
      if (!doc.exists) return false;
      
      final data = doc.data();
      final followersWithNotifications = List<String>.from(data?['followersWithNotifications'] ?? []);
      return followersWithNotifications.contains(followerId);
    } catch (e) {
      _log('❌ Takip bildirim kontrol hatası: $e');
      return false;
    }
  }
}

