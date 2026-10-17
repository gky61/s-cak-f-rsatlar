import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('Deal.cleanProductUrl Tests', () {
    test('Should completely strip query parameters for major stores (Amazon, Trendyol)', () {
      const url1 = 'https://www.trendyol.com/urun-123?utm_source=firsatkolik&merchantId=777';
      expect(Deal.cleanProductUrl(url1), 'https://www.trendyol.com/urun-123');

      const url2 = 'https://www.amazon.com.tr/dp/B07K3TWJ5J?ref=cm_sw_r_apan_dp_PNPYF5F3PHB7M9Q4T45D&ref_=cm_sw_r_apan_dp_PNPYF5F3PHB7M9Q4T45D&social_share=cm_sw_r_apan_dp_PNPYF5F3PHB7M9Q4T45D';
      expect(Deal.cleanProductUrl(url2), 'https://www.amazon.com.tr/dp/B07K3TWJ5J');
    });

    test('Should keep product ID parameters for custom domains', () {
      const url = 'https://www.example.com/product.php?id=123&utm_source=some_campaign';
      expect(Deal.cleanProductUrl(url), 'https://www.example.com/product.php?id=123');
    });

    test('Should strip non-product parameters for custom domains', () {
      const url = 'https://www.example.com/item?id=999&tracking_id=abc&fbclid=123';
      expect(Deal.cleanProductUrl(url), 'https://www.example.com/item?id=999');
    });

    test('Should handle trailing question mark gracefully', () {
      const url = 'https://www.trendyol.com/urun-123?';
      expect(Deal.cleanProductUrl(url), 'https://www.trendyol.com/urun-123');
    });

    test('Should return original string on parsing error', () {
      const url = 'not-a-valid-url-123';
      expect(Deal.cleanProductUrl(url), url);
    });

    test('Should unwrap btrck.com affiliate URL to clean canonical Teknosa product URL', () {
      const btrckUrl = 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=906bd201-92dc-4898-914a-10309b2cd576&aff_sub=906bd201-92dc-4898-914a-10309b2cd576&aff_sub3=teknosa.com/tcl-mt40x-mavi-akilli-cocuk-saati-p-145059639&url=https%3A%2F%2Fwww.teknosa.com%2Ftcl-mt40x-mavi-akilli-cocuk-saati-p-145059639%3Futm_source%3Dsocial_affiliate%26utm_medium%3Dpaylaskazan%26utm_campaign%3D906bd201-92dc-4898-914a-10309b2cd576';
      expect(Deal.cleanProductUrl(btrckUrl), 'https://www.teknosa.com/tcl-mt40x-mavi-akilli-cocuk-saati-p-145059639');
    });

    test('Should unwrap btrck.com affiliate URL via aff_sub3 fallback', () {
      const btrckUrlNoParam = 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&aff_sub3=teknosa.com/apple-iphone-13-128gb-yildiz-isigi-akilli-telefon-p-125078170';
      expect(Deal.cleanProductUrl(btrckUrlNoParam), 'https://www.teknosa.com/apple-iphone-13-128gb-yildiz-isigi-akilli-telefon-p-125078170');
    });

    test('Should normalize Amazon URLs to canonical /dp/ASIN regardless of title slug variations', () {
      const slugUrl = 'https://www.amazon.com.tr/Apple-iPhone-15-128-GB/dp/B0CHX1W1XY?tag=spambot&ref=abc';
      expect(Deal.cleanProductUrl(slugUrl), 'https://www.amazon.com.tr/dp/B0CHX1W1XY');

      const plainUrl = 'https://www.amazon.com.tr/dp/B0CHX1W1XY';
      expect(Deal.cleanProductUrl(plainUrl), 'https://www.amazon.com.tr/dp/B0CHX1W1XY');

      const gpUrl = 'https://www.amazon.com.tr/gp/product/B0CHX1W1XY/ref=ox_sc_act_title_1';
      expect(Deal.cleanProductUrl(gpUrl), 'https://www.amazon.com.tr/dp/B0CHX1W1XY');

      const lowercaseAsinUrl = 'https://www.amazon.com.tr/product-slug/dp/b0chx1w1xy';
      expect(Deal.cleanProductUrl(lowercaseAsinUrl), 'https://www.amazon.com.tr/dp/B0CHX1W1XY');
    });

    test('Should preserve Hepsiburada magaza parameter while stripping tracking parameters', () {
      const hbWithSeller = 'https://www.hepsiburada.com/apple-iphone-15-128-gb-p-HBCV00004WO64Y?magaza=Hepsiburada&utm_source=firsatkolik&wt_inf=1';
      expect(Deal.cleanProductUrl(hbWithSeller), 'https://www.hepsiburada.com/apple-iphone-15-128-gb-p-HBCV00004WO64Y?magaza=Hepsiburada');

      const hbWithoutSeller = 'https://www.hepsiburada.com/apple-iphone-15-128-gb-p-HBCV00004WO64Y?utm_source=firsatkolik';
      expect(Deal.cleanProductUrl(hbWithoutSeller), 'https://www.hepsiburada.com/apple-iphone-15-128-gb-p-HBCV00004WO64Y');
    });

    test('Should preserve Teknosa shopId parameter while stripping tracking parameters', () {
      const teknosaWithShop = 'https://www.teknosa.com/apple-iphone-15-128gb-p-125078546?shopId=2442&utm_source=social_affiliate&utm_medium=paylaskazan';
      expect(Deal.cleanProductUrl(teknosaWithShop), 'https://www.teknosa.com/apple-iphone-15-128gb-p-125078546?shopId=2442');

      const teknosaWithoutShop = 'https://www.teknosa.com/apple-iphone-15-128gb-p-125078546?utm_source=social_affiliate';
      expect(Deal.cleanProductUrl(teknosaWithoutShop), 'https://www.teknosa.com/apple-iphone-15-128gb-p-125078546');
    });

    test('FS-DEAL-13: Should strip URL fragment anchors (#reviews, #fiyat) to ensure deterministic cleanUrl deduplication', () {
      const urlWithFragment = 'https://www.trendyol.com/brand/product-p-12345?utm_source=test#reviews';
      expect(Deal.cleanProductUrl(urlWithFragment), 'https://www.trendyol.com/brand/product-p-12345');

      const amazonWithFragment = 'https://www.amazon.com.tr/dp/B07K3TWJ5J?ref=abc#customerReviews';
      expect(Deal.cleanProductUrl(amazonWithFragment), 'https://www.amazon.com.tr/dp/B07K3TWJ5J');
    });
  });

  group('Deal.displayUrl Tests', () {
    Deal createTestDeal({required String link, required String cleanUrl}) {
      return Deal(
        id: '1',
        title: 'Test Deal',
        description: 'Desc',
        price: 100,
        link: link,
        cleanUrl: cleanUrl,
        imageUrl: 'https://example.com/img.jpg',
        store: 'Teknosa',
        category: 'elektronik',
        createdAt: DateTime.now(),
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        postedBy: 'admin',
        isEditorPick: false,
      );
    }

    test('Should return cleanUrl when valid and non-affiliate', () {
      final deal = createTestDeal(
        link: 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=123&url=https%3A%2F%2Fwww.teknosa.com%2Furun-p-123',
        cleanUrl: 'https://www.teknosa.com/urun-p-123',
      );
      expect(deal.displayUrl, 'https://www.teknosa.com/urun-p-123');
    });

    test('Should unwrap link if cleanUrl is empty', () {
      final deal = createTestDeal(
        link: 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=123&url=https%3A%2F%2Fwww.teknosa.com%2Furun-p-123%3Futm_source%3Dsocial_affiliate',
        cleanUrl: '',
      );
      expect(deal.displayUrl, 'https://www.teknosa.com/urun-p-123');
    });

    test('Should unwrap link if cleanUrl was mistakenly stored as btrck affiliate URL', () {
      final deal = createTestDeal(
        link: 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=123&url=https%3A%2F%2Fwww.teknosa.com%2Furun-p-123',
        cleanUrl: 'https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=123&url=https%3A%2F%2Fwww.teknosa.com%2Furun-p-123',
      );
      expect(deal.displayUrl, 'https://www.teknosa.com/urun-p-123');
    });
  });

  group('Deal.buildCanonicalCleanUrl Tests', () {
    test('Should fallback to cleanProductUrl when canonicalUrl is null or empty', () {
      const raw = 'https://www.hepsiburada.com/urun-p-123?magaza=Satici&utm_source=firsatkolik';
      expect(
        Deal.buildCanonicalCleanUrl(raw, null),
        'https://www.hepsiburada.com/urun-p-123?magaza=Satici',
      );
      expect(
        Deal.buildCanonicalCleanUrl(raw, ''),
        'https://www.hepsiburada.com/urun-p-123?magaza=Satici',
      );
    });

    test('Should transfer Hepsiburada magaza parameter to canonical URL', () {
      const rawVariant = 'https://www.hepsiburada.com/defacto-mont-p-HBCV00009ZM96N?magaza=DeFacto&utm_source=firsatkolik';
      const canonical = 'https://www.hepsiburada.com/defacto-mont-pm-HBC00009Z5HVU';
      expect(
        Deal.buildCanonicalCleanUrl(rawVariant, canonical),
        'https://www.hepsiburada.com/defacto-mont-pm-HBC00009Z5HVU?magaza=DeFacto',
      );
    });

    test('Should transfer Teknosa shopId parameter to canonical URL', () {
      const rawVariant = 'https://www.teknosa.com/telefon-p-123?shopId=999&utm_source=affiliate';
      const canonical = 'https://www.teknosa.com/telefon-p-123';
      expect(
        Deal.buildCanonicalCleanUrl(rawVariant, canonical),
        'https://www.teknosa.com/telefon-p-123?shopId=999',
      );
    });

    test('Should reject mismatched host in canonical URL for security', () {
      const raw = 'https://www.hepsiburada.com/urun-p-123?magaza=DeFacto';
      const maliciousCanonical = 'https://www.phishing-site.com/fake-product';
      expect(
        Deal.buildCanonicalCleanUrl(raw, maliciousCanonical),
        'https://www.hepsiburada.com/urun-p-123?magaza=DeFacto',
      );
    });
  });
}
