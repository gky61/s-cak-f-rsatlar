import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/getir_scraper.dart';
import 'package:sicak_firsatlar/services/category_detection_service.dart';

void main() {
  group('GetirScraper Unit Tests', () {
    final scraper = GetirScraper();

    test('should identify getir.com urls correctly', () {
      expect(scraper.canHandle('https://getir.com/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/'), isTrue);
      expect(scraper.canHandle('https://www.getir.com/urun/some-product'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape product details correctly from getir next page HTML', () async {
      // Load saved getir HTML
      final file = File('scratch/getir_page_utf8.html');
      final html = await file.readAsString(encoding: utf8);
      
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Chunkies & Magnum Badem & Nogger Paketi'));

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(367.99));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('3 Adet'));

      final image = scraper.scrape(
        document: doc,
        url: 'https://getir.com/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/',
        isLogoUrl: (u) => false,
        resolveImageUrl: (img, page) => img,
        log: (msg) => print(msg),
      );
      expect(image, equals('https://cdn-image.getir.com/market/product/48c81d77-9f2e-48d2-905c-6d49668ab0d5.jpg'));
    });

    test('should classify Ekmek as supermarket > Gıda Ürünleri', () {
      final categoryResult = CategoryDetectionService.detectCategory('Ekmek');
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], equals('supermarket'));
      expect(categoryResult['subCategory'], equals('Gıda Ürünleri'));
    });
  });
}
