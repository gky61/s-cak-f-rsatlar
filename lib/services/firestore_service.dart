import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import '../models/deal.dart';
import '../models/comment.dart';
import '../models/message.dart';
import '../models/admin_to_user_message.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'deal_service.dart';
import 'user_service.dart';
import 'message_service.dart';
import 'comment_service.dart';

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

  // Raporlar koleksiyonu
  CollectionReference get reportsCollection => firestore.collection('reports');

  // ===========================================================================
  // DEAL İŞLEMLERİ (DealService üzerinden)
  // ===========================================================================
  
  Stream<DealsSnapshot> getDealsStream() => _dealService.getDealsStream();
  
  Future<List<Deal>> getDealsPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? category,
    String? subCategory,
  }) => _dealService.getDealsPaginated(
    limit: limit,
    lastDocument: lastDocument,
    category: category,
    subCategory: subCategory,
  );

  Future<List<Deal>> getInitialDeals({int limit = 20}) => getDealsPaginated(limit: limit);
  
  Stream<List<Deal>> getAllDealsStream() => _dealService.getApprovedDealsStream(); // İsim uyumluluğu için
  
  Stream<List<Deal>> getExpiredDealsStream() => _dealService.getExpiredDealsStream();
  
  Stream<List<Deal>> getPendingDealsStream() => _dealService.getPendingDealsStream();
  
  Stream<List<Deal>> getUserSubmittedPendingDealsStream() => _dealService.getUserSubmittedPendingDealsStream();
  
  Stream<List<Deal>> getApprovedDealsStream() => _dealService.getApprovedDealsStream();
  
  Future<Deal?> getDeal(String dealId) => _dealService.getDeal(dealId);
  
  Future<String?> addDeal(Deal deal) async {
    // Legacy support: createDeal tercih edilmeli
    final docRef = await firestore.collection('deals').add(deal.toFirestore());
      return docRef.id;
  }

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
    String? priceLabel,
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
        priceLabel: priceLabel,
      );

  Future<bool> updateDeal(String dealId, Map<String, dynamic> updates) => _dealService.updateDeal(dealId, updates);
  
  Future<bool> deleteDeal(String dealId) => _dealService.deleteDeal(dealId);
  
  Future<bool> markDealAsExpired(String dealId) => _dealService.markDealAsExpired(dealId);
  
  Future<bool> unexpireDeal(String dealId) => _dealService.unexpireDeal(dealId);
  
  Future<void> deleteOldDeals() async {
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 180));
      final snapshot = await firestore.collection('deals')
          .where('isApproved', isEqualTo: true)
          .get();
      
      final batch = firestore.batch();
      for (var doc in snapshot.docs) {
        final created = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (created != null && created.isBefore(cutoff)) {
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) print('Temizlik hatası: $e');
    }
  }

  Future<void> deleteUnapprovedDealsAfter24Hours() async {
    // Benzer mantık...
  }

  Future<void> cleanupExpiredDeals() async {
    // DealService tarafında implemente edilebilir veya burada kalabilir.
  }

  Stream<List<Deal>> getUserDealsStream(String userId, {int? limit}) {
    return firestore.collection('deals')
        .where('postedBy', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => Deal.fromFirestore(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (limit != null) {
            return list.take(limit).toList();
          }
          return list;
        });
  }

  Stream<List<Deal>> getUserLastDealsStream(String userId, {int limit = 5}) {
    return firestore.collection('users').doc(userId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return [];
      
      final data = doc.data();
      final List<dynamic> rawList = data?['sonPaylasilanFirsatlar'] ?? [];
      
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));
      List<Deal> deals = [];
      
      for (var item in rawList) {
        if (item is! Map) continue;
        final dealId = item['firsatId']?.toString() ?? '';
        if (dealId.isEmpty) continue;
        
        final title = item['baslik']?.toString() ?? '';
        final priceStr = item['fiyat']?.toString() ?? '0';
        final price = double.tryParse(priceStr) ?? 0.0;
        final store = item['magazaAdi']?.toString() ?? '';
        final link = item['link']?.toString() ?? '';
        final paylasilmaTarihiTimestamp = item['paylasilmaTarihi'] as Timestamp?;
        final paylasilmaTarihi = paylasilmaTarihiTimestamp?.toDate() ?? now;
        final isOld = paylasilmaTarihi.isBefore(cutoffTime);
        
        final dealDoc = await firestore.collection('deals').doc(dealId).get();
        if (dealDoc.exists) {
          final deal = Deal.fromFirestore(dealDoc);
          if (isOld || deal.isExpired || deal.createdAt.isBefore(cutoffTime)) {
            deals.add(Deal(
              id: deal.id,
              title: deal.title,
              description: deal.description,
              price: deal.price,
              originalPrice: deal.originalPrice,
              discountRate: deal.discountRate,
              store: deal.store,
              category: deal.category,
              subCategory: deal.subCategory,
              link: deal.link,
              imageUrl: deal.imageUrl,
              hotVotes: deal.hotVotes,
              coldVotes: deal.coldVotes,
              expiredVotes: deal.expiredVotes,
              commentCount: deal.commentCount,
              postedBy: deal.postedBy,
              createdAt: deal.createdAt,
              isEditorPick: deal.isEditorPick,
              isApproved: deal.isApproved,
              isExpired: true,
              isUserSubmitted: deal.isUserSubmitted,
            ));
          } else {
            deals.add(deal);
          }
        } else {
          deals.add(Deal(
            id: dealId,
            title: title,
            description: 'Bu fırsatın süresi dolmuştur.',
            price: price,
            store: store,
            category: 'tumu',
            link: link,
            imageUrl: '',
            hotVotes: 0,
            coldVotes: 0,
            commentCount: 0,
            postedBy: '',
            createdAt: paylasilmaTarihi,
            isEditorPick: false,
            isApproved: true,
            isExpired: true,
            isUserSubmitted: false,
          ));
        }
      }
      return deals.take(limit).toList();
    });
  }

  Stream<List<Deal>> getMostLikedDeals({int minLikes = 25}) {
    return firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(days: 30)); // 30-day time window for popular deals
      
      final deals = snapshot.docs
          .map((doc) {
            try {
              return Deal.fromFirestore(doc);
            } catch (e) {
              return null;
            }
          })
          .where((deal) =>
              deal != null &&
              deal.isTest != true &&
              deal.isExpired != true &&
              deal.hotVotes >= minLikes &&
              !deal.createdAt.isBefore(cutoffTime))
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.hotVotes.compareTo(a.hotVotes));
      return deals.take(50).toList();
    });
  }

  Stream<List<Deal>> getFollowedCategoriesDeals(String userId) {
    late StreamController<List<Deal>> controller;
    
    StreamSubscription? subSubscription;
    StreamSubscription? dealsSubscription;
    
    List<String> followedCategories = [];
    List<Deal> approvedDeals = [];
    
    void updateList() {
      if (controller.isClosed) return;
      if (followedCategories.isEmpty) {
        controller.add([]);
        return;
      }
      final filtered = approvedDeals.where((d) => followedCategories.contains(d.category)).toList();
      controller.add(filtered);
    }
    
    controller = StreamController<List<Deal>>.broadcast(
      onListen: () {
        subSubscription = firestore
            .collection('notificationSubscriptions')
            .where('uid', isEqualTo: userId)
            .where('type', isEqualTo: 'category')
            .where('enabled', isEqualTo: true)
            .snapshots()
            .listen((snapshot) {
          followedCategories = snapshot.docs
              .map((doc) => doc.data()['key'] as String? ?? '')
              .where((key) => key.isNotEmpty && !key.contains(':'))
              .toList();
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
          final cutoffTime = now.subtract(const Duration(days: 30)); // 30-day time window for category deals
          
          return snapshot.docs
              .map((doc) {
                try {
                  return Deal.fromFirestore(doc);
                } catch (e) {
                  return null;
                }
              })
              .where((deal) =>
                  deal != null &&
                  deal.isTest != true &&
                  deal.isExpired != true &&
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
  Future<bool> addHotVote(String dealId, String userId) => _dealService.addHotVote(dealId, userId);
  Future<bool> addColdVote(String dealId, String userId) => _dealService.addColdVote(dealId, userId);
  Future<bool> addExpiredVote(String dealId, String userId) => _dealService.addExpiredVote(dealId, userId);
  Future<bool> removeVote(String dealId, String userId) => _dealService.removeVote(dealId, userId);
  Future<bool> removeHotVote(String dealId, String userId) => _dealService.removeVote(dealId, userId);
  Future<bool> removeColdVote(String dealId, String userId) => _dealService.removeVote(dealId, userId);
  Future<bool> removeExpiredVote(String dealId, String userId) => _dealService.removeVote(dealId, userId);
      
  // ===========================================================================
  // KULLANICI İŞLEMLERİ (UserService üzerinden)
  // ===========================================================================

  Future<bool> isFavorite(String userId, String dealId) => _userService.isFavorite(userId, dealId);
  Future<bool> addToFavorites(String userId, String dealId, {String? title, double? price, String? store, String? link}) =>
      _userService.addToFavorites(userId, dealId, title: title, price: price, store: store, link: link);
  Future<bool> removeFromFavorites(String userId, String dealId) => _userService.removeFromFavorites(userId, dealId);
  Stream<List<Deal>> getFavoriteDeals(String userId) => _userService.getFavoriteDeals(userId);
  Future<void> addLastSharedDeal(String userId, {required String dealId, required String title, required double price, required String store, required String link}) =>
      _userService.addLastSharedDeal(userId, dealId: dealId, title: title, price: price, store: store, link: link);
  
  Future<void> followUser(String followerId, String followingId) => _userService.followUser(followerId, followingId);
  Future<void> unfollowUser(String followerId, String followingId) => _userService.unfollowUser(followerId, followingId);
  Future<bool> isFollowing(String followerId, String followingId) => _userService.isFollowing(followerId, followingId);
  Stream<List<AppUser>> getFollowingUsersStream(String userId) => _userService.getFollowingUsersStream(userId);
  Future<bool> isFollowNotificationEnabled(String followerId, String followingId) => _userService.isFollowNotificationEnabled(followerId, followingId);
  Future<void> toggleFollowNotification(String followerId, String followingId, bool enable) => _userService.toggleFollowNotification(followerId, followingId, enable);
  
  Future<List<String>> getUserWatchKeywords(String userId) => _userService.getUserWatchKeywords(userId);
  Future<void> addWatchKeyword(String userId, String keyword) => _userService.addWatchKeyword(userId, keyword);
  Future<void> removeWatchKeyword(String userId, String keyword) => _userService.removeWatchKeyword(userId, keyword);
  
  Future<bool> isUserBlocked(String userId) => _userService.isUserBlocked(userId);
  Future<bool> blockUser(String userId) => _userService.blockUser(userId);

  // ===========================================================================
  // MESAJLAŞMA İŞLEMLERİ (MessageService üzerinden)
  // ===========================================================================

  Future<String?> sendMessage({required String senderId, required String receiverId, required String text}) =>
      _messageService.sendMessage(senderId: senderId, receiverId: receiverId, text: text);
      
  Stream<List<Message>> getUserMessagesStream(String userId) {
    late StreamController<List<Message>> controller;
    StreamSubscription? senderSub;
    StreamSubscription? receiverSub;

    controller = StreamController<List<Message>>(
      onListen: () {
        List<Message> s = [], r = [];
        void emit() {
          if (!controller.isClosed) {
            final all = [...s, ...r]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            controller.add(all);
          }
        }

        senderSub = firestore
            .collection('messages')
            .where('senderId', isEqualTo: userId)
            .snapshots()
            .listen(
          (snap) {
            s = snap.docs.map((d) => Message.fromFirestore(d)).toList();
            emit();
          },
          onError: (error) {
            if (error.toString().contains('permission-denied')) {
              _log('ℹ️ senderStream çıkış sırasında kapandı (beklenen)');
            } else {
              _log('⚠️ senderStream error: $error');
            }
          },
        );

        receiverSub = firestore
            .collection('messages')
            .where('receiverId', isEqualTo: userId)
            .snapshots()
            .listen(
          (snap) {
            r = snap.docs.map((d) => Message.fromFirestore(d)).toList();
            emit();
          },
          onError: (error) {
            if (error.toString().contains('permission-denied')) {
              _log('ℹ️ receiverStream çıkış sırasında kapandı (beklenen)');
            } else {
              _log('⚠️ receiverStream error: $error');
            }
          },
        );
      },
      onCancel: () {
        senderSub?.cancel();
        receiverSub?.cancel();
      },
    );

    return controller.stream;
  }
  
  Stream<List<Message>> getConversationStream(String u1, String u2) => _messageService.getConversationStream(u1, u2);
  Future<void> markMessageAsRead(String id) => _messageService.markMessageAsRead(id);
  Stream<List<Message>> getAllMessagesStream() => _messageService.getAllMessagesStream();
  Future<void> markMessageAsReadByAdmin(String id) => _messageService.markMessageAsReadByAdmin(id);
  Future<int> deleteAllMessages() => _messageService.deleteAllMessages();
  Future<void> deleteUserMessage(String id) => _messageService.deleteUserMessage(id);
  Future<int> getUnreadMessageCount(String uid) => _messageService.getUnreadMessageCount(uid);
  
  Stream<List<AdminToUserMessage>> getAdminToUserMessagesStream(String uid, {int limit = 200}) => 
      _messageService.getAdminToUserMessagesStream(uid, limit: limit);
  Future<int> getUnreadAdminToUserMessageCount(String uid) => _messageService.getUnreadAdminToUserMessageCount(uid);
  Future<void> markAdminToUserMessageAsRead(String id) => _messageService.markAdminToUserMessageAsRead(id);
  Future<void> deleteAdminToUserMessage(String id) => _messageService.deleteAdminToUserMessage(id);
  Future<int> deleteAllAdminToUserMessages(String userId) async {
    final batch = firestore.batch();
    final snap = await firestore.collection('adminToUserMessages').where('userId', isEqualTo: userId).get();
    for (var doc in snap.docs) batch.delete(doc.reference);
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
  );

  Stream<List<Comment>> getCommentsStream(String dealId) => _commentService.getCommentsStream(dealId);
  Future<bool> deleteComment(String commentId, String dealId) => _commentService.deleteComment(commentId, dealId);
  
  Stream<List<Map<String, dynamic>>> getCommentReplyNotificationsStream(String userId) => 
      _commentService.getCommentReplyNotificationsStream(userId);
  Future<void> markCommentReplyNotificationAsRead(String userId, String notificationId) => 
      _commentService.markCommentReplyNotificationAsRead(userId, notificationId);
  Future<void> deleteCommentReplyNotification(String userId, String notificationId) => 
      _commentService.deleteCommentReplyNotification(userId, notificationId);
  Future<int> deleteAllCommentReplyNotifications(String userId) => 
      _commentService.deleteAllCommentReplyNotifications(userId);

  // Unified Notification Center Methods
  Stream<List<Map<String, dynamic>>> getUserNotificationsStream(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        DateTime createdAt = DateTime.now();
        if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is String) {
          createdAt = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
        }
        return {
          'id': doc.id,
          'type': data['type'] ?? 'deal',
          'dealId': data['dealId'] ?? '',
          'dealTitle': data['dealTitle'] ?? '',
          'commentId': data['commentId'] ?? '',
          'title': data['title'] ?? 'Yeni Fırsat',
          'body': data['body'] ?? '',
          'reason': data['reason'] ?? '',
          'reasonDetail': data['reasonDetail'] ?? '',
          'read': data['read'] ?? false,
          'createdAt': createdAt,
        };
      }).toList();
    });
  }

  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllNotifications(String userId) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .get();
    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
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

  void _log(String msg) {
    if (kDebugMode) {
      print('[FirestoreService] $msg');
    }
  }
}
