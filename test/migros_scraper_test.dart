import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:sicak_firsatlar/services/scrapers/migros_scraper.dart';

void main() {
  group('MigrosScraper Price Label Tests', () {
    final scraper = MigrosScraper();

    test('should extract CRM label from .product-label.crm', () async {
      const html = '''
        <html>
          <body>
            <div class="product-label crm">50 TL SEPETTE 299 TL</div>
            <div class="product-card-title">Migros Süt 1 L</div>
          </body>
        </html>
      ''';
      
      final document = parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(document);
      
      expect(priceLabel, '50 TL SEPETTE 299 TL');
    });

    test('should return null when CRM label is missing', () async {
      const html = '''
        <html>
          <body>
            <div class="product-card-title">Migros Süt 1 L</div>
          </body>
        </html>
      ''';
      
      final document = parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(document);
      
      expect(priceLabel, isNull);
    });
  });
}
