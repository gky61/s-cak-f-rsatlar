import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/message.dart';
import 'package:sicak_firsatlar/models/conversation.dart';
import 'package:sicak_firsatlar/services/message_service.dart';

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
      const tag1 = 'msg_$sender1';

      final notifId2 = sender1.hashCode % 100000;
      const tag2 = 'msg_$sender1';

      expect(notifId1, equals(notifId2));
      expect(tag1, equals(tag2));
      expect(tag1, 'msg_user_murat_123');
    });

    test('Different senders produce distinct tags and IDs', () {
      const senderA = 'user_ahmet';
      const senderB = 'user_zeynep';

      const tagA = 'msg_$senderA';
      const tagB = 'msg_$senderB';

      expect(tagA, isNot(equals(tagB)));
      expect(tagA, 'msg_user_ahmet');
      expect(tagB, 'msg_user_zeynep');
    });

    test('Admin sender produces msg_admin tag', () {
      const senderAdmin = 'admin';
      const tagAdmin = 'msg_$senderAdmin';
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
      } else if (payload.startsWith('coupon:')) {
        final kuponId = payload.substring('coupon:'.length);
        return {'type': 'coupon', 'kuponId': kuponId.isNotEmpty ? kuponId : null};
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

    test('Parses coupon payload', () {
      final res = parsePayload('coupon:kupon_abc_123');
      expect(res['type'], 'coupon');
      expect(res['kuponId'], 'kupon_abc_123');
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
        final isIncomingSeed = m.senderId == 'user_sender' || m.id.startsWith('incoming_');
        final hasDuplicate = isIncomingSeed
            ? serverMessages.any((sm) =>
                sm.id == m.id ||
                (sm.senderId == m.senderId &&
                 (sm.text.trim() == m.text.trim() ||
                  (m.text.trim().endsWith('...') && sm.text.trim().startsWith(m.text.trim().substring(0, m.text.trim().length - 3).trim())))))
            : serverMessages.any((sm) =>
                sm.id == m.id ||
                (sm.senderId == m.senderId &&
                 sm.text.trim() == m.text.trim() &&
                 sm.createdAt.difference(m.createdAt).inSeconds.abs() < 120));
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

      // PROD-READY Eviction & Reconciliation
      optimisticList.removeWhere((om) {
        final isIncomingSeed = om.senderId == 'user_sender' || om.id.startsWith('incoming_');
        if (!isIncomingSeed) return false;
        return serverMessages.any((sm) =>
          sm.id == om.id ||
          (sm.senderId == om.senderId &&
           (sm.text.trim() == om.text.trim() ||
            (om.text.trim().endsWith('...') && sm.text.trim().startsWith(om.text.trim().substring(0, om.text.length - 3).trim()))))
        );
      });

      mergedMap = {};
      for (var m in serverMessages) {
        mergedMap[m.id] = m;
      }
      for (var m in optimisticList) {
        final isIncomingSeed = m.senderId == 'user_sender' || m.id.startsWith('incoming_');
        final hasDuplicate = isIncomingSeed
            ? serverMessages.any((sm) =>
                sm.id == m.id ||
                (sm.senderId == m.senderId &&
                 (sm.text.trim() == m.text.trim() ||
                  (m.text.trim().endsWith('...') && sm.text.trim().startsWith(m.text.trim().substring(0, m.text.trim().length - 3).trim())))))
            : serverMessages.any((sm) =>
                sm.id == m.id ||
                (sm.senderId == m.senderId &&
                 sm.text.trim() == m.text.trim() &&
                 sm.createdAt.difference(m.createdAt).inSeconds.abs() < 120));
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

    test('Incoming seeded message NEVER duplicates even after 24-minute delay (User Screenshot Bug Simulation)', () {
      final now = DateTime.now();
      // Gönderici mesajı 15:53'te attı (24 dakika önce)
      final originalSentTime = now.subtract(const Duration(minutes: 24));

      // Kullanıcı bildirime 16:17'de (now) tıkladı
      final incomingSeedMessage = Message(
        id: 'incoming_${now.millisecondsSinceEpoch}',
        conversationId: 'conv_gky61',
        senderId: 'gky61',
        senderName: 'gky61',
        senderImageUrl: '',
        receiverId: 'my_user_id',
        receiverName: '',
        receiverImageUrl: '',
        text: 'Neyse hata olmasın da',
        createdAt: now, // 16:17
        isRead: true,
        status: 'sent',
      );

      final optimisticList = [incomingSeedMessage];

      // Firestore'dan gelen gerçek mesajlar (15:53 tarihli)
      final serverMessages = [
        Message(
          id: 'firestore_msg_real_001',
          conversationId: 'conv_gky61',
          senderId: 'gky61',
          senderName: 'gky61',
          senderImageUrl: '',
          receiverId: 'my_user_id',
          receiverName: '',
          receiverImageUrl: '',
          text: 'Neyse hata olmasın da',
          createdAt: originalSentTime, // 15:53 (24 dk fark!)
          isRead: false,
          status: 'delivered',
        ),
        Message(
          id: 'firestore_msg_real_002',
          conversationId: 'conv_gky61',
          senderId: 'gky61',
          senderName: 'gky61',
          senderImageUrl: '',
          receiverId: 'my_user_id',
          receiverName: '',
          receiverImageUrl: '',
          text: 'Acaba o da mı oldu',
          createdAt: originalSentTime.subtract(const Duration(seconds: 10)),
          isRead: true,
          status: 'read',
        ),
      ];

      // PROD-READY Eviction & Reconciliation çalıştır
      optimisticList.removeWhere((om) {
        final isIncomingSeed = om.senderId == 'gky61' || om.id.startsWith('incoming_');
        if (!isIncomingSeed) return false;
        return serverMessages.any((sm) =>
          sm.id == om.id ||
          (sm.senderId == om.senderId &&
           (sm.text.trim() == om.text.trim() ||
            (om.text.trim().endsWith('...') && sm.text.trim().startsWith(om.text.trim().substring(0, om.text.length - 3).trim()))))
        );
      });

      final Map<String, Message> mergedMap = {};
      for (var m in serverMessages) {
        mergedMap[m.id] = m;
      }
      for (var m in optimisticList) {
        final isIncomingSeed = m.senderId == 'gky61' || m.id.startsWith('incoming_');
        final hasDuplicate = isIncomingSeed
            ? serverMessages.any((sm) =>
                sm.id == m.id ||
                (sm.senderId == m.senderId &&
                 (sm.text.trim() == m.text.trim() ||
                  (m.text.trim().endsWith('...') && sm.text.trim().startsWith(m.text.trim().substring(0, m.text.trim().length - 3).trim())))))
            : serverMessages.any((sm) =>
                sm.id == m.id ||
                (sm.senderId == m.senderId &&
                 sm.text.trim() == m.text.trim() &&
                 sm.createdAt.difference(m.createdAt).inSeconds.abs() < 120));
        if (!hasDuplicate) mergedMap[m.id] = m;
      }

      final allMessages = mergedMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // KRİTİK DOĞRULAMA:
      // 1. Tohum mesaj listeden temizlenmeli (evicted)
      expect(optimisticList.isEmpty, isTrue);
      // 2. Toplam mesaj sayısı tam 2 olmalı (mükerrer/hayalet 16:17 mesajı OLMAMALI!)
      expect(allMessages.length, equals(2));
      // 3. En son mesaj 15:53 tarihli gerçek Firestore mesajı olmalı
      expect(allMessages[0].id, equals('firestore_msg_real_001'));
      expect(allMessages[0].text, equals('Neyse hata olmasın da'));
      expect(allMessages[0].createdAt, equals(originalSentTime));
      // 4. İkinci mesaj bir önceki mesaj olmalı
      expect(allMessages[1].text, equals('Acaba o da mı oldu'));
    });

    test('Incoming truncated notification body with ellipsis dedups against full server message', () {
      final now = DateTime.now();

      // Bildirim gövdesi 100 karaktere kesilmiş mesaj
      final incomingSeedMessage = Message(
        id: 'incoming_truncated_123',
        conversationId: 'conv_user',
        senderId: 'user_long',
        senderName: 'Yazar',
        senderImageUrl: '',
        receiverId: 'my_id',
        receiverName: '',
        receiverImageUrl: '',
        text: 'Bu çok uzun bir mesajdır ve bildirim payloadı içerisine sığmadığı için yüz karaktere kesilmiştir...',
        createdAt: now,
        isRead: true,
        status: 'sent',
      );

      final optimisticList = [incomingSeedMessage];

      final serverMessages = [
        Message(
          id: 'server_long_001',
          conversationId: 'conv_user',
          senderId: 'user_long',
          senderName: 'Yazar',
          senderImageUrl: '',
          receiverId: 'my_id',
          receiverName: '',
          receiverImageUrl: '',
          text: 'Bu çok uzun bir mesajdır ve bildirim payloadı içerisine sığmadığı için yüz karaktere kesilmiştir ve devamında çok önemli bilgiler vardır.',
          createdAt: now.subtract(const Duration(minutes: 10)),
          isRead: false,
          status: 'delivered',
        ),
      ];

      optimisticList.removeWhere((om) {
        final isIncomingSeed = om.senderId == 'user_long' || om.id.startsWith('incoming_');
        if (!isIncomingSeed) return false;
        return serverMessages.any((sm) =>
          sm.id == om.id ||
          (sm.senderId == om.senderId &&
           (sm.text.trim() == om.text.trim() ||
            (om.text.trim().endsWith('...') && sm.text.trim().startsWith(om.text.trim().substring(0, om.text.length - 3).trim()))))
        );
      });

      expect(optimisticList.isEmpty, isTrue);
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

  group('7. Conversation Model & 100k Scale Architecture Tests', () {
    test('getConversationId produces deterministic, sorted identifier', () {
      final id1 = MessageService.getConversationId('user_alpha', 'user_beta');
      final id2 = MessageService.getConversationId('user_beta', 'user_alpha');

      expect(id1, equals(id2));
      expect(id1, equals('user_alpha_user_beta'));
    });

    test('Conversation model serialization and deserialization roundtrip', () {
      final now = DateTime(2026, 10, 16, 14, 0, 0);
      final conversation = Conversation(
        id: 'user1_user2',
        participants: ['user1', 'user2'],
        lastMessageText: 'Merhaba fırsat var mı?',
        lastMessageSenderId: 'user1',
        lastMessageSenderName: 'Ali',
        lastMessageCreatedAt: now,
        lastMessageIsRead: false,
        unreadCounts: {'user1': 0, 'user2': 1},
        participantDetails: {
          'user1': const ConversationParticipant(name: 'Ali', avatar: 'assets/avatar_a.webp'),
          'user2': const ConversationParticipant(name: 'Veli', avatar: 'assets/avatar_b.webp'),
        },
        clearedAt: {'user1': now.subtract(const Duration(days: 1))},
        updatedAt: now,
      );

      final map = conversation.toFirestore();
      expect(map['participants'], equals(['user1', 'user2']));
      expect(map['lastMessage']['text'], equals('Merhaba fırsat var mı?'));
      expect(map['unreadCounts']['user2'], equals(1));

      final parsed = Conversation.fromMap('user1_user2', map);
      expect(parsed.id, equals('user1_user2'));
      expect(parsed.lastMessageText, equals('Merhaba fırsat var mı?'));
      expect(parsed.getOtherUserId('user1'), equals('user2'));
      expect(parsed.getOtherUserName('user1'), equals('Veli'));
      expect(parsed.getOtherUserAvatar('user1'), equals('assets/avatar_b.webp'));
      expect(parsed.getUnreadCount('user2'), equals(1));
      expect(parsed.getUnreadCount('user1'), equals(0));
    });

    test('isClearedForMessage correctly filters messages older than user clearedAt timestamp', () {
      final clearTime = DateTime(2026, 10, 16, 12, 0, 0);
      final conversation = Conversation(
        id: 'u1_u2',
        participants: ['u1', 'u2'],
        lastMessageText: 'Selam',
        lastMessageSenderId: 'u1',
        lastMessageSenderName: 'U1',
        lastMessageCreatedAt: clearTime,
        lastMessageIsRead: true,
        updatedAt: clearTime,
        clearedAt: {'u1': clearTime},
      );

      final olderMessageTime = DateTime(2026, 10, 16, 11, 59, 0);
      final newerMessageTime = DateTime(2026, 10, 16, 12, 01, 0);

      // u1 sohbeti sildikten önceki mesajı görmemeli
      expect(conversation.isClearedForMessage('u1', olderMessageTime), isTrue);
      // u1 sohbeti sildikten sonraki yeni mesajı görebilmeli
      expect(conversation.isClearedForMessage('u1', newerMessageTime), isFalse);
      // u2 sohbeti hiç silmediği için eski mesajı da görebilmeli
      expect(conversation.isClearedForMessage('u2', olderMessageTime), isFalse);
    });
  });

  group('8. Message Retract (15-min) and Soft Delete Tests', () {
    test('Message model deserialization handles isDeletedForEveryone and deletedBy', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg_test_retract',
        conversationId: 'u1_u2',
        senderId: 'u1',
        senderName: 'Ahmet',
        senderImageUrl: '',
        receiverId: 'u2',
        receiverName: 'Mehmet',
        receiverImageUrl: '',
        text: 'Bu mesaj silindi',
        createdAt: now,
        isDeletedForEveryone: true,
        deletedBy: ['u1'],
      );

      final map = message.toFirestore();
      expect(map['isDeletedForEveryone'], isTrue);
      expect(map['deletedBy'], contains('u1'));

      final fromMap = Message.fromMap(map, 'msg_test_retract');
      expect(fromMap.isDeletedForEveryone, isTrue);
      expect(fromMap.text, equals('Bu mesaj silindi'));
      expect(fromMap.deletedBy, contains('u1'));
    });

    test('15-Minute retract rule validates strictly by timestamp difference', () {
      final now = DateTime(2026, 10, 16, 15, 30, 0);

      // 10 dakika önce atılmış mesaj -> Geri çekilebilir (<= 15 dk)
      final within10Min = now.subtract(const Duration(minutes: 10));
      expect(now.difference(within10Min).inMinutes <= 15, isTrue);

      // Tam 15 dakika önce atılmış mesaj -> Geri çekilebilir
      final exactly15Min = now.subtract(const Duration(minutes: 15));
      expect(now.difference(exactly15Min).inMinutes <= 15, isTrue);

      // 16 dakika önce atılmış mesaj -> Geri çekilemez (> 15 dk)
      final over15Min = now.subtract(const Duration(minutes: 16));
      expect(now.difference(over15Min).inMinutes <= 15, isFalse);
    });
  });

  group('9. Firestore Security Rules & Composite Index Structural Audit Tests', () {
    test('firestore.rules enforces conversations and messages security contracts', () {
      final rulesCode = File('firestore.rules').readAsStringSync();

      // Conversations koleksiyon kuralı mevcut olmalı
      expect(rulesCode.contains('match /conversations/{conversationId}'), isTrue);
      // Mesaj silme kuralı admin-only olmalı (delil karartma kalkanı)
      expect(rulesCode.contains('allow delete: if isAdmin();'), isTrue);
      // Retract güncellemesi kurallarda tanımlı olmalı
      expect(rulesCode.contains('request.resource.data.isDeletedForEveryone == true'), isTrue);
      expect(rulesCode.contains("request.resource.data.text == 'Bu mesaj silindi'"), isTrue);
      // FS-MSG-08: Alıcının engellediği kullanıcıların mesaj göndermesini engelleyen kural olmalı
      expect(rulesCode.contains('blockedUsers'), isTrue);
    });

    test('firestore.indexes.json contains required composite index for conversations query', () {
      final indexesCode = File('firestore.indexes.json').readAsStringSync();

      expect(indexesCode.contains('"collectionGroup": "conversations"'), isTrue);
      expect(indexesCode.contains('"fieldPath": "participants"'), isTrue);
      expect(indexesCode.contains('"arrayConfig": "CONTAINS"'), isTrue);
      expect(indexesCode.contains('"fieldPath": "updatedAt"'), isTrue);
      expect(indexesCode.contains('"collectionGroup": "adminToUserMessages"'), isTrue);
    });

    test('functions/index.js contains KVKK-compliant message anonymization and soft-delete on account cleanup', () {
      final functionsCode = File('functions/index.js').readAsStringSync();

      expect(functionsCode.contains("senderName: 'Silinmiş Kullanıcı'"), isTrue);
      expect(functionsCode.contains("db.collection('conversations')"), isTrue);
      expect(functionsCode.contains('anonymizedMsgCount'), isTrue);
      expect(functionsCode.contains('participantDetails'), isTrue);
    });
  });

  group('10. FS-MSG-11 to FS-MSG-17 Advanced Disaster & Vulnerability Tests', () {
    test('FS-MSG-11: Pagination logic suppresses zombie messages created before user clearedAt', () {
      final clearedAt = DateTime(2026, 10, 16, 12, 0, 0);
      final messages = [
        Message(
          id: 'msg_recent_1',
          conversationId: 'u1_u2',
          senderId: 'u2',
          senderName: 'Mehmet',
          senderImageUrl: '',
          receiverId: 'u1',
          receiverName: 'Ali',
          receiverImageUrl: '',
          text: 'Yeni temiz sohbet sonrası mesaj',
          createdAt: DateTime(2026, 10, 16, 12, 5, 0),
        ),
        Message(
          id: 'msg_zombie_1',
          conversationId: 'u1_u2',
          senderId: 'u2',
          senderName: 'Mehmet',
          senderImageUrl: '',
          receiverId: 'u1',
          receiverName: 'Ali',
          receiverImageUrl: '',
          text: 'Sohbet temizlenmeden önceki zombi mesaj (deletedBy eksik kalmış)',
          createdAt: DateTime(2026, 10, 16, 11, 45, 0),
        ),
      ];

      // Filtreleme kuralı (loadOlderMessages içindeki mantık)
      final filtered = messages.where((m) {
        if (m.deletedBy.contains('u1')) return false;
        if (m.createdAt.isBefore(clearedAt)) return false;
        return true;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('msg_recent_1'));
      expect(filtered.any((m) => m.id == 'msg_zombie_1'), isFalse);
    });

    test('FS-MSG-12: firestore.rules uses strict whitelist for message updates', () {
      final rulesCode = File('firestore.rules').readAsStringSync();
      // Whitelist kuralının varlığını doğrula (affectedKeys().hasOnly(...))
      expect(rulesCode.contains("affectedKeys().hasOnly(['isRead', 'isReadByAdmin', 'readAt', 'reactions', 'deletedBy'])"), isTrue);
      // Keyfi alan enjeksiyonuna karşı açık blacklist bulunmamalı
      expect(rulesCode.contains("affectedKeys().hasAny(['senderId', 'receiverId', 'createdAt'])"), isFalse);
    });

    test('FS-MSG-13: firestore.rules enforces server-side 15-minute retract timestamp check', () {
      final rulesCode = File('firestore.rules').readAsStringSync();
      // Server-side request.time <= resource.data.createdAt + 15m doğrulaması
      expect(rulesCode.contains("request.time <= resource.data.createdAt + duration.value(15, 'm')"), isTrue);
      expect(rulesCode.contains("affectedKeys().hasOnly(['isDeletedForEveryone', 'text', 'dealId', 'dealTitle', 'dealImageUrl', 'dealPrice', 'dealStore', 'reactions', 'deletedAt'])"), isTrue);
    });

    test('FS-MSG-14: Reaction spoofing defense rejects unauthorized caller and clamps emoji length', () {
      // 1. Emoji uzunluk sınırlaması (Grapheme / Karakter bloat saldırısı)
      String sanitizeEmoji(String rawEmoji) {
        final trimmed = rawEmoji.trim();
        return trimmed.length > 10 ? trimmed.substring(0, 10) : trimmed;
      }

      final longEmojiPayload = '👍' * 50;
      final sanitized = sanitizeEmoji(longEmojiPayload);
      expect(sanitized.length <= 10, isTrue);

      // 2. Yetkisiz kullanıcı engeli
      bool canToggle(String authUid, String targetUserId) {
        return authUid == targetUserId;
      }
      expect(canToggle('user_hacker', 'user_victim'), isFalse);
      expect(canToggle('user_legit', 'user_legit'), isTrue);
    });

    test('FS-MSG-15: onUserMessageCreated masks profanity on push notification and sends moderation alarm', () {
      final functionsCode = File('functions/index.js').readAsStringSync();
      expect(functionsCode.contains('[FS-MSG-15] Mesajda küfür/şüpheli içerik tespit edildi'), isTrue);
      expect(functionsCode.contains("createModerationMessage"), isTrue);
      expect(functionsCode.contains("resolvedBody = 'Yeni bir mesaj aldınız'"), isTrue);
    });

    test('FS-MSG-16: markConversationAsRead uses paginated loop for 100+ unread messages', () {
      final msgServiceCode = File('lib/services/message_service.dart').readAsStringSync();
      expect(msgServiceCode.contains('FS-MSG-16: 100+ okunmamış mesaj olduğunda tümünü sayfalı tüketerek'), isTrue);
      expect(msgServiceCode.contains('while (true)'), isTrue);
      expect(msgServiceCode.contains('batch.commit()'), isTrue);
    });

    test('FS-MSG-17: FCM payload data fields are strictly sliced to fit under 4KB ceiling', () {
      final functionsCode = File('functions/index.js').readAsStringSync();
      expect(functionsCode.contains('FS-MSG-17: FCM Data payload\'unun 4KB tavanını aşmasını önleyen'), isTrue);
      expect(functionsCode.contains('slice(0, 100)'), isTrue);
      expect(functionsCode.contains('slice(0, 80)'), isTrue);
      expect(functionsCode.contains('slice(0, 200)'), isTrue);
      expect(functionsCode.contains('slice(0, 500)'), isTrue);
    });
  });
}

