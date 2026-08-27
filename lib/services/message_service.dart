import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:sicak_firsatlar/utils/asset_path_migration.dart';
import '../models/message.dart';
import '../models/admin_to_user_message.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      } else {
        final senderDoc = await _firestore.collection('users').doc(senderId).get();
        if (!senderDoc.exists) return null;
        final sData = senderDoc.data();
        senderName = sData?['username'] ?? sData?['displayName'] ?? sData?['nickname'] ?? 'Kullanıcı';
        senderImageUrl = migrateAssetPath((sData?['profileImageUrl'] ?? sData?['photoURL'] ?? '').toString());
      }

      String receiverName = 'Kullanıcı';
      String receiverImageUrl = '';
      if (receiverId == 'botkolik') {
        receiverName = 'Botkolik';
        receiverImageUrl = 'assets/botkolik.webp';
      } else {
        final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
        if (!receiverDoc.exists) return null;
        final rData = receiverDoc.data();
        // Engellenmişlik kontrolü: Alıcı göndereni engellediyse mesaj gitmez
        final receiverBlockedList = List<String>.from(rData?['blockedUsers'] ?? []);
        if (receiverBlockedList.contains(senderId)) {
          _log('🚫 Alıcı bu kullanıcıyı engellediği için mesaj iletilmedi.');
          return null;
        }
        receiverName = rData?['username'] ?? rData?['displayName'] ?? rData?['nickname'] ?? 'Kullanıcı';
        receiverImageUrl = migrateAssetPath((rData?['profileImageUrl'] ?? rData?['photoURL'] ?? '').toString());
      }

      final convId = getConversationId(senderId, receiverId);
      final message = Message(
        id: '',
        conversationId: convId,
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
      return docRef.id;
    } catch (e) {
      _log('Mesaj gönderme hatası: $e');
      return null;
    }
  }

  Stream<List<Message>> getConversationStream(String userId1, String userId2, {int limit = 60}) {
    // userId1 = mevcut kullanıcı (giriş yapmış), userId2 = konuştuğu kişi
    late StreamController<List<Message>> controller;
    StreamSubscription? sentSub;
    StreamSubscription? receivedSub;

    controller = StreamController<List<Message>>(
      onListen: () {
        List<Message> sentMessages = [];
        List<Message> receivedMessages = [];

        void emit() {
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

            // En yeni `limit` kadar mesajı al
            final result = all.length > limit ? all.sublist(all.length - limit) : all;
            controller.add(result);
          }
        }

        // Gönderilen mesajlar (userId1 -> userId2) - İndeks hatası vermeyen saf equality sorgusu
        sentSub = _firestore
            .collection('messages')
            .where('senderId', isEqualTo: userId1)
            .where('receiverId', isEqualTo: userId2)
            .snapshots()
            .listen(
          (snap) {
            sentMessages = snap.docs.map((d) => Message.fromFirestore(d)).toList();
            emit();
          },
          onError: (error) {
            if (!error.toString().contains('permission-denied')) {
              _log('⚠️ sentConversationStream error: $error');
            }
          },
        );

        // Alınan mesajlar (userId2 -> userId1) - İndeks hatası vermeyen saf equality sorgusu
        receivedSub = _firestore
            .collection('messages')
            .where('senderId', isEqualTo: userId2)
            .where('receiverId', isEqualTo: userId1)
            .snapshots()
            .listen(
          (snap) {
            receivedMessages = snap.docs.map((d) => Message.fromFirestore(d)).toList();
            emit();
          },
          onError: (error) {
            if (!error.toString().contains('permission-denied')) {
              _log('⚠️ receivedConversationStream error: $error');
            }
          },
        );
      },
      onCancel: () {
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

  Future<void> markConversationAsRead(String currentUserId, String otherUserId) async {
    try {
      final snap = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      _log('markConversationAsRead error: $e');
    }
  }

  // Mesaja Tepki Ekle / Kaldır (Toggle Emoji Reaction)
  Future<void> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final docRef = _firestore.collection('messages').doc(messageId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

      if (reactions[userId] == emoji) {
        // Kullanıcı aynı emojiyi seçti -> tepkiyi kaldır (toggle off)
        await docRef.update({
          'reactions.$userId': FieldValue.delete(),
        });
      } else {
        // Farklı emoji seçti veya yeni tepki verdi -> kaydet / güncelle
        await docRef.update({
          'reactions.$userId': emoji,
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

  // Herkesten Sil (15 Dakika kuralı)
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
        await _firestore.collection('messages').doc(messageId).delete();
        return true;
      }
      return false;
    } catch (e) {
      _log('deleteMessageForEveryone error: $e');
      return false;
    }
  }

  // Kullanıcı mesajını kalıcı sil
  Future<void> deleteUserMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
    } catch (e) {
      _log('deleteUserMessage error: $e');
    }
  }

  /// İki kullanıcı arasındaki tüm sohbeti ve mesajları Firestore'dan kalıcı olarak siler.
  Future<void> deleteConversationPermanently(String currentUserId, String otherUserId) async {
    try {
      // 1. currentUserId -> otherUserId mesajları
      final sentSnap = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: otherUserId)
          .get();

      // 2. otherUserId -> currentUserId mesajları
      final receivedSnap = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .get();

      final allDocs = [...sentSnap.docs, ...receivedSnap.docs];

      if (allDocs.isNotEmpty) {
        for (var i = 0; i < allDocs.length; i += 500) {
          final batch = _firestore.batch();
          final chunk = allDocs.sublist(i, (i + 500 > allDocs.length) ? allDocs.length : i + 500);
          for (var doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      // 3. Yazıyor (typingStatus) kayıtlarını temizle
      final conversationId = getConversationId(currentUserId, otherUserId);
      try {
        await _firestore.collection('typingStatus').doc('${conversationId}_$currentUserId').delete();
        await _firestore.collection('typingStatus').doc('${conversationId}_$otherUserId').delete();
      } catch (_) {}
    } catch (e) {
      _log('deleteConversationPermanently error: $e');
      rethrow;
    }
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
    final s = await _firestore.collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return s.docs.where((d) {
      final deletedBy = List<String>.from(d.data()['deletedBy'] ?? []);
      return !deletedBy.contains(userId);
    }).length;
  }

  // Admin Bildirimleri (AdminToUserMessage)
  Stream<List<AdminToUserMessage>> getAdminToUserMessagesStream(String userId, {int limit = 200}) {
    return _firestore.collection('adminToUserMessages').where('userId', isEqualTo: userId).snapshots().map((s) {
      final items = s.docs.map((d) => AdminToUserMessage.fromFirestore(d)).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.take(limit).toList();
    });
  }

  Future<int> getUnreadAdminToUserMessageCount(String userId) async {
    try {
      final s = await _firestore.collection('adminToUserMessages')
          .where('userId', isEqualTo: userId)
          .get();
      return s.docs.map((d) => AdminToUserMessage.fromFirestore(d)).where((m) => !m.isRead).length;
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

  // Admin Paneli - Tüm Kullanıcı Mesajları
  Stream<List<Message>> getAllMessagesStream() {
    return _firestore.collection('messages').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
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
      final snapshot = await _firestore.collection('messages').get();
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
