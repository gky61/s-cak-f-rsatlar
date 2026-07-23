import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/vatan_scraper.dart';

void main() {
  group('VatanScraper Unit Tests', () {
    final scraper = VatanScraper();

    test('canHandle should match Vatan Bilgisayar domains', () {
      expect(scraper.canHandle('https://www.vatanbilgisayar.com/lenovo-ideapad-slim-3.html'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape price, title, ratingValue, ratingCount, and brand from Vatan ld+json string', () async {
      const html = '''
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Lenovo Ideapad Slim 3 13.Nesil Core i5 13420H-8Gb-512Gb Ssd-16inc-W11",
        "brand": {
          "@type": "Brand",
          "name": "LENOVO"
        },
        "offers": {
          "@type": "Offer",
          "price": "26999"
        },
        "aggregateRating": {
          "@type": "AggregateRating",
          "ratingValue": "4,71",
          "reviewCount": "248"
        }
      }
      </script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(26999.00));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Lenovo Ideapad Slim 3 13.Nesil Core i5 13420H-8Gb-512Gb Ssd-16inc-W11'));

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.71));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(248));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('LENOVO'));
    });
  });
}
