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
  });
}
