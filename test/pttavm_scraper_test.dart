import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/pttavm_scraper.dart';

void main() {
  group('PttavmScraper Unit Tests', () {
    final scraper = PttavmScraper();

    test('canHandle should match PttAVM domains', () {
      expect(scraper.canHandle('https://www.pttavm.com/dijitsu-db120rre-retro-kirmizi-mini-buzdolabi-p-1458599324'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (1.8), reviewCount (5), and brand (Dijitsu from additionalProperty) from ld+json', () async {
      const html = '''
      <script type="application/ld+json">{"@context":"https://schema.org","@type":"Product","name":"Dijitsu DB120RRE Retro Kırmızı Mini Buzdolabı","description":null,"sku":"1458599324","brand":{"@type":"Brand","name":"FIRSATLARALEMİ"},"category":"Buzdolapları","url":"https://www.pttavm.com/dijitsu-db120rre-retro-kirmizi-mini-buzdolabi-p-1458599324","image":["https://cdn-s3.pttavm.com/pimages/592/145/859/fa952540-c2b8-4da6-83ac-0419db76d383.webp"],"offers":{"@type":"Offer","price":6699,"priceCurrency":"TRY","availability":"https://schema.org/InStock"},"aggregateRating":{"@type":"AggregateRating","ratingValue":1.8,"reviewCount":5,"bestRating":5,"worstRating":1},"additionalProperty":[{"@type":"PropertyValue","name":"External Source","value":"Dijitsu"},{"@type":"PropertyValue","name":"External ID","value":"Dijitsu DB120RRE Retro Kırmızı Mini Buzdolabı"}]}</script>
      ''';
      final doc = html_parser.parse(html);

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(1.8));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(5));

      // Brand: additionalProperty "External Source" -> "Dijitsu" (brand alanı satıcıyı içerir)
      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Dijitsu'));
    });
  });
}
