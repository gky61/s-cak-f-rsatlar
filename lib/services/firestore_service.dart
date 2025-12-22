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
      final deals = snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();

      // Client-side'da bitmeyenleri önce göster
      deals.sort((a, b) {
        if (!a.isExpired && b.isExpired) return -1;
        if (a.isExpired && !b.isExpired) return 1;
        return 0; // Zaten Firestore'da sıralı
      });

      return deals;
    } catch (e) {
      print('Pagination hatası: $e');
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
      
      // Kullanıcının puanını artır (her paylaşım 5 puan)
      await _incrementUserPoints(userId, points: 5, dealCount: 1);
      
      return docRef.id;
    } catch (e) {
      print('Deal oluşturma hatası: $e');
      return null;
    }
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
      print('Kullanıcı puanı güncelleme hatası: $e');
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
      
      // Deal sahibinin puanını artır (her hot vote 2 puan)
      final deal = await getDeal(dealId);
      if (deal != null && !voteDoc.exists) {
        // Sadece yeni beğeni ise puan ver (daha önce beğenmişse puan verme)
        await _incrementUserPoints(deal.postedBy, points: 2, totalLikes: 1);
      }
      
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
      print('Hot vote geri alma hatası: $e');
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

  // Expired vote ekleme (Fırsat Bitti oyu)
  Future<bool> addExpiredVote(String dealId, String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Önceki oyu kontrol et
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
        // Diğer oyları temizle (hot/cold)
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
      
      // Expired votes sayısını artır
      final dealRef = _firestore.collection('deals').doc(dealId);
      batch.update(dealRef, {
        'expiredVotes': FieldValue.increment(1),
      });
      
      await batch.commit();
      
      // Oyları kontrol et, 10'a ulaştıysa otomatik olarak bitir
      final dealDoc = await dealRef.get();
      if (dealDoc.exists) {
        final expiredVotes = (dealDoc.data()?['expiredVotes'] ?? 0) as int;
        if (expiredVotes >= 10) {
          await dealRef.update({'isExpired': true});
        }
      }
      
      return true;
    } catch (e) {
      print('Expired vote ekleme hatası: $e');
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
      print('Deal silme hatası: $e');
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
          print('Favori deal getirme hatası: $e');
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
        print('getMostLikedDeals hatası: $e');
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
        print('getFollowedCategoriesDeals hatası: $e');
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
          print('⚠️ Temizlik zaten son 12 saat içinde yapıldı, atlanıyor');
          return;
        }
      }

      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24));
      
      // 24 saatten eski onaylanmış deal'ları bul
      final snapshot = await _firestore
          .collection('deals')
          .where('isApproved', isEqualTo: true)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

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
      
      print('✅ $deletedCount eski deal silindi');
    } catch (e) {
      print('❌ Eski deal\'lar silinirken hata: $e');
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
          print('⚠️ Onay bekleyen deal temizliği zaten son 1 saat içinde yapıldı, atlanıyor');
          return;
        }
      }

      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24));
      
      // 24 saatten eski ve onaylanmamış deal'leri bul
      final snapshot = await _firestore
          .collection('deals')
          .where('isApproved', isEqualTo: false)
          .where('isExpired', isEqualTo: false)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      if (snapshot.docs.isEmpty) {
        print('✅ 24 saatten eski onay bekleyen deal yok');
        // Yine de son temizlik zamanını güncelle
        await _firestore.collection('system').doc('lastPendingCleanup').set({
          'timestamp': Timestamp.now(),
        });
        return;
      }

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
      await _firestore.collection('system').doc('lastPendingCleanup').set({
        'timestamp': Timestamp.now(),
      });
      
      print('✅ 24 saatten eski onay bekleyen deal\'lar silindi: $deletedCount adet');
    } catch (e) {
      print('❌ Onay bekleyen deal\'ları temizleme hatası: $e');
    }
  }
}

