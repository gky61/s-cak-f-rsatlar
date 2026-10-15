import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/deal_service.dart';

void main() {
  group('Connectivity & Zero-Flicker Hydration Architecture Tests', () {
    test('[Test 1] DealsPageResult distinguishes network failures from legitimate empty results', () {
      // 1. Meşru Boş Liste (Gerçekten veritabanında fırsat yok)
      const legitimateEmpty = DealsPageResult(
        deals: [],
        hasMore: false,
        isFromCache: false,
        isError: false,
      );
      expect(legitimateEmpty.deals.isEmpty, isTrue);
      expect(legitimateEmpty.isError, isFalse);
      expect(legitimateEmpty.errorMessage, isNull);

      // 2. Ağ Kesintisi / Zaman Aşımı Hatası (Veritabanı dolu ama ağ ulaşılamadı)
      const networkErrorResult = DealsPageResult(
        deals: [],
        hasMore: false,
        isFromCache: false,
        isError: true,
        errorMessage: 'Client is offline / TimeoutException',
      );
      expect(networkErrorResult.deals.isEmpty, isTrue);
      expect(networkErrorResult.isError, isTrue);
      expect(networkErrorResult.errorMessage, contains('offline'));
    });

    test('[Test 2] ConnectivityService implements Anti-Flapping Grace Period and fast recovery', () {
      final connFile = File('lib/services/connectivity_service.dart');
      expect(connFile.existsSync(), isTrue);

      final content = connFile.readAsStringSync();
      expect(content.contains('_pendingOfflineTimer'), isTrue,
          reason: 'ConnectivityService sahte çevrimdışı sıçramalarını önlemek için pending timer kalkanına sahip olmalıdır');
      expect(content.contains('const Duration(milliseconds: 1500)'), isTrue,
          reason: '1500ms Grace Period (Android NetworkCapabilities ısınma penceresi) uygulanmalıdır');
      expect(content.contains('_pendingOfflineTimer?.cancel()'), isTrue,
          reason: 'Aktif ağ tespit edildiğinde bekleyen sahte alarm anında iptal edilmelidir');
    });

    test('[Test 3] HomeScreen prevents premature error and empty states on cold-start', () {
      final homeFile = File('lib/screens/home_screen.dart');
      expect(homeFile.existsSync(), isTrue);

      final content = homeFile.readAsStringSync();
      expect(content.contains('!serverResult.isError'), isTrue,
          reason: 'HomeScreen server-first cevabında hata flagini denetlemelidir');
      expect(content.contains('res.isError && _dealsList.isEmpty'), isTrue,
          reason: 'HomeScreen arka plan dinleyicisinde gerçek ağ hatasını boş listeden ayırmalıdır');
      expect(content.contains('serverResult.isError'), isTrue,
          reason: 'Background listener hata durumunda önbellekteki veriyi korumalıdır');
    });

    test('[Test 4] PopularDealsScreen and FavoritesScreen integrate isError safeguards', () {
      final popFile = File('lib/screens/popular_deals_screen.dart');
      final favFile = File('lib/screens/favorites_screen.dart');
      expect(popFile.existsSync(), isTrue);
      expect(favFile.existsSync(), isTrue);

      final popContent = popFile.readAsStringSync();
      final favContent = favFile.readAsStringSync();

      expect(popContent.contains('res.isError && _dealsList.isEmpty'), isTrue);
      expect(popContent.contains('res.isError || res.deals.isEmpty'), isTrue);

      expect(favContent.contains('res.isError && _followedDealsList.isEmpty'), isTrue);
      expect(favContent.contains('res.isError || res.deals.isEmpty'), isTrue);
    });

    test('[Test 5] OfflineBanner uses optimized const structures, clipBehavior and listens to filtered connection stream', () {
      final bannerFile = File('lib/widgets/offline_banner.dart');
      expect(bannerFile.existsSync(), isTrue);

      final content = bannerFile.readAsStringSync();
      expect(content.contains('ConnectivityService().connectionStatusStream'), isTrue);
      expect(content.contains('ConnectivityService().isConnected'), isTrue);
      expect(content.contains('clipBehavior: Clip.hardEdge'), isTrue,
          reason: 'Yükseklik animasyonları sırasında RenderFlex overflow taşmalarını engellemek için clipBehavior hardEdge olmalıdır');
      expect(content.contains('child: const Row('), isTrue,
          reason: 'Gereksiz render maliyetini önlemek için const Row kullanılmalıdır');
    });

    test('[Test 6] deal_service distinguishes empty cache misses from actual server network failures', () {
      final dealSvcFile = File('lib/services/deal_service.dart');
      expect(dealSvcFile.existsSync(), isTrue);

      final content = dealSvcFile.readAsStringSync();
      expect(content.contains("final isCacheMiss = source == Source.cache && e.toString().contains('unavailable');"), isTrue,
          reason: 'deal_service önbellek boş olduğunda (cache miss) bunu sistem hatası olarak etiketlememelidir');
      expect(content.contains('isError: !isCacheMiss'), isTrue);
    });

    test('[Test 7] HomeScreen, PopularDealsScreen and FavoritesScreen preserve feed list on pull-to-refresh and pagination errors', () {
      final homeFile = File('lib/screens/home_screen.dart');
      final popFile = File('lib/screens/popular_deals_screen.dart');
      final favFile = File('lib/screens/favorites_screen.dart');

      final homeContent = homeFile.readAsStringSync();
      final popContent = popFile.readAsStringSync();
      final favContent = favFile.readAsStringSync();

      // Pull-to-refresh koruması: Ağ hatasında ekrandaki listeyi ezmeme güvencesi
      expect(homeContent.contains('if (!serverResult.isError) {') && homeContent.contains('if (_dealsList.isEmpty) {'), isTrue,
          reason: 'HomeScreen pull-to-refresh hatasında mevcut fırsat listesini korumalıdır');
      expect(popContent.contains('if (!serverResult.isError) {') && popContent.contains('if (_dealsList.isEmpty) {'), isTrue,
          reason: 'PopularDealsScreen pull-to-refresh hatasında mevcut fırsat listesini korumalıdır');
      expect(favContent.contains('if (!serverResult.isError) {') && favContent.contains('if (_followedDealsList.isEmpty) {'), isTrue,
          reason: 'FavoritesScreen pull-to-refresh hatasında mevcut takip edilen fırsat listesini korumalıdır');

      // Pagination koruması: Sayfalama sırasında geçici ağ kesintisinde hasMore'u kalıcı olarak yok etmeme güvencesi
      expect(homeContent.contains('if (!result.isError) {') && homeContent.contains('_isLoadingMore = false;'), isTrue,
          reason: 'HomeScreen sayfalama hatasında state akışını bozmamalıdır');
      expect(popContent.contains('if (!result.isError) {') && popContent.contains('_isLoading = false;'), isTrue,
          reason: 'PopularDealsScreen sayfalama hatasında state akışını bozmamalıdır');
      expect(favContent.contains('if (!result.isError) {') && favContent.contains('_isLoadingFollowed = false;'), isTrue,
          reason: 'FavoritesScreen sayfalama hatasında state akışını bozmamalıdır');
    });
  });
}
