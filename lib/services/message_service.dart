import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:sicak_firsatlar/utils/asset_path_migration.dart';
import '../models/message.dart';
import '../models/admin_to_user_message.dart';
import '../models/conversation.dart';
import 'system_log_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class _CachedUserProfile {
  final String name;
  final String imageUrl;
  final List<String> blockedUsers;
  final DateTime cachedAt;

  _CachedUserProfile({
    required this.name,
    required this.imageUrl,
    this.blockedUsers = const [],
    required this.cachedAt,
  });

  bool get isExpired => DateTime.now().difference(cachedAt) > const Duration(minutes: 10);
}

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // FS-21: Mesajlaşma sırasında her mesajda N+1 Firestore user okumasını önleyen in-memory profil önbelleği
  static final Map<String, _CachedUserProfile> _profileCache = {};

  static String getConversationId(String u1, String u2) {
    final list = [u1, u2]..sort();
    return '${list[0]}_${list[1]}';
  }

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
  }) async {
    try {
      String senderName = 'Kullanıcı';
      String senderImageUrl = '';
      if (senderId == 'botkolik') {
        senderName = 'Botkolik';
        senderImageUrl = 'assets/botkolik.webp';
      } else if (senderId == 'admin') {
        senderName = 'FırsatKolik Yönetim';
        senderImageUrl = 'assets/logo.webp';
      } else if (senderId == 'test_user_ahmet') {
        senderName = 'Ahmet Yılmaz (Test)';
      } else if (senderId == 'test_user_zeynep') {
        senderName = 'Zeynep Kaya (Test)';
        senderImageUrl = 'assets/avatars/avatar_duck.webp';
      } else {
        // FS-21: Gönderen mevcut oturum kullanıcısı ise profil FirebaseAuth bellek önbelleğinden doğrudan alınır (0 okuma)
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null && fbUser.uid == senderId && fbUser.displayName != null && fbUser.displayName!.trim().isNotEmpty) {
          senderName = fbUser.displayName!.trim();
          senderImageUrl = migrateAssetPath(fbUser.photoURL ?? '');
        } else if (_profileCache.containsKey(senderId) && !_profileCache[senderId]!.isExpired) {
          final cached = _profileCache[senderId]!;
          senderName = cached.name;
          senderImageUrl = cached.imageUrl;
        } else {
          final senderDoc = await _firestore.collection('users').doc(senderId).get();
          if (!senderDoc.exists) return null;
          final sData = senderDoc.data();
          senderName = sData?['username'] ?? sData?['displayName'] ?? sData?['nickname'] ?? 'Kullanıcı';
          senderImageUrl = migrateAssetPath((sData?['profileImageUrl'] ?? sData?['photoURL'] ?? '').toString());
          _profileCache[senderId] = _CachedUserProfile(
            name: senderName,
            imageUrl: senderImageUrl,
            cachedAt: DateTime.now(),
          );
        }
      }

      String receiverName = 'Kullanıcı';
      String receiverImageUrl = '';
      if (receiverId == 'botkolik') {
        receiverName = 'Botkolik';
        receiverImageUrl = 'assets/botkolik.webp';
      } else if (receiverId == 'admin') {
        receiverName = 'FırsatKolik Yönetim';
        receiverImageUrl = 'assets/logo.webp';
      } else if (receiverId == 'test_user_ahmet') {
        receiverName = 'Ahmet Yılmaz (Test)';
      } else if (receiverId == 'test_user_zeynep') {
        receiverName = 'Zeynep Kaya (Test)';
        receiverImageUrl = 'assets/avatars/avatar_duck.webp';
      } else {
        // FS-21: Alıcı profili ve engelleme listesi 10 dakikalık in-memory önbellekle korunur
        if (_profileCache.containsKey(receiverId) && !_profileCache[receiverId]!.isExpired) {
          final cached = _profileCache[receiverId]!;
          if (cached.blockedUsers.contains(senderId)) {
            _log('🚫 Alıcı bu kullanıcıyı engellediği için mesaj iletilmedi.');
            return null;
          }
          receiverName = cached.name;
          receiverImageUrl = cached.imageUrl;
        } else {
          final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
          if (!receiverDoc.exists) return null;
          final rData = receiverDoc.data();
          final receiverBlockedList = List<String>.from(rData?['blockedUsers'] ?? []);
          if (receiverBlockedList.contains(senderId)) {
            _log('🚫 Alıcı bu kullanıcıyı engellediği için mesaj iletilmedi.');
            return null;
          }
          receiverName = rData?['username'] ?? rData?['displayName'] ?? rData?['nickname'] ?? 'Kullanıcı';
          receiverImageUrl = migrateAssetPath((rData?['profileImageUrl'] ?? rData?['photoURL'] ?? '').toString());
          _profileCache[receiverId] = _CachedUserProfile(
            name: receiverName,
            imageUrl: receiverImageUrl,
            blockedUsers: receiverBlockedList,
            cachedAt: DateTime.now(),
          );
        }
      }

      final convId = getConversationId(senderId, receiverId);
      final message = Message(
        id: '',
        conversationId: convId,
        participants: [senderId, receiverId],
        senderId: senderId,
        senderName: senderName,
        senderImageUrl: senderImageUrl,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverImageUrl: receiverImageUrl,
        text: text.trim(),
        createdAt: DateTime.now(),
        isRead: false,
        isReadByAdmin: false,
        dealId: dealId,
        dealTitle: dealTitle,
        dealImageUrl: dealImageUrl != null ? migrateAssetPath(dealImageUrl) : null,
        dealPrice: dealPrice,
        dealStore: dealStore,
        replyToMessageId: replyToMessageId,
        replyToSenderName: replyToSenderName,
        replyToText: replyToText,
      );

      final docRef = await _firestore.collection('messages').add(message.toFirestore());

      // FS-MSG-01: Üst seviye conversations dokümanını anlık güncelle (0 kayıp ve hızlı gelen kutusu senkronizasyonu)
      final convRef = _firestore.collection('conversations').doc(convId);
      convRef.set({
        'id': convId,
        'participants': [senderId, receiverId],
        'lastMessage': {
          'text': text.trim(),
          'senderId': senderId,
          'senderName': senderName,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          if (dealId != null) 'dealId': dealId,
          if (dealTitle != null) 'dealTitle': dealTitle,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts': {
          receiverId: FieldValue.increment(1),
          senderId: 0,
        },
        'participantDetails': {
          senderId: {
            'name': senderName,
            'avatar': senderImageUrl,
            'isDeleted': false,
          },
          receiverId: {
            'name': receiverName,
            'avatar': receiverImageUrl,
            'isDeleted': false,
          },
        },
      }, SetOptions(merge: true)).catchError((e) {
        _log('⚠️ conversations metadata güncelleme uyarısı: $e');
      });

      return docRef.id;
    } catch (e, stack) {
      _log('Mesaj gönderme hatası: $e');
      SystemLogService.instance.logError(
        category: 'message',
        errorType: 'SendMessageException',
        message: 'Mesaj gönderilemedi: $e',
        stack: stack,
        severity: SystemErrorSeverity.error,
        metadata: {'senderId': senderId, 'receiverId': receiverId},
      );
      return null;
    }
  }

  Stream<List<Message>> getConversationStream(String userId1, String userId2, {int limit = 60}) {
    // userId1 = mevcut kullanıcı (giriş yapmış), userId2 = konuştuğu kişi
    final effectiveLimit = limit.clamp(10, 100);
    final convId = getConversationId(userId1, userId2);

    late StreamController<List<Message>> controller;
    StreamSubscription? singleSub;
    StreamSubscription? sentSub;
    StreamSubscription? receivedSub;
    bool fallbackActive = false;

    controller = StreamController<List<Message>>(
      onListen: () {
        void startDualStreamFallback() {
          if (fallbackActive || controller.isClosed) return;
          fallbackActive = true;
          singleSub?.cancel();

          List<Message> sentMessages = [];
          List<Message> receivedMessages = [];

          void emitDual() {
            if (!controller.isClosed) {
              final Map<String, Message> messageMap = {};
              for (var m in sentMessages) {
                if (!m.deletedBy.contains(userId1)) {
                  messageMap[m.id] = m;
                }
              }
              for (var m in receivedMessages) {
                if (!m.deletedBy.contains(userId1)) {
                  messageMap[m.id] = m;
                }
              }
              final all = messageMap.values.toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

              final result = all.length > limit ? all.sublist(all.length - limit) : all;
              controller.add(result);
            }
          }

          sentSub = _firestore
              .collection('messages')
              .where('senderId', isEqualTo: userId1)
              .where('receiverId', isEqualTo: userId2)
              .orderBy('createdAt', descending: true)
              .limit(effectiveLimit)
              .snapshots()
              .listen(
            (snap) {
              sentMessages = snap.docs.map((d) => Message.fromFirestore(d)).toList();
              emitDual();
            },
            onError: (error) {
              final isPerm = error.toString().contains('permission-denied');
              if (isPerm && FirebaseAuth.instance.currentUser == null) {
                return;
              }
              _log('⚠️ sentSub error: $error');
            },
          );

          receivedSub = _firestore
              .collection('messages')
              .where('senderId', isEqualTo: userId2)
              .where('receiverId', isEqualTo: userId1)
              .orderBy('createdAt', descending: true)
              .limit(effectiveLimit)
              .snapshots()
              .listen(
            (snap) {
              receivedMessages = snap.docs.map((d) => Message.fromFirestore(d)).toList();
              emitDual();
            },
            onError: (error) {
              final isPerm = error.toString().contains('permission-denied');
              if (isPerm && FirebaseAuth.instance.currentUser == null) {
                return;
              }
              _log('⚠️ receivedSub error: $error');
            },
          );
        }

        // FS-21: Öncelikle tekil conversationId + participants akışını başlat (50% listener ve soket tasarrufu)
        singleSub = _firestore
            .collection('messages')
            .where('conversationId', isEqualTo: convId)
            .where('participants', arrayContains: userId1)
            .orderBy('createdAt', descending: true)
            .limit(effectiveLimit)
            .snapshots()
            .listen(
          (snap) {
            if (!controller.isClosed) {
              final messages = snap.docs
                  .map((d) => Message.fromFirestore(d))
                  .where((m) => !m.deletedBy.contains(userId1))
                  .toList();
              messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              final result = messages.length > limit ? messages.sublist(messages.length - limit) : messages;
              controller.add(result);
            }
          },
          onError: (error) {
            _log('⚠️ Single conversation stream fallback tetiklendi: $error');
            startDualStreamFallback();
          },
        );
      },
      onCancel: () {
        singleSub?.cancel();
        sentSub?.cancel();
        receivedSub?.cancel();
      },
    );

    return controller.stream;
  }

  // Okundu işaretleme
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({'isRead': true});
    } catch (e) {
      _log('markMessageAsRead error: $e');
    }
  }

  /// FS-MSG-01 & FS-MSG-03: Gelen kutusu üst seviye conversations akışı.
  /// N+1 User dinleyicilerini ve 100 limitli mesaj havuzu kırpılmasını önler.
  Stream<List<Conversation>> getConversationsStream(String currentUserId, {int limit = 40}) {
    final effectiveLimit = limit.clamp(10, 100);
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .limit(effectiveLimit)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .where((conv) => !conv.isClearedFor(currentUserId))
          .toList();
    });
  }

  /// FS-MSG-01: Kullanıcının toplam okunmamış mesaj sayısını 0 Firestore okuma maliyetiyle
  /// üst seviye conversations belgelerinden anlık dinler.
  Stream<int> getUnreadTotalMessageCountStream(String currentUserId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snap) {
      int totalUnread = 0;
      for (var doc in snap.docs) {
        final conv = Conversation.fromFirestore(doc);
        if (!conv.isClearedFor(currentUserId)) {
          totalUnread += conv.getUnreadCount(currentUserId);
        }
      }
      return totalUnread;
    });
  }

  /// FS-MSG-02, FS-MSG-06 & FS-MSG-11: Two-Tier Sayfalama için tek seferlik statik geçmiş mesaj sorgusu.
  /// Dinleyiciyi yeniden başlatmaz, eski mesajları startAfter timestamp ile çeker ve clearedAt kalkanıyla zombileri engeller.
  Future<List<Message>> loadOlderMessages({
    required String currentUserId,
    required String otherUserId,
    required DateTime oldestCreatedAt,
    DateTime? clearedAt,
    int limit = 30,
  }) async {
    try {
      final convId = getConversationId(currentUserId, otherUserId);
      DateTime? effectiveClearedAt = clearedAt;
      if (effectiveClearedAt == null) {
        try {
          final convDoc = await _firestore.collection('conversations').doc(convId).get();
          if (convDoc.exists) {
            final clearedMap = convDoc.data()?['clearedAt'];
            if (clearedMap is Map && clearedMap[currentUserId] != null) {
              final cVal = clearedMap[currentUserId];
              if (cVal is Timestamp) {
                effectiveClearedAt = cVal.toDate();
              } else if (cVal is String) {
                effectiveClearedAt = DateTime.tryParse(cVal);
              }
            }
          }
        } catch (_) {}
      }

      final snap = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: convId)
          .where('participants', arrayContains: currentUserId)
          .orderBy('createdAt', descending: true)
          .startAfter([Timestamp.fromDate(oldestCreatedAt)])
          .limit(limit)
          .get();

      return snap.docs
          .map((d) => Message.fromFirestore(d))
          .where((m) {
            if (m.deletedBy.contains(currentUserId)) return false;
            if (effectiveClearedAt != null && m.createdAt.isBefore(effectiveClearedAt)) return false;
            return true;
          })
          .toList();
    } catch (e) {
      _log('loadOlderMessages error: $e');
      return [];
    }
  }

  /// FS-MSG-16: 100+ okunmamış mesaj olduğunda tümünü sayfalı tüketerek senkronizasyonu korur
  Future<void> markConversationAsRead(String currentUserId, String otherUserId) async {
    try {
      int updatedTotal = 0;
      while (true) {
        final snap = await _firestore
            .collection('messages')
            .where('senderId', isEqualTo: otherUserId)
            .where('receiverId', isEqualTo: currentUserId)
            .where('isRead', isEqualTo: false)
            .limit(100)
            .get();

        if (snap.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (var doc in snap.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
        updatedTotal += snap.docs.length;

        // Emniyet tavanı: Tek seferde maksimum 500 mesaj (Kota koruması)
        if (snap.docs.length < 100 || updatedTotal >= 500) break;
      }

      // conversations unreadCounts alanını da sıfırla (anında senkronizasyon)
      final convId = getConversationId(currentUserId, otherUserId);
      _firestore.collection('conversations').doc(convId).set({
        'unreadCounts': {
          currentUserId: 0,
        },
      }, SetOptions(merge: true)).catchError((_) {});
    } catch (e) {
      _log('markConversationAsRead error: $e');
    }
  }

  // Mesaja Tepki Ekle / Kaldır (Toggle Emoji Reaction) - FS-MSG-14 Güvenlik Kalkanı
  Future<void> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid == null || authUid != userId) {
        _log('🚫 FS-MSG-14: Yetkisiz tepki denemesi engellendi.');
        return;
      }
      final cleanEmoji = emoji.trim();
      if (cleanEmoji.isEmpty || cleanEmoji.length > 10) return;

      final docRef = _firestore.collection('messages').doc(messageId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

      if (reactions[userId] == cleanEmoji) {
        // Kullanıcı aynı emojiyi seçti -> tepkiyi kaldır (toggle off)
        await docRef.update({
          'reactions.$userId': FieldValue.delete(),
        });
      } else {
        // Farklı emoji seçti veya yeni tepki verdi -> kaydet / güncelle
        await docRef.update({
          'reactions.$userId': cleanEmoji,
        });
      }
    } catch (e) {
      _log('toggleReaction error: $e');
    }
  }

  // Benden Sil (Soft Delete)
  Future<void> softDeleteMessageForUser(String messageId, String userId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'deletedBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      _log('softDeleteMessageForUser error: $e');
    }
  }

  // Herkesten Sil (15 Dakika kuralı & Kanıt Karartmayı Önleyen Dünya Standardı Retract Mekanizması)
  Future<bool> deleteMessageForEveryone(String messageId, String currentUserId) async {
    try {
      final doc = await _firestore.collection('messages').doc(messageId).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      if (data['senderId'] != currentUserId) return false;

      DateTime createdAt = DateTime.now();
      final cVal = data['createdAt'];
      if (cVal is Timestamp) {
        createdAt = cVal.toDate();
      } else if (cVal is String) {
        createdAt = DateTime.tryParse(cVal) ?? DateTime.now();
      }

      final diffMinutes = DateTime.now().difference(createdAt).inMinutes;
      if (diffMinutes <= 15) {
        // Fiziksel silme yerine retract (geri çekme): delil ve moderasyon zincirini korur
        await _firestore.collection('messages').doc(messageId).update({
          'isDeletedForEveryone': true,
          'text': 'Bu mesaj silindi',
          'dealId': FieldValue.delete(),
          'dealTitle': FieldValue.delete(),
          'dealImageUrl': FieldValue.delete(),
          'dealPrice': FieldValue.delete(),
          'dealStore': FieldValue.delete(),
          'reactions': {},
          'deletedAt': FieldValue.serverTimestamp(),
        });

        // conversations belgesindeki lastMessage bu mesaj ise onun metnini de güncelle
        final convId = (data['conversationId'] ?? '').toString();
        if (convId.isNotEmpty) {
          final convRef = _firestore.collection('conversations').doc(convId);
          convRef.get().then((cDoc) {
            if (cDoc.exists) {
              final lm = cDoc.data()?['lastMessage'];
              if (lm is Map && (lm['createdAt'] == data['createdAt'] || lm['senderId'] == currentUserId)) {
                convRef.update({
                  'lastMessage.text': 'Bu mesaj silindi',
                }).catchError((_) {});
              }
            }
          }).catchError((_) {});
        }
        return true;
      }
      return false;
    } catch (e) {
      _log('deleteMessageForEveryone error: $e');
      return false;
    }
  }

  // Kullanıcı mesajını güvenli sil (Soft-delete öncelikli, kalıcı silme yasak)
  Future<void> deleteUserMessage(String messageId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await softDeleteMessageForUser(messageId, uid);
      }
    } catch (e) {
      _log('deleteUserMessage error: $e');
    }
  }

  /// Sohbeti sadece çağıran kullanıcı için temizler (Soft Delete).
  /// Masum karşı tarafın konuşma geçmişini ASLA yok etmez ve delilleri korur.
  Future<void> clearConversationForUser(String currentUserId, String otherUserId) async {
    try {
      final convId = getConversationId(currentUserId, otherUserId);

      // 1. conversations dokümanında clearedAt zaman damgasını ve okunmamış sayısını güncelle
      final convRef = _firestore.collection('conversations').doc(convId);
      await convRef.set({
        'clearedAt': {
          currentUserId: FieldValue.serverTimestamp(),
        },
        'unreadCounts': {
          currentUserId: 0,
        },
      }, SetOptions(merge: true));

      // 2. Mevcut mesajlara deletedBy ekle (benden sil soft-delete)
      final recentMsgs = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: convId)
          .limit(100)
          .get();

      if (recentMsgs.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in recentMsgs.docs) {
          batch.update(doc.reference, {
            'deletedBy': FieldValue.arrayUnion([currentUserId])
          });
        }
        await batch.commit();
      }

      // 3. Yazıyor durumlarını temizle
      try {
        await _firestore.collection('typingStatus').doc('${convId}_$currentUserId').delete();
      } catch (_) {}
    } catch (e) {
      _log('clearConversationForUser error: $e');
    }
  }

  /// Geriye uyumluluk: Eski çağıranlar için deleteConversationPermanently güvenli biçimde
  /// clearConversationForUser metoduna delege eder. Masum kullanıcının verisi korunur.
  Future<void> deleteConversationPermanently(String currentUserId, String otherUserId) async {
    await clearConversationForUser(currentUserId, otherUserId);
  }

  // Yazıyor... (Typing indicator)
  Future<void> setTypingStatus({
    required String currentUserId,
    required String otherUserId,
    required bool isTyping,
  }) async {
    try {
      final conversationId = getConversationId(currentUserId, otherUserId);
      final docRef = _firestore.collection('typingStatus').doc('${conversationId}_$currentUserId');
      if (isTyping) {
        await docRef.set({
          'isTyping': true,
          'userId': currentUserId,
          'conversationId': conversationId,
          'updatedAt': FieldValue.serverTimestamp(),
          // FS-26: Hayalet belge birikimini sıfır maliyetle temizleyen Firestore Native TTL alanı (10 dk)
          'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
        });
      } else {
        await docRef.delete();
      }
    } catch (e) {
      // Sessiz hata
    }
  }

  Stream<bool> getTypingStream({
    required String currentUserId,
    required String otherUserId,
  }) {
    final conversationId = getConversationId(currentUserId, otherUserId);
    final docRef = _firestore.collection('typingStatus').doc('${conversationId}_$otherUserId');
    return docRef.snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data();
      if (data == null) return false;
      final isTyping = data['isTyping'] == true;
      final updatedAt = data['updatedAt'];
      if (updatedAt is Timestamp) {
        final diffSeconds = DateTime.now().difference(updatedAt.toDate()).inSeconds;
        // 5 saniyeden eskiyse düşür
        if (diffSeconds > 5) return false;
      }
      return isTyping;
    }).handleError((_) => false);
  }

  // Kullanıcı Engelleme / Engeli Kaldırma
  Future<void> blockUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([targetUserId])
      });
    } catch (e) {
      _log('blockUser error: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayRemove([targetUserId])
      });
    } catch (e) {
      _log('unblockUser error: $e');
      rethrow;
    }
  }

  Future<bool> isUserBlocked(String currentUserId, String targetUserId) async {
    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      if (!doc.exists) return false;
      final blocked = List<String>.from(doc.data()?['blockedUsers'] ?? []);
      return blocked.contains(targetUserId);
    } catch (e) {
      return false;
    }
  }

  // Sohbeti Sessize Alma / Açma (Mute)
  Future<void> toggleMuteConversation(String currentUserId, String otherUserId, bool mute) async {
    try {
      if (mute) {
        await _firestore.collection('users').doc(currentUserId).update({
          'mutedConversations': FieldValue.arrayUnion([otherUserId])
        });
      } else {
        await _firestore.collection('users').doc(currentUserId).update({
          'mutedConversations': FieldValue.arrayRemove([otherUserId])
        });
      }
    } catch (e) {
      _log('toggleMuteConversation error: $e');
    }
  }

  Future<bool> isConversationMuted(String currentUserId, String otherUserId) async {
    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      if (!doc.exists) return false;
      final muted = List<String>.from(doc.data()?['mutedConversations'] ?? []);
      return muted.contains(otherUserId);
    } catch (e) {
      return false;
    }
  }

  Future<int> getUnreadMessageCount(String userId) async {
    try {
      // 1. Öncelikle üst seviye conversations koleksiyonundan optimize toplamı al (0'a yakın maliyet)
      final convSnap = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .get();

      if (convSnap.docs.isNotEmpty) {
        int total = 0;
        for (var doc in convSnap.docs) {
          final conv = Conversation.fromFirestore(doc);
          if (!conv.isClearedFor(userId)) {
            total += conv.getUnreadCount(userId);
          }
        }
        return total;
      }

      // 2. conversations henüz oluşmamışsa (eski veriler için AggregateQuery count)
      final countSnap = await _firestore
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return countSnap.count ?? 0;
    } catch (e) {
      _log('getUnreadMessageCount error: $e');
      return 0;
    }
  }

  // Admin Bildirimleri (AdminToUserMessage)
  Stream<List<AdminToUserMessage>> getAdminToUserMessagesStream(String userId, {int limit = 100}) {
    final effectiveLimit = limit.clamp(10, 100);
    return _firestore.collection('adminToUserMessages')
        .where('userId', isEqualTo: userId)
        .limit(effectiveLimit)
        .snapshots()
        .map((s) {
      final items = s.docs.map((d) => AdminToUserMessage.fromFirestore(d)).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.take(effectiveLimit).toList();
    });
  }

  Future<int> getUnreadAdminToUserMessageCount(String userId) async {
    try {
      final s = await _firestore.collection('adminToUserMessages')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .limit(100)
          .get();
      return s.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAdminToUserMessageAsRead(String messageId) async {
    await _firestore.collection('adminToUserMessages').doc(messageId).update({'isRead': true});
  }

  Future<void> deleteAdminToUserMessage(String messageId) async {
    await _firestore.collection('adminToUserMessages').doc(messageId).delete();
  }

  /// Yönetici tarafından kullanıcıya resmi duyuru/mesaj gönderir (adminToUserMessages)
  Future<bool> sendAdminToUserMessage({
    required String targetUserId,
    required String adminId,
    required String adminName,
    required String title,
    required String content,
  }) async {
    try {
      final ref = _firestore.collection('adminToUserMessages').doc();
      await ref.set({
        'id': ref.id,
        'userId': targetUserId,
        'adminId': adminId,
        'adminName': adminName,
        'title': title,
        'content': content,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Admin Paneli - Tüm Kullanıcı Mesajları (Maksimum 100 güncel mesaj ile sınırlandırılmış güvenli akış)
  Stream<List<Message>> getAllMessagesStream() {
    return _firestore.collection('messages').orderBy('createdAt', descending: true).limit(100).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  Future<void> markMessageAsReadByAdmin(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({'isReadByAdmin': true});
    } catch (e) {
      _log('markMessageAsReadByAdmin error: $e');
    }
  }

  Future<int> deleteAllMessages() async {
    try {
      // Güvenlik tavanı: Tek seferde en fazla 100 mesaj silinebilir.
      final snapshot = await _firestore.collection('messages').limit(100).get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      _log('deleteAllMessages error: $e');
      return 0;
    }
  }

  Future<bool> deleteSingleMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
      return true;
    } catch (e) {
      _log('deleteSingleMessage error: $e');
      return false;
    }
  }

  // Moderasyon Mesajı (Admin Paneli İçin)
  Future<void> createModerationMessage({
    required String type,
    required String userId,
    required String userName,
    required String content,
    String? dealId,
    String? commentId,
    required String reason,
  }) async {
    await _firestore.collection('adminMessages').add({
      'type': type,
      'userId': userId,
      'userName': userName,
      'content': content.length > 200 ? '${content.substring(0, 200)}...' : content,
      'dealId': dealId,
      'commentId': commentId,
      'reason': reason,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
