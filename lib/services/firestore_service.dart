import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/deal.dart';
import '../models/comment.dart';
import '../models/message.dart';
import '../models/admin_to_user_message.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import 'deal_service.dart';
import 'user_service.dart';
import 'message_service.dart';
import 'comment_service.dart';
import 'system_log_service.dart';
import 'app_badge_service.dart';

export 'deal_service.dart' show DealSubmitResult, DealBusinessException, DealPendingApprovalException, DealAlreadySharedException;

/// Bu sınıf artık bir Facade (Ön Yüz) görevi görmektedir.
/// Tüm karmaşık işlemler alt servislere (DealService, UserService vb.) dağıtılmıştır.
class FirestoreService {
  // Alt Servisler
  final DealService _dealService = DealService();
  final UserService _userService = UserService();
  final MessageService _messageService = MessageService();
  final CommentService _commentService = CommentService();
  
  // Public getter
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Bozuk veya eksik Firestore verisi içeren dokümanları loglar ve güvenli şekilde null döndürür
  Deal? _safeParseDeal(DocumentSnapshot doc) {
    try {
      return Deal.fromFirestore(doc);
    } catch (e, stack) {
      _log('❌ Deal parse hatası (doc.id: ${doc.id}): $e');
      SystemLogService.instance.logError(
        category: 'data_parsing',
        errorType: 'DealDeserializationException',
        message: 'Fırsat dokümanı parse edilemedi (${doc.id}): $e',
        stack: stack,
        severity: SystemErrorSeverity.error,
        metadata: {'docId': doc.id},
      );
      return null;
    }
  }

  // Raporlar koleksiyonu
  CollectionReference get reportsCollection => firestore.collection('reports');

  // ===========================================================================
  // DEAL İŞLEMLERİ (DealService üzerinden)
  // ===========================================================================
  
  Stream<DealsSnapshot> getDealsStream() => _dealService.getDealsStream();
  
