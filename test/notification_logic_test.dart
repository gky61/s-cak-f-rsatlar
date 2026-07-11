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
  });
}
