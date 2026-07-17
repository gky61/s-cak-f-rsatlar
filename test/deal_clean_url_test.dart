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
  });
}
