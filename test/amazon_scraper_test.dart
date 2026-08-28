import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/amazon_scraper.dart';

void main() {
  group('AmazonScraper Unit Tests', () {
    final scraper = AmazonScraper();

    test('canHandle should match Amazon domains', () {
      expect(scraper.canHandle('https://www.amazon.com.tr/dp/B0GGB6P1JF'), isTrue);
      expect(scraper.canHandle('https://amzn.eu/d/07A3YdHA'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (4.3), ratingCount (16), and brand (iFFALCON) from Amazon HTML structure', () async {
      const html = '''
      <html>
        <body>
          <h1 id="productTitle">iFFALCON 75U75A 75 İnç Smart TV</h1>
          <div id="averageCustomerReviews">
            <span class="a-icon-alt">5 yıldız üzerinden 4,3</span>
            <span id="acrCustomerReviewText">(16)</span>
          </div>
          <table>
            <tr class="po-brand">
              <td class="po-break-word">iFFALCON</td>
            </tr>
          </table>
        </body>
      </html>
      ''';
      final doc = html_parser.parse(html);

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.3));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(16));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('iFFALCON'));
    });

    test('should parse rating, count, and brand from user real amazon-page.html file', () async {
      var file = File('cloud-run-bot/scratch/amazon-page.html');
      if (!file.existsSync()) {
        file = File('scratch/amazon-page.html');
      }
      if (!file.existsSync()) {
        print('Skipping test, amazon-page.html not found');
        return;
      }

      final html = file.readAsStringSync();
      final doc = html_parser.parse(html);

      final ratingVal = scraper.scrapeRatingValue(doc);
      print('Parsed ratingValue from amazon-page.html: $ratingVal');
      expect(ratingVal, equals(4.3));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      print('Parsed ratingCount from amazon-page.html: $ratingCnt');
      expect(ratingCnt, equals(16));

      final brand = scraper.scrapeBrand(doc);
      print('Parsed brand from amazon-page.html: $brand');
      expect(brand, equals('iFFALCON'));
    });

    test('should NOT mark deal as Prime Fırsatı for generic delivery or navbar text (False Positive Prevention)', () async {
      const html = '''
      <html>
        <body>
          <div id="navbar"><a href="/prime">Prime Fırsat Günleri</a></div>
          <div id="mir-layout-DELIVERY_BLOCK">
            <span>Prime ile ÜCRETSİZ teslimat: Yarın</span>
          </div>
          <div class="a-section">Normal Fiyat: 500 TL</div>
        </body>
      </html>
      ''';
      final doc = html_parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(priceLabel, isNull);
    });

    test('should mark deal as Prime Fırsatı when dealBadgeSupportingText or primeExclusivePricing exists', () async {
      const html = '''
      <html>
        <body>
          <div id="apex_desktop">
            <span id="dealBadgeSupportingText">Prime Fırsatı</span>
            <span class="a-price">299,00 TL</span>
          </div>
        </body>
      </html>
      ''';
      final doc = html_parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(priceLabel, equals('Prime Fırsatı'));
    });
  });
}

