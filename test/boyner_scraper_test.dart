import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/boyner_scraper.dart';

void main() {
  group('BoynerScraper Tests', () {
    final scraper = BoynerScraper();

    test('canHandle should return true for boyner.com.tr URLs', () {
      expect(scraper.canHandle('https://www.boyner.com.tr/tommy-hilfiger-tas-kadin-omuz-cantasi-aw0aw18463aep-p-15891128'), isTrue);
      expect(scraper.canHandle('https://boyner.com.tr/armani-p-797957'), isTrue);
      expect(scraper.canHandle('https://www.hepsiburada.com/item'), isFalse);
    });

    test('Product #1 (Tommy Hilfiger Bag) - Should scrape title, brand, prices and ratings correctly', () async {
      final file = File('scratch/boyner_1.html');
      if (!file.existsSync()) return;
      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.boyner.com.tr/tommy-hilfiger-tas-kadin-omuz-cantasi-aw0aw18463aep-p-15891128?magaza=boyner';

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Tommy Hilfiger'));

      final brand = scraper.scrapeBrand(document);
      expect(brand, equals('Tommy Hilfiger'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(2349.0));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(3299.0));

      final ratingValue = await scraper.scrapeRatingValue(document);
      expect(ratingValue, equals(4.1));

      final ratingCount = await scraper.scrapeRatingCount(document);
      expect(ratingCount, equals(7));
    });

    test('Product #2 (Armani Perfume) - Should scrape title, brand, prices and ratings correctly', () async {
      final file = File('scratch/boyner_2.html');
      if (!file.existsSync()) return;
      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.boyner.com.tr/armani-stronger-with-you-intensely-edp-100-ml-erkek-parfum-p-797957?magaza=boyner';

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Armani'));

      final brand = scraper.scrapeBrand(document);
      expect(brand, equals('Armani'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(5625.0));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(7500.0));

      final ratingValue = await scraper.scrapeRatingValue(document);
      expect(ratingValue, equals(4.2));

      final ratingCount = await scraper.scrapeRatingCount(document);
      expect(ratingCount, equals(452));
    });

    test('Product #3 (New Balance 530) - Should scrape title, brand, price and ratings correctly', () async {
      final file = File('scratch/boyner_3.html');
      if (!file.existsSync()) return;
      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.boyner.com.tr/new-balance-530-mr530sg-nb-beyaz-mavi-kadin-lifestyle-ayakkabi-p-1755886?magaza=boyner';

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('New Balance'));

      final brand = scraper.scrapeBrand(document);
      expect(brand, equals('New Balance'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(7499.0));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, isNull);

      final ratingValue = await scraper.scrapeRatingValue(document);
      expect(ratingValue, equals(3.9));

      final ratingCount = await scraper.scrapeRatingCount(document);
      expect(ratingCount, equals(30));
    });
  });
}
