import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/deal.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'content_moderation_service.dart';
import 'user_service.dart';
import 'link_preview_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class DealsSnapshot {
  final List<Deal> deals;
  final bool isFromCache;
  DealsSnapshot({required this.deals, required this.isFromCache});
}

class DealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Deals koleksiyonunu dinleme
  Stream<DealsSnapshot> getDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));
      
      final deals = snapshot.docs
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
            if (deal.isTest == true) return false;
            if (deal.isExpired == true) return false;
            if (deal.createdAt.isBefore(cutoffTime)) return false;
            return true;
          })
          .cast<Deal>()
          .toList();
      return DealsSnapshot(deals: deals, isFromCache: snapshot.metadata.isFromCache);
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
      final cutoffTime = now.subtract(const Duration(hours: 48));
      
      return snapshot.docs
          .map((doc) => Deal.fromFirestore(doc))
          .where((deal) {
            if (deal.isTest == true) return false;
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
          .where((deal) => deal != null && deal.isTest != true)
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
          .where((deal) => deal != null && deal!.isApproved != true && deal.isTest != true)
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
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));
      final deals = snapshot.docs
          .map((doc) {
            try { return Deal.fromFirestore(doc); } catch (e) { return null; }
          })
          .where((deal) => deal != null && deal!.isApproved == true && deal.isExpired != true && !deal.createdAt.isBefore(cutoffTime) && deal.isTest != true)
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
      final deals = snapshot.docs
          .map((doc) => Deal.fromFirestore(doc))
          .where((deal) => deal.isTest != true)
          .toList();
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
    double? originalPrice,
    String? priceLabel,
    double? ratingValue,
    int? ratingCount,
    String? brand,
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
            // Akıllı Mükerrer Link Kontrolü
      // Önce yönlendirmeleri çözüyoruz (short link vb. durumları için)
      String resolvedUrl = url;
      try {
        final linkPreviewService = LinkPreviewService();
        resolvedUrl = await linkPreviewService.resolveUrlRedirects(url);
      } catch (e) {
        _log('⚠️ Yönlendirme çözülemedi: $e');
      }

      final cleanUrl = Deal.cleanProductUrl(resolvedUrl);
      if (cleanUrl.isNotEmpty) {
        final querySnapshot = await _firestore
            .collection('deals')
            .where('cleanUrl', isEqualTo: cleanUrl)
            .where('isApproved', isEqualTo: true)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          for (var doc in querySnapshot.docs) {
            final dealData = doc.data();
            
            // Pasif/Biten Kontrolleri:
            final isExpired = dealData['isExpired'] == true;
            final expiredVotes = dealData['expiredVotes'] ?? 0;
            if (isExpired || expiredVotes >= 15) {
              continue;
            }
            
            // Soğuk oylama kontrolü:
            final hotVotes = dealData['hotVotes'] ?? 0;
            final coldVotes = dealData['coldVotes'] ?? 0;
            final totalVotes = hotVotes + coldVotes;
            if (totalVotes >= 5) {
              final hotPercentage = (hotVotes / totalVotes * 100);
              if (hotPercentage < 20) {
                continue;
              }
            }
            if (hotVotes - coldVotes <= -5) {
              continue;
            }
            
            // Aktif fırsat eşleşti -> paylaşımı engelle
            throw Exception('already_shared:${doc.id}');
          }
        }
      }
      
      bool isApprovalRequired = true;
      try {
        final settingsDoc = await _firestore.collection('settings').doc('app').get();
        if (settingsDoc.exists) {
          isApprovalRequired = settingsDoc.data()?['dealApprovalRequired'] ?? true;
        }
      } catch (e) {
        _log('⚠️ Settings loading error: $e');
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
        isApproved: isApprovalRequired ? false : true,
        isUserSubmitted: true,
        cleanUrl: cleanUrl,
        originalPrice: originalPrice,
        priceLabel: priceLabel,
        ratingValue: ratingValue,
        ratingCount: ratingCount,
        brand: brand,
      );

      final docRef = await _firestore.collection('deals').add(deal.toFirestore());
      
      // Kullanıcı puanını artır (UserService kullanımı)
      final userService = UserService();
      await userService.incrementUserPoints(userId, points: 5, dealCount: 1);
      
      // Profil geçmişine minimalist fırsat kartı ekle
      await userService.addLastSharedDeal(
        userId,
        dealId: docRef.id,
        title: title,
        price: price,
        store: store,
        link: url,
      );
      
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
  Future<bool> _updateVoteInternal(String dealId, String userId, String? newType) async {
    try {
      final dealRef = _firestore.collection('deals').doc(dealId);
      final voteRef = dealRef.collection('votes').doc(userId);

      return await _firestore.runTransaction((transaction) async {
        final dealSnapshot = await transaction.get(dealRef);
        final voteSnapshot = await transaction.get(voteRef);

        if (!dealSnapshot.exists) {
          return false;
        }

        final dealData = dealSnapshot.data() as Map<String, dynamic>;
        int hotVotes = dealData['hotVotes'] ?? 0;
        int coldVotes = dealData['coldVotes'] ?? 0;
        final String postedBy = dealData['postedBy'] ?? '';

        String? oldType;
        if (voteSnapshot.exists) {
          oldType = voteSnapshot.data()?['type'] as String?;
        }

        // Eğer eski oy ile yeni oy aynı ise, hiçbir şey yapma
        if (oldType == newType) {
          return true;
        }

        // 1. Eski oyu çıkar ve sayaçları güncelle
        if (oldType != null) {
          if (oldType == 'hot') {
            hotVotes = (hotVotes > 0) ? hotVotes - 1 : 0;
          } else if (oldType == 'cold') {
            coldVotes = (coldVotes > 0) ? coldVotes - 1 : 0;
          }
        }

        // 2. Yeni oyu ekle ve sayaçları güncelle
        if (newType != null) {
          if (newType == 'hot') {
            hotVotes += 1;
          } else if (newType == 'cold') {
            coldVotes += 1;
          }
        }

        // 3. vote doc güncelle
        if (newType == null) {
          final bool expiredVal = voteSnapshot.exists && voteSnapshot.data()?['expired'] == true;
          if (!expiredVal) {
            transaction.delete(voteRef);
          } else {
            transaction.update(voteRef, {
              'type': FieldValue.delete(),
            });
          }
        } else {
          transaction.set(voteRef, {'type': newType}, SetOptions(merge: true));
        }

        // 4. deal doc güncelle
        transaction.update(dealRef, {
          'hotVotes': hotVotes,
          'coldVotes': coldVotes,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 5. Deal sahibine puan ver / geri al (exploit önleme)
        // 'hot' oyu eklendiğinde +2 puan, kaldırıldığında/değiştirildiğinde -2 puan
        final int oldPoints = (oldType == 'hot') ? 2 : 0;
        final int newPoints = (newType == 'hot') ? 2 : 0;
        final int diffPoints = newPoints - oldPoints;

        final int oldLikes = (oldType == 'hot') ? 1 : 0;
        final int newLikes = (newType == 'hot') ? 1 : 0;
        final int diffLikes = newLikes - oldLikes;

        if (postedBy.isNotEmpty && (diffPoints != 0 || diffLikes != 0)) {
          final userService = UserService();
          // Puan güncellemesini transaction sonrasında arka planda yap
          Future.delayed(Duration.zero, () async {
            await userService.incrementUserPoints(postedBy, points: diffPoints, totalLikes: diffLikes);
          });
        }

        return true;
      });
    } catch (e) {
      _log('updateVoteInternal hatası: $e');
      return false;
    }
  }

  Future<bool> addHotVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, 'hot');
  Future<bool> addColdVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, 'cold');
  Future<bool> removeVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, null);
  Future<bool> removeHotVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, null);
  Future<bool> removeColdVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, null);

  // Bağımsız Fırsat Bitti Oylaması (votes/{userId} dokümanında 'expired': true alanı olarak tutulur)
  Future<bool> addExpiredVote(String dealId, String userId) async {
    try {
      final dealRef = _firestore.collection('deals').doc(dealId);
      final voteRef = dealRef.collection('votes').doc(userId);

      return await _firestore.runTransaction((transaction) async {
        final dealSnapshot = await transaction.get(dealRef);
        final voteSnapshot = await transaction.get(voteRef);

        if (!dealSnapshot.exists) return false;

        bool alreadyVotedExpired = false;
        if (voteSnapshot.exists) {
          alreadyVotedExpired = voteSnapshot.data()?['expired'] == true;
        }

        if (alreadyVotedExpired) return true; // Zaten bitirme oyu verilmiş

        final dealData = dealSnapshot.data() as Map<String, dynamic>;
        int hotVotes = dealData['hotVotes'] ?? 0;
        int expiredVotes = dealData['expiredVotes'] ?? 0;
        bool isExpired = dealData['isExpired'] ?? false;

        expiredVotes += 1;
        final dynamicLimit = (5 + (hotVotes / 5).floor()).clamp(5, 20);
        if (expiredVotes >= dynamicLimit) {
          isExpired = true;
        }

        transaction.set(voteRef, {'expired': true, 'expiredAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        transaction.update(dealRef, {
          'expiredVotes': expiredVotes,
          'isExpired': isExpired,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      _log('addExpiredVote hatası: $e');
      return false;
    }
  }

  Future<bool> removeExpiredVote(String dealId, String userId) async {
    try {
      final dealRef = _firestore.collection('deals').doc(dealId);
      final voteRef = dealRef.collection('votes').doc(userId);

      return await _firestore.runTransaction((transaction) async {
        final dealSnapshot = await transaction.get(dealRef);
        final voteSnapshot = await transaction.get(voteRef);

        if (!dealSnapshot.exists || !voteSnapshot.exists) return false;

        bool alreadyVotedExpired = voteSnapshot.data()?['expired'] == true;
        if (!alreadyVotedExpired) return true;

        final dealData = dealSnapshot.data() as Map<String, dynamic>;
        int expiredVotes = dealData['expiredVotes'] ?? 0;
        expiredVotes = (expiredVotes > 0) ? expiredVotes - 1 : 0;

        // type alanı da yoksa dökümanı tamamen sil, varsa sadece expired alanını kaldır
        final String? type = voteSnapshot.data()?['type'] as String?;
        if (type == null) {
          transaction.delete(voteRef);
        } else {
          transaction.update(voteRef, {
            'expired': FieldValue.delete(),
            'expiredAt': FieldValue.delete(),
          });
        }

        transaction.update(dealRef, {
          'expiredVotes': expiredVotes,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      _log('removeExpiredVote hatası: $e');
      return false;
    }
  }

  Future<bool> hasUserVotedExpired(String dealId, String userId) async {
    try {
      final doc = await _firestore.collection('deals').doc(dealId).collection('votes').doc(userId).get();
      return doc.data()?['expired'] == true;
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

  // Test deals dinleme stream'i
  Stream<List<Deal>> getTestDealsStream() {
    return _firestore
        .collection('deals')
        .where('isTest', isEqualTo: true)
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

  // Toplu deal silme
  Future<bool> deleteDealsBatch(List<String> dealIds) async {
    try {
      final batch = _firestore.batch();
      for (final id in dealIds) {
        batch.delete(_firestore.collection('deals').doc(id));
      }
      await batch.commit();
      return true;
    } catch (e) {
      _log('Batch silme hatası: $e');
      return false;
    }
  }
}
