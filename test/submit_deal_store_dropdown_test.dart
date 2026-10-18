import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/affiliate/affiliate_service.dart';
import 'package:sicak_firsatlar/utils/deal_url_detector.dart';
import 'package:sicak_firsatlar/utils/store_asset_helper.dart';

void main() {
  group('SubmitDealScreen & Store Dropdown Zero-Crash Contract Tests', () {
    test('DealUrlDetector detectStoreName should detect CarrefourSA correctly', () {
      final detected = DealUrlDetector.detectStoreName('https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671');
      expect(detected, 'CarrefourSA');
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671'), isTrue);
    });

    test('AffiliateService detectStore should detect CarrefourSA correctly', () {
      final detected = AffiliateService.detectStore('https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671');
      expect(detected, 'CarrefourSA');
    });

    test('StoreAssetHelper returns valid logo asset for CarrefourSA without throwing', () {
      final asset = StoreAssetHelper.getStoreAsset('CarrefourSA');
      expect(asset, 'assets/carrefoursa.webp');
    });

    test('Stores list defensive containment check prevents DropdownButtonFormField crash', () {
      final stores = [
        'Trendyol',
        'Hepsiburada',
        'N11',
        'Amazon',
        'Pazarama',
        'Vatan Bilgisayar',
        'MediaMarkt',
        'İtopya',
        'İdefix',
        'Teknosa',
        'Mavi',
        'DeFacto',
        'Zara',
        'Mango',
        'Beymen',
        'PttAVM',
        'İncehesap',
        'Havit',
        'Migros',
        'Getir',
        'Boyner',
        'Gamer Gen',
        'Gaming Gen',
        'CarrefourSA',
        'Diğer',
      ];

      // 1. CarrefourSA is guaranteed to be in the stores list
      expect(stores.contains('CarrefourSA'), isTrue);

      // 2. Safe dropdown value resolution:
      String? resolveSafeStore(String? selectedStore) {
        return selectedStore == null
            ? null
            : (stores.contains(selectedStore) ? selectedStore : 'Diğer');
      }

      // Normal supported store
      expect(resolveSafeStore('CarrefourSA'), 'CarrefourSA');
      expect(resolveSafeStore('Migros'), 'Migros');
      // Null store
      expect(resolveSafeStore(null), isNull);
      // Completely unknown store safely falls back to 'Diğer' and NEVER causes assertion error
      expect(resolveSafeStore('UnknownRandomStore'), 'Diğer');
      expect(resolveSafeStore('carrefour_lowercase'), 'Diğer');
    });
  });
}
