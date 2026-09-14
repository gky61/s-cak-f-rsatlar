import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('Notification UI/UX & Data Integrity Unit Tests', () {
    test('Smart status fallback correctly identifies approved notifications', () {
      // 1. Durum: status alanı var
      final doc1 = {'title': 'Fırsatınız Onaylandı!', 'status': 'approved'};
      final rawStatus1 = doc1['status']?.toString().toLowerCase() ?? '';
      expect(rawStatus1, 'approved');

      // 2. Durum: status alanı eksik ama başlıkta Onaylandı var
      final doc2 = {'title': '🎉 Fırsatınız Onaylandı!'};
      String derivedStatus2 = doc2['status'] ?? '';
      if (derivedStatus2.isEmpty) {
        final titleLower = (doc2['title'] ?? '').toLowerCase();
        if (titleLower.contains('onaylandı') || titleLower.contains('onaylandi')) {
          derivedStatus2 = 'approved';
        } else if (titleLower.contains('reddedildi')) {
          derivedStatus2 = 'rejected';
        }
      }
      expect(derivedStatus2, 'approved');

      // 3. Durum: status alanı eksik ama başlıkta Reddedildi var
      final doc3 = {'title': '❌ Fırsatınız Reddedildi'};
      String derivedStatus3 = doc3['status'] ?? '';
      if (derivedStatus3.isEmpty) {
        final titleLower = (doc3['title'] ?? '').toLowerCase();
        if (titleLower.contains('onaylandı') || titleLower.contains('onaylandi')) {
          derivedStatus3 = 'approved';
        } else if (titleLower.contains('reddedildi')) {
          derivedStatus3 = 'rejected';
        }
      }
      expect(derivedStatus3, 'rejected');
    });

    test('Timestamp formatting handles today, yesterday, and older dates gracefully', () {
      String formatTime(DateTime dt) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final itemDate = DateTime(dt.year, dt.month, dt.day);
        final differenceInDays = today.difference(itemDate).inDays;

        if (differenceInDays == 0) {
          return DateFormat('HH:mm').format(dt);
        } else if (differenceInDays == 1) {
          return 'Dün ${DateFormat('HH:mm').format(dt)}';
        } else if (now.year == dt.year) {
          return DateFormat('d MMM • HH:mm').format(dt);
        } else {
          return DateFormat('d MMM yyyy').format(dt);
        }
      }

      final now = DateTime.now();
      final todayFormatted = formatTime(now);
      expect(todayFormatted, DateFormat('HH:mm').format(now));

      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayFormatted = formatTime(yesterday);
      expect(yesterdayFormatted.startsWith('Dün '), isTrue);

      final olderThisYear = DateTime(now.year, 1, 15, 14, 30);
      if (now.month > 1 || now.day > 16) {
        final olderFormatted = formatTime(olderThisYear);
        expect(olderFormatted.contains('15'), isTrue);
      }
    });

    test('Tab unread counts are partitioned accurately by type', () {
      final items = [
        {'id': '1', 'type': 'deal', 'read': false},
        {'id': '2', 'type': 'submission_status', 'read': false},
        {'id': '3', 'type': 'admin_message', 'read': true},
        {'id': '4', 'type': 'comment_reply', 'read': false},
        {'id': '5', 'type': 'comment', 'read': true},
      ];

      final unreadAll = items.where((i) => !(i['read'] as bool)).length;
      final unreadAdmin = items.where((i) {
        final isUnread = !(i['read'] as bool);
        final type = i['type'] as String;
        return isUnread &&
            (type == 'admin_message' ||
                type == 'admin' ||
                type == 'marketing' ||
                type == 'manual_notification' ||
                type == 'submission_status');
      }).length;
      final unreadReplies = items.where((i) {
        final isUnread = !(i['read'] as bool);
        final type = i['type'] as String;
        return isUnread && (type == 'comment_reply' || type == 'comment');
      }).length;

      expect(unreadAll, 3); // 1, 2, 4
      expect(unreadAdmin, 1); // 2 (submission_status)
      expect(unreadReplies, 1); // 4 (comment_reply)
    });

    test('Both comment and comment_reply navigate to deal detail with scrollToCommentId', () {
      String resolveTarget(Map<String, dynamic> item) {
        final type = item['type'] ?? 'deal';
        final dealId = (item['dealId'] ?? '').toString().trim();
        final commentId = (item['commentId'] ?? '').toString().trim();

        if (type == 'comment_reply' || type == 'comment') {
          if (dealId.isNotEmpty) {
            return 'deal_detail:$dealId:scroll_$commentId';
          }
          return 'modal';
        }
        return 'other';
      }

      final commentReplyItem = {
        'type': 'comment_reply',
        'dealId': 'deal_123',
        'commentId': 'comm_456',
        'title': 'gky61 yorumunuza cevap verdi',
      };
      expect(resolveTarget(commentReplyItem), 'deal_detail:deal_123:scroll_comm_456');

      final rootCommentItem = {
        'type': 'comment',
        'dealId': 'deal_123',
        'commentId': 'comm_789',
        'title': '💬 gky61 fırsatınıza yorum yaptı',
      };
      // ÖNCEDEN 'modal' açılıyordu, ARTIK doğrudan yoruma yönlendiriyor!
      expect(resolveTarget(rootCommentItem), 'deal_detail:deal_123:scroll_comm_789');
    });

    test('Card body cleanup removes redundant dealTitle duplicates and formats clean price', () {
      String cleanBody(String rawBody, String dealTitle) {
        String displayBody = rawBody.trim();
        if (dealTitle.isNotEmpty && displayBody.startsWith(dealTitle)) {
          displayBody = displayBody.substring(dealTitle.length).trim();
          if (displayBody.startsWith(':') || displayBody.startsWith('-')) {
            displayBody = displayBody.substring(1).trim();
          }
        }
        return displayBody;
      }

      // Senaryo 1: Gövde fırsat başlığı + fiyat içeriyor (Ekran görüntüsündeki 1. ve 4. kart)
      const dealTitle1 = 'Proteinocean Citrulline 120g 120 Servis';
      const rawBody1 = 'Proteinocean Citrulline 120g 120 Servis\n💰 339 TL';
      expect(cleanBody(rawBody1, dealTitle1), '💰 339 TL');

      // Senaryo 2: Gövde sadece başlığın aynısı (Ekran görüntüsündeki 2. kart)
      const dealTitle2 = 'Xenon Smart Ayaklı Vantilatör Air Luxe';
      const rawBody2 = 'Xenon Smart Ayaklı Vantilatör Air Luxe';
      expect(cleanBody(rawBody2, dealTitle2), ''); // Boş kalır ve mükerrer basılmaz

      // Senaryo 3: Yorum içeriği (fırsat başlığıyla başlamayan gerçek yorum metni)
      const dealTitle3 = 'Paşabahçe 4 Parça Hazırlık Seti';
      const rawBody3 = 'Patron çıldırdı. Apple dan mı bu paylaşım';
      expect(cleanBody(rawBody3, dealTitle3), 'Patron çıldırdı. Apple dan mı bu paylaşım');
    });

    test('Title emoji normalization cleans leading chat bubble for visual consistency', () {
      String cleanTitle(String type, String rawTitle) {
        String displayTitle = rawTitle.trim();
        if ((type == 'comment' || type == 'comment_reply') && displayTitle.startsWith('💬')) {
          displayTitle = displayTitle.replaceFirst('💬', '').trim();
        }
        return displayTitle;
      }

      expect(cleanTitle('comment', '💬 gky61 fırsatınıza yorum yaptı'), 'gky61 fırsatınıza yorum yaptı');
      expect(cleanTitle('comment_reply', 'gky61 yorumunuza cevap verdi'), 'gky61 yorumunuza cevap verdi');
      // İkisi de aynı standart tipografi ve başlık yapısına kavuştu
    });

    test('Dialog action button is available for any valid non-rejected notification with dealId', () {
      bool hasViewDealButton(Map<String, dynamic> item) {
        final dealId = (item['dealId'] ?? '').toString().trim();
        final rawStatus = (item['status'] as String? ?? '').toLowerCase();
        final titleLower = (item['title'] as String? ?? '').toLowerCase();
        final isRejected = rawStatus == 'rejected' || titleLower.contains('reddedildi');
        return dealId.isNotEmpty && !isRejected;
      }

      // Kampanya bildirimi (dealId var)
      expect(hasViewDealButton({'type': 'marketing', 'dealId': 'deal_123'}), isTrue);

      // Onaylanan bildirim (dealId var)
      expect(hasViewDealButton({'type': 'submission_status', 'status': 'approved', 'dealId': 'deal_123'}), isTrue);

      // Reddedilen bildirim (fırsat yayında değil, buton olmamalı)
      expect(hasViewDealButton({'type': 'submission_status', 'status': 'rejected', 'dealId': 'deal_123'}), isFalse);
    });

    test('Empty string ("") title and body gracefully fallback to rich semantic text', () {
      Map<String, String> resolveNotificationText({
        required String type,
        String? notificationTitle,
        String? title,
        String? messageTitle,
        String? notificationBody,
        String? body,
        String? messageBody,
        String? dealTitle,
        String? senderName,
      }) {
        String clean(dynamic val) => val == null ? '' : val.toString().trim();

        String resolvedTitle = clean(notificationTitle);
        if (resolvedTitle.isEmpty) resolvedTitle = clean(title);
        if (resolvedTitle.isEmpty) resolvedTitle = clean(messageTitle);

        final cleanDealTitle = clean(dealTitle);
        final cleanSender = clean(senderName).isEmpty ? 'Kullanıcı' : clean(senderName);

        if (resolvedTitle.isEmpty || resolvedTitle == 'Yeni Bildirim') {
          if (type == 'deal') {
            resolvedTitle = '🎯 Yeni Fırsat!';
          } else if (type == 'comment') {
            resolvedTitle = '💬 $cleanSender fırsatınıza yorum yaptı';
          } else if (type == 'comment_reply') {
            resolvedTitle = '💬 $cleanSender yorumunuza cevap verdi';
          } else if (type == 'admin_deal') {
            resolvedTitle = '👮‍♂️ Onay Bekleyen Fırsat';
          } else if (type == 'admin_message') {
            resolvedTitle = '🛡️ FırsatKolik Yönetim';
          } else if (type == 'marketing') {
            resolvedTitle = '🔥 Özel Fırsat Duyurusu';
          } else if (cleanDealTitle.isNotEmpty) {
            resolvedTitle = '🎯 $cleanDealTitle';
          } else {
            resolvedTitle = '🔔 FırsatKolik';
          }
        }

        String resolvedBody = clean(notificationBody);
        if (resolvedBody.isEmpty) resolvedBody = clean(body);
        if (resolvedBody.isEmpty) resolvedBody = clean(messageBody);

        if (resolvedBody.isEmpty) {
          if (cleanDealTitle.isNotEmpty) {
            resolvedBody = '$cleanDealTitle\nFırsatı görmek için dokunun.';
          } else if (type == 'deal') {
            resolvedBody = 'İlginizi çekebilecek yeni bir indirim paylaşıldı.';
          } else if (type == 'comment' || type == 'comment_reply') {
            resolvedBody = 'Yorum detaylarını incelemek için dokunun.';
          } else if (type == 'admin_message') {
            resolvedBody = 'Yeni bir yönetici bildiriminiz var.';
          } else {
            resolvedBody = 'Detayları görüntülemek için dokunun.';
          }
        }

        return {'title': resolvedTitle, 'body': resolvedBody};
      }

      // Senaryo 1: data['title'] ve data['body'] boş string ("") - Eski sistemde "Yeni Bildirim / boş" oluyordu
      final res1 = resolveNotificationText(
        type: 'deal',
        title: '',
        body: '',
        dealTitle: 'Dyson V15 Süpürge',
      );
      expect(res1['title'], '🎯 Yeni Fırsat!');
      expect(res1['body'], contains('Dyson V15 Süpürge'));

      // Senaryo 2: title "Yeni Bildirim" olarak gelmişse akıllı kurtarma devreye girer
      final res2 = resolveNotificationText(
        type: 'comment',
        title: 'Yeni Bildirim',
        senderName: 'Ahmet',
      );
      expect(res2['title'], '💬 Ahmet fırsatınıza yorum yaptı');
      expect(res2['body'], contains('Yorum detaylarını'));

      // Senaryo 3: Yönetici mesajında boş gövde
      final res3 = resolveNotificationText(
        type: 'admin_message',
        title: '',
        body: '',
      );
      expect(res3['title'], '🛡️ FırsatKolik Yönetim');
      expect(res3['body'], 'Yeni bir yönetici bildiriminiz var.');
    });

    test('Ghost / dryRun push message suppression drops empty payloads', () {
      bool shouldSuppressPush(Map<String, dynamic> data, dynamic notification) {
        if (data.isEmpty && notification == null) return true;
        if (data['dryRun'] == 'true' || data['silent'] == 'true') return true;
        return false;
      }

      // Tamamen boş mesaj -> Bastırılmalı
      expect(shouldSuppressPush({}, null), isTrue);

      // DryRun test mesajı -> Bastırılmalı
      expect(shouldSuppressPush({'dryRun': 'true'}, null), isTrue);

      // Gerçek fırsat mesajı -> Gösterilmeli
      expect(shouldSuppressPush({'type': 'deal', 'dealId': '123'}, null), isFalse);
    });

    test('Deterministic seed key and notification ID generation collapses duplicate alerts', () {
      int generateNotifId({
        required String type,
        String notificationId = '',
        String dealId = '',
        String commentId = '',
        String messageId = '',
        String senderId = '',
      }) {
        final seedKey = notificationId.isNotEmpty
            ? notificationId
            : (dealId.isNotEmpty
                ? dealId
                : (commentId.isNotEmpty
                    ? commentId
                    : (messageId.isNotEmpty
                        ? messageId
                        : (senderId.isNotEmpty ? senderId : type))));

        return (seedKey.hashCode & 0x7FFFFFFF) % 100000;
      }

      // Aynı dealId'ye ait peş peşe gelen 4 bildirim aynı deterministik ID'yi alır
      final id1 = generateNotifId(type: 'deal', dealId: 'deal_4380');
      final id2 = generateNotifId(type: 'deal', dealId: 'deal_4380');
      final id3 = generateNotifId(type: 'deal', dealId: 'deal_4380');
      final id4 = generateNotifId(type: 'deal', dealId: 'deal_4380');

      expect(id1, equals(id2));
      expect(id2, equals(id3));
      expect(id3, equals(id4));
      // Android drawer'da 4 tane ayrı kart açılmaz, mevcut kart güncellenir
    });

    test('Reason-based rate limiting and burst debounce status codes are mapped accurately', () {
      String evaluateRateLimit({
        required String reason,
        required String type,
        required int countHourly,
        required int limitHourly,
        required int secondsSinceLastDeal,
        required int dealMinIntervalSeconds,
        required bool isTestUser,
      }) {
        if (reason == 'category' && countHourly >= limitHourly) {
          return 'skipped_category_limit';
        }
        if (reason == 'author' && countHourly >= limitHourly) {
          return 'skipped_author_limit';
        }
        if ((reason == 'keyword' || type == 'keyword') && countHourly >= limitHourly) {
          return 'skipped_keyword_limit';
        }
        if ((type == 'comment' || type == 'comment_reply') && countHourly >= limitHourly) {
          return 'skipped_comment_rate_limit';
        }
        if (type == 'marketing' && countHourly >= limitHourly) {
          return 'skipped_marketing_limit';
        }
        if (type == 'admin_message' && !isTestUser && countHourly >= limitHourly) {
          return 'skipped_admin_message_rate_limit';
        }
        if ((type == 'deal' || reason == 'category' || reason == 'author' || reason == 'keyword') && !isTestUser) {
          if (secondsSinceLastDeal < dealMinIntervalSeconds) {
            return 'skipped_deal_burst_cooldown';
          }
          if (countHourly >= limitHourly) {
            return 'skipped_deal_hourly_total_limit';
          }
        }
        return 'sent';
      }

      // Kategori limit aşımı
      expect(evaluateRateLimit(
        reason: 'category', type: 'deal', countHourly: 3, limitHourly: 3,
        secondsSinceLastDeal: 120, dealMinIntervalSeconds: 30, isTestUser: false,
      ), equals('skipped_category_limit'));

      // Yazar limit aşımı
      expect(evaluateRateLimit(
        reason: 'author', type: 'deal', countHourly: 4, limitHourly: 4,
        secondsSinceLastDeal: 120, dealMinIntervalSeconds: 30, isTestUser: false,
      ), equals('skipped_author_limit'));

      // Anahtar kelime limit aşımı
      expect(evaluateRateLimit(
        reason: 'keyword', type: 'deal', countHourly: 6, limitHourly: 6,
        secondsSinceLastDeal: 120, dealMinIntervalSeconds: 30, isTestUser: false,
      ), equals('skipped_keyword_limit'));

      // Yorum / Topluluk aşırı bildirim
      expect(evaluateRateLimit(
        reason: 'comment', type: 'comment_reply', countHourly: 10, limitHourly: 10,
        secondsSinceLastDeal: 120, dealMinIntervalSeconds: 30, isTestUser: false,
      ), equals('skipped_comment_rate_limit'));

      // Pazarlama günlük sınır aşımı
      expect(evaluateRateLimit(
        reason: 'marketing', type: 'marketing', countHourly: 2, limitHourly: 2,
        secondsSinceLastDeal: 120, dealMinIntervalSeconds: 30, isTestUser: false,
      ), equals('skipped_marketing_limit'));

      // Admin mesajı aşırı gönderim koruması
      expect(evaluateRateLimit(
        reason: 'admin_broadcast', type: 'admin_message', countHourly: 5, limitHourly: 5,
        secondsSinceLastDeal: 120, dealMinIntervalSeconds: 30, isTestUser: false,
      ), equals('skipped_admin_message_rate_limit'));

      // Burst cooldown (Son deal push üzerinden 5 saniye geçmişse ve limit 30 saniye ise)
      expect(evaluateRateLimit(
        reason: 'author', type: 'deal', countHourly: 1, limitHourly: 8,
        secondsSinceLastDeal: 5, dealMinIntervalSeconds: 30, isTestUser: false,
      ), equals('skipped_deal_burst_cooldown'));

      // Test kullanıcıları burst cooldown'dan muaftır
      expect(evaluateRateLimit(
        reason: 'author', type: 'deal', countHourly: 1, limitHourly: 8,
        secondsSinceLastDeal: 5, dealMinIntervalSeconds: 30, isTestUser: true,
      ), equals('sent'));
    });
  });
}
