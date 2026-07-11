import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/pazarama_scraper.dart';

void main() {
  group('PazaramaScraper Unit Tests', () {
    final scraper = PazaramaScraper();

    test('should parse normal price from pazarama-normal html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Normal Pazarama Urunu",
        "offers": {
          "price": "47879.00"
        }
      }
      </script>
      <meta name="description" content="Normal pazarama urun aciklamasi">
      ''';
      final doc = html_parser.parse(html);
      
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(47879.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Normal Pazarama Urunu'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('Normal pazarama urun aciklamasi'));
    });

    test('should parse plus price from pazarama-plus html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Plus Pazarama Urunu"
      }
      </script>
      <meta name="description" content="Plus pazarama urun aciklamasi">
      <div>
        <img src="pz-plus-icon" alt="plus-icon">
        <span>455,24 TL</span>
      </div>
      ''';
      final doc = html_parser.parse(html);
      
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(455.24));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Plus Pazarama Urunu'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('Plus pazarama urun aciklamasi'));
    });
  });
}
