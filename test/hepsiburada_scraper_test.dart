import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/hepsiburada_scraper.dart';

void main() {
  group('HepsiburadaScraper Unit Tests', () {
    final scraper = HepsiburadaScraper();

    test('canHandle should match Hepsiburada domains', () {
      expect(scraper.canHandle('https://www.hepsiburada.com/product-p-HBCV0000AHHOFE'), isTrue);
      expect(scraper.canHandle('https://hb.biz/some-short-url'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape normal price from hb-normal html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Apple iPhone 17 Pro Max 256 GB",
        "offers": {
          "price": "120499.00"
        }
      }
      </script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(120499.00));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Apple iPhone 17 Pro Max 256 GB'));
    });

    test('should scrape premium price from hb-premium html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Ant Home Asimetrik Ayna, Çerçeveli Ayna, Duvar Aynası, Konsol Aynası, Banyo Aynası, Çerçeveli"
      }
      </script>
      <span>Premium ile <b>344,49 TL</b></span>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(344.49));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Ant Home Asimetrik Ayna, Çerçeveli Ayna, Duvar Aynası, Konsol Aynası, Banyo Aynası, Çerçeveli'));
    });

    test('should scrape premium price from hb-premium-2 html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Selpak® Kağıt Havlu"
      }
      </script>
      <span>Premium ile <b>282,67 TL</b></span>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(282.67));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Selpak® Kağıt Havlu'));
    });
  });
}
