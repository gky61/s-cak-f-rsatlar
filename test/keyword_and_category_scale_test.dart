import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/notification_preferences.dart';
import 'package:sicak_firsatlar/services/notification_service.dart';

void main() {
  group('1. Unicode Turkish "İ" and Character Normalization Tests (FS-NOTIF-08)', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    test('Normalizes uppercase "İ" at start of word to ASCII "i" (Matches Node.js)', () {
      expect(service.normalizeKeyword('İphone'), equals('iphone'));
      expect(service.normalizeKeyword('İphone 15 Pro Max'), equals('iphone 15 pro max'));
      expect(service.normalizeKeyword('İndirim'), equals('indirim'));
      expect(service.normalizeKeyword('İşlemci'), equals('islemci'));
      expect(service.normalizeKeyword('İpad'), equals('ipad'));
    });

    test('Normalizes uppercase "I" and lowercase "ı" to ASCII "i"', () {
      expect(service.normalizeKeyword('IPHONE'), equals('iphone'));
      expect(service.normalizeKeyword('ıphone'), equals('iphone'));
      expect(service.normalizeKeyword('IŞIK'), equals('isik'));
      expect(service.normalizeKeyword('ışık'), equals('isik'));
    });

    test('Normalizes other Turkish characters correctly and strips punctuation', () {
      expect(service.normalizeKeyword('Çanta'), equals('canta'));
      expect(service.normalizeKeyword('Örtü'), equals('ortu'));
      expect(service.normalizeKeyword('Şampuan'), equals('sampuan'));
      expect(service.normalizeKeyword('Ütü'), equals('utu'));
      expect(service.normalizeKeyword('Dyson V15 Detect!'), equals('dyson v15 detect'));
      expect(service.normalizeKeyword('  Xiaomi 13T Pro (12GB/512GB)  '), equals('xiaomi 13t pro 12gb512gb'));
    });

    test('Binary equality matches between normalized Turkish and search queries', () {
      final normalizedFromClient = service.normalizeKeyword('İphone 15');
      const targetQuery = 'iphone 15';
      expect(normalizedFromClient, equals(targetQuery));
      expect(normalizedFromClient.codeUnits, equals(targetQuery.codeUnits));
    });
  });

  group('2. Quiet Hours (isQuietHoursNow) Matrix Tests (FS-NOTIF-01)', () {
    test('Overnight quiet hours (23:00 - 08:00)', () {
      final prefs = NotificationPreferences(
        quietHoursEnabled: true,
        quietHoursStart: '23:00',
        quietHoursEnd: '08:00',
        updatedAt: DateTime.now(),
      );

      // Nighttime inside window
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 23, 30)), isTrue);
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 2, 15)), isTrue);
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 7, 59)), isTrue);

      // Daytime outside window
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 8, 0)), isFalse);
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 14, 30)), isFalse);
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 22, 59)), isFalse);
    });

    test('Same-day quiet hours (13:00 - 15:00)', () {
      final prefs = NotificationPreferences(
        quietHoursEnabled: true,
        quietHoursStart: '13:00',
        quietHoursEnd: '15:00',
        updatedAt: DateTime.now(),
      );

      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 13, 30)), isTrue);
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 12, 59)), isFalse);
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 15, 01)), isFalse);
    });

    test('Quiet hours disabled always returns false', () {
      final prefs = NotificationPreferences(
        quietHoursEnabled: false,
        quietHoursStart: '23:00',
        quietHoursEnd: '08:00',
        updatedAt: DateTime.now(),
      );

      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 2, 0)), isFalse);
      expect(prefs.isQuietHoursNow(DateTime(2026, 10, 16, 23, 30)), isFalse);
    });
  });

  group('3. Multi-Push Echo Storm Deduplication Tests (FS-NOTIF-02)', () {
    setUp(() {
      NotificationService.clearRecentDealHandledForTesting();
    });

    test('Suppresses subsequent duplicate deal notification in 60s sliding window', () {
      const dealId = 'deal_test_12345';
      
      // First arrival: not yet handled
      expect(NotificationService.isRecentDealHandledForTesting(dealId), isFalse);

      // Mark handled (e.g. category topic push arrived first)
      NotificationService.markRecentDealHandledForTesting(dealId);

      // Second arrival (e.g. subcategory or keyword topic push arriving 500ms later)
      expect(NotificationService.isRecentDealHandledForTesting(dealId), isTrue);

      // Distinct dealId is independent
      expect(NotificationService.isRecentDealHandledForTesting('deal_test_99999'), isFalse);
    });
  });

  group('4. Security Rules & Composite Index Structural Audit Tests (FS-NOTIF-10 & FS-NOTIF-13)', () {
    test('firestore.rules enforces strict schema on notificationSubscriptions', () {
      final rulesFile = File('firestore.rules');
      expect(rulesFile.existsSync(), isTrue);
      final content = rulesFile.readAsStringSync();

      expect(content, contains('match /notificationSubscriptions/{subscriptionId}'));
      expect(content, contains("request.resource.data.type in ['keyword', 'category', 'author']"));
      expect(content, contains('request.resource.data.key.size() <= 100'));
      expect(content, contains('request.resource.data.displayValue.size() <= 100'));
      expect(content, contains('request.resource.data.enabled is bool'));
      expect(content, contains('subscriptionId.size() <= 160'));
      expect(content, contains("hasAny(['uid', 'userId', 'type', 'key'])"));
    });

    test('firestore.indexes.json orders equality filters (type, enabled) before IN filter (key)', () {
      final indexFile = File('firestore.indexes.json');
      expect(indexFile.existsSync(), isTrue);
      final jsonMap = jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
      final indexes = jsonMap['indexes'] as List<dynamic>;

      final subIndex = indexes.firstWhere(
        (idx) {
          if (idx['collectionGroup'] != 'notificationSubscriptions') return false;
          final fields = (idx['fields'] as List<dynamic>).map((f) => f['fieldPath']).toList();
          return fields.contains('type') && fields.contains('enabled') && fields.contains('key');
        },
        orElse: () => null,
      );

      expect(subIndex, isNotNull);
      final fields = (subIndex['fields'] as List<dynamic>).map((f) => f['fieldPath']).toList();
      expect(fields, equals(['type', 'enabled', 'key']));
    });
  });

  group('5. Cloud Functions Contract Audit Tests (FS-NOTIF-07, 11, 15)', () {
    test('functions/index.js contains subcategory matching and topic distribution', () {
      final indexJsFile = File('functions/index.js');
      expect(indexJsFile.existsSync(), isTrue);
      final content = indexJsFile.readAsStringSync();

      // Subcategory check in categoriesToCheck
      expect(content, contains("deal.subCategory || deal.subcategory"));
      expect(content, contains("categoriesToCheck.push(`\${category}:\${cleanSubTrim}`)"));
      expect(content, contains("categoriesToCheck.push(`\${category}:\${cleanSubTrim.toLowerCase()}`)"));

      // Subcategory topic broadcast
      expect(content, contains("cat_\${cleanCategory}_\${cleanSub}"));

      // Botkolik FCM topic broadcast
      expect(content, contains("author_botkolik"));

      // 4KB Payload ceilings and anti-flood tags
      expect(content, contains("deal.title || '').substring(0, 100)"));
      expect(content, contains("onlyAlertOnce: true"));
      expect(content, contains("'apns-collapse-id': `deal_\${dealId}`"));
      expect(content, contains("tag: `deal_\${dealId}`"));

      // FS-NOTIF-05: 90 Candidate Keywords Ceiling (max 3 chunks)
      expect(content, contains("[...candidateKeywords].slice(0, 90)"));
    });

    test('lib/services/user_service.dart and notification_service.dart synchronize author FCM topics', () {
      final userSerFile = File('lib/services/user_service.dart');
      expect(userSerFile.existsSync(), isTrue);
      final userSerContent = userSerFile.readAsStringSync();
      expect(userSerContent, contains("FirebaseMessaging.instance.subscribeToTopic('author_\$sanitizedKey')"));
      expect(userSerContent, contains("FirebaseMessaging.instance.unsubscribeFromTopic('author_\$sanitizedKey')"));

      final notifSerFile = File('lib/services/notification_service.dart');
      expect(notifSerFile.existsSync(), isTrue);
      final notifSerContent = notifSerFile.readAsStringSync();
      expect(notifSerContent, contains("authorSubsSnap = await _firestore"));
      expect(notifSerContent, contains("_messaging.subscribeToTopic('author_\$sanitizedAuthor')"));
      expect(notifSerContent, contains("_cachedUserId == userId"));
    });
  });
}
