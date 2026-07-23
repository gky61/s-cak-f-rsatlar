import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/n11_scraper.dart';

void main() {
  group('N11Scraper Unit Tests', () {
    final scraper = N11Scraper();

    test('canHandle should match N11 domains', () {
      expect(scraper.canHandle('https://m.n11.com/urun/siemens-eq6-plus-s700-te657319rw-tam-otomatik-kahve-makinesi-45338828'), isTrue);
      expect(scraper.canHandle('https://www.n11.com/urun/siemens-eq6'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (4.5), ratingCount (47), and brand (Siemens) from N11 ld+json string', () async {
      const html = '''
      <script type="application/ld+json">{"@context":"https://schema.org/","@type":"Product","aggregateRating":{"@type":"AggregateRating","ratingCount":"47","ratingValue":4.5,"reviewCount":"47"},"brand":"Siemens","description":"Siemens EQ6 Plus S700 TE657319RW Tam Otomatik Kahve Makinesi Koyu Inox","image":"https://n11scdn2-im.akamaized.net/a1/640/20/09/21/84/44/56/86/11/27/49/86/67/01624004745729654692.jpg","name":"Siemens EQ6 Plus S700 TE657319RW Tam Otomatik Kahve Makinesi Koyu Inox Fiyatları ve Özellikleri","gtin8":"4242003806371","sku":"127367357093","offers":{"@type":"AggregateOffer","lowPrice":"34050","offerCount":"9","priceCurrency":"TRY","url":"https://m.n11.com/urun/siemens-eq6-plus-s700-te657319rw-tam-otomatik-kahve-makinesi-45338828?magaza=kapidakifirsat"}}</script>
      ''';
      final doc = html_parser.parse(html);

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.5));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(47));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Siemens'));
    });
  });
}
