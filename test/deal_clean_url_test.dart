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
}
