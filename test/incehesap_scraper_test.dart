import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/incehesap_scraper.dart';

void main() {
  group('IncehesapScraper Unit Tests', () {
    final scraper = IncehesapScraper();

    test('canHandle should match Incehesap domains', () {
      expect(scraper.canHandle('https://www.incehesap.com/james-donkey-jd450-gaming-mouse-fiyati-3087770/'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (5), reviewCount (2) from DOM microdata and brand (James Donkey) from itemprop', () async {
      const html = '''
      <div itemprop="aggregateRating" itemscope="" itemtype="https://schema.org/AggregateRating">
        Rated <span itemprop="ratingValue">5</span>/5
        based on <span itemprop="reviewCount">2</span> customer reviews
      </div>
      <div itemprop="brand" itemtype="https://schema.org/Brand" itemscope="">
        <meta itemprop="name" content="James Donkey">
      </div>
      ''';
      final doc = html_parser.parse(html);

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(5.0));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(2));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('James Donkey'));
    });
  });
}
