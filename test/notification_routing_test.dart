import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/notification_service.dart';

void main() {
  group('NotificationService.resolveRouting - Bildirim Yönlendirme ve Chat-Hijacking Koruma Testleri', () {
    test('1. İlginizi Çeken Kelime (Backend standart format) -> Fırsat Detayına gitmeli', () {
      final data = {
        'type': 'deal',
        'reason': 'keyword',
        'dealId': 'deal_iphone_15',
        'title': '🎯 İlginizi Çeken Kelime!',
        'body': '"iphone 15" içeren yeni fırsat',
        'dealTitle': 'Apple iPhone 15 128 GB',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_iphone_15'));
      expect(decision.commentId, isNull);
    });

    test('2. İlginizi Çeken Kelime (Chat-Hijacking Zaafiyeti Simülasyonu: type=keyword ve userId mevcut) -> Sohbete DEĞİL Fırsat Detayına gitmeli', () {
      final data = {
        'type': 'keyword',
        'reason': 'keyword',
        'dealId': 'deal_dyson_v15',
        'userId': 'user_recipient_target_999', // Hedef kullanıcının ID'si payload'da yer alsa bile
        'title': '🎯 İlginizi Çeken Kelime!',
        'body': '"dyson" içeren yeni fırsat',
      };

      final decision = NotificationService.resolveRouting(data);

      // KESİNLİKLE chat olmamalı, deal olmalı
      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_dyson_v15'));
      expect(decision.senderId, isNull);
    });

    test('3. Takip Edilen Kişi / Bot Bildirimi (reason=author / type=follow) -> Fırsat Detayına gitmeli', () {
      final data = {
        'type': 'deal',
        'reason': 'author',
        'dealId': 'deal_botkolik_1',
        'userId': 'botkolik',
        'title': '⚡ Botkolik Radarı!',
        'body': 'Botkolik yeni bir fırsat yakaladı',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_botkolik_1'));
    });

    test('4. Kategori Takip Bildirimi (reason=category) -> Fırsat Detayına gitmeli', () {
      final data = {
        'type': 'deal',
        'reason': 'category',
        'dealId': 'deal_elektronik_88',
        'title': '🎯 Yeni Fırsat!',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_elektronik_88'));
    });

    test('5. Fırsata Yapılan Yorum Bildirimi -> İlgili Fırsat Detayına ve Yoruma Odaklanmalı', () {
      final data = {
        'type': 'comment',
        'dealId': 'deal_macbook_pro',
        'commentId': 'comment_top_level_123',
        'userId': 'commenter_user_id',
        'title': '💬 Ahmet fırsatınıza yorum yaptı',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_macbook_pro'));
      expect(decision.commentId, equals('comment_top_level_123'));
    });

    test('6. Yoruma Verilen Cevap Bildirimi -> İlgili Fırsat Detayına ve Cevaba Odaklanmalı', () {
      final data = {
        'type': 'comment_reply',
        'dealId': 'deal_ps5',
        'commentId': 'reply_sub_456',
        'title': '💬 Mehmet yorumunuza cevap verdi',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_ps5'));
      expect(decision.commentId, equals('reply_sub_456'));
    });

    test('7. Birebir Sohbet Mesajı (type=message) -> Doğru Gönderici ile Chat Ekranına gitmeli', () {
      final data = {
        'type': 'message',
        'senderId': 'user_alice_123',
        'senderName': '💬 Alice',
        'messageText': 'Selam, fırsat hala geçerli mi?',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.chat));
      expect(decision.senderId, equals('user_alice_123'));
      expect(decision.senderName, equals('Alice'));
    });

    test('8. Birebir Sohbet Mesajında Paylaşılan Fırsat Kartı -> Chat Ekranına Fırsat Bilgisiyle gitmeli', () {
      final data = {
        'type': 'message',
        'senderId': 'user_bob_456',
        'senderName': 'Bob',
        'messageText': 'Şu fırsata bakar mısın?',
        'dealId': 'deal_shared_tv',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.chat));
      expect(decision.senderId, equals('user_bob_456'));
      expect(decision.dealId, equals('deal_shared_tv'));
    });

    test('9. Göndericisi olmayan Mesaj Bildirimi -> Mesajlar Listesine (Gelen Kutusu) gitmeli', () {
      final data = {
        'type': 'message',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.messagesList));
    });

    test('10. Yönetici Duyurusu (type=admin_message) -> Admin Sohbetine gitmeli', () {
      final data = {
        'type': 'admin_message',
        'messageId': 'admin_msg_001',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.adminChat));
    });

    test('11. Onay Bekleyen Fırsat (type=admin_deal) -> Admin Paneline gitmeli', () {
      final data = {
        'type': 'admin_deal',
        'dealId': 'deal_pending_77',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.adminScreen));
      expect(decision.dealId, equals('deal_pending_77'));
    });

    test('12. Pazarlama Bildirimi (dealId içeren) -> Fırsat Detayına gitmeli', () {
      final data = {
        'type': 'marketing',
        'dealId': 'deal_black_friday',
        'title': '🔥 Süper Cuma İndirimi!',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_black_friday'));
    });

    test('13. Pazarlama Bildirimi (dealId içermeyen genel duyuru) -> Hiçbir ekrana gitmeyip anasayfada kalmalı', () {
      final data = {
        'type': 'marketing',
        'title': '🔥 Bayram Tebriği!',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.none));
    });

    test('14. Snake_case alan desteği (deal_id, comment_id) -> Doğru parametrelerle çözümlenmeli', () {
      final data = {
        'type': 'deal',
        'deal_id': 'deal_snake_case_1',
        'comment_id': 'comment_snake_1',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_snake_case_1'));
      expect(decision.commentId, equals('comment_snake_1'));
    });

    test('15. Fırsat Gönderim Onayı (type=submission_status, status=approved) -> Fırsat Detayına gitmeli', () {
      final data = {
        'type': 'submission_status',
        'status': 'approved',
        'dealId': 'deal_user_sub_88',
        'title': '🎉 Fırsatınız Onaylandı!',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.deal));
      expect(decision.dealId, equals('deal_user_sub_88'));
    });

    test('16. Fırsat Gönderim Reddi (type=submission_status, status=rejected) -> Bildirim Merkezine gitmeli', () {
      final data = {
        'type': 'submission_status',
        'status': 'rejected',
        'dealId': 'deal_user_sub_99',
        'title': 'ℹ️ Fırsatınız Reddedildi',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.adminNotifications));
    });

    test('17. Active Deal Screen Tracking (Self-Screen Spam Protection) -> activeDealId eşleşme kontrolü', () {
      NotificationService.activeDealId = 'deal_test_active_456';
      expect(NotificationService.activeDealId, equals('deal_test_active_456'));

      // Detay sayfasından çıkıldığında null olmalı
      NotificationService.activeDealId = null;
      expect(NotificationService.activeDealId, isNull);
    });

    test('18. Admin Screen Active Tracking -> isAdminScreenActive kontrolü', () {
      NotificationService.isAdminScreenActive = true;
      expect(NotificationService.isAdminScreenActive, isTrue);

      // Admin panelinden çıkıldığında false olmalı
      NotificationService.isAdminScreenActive = false;
      expect(NotificationService.isAdminScreenActive, isFalse);
    });

    test('19. Chat Active Screen Tracking -> activeChatUserId kontrolü', () {
      NotificationService.activeChatUserId = 'user_chat_target_789';
      expect(NotificationService.activeChatUserId, equals('user_chat_target_789'));

      NotificationService.activeChatUserId = null;
      expect(NotificationService.activeChatUserId, isNull);
    });

    // ──────────────────────────────────────────────────────────
    // NOTIF-15: Topluluk Kuponu Yönlendirme Testleri
    // ──────────────────────────────────────────────────────────

    test('20. Topluluk Kuponu Bildirimi (type=coupon) -> Kuponlar Sayfasına (Topluluk Sekmesi) gitmeli', () {
      final data = {
        'type': 'coupon',
        'reason': 'community',
        'kuponId': 'kupon_trendyol_abc123',
        'magazaAdi': 'Trendyol',
        'title': '🎟️ Trendyol Kuponu!',
        'body': '@Ahmet, Trendyol için yeni bir indirim kuponu paylaştı',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.coupons));
      expect(decision.kuponId, equals('kupon_trendyol_abc123'));
      expect(decision.initialTabIndex, equals(1)); // Topluluk Kuponları sekmesi
      expect(decision.dealId, isNull); // Fırsat değil, kupon!
    });

    test('21. Topluluk Kuponu Bildirimi (type=community_coupon) -> Kuponlar Sayfasına gitmeli', () {
      final data = {
        'type': 'community_coupon',
        'reason': 'community',
        'couponId': 'kupon_hepsiburada_xyz789',
        'magazaAdi': 'Hepsiburada',
        'title': '🎟️ Hepsiburada Kuponu!',
        'body': '@Mehmet yeni bir indirim kuponu paylaştı',
      };

      final decision = NotificationService.resolveRouting(data);

      expect(decision.destination, equals(NotificationDestinationType.coupons));
      expect(decision.kuponId, equals('kupon_hepsiburada_xyz789'));
      expect(decision.initialTabIndex, equals(1));
    });

    test('22. Topluluk Kuponu Bildirimi (Chat-Hijacking Koruması: userId mevcut olsa bile) -> Kuponlar Sayfasına gitmeli', () {
      final data = {
        'type': 'coupon',
        'reason': 'community',
        'kuponId': 'kupon_amazon_def456',
        'userId': 'user_coupon_sharer_123', // userId payload'da olsa bile
        'magazaAdi': 'Amazon',
        'title': '🎟️ Amazon Kuponu!',
      };

      final decision = NotificationService.resolveRouting(data);

      // KESİNLİKLE chat olmamalı, coupons olmalı
      expect(decision.destination, equals(NotificationDestinationType.coupons));
      expect(decision.kuponId, equals('kupon_amazon_def456'));
      expect(decision.senderId, isNull);
    });

    test('23. Coupons Screen Active Tracking -> isCouponsScreenActive kontrolü', () {
      NotificationService.isCouponsScreenActive = true;
      expect(NotificationService.isCouponsScreenActive, isTrue);

      // Kuponlar sayfasından çıkıldığında false olmalı
      NotificationService.isCouponsScreenActive = false;
      expect(NotificationService.isCouponsScreenActive, isFalse);
    });
  });
}

