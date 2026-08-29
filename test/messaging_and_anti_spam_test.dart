import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/message.dart';

void main() {
  group('1. Anti-Spam Rate Limiter (Sliding Window) Tests', () {
    test('Allows up to 3 messages within 5 seconds', () {
      final timestamps = <DateTime>[];
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      // Simule edilen mesaj gönderme fonksiyonu
      bool trySendMessage(DateTime time) {
        timestamps.removeWhere((ts) => time.difference(ts).inSeconds >= 5);
        if (timestamps.length >= 3) {
          return false; // Engellendi
        }
        timestamps.add(time);
        return true; // Başarılı
      }

      // 1. mesaj (0. saniye) -> İzin verilmeli
      expect(trySendMessage(now), isTrue);
      // 2. mesaj (1. saniye) -> İzin verilmeli
      expect(trySendMessage(now.add(const Duration(seconds: 1))), isTrue);
      // 3. mesaj (2. saniye) -> İzin verilmeli
      expect(trySendMessage(now.add(const Duration(seconds: 2))), isTrue);

      // 4. mesaj (3. saniye) -> ENGELLENMELİ (5 saniyede 4. mesaj)
      expect(trySendMessage(now.add(const Duration(seconds: 3))), isFalse);

      // 5. saniye geçtiğinde (6. saniye) -> İlk mesaj pencereden çıktı, İzin verilmeli
      expect(trySendMessage(now.add(const Duration(seconds: 6))), isTrue);
    });

    test('Window slides dynamically and maintains max 3 messages per 5s slice', () {
      final timestamps = <DateTime>[];
      final baseTime = DateTime(2026, 8, 29, 12, 0, 0);

      bool trySendMessage(DateTime time) {
        timestamps.removeWhere((ts) => time.difference(ts).inSeconds >= 5);
        if (timestamps.length >= 3) return false;
        timestamps.add(time);
        return true;
      }

      // 0s, 1s, 2s gönderildi
      expect(trySendMessage(baseTime), isTrue);
      expect(trySendMessage(baseTime.add(const Duration(seconds: 1))), isTrue);
      expect(trySendMessage(baseTime.add(const Duration(seconds: 2))), isTrue);

      // 4s anında hala pencere içinde 3 mesaj var -> Engellendi
      expect(trySendMessage(baseTime.add(const Duration(seconds: 4))), isFalse);

      // 5.1s anında 0s'deki mesaj düştü -> 1 hak açıldı
      expect(trySendMessage(baseTime.add(const Duration(milliseconds: 5100))), isTrue);

      // Hemen ardından (5.2s) tekrar denerse -> Yine 3 mesaj oldu, engellenmeli
      expect(trySendMessage(baseTime.add(const Duration(milliseconds: 5200))), isFalse);

      // 10s sonra tamamen temizlendi -> Tekrar 3 hak var
      expect(trySendMessage(baseTime.add(const Duration(seconds: 10))), isTrue);
      expect(trySendMessage(baseTime.add(const Duration(seconds: 11))), isTrue);
      expect(trySendMessage(baseTime.add(const Duration(seconds: 12))), isTrue);
      expect(trySendMessage(baseTime.add(const Duration(seconds: 13))), isFalse);
    });
  });

  group('2. Notification Stacking & Deterministic ID / Tag Tests', () {
    test('Same sender produces deterministic notifId and tag (Prevents notification stacking)', () {
      const sender1 = 'user_murat_123';
      final notifId1 = sender1.hashCode % 100000;
      final tag1 = 'msg_$sender1';

      final notifId2 = sender1.hashCode % 100000;
      final tag2 = 'msg_$sender1';

      expect(notifId1, equals(notifId2));
      expect(tag1, equals(tag2));
      expect(tag1, 'msg_user_murat_123');
    });

    test('Different senders produce distinct tags and IDs', () {
      const senderA = 'user_ahmet';
      const senderB = 'user_zeynep';

      final tagA = 'msg_$senderA';
      final tagB = 'msg_$senderB';

      expect(tagA, isNot(equals(tagB)));
      expect(tagA, 'msg_user_ahmet');
      expect(tagB, 'msg_user_zeynep');
    });

    test('Admin sender produces msg_admin tag', () {
      const senderAdmin = 'admin';
      final tagAdmin = 'msg_$senderAdmin';
      expect(tagAdmin, 'msg_admin');
    });
  });

  group('3. Notification Payload String Parser Tests', () {
    Map<String, dynamic> parsePayload(String payload) {
      if (payload.startsWith('admin_message:') || payload == 'admin_message') {
        return {'type': 'admin_message'};
      } else if (payload.startsWith('admin_deal:')) {
        final dealId = payload.substring('admin_deal:'.length);
        return {'type': 'admin_deal', 'dealId': dealId};
      } else if (payload.startsWith('comment_reply:')) {
        final parts = payload.split(':');
        final dealId = parts.length > 1 ? parts[1] : '';
        final commentId = parts.length > 2 ? parts[2] : '';
        return {'type': 'comment_reply', 'dealId': dealId, 'commentId': commentId};
      } else if (payload.startsWith('message:')) {
        final parts = payload.split(':');
        final senderId = parts.length > 1 ? parts[1] : '';
        final senderName = parts.length > 2 ? parts[2] : 'Kullanıcı';
        final messageText = parts.length > 3 ? parts.sublist(3).join(':') : '';
        return {
          'type': 'message',
          'senderId': senderId,
          'senderName': senderName,
          'messageText': messageText,
        };
      } else {
        return {'type': 'deal', 'dealId': payload};
      }
    }

    test('Parses message payload with text including colons correctly', () {
      final res = parsePayload('message:user_456:Ahmet Yılmaz:Saat 14:30 da buluşalım: tamam mı?');
      expect(res['type'], 'message');
      expect(res['senderId'], 'user_456');
      expect(res['senderName'], 'Ahmet Yılmaz');
      expect(res['messageText'], 'Saat 14:30 da buluşalım: tamam mı?');
    });

    test('Parses admin message payload', () {
      final res = parsePayload('admin_message');
      expect(res['type'], 'admin_message');
    });

    test('Parses comment reply payload', () {
      final res = parsePayload('comment_reply:deal_abc123:comment_xyz789');
      expect(res['type'], 'comment_reply');
      expect(res['dealId'], 'deal_abc123');
      expect(res['commentId'], 'comment_xyz789');
    });

    test('Parses admin deal payload', () {
      final res = parsePayload('admin_deal:deal_999');
      expect(res['type'], 'admin_deal');
      expect(res['dealId'], 'deal_999');
    });

    test('Parses direct deal payload', () {
      final res = parsePayload('deal_standard_44');
      expect(res['type'], 'deal');
      expect(res['dealId'], 'deal_standard_44');
    });
  });

  group('4. Instant Message Seeding & Deduplication Blending Tests', () {
    test('Optimistic seeded message blends seamlessly with Firestore server stream and dedups', () {
      final now = DateTime.now();

      // Push bildiriminden açıldığında gelen optimistic mesaj
      final optimisticMsg = Message(
        id: 'incoming_temp_123',
        conversationId: 'conv_123',
        senderId: 'user_sender',
        senderName: 'Ahmet',
        senderImageUrl: '',
        receiverId: 'user_my_uid',
        receiverName: '',
        receiverImageUrl: '',
        text: 'Harika bir fırsat buldum!',
        createdAt: now,
        isRead: true,
        status: 'sent',
      );

      final optimisticList = [optimisticMsg];

      // 1. Durum: Henüz Firestore bağlanmadı (serverMessages = [])
      List<Message> serverMessages = [];

      Map<String, Message> mergedMap = {};
      for (var m in serverMessages) {
        mergedMap[m.id] = m;
      }
      for (var m in optimisticList) {
        final hasDuplicate = serverMessages.any((sm) =>
          sm.id == m.id ||
          (sm.senderId == m.senderId &&
           sm.text.trim() == m.text.trim() &&
           sm.createdAt.difference(m.createdAt).inSeconds.abs() < 120)
        );
        if (!hasDuplicate) mergedMap[m.id] = m;
      }

      var allMessages = mergedMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Henüz sunucu verisi yokken bile ekranda mesaj var (sıfır gecikme)
      expect(allMessages.length, equals(1));
      expect(allMessages.first.text, 'Harika bir fırsat buldum!');
      expect(allMessages.first.id, 'incoming_temp_123');

      // 2. Durum: 800ms sonra Firestore sunucusundan gerçek mesajlar geldi
      serverMessages = [
        Message(
          id: 'server_real_doc_999',
          conversationId: 'conv_123',
          senderId: 'user_sender',
          senderName: 'Ahmet',
          senderImageUrl: '',
          receiverId: 'user_my_uid',
          receiverName: '',
          receiverImageUrl: '',
          text: 'Harika bir fırsat buldum!', // Aynı metin
          createdAt: now.subtract(const Duration(seconds: 1)),
          isRead: false,
          status: 'delivered',
        ),
        Message(
          id: 'server_real_doc_older',
          conversationId: 'conv_123',
          senderId: 'user_sender',
          senderName: 'Ahmet',
          senderImageUrl: '',
          receiverId: 'user_my_uid',
          receiverName: '',
          receiverImageUrl: '',
          text: 'Eski mesaj',
          createdAt: now.subtract(const Duration(minutes: 5)),
          isRead: true,
          status: 'read',
        ),
      ];

      mergedMap = {};
      for (var m in serverMessages) {
        mergedMap[m.id] = m;
      }
      for (var m in optimisticList) {
        final hasDuplicate = serverMessages.any((sm) =>
          sm.id == m.id ||
          (sm.senderId == m.senderId &&
           sm.text.trim() == m.text.trim() &&
           sm.createdAt.difference(m.createdAt).inSeconds.abs() < 120)
        );
        if (!hasDuplicate) mergedMap[m.id] = m;
      }

      allMessages = mergedMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Dedup çalıştı: Toplam 2 mesaj olmalı (aynı mesaj çift görünmemeli)
      expect(allMessages.length, equals(2));
      // En yeni mesaj listenin başında olmalı (reverse: true için descending)
      expect(allMessages[0].id, equals('server_real_doc_999'));
      expect(allMessages[0].text, equals('Harika bir fırsat buldum!'));
      expect(allMessages[1].id, equals('server_real_doc_older'));
      expect(allMessages[1].text, equals('Eski mesaj'));
    });
  });
}
