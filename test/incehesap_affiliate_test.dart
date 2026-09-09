import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/screens/deal_detail/deal_link_utils.dart';
import 'package:sicak_firsatlar/services/affiliate/adapters/incehesap_affiliate_adapter.dart';
import 'package:sicak_firsatlar/services/affiliate/affiliate_service.dart';

void main() {
  HttpOverrides.global = null;

  group('İncehesap Paylaştıkça Kazan Affiliate Tests', () {
    const canonicalLaptopUrl = 'https://www.incehesap.com/asus-tuf-gaming-f16-fx607vjb-rl136-core-5-210h-16gb-ddr5-512gb-ssd-rtx3050-6gb-16-0-wuxga-165hz-ips-freedos-gaming-laptop-fiyati-91918/';
    const shortLaptopUrl = 'https://www.incehesap.com/u/R5GDA5JqZF/';
    const canonicalOemUrl = 'https://www.incehesap.com/notorious-oem-paket-fiyati-62721/';
    const shortOemUrl = 'https://www.incehesap.com/u/TAIXbK33rm/';

    setUp(() {
      // Test başında şalterin açık olduğundan ve varsayılan adaptörün ayarlı olduğundan emin ol
      AffiliateService.setStoreEnabled('incehesap', true);
      AffiliateService.updateIncehesapSettings(
        isEnabled: true,
        sessionCookie: IncehesapAffiliateAdapter.defaultSessionCookie,
      );
    });

    test('detectStoreFromUrl should detect İncehesap for canonical and shortlink urls', () {
      expect(DealLinkUtils.detectStoreFromUrl(canonicalLaptopUrl), equals('İncehesap'));
      expect(DealLinkUtils.detectStoreFromUrl(shortLaptopUrl), equals('İncehesap'));
      expect(DealLinkUtils.detectStoreFromUrl(canonicalOemUrl), equals('İncehesap'));
      expect(DealLinkUtils.detectStoreFromUrl(shortOemUrl), equals('İncehesap'));
    });

    test('IncehesapAffiliateAdapter canHandle and isAlreadyAffiliate', () {
      final adapter = IncehesapAffiliateAdapter();

      expect(adapter.canHandle(Uri.parse(canonicalLaptopUrl)), isTrue);
      expect(adapter.canHandle(Uri.parse(shortLaptopUrl)), isTrue);
      expect(adapter.canHandle(Uri.parse('https://www.google.com')), isFalse);

      expect(adapter.isAlreadyAffiliate(Uri.parse(shortLaptopUrl)), isTrue);
      expect(adapter.isAlreadyAffiliate(Uri.parse(shortOemUrl)), isTrue);
      expect(adapter.isAlreadyAffiliate(Uri.parse(canonicalLaptopUrl)), isFalse);
    });

    test('extractProductId should extract numeric ID correctly', () {
      final adapter = IncehesapAffiliateAdapter();

      expect(adapter.extractProductId(Uri.parse(canonicalLaptopUrl)), equals('91918'));
      expect(adapter.extractProductId(Uri.parse(canonicalOemUrl)), equals('62721'));
      expect(adapter.extractProductId(Uri.parse('https://www.incehesap.com/test-fiyati-12345/')), equals('12345'));
      expect(adapter.extractProductId(Uri.parse('https://www.incehesap.com/urun.php?urunId=54321')), equals('54321'));
    });

    test('isStoreSupported should return true for İncehesap when enabled', () {
      AffiliateService.setStoreEnabled('incehesap', true);
      expect(AffiliateService.isStoreSupported('İncehesap'), isTrue);
      expect(AffiliateService.isStoreSupported(canonicalLaptopUrl), isTrue);
      expect(AffiliateService.isStoreSupported(shortLaptopUrl), isTrue);

      // Kill-switch: kapalı olduğunda false dönmeli
      AffiliateService.setStoreEnabled('incehesap', false);
      expect(AffiliateService.isStoreSupported('İncehesap'), isFalse);
      expect(AffiliateService.isStoreSupported(canonicalLaptopUrl), isFalse);

      // Test bitimi tekrar aç
      AffiliateService.setStoreEnabled('incehesap', true);
    });

    test('syncFromMap should update settings and sessionCookie from Firestore data', () {
      AffiliateService.syncFromMap({
        'incehesapAffiliateEnabled': true,
        'incehesapSessionCookie': 'mock_session_cookie_123',
      });

      final adapter = AffiliateService.getAdapter(canonicalOemUrl) as IncehesapAffiliateAdapter?;
      expect(adapter, isNotNull);
      expect(adapter!.isEnabled, isTrue);
      expect(adapter.sessionCookie, equals('mock_session_cookie_123'));
    });

    test('convertToAffiliateLink should preserve existing /u/ shortlinks and clean canonical URLs', () {
      final result1 = DealLinkUtils.convertToAffiliateLink(shortLaptopUrl);
      expect(result1, equals(shortLaptopUrl));

      final result2 = DealLinkUtils.convertToAffiliateLink(shortOemUrl);
      expect(result2, equals(shortOemUrl));

      final convertedOem = DealLinkUtils.convertToAffiliateLink(canonicalOemUrl);
      expect(convertedOem, equals(canonicalOemUrl));
    });

    test('resolveAndConvertToAffiliate should resolve shortlink and generate live affiliate link', () async {
      final resolvedShort = await AffiliateService.resolveAndConvertToAffiliate(shortOemUrl);
      expect(resolvedShort, equals(shortOemUrl));

      const mouseUrl = 'https://www.incehesap.com/hawk-gaming-hm120-1k-hz-12500-dpi-tri-mode-kablosuz-bluetooth-beyaz-gaming-mouse-fiyati-90880/';
      final convertedMouse = await AffiliateService.resolveAndConvertToAffiliate(mouseUrl);
      expect(convertedMouse, startsWith('https://www.incehesap.com/u/'));
      expect(convertedMouse, equals('https://www.incehesap.com/u/YuXwryefSh/'));
    });

    test('IncehesapAffiliateAdapter when disabled should fallback to clean canonical URL', () {
      final adapter = IncehesapAffiliateAdapter(
        enabled: false,
      );

      final converted = adapter.convert(Uri.parse('$canonicalLaptopUrl?utm_source=test&ref=xyz'));
      expect(converted, equals(canonicalLaptopUrl));
      expect(converted, isNot(contains('utm_source')));
      expect(converted, isNot(contains('ref=')));
    });

    test('Deal.cleanProductUrl should strip tracking params from Incehesap URLs', () {
      const dirtyUrl = 'https://www.incehesap.com/asus-tuf-gaming-f16-fx607vjb-rl136-core-5-210h-16gb-ddr5-512gb-ssd-rtx3050-6gb-16-0-wuxga-165hz-ips-freedos-gaming-laptop-fiyati-91918/?utm_source=affiliate&utm_medium=paylastikca_kazan&fbclid=12345';
      final clean = Deal.cleanProductUrl(dirtyUrl);
      expect(clean, equals(canonicalLaptopUrl));
      expect(clean, isNot(contains('utm_source')));
      expect(clean, isNot(contains('fbclid')));
    });
  });
}
