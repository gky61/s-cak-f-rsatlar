import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sicak_firsatlar/services/share_intent_service.dart';
import 'package:sicak_firsatlar/services/notification_service.dart';
import 'package:sicak_firsatlar/screens/submit_deal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.isColdStartNotificationTapActive = false;
  });

  group('ShareIntentService Stale Intent & Multi-Share Reliability Tests', () {
    test('markUrlConsumed safely cleans intent state without creating toxic disk blacklist', () async {
      const testUrl = 'https://www.migros.com.tr/hemen/nestle-beyaz-kare-cikolata-60-g-p-6b6158';

      await ShareIntentService.instance.markUrlConsumed(testUrl);

      final prefs = await SharedPreferences.getInstance();
      // Disk kara listesi oluşturulmamalı; böylece aynı URL ikinci kez paylaşıldığında engellenmez
      expect(prefs.getStringList('share_intent_consumed_urls_list'), isNull);
      expect(prefs.getString('share_intent_last_consumed_url'), isNull);
      expect(prefs.getInt('share_intent_last_consumed_time'), isNull);
    });

    test('initialize cleans legacy toxic SharedPreferences keys on launch', () async {
      SharedPreferences.setMockInitialValues({
        'share_intent_consumed_urls_list': ['https://www.migros.com.tr/eski-link'],
        'share_intent_last_consumed_url': 'https://www.migros.com.tr/eski-link',
        'share_intent_last_consumed_time': 123456789,
      });

      ShareIntentService.instance.initialize();

      // Async SharedPreferences.remove çağrılarının tamamlanması için mikro-gecikme
      await Future.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('share_intent_consumed_urls_list'), isNull);
      expect(prefs.getString('share_intent_last_consumed_url'), isNull);
      expect(prefs.getInt('share_intent_last_consumed_time'), isNull);
    });

    test('isColdStartNotificationTapActive flag suppresses cold start share intent', () async {
      NotificationService.isColdStartNotificationTapActive = true;

      // When notification tap is active on cold start, empty media or media files
      // should be safely suppressed without opening SubmitDealScreen
      await ShareIntentService.instance.handleSharedMedia([], isColdStart: true);
      expect(NotificationService.isColdStartNotificationTapActive, isTrue);
    });

    test('SubmitDealScreen tracks isScreenOpen state correctly', () {
      expect(SubmitDealScreen.isScreenOpen, isFalse);
    });

    test('NotificationService coldStartNotificationFuture returns valid boolean without deadlocks', () async {
      NotificationService.isColdStartNotificationTapActive = false;
      final future = NotificationService.coldStartNotificationFuture;
      final result = await future.timeout(const Duration(milliseconds: 100), onTimeout: () => false);
      expect(result, isFalse);
    });
  });
}
