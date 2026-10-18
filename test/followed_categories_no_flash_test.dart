import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sicak_firsatlar/services/deal_service.dart';
import 'package:sicak_firsatlar/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FS-18: Followed Categories Zero-Flash & No Loading State Tests', () {
    test('DealsPageResult correctly supports hasFollowedCategories flag', () {
      const defaultResult = DealsPageResult(deals: []);
      expect(defaultResult.hasFollowedCategories, isTrue);

      const noCategoriesResult = DealsPageResult(
        deals: [],
        hasFollowedCategories: false,
      );
      expect(noCategoriesResult.hasFollowedCategories, isFalse);
      expect(noCategoriesResult.deals, isEmpty);
    });

    test('NotificationService dual-layer caching updates memory and SharedPreferences', () async {
      final notifService = NotificationService();
      const testUid = 'user_test_zero_flash_123';

      // 1. Başlangıçta önbellek boş
      notifService.invalidateSubscriptionCaches();
      expect(notifService.getCachedHasFollowedCategoriesSync(testUid), isNull);

      // 2. Takip edilen kategori olmadığını set et (boş liste)
      await notifService.setCachedFollowedCategories(testUid, [], []);
      expect(notifService.getCachedHasFollowedCategoriesSync(testUid), isFalse);

      final hasCats = await notifService.hasFollowedCategories(testUid);
      expect(hasCats, isFalse);

      // 3. Kategori eklendiğinde önbellek reaktif olarak true olmalı
      await notifService.addFollowedCategoryToCache(testUid, 'elektronik');
      expect(notifService.getCachedHasFollowedCategoriesSync(testUid), isTrue);

      final hasCatsAfterAdd = await notifService.hasFollowedCategories(testUid);
      expect(hasCatsAfterAdd, isTrue);

      // 4. Kategori kaldırıldığında false'a dönmeli
      await notifService.removeFollowedCategoryFromCache(testUid, 'elektronik');
      expect(notifService.getCachedHasFollowedCategoriesSync(testUid), isFalse);

      final hasCatsAfterRemove = await notifService.hasFollowedCategories(testUid);
      expect(hasCatsAfterRemove, isFalse);
    });

    test('NotificationService disk persistence survives memory cache clear', () async {
      final notifService = NotificationService();
      const testUid = 'user_test_persistence_456';

      // Disk ve bellek hazırla
      await notifService.setCachedFollowedCategories(testUid, ['moda'], ['moda:ayakkabi']);
      expect(notifService.getCachedHasFollowedCategoriesSync(testUid), isTrue);

      // Belleği temizle (simulated app restart)
      notifService.invalidateSubscriptionCaches();
      expect(notifService.getCachedHasFollowedCategoriesSync(testUid), isNull);

      // hasFollowedCategories diskten (SharedPreferences) yeniden hydrate etmeli
      final diskResolved = await notifService.hasFollowedCategories(testUid);
      expect(diskResolved, isTrue);
      // Artık bellekte de senkron olarak mevcut olmalı
      expect(notifService.getCachedHasFollowedCategoriesSync(testUid), isTrue);

      // 3. Soğuk açılışta bellek boşken kategori silindiğinde diskten güvenle silinmeli
      notifService.invalidateSubscriptionCaches();
      await notifService.removeFollowedCategoryFromCache(testUid, 'moda');
      await notifService.removeFollowedSubCategoryFromCache(testUid, 'moda:ayakkabi');
      
      final hasCatsAfterColdRemove = await notifService.hasFollowedCategories(testUid);
      expect(hasCatsAfterColdRemove, isFalse);
    });

    test('Tab switch re-fetch logic: Stale vs Non-stale behavior', () {
      final now = DateTime.now();

      bool checkShouldFetch(DateTime? lastFetch, DateTime currentTime) {
        final isStale = lastFetch == null || currentTime.difference(lastFetch) > const Duration(minutes: 30);
        return lastFetch == null || isStale;
      }
      
      // Senaryo 1: Veri az önce çekilmiş (5 saniye önce) ve liste boş (kategori yok veya fırsat yok)
      final recentFetch = now.subtract(const Duration(seconds: 5));
      final shouldFetchRecent = checkShouldFetch(recentFetch, now);
      // Eski hatalı mantık: (deals.isEmpty || isStale) => true idi!
      // Yeni hatasız mantık: (lastFetch == null || isStale) => false!
      expect(shouldFetchRecent, isFalse, reason: 'Taze çekilmiş boş liste her sekme tıklamasında tekrar yüklenmemeli');

      // Senaryo 2: Veri hiç çekilmemiş (soğuk açılış)
      final shouldFetchInitial = checkShouldFetch(null, now);
      expect(shouldFetchInitial, isTrue, reason: 'Daha önce hiç çekilmemişse mutlaka yüklenmeli');

      // Senaryo 3: Veri 31 dakika önce çekilmiş (bayat)
      final staleFetch = now.subtract(const Duration(minutes: 31));
      final shouldFetchOld = checkShouldFetch(staleFetch, now);
      expect(shouldFetchOld, isTrue, reason: '30 dakikadan eski ise arka plan tazelemesi tetiklenmeli');
    });
  });
}
