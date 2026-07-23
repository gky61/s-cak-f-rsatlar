import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/mavi_scraper.dart';

void main() {
  group('MaviScraper Unit Tests', () {
    final scraper = MaviScraper();

    test('canHandle should match Mavi domains', () {
      expect(scraper.canHandle('https://www.mavi.com/mini-mavi-logo-baskili-interlok-beyaz-basic-tisort/p/1612122-70057'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (4.8) and ratingCount (5) from DOM (birinci öncelik)', () async {
      const html = '''
      <div class="average-rate">
        <span class="average-rate__number type:small">4.8</span>
        <div class="average-rate__star-rate">
          <span class="star-rating type:small starColor:black">
            <span class="star-rating-inner active" style="width:96.0%"></span>
          </span>
        </div>
      </div>
      <div class="rate-info type:small">5&nbsp;Değerlendirme</div>
      <script type="application/ld+json">
        {
          "@context":"https://schema.org",
          "@type":"WebPage",
          "mainEntity":{
            "@type":"WebPageElement",
            "offers":{
              "@type":"Offer",
              "itemOffered":[{
                "@type":"Product",
                "name":"Test Ürün",
                "aggregateRating": {
                  "@type": "AggregateRating",
                  "ratingValue": "4.5",
                  "reviewCount": "1"
                }
              }]
            }
          }
        }
      </script>
      ''';
      final doc = html_parser.parse(html);

      // DOM birinci öncelik: 4.8 (JSON-LD'deki 4.5 değil)
      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.8));

      // DOM birinci öncelik: 5 (JSON-LD'deki 1 değil)
      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(5));
    });

    test('should fallback to JSON-LD when DOM rating elements are absent', () async {
      const html = '''
      <script type="application/ld+json">
        {
          "@context":"https://schema.org",
          "@type":"WebPage",
          "mainEntity":{
            "@type":"WebPageElement",
            "offers":{
              "@type":"Offer",
              "itemOffered":[{
                "@type":"Product",
                "name":"Mini Mavi Logo Baskılı İnterlok Beyaz Basic Tişört",
                "brand": {
                  "@type": "Brand",
                  "name": "Mavi"
                },
                "offers":{"@type":"Offer","price":"419.99","priceCurrency":"TRY"},
                "aggregateRating": {
                  "@type": "AggregateRating",
                  "ratingValue": "4.5",
                  "reviewCount": "1"
                }
              }]
            }
          }
        }
      </script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(419.99));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals("Mini Mavi Logo Baskılı İnterlok Beyaz Basic Tişört"));

      // DOM yok, JSON-LD fallback çalışmalı
      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.5));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(1));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Mavi'));
    });
  });
}
