import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/mediamarkt_scraper.dart';

void main() {
  group('MediaMarktScraper Unit Tests', () {
    final scraper = MediaMarktScraper();

    test('canHandle should match MediaMarkt domains', () {
      expect(scraper.canHandle('https://www.mediamarkt.com.tr/tr/product/_apple-iphone-15-128gb-1234.html'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (4.9), reviewCount (17), and brand (Apple) from ld+json', () async {
      const html = '''
      <script type="application/ld+json">
      {
        "@context": "https://schema.org/",
        "@type": "Product",
        "name": "APPLE iPhone 15 128 GB Akıllı Telefon Siyah",
        "image": "https://cms-images.mmst.eu/2c383f5b/321.jpg",
        "description": "APPLE iPhone 15 128 GB Akıllı Telefon Siyah en uygun fiyatla MediaMarkt'ta!",
        "brand": {
          "@type": "Brand",
          "name": "Apple"
        },
        "aggregateRating": {
          "@type": "AggregateRating",
          "ratingValue": 4.9,
          "reviewCount": 17,
          "bestRating": 5
        },
        "offers": {
          "@type": "Offer",
          "priceCurrency": "TRY",
          "price": "49999.00"
        }
      }
      </script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(49999.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('APPLE iPhone 15 128 GB Akıllı Telefon Siyah'));

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.9));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(17));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Apple'));
    });

    test('should parse ratingValue (4.9) and reviewCount (17) from user provided DOM header aria-label', () async {
      const html = '''
      <html>
        <body>
          <header class="mms-ui-gmypTc mms-ui-lOKb mms-ui-gmEXAU mms-ui-jhxEPr mms-ui-jaLRUs mms-ui-jPTFXc mms-ui-hdSXft mms-ui-gYQtUZ mms-ui-kqNbQS" data-test="mms-pdp-average-rating-summary" aria-label="Ortalama ürün değerlendirmesi 17 incelemelerine göre 4.9 şeklindedir."></header>
          <meta property="product:brand" content="Apple">
        </body>
      </html>
      ''';
      final doc = html_parser.parse(html);

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.9));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(17));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Apple'));
    });
  });
}
