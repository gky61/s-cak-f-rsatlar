import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/gaming_gen_scraper.dart';

void main() {
  group('GamingGenScraper Tests', () {
    final scraper = GamingGenScraper();

    test('canHandle URL verification', () {
      expect(scraper.canHandle('https://www.gaming.gen.tr/urun/542776/pc-hocasi-gg10/'), isTrue);
      expect(scraper.canHandle('https://gaming.gen.tr/urun/612335/ultima-5080/'), isTrue);
      expect(scraper.canHandle('https://www.gamer.gen.tr/urun_u123'), isFalse);
      expect(scraper.canHandle('https://www.itopya.com/urun_u123'), isFalse);
      expect(scraper.canHandle('https://www.hepsiburada.com/item'), isFalse);
    });

    test('Product #1 (PC HOCASI-GG10 Hazır Sistem)', () async {
      final file = File('scratch/gaming_gen_1.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gaming_gen_1.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('PC HOCASI-GG10'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, isNotNull);
      expect(price! >= 48498.98 && price <= 48499.00, isTrue);

      final ratingVal = await scraper.scrapeRatingValue(doc);
      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingVal, isNotNull);
      expect(ratingVal! >= 4.8 && ratingVal <= 4.9, isTrue);
      expect(ratingCnt, equals(27));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Powered by ASUS'));

      final image = scraper.scrape(
        document: doc,
        url: 'https://www.gaming.gen.tr/urun/542776/pc-hocasi-gg10/',
        isLogoUrl: (u) => u.toLowerCase().contains('logo'),
        resolveImageUrl: (img, page) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image!.contains('.jpg'), isTrue);

      final breadcrumbs = scraper.scrapeBreadcrumbs(doc);
      expect(breadcrumbs.contains('Tavsiye Sistemler'), isTrue);
    });

    test('Product #2 (ULTIMA-5080 Hazır Sistem)', () async {
      final file = File('scratch/gaming_gen_2.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gaming_gen_2.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('ULTIMA-5080'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, isNotNull);
      expect(price! >= 159999.00 && price <= 159999.01, isTrue);

      final ratingVal = await scraper.scrapeRatingValue(doc);
      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingVal, equals(4.5));
      expect(ratingCnt, equals(2));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Powered by ASUS'));
    });

    test('Product #3 (IMOLA-5060 Hazır Sistem)', () async {
      final file = File('scratch/gaming_gen_3.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gaming_gen_3.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('IMOLA-5060'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, isNotNull);
      expect(price! >= 57998.99 && price <= 57999.00, isTrue);

      final ratingVal = await scraper.scrapeRatingValue(doc);
      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingVal, equals(4.9));
      expect(ratingCnt, equals(373));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Powered by ASUS'));
    });

    test('Product #4 (Thermalright Sıvı/Hava Soğutucu)', () async {
      final file = File('scratch/gaming_gen_4.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gaming_gen_4.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('Thermalright Assassin King'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(1999.00));

      final ratingVal = await scraper.scrapeRatingValue(doc);
      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingVal, equals(4.9));
      expect(ratingCnt, equals(79));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Thermalright'));

      final breadcrumbs = scraper.scrapeBreadcrumbs(doc);
      expect(breadcrumbs.contains('Hava Soğutma'), isTrue);
    });

    test('Product #5 (GameRaider IGNIA GR16 Gaming Laptop)', () async {
      final file = File('scratch/gaming_gen_5.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gaming_gen_5.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('GameRaider IGNIA GR16'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(99999.00));

      final ratingVal = await scraper.scrapeRatingValue(doc);
      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingVal, equals(5.0));
      expect(ratingCnt, equals(10));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('GameRaider'));

      final breadcrumbs = scraper.scrapeBreadcrumbs(doc);
      expect(breadcrumbs.contains('Gaming Laptop'), isTrue);
    });

    test('Product #6 (Cybeart Oyuncu Koltuğu - Değerlendirme Yok)', () async {
      final file = File('scratch/gaming_gen_6.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gaming_gen_6.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('Cybeart Apex Series'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(14999.00));

      final ratingVal = await scraper.scrapeRatingValue(doc);
      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingVal, isNull);
      expect(ratingCnt, isNull);

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Cybeart'));
    });

    test('Product #7 (MSI All In One PC - Değerlendirme Yok)', () async {
      final file = File('scratch/gaming_gen_7.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gaming_gen_7.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('MSI PRO AP272P'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(61899.00));

      final ratingVal = await scraper.scrapeRatingValue(doc);
      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingVal, isNull);
      expect(ratingCnt, isNull);

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('MSI'));
    });
  });
}
