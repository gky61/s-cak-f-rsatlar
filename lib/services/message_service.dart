import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/message.dart';
import '../models/admin_to_user_message.dart';
import 'notification_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    try {
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      
      if (!senderDoc.exists || !receiverDoc.exists) return null;

      final message = Message(
        id: '',
        senderId: senderId,
        senderName: senderDoc.data()?['username'] ?? 'Kullanıcı',
        senderImageUrl: senderDoc.data()?['profileImageUrl'] ?? '',
        receiverId: receiverId,
        receiverName: receiverDoc.data()?['username'] ?? 'Kullanıcı',
        receiverImageUrl: receiverDoc.data()?['profileImageUrl'] ?? '',
        text: text.trim(),
        createdAt: DateTime.now(),
        isRead: false,
        isReadByAdmin: false,
      );

      final docRef = await _firestore.collection('messages').add(message.toFirestore());
      
      // Bildirim gönderme işlemi Cloud Functions veya alıcı tarafındaki dinleyici ile yapılır.
      // Burada yerel bildirim göstermek gönderen kişi için anlamsızdır.
      /*
      try {
        final notificationService = NotificationService();
        await notificationService.sendMessageNotification(
          receiverId: receiverId,
          senderName: message.senderName,
          messageText: text,
          messageId: docRef.id,
        );
      } catch (e) {
        _log('Bildirim hatası: $e');
      }
      */

      return docRef.id;
    } catch (e) {
      _log('Mesaj gönderme hatası: $e');
      return null;
    }
  }

  Stream<List<Message>> getConversationStream(String userId1, String userId2) {
    // userId1 = mevcut kullanıcı (giriş yapmış), userId2 = konuştuğu kişi
    // Security rules: Sadece senderId veya receiverId == userId() olan mesajları okuyabilir
    // Bu yüzden mevcut kullanıcının gönderdiği ve aldığı mesajları ayrı ayrı çekmeliyiz
    
    // Kullanıcının gönderdiği mesajlar (userId1 -> userId2)
    final sentStream = _firestore
        .collection('messages')
        .where('senderId', isEqualTo: userId1)
        .where('receiverId', isEqualTo: userId2)
        .snapshots();
    
    // Kullanıcının aldığı mesajlar (userId2 -> userId1)
    final receivedStream = _firestore
        .collection('messages')
        .where('senderId', isEqualTo: userId2)
        .where('receiverId', isEqualTo: userId1)
        .snapshots();
    
    // İki stream'i birleştir
    return sentStream.asyncMap((sentSnapshot) async {
      final receivedSnapshot = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId2)
          .where('receiverId', isEqualTo: userId1)
          .get();
      
      final allMessages = <Message>[];
      final messageIds = <String>{};
      
      // Gönderilen mesajları ekle
      for (var doc in sentSnapshot.docs) {
        final message = Message.fromFirestore(doc);
        if (!messageIds.contains(message.id)) {
          allMessages.add(message);
          messageIds.add(message.id);
        }
      }
      
      // Alınan mesajları ekle
      for (var doc in receivedSnapshot.docs) {
        final message = Message.fromFirestore(doc);
        if (!messageIds.contains(message.id)) {
          allMessages.add(message);
          messageIds.add(message.id);
        }
      }
      
      allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return allMessages;
    });
  }

  Future<void> markMessageAsRead(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({'isRead': true});
  }

  Stream<List<Message>> getAllMessagesStream() {
    return _firestore.collection('messages').orderBy('createdAt', descending: true).snapshots().map(
      (s) => s.docs.map((d) => Message.fromFirestore(d)).toList()
    );
  }

  Future<void> markMessageAsReadByAdmin(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({'isReadByAdmin': true});
  }

  Future<int> deleteAllMessages() async {
    try {
      final snapshot = await _firestore.collection('messages').get();
      if (snapshot.docs.isEmpty) return 0;

      final batch = _firestore.batch();
      int count = 0;
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count % 500 == 0) await batch.commit();
      }
      if (count % 500 != 0) await batch.commit();
      return count;
    } catch (e) {
      rethrow;
    }
  }

  // EKLENDİ: Kullanıcı mesajını sil
  Future<void> deleteUserMessage(String messageId) async {
    await _firestore.collection('messages').doc(messageId).delete();
  }

  Future<int> getUnreadMessageCount(String userId) async {
    final s = await _firestore.collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return s.docs.length;
  }

  // Admin Bildirimleri (AdminToUserMessage)
  Stream<List<AdminToUserMessage>> getAdminToUserMessagesStream(String userId, {int limit = 200}) {
    return _firestore.collection('adminToUserMessages').where('userId', isEqualTo: userId).snapshots().map((s) {
      final items = s.docs.map((d) => AdminToUserMessage.fromFirestore(d)).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.take(limit).toList();
    });
  }

  // EKLENDİ: Okunmamış admin bildirim sayısı
  Future<int> getUnreadAdminToUserMessageCount(String userId) async {
    try {
      final s = await _firestore.collection('adminToUserMessages')
          .where('userId', isEqualTo: userId)
          //.where('isRead', isEqualTo: false) // Index hatası vermesin diye client side filtreleme
          .get();
      return s.docs.map((d) => AdminToUserMessage.fromFirestore(d)).where((m) => !m.isRead).length;
    } catch (e) {
      return 0;
    }
  }

  // EKLENDİ: Admin bildirimini okundu işaretle
  Future<void> markAdminToUserMessageAsRead(String messageId) async {
    await _firestore.collection('adminToUserMessages').doc(messageId).update({'isRead': true});
  }

  // EKLENDİ: Admin bildirimini sil
  Future<void> deleteAdminToUserMessage(String messageId) async {
    await _firestore.collection('adminToUserMessages').doc(messageId).delete();
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
      'content': content.length > 200 ? content.substring(0, 200) + '...' : content,
      'dealId': dealId,
      'commentId': commentId,
      'reason': reason,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
