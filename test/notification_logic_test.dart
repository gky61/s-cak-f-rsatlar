import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences Unit Tests', () {
    test('Default preferences should match roadmap defaults', () {
      final prefs = NotificationPreferences.defaultPreferences();
      expect(prefs.pushMasterEnabled, isTrue);
      expect(prefs.dealNotificationsEnabled, isTrue);
      expect(prefs.communityNotificationsEnabled, isTrue);
      expect(prefs.submissionStatusNotificationsEnabled, isTrue);
      expect(prefs.marketingNotificationsEnabled, isFalse); // Varsayılan kapalı olmalı
      expect(prefs.quietHoursEnabled, isFalse);
      expect(prefs.quietHoursStart, '23:00');
      expect(prefs.quietHoursEnd, '08:00');
      expect(prefs.timezone, 'Europe/Istanbul');
    });

    test('toMap and fromFirestore serialization should work correctly', () {
      final original = NotificationPreferences(
        pushMasterEnabled: false,
        dealNotificationsEnabled: true,
        communityNotificationsEnabled: false,
        submissionStatusNotificationsEnabled: true,
        marketingNotificationsEnabled: true,
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '07:00',
        timezone: 'Europe/Istanbul',
        updatedAt: DateTime.now(),
      );

      final map = original.toMap();
      expect(map['pushMasterEnabled'], isFalse);
      expect(map['dealNotificationsEnabled'], isTrue);
      expect(map['communityNotificationsEnabled'], isFalse);
      expect(map['submissionStatusNotificationsEnabled'], isTrue);
      expect(map['marketingNotificationsEnabled'], isTrue);
      expect(map['quietHoursEnabled'], isTrue);
      expect(map['quietHoursStart'], '22:00');
      expect(map['quietHoursEnd'], '07:00');
      expect(map['timezone'], 'Europe/Istanbul');
    });

    test('Master switch toggle ON/OFF updates all sub-settings without relying on memory', () {
      // 1. Initial state with mixed sub-settings
      var prefs = NotificationPreferences(
        pushMasterEnabled: true,
        dealNotificationsEnabled: true,
        categoryNotificationsEnabled: false,
        keywordNotificationsEnabled: true,
        communityNotificationsEnabled: false,
        submissionStatusNotificationsEnabled: true,
        marketingNotificationsEnabled: false,
        quietHoursEnabled: false,
        updatedAt: DateTime.now(),
      );

      // 2. Turn Master OFF -> All sub-settings must become false
      final masterOffVal = false;
      prefs = NotificationPreferences(
        pushMasterEnabled: masterOffVal,
        dealNotificationsEnabled: masterOffVal,
        categoryNotificationsEnabled: masterOffVal,
        keywordNotificationsEnabled: masterOffVal,
        communityNotificationsEnabled: masterOffVal,
        submissionStatusNotificationsEnabled: masterOffVal,
        marketingNotificationsEnabled: masterOffVal,
        quietHoursEnabled: masterOffVal,
        quietHoursStart: prefs.quietHoursStart,
        quietHoursEnd: prefs.quietHoursEnd,
        timezone: prefs.timezone,
        updatedAt: DateTime.now(),
      );

      expect(prefs.pushMasterEnabled, isFalse);
      expect(prefs.dealNotificationsEnabled, isFalse);
      expect(prefs.categoryNotificationsEnabled, isFalse);
      expect(prefs.keywordNotificationsEnabled, isFalse);
      expect(prefs.communityNotificationsEnabled, isFalse);
      expect(prefs.submissionStatusNotificationsEnabled, isFalse);
      expect(prefs.marketingNotificationsEnabled, isFalse);
      expect(prefs.quietHoursEnabled, isFalse);

      // 3. Enable an individual sub-setting while Master is OFF
      prefs = NotificationPreferences(
        pushMasterEnabled: prefs.pushMasterEnabled,
        dealNotificationsEnabled: prefs.dealNotificationsEnabled,
        categoryNotificationsEnabled: prefs.categoryNotificationsEnabled,
        keywordNotificationsEnabled: prefs.keywordNotificationsEnabled,
        communityNotificationsEnabled: true, // turned ON independently
        submissionStatusNotificationsEnabled: prefs.submissionStatusNotificationsEnabled,
        marketingNotificationsEnabled: prefs.marketingNotificationsEnabled,
        quietHoursEnabled: prefs.quietHoursEnabled,
        quietHoursStart: prefs.quietHoursStart,
        quietHoursEnd: prefs.quietHoursEnd,
        timezone: prefs.timezone,
        updatedAt: DateTime.now(),
      );

      expect(prefs.pushMasterEnabled, isFalse);
      expect(prefs.communityNotificationsEnabled, isTrue);

      // 4. Turn Master ON -> All sub-settings must become true (memory ignored)
      final masterOnVal = true;
      prefs = NotificationPreferences(
        pushMasterEnabled: masterOnVal,
        dealNotificationsEnabled: masterOnVal,
        categoryNotificationsEnabled: masterOnVal,
        keywordNotificationsEnabled: masterOnVal,
        communityNotificationsEnabled: masterOnVal,
        submissionStatusNotificationsEnabled: masterOnVal,
        marketingNotificationsEnabled: masterOnVal,
        quietHoursEnabled: masterOnVal,
        quietHoursStart: prefs.quietHoursStart,
        quietHoursEnd: prefs.quietHoursEnd,
        timezone: prefs.timezone,
        updatedAt: DateTime.now(),
      );

      expect(prefs.pushMasterEnabled, isTrue);
      expect(prefs.dealNotificationsEnabled, isTrue);
      expect(prefs.categoryNotificationsEnabled, isTrue);
      expect(prefs.keywordNotificationsEnabled, isTrue);
      expect(prefs.communityNotificationsEnabled, isTrue);
      expect(prefs.submissionStatusNotificationsEnabled, isTrue);
      expect(prefs.marketingNotificationsEnabled, isTrue);
      expect(prefs.quietHoursEnabled, isTrue);
    });
  });
}
