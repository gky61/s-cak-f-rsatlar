import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/defacto_scraper.dart';

void main() {
  group('DefactoScraper Unit Tests', () {
    final scraper = DefactoScraper();

    test('canHandle should match DeFacto domains', () {
      expect(scraper.canHandle('https://www.defacto.com.tr/regular-fit-mavi-pamuklu-jean-bermuda-sort-3401791'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (5.0 from "5,00"), ratingCount (1), and brand ("DeFacto" as plain string) from ld+json', () async {
      const html = '''
      <script type="application/ld+json">{"@context":"https://schema.org/","@type":"Product","name":"Regular Fit Pamuklu Jean Bermuda Şort","image":["https://dfcdn.defacto.com.tr/7/G8666AX_26SM_NM39_01_02.jpg"],"description":"Aradığın Mavi Erkek Regular Fit Pamuklu Jean Bermuda Şort","brand":"DeFacto","sku":"f212bff5-9be4-4037-9844-414e7cb802bc","offers":{"@type":"Offer","url":"https://www.defacto.com.tr/regular-fit-mavi-pamuklu-jean-bermuda-sort-3401791","priceCurrency":"TRY","price":"999.99","availability":"https://schema.org/InStock"},"aggregateRating":{"@type":"AggregateRating","ratingValue":"5,00","bestRating":"5.0","worstRating":"1.0","ratingCount":"1","reviewCount":"1"}}</script>
      ''';
      final doc = html_parser.parse(html);

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(5.0));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(1));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('DeFacto'));
    });
  });
}
