import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/services/affiliate/affiliate_service.dart';
import 'package:sicak_firsatlar/services/affiliate/adapters/amazon_affiliate_adapter.dart';
import 'package:sicak_firsatlar/screens/deal_detail/deal_link_utils.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  group('Amazon Associates TR (amazon.com.tr) Affiliate Tests', () {
    late AmazonAffiliateAdapter adapter;

    const sampleProduct1 = 'https://www.amazon.com.tr/dp/B08N5WRWNW';
    const sampleProductWithSlug = 'https://www.amazon.com.tr/Apple-iPhone-13-128-GB/dp/B09G96KG8R';
    const sampleProductGp = 'https://www.amazon.com.tr/gp/product/B07PGL2ZSL';
    const sampleProductAw = 'https://www.amazon.com.tr/gp/aw/d/B08L5WHFT9';

    setUp(() {
      adapter = AmazonAffiliateAdapter(
        tag: 'firsatkolik-21',
        enabled: true,
      );
      AffiliateService.updateAmazonSettings(isEnabled: true, tag: 'firsatkolik-21');
    });

    test('canHandle should correctly recognize Amazon domains and shortlink domains', () {
      expect(adapter.canHandle(Uri.parse(sampleProduct1)), isTrue);
      expect(adapter.canHandle(Uri.parse(sampleProductWithSlug)), isTrue);
      expect(adapter.canHandle(Uri.parse('https://amzn.eu/d/097K8DSA')), isTrue);
      expect(adapter.canHandle(Uri.parse('https://amzn.to/test1234')), isTrue);
      expect(adapter.canHandle(Uri.parse('https://link.amazon/test')), isTrue);
      expect(adapter.canHandle(Uri.parse('https://www.hepsiburada.com/urun-p-123')), isFalse);
      expect(adapter.canHandle(Uri.parse('https://www.teknosa.com/urun-p-123')), isFalse);
    });

    test('convert should synthesize canonical Amazon URL with tag=firsatkolik-21 in 0 ms', () {
      final converted = adapter.convert(Uri.parse(sampleProduct1));

      expect(converted.contains('amazon.com.tr/dp/B08N5WRWNW'), isTrue);
      expect(converted.contains('tag=firsatkolik-21'), isTrue);
      expect(converted.startsWith('https://'), isTrue);
    });

    test('convert should extract ASIN from various Amazon URL patterns (/dp, /slug/dp, /gp/product, /gp/aw/d)', () {
      final products = [
        sampleProduct1,
        sampleProductWithSlug,
        sampleProductGp,
        sampleProductAw,
      ];
      final expectedAsins = [
        'B08N5WRWNW',
        'B09G96KG8R',
        'B07PGL2ZSL',
        'B08L5WHFT9',
      ];

      for (var i = 0; i < products.length; i++) {
        final result = adapter.convert(Uri.parse(products[i]));
        expect(result.contains('/dp/${expectedAsins[i]}'), isTrue,
            reason: 'Failed for ${products[i]}');
        expect(result.contains('tag=firsatkolik-21'), isTrue);
      }
    });

    test('convert should strip tracking parameters and garbage (ref, linkCode, ascsubtag, social_share)', () {
      const urlWithGarbage = 'https://www.amazon.com.tr/dp/B08N5WRWNW?ref_=cm_sw_r_apan_dp_097K8DSA&social_share=cm_sw_r_apan_dp_097K8DSA&linkCode=ll1&ascsubtag=test_subtag';
      final converted = adapter.convert(Uri.parse(urlWithGarbage));

      expect(converted.contains('tag=firsatkolik-21'), isTrue);
      expect(converted.contains('ref_='), isFalse);
      expect(converted.contains('social_share'), isFalse);
      expect(converted.contains('linkCode'), isFalse);
      expect(converted.contains('ascsubtag'), isFalse);
      expect(converted, 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=firsatkolik-21');
    });

    test('isAlreadyAffiliate should recognize own firsatkolik-21 tag and reject 3rd-party tags', () {
      final ownSynthesized = adapter.convert(Uri.parse(sampleProduct1));
      expect(adapter.isAlreadyAffiliate(Uri.parse(ownSynthesized)), isTrue);

      // Başkasına ait tag içeren link
      const otherPersonLink = 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=baskasinin_tagi-21';
      expect(adapter.isAlreadyAffiliate(Uri.parse(otherPersonLink)), isFalse);

      // Kısa linkler henüz çözümlenmediği için false olmalı
      expect(adapter.isAlreadyAffiliate(Uri.parse('https://amzn.eu/d/097K8DSA')), isFalse);
    });

    test('Anti-Hijack / Unwrap & Retargeting: 3rd party Amazon affiliate link should retarget to firsatkolik-21', () {
      const thirdPartyUrl = 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=yabanci_affiliate-21&linkCode=ll1&ascsubtag=12345';
      final retargeted = adapter.convert(Uri.parse(thirdPartyUrl));

      expect(retargeted.contains('tag=firsatkolik-21'), isTrue);
      expect(retargeted.contains('yabanci_affiliate-21'), isFalse);
      expect(retargeted.contains('linkCode'), isFalse);
      expect(retargeted.contains('ascsubtag'), isFalse);
      expect(retargeted, 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=firsatkolik-21');
    });

    test('Fallback / Kill-Switch: When adapter is disabled, it safely returns clean product URL without tag', () {
      final disabledAdapter = AmazonAffiliateAdapter(
        tag: 'firsatkolik-21',
        enabled: false,
      );

      final result = disabledAdapter.convert(Uri.parse(sampleProduct1));
      expect(result, 'https://www.amazon.com.tr/dp/B08N5WRWNW');
      expect(result.contains('tag='), isFalse);
    });

    test('Fallback / Kill-Switch: When adapter is disabled and given a 3rd party link, it unwraps to clean URL', () {
      final disabledAdapter = AmazonAffiliateAdapter(
        tag: 'firsatkolik-21',
        enabled: false,
      );
      const thirdPartyUrl = 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=yabanci_tag-21&ref=test';

      final result = disabledAdapter.convert(Uri.parse(thirdPartyUrl));
      expect(result, 'https://www.amazon.com.tr/dp/B08N5WRWNW');
      expect(result.contains('tag='), isFalse);
      expect(result.contains('ref='), isFalse);
    });

    test('Deal.cleanProductUrl should strip tag and query parameters leaving clean canonical product URL', () {
      final synthesized = adapter.convert(Uri.parse(sampleProduct1));

      final clean = Deal.cleanProductUrl(synthesized);
      expect(clean, sampleProduct1);
      expect(clean.contains('tag='), isFalse);
    });

    test('Deal.displayUrl should cleanly show canonical product URL for users, never tag', () {
      final synthesized = adapter.convert(Uri.parse(sampleProduct1));

      final deal = Deal(
        id: 'amz-1',
        title: 'Amazon Test Ürün',
        description: 'Test Deal',
        postedBy: 'admin',
        isEditorPick: false,
        price: 999.00,
        link: synthesized,
        cleanUrl: sampleProduct1,
        imageUrl: 'https://example.com/img.jpg',
        store: 'Amazon',
        category: 'elektronik',
        createdAt: DateTime.now(),
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
      );

      expect(deal.displayUrl, sampleProduct1);
      expect(deal.displayUrl.contains('tag='), isFalse);
    });

    test('AffiliateService and DealLinkUtils should recognize Amazon as a supported affiliate store', () {
      AffiliateService.setStoreEnabled('amazon', true);
      expect(AffiliateService.isStoreSupported('amazon'), isTrue);
      expect(AffiliateService.isStoreSupported('Amazon'), isTrue);
      expect(AffiliateService.isStoreSupported(sampleProduct1), isTrue);
      expect(DealLinkUtils.isStoreSupported('amazon'), isTrue);
    });

    test('Kill-Switch: When amazonAffiliateEnabled is false, isStoreSupported returns false and conversion returns clean organic URL', () {
      // 1. Şalteri kapat (Firestore syncFromMap simülasyonu)
      AffiliateService.syncFromMap({'amazonAffiliateEnabled': false});

      expect(AffiliateService.isStoreEnabled('amazon'), isFalse);
      expect(AffiliateService.isStoreSupported('amazon'), isFalse);
      expect(AffiliateService.isStoreSupported('Amazon'), isFalse);
      expect(AffiliateService.isStoreSupported(sampleProduct1), isFalse);

      // 2. Dönüşüm denendiğinde tag eklenmemeli, temiz organik link dönmeli
      final converted = AffiliateService.convertToAffiliateLink(sampleProduct1);
      expect(converted, equals(sampleProduct1));
      expect(converted.contains('tag='), isFalse);

      // 3. Yabancı bir Amazon linki geldiğinde dahi temiz organik linke unwrap edilmeli
      const foreignLink = 'https://www.amazon.com.tr/dp/B08N5WRWNW?tag=baskasi-21&ref=test';
      final unwrapped = AffiliateService.convertToAffiliateLink(foreignLink);
      expect(unwrapped, equals('https://www.amazon.com.tr/dp/B08N5WRWNW'));
      expect(unwrapped.contains('tag='), isFalse);

      // 4. Şalteri tekrar aç ve doğrulamasını yap
      AffiliateService.syncFromMap({'amazonAffiliateEnabled': true});
      expect(AffiliateService.isStoreEnabled('amazon'), isTrue);
      expect(AffiliateService.isStoreSupported('amazon'), isTrue);
    });

    test('LinkPreviewService.resolveUrlRedirects should resolve amzn.eu mobile share shortlink to canonical URL', () async {
      const shortUrl = 'https://amzn.eu/d/097K8DSA';
      final linkService = LinkPreviewService();
      final resolved = await linkService.resolveUrlRedirects(shortUrl);

      expect(resolved.contains('amazon.com.tr'), isTrue);
      expect(AmazonAffiliateAdapter.extractAsin(resolved), isNotNull);
    });
  });
}
