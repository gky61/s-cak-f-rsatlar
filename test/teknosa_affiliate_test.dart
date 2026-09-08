import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/screens/deal_detail/deal_link_utils.dart';
import 'package:sicak_firsatlar/services/domain_allowlist_service.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';
import 'package:sicak_firsatlar/services/affiliate/adapters/teknosa_affiliate_adapter.dart';
import 'package:sicak_firsatlar/services/scrapers/teknosa_scraper.dart';

void main() {
  HttpOverrides.global = null;

  group('Teknosa TUNE Affiliate Deep-Link Tests', () {
    const productUrl = 'https://www.teknosa.com/yenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989?shopId=2442';
    const paylasKazanUrl = 'https://paylaskazan.teknosa.com/teknosa-F8NSB38NC3';

    test('detectStoreFromUrl should detect Teknosa for canonical, shortlink, and TUNE urls', () {
      expect(DealLinkUtils.detectStoreFromUrl(productUrl), equals('Teknosa'));
      expect(DealLinkUtils.detectStoreFromUrl(paylasKazanUrl), equals('Teknosa'));
      expect(DealLinkUtils.detectStoreFromUrl('https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016'), equals('Teknosa'));
    });

    test('convertToAffiliateLink should convert canonical Teknosa link to TUNE deep-link', () {
      final affiliateLink = DealLinkUtils.convertToAffiliateLink(productUrl);

      expect(affiliateLink, startsWith('https://rdr.btrck.com/aff_c'));
      // Teknosa'nın yerel Paylaş Kazan yönlendirmesiyle uyumlu düz slash '/' standardı
      expect(affiliateLink, contains('aff_sub3=teknosa.com/yenilenmis-iphone-xr'));
      expect(affiliateLink, isNot(contains('aff_sub3=teknosa.com%2F')));

      final uri = Uri.parse(affiliateLink);
      expect(uri.queryParameters['offer_id'], equals('5'));
      expect(uri.queryParameters['aff_id'], equals('1016'));
      expect(uri.queryParameters['source'], equals('906bd201-92dc-4898-914a-10309b2cd576'));
      expect(uri.queryParameters['aff_sub'], equals('906bd201-92dc-4898-914a-10309b2cd576'));
      expect(uri.queryParameters['aff_sub3'], contains('teknosa.com/yenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989'));
      
      final targetUrl = uri.queryParameters['url'];
      expect(targetUrl, isNotNull);
      expect(targetUrl, contains('shopId=2442'));
      expect(targetUrl, contains('utm_source=social_affiliate'));
      expect(targetUrl, contains('utm_medium=paylaskazan'));
      expect(targetUrl, contains('utm_campaign=906bd201-92dc-4898-914a-10309b2cd576'));
    });

    test('convertToAffiliateLink should normalize and upgrade legacy %2F btrck link to plain slash standard', () {
      const legacyBtrckUrl = 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=906bd201-92dc-4898-914a-10309b2cd576&aff_sub=906bd201-92dc-4898-914a-10309b2cd576&aff_sub3=teknosa.com%2Ftcl-mt40x-movetime-mavi-cocuk-saati-p-145059241&url=https%3A%2F%2Fwww.teknosa.com%2Ftcl-mt40x-movetime-mavi-cocuk-saati-p-145059241';

      final upgradedLink = DealLinkUtils.convertToAffiliateLink(legacyBtrckUrl);

      expect(upgradedLink, contains('aff_sub3=teknosa.com/tcl-mt40x-movetime-mavi-cocuk-saati-p-145059241'));
      expect(upgradedLink, isNot(contains('aff_sub3=teknosa.com%2F')));
    });

    test('convertToAffiliateLink should be idempotent and preserve already-converted links', () {
      final affiliateLink = DealLinkUtils.convertToAffiliateLink(productUrl);
      final reConverted = DealLinkUtils.convertToAffiliateLink(affiliateLink);
      expect(reConverted, equals(affiliateLink));

      final preservedShortlink = DealLinkUtils.convertToAffiliateLink(paylasKazanUrl);
      expect(preservedShortlink, equals(paylasKazanUrl));
    });

    test('convertToAffiliateLink should hijack/retarget third-party btrck.com affiliate link to admin UUID', () {
      const otherUserUuid = '11111111-2222-3333-4444-555555555555';
      const thirdPartyBtrckUrl = 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=$otherUserUuid&aff_sub=$otherUserUuid&url=https%3A%2F%2Fwww.teknosa.com%2Fyenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989%3FshopId%3D2442';

      final convertedLink = DealLinkUtils.convertToAffiliateLink(thirdPartyBtrckUrl);

      expect(convertedLink, startsWith('https://rdr.btrck.com/aff_c'));
      final uri = Uri.parse(convertedLink);
      expect(uri.queryParameters['source'], equals('906bd201-92dc-4898-914a-10309b2cd576'));
      expect(uri.queryParameters['aff_sub'], equals('906bd201-92dc-4898-914a-10309b2cd576'));
      expect(uri.queryParameters['source'], isNot(equals(otherUserUuid)));
      expect(uri.queryParameters['url'], contains('utm_campaign=906bd201-92dc-4898-914a-10309b2cd576'));
    });

    test('resolveAndConvertToAffiliate should resolve Paylaş Kazan shortlink and convert to admin affiliate deep-link', () async {
      final convertedLink = await DealLinkUtils.resolveAndConvertToAffiliate(paylasKazanUrl);

      expect(convertedLink, startsWith('https://rdr.btrck.com/aff_c'));
      final uri = Uri.parse(convertedLink);
      expect(uri.queryParameters['source'], equals('906bd201-92dc-4898-914a-10309b2cd576'));
      expect(uri.queryParameters['aff_sub'], equals('906bd201-92dc-4898-914a-10309b2cd576'));
      expect(uri.queryParameters['url'], contains('teknosa.com'));
      expect(uri.queryParameters['url'], contains('-p-790182989'));
      expect(uri.queryParameters['url'], contains('utm_campaign=906bd201-92dc-4898-914a-10309b2cd576'));
    });

    test('Synthesized TUNE link should resolve cleanly back to canonical product URL', () async {
      final affiliateLink = DealLinkUtils.convertToAffiliateLink(productUrl);
      final linkService = LinkPreviewService();
      final resolved = await linkService.resolveTeknosaPaylasKazan(affiliateLink);

      expect(resolved, contains('teknosa.com'));
      expect(resolved, contains('-p-790182989'));
      expect(resolved, contains('shopId=2442'));
      expect(resolved, isNot(contains('rdr.btrck.com')));
    });

    test('DomainAllowlistService should validate synthesized TUNE affiliate URL end-to-end', () async {
      final affiliateLink = DealLinkUtils.convertToAffiliateLink(productUrl);
      final validationResult = await DomainAllowlistService.validateUrl(affiliateLink);

      expect(validationResult, equals(UrlValidationResult.valid));
    });

    test('Fallback / Kill-Switch: When adapter is disabled, it safely falls back to canonical product URL', () {
      final disabledAdapter = TeknosaAffiliateAdapter(enabled: false);
      expect(disabledAdapter.isEnabled, isFalse);

      final result = disabledAdapter.convert(Uri.parse(productUrl));
      expect(result, equals(productUrl));
      expect(result, isNot(contains('btrck.com')));
    });

    test('Fallback / Kill-Switch: When adapter is disabled and given a third-party btrck link, it unwraps and returns clean product URL', () {
      const otherUserUuid = '99999999-8888-7777-6666-555555555555';
      const thirdPartyBtrckUrl = 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=$otherUserUuid&url=https%3A%2F%2Fwww.teknosa.com%2Fyenilenmis-iphone-xr-128-gb-mavi-cep-telefonu-1-yil-garantili-a-kalite-p-790182989%3FshopId%3D2442';

      final disabledAdapter = TeknosaAffiliateAdapter(enabled: false);
      final result = disabledAdapter.convert(Uri.parse(thirdPartyBtrckUrl));

      expect(result, contains('teknosa.com'));
      expect(result, contains('-p-790182989'));
      expect(result, isNot(contains('btrck.com')));
      expect(result, isNot(contains(otherUserUuid)));
    });

    test('Scraping Independence: Canonical product URL can be handled by TeknosaScraper independently of affiliate conversion', () {
      final scraper = TeknosaScraper();
      expect(scraper.canHandle(productUrl), isTrue);
      expect(scraper.domain, equals('teknosa.com'));
    });

    test('Store Gating: isStoreSupported should only return true for isAffiliateReady stores (Teknosa)', () {
      // Desteklenen mağazalar (Şimdilik yalnızca Teknosa)
      expect(DealLinkUtils.isStoreSupported('teknosa'), isTrue);
      expect(DealLinkUtils.isStoreSupported('Teknosa'), isTrue);
      expect(DealLinkUtils.isStoreSupported(productUrl), isTrue);
      expect(DealLinkUtils.isStoreSupported('https://rdr.btrck.com/aff_c?offer_id=5'), isTrue);

      // Canlıya alınan mağazalar (Teknosa, Hepsiburada ve Amazon)
      expect(DealLinkUtils.isStoreSupported('hepsiburada'), isTrue);
      expect(DealLinkUtils.isStoreSupported('Hepsiburada'), isTrue);
      expect(DealLinkUtils.isStoreSupported('https://www.hepsiburada.com/urun-p-123'), isTrue);
      expect(DealLinkUtils.isStoreSupported('amazon'), isTrue);
      expect(DealLinkUtils.isStoreSupported('Amazon'), isTrue);
      expect(DealLinkUtils.isStoreSupported('https://www.amazon.com.tr/dp/B08N5WRWNW'), isTrue);

      // Henüz canlıya alınmamış veya taslak olan mağazalar (Trendyol, N11, vb.)
      expect(DealLinkUtils.isStoreSupported('trendyol'), isFalse);
      expect(DealLinkUtils.isStoreSupported('Trendyol'), isFalse);
      expect(DealLinkUtils.isStoreSupported('https://www.trendyol.com/brand/product-p-123'), isFalse);
      expect(DealLinkUtils.isStoreSupported('n11'), isFalse);
      expect(DealLinkUtils.isStoreSupported('zara'), isFalse);
      expect(DealLinkUtils.isStoreSupported(null), isFalse);
      expect(DealLinkUtils.isStoreSupported(''), isFalse);
    });

    test('Store Gating: convertToAffiliateLink should only convert supported stores and leave others untouched', () {
      const trendyolUrl = 'https://www.trendyol.com/apple/iphone-13-128gb-yildiz-isigi-p-150247656';
      const n11Url = 'https://www.n11.com/urun/apple-iphone-13-128-gb-2152864';

      // Trendyol ve N11 henüz üretim aşamasında olmadığı için dönüştürülmemeli, orijinal URL korunmalı
      expect(DealLinkUtils.convertToAffiliateLink(trendyolUrl), equals(trendyolUrl));
      expect(DealLinkUtils.convertToAffiliateLink(n11Url), equals(n11Url));

      // Teknosa ise başarıyla btrck linkine dönüştürülmeli
      expect(DealLinkUtils.convertToAffiliateLink(productUrl), startsWith('https://rdr.btrck.com/aff_c'));
    });
  });
}


