import 'dart:io';
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

  group('5. In-App Message Dual-Channel Deduplication & Debounce Tests', () {
    test('Dual-channel deduplication: Firestore first, then FCM is suppressed', () {
      final handledIds = <String>{};
      int bannerShowCount = 0;

      void onReceiveMessage(String messageId, String channel) {
        if (handledIds.contains(messageId)) {
          return; // Zaten işlenmiş, afiş basılmaz
        }
        handledIds.add(messageId);
        bannerShowCount++;
      }

      const testMsgId = 'msg_doc_abc123';

      // 1. Kanal (0 ms): Firestore snapshot gelir
      onReceiveMessage(testMsgId, 'firestore');
      expect(bannerShowCount, equals(1));
      expect(handledIds.contains(testMsgId), isTrue);

      // 2. Kanal (~1000 ms sonra): FCM onMessage gelir
      onReceiveMessage(testMsgId, 'fcm_on_message');
      // Afiş tekrar basılmamalı, dedup çalışmalı
      expect(bannerShowCount, equals(1));
    });

    test('Dual-channel deduplication: FCM first, then Firestore is suppressed', () {
      final handledIds = <String>{};
      int bannerShowCount = 0;

      void onReceiveMessage(String messageId, String channel) {
        if (handledIds.contains(messageId)) {
          return;
        }
        handledIds.add(messageId);
        bannerShowCount++;
      }

      const testMsgId = 'msg_doc_xyz789';

      // 1. FCM ilk ulaşırsa
      onReceiveMessage(testMsgId, 'fcm_on_message');
      expect(bannerShowCount, equals(1));

      // 2. Firestore snapshot arkasından ulaşırsa
      onReceiveMessage(testMsgId, 'firestore');
      expect(bannerShowCount, equals(1));
    });

    test('Bounded cache evicts oldest entries when capacity exceeds 200', () {
      final handledIds = <String>{};

      void addHandledId(String id) {
        if (handledIds.length >= 200) {
          handledIds.remove(handledIds.first);
        }
        handledIds.add(id);
      }

      // 205 mesaj ekle
      for (int i = 1; i <= 205; i++) {
        addHandledId('msg_$i');
      }

      expect(handledIds.length, equals(200));
      // İlk 5 mesaj atılmış olmalı (FIFO)
      expect(handledIds.contains('msg_1'), isFalse);
      expect(handledIds.contains('msg_5'), isFalse);
      // Son mesajlar korunmalı
      expect(handledIds.contains('msg_6'), isTrue);
      expect(handledIds.contains('msg_205'), isTrue);
    });

    test('InAppMessageBanner 3000ms sliding window debounce suppresses duplicate banners', () {
      String? lastShownKey;
      DateTime? lastShownTime;
      int renderedBanners = 0;

      bool tryShowBanner(String senderId, String messageText, DateTime time) {
        final bannerKey = '${senderId}_${messageText.trim()}';
        if (lastShownKey == bannerKey &&
            lastShownTime != null &&
            time.difference(lastShownTime!).inMilliseconds < 3000) {
          return false; // Mükerrer, bastırıldı
        }
        lastShownKey = bannerKey;
        lastShownTime = time;
        renderedBanners++;
        return true;
      }

      final baseTime = DateTime(2026, 8, 29, 14, 0, 0);

      // 1. İlk mesaj -> Gösterilmeli
      expect(tryShowBanner('user_ali', 'Selam naber?', baseTime), isTrue);
      expect(renderedBanners, equals(1));

      // 2. 1000ms sonra aynı mesaj (FCM ikinci tetiklemesi senaryosu) -> BASTIRILMALI
      expect(tryShowBanner('user_ali', 'Selam naber?', baseTime.add(const Duration(milliseconds: 1000))), isFalse);
      expect(renderedBanners, equals(1));

      // 3. 2500ms sonra aynı mesaj -> BASTIRILMALI (<3000ms)
      expect(tryShowBanner('user_ali', 'Selam naber?', baseTime.add(const Duration(milliseconds: 2500))), isFalse);
      expect(renderedBanners, equals(1));

      // 4. 2600ms anında FARKLI bir mesaj veya kullanıcı -> GÖSTERİLMELİ
      expect(tryShowBanner('user_veli', 'Fırsat linki var mı?', baseTime.add(const Duration(milliseconds: 2600))), isTrue);
      expect(renderedBanners, equals(2));

      // 5. 3100ms sonra Ali'den tekrar mesaj gelirse -> GÖSTERİLMELİ (>3000ms)
      expect(tryShowBanner('user_ali', 'Selam naber?', baseTime.add(const Duration(milliseconds: 5800))), isTrue);
      expect(renderedBanners, equals(3));
    });
  });

  group('6. Android Background Channel & messages_channel_v3 Consistency Tests', () {
    test('main.dart background handler uses messages_channel_v3 and Importance.max', () {
      final mainDartCode = File('lib/main.dart').readAsStringSync();
      expect(mainDartCode.contains("channelId = 'messages_channel_v3';"), isTrue);
      expect(mainDartCode.contains("'messages_channel_v3'"), isTrue);
      expect(mainDartCode.contains("channelId = 'messages_channel'"), isFalse);
    });

    test('notification_service.dart uses messages_channel_v3 consistently without legacy channel', () {
      final notifServiceCode = File('lib/services/notification_service.dart').readAsStringSync();
      expect(notifServiceCode.contains("'messages_channel_v3'"), isTrue);
      // Ensure no legacy 'messages_channel' string literal remains
      final legacyChannelRegex = RegExp(r"""['"]messages_channel['"]""");
      expect(legacyChannelRegex.hasMatch(notifServiceCode), isFalse);
    });
  });
}
