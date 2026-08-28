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

    test('should extract campaign label (e.g. 3 Al 2 Öde) from CRM label', () async {
      const html = '''
        <html>
          <body>
            <div class="product-label crm">3 AL 2 ÖDE</div>
            <div class="product-card-title">Eti Lifalif Bar</div>
          </body>
        </html>
      ''';
      
      final document = parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(document);
      
      expect(priceLabel, '3 AL 2 ÖDE');
    });

    test('should preserve Money gift campaign label as is (3 Al 2\'si Money Hediye)', () async {
      const html = '''
        <html>
          <body>
            <div class="product-label crm">3 Al 2'si Money Hediye</div>
            <div class="product-card-title">Dido Gofret</div>
          </body>
        </html>
      ''';
      
      final document = parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(document);
      
      expect(priceLabel, "3 Al 2'si Money Hediye");
    });

    test('should return null for generic İyi Fiyat labels', () async {
      const html = '''
        <html>
          <body>
            <div class="product-label crm">İYİ FİYAT</div>
            <div class="product-card-title">Dana Pirzola</div>
          </body>
        </html>
      ''';
      
      final document = parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(document);
      
      expect(priceLabel, isNull);
    });

    test('should return null when no CRM or Money label exists in DOM or API', () async {
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