  // FS-09: SWR + Cache-First Sayfalı Fırsat Getirme
  Future<DealsPageResult> getDealsPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? category,
    String? subCategory,
    Source source = Source.serverAndCache,
  }) => _dealService.getDealsPaginated(
    limit: limit,
    lastDocument: lastDocument,
    category: category,
    subCategory: subCategory,
    source: source,
  );

  // FS-09: Yalnızca en yeni fırsatı dinleyen ultra hafif stream (limit: 1)
  Stream<Deal?> getLatestDealStream({String? category}) =>
      _dealService.getLatestDealStream(category: category);

  // FS-20: Hibrit Arama Kademe 2 — Firestore Sunucu Tabanlı Hedefli Arama
  Future<List<Deal>> searchDealsServer({
    required String query,
    String? category,
    int limit = 30,
  }) =>
      _dealService.searchDealsServer(
        query: query,
        category: category,
        limit: limit,
      );

  Future<List<Deal>> getInitialDeals({int limit = 20}) async =>
      (await getDealsPaginated(limit: limit)).deals;
  
  Stream<List<Deal>> getAllDealsStream() => _dealService.getApprovedDealsStream(); // İsim uyumluluğu için
  
  Stream<List<Deal>> getExpiredDealsStream() => _dealService.getExpiredDealsStream();
  
  Stream<List<Deal>> getPendingDealsStream() => _dealService.getPendingDealsStream();
  
  Stream<List<Deal>> getUserSubmittedPendingDealsStream() => _dealService.getUserSubmittedPendingDealsStream();
  
  Stream<List<Deal>> getApprovedDealsStream() => _dealService.getApprovedDealsStream();
  
  Future<bool> approveDealsBatch(List<String> dealIds) => _dealService.approveDealsBatch(dealIds);
  Future<bool> rejectDealsBatch(List<String> dealIds) => _dealService.rejectDealsBatch(dealIds);
  
  Future<Deal?> getDeal(String dealId) => _dealService.getDeal(dealId);
  Future<bool> markDealAsExpired(String dealId) => _dealService.markDealAsExpired(dealId);
  
  Future<String?> addDeal(Deal deal) async {
    // Legacy support: createDeal tercih edilmeli
    final docRef = await firestore.collection('deals').add(deal.toFirestore());
      return docRef.id;
  }

  Future<DealSubmitResult?> createDeal({
    required String title,
    required String description,
    required double price,
    required String store,
    required String category,
    String? subCategory,
    required String imageUrl,
    required String url,
    required String userId,
    String? postedByName,
    String? postedByAvatar,
    double? originalPrice,
    String? priceLabel,
    double? ratingValue,
    int? ratingCount,
    String? brand,
    String? canonicalUrl,
    bool isAmazonWarehouse = false,
    bool hidePrice = false,
  }) => _dealService.createDeal(
        title: title,
        description: description,
        price: price,
        store: store,
        category: category,
        subCategory: subCategory,
        imageUrl: imageUrl,
        url: url,
        userId: userId,
        postedByName: postedByName,
        postedByAvatar: postedByAvatar,
        originalPrice: originalPrice,
        priceLabel: priceLabel,
        ratingValue: ratingValue,
        ratingCount: ratingCount,
        brand: brand,
        canonicalUrl: canonicalUrl,
        isAmazonWarehouse: isAmazonWarehouse,
        hidePrice: hidePrice,
      );

  Future<bool> updateDeal(String dealId, Map<String, dynamic> updates) => _dealService.updateDeal(dealId, updates);
  
  Future<bool> deleteDeal(String dealId) => _dealService.deleteDeal(dealId);
  
  Future<bool> unexpireDeal(
    String dealId, {
    bool refreshTimestamp = false,
    bool hidePrice = false,
    bool isEditorPick = false,
  }) =>
      _dealService.unexpireDeal(
        dealId,
        refreshTimestamp: refreshTimestamp,
        hidePrice: hidePrice,
        isEditorPick: isEditorPick,
      );

  Future<bool> unexpireDealsBatch(
    List<String> dealIds, {
    bool refreshTimestamp = false,
  }) =>
      _dealService.unexpireDealsBatch(
        dealIds,
        refreshTimestamp: refreshTimestamp,
      );
  
  Future<void> deleteOldDeals() async {
    // NOT: Eski fırsatların temizliği (purgeOldDeals) Cloud Functions cron job tarafından
    // sunucu tarafında güvenli ve yetkili biçimde yürütülür.
    return;
  }

  Future<void> deleteUnapprovedDealsAfter24Hours() async {
    // NOT: Onaysız eski fırsat temizliği sunucu tarafında yürütülür.
    return;
  }

  Future<void> cleanupExpiredDeals() async {
    // NOT: Süresi dolan fırsat temizliği (cleanupExpiredDeals) sunucu tarafında yürütülür.
    return;
  }

  Stream<List<Deal>> getUserDealsStream(String userId, {int? limit, bool onlyApproved = false}) {
    // Güvenlik Tavanı (Maks 100): Firestore seviyesinde doğrudan limit uygulanır.
    // postedBy + createdAt bileşik indeksi üzerinden en taze fırsatlar tavanla çekilir.
    // Bellek tükenmesi ve on binlerce fırsatın gereksiz yere indirilmesi engellenir.
    final effectiveLimit = limit != null ? (onlyApproved ? (limit * 2).clamp(10, 100) : limit) : 100;

    return firestore.collection('deals')
        .where('postedBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(effectiveLimit)
        .snapshots()
        .map((s) {
          var list = s.docs.map((d) => Deal.fromFirestore(d)).toList();
          if (onlyApproved) {
            list = list.where((d) => d.isApproved == true && d.isTest != true).toList();
          }
          if (limit != null) {
            return list.take(limit).toList();
          }
          return list;
        });
  }

  /// Botkolik tarafından paylaşılan (otonom kazınan) onaylı tüm fırsatların akışı
  Stream<List<Deal>> getBotkolikDealsStream({int? limit, String? categoryId}) {
    Query query = firestore.collection('deals')
        .where('isApproved', isEqualTo: true)
        .where('isUserSubmitted', isEqualTo: false);

    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      query = query.where('category', isEqualTo: categoryId);
    }

    query = query.orderBy('createdAt', descending: true).limit(limit ?? 50);

    return query.snapshots().map((s) {
      final list = s.docs
          .map((d) => Deal.fromFirestore(d))
          .where((deal) => deal.isTest != true)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<Deal>> getPopularDeals({int minHotVotes = 3}) {
    return firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48)); // Tüm menülerle tutarlı
      
      final deals = snapshot.docs
          .map((doc) => _safeParseDeal(doc))
          .where((deal) =>
              deal != null &&
              deal.isTest != true &&
              deal.isExpired != true &&
              deal.hotVotes >= minHotVotes &&
              deal.netScore > 0 && // Net skoru pozitif olmalı (topluluk onaylı)
              !deal.createdAt.isBefore(cutoffTime))
          .cast<Deal>()
          .toList();

      // Popülerlik skoruna göre sırala (Wilson Score + Zaman Çürümesi + Engagement)
      deals.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
      return deals.take(50).toList();
    });
  }

  /// Alias for backward compatibility
  Stream<List<Deal>> getMostLikedDeals({int minLikes = 3}) => getPopularDeals(minHotVotes: minLikes);

  // FS-18: Popüler Fırsatlar Sayfalı ve SWR Destekli Getirme
  Future<DealsPageResult> getPopularDealsPaginated({
    int limit = 40,
    DocumentSnapshot? lastDocument,
    int minHotVotes = 3,
    String? category,
    Source source = Source.serverAndCache,
  }) =>
      _dealService.getPopularDealsPaginated(
        limit: limit,
        lastDocument: lastDocument,
        minHotVotes: minHotVotes,
        category: category,
        source: source,
      );

  // FS-18: Favori Kategorilerim Sayfalı ve SWR Destekli Getirme
  Future<DealsPageResult> getFollowedCategoriesDealsPaginated({
    required String userId,
    int limit = 40,
    DocumentSnapshot? lastDocument,
    Source source = Source.serverAndCache,
  }) =>
      _dealService.getFollowedCategoriesDealsPaginated(
        userId: userId,
        limit: limit,
        lastDocument: lastDocument,
        source: source,
      );

  Stream<List<Deal>> getFollowedCategoriesDeals(String userId) {
    late StreamController<List<Deal>> controller;
    
    StreamSubscription? subSubscription;
    StreamSubscription? dealsSubscription;
    
    Set<String> followedCategoryKeys = {};
    Set<String> followedSubCategoryKeys = {};
    List<Deal> approvedDeals = [];
    
    void updateList() {
      if (controller.isClosed) return;
      if (followedCategoryKeys.isEmpty && followedSubCategoryKeys.isEmpty) {
        controller.add([]);
        return;
      }
      final filtered = approvedDeals.where((d) {
        final catLower = d.category.toLowerCase();
        if (followedCategoryKeys.contains(catLower)) return true;
        
        if (d.subCategory != null && d.subCategory!.isNotEmpty) {
          final subKey = '$catLower:${d.subCategory!.toLowerCase()}';
          if (followedSubCategoryKeys.contains(subKey)) return true;
        }
        return false;
      }).toList();

      // Ana Sayfa Algoritması (homeFeedScore DESC) ile birebir aynı skorlama ve sıralama
      filtered.sort((a, b) => b.homeFeedScore.compareTo(a.homeFeedScore));

      controller.add(filtered);
    }
    
    controller = StreamController<List<Deal>>.broadcast(
      onListen: () {
        subSubscription = firestore
            .collection('notificationSubscriptions')
            .where('uid', isEqualTo: userId)
            .where('type', isEqualTo: 'category')
            .where('enabled', isEqualTo: true)
            .limit(100)
            .snapshots()
            .listen((snapshot) {
          followedCategoryKeys.clear();
          followedSubCategoryKeys.clear();
          for (var doc in snapshot.docs) {
            final key = (doc.data()['key'] as String? ?? '').toLowerCase();
            if (key.isEmpty) continue;
            if (key.contains(':')) {
              followedSubCategoryKeys.add(key);
            } else {
              followedCategoryKeys.add(key);
            }
          }
          updateList();
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });
        
        dealsSubscription = firestore
            .collection('deals')
            .where('isApproved', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots()
            .map((snapshot) {
          final now = DateTime.now();
          final cutoffTime = now.subtract(const Duration(hours: 48)); // Anasayfa ile tutarlı
          
          return snapshot.docs
              .map((doc) => _safeParseDeal(doc))
              .where((deal) =>
                  deal != null &&
                  deal.isTest != true &&
                  !deal.createdAt.isBefore(cutoffTime))
              .cast<Deal>()
              .toList();
        })
        .listen((deals) {
          approvedDeals = deals;
          updateList();
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });
      },
      onCancel: () {
        subSubscription?.cancel();
        dealsSubscription?.cancel();
        subSubscription = null;
        dealsSubscription = null;
      },
    );
    
    return controller.stream;
  }

  // ===========================================================================
  // OYLAMA İŞLEMLERİ (DealService ve UserService)
  // ===========================================================================

  Future<String?> getUserVote(String dealId, String userId) => _dealService.getUserVote(dealId, userId);
  Future<bool> hasUserVotedExpired(String dealId, String userId) => _dealService.hasUserVotedExpired(dealId, userId);
  Future<bool> addHotVote(String dealId, String userId) => _dealService.addHotVote(dealId, userId);
  Future<bool> addColdVote(String dealId, String userId) => _dealService.addColdVote(dealId, userId);
  Future<bool> addExpiredVote(String dealId, String userId) => _dealService.addExpiredVote(dealId, userId);
  Future<bool> removeVote(String dealId, String userId) => _dealService.removeVote(dealId, userId);
  Future<bool> removeHotVote(String dealId, String userId) => _dealService.removeHotVote(dealId, userId);
  Future<bool> removeColdVote(String dealId, String userId) => _dealService.removeColdVote(dealId, userId);
  Future<bool> removeExpiredVote(String dealId, String userId) => _dealService.removeExpiredVote(dealId, userId);
      
  // ===========================================================================
  // KULLANICI İŞLEMLERİ (UserService üzerinden)
  // ===========================================================================

  Future<bool> isFavorite(String userId, String dealId) => _userService.isFavorite(userId, dealId);
  Future<bool> addToFavorites(
    String userId,
    String dealId, {
    String? title,
    double? price,
    String? store,
    String? link,
    String? imageUrl,
    String? category,
    bool? isExpired,
  }) =>
      _userService.addToFavorites(
        userId,
        dealId,
        title: title,
        price: price,
        store: store,
        link: link,
        imageUrl: imageUrl,
        category: category,
        isExpired: isExpired,
      );
  Future<bool> removeFromFavorites(String userId, String dealId) => _userService.removeFromFavorites(userId, dealId);
  Stream<List<Deal>> getFavoriteDeals(String userId) => _userService.getFavoriteDeals(userId);
  Future<DealsPageResult> getFavoriteDealsPaginated({
    required String userId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
    Source source = Source.serverAndCache,
  }) =>
      _userService.getFavoriteDealsPaginated(
        userId: userId,
        limit: limit,
        lastDocument: lastDocument,
        source: source,
      );
  Future<void> addLastSharedDeal(String userId, {required String dealId, required String title, required double price, required String store, required String link}) =>
      _userService.addLastSharedDeal(userId, dealId: dealId, title: title, price: price, store: store, link: link);
  
  Future<void> followUser(String followerId, String followingId) => _userService.followUser(followerId, followingId);
  Future<void> unfollowUser(String followerId, String followingId) => _userService.unfollowUser(followerId, followingId);
  Future<bool> isFollowing(String followerId, String followingId) => _userService.isFollowing(followerId, followingId);
  Stream<List<AppUser>> getFollowingUsersStream(String userId) => _userService.getFollowingUsersStream(userId);
  Future<bool> isFollowNotificationEnabled(String followerId, String followingId) => _userService.isFollowNotificationEnabled(followerId, followingId);
  Future<void> toggleFollowNotification(String followerId, String followingId, bool enable) => _userService.toggleFollowNotification(followerId, followingId, enable);

  /// Takip edilen kullanıcılar arasından bildirim aboneliği açık olanların UID set'ini dinler
  Stream<Set<String>> getFollowedNotificationUserIdsStream(String currentUserId) {
    return firestore
        .collection('notificationSubscriptions')
        .where('uid', isEqualTo: currentUserId)
        .where('type', isEqualTo: 'author')
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final set = <String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['enabled'] == true) {
              final key = data['key'] as String? ?? '';
              if (key.isNotEmpty) set.add(key);
            }
          }
          return set;
        });
  }

  /// Takip edilen kullanıcıların paylaştığı onaylı sıcak fırsatların akışı
  Stream<List<Deal>> getFollowedUsersDealsStream(List<String> followedUserIds, {int limit = 50}) {
    if (followedUserIds.isEmpty) {
      return Stream.value([]);
    }

    final effectiveLimit = limit.clamp(10, 100);
    final chunks = <List<String>>[];
    for (var i = 0; i < followedUserIds.length; i += 30) {
      chunks.add(followedUserIds.sublist(
        i,
        (i + 30 > followedUserIds.length) ? followedUserIds.length : i + 30,
      ));
    }

    if (chunks.length == 1) {
      return firestore
          .collection('deals')
          .where('isApproved', isEqualTo: true)
          .where('postedBy', whereIn: chunks.first)
          .orderBy('createdAt', descending: true)
          .limit(effectiveLimit)
          .snapshots()
          .map((snapshot) {
            final deals = snapshot.docs
                .map((doc) => _safeParseDeal(doc))
                .where((deal) => deal != null && deal.isTest != true)
                .cast<Deal>()
                .toList();
            deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return deals.take(effectiveLimit).toList();
          });
    }

    late StreamController<List<Deal>> controller;
    final subscriptions = <StreamSubscription>[];
    final Map<int, List<Deal>> chunkResults = {};

    void emitMerged() {
      final allDeals = <Deal>[];
      for (final list in chunkResults.values) {
        allDeals.addAll(list);
      }
      allDeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) {
        controller.add(allDeals.take(effectiveLimit).toList());
      }
    }

    controller = StreamController<List<Deal>>.broadcast(
      onListen: () {
        for (var i = 0; i < chunks.length; i++) {
          final index = i;
          final sub = firestore
              .collection('deals')
              .where('isApproved', isEqualTo: true)
              .where('postedBy', whereIn: chunks[index])
              .orderBy('createdAt', descending: true)
              .limit(effectiveLimit)
              .snapshots()
              .listen((snapshot) {
                final list = snapshot.docs
                    .map((d) => _safeParseDeal(d))
                    .where((d) => d != null && d.isTest != true)
                    .cast<Deal>()
                    .toList();
                chunkResults[index] = list;
                emitMerged();
              }, onError: (e) {
                if (!controller.isClosed) controller.addError(e);
              });
          subscriptions.add(sub);
        }
      },
      onCancel: () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
        subscriptions.clear();
        chunkResults.clear();
      },
    );

    return controller.stream;
  }

  /// Takip edilmeyen, topluluğun öne çıkan/popüler avcılarını önerir
  Stream<List<AppUser>> getSuggestedHuntersStream({int limit = 10, List<String> excludeUserIds = const []}) {
    return firestore
        .collection('users')
        .limit(30)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) {
                try {
                  return AppUser.fromFirestore(d);
                } catch (_) {
                  return null;
                }
              })
              .where((u) => u != null && !u.isBot && !excludeUserIds.contains(u.uid))
              .cast<AppUser>()
              .toList();
          list.sort((a, b) {
            if (b.dealCount != a.dealCount) {
              return b.dealCount.compareTo(a.dealCount);
            }
            return b.points.compareTo(a.points);
          });
          return list.take(limit).toList();
        });
  }
  
  Future<List<String>> getUserWatchKeywords(String userId) => _userService.getUserWatchKeywords(userId);
  Future<void> addWatchKeyword(String userId, String keyword) => _userService.addWatchKeyword(userId, keyword);
  Future<void> removeWatchKeyword(String userId, String keyword) => _userService.removeWatchKeyword(userId, keyword);
  
  Future<bool> isUserBlocked(String userId) => _userService.isUserBlocked(userId);
  Future<bool> blockUser(String userId) => _userService.blockUser(userId);
  Future<bool> isUserDealBanned(String userId) => _userService.isUserDealBanned(userId);
  Future<bool> isUserCommentBanned(String userId) => _userService.isUserCommentBanned(userId);

  // ===========================================================================
  // MESAJLAŞMA İŞLEMLERİ (MessageService üzerinden)
  // ===========================================================================

  Future<String?> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? dealId,
    String? dealTitle,
    String? dealImageUrl,
    String? dealPrice,
    String? dealStore,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToText,
  }) =>
      _messageService.sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        dealId: dealId,
        dealTitle: dealTitle,
        dealImageUrl: dealImageUrl,
        dealPrice: dealPrice,
        dealStore: dealStore,
        replyToMessageId: replyToMessageId,
        replyToSenderName: replyToSenderName,
        replyToText: replyToText,
      );
      
  Stream<List<Message>> getUserMessagesStream(String userId) {
    late StreamController<List<Message>> controller;
    StreamSubscription? senderSub;
    StreamSubscription? receiverSub;
    StreamSubscription? adminSub;

    controller = StreamController<List<Message>>(
      onListen: () {
        List<Message> s = [], r = [], a = [];
        void emit() {
          if (!controller.isClosed) {
            final all = [...s, ...r, ...a]
                .where((m) => !m.deletedBy.contains(userId))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            controller.add(all);
          }
        }

        senderSub = firestore
            .collection('messages')
            .where('senderId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots()
            .listen(
          (snap) {
            s = snap.docs.map((d) => Message.fromFirestore(d)).toList();
            emit();
          },
          onError: (error) {
            final isPerm = error.toString().contains('permission-denied');
            if (isPerm && FirebaseAuth.instance.currentUser == null) {
              return; // Oturum kapalıyken beklenen kapanış
            }
            _log('⚠️ senderStream error: $error');
            SystemLogService.instance.logError(
              category: 'stream_listener',
              errorType: 'SenderStreamException',
              message: error.toString(),
              severity: SystemErrorSeverity.error,
            );
          },
        );

        receiverSub = firestore
            .collection('messages')
            .where('receiverId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots()
            .listen(
          (snap) {
            r = snap.docs.map((d) => Message.fromFirestore(d)).toList();
            emit();
          },
          onError: (error) {
            final isPerm = error.toString().contains('permission-denied');
            if (isPerm && FirebaseAuth.instance.currentUser == null) {
              return; // Oturum kapalıyken beklenen kapanış
            }
            _log('⚠️ receiverStream error: $error');
            SystemLogService.instance.logError(
              category: 'stream_listener',
              errorType: 'ReceiverStreamException',
              message: error.toString(),
              severity: SystemErrorSeverity.error,
            );
          },
        );

        adminSub = firestore
            .collection('adminToUserMessages')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .listen(
          (snap) {
            a = snap.docs.map((d) => Message.fromAdminFirestore(d)).toList();
            emit();
          },
          onError: (error) {
            final isPerm = error.toString().contains('permission-denied');
            if (isPerm && FirebaseAuth.instance.currentUser == null) {
              return; // Oturum kapalıyken beklenen kapanış
            }
            _log('⚠️ adminStream error: $error');
            SystemLogService.instance.logError(
              category: 'stream_listener',
              errorType: 'AdminStreamException',
              message: error.toString(),
              severity: SystemErrorSeverity.error,
            );
          },
        );
      },
      onCancel: () {
        senderSub?.cancel();
        receiverSub?.cancel();
        adminSub?.cancel();
      },
    );

    return controller.stream;
  }
  
  Stream<List<Conversation>> getConversationsStream(String uid, {int limit = 40}) =>
      _messageService.getConversationsStream(uid, limit: limit);
  Stream<int> getUnreadTotalMessageCountStream(String uid) =>
      _messageService.getUnreadTotalMessageCountStream(uid);
  Future<List<Message>> loadOlderMessages({
    required String currentUserId,
    required String otherUserId,
    required DateTime oldestCreatedAt,
    DateTime? clearedAt,
    int limit = 30,
  }) =>
      _messageService.loadOlderMessages(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        oldestCreatedAt: oldestCreatedAt,
        clearedAt: clearedAt,
        limit: limit,
      );

  Stream<List<Message>> getConversationStream(String u1, String u2, {int limit = 60}) =>
      _messageService.getConversationStream(u1, u2, limit: limit);
  Future<void> toggleReaction({required String messageId, required String userId, required String emoji}) =>
      _messageService.toggleReaction(messageId: messageId, userId: userId, emoji: emoji);
  Future<void> markMessageAsRead(String id) => _messageService.markMessageAsRead(id);
  Future<void> markConversationAsRead(String u1, String u2) => _messageService.markConversationAsRead(u1, u2);
  Future<void> softDeleteMessageForUser(String messageId, String userId) => _messageService.softDeleteMessageForUser(messageId, userId);
  Future<bool> deleteMessageForEveryone(String messageId, String currentUserId) => _messageService.deleteMessageForEveryone(messageId, currentUserId);
  Future<void> deleteUserMessage(String id) => _messageService.deleteUserMessage(id);
  Future<void> clearConversationForUser(String u1, String u2) =>
      _messageService.clearConversationForUser(u1, u2);
  Future<void> deleteConversationPermanently(String u1, String u2) =>
      _messageService.deleteConversationPermanently(u1, u2);
  Future<int> getUnreadMessageCount(String uid) => _messageService.getUnreadMessageCount(uid);
  Stream<List<Message>> getAllMessagesStream() => _messageService.getAllMessagesStream();
  Future<void> markMessageAsReadByAdmin(String id) => _messageService.markMessageAsReadByAdmin(id);
  Future<int> deleteAllMessages() => _messageService.deleteAllMessages();
  Future<bool> deleteSingleMessage(String id) => _messageService.deleteSingleMessage(id);

  Future<void> setTypingStatus({required String currentUserId, required String otherUserId, required bool isTyping}) =>
      _messageService.setTypingStatus(currentUserId: currentUserId, otherUserId: otherUserId, isTyping: isTyping);
  Stream<bool> getTypingStream({required String currentUserId, required String otherUserId}) =>
      _messageService.getTypingStream(currentUserId: currentUserId, otherUserId: otherUserId);

  Future<void> blockUserForChat(String currentUserId, String targetUserId) => _messageService.blockUser(currentUserId, targetUserId);
  Future<void> unblockUserForChat(String currentUserId, String targetUserId) => _messageService.unblockUser(currentUserId, targetUserId);
  Future<bool> isUserBlockedForChat(String currentUserId, String targetUserId) => _messageService.isUserBlocked(currentUserId, targetUserId);

  Future<void> toggleMuteConversation(String currentUserId, String otherUserId, bool mute) => _messageService.toggleMuteConversation(currentUserId, otherUserId, mute);
  Future<bool> isConversationMuted(String currentUserId, String otherUserId) => _messageService.isConversationMuted(currentUserId, otherUserId);
  
  Stream<List<AdminToUserMessage>> getAdminToUserMessagesStream(String uid, {int limit = 200}) => 
      _messageService.getAdminToUserMessagesStream(uid, limit: limit);
  Future<int> getUnreadAdminToUserMessageCount(String uid) => _messageService.getUnreadAdminToUserMessageCount(uid);
  Future<void> markAdminToUserMessageAsRead(String id) => _messageService.markAdminToUserMessageAsRead(id);
  Future<void> deleteAdminToUserMessage(String id) => _messageService.deleteAdminToUserMessage(id);
  Future<int> deleteAllAdminToUserMessages(String userId) async {
    final batch = firestore.batch();
    final snap = await firestore.collection('adminToUserMessages').where('userId', isEqualTo: userId).limit(100).get();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }

  // ===========================================================================
  // YORUM İŞLEMLERİ (CommentService üzerinden)
  // ===========================================================================

  Future<bool> addComment({
    required String dealId,
    required String userId,
    required String userName,
    required String userEmail,
    required String text,
    String? parentCommentId,
    String? replyToUserName,
    String? quotedCommentText,
    String? userProfileImageUrl,
    List<String>? userBadges,
    String? userPinnedBadge,
  }) => _commentService.addComment(
        dealId: dealId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        text: text,
        parentCommentId: parentCommentId,
        replyToUserName: replyToUserName,
        quotedCommentText: quotedCommentText,
    userProfileImageUrl: userProfileImageUrl,
    userBadges: userBadges,
    userPinnedBadge: userPinnedBadge,
  );

  Stream<List<Comment>> getCommentsStream(String dealId) => _commentService.getCommentsStream(dealId);
  Future<bool> deleteComment(String commentId, String dealId) => _commentService.deleteComment(commentId, dealId);
  Future<void> toggleCommentReaction({
    required String dealId,
    required String commentId,
    required String userId,
    required String emoji,
  }) => _commentService.toggleCommentReaction(
        dealId: dealId,
        commentId: commentId,
        userId: userId,
        emoji: emoji,
      );
  
  Stream<List<Map<String, dynamic>>> getCommentReplyNotificationsStream(String userId) => 
      _commentService.getCommentReplyNotificationsStream(userId);
  Future<void> markCommentReplyNotificationAsRead(String userId, String notificationId) => 
      _commentService.markCommentReplyNotificationAsRead(userId, notificationId);
  Future<void> deleteCommentReplyNotification(String userId, String notificationId) => 
      _commentService.deleteCommentReplyNotification(userId, notificationId);
  Future<int> deleteAllCommentReplyNotifications(String userId) => 
      _commentService.deleteAllCommentReplyNotifications(userId);

  // ===========================================================================
  // UNIFIED NOTIFICATION CENTER (FS-02 DUAL-LAYER IN-APP FEED)
  // ===========================================================================

  static final StreamController<void> _announcementChangeController = StreamController<void>.broadcast();
  static Set<String>? _cachedReadAnnouncements;
  static Set<String>? _cachedDismissedAnnouncements;
  static String? _hydratedUserId;

  static Set<String> get cachedReadAnnouncements => _cachedReadAnnouncements ?? {};
  static Set<String> get cachedDismissedAnnouncements => _cachedDismissedAnnouncements ?? {};

  /// Oturum kapatıldığında veya kullanıcı değiştiğinde statik önbelleği temizler
  static void clearAnnouncementCache() {
    _cachedReadAnnouncements = null;
    _cachedDismissedAnnouncements = null;
    _hydratedUserId = null;
  }

  /// Buluttaki okundu/silindi tercihlerini yerel diske aktarır (Reinstall dirilme kalkanı)
  Future<void> syncAnnouncementPreferencesFromCloud(String userId) async {
    if (userId.isEmpty || _hydratedUserId == userId) return;
    try {
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('notificationPreferences')
          .doc('main')
          .get();
      if (!doc.exists) {
        _hydratedUserId = userId;
        return;
      }
      final data = doc.data();
      if (data == null) {
        _hydratedUserId = userId;
        return;
      }

      final cloudRead = List<String>.from(data['readAnnouncementIds'] ?? []);
      final cloudDismissed = List<String>.from(data['dismissedAnnouncementIds'] ?? []);

      final prefs = await SharedPreferences.getInstance();
      bool changed = false;

      if (cloudRead.isNotEmpty) {
        final localRead = prefs.getStringList('read_announcements') ?? [];
        final mergedRead = {...localRead, ...cloudRead}.toList();
        if (mergedRead.length != localRead.length) {
          await prefs.setStringList('read_announcements', mergedRead);
          _cachedReadAnnouncements = mergedRead.toSet();
          changed = true;
        }
      }

      if (cloudDismissed.isNotEmpty) {
        final localDismissed = prefs.getStringList('dismissed_announcements') ?? [];
        final mergedDismissed = {...localDismissed, ...cloudDismissed}.toList();
        if (mergedDismissed.length != localDismissed.length) {
          await prefs.setStringList('dismissed_announcements', mergedDismissed);
          _cachedDismissedAnnouncements = mergedDismissed.toSet();
          changed = true;
        }
      }

      _hydratedUserId = userId;
      if (changed) {
        _announcementChangeController.add(null);
      }
    } catch (_) {}
  }

  Future<Set<String>> _getReadAnnouncements([String? userId]) async {
    if (_cachedReadAnnouncements != null) return _cachedReadAnnouncements!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('read_announcements') ?? [];
      _cachedReadAnnouncements = list.toSet();
      if (list.isEmpty && userId != null && userId.isNotEmpty && _hydratedUserId != userId) {
        unawaited(syncAnnouncementPreferencesFromCloud(userId));
      }
      return _cachedReadAnnouncements!;
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> _getDismissedAnnouncements([String? userId]) async {
    if (_cachedDismissedAnnouncements != null) return _cachedDismissedAnnouncements!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_announcements') ?? [];
      _cachedDismissedAnnouncements = list.toSet();
      if (list.isEmpty && userId != null && userId.isNotEmpty && _hydratedUserId != userId) {
        unawaited(syncAnnouncementPreferencesFromCloud(userId));
      }
      return _cachedDismissedAnnouncements!;
    } catch (_) {
      return {};
    }
  }

  // FS-02: Kişisel bildirimler ile küresel duyuruları birleştiren akış (Dual-Layer Feed)
  Stream<List<Map<String, dynamic>>> getUserNotificationsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? userSub;
    StreamSubscription? globalSub;
    StreamSubscription? changeSub;

    List<Map<String, dynamic>> latestUserNotifs = [];
    List<Map<String, dynamic>> latestGlobalNotifs = [];

    Future<void> emitMerged() async {
      if (controller.isClosed) return;
      try {
        final readSet = await _getReadAnnouncements(userId);
        final dismissedSet = await _getDismissedAnnouncements(userId);
        final now = DateTime.now();

        final filteredGlobals = latestGlobalNotifs.where((g) {
          final id = g['id'] as String? ?? '';
          final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
          if (dismissedSet.contains(id) || dismissedSet.contains(normalizedId)) return false;
          final expiresAt = g['expiresAt'] as DateTime?;
          if (expiresAt != null && expiresAt.isBefore(now)) return false;
          return true;
        }).map((g) {
          final copy = Map<String, dynamic>.from(g);
          final id = copy['id'] as String? ?? '';
          final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
          if (readSet.contains(id) || readSet.contains(normalizedId)) {
            copy['read'] = true;
          }
          return copy;
        }).toList();

        // Kişisel bildirimleri de dismissedSet ve readSet ile senkronize et
        final filteredUsers = latestUserNotifs.where((u) {
          final id = u['id'] as String? ?? '';
          final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
          final announcementId = u['announcementId'] as String? ?? '';
          if (dismissedSet.contains(id) ||
              dismissedSet.contains(normalizedId) ||
              (announcementId.isNotEmpty && (dismissedSet.contains(announcementId) || dismissedSet.contains('manual_$announcementId')))) {
            return false;
          }
          return true;
        }).map((u) {
          final copy = Map<String, dynamic>.from(u);
          final id = copy['id'] as String? ?? '';
          final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
          final announcementId = copy['announcementId'] as String? ?? '';
          if (readSet.contains(id) ||
              readSet.contains(normalizedId) ||
              (announcementId.isNotEmpty && (readSet.contains(announcementId) || readSet.contains('manual_$announcementId')))) {
            copy['read'] = true;
          }
          return copy;
        }).toList();

        // Tekrarlı ID'leri ele (hem globalAnnouncements hem kişisel doküman varsa)
        final seenIds = <String>{};
        final combined = <Map<String, dynamic>>[];

        for (final item in [...filteredGlobals, ...filteredUsers]) {
          final rawId = item['id'] as String? ?? '';
          final normalizedId = rawId.startsWith('manual_') ? rawId.substring(7) : rawId;
          final announcementId = item['announcementId'] as String? ?? normalizedId;
          final dedupKey = announcementId.isNotEmpty ? announcementId : rawId;

          if (dedupKey.isNotEmpty && !seenIds.add(dedupKey)) continue;
          combined.add(item);
        }

        combined.sort((a, b) {
          final dateA = (a['createdAt'] is DateTime) ? a['createdAt'] as DateTime : DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = (b['createdAt'] is DateTime) ? b['createdAt'] as DateTime : DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });

        if (!controller.isClosed) {
          controller.add(combined);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(latestUserNotifs);
        }
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        userSub = firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots()
            .listen((snapshot) {
          latestUserNotifs = snapshot.docs.map((doc) {
            final data = doc.data();
            DateTime createdAt = DateTime.now();
            if (data['createdAt'] is Timestamp) {
              createdAt = (data['createdAt'] as Timestamp).toDate();
            } else if (data['createdAt'] is String) {
              createdAt = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
            }

            final map = Map<String, dynamic>.from(data);
            map['id'] = doc.id;
            map['type'] = data['type'] ?? 'deal';
            map['dealId'] = data['dealId'] ?? '';
            map['dealTitle'] = data['dealTitle'] ?? '';
            map['commentId'] = data['commentId'] ?? '';
            map['kuponId'] = data['kuponId'] ?? data['targetId'] ?? '';
            map['title'] = data['title'] ?? 'Yeni Fırsat';
            map['body'] = data['body'] ?? '';
            map['reason'] = data['reason'] ?? '';
            map['reasonDetail'] = data['reasonDetail'] ?? '';
            map['read'] = data['read'] ?? false;
            map['createdAt'] = createdAt;

            final rawStatus = data['status']?.toString().trim().toLowerCase() ?? '';
            if (rawStatus.isNotEmpty) {
              map['status'] = rawStatus;
            } else {
              final titleLower = (data['title'] ?? '').toString().toLowerCase();
              if (titleLower.contains('onaylandı') || titleLower.contains('onaylandi')) {
                map['status'] = 'approved';
              } else if (titleLower.contains('reddedildi')) {
                map['status'] = 'rejected';
              } else {
                map['status'] = '';
              }
            }
            return map;
          }).toList();
          emitMerged();
        }, onError: (err) {
          if (!controller.isClosed) controller.addError(err);
        });

        globalSub = firestore
            .collection('globalAnnouncements')
            .where('active', isEqualTo: true)
            .limit(15)
            .snapshots()
            .listen((snapshot) {
          latestGlobalNotifs = snapshot.docs.map((doc) {
            final data = doc.data();
            DateTime createdAt = DateTime.now();
            if (data['createdAt'] is Timestamp) {
              createdAt = (data['createdAt'] as Timestamp).toDate();
            } else if (data['createdAt'] is String) {
              createdAt = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
            }

            DateTime? expiresAt;
            if (data['expiresAt'] is Timestamp) {
              expiresAt = (data['expiresAt'] as Timestamp).toDate();
            } else if (data['expiresAt'] is String) {
              expiresAt = DateTime.tryParse(data['expiresAt'] as String);
            }

            final map = Map<String, dynamic>.from(data);
            map['id'] = doc.id;
            map['type'] = data['type'] ?? 'admin_message';
            map['dealId'] = data['dealId'] ?? '';
            map['kuponId'] = data['kuponId'] ?? data['targetId'] ?? '';
            map['title'] = data['title'] ?? 'Resmi Duyuru';
            map['body'] = data['body'] ?? '';
            map['imageUrl'] = data['imageUrl'] ?? '';
            map['reason'] = data['reason'] ?? 'admin_message';
            map['read'] = false;
            map['createdAt'] = createdAt;
            map['expiresAt'] = expiresAt;
            map['isGlobalAnnouncement'] = true;
            return map;
          }).toList();
          emitMerged();
        }, onError: (_) {
          emitMerged();
        });

        changeSub = _announcementChangeController.stream.listen((_) {
          emitMerged();
        });
      },
      onCancel: () async {
        await userSub?.cancel();
        await globalSub?.cancel();
        await changeSub?.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  /// FS-PREF-02: 100k DAU İçin Ultra Hafif Okunmamış Bildirim Sayacı Akışı (HomeScreen Zil Rozeti İçin)
  /// 100+15 dokümanlık ağır feed indirmesi yerine sadece okunmamış kişisel bildirimleri (limit 20)
  /// ve aktif küresel duyuruları hafifçe denetleyerek rozet sayısını döner.
  /// FS-02 Dedup Kalkanı: Hem kişisel hem küresel duyurusu olan bildirimleri tek sayar; hayalet rozetleri engeller.
  Stream<int> getUnreadNotificationCountStream(String userId) {
    if (userId.isEmpty) return Stream.value(0);

    late StreamController<int> controller;
    StreamSubscription? userSub;
    StreamSubscription? globalSub;
    StreamSubscription? changeSub;

    List<Map<String, dynamic>> unreadPersonalDocs = [];
    List<String> activeGlobalIds = [];

    Future<void> emitCount() async {
      if (controller.isClosed) return;
      try {
        final readSet = await _getReadAnnouncements(userId);
        final dismissedSet = await _getDismissedAnnouncements(userId);

        // 1. Kişisel bildirimleri oku/gizle durumuna göre filtrele ve dedup anahtarlarını topla
        final personalDedupKeys = <String>{};
        int validPersonalCount = 0;

        for (final doc in unreadPersonalDocs) {
          final id = doc['id'] as String? ?? '';
          final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
          final announcementId = doc['announcementId'] as String? ?? '';

          // Eğer bu kişisel doküman küresel bir duyurunun kopyasıysa ve okunmuş/gizlenmişse sayma
          if (dismissedSet.contains(id) ||
              dismissedSet.contains(normalizedId) ||
              (announcementId.isNotEmpty &&
                  (dismissedSet.contains(announcementId) ||
                      dismissedSet.contains('manual_$announcementId')))) {
            continue;
          }
          if (readSet.contains(id) ||
              readSet.contains(normalizedId) ||
              (announcementId.isNotEmpty &&
                  (readSet.contains(announcementId) ||
                      readSet.contains('manual_$announcementId')))) {
            continue;
          }

          final dedupKey = announcementId.isNotEmpty ? announcementId : (normalizedId.isNotEmpty ? normalizedId : id);
          if (dedupKey.isNotEmpty) {
            personalDedupKeys.add(dedupKey);
            personalDedupKeys.add(id);
            personalDedupKeys.add(normalizedId);
          }
          validPersonalCount++;
        }

        // 2. Küresel duyuruları say: Hem okunmuş/gizlenmişleri ele, HEM DE kişisel dokümanlarda zaten olanları ele (FS-02 Dedup)
        int validGlobalCount = 0;
        for (final id in activeGlobalIds) {
          final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
          if (dismissedSet.contains(id) || dismissedSet.contains(normalizedId)) continue;
          if (readSet.contains(id) || readSet.contains(normalizedId)) continue;
          if (personalDedupKeys.contains(id) || personalDedupKeys.contains(normalizedId)) {
            // Zaten kişisel okunmamış bildirim olarak sayıldı, mükerrer sayımı önle!
            continue;
          }
          validGlobalCount++;
        }

        final total = validPersonalCount + validGlobalCount;
        if (!controller.isClosed) {
          controller.add(total);
        }
      } catch (_) {
        if (!controller.isClosed) {
          controller.add(unreadPersonalDocs.length);
        }
      }
    }

    controller = StreamController<int>(
      onListen: () {
        // Sadece okunmamış kişisel bildirimleri dinle (maksimum 20 doküman)
        userSub = firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .limit(20)
            .snapshots()
            .listen((snapshot) {
          unreadPersonalDocs = snapshot.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'announcementId': data['announcementId'] as String? ?? '',
            };
          }).toList();
          emitCount();
        }, onError: (_) => emitCount());

        // Küresel duyuruları hafifçe dinle (maksimum 5 doküman)
        globalSub = firestore
            .collection('globalAnnouncements')
            .where('active', isEqualTo: true)
            .limit(5)
            .snapshots()
            .listen((snapshot) {
          activeGlobalIds = snapshot.docs.map((d) => d.id).toList();
          emitCount();
        }, onError: (_) => emitCount());

        changeSub = _announcementChangeController.stream.listen((_) {
          emitCount();
        });
      },
      onCancel: () async {
        await userSub?.cancel();
        await globalSub?.cancel();
        await changeSub?.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    final rawId = notificationId.trim();
    if (rawId.isEmpty || userId.isEmpty) return;
    final normalizedId = rawId.startsWith('manual_') ? rawId.substring(7) : rawId;

    // Evrensel ID Çözücü: Hem ham ID, hem normalizedId, hem de userId uzantılı varyasyonları topla
    final targetDocIds = <String>{rawId, normalizedId};
    if (rawId.endsWith('_$userId')) {
      final baseAnnouncementId = rawId.substring(0, rawId.length - userId.length - 1);
      if (baseAnnouncementId.isNotEmpty) {
        targetDocIds.add(baseAnnouncementId);
      }
    } else {
      targetDocIds.add('${rawId}_$userId');
      targetDocIds.add('${normalizedId}_$userId');
    }

    // 1. SharedPreferences ve Statik Bellek Cache'e ekle (0-maliyet reaktif akış)
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('read_announcements') ?? [];
      bool changed = false;
      for (final id in targetDocIds) {
        if (!list.contains(id)) {
          list.add(id);
          changed = true;
        }
        _cachedReadAnnouncements?.add(id);
      }
      if (changed) {
        await prefs.setStringList('read_announcements', list);
      }
      _announcementChangeController.add(null);
    } catch (_) {}

    // 2. Kalıcı Bulut Senkronizasyonu (Reinstall dirilme kalkanı)
    try {
      final announcementTargets = targetDocIds
          .where((id) => id.startsWith('coupon_') || id.startsWith('manual_') || id.startsWith('log_') || !id.contains('_$userId'))
          .toList();
      if (announcementTargets.isNotEmpty) {
        firestore
            .collection('users')
            .doc(userId)
            .collection('notificationPreferences')
            .doc('main')
            .set({
          'readAnnouncementIds': FieldValue.arrayUnion(announcementTargets),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      }
    } catch (_) {}

    // 3. Kişisel bildirim dokümanlarını Firestore'da paralel güncelle
    try {
      await Future.wait(
        targetDocIds.map((docId) => firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(docId)
            .update({'read': true})
            .catchError((_) {})),
      );
    } catch (_) {}

    // 4. announcementId veya kuponId üzerinden eşleşen kişisel dokümanları güncelle
    try {
      final querySnap = await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('announcementId', isEqualTo: rawId)
          .where('read', isEqualTo: false)
          .limit(5)
          .get();
      if (querySnap.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final d in querySnap.docs) {
          batch.update(d.reference, {'read': true});
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    if (userId.isEmpty) return;
    // 1. Aktif duyuruları yerel okundu listesine ve statik cache'e ekle
    final announcementIdsToAdd = <String>[];
    try {
      final globalSnap = await firestore
          .collection('globalAnnouncements')
          .where('active', isEqualTo: true)
          .limit(30)
          .get();
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('read_announcements') ?? [];
      for (final doc in globalSnap.docs) {
        final id = doc.id;
        final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
        if (!list.contains(id)) list.add(id);
        if (!list.contains(normalizedId)) list.add(normalizedId);
        announcementIdsToAdd.add(id);
        announcementIdsToAdd.add(normalizedId);
        _cachedReadAnnouncements?.add(id);
        _cachedReadAnnouncements?.add(normalizedId);
      }
      await prefs.setStringList('read_announcements', list);
      _announcementChangeController.add(null);
    } catch (_) {}

    // Bulut senkronizasyonu
    if (announcementIdsToAdd.isNotEmpty) {
      try {
        firestore
            .collection('users')
            .doc(userId)
            .collection('notificationPreferences')
            .doc('main')
            .set({
          'readAnnouncementIds': FieldValue.arrayUnion(announcementIdsToAdd),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      } catch (_) {}
    }

    // 2. FS-PREF-10 & FS-PREF-16: Kişisel okunmamış bildirimleri sayfalı (while loop) tüketerek tümünü okundu yap
    while (true) {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .limit(400)
          .get();

      if (snapshot.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      if (snapshot.docs.length < 400) break;
    }

    // FS-PREF-13: Tüm bildirimler okundu işaretlendiğinde uygulama rozetini de sıfırla
    try {
      await AppBadgeService.instance.clearBadge();
    } catch (_) {}
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    final rawId = notificationId.trim();
    if (rawId.isEmpty || userId.isEmpty) return;
    final normalizedId = rawId.startsWith('manual_') ? rawId.substring(7) : rawId;

    // Evrensel ID Çözücü
    final targetDocIds = <String>{rawId, normalizedId};
    if (rawId.endsWith('_$userId')) {
      final baseAnnouncementId = rawId.substring(0, rawId.length - userId.length - 1);
      if (baseAnnouncementId.isNotEmpty) {
        targetDocIds.add(baseAnnouncementId);
      }
    } else {
      targetDocIds.add('${rawId}_$userId');
      targetDocIds.add('${normalizedId}_$userId');
    }

    // 1. SharedPreferences ve Statik Cache'e ekle
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_announcements') ?? [];
      bool changed = false;
      for (final id in targetDocIds) {
        if (!list.contains(id)) {
          list.add(id);
          changed = true;
        }
        _cachedDismissedAnnouncements?.add(id);
      }
      if (changed) {
        await prefs.setStringList('dismissed_announcements', list);
      }
      _announcementChangeController.add(null);
    } catch (_) {}

    // 2. Kalıcı Bulut Senkronizasyonu (Reinstall dirilme kalkanı)
    try {
      final announcementTargets = targetDocIds
          .where((id) => id.startsWith('coupon_') || id.startsWith('manual_') || id.startsWith('log_') || !id.contains('_$userId'))
          .toList();
      if (announcementTargets.isNotEmpty) {
        firestore
            .collection('users')
            .doc(userId)
            .collection('notificationPreferences')
            .doc('main')
            .set({
          'dismissedAnnouncementIds': FieldValue.arrayUnion(announcementTargets),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      }
    } catch (_) {}

    // 3. Kişisel bildirim dokümanlarını paralel sil
    try {
      await Future.wait(
        targetDocIds.map((docId) => firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(docId)
            .delete()
            .catchError((_) {})),
      );
    } catch (_) {}

    // 4. announcementId üzerinden eşleşen kişisel dokümanları da sil
    try {
      final querySnap = await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('announcementId', isEqualTo: rawId)
          .limit(5)
          .get();
      if (querySnap.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final d in querySnap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}

    // 5. Eğer admin ise ve küresel duyuru siliniyorsa (örn: kupon duyurusu), küresel koleksiyondan da temizlemeyi dene
    if (rawId.startsWith('coupon_')) {
      try {
        firestore.collection('globalAnnouncements').doc(rawId).delete().catchError((_) {});
      } catch (_) {}
    }
  }

  Future<void> deleteAllNotifications(String userId) async {
    if (userId.isEmpty) return;
    // 1. Aktif duyuruları yerel gizlenen listesine ve statik cache'e ekle
    final announcementIdsToAdd = <String>[];
    try {
      final globalSnap = await firestore
          .collection('globalAnnouncements')
          .where('active', isEqualTo: true)
          .limit(30)
          .get();
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_announcements') ?? [];
      for (final doc in globalSnap.docs) {
        final id = doc.id;
        final normalizedId = id.startsWith('manual_') ? id.substring(7) : id;
        if (!list.contains(id)) list.add(id);
        if (!list.contains(normalizedId)) list.add(normalizedId);
        announcementIdsToAdd.add(id);
        announcementIdsToAdd.add(normalizedId);
        _cachedDismissedAnnouncements?.add(id);
        _cachedDismissedAnnouncements?.add(normalizedId);
      }
      await prefs.setStringList('dismissed_announcements', list);
      _announcementChangeController.add(null);
    } catch (_) {}

    // Bulut senkronizasyonu
    if (announcementIdsToAdd.isNotEmpty) {
      try {
        firestore
            .collection('users')
            .doc(userId)
            .collection('notificationPreferences')
            .doc('main')
            .set({
          'dismissedAnnouncementIds': FieldValue.arrayUnion(announcementIdsToAdd),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      } catch (_) {}
    }

    // 2. FS-PREF-10 & FS-PREF-16: Kişisel bildirimleri sayfalı (while loop) tüketerek tümünü sil
    while (true) {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .limit(400)
          .get();

      if (snapshot.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 400) break;
    }

    // FS-PREF-13: Tüm bildirimler silindiğinde uygulama rozetini de sıfırla
    try {
      await AppBadgeService.instance.clearBadge();
    } catch (_) {}
  }

  // ===========================================================================
  // AYARLAR VE DİĞERLERİ (DealService içinde)
  // ===========================================================================
  Future<bool> isDealSharingEnabled() => _dealService.isDealSharingEnabled();
  Future<bool> setDealSharingEnabled(bool enabled) => _dealService.setDealSharingEnabled(enabled);
  Stream<bool> dealSharingEnabledStream() => firestore.collection('settings').doc('app').snapshots().map((s) => s.data()?['dealSharingEnabled'] ?? true);
  Stream<bool> couponsEnabledStream() => firestore.collection('settings').doc('app').snapshots().map((s) => s.data()?['couponsEnabled'] ?? true);
  
  Stream<List<Deal>> getTestDealsStream() => _dealService.getTestDealsStream();
  Future<bool> deleteDealsBatch(List<String> dealIds) => _dealService.deleteDealsBatch(dealIds);
  
  Future<bool> isCommentSharingEnabled() async {
    try {
      final doc = await firestore.collection('settings').doc('app').get();
      return doc.data()?['commentSharingEnabled'] ?? true;
    } catch (e) { return true; }
  }

  Future<bool> isBotkolikChatEnabled() async {
    try {
      final doc = await firestore.collection('settings').doc('app').get();
      return doc.data()?['botkolikChatEnabled'] ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<bool> setBotkolikChatEnabled(bool enabled) async {
    try {
      await firestore.collection('settings').doc('app').set({
        'botkolikChatEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<bool> botkolikChatEnabledStream() => firestore
      .collection('settings')
      .doc('app')
      .snapshots()
      .map((s) => s.data()?['botkolikChatEnabled'] ?? true);

  void _log(String msg) {
    if (kDebugMode) {
      print('[FirestoreService] $msg');
    }
  }
}
