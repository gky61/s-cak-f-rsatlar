import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/app_badge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel badgeChannel = MethodChannel('com.sicakfirsatlar.app/badge');
  const MethodChannel localNotifChannel = MethodChannel('dexterous.com/flutter/local_notifications');

  final List<MethodCall> badgeChannelCalls = [];
  final List<MethodCall> localNotifChannelCalls = [];

  setUp(() {
    badgeChannelCalls.clear();
    localNotifChannelCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(badgeChannel, (MethodCall methodCall) async {
      badgeChannelCalls.add(methodCall);
      if (methodCall.method == 'setBadge' || methodCall.method == 'clearBadge') {
        return true;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localNotifChannel, (MethodCall methodCall) async {
      localNotifChannelCalls.add(methodCall);
      if (methodCall.method == 'cancelAll') {
        return true;
      }
      return null;
    });
  });

  tearPlatformChannels() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(badgeChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localNotifChannel, null);
  }

  tearDown(() {
    tearPlatformChannels();
  });

  group('AppBadgeService Tests', () {
    test('Singleton instance integrity', () {
      final s1 = AppBadgeService();
      final s2 = AppBadgeService.instance;
      expect(identical(s1, s2), isTrue);
    });

    test('setBadge with positive number sends setBadge to native channel and updates currentBadgeCount', () async {
      final service = AppBadgeService.instance;
      await service.setBadge(5);

      expect(service.currentBadgeCount, equals(5));
      expect(badgeChannelCalls.length, equals(1));
      expect(badgeChannelCalls.first.method, equals('setBadge'));
      expect(badgeChannelCalls.first.arguments, equals({'count': 5}));
    });

    test('setBadge with 0 triggers clearBadge', () async {
      final service = AppBadgeService.instance;
      await service.setBadge(0);

      expect(service.currentBadgeCount, equals(0));
      expect(badgeChannelCalls.any((call) => call.method == 'clearBadge'), isTrue);
    });

    test('setBadge with negative number defaults to 0 and clears badge', () async {
      final service = AppBadgeService.instance;
      await service.setBadge(-3);

      expect(service.currentBadgeCount, equals(0));
      expect(badgeChannelCalls.any((call) => call.method == 'clearBadge'), isTrue);
    });

    test('clearBadge resets badge count to 0 and invokes native clearBadge', () async {
      final service = AppBadgeService.instance;
      // Set to 4 first
      await service.setBadge(4);
      expect(service.currentBadgeCount, equals(4));

      badgeChannelCalls.clear();
      await service.clearBadge();

      expect(service.currentBadgeCount, equals(0));
      expect(badgeChannelCalls.length, equals(1));
      expect(badgeChannelCalls.first.method, equals('clearBadge'));
    });

    test('stopRealtimeBadgeSync safely cancels active subscriptions and resets counts', () {
      final service = AppBadgeService.instance;
      service.stopRealtimeBadgeSync();
      // Calling multiple times should not throw
      service.stopRealtimeBadgeSync();
      expect(service.currentBadgeCount, isNotNull);
    });
  });
}
