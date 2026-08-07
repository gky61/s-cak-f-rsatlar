import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('Amazon Depo (smid=A215JX4S9CANSO) Dart Unit Testleri', () {
    test('smid=A215JX4S9CANSO içeren URL\'ler Depo Ürünü olarak tespit edilmeli', () {
      final depoUrls = [
        'https://www.amazon.com.tr/dp/B0F9Z1D5S3?smid=A215JX4S9CANSO&th=1&tag=firsatkolik-21',
        'https://www.amazon.com.tr/dp/B0BJQP23Y8?smid=A215JX4S9CANSO&th=1&ref=123',
        'https://www.amazon.com.tr/dp/B0D7VNP61V?smid=A215JX4S9CANSO&th=1&tag=test',
        'https://www.amazon.com.tr/dp/B0DZDC5R6C?smid=a215jx4s9canso&th=1&tag=lowercase_check',
      ];

      for (final url in depoUrls) {
        expect(Deal.checkIsAmazonWarehouse(url), isTrue, reason: 'Depo tespiti başarısız: $url');
      }
    });

    test('Normal ürün URL\'leri Depo Ürünü olarak etiketlenmemeli', () {
      final normalUrls = [
        'https://www.amazon.com.tr/dp/B08N5WRWNW',
        'https://www.amazon.com.tr/gp/product/B08N5WRWNW',
        'https://www.trendyol.com/brand/product-p-12345',
      ];

      for (final url in normalUrls) {
        expect(Deal.checkIsAmazonWarehouse(url), isFalse, reason: 'Normal ürün yanlışlıkla depo seçildi: $url');
      }
    });
  });
}
