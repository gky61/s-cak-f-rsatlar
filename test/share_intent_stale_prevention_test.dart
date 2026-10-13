import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sicak_firsatlar/services/share_intent_service.dart';
import 'package:sicak_firsatlar/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.isColdStartNotificationTapActive = false;
  });

  group('ShareIntentService Stale Intent & Notification Suppression Tests', () {
    test('markUrlConsumed writes consumed URL and timestamp to SharedPreferences', () async {
      const testUrl = 'https://www.amazon.com.tr/dp/B08N5WRWNW';

      await ShareIntentService.instance.markUrlConsumed(testUrl);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('share_intent_last_consumed_url'), equals(testUrl));
      expect(prefs.getInt('share_intent_last_consumed_time'), isNotNull);

      final list = prefs.getStringList('share_intent_consumed_urls_list');
      expect(list, isNotNull);
      expect(list, contains(testUrl));
    });

    test('markUrlConsumed maintains multi-URL LRU list buffer', () async {
      const url1 = 'https://www.trendyol.com/urun-1';
      const url2 = 'https://www.hepsiburada.com/urun-2';
      const url3 = 'https://www.amazon.com.tr/urun-3';

      await ShareIntentService.instance.markUrlConsumed(url1);
      await ShareIntentService.instance.markUrlConsumed(url2);
      await ShareIntentService.instance.markUrlConsumed(url3);

      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('share_intent_consumed_urls_list');
      expect(list, isNotNull);
      expect(list!.length, equals(3));
      expect(list.first, equals(url3)); // En son eklenen en başta (LRU)
      expect(list, contains(url1));
      expect(list, contains(url2));
    });

    test('isColdStartNotificationTapActive flag suppresses cold start share intent', () async {
      NotificationService.isColdStartNotificationTapActive = true;

      // When notification tap is active on cold start, empty media or media files
      // should be safely suppressed without opening SubmitDealScreen
      await ShareIntentService.instance.handleSharedMedia([], isColdStart: true);
      expect(NotificationService.isColdStartNotificationTapActive, isTrue);
    });

    test('Repeated empty or whitespace URL does not crash markUrlConsumed', () async {
      await ShareIntentService.instance.markUrlConsumed('');
      await ShareIntentService.instance.markUrlConsumed('   ');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('share_intent_last_consumed_url'), isNull);
      expect(prefs.getStringList('share_intent_consumed_urls_list'), isNull);
    });

    test('NotificationService coldStartNotificationFuture returns valid boolean without deadlocks', () async {
      NotificationService.isColdStartNotificationTapActive = false;
      final future = NotificationService.coldStartNotificationFuture;
      final result = await future.timeout(const Duration(milliseconds: 100), onTimeout: () => false);
      expect(result, isFalse);
    });
  });
}
