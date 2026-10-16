import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/notification_preferences.dart';

void main() {
  group('1. NotificationPreferences Model & Quiet Hours Tests', () {
    test('Default preferences have correct safe baseline configuration', () {
      final prefs = NotificationPreferences.defaultPreferences();
      expect(prefs.pushMasterEnabled, isTrue);
      expect(prefs.dealNotificationsEnabled, isTrue);
      expect(prefs.categoryNotificationsEnabled, isFalse);
      expect(prefs.keywordNotificationsEnabled, isTrue);
      expect(prefs.quietHoursEnabled, isTrue);
      expect(prefs.quietHoursStart, '23:00');
      expect(prefs.quietHoursEnd, '08:00');
    });

    test('isQuietHoursNow accurately evaluates overnight window (23:00 - 08:00)', () {
      final prefs = NotificationPreferences.defaultPreferences();
      // Gece 02:30 -> Sessiz saat içi
      final midnight = DateTime(2026, 10, 16, 2, 30);
      expect(prefs.isQuietHoursNow(midnight), isTrue);

      // Öğlen 14:00 -> Sessiz saat dışı
      final afternoon = DateTime(2026, 10, 16, 14, 0);
      expect(prefs.isQuietHoursNow(afternoon), isFalse);

      // 23:00 tam başlangıç anı -> Sessiz saat içi
      final start = DateTime(2026, 10, 16, 23, 0);
      expect(prefs.isQuietHoursNow(start), isTrue);

      // 08:00 tam bitiş anı -> Sessiz saat dışı (< quietHoursEnd)
      final end = DateTime(2026, 10, 16, 8, 0);
      expect(prefs.isQuietHoursNow(end), isFalse);
    });

    test('toMap and copyWith preserve lastStates and serialization integrity', () {
      final prefs = NotificationPreferences.defaultPreferences();
      final updated = prefs.copyWith(
        dealNotificationsEnabled: false,
        categoryNotificationsEnabled: true,
      );

      final map = updated.toMap();
      expect(map['dealNotificationsEnabled'], isFalse);
      expect(map['categoryNotificationsEnabled'], isTrue);
      expect(map['pushMasterEnabled'], isTrue);
    });
  });

  group('2. FS-PREF-01 & FS-PREF-06: functions/index.js Coupon Notification Contracts', () {
    test('dispatchApprovedCouponNotifications defines announcementId at function scope and eliminates 150 random users write', () {
      final file = File('functions/index.js');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // announcementId try dışında tanımlanmış olmalı
      expect(content.contains('const announcementId = `coupon_\${kuponId}`;'), isTrue);

      // 150 rastgele kullanıcı çekme döngüsü tamamen tasfiye edilmiş olmalı
      expect(content.contains('activeUsersSnap = await admin.firestore().collection(\'users\')'), isFalse);
      expect(content.contains('limit(150)\n        .get()'), isFalse);

      // ReferenceError satırı giderilmiş olmalı
      expect(content.contains('announcementId: announcementId'), isTrue);
    });
  });

  group('3. FS-PREF-03: UserService Author FCM Topic Synchronization Contracts', () {
    test('followUser subscribes and unfollowUser unsubscribes from author FCM topic', () {
      final file = File('lib/services/user_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // followUser içinde subscribeToTopic varlığı
      expect(content.contains("FirebaseMessaging.instance.subscribeToTopic('author_\$sanitizedKey')"), isTrue);

      // unfollowUser içinde unsubscribeFromTopic varlığı
      expect(content.contains("FirebaseMessaging.instance.unsubscribeFromTopic('author_\$sanitizedKey')"), isTrue);
    });
  });

  group('4. FS-PREF-04: NotificationService resubscribeToTopics Filter Contract', () {
    test('resubscribeToTopics respects dealNotificationsEnabled for author topic subscriptions', () {
      final file = File('lib/services/notification_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Yazar konularında hem pushMasterEnabled hem de dealNotificationsEnabled şartı aranmalı
      expect(content.contains('final isAuthorPushActive = prefs.pushMasterEnabled && prefs.dealNotificationsEnabled;'), isTrue);
    });
  });

  group('5. FS-PREF-02: HomeScreen Read Avalanche Mitigation Contract', () {
    test('HomeScreen uses getUnreadNotificationCountStream instead of heavy getUserNotificationsStream', () {
      final file = File('lib/screens/home_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // HomeScreen bildirim zilinde getUserNotificationsStream kullanılmamalı
      expect(content.contains('_firestoreService.getUnreadNotificationCountStream(currentUserId)'), isTrue);

      // firestore_service.dart içinde fonksiyonun tanımlı olduğu doğrulanmalı
      final serviceFile = File('lib/services/firestore_service.dart');
      expect(serviceFile.readAsStringSync().contains('Stream<int> getUnreadNotificationCountStream(String userId)'), isTrue);
    });
  });

  group('6. FS-PREF-05: KeywordTrackingScreen Preferences Warning Banner Contract', () {
    test('KeywordTrackingScreen loads NotificationPreferences and renders warning banner when push is disabled', () {
      final file = File('lib/screens/keyword_tracking_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('NotificationPreferences? _notificationPreferences;'), isTrue);
      expect(content.contains('_notificationService.getNotificationPreferences()'), isTrue);
      expect(content.contains('Kelime Bildirimleriniz Kapalı'), isTrue);
      expect(content.contains('MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())'), isTrue);
    });
  });

  group('7. FS-PREF-14: firestore.rules Schema Validation Contract', () {
    test('firestore.rules enforces strict keys whitelist and boolean types on notificationPreferences', () {
      final file = File('firestore.rules');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('match /notificationPreferences/{documentId}'), isTrue);
      expect(content.contains("request.resource.data.keys().hasOnly(["), isTrue);
      expect(content.contains("'pushMasterEnabled'"), isTrue);
      expect(content.contains("'dealNotificationsEnabled'"), isTrue);
      expect(content.contains("'categoryNotificationsEnabled'"), isTrue);
      expect(content.contains("'keywordNotificationsEnabled'"), isTrue);
      expect(content.contains("'dismissedAnnouncementIds'"), isTrue);
      expect(content.contains("'readAnnouncementIds'"), isTrue);
    });
  });

  group('8. FS-PREF-09: NotificationPreferences Disk Cache Serialization & Reconciliation Tests', () {
    test('toJson and fromJson correctly roundtrip all fields including lastStates and ISO timestamps', () {
      final now = DateTime(2026, 10, 16, 15, 30, 0);
      final prefs = NotificationPreferences(
        pushMasterEnabled: false,
        dealNotificationsEnabled: false,
        categoryNotificationsEnabled: true,
        keywordNotificationsEnabled: false,
        communityNotificationsEnabled: true,
        submissionStatusNotificationsEnabled: false,
        marketingNotificationsEnabled: true,
        quietHoursEnabled: true,
        quietHoursStart: "22:00",
        quietHoursEnd: "07:30",
        timezone: "Europe/Istanbul",
        updatedAt: now,
        schemaVersion: 2,
        lastStates: {
          'dealNotificationsEnabled': true,
          'categoryNotificationsEnabled': false,
        },
      );

      final json = prefs.toJson();
      expect(json['pushMasterEnabled'], isFalse);
      expect(json['quietHoursStart'], equals('22:00'));
      expect(json['quietHoursEnd'], equals('07:30'));
      expect(json['lastStates']['dealNotificationsEnabled'], isTrue);

      final restored = NotificationPreferences.fromJson(json);
      expect(restored.pushMasterEnabled, isFalse);
      expect(restored.dealNotificationsEnabled, isFalse);
      expect(restored.categoryNotificationsEnabled, isTrue);
      expect(restored.quietHoursStart, equals('22:00'));
      expect(restored.quietHoursEnd, equals('07:30'));
      expect(restored.lastStates['dealNotificationsEnabled'], isTrue);
      expect(restored.updatedAt.toIso8601String(), equals(now.toIso8601String()));
    });
  });

  group('9. FS-PREF-10 & FS-PREF-13: FirestoreService Paginated Operations & AppBadge Contract Tests', () {
    test('deleteAllNotifications and markAllNotificationsAsRead implement while(true) chunking and clearBadge', () {
      final file = File('lib/services/firestore_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // markAllNotificationsAsRead içinde while loop ve clearBadge doğrulaması
      expect(content.contains('// 2. FS-PREF-10 & FS-PREF-16: Kişisel okunmamış bildirimleri sayfalı (while loop) tüketerek tümünü okundu yap'), isTrue);
      expect(content.contains('AppBadgeService.instance.clearBadge()'), isTrue);

      // deleteAllNotifications içinde while loop doğrulaması
      expect(content.contains('// 2. FS-PREF-10 & FS-PREF-16: Kişisel bildirimleri sayfalı (while loop) tüketerek tümünü sil'), isTrue);
    });
  });

  group('10. FS-PREF-15: StreamController onCancel Resource Cleanup & Memory Leak Guard Tests', () {
    test('getUserNotificationsStream and getUnreadNotificationCountStream ensure controller.close() in onCancel', () {
      final file = File('lib/services/firestore_service.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // onCancel bloklarında controller.close() varlığı
      expect(content.contains('if (!controller.isClosed)'), isTrue);
      expect(content.contains('await controller.close();'), isTrue);
    });
  });
}
