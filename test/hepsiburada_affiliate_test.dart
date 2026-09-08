import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/services/affiliate/affiliate_service.dart';
import 'package:sicak_firsatlar/services/affiliate/adapters/hepsiburada_affiliate_adapter.dart';
import 'package:sicak_firsatlar/screens/deal_detail/deal_link_utils.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  group('Hepsiburada LinkGelir (Adjust 7t4g.adj.st) Affiliate Tests', () {
    late HepsiburadaAffiliateAdapter adapter;

    const sampleProduct1 = 'https://www.hepsiburada.com/altinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-dar-kesim-tisort-p-HBCV00004RJ9GF';
    const sampleProduct2 = 'https://www.hepsiburada.com/axe-ice-chill-erkek-deodorant--bodyspray-48-saat-ferahlik-150-ml-p-HBV00000I6DSC';
    const sampleProduct3 = 'https://www.hepsiburada.com/bargello-675-erkek-50-ml-parfum-edp-fresh-p-HBV00000QYSC7?magaza=Bargello';
    const sampleProduct4 = 'https://www.hepsiburada.com/evessan-100x200-kanepe---fitilli-kadife-yikanir-silinir-pratik-yer-yatagi-p-HBCV0000ADWII9';

    setUp(() {
      adapter = HepsiburadaAffiliateAdapter(
        accountName: 'muratcan gokyokus',
        enabled: true,
      );
      AffiliateService.updateHepsiburadaSettings(isEnabled: true, accountName: 'muratcan gokyokus');
    });

    test('canHandle should correctly recognize Hepsiburada URLs and short domains', () {
      expect(adapter.canHandle(Uri.parse(sampleProduct1)), isTrue);
      expect(adapter.canHandle(Uri.parse('https://app.hb.biz/xh5GZgJFADek')), isTrue);
      expect(adapter.canHandle(Uri.parse('https://hb.biz/test')), isTrue);
      expect(adapter.canHandle(Uri.parse('https://7t4g.adj.st/product?sku=HBCV00004RJ9GF')), isTrue);
      expect(adapter.canHandle(Uri.parse('https://www.teknosa.com/urun-p-123')), isFalse);
      expect(adapter.canHandle(Uri.parse('https://www.amazon.com.tr/dp/B08N5WRWNW')), isFalse);
    });

    test('convert should synthesize a complete Adjust 7t4g.adj.st deep link in 0 ms', () {
      final converted = adapter.convert(Uri.parse(sampleProduct1));

      expect(converted.startsWith('https://7t4g.adj.st/product'), isTrue);
      expect(converted.contains('sku=HBCV00004RJ9GF'), isTrue);
      expect(converted.contains('adj_t=10zuiki3_y4q2fze'), isTrue);
      expect(converted.contains('adj_campaign=ux_gelistirmeleri'), isTrue);
      expect(converted.contains('adj_adgroup=muratcan%20gokyokus'), isTrue);
      expect(converted.contains('adj_creative=HBCV00004RJ9GF'), isTrue);
      expect(converted.contains('utm_source=influencer'), isTrue);
      expect(converted.contains('utm_medium=linkgelir'), isTrue);
      expect(converted.contains('adj_fallback='), isTrue);
      expect(converted.contains('adj_deep_link='), isTrue);
    });

    test('convert should synthesize correct deep links for all 4 test SKUs', () {
      final skus = [
        'HBCV00004RJ9GF',
        'HBV00000I6DSC',
        'HBV00000QYSC7',
        'HBCV0000ADWII9',
      ];
      final products = [sampleProduct1, sampleProduct2, sampleProduct3, sampleProduct4];

      for (var i = 0; i < products.length; i++) {
        final result = adapter.convert(Uri.parse(products[i]));
        expect(result.contains('sku=${skus[i]}'), isTrue);
        expect(result.contains('adj_creative=${skus[i]}'), isTrue);
        expect(result.contains('adj_adgroup=muratcan%20gokyokus'), isTrue);
      }
    });

    test('convert should preserve seller/merchantName if present', () {
      final converted = adapter.convert(Uri.parse(sampleProduct3));

      expect(converted.contains('merchantName=Bargello'), isTrue);
    });

    test('isAlreadyAffiliate should recognize own synthesized Adjust link and reject 3rd-party links', () {
      final ownSynthesized = adapter.convert(Uri.parse(sampleProduct1));
      expect(adapter.isAlreadyAffiliate(Uri.parse(ownSynthesized)), isTrue);

      // Başkasına ait Adjust linki
      const otherPersonLink = 'https://7t4g.adj.st/product?sku=HBCV00004RJ9GF&adj_t=10zuiki3_y4q2fze&adj_adgroup=ahmet_yilmaz';
      expect(adapter.isAlreadyAffiliate(Uri.parse(otherPersonLink)), isFalse);

      // Kısa linkler henüz çözümlenmediği için false olmalı
      expect(adapter.isAlreadyAffiliate(Uri.parse('https://app.hb.biz/xh5GZgJFADek')), isFalse);
    });

    test('Anti-Hijack / Unwrap & Retargeting: 3rd party Adjust link should unwrap and retarget to admin', () {
      const thirdPartyAdjust = 'https://7t4g.adj.st/product?sku=HBCV00004RJ9GF&adj_t=10zuiki3_y4q2fze&adj_adgroup=yabanci_kullanici&adj_fallback=https%3A%2F%2Fwww.hepsiburada.com%2Faltinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-dar-kesim-tisort-p-HBCV00004RJ9GF%3Fftid%3Dother_person_code';
      
      final retargeted = adapter.convert(Uri.parse(thirdPartyAdjust));

      expect(retargeted.contains('adj_adgroup=muratcan%20gokyokus'), isTrue);
      expect(retargeted.contains('yabanci_kullanici'), isFalse);
      expect(retargeted.contains('sku=HBCV00004RJ9GF'), isTrue);
    });

    test('Fallback / Kill-Switch: When adapter is disabled, it safely returns clean product URL', () {
      final disabledAdapter = HepsiburadaAffiliateAdapter(
        accountName: 'muratcan gokyokus',
        enabled: false,
      );

      final result = disabledAdapter.convert(Uri.parse(sampleProduct1));
      expect(result, sampleProduct1);
      expect(result.contains('7t4g.adj.st'), isFalse);
    });

    test('Fallback / Kill-Switch: When adapter is disabled and given a 3rd party Adjust link, it unwraps to clean URL', () {
      final disabledAdapter = HepsiburadaAffiliateAdapter(
        accountName: 'muratcan gokyokus',
        enabled: false,
      );
      const thirdPartyAdjust = 'https://7t4g.adj.st/product?sku=HBCV00004RJ9GF&adj_t=10zuiki3_y4q2fze&adj_adgroup=yabanci_kullanici&adj_fallback=https%3A%2F%2Fwww.hepsiburada.com%2Faltinyildiz-classics-erkek-100-pamuk-v-yaka-lacivert-slim-fit-dar-kesim-tisort-p-HBCV00004RJ9GF%3Fftid%3Dother_person_code';

      final result = disabledAdapter.convert(Uri.parse(thirdPartyAdjust));
      expect(result, sampleProduct1);
      expect(result.contains('adj_adgroup'), isFalse);
    });

    test('Deal.cleanProductUrl should unwrap synthesized Adjust URL to canonical product URL', () {
      final synthesized = adapter.convert(Uri.parse(sampleProduct1));

      final clean = Deal.cleanProductUrl(synthesized);
      expect(clean, sampleProduct1);
    });

    test('Deal.displayUrl should cleanly show canonical product URL for users, never Adjust link', () {
      final synthesized = adapter.convert(Uri.parse(sampleProduct1));

      final deal = Deal(
        id: 'hb-1',
        title: 'Altınyıldız Tişört',
        description: 'Test Deal',
        postedBy: 'admin',
        isEditorPick: false,
        price: 299.69,
        link: synthesized,
        cleanUrl: sampleProduct1,
        imageUrl: 'https://example.com/img.jpg',
        store: 'Hepsiburada',
        category: 'moda',
        createdAt: DateTime.now(),
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
      );

      expect(deal.displayUrl, sampleProduct1);
      expect(deal.displayUrl.contains('7t4g.adj.st'), isFalse);
    });

    test('AffiliateService and DealLinkUtils should recognize Hepsiburada as a supported affiliate store', () {
      AffiliateService.setStoreEnabled('hepsiburada', true);
      expect(AffiliateService.isStoreSupported('hepsiburada'), isTrue);
      expect(AffiliateService.isStoreSupported('Hepsiburada'), isTrue);
      expect(AffiliateService.isStoreSupported(sampleProduct1), isTrue);
      expect(DealLinkUtils.isStoreSupported('hepsiburada'), isTrue);
    });

    test('Kill-Switch: When hepsiburadaAffiliateEnabled is false, isStoreSupported returns false and conversion returns clean organic URL', () {
      // 1. Şalteri kapat (Firestore syncFromMap simülasyonu)
      AffiliateService.syncFromMap({'hepsiburadaAffiliateEnabled': false});

      expect(AffiliateService.isStoreEnabled('hepsiburada'), isFalse);
      expect(AffiliateService.isStoreSupported('hepsiburada'), isFalse);
      expect(AffiliateService.isStoreSupported('Hepsiburada'), isFalse);
      expect(AffiliateService.isStoreSupported(sampleProduct1), isFalse);

      // 2. Dönüşüm denendiğinde Adjust linki üretilmemeli, temiz organik link dönmeli
      final converted = AffiliateService.convertToAffiliateLink(sampleProduct1);
      expect(converted, equals(sampleProduct1));
      expect(converted.contains('7t4g.adj.st'), isFalse);

      // 3. Yabancı bir Adjust linki geldiğinde dahi temiz organik linke unwrap edilmeli
      const foreignAdjust = 'https://7t4g.adj.st/product?sku=HBCV0000ADWII9&adj_fallback=https%3A%2F%2Fwww.hepsiburada.com%2Ftest-p-HBCV0000ADWII9';
      final unwrapped = AffiliateService.convertToAffiliateLink(foreignAdjust);
      expect(unwrapped, equals('https://www.hepsiburada.com/test-p-HBCV0000ADWII9'));
      expect(unwrapped.contains('7t4g.adj.st'), isFalse);

      // 4. Şalteri tekrar aç ve doğrulamasını yap
      AffiliateService.syncFromMap({'hepsiburadaAffiliateEnabled': true});
      expect(AffiliateService.isStoreEnabled('hepsiburada'), isTrue);
      expect(AffiliateService.isStoreSupported('hepsiburada'), isTrue);
    });

    test('LinkPreviewService.resolveUrlRedirects should resolve app.hb.biz shortlink to canonical URL', () async {
      const shortUrl = 'https://app.hb.biz/xh5GZgJFADek';
      final linkService = LinkPreviewService();
      final resolved = await linkService.resolveUrlRedirects(shortUrl);

      expect(resolved.contains('hepsiburada.com'), isTrue);
      expect(resolved.contains('HBCV00004RJ9GF'), isTrue);
    });
  });
}
