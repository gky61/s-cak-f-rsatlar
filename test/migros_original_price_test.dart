import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/migros_scraper.dart';

void main() {
  group('MigrosScraper originalPrice Tests', () {
    final scraper = MigrosScraper();

    test('should extract originalPrice from .single-price-amount when present', () async {
      const html = '''
        <html>
          <body>
            <div class="product-detail">
              <span class="single-price-amount"> 70,00 <span class="currency">TL</span></span>
              <span id="new-amount">50,00 TL</span>
            </div>
          </body>
        </html>
      ''';
      final doc = html_parser.parse(html);
      final price = await scraper.scrapePrice(doc);
      final origPrice = scraper.scrapeOriginalPrice(doc, price);

      expect(price, equals(50.0));
      expect(origPrice, equals(70.0));
    });

    test('should return null when no originalPrice element exists', () async {
      const html = '''
        <html>
          <body>
            <div class="product-detail">
              <span id="new-amount">50,00 TL</span>
            </div>
          </body>
        </html>
      ''';
      final doc = html_parser.parse(html);
      final price = await scraper.scrapePrice(doc);
      final origPrice = scraper.scrapeOriginalPrice(doc, price);

      expect(price, equals(50.0));
      expect(origPrice, isNull);
    });
  });
}
