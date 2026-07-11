import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:sicak_firsatlar/services/scrapers/pttavm_scraper.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  group('PttavmScraper Unit Tests', () {
    final scraper = PttavmScraper();

    test('should scrape title, image, description, and price correctly from Product JSON-LD', () async {
      final html = '''
<!DOCTYPE html>
<html>
<head>
<script type="application/ld+json">{"@context":"https://schema.org","@type":"Product","name":"Apple AirPods Pro 3. Nesil (Apple Türkiye Garantili)","description":null,"sku":"1462157482","mpn":"1462157482","brand":{"@type":"Brand","name":"FXELEKTRONİK"},"category":"Bluetooth Kulaklıklar","url":"https://www.pttavm.com/apple-airpods-pro-3-nesil-apple-turkiye-garantili-p-1462157482","image":["https://cdn-s3.pttavm.com/pimages/592/146/215/de3a460e-154a-4959-afbb-9154bc6e0c96.webp","https://cdn-s3.pttavm.com/pimages/592/146/215/a18e131c-c743-4774-91c6-bba0bf1bad06.webp"],"offers":{"@type":"Offer","price":10999.58,"priceCurrency":"TRY","availability":"https://schema.org/InStock","seller":{"@type":"Organization","name":"FXELEKTRONİK"},"highPrice":12865,"lowPrice":10999.58,"shippingDetails":{"@type":"OfferShippingDetails","shippingRate":{"@type":"MonetaryAmount","value":0,"currency":"TRY"}}},"review":null,"warranty":null,"itemCondition":"https://schema.org/NewCondition","additionalProperty":[{"@type":"PropertyValue","name":"External Source","value":"Apple"},{"@type":"PropertyValue","name":"External ID","value":"0195950543711"}]}</script>
<meta data-rh="true" name="description" content="Metal Ayakkabılık 4'lü Kilitli Model Siyah yorumlarını inceleyin, Pttavm'de güvenli olarak, en iyi fiyatla ve özel indirimli fiyatla güvenle satın alın">
</head>
<body>
</body>
</html>
''';

      final doc = html_parser.parse(html);

      // Scrape Title
      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Apple AirPods Pro 3. Nesil (Apple Türkiye Garantili)'));

      // Scrape Image
      final image = scraper.scrape(
        document: doc,
        url: 'https://www.pttavm.com/some-product',
        isLogoUrl: (u) => false,
        resolveImageUrl: (img, page) => img,
        log: (msg) => print(msg),
      );
      expect(image, equals('https://cdn-s3.pttavm.com/pimages/592/146/215/de3a460e-154a-4959-afbb-9154bc6e0c96.webp'));

      // Scrape Description (since JSON-LD desc is null, it should fallback to meta data-rh="true")
      final desc = scraper.scrapeDescription(doc);
      expect(desc, contains('Metal Ayakkabılık 4\'lü Kilitli Model Siyah'));

      // Scrape Price
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(10999.58));
    });

    test('Fetch real PttAVM URL using LinkPreviewService', () async {
      // Use the URL from the user's JSON-LD or another valid product page
      final url = "https://www.pttavm.com/apple-airpods-pro-3-nesil-apple-turkiye-garantili-p-1462157482";
      print("Fetching $url via LinkPreviewService...");

      final service = LinkPreviewService();
      final result = await service.fetchMetadata(url);

      expect(result, isNotNull);
      print("Result title: ${result?.title}");
      print("Result price: ${result?.price}");
      print("Result imageUrl: ${result?.imageUrl}");
      print("Result description: ${result?.description}");

      expect(result?.title, contains("AirPods"));
      expect(result?.price, isNotNull);
      expect(result?.price, greaterThan(0));
      expect(result?.imageUrl, isNotNull);
      expect(result?.imageUrl, contains("pttavm.com"));
    });
  });
}
