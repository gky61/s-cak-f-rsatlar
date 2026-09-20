import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/gamer_gen_scraper.dart';

void main() {
  group('GamerGenScraper Tests', () {
    final scraper = GamerGenScraper();

    test('canHandle URL verification', () {
      expect(scraper.canHandle('https://www.gamer.gen.tr/aoc-q27g41zdf_u56708'), isTrue);
      expect(scraper.canHandle('https://gamer.gen.tr/gg-horizon_h58071'), isTrue);
      expect(scraper.canHandle('https://www.itopya.com/urun_u123'), isFalse);
      expect(scraper.canHandle('https://www.hepsiburada.com/item'), isFalse);
    });

    test('Product #1 (AOC Monitör - Sepette İndirimli)', () async {
      final file = File('scratch/gamer_gen_1.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gamer_gen_1.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('AOC Q27G41ZDF'), isTrue);
      expect(title.endsWith('Paylaş'), isFalse);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(18999.0));

      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      expect(originalPrice, equals(23158.63));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('AOC'));

      final image = scraper.scrape(
        document: doc,
        url: 'https://www.gamer.gen.tr/aoc-q27g41zdf-27%22-240hz-0.03ms-hdmi-dp-adaptive-sync-hdr10-qhd-qd-oled-gaming-monitor_u56708',
        isLogoUrl: (u) => u.toLowerCase().contains('logo'),
        resolveImageUrl: (img, page) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image!.contains('1-063fdf.png'), isTrue);

      final ratingVal = await scraper.scrapeRatingValue(doc);
      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingVal, isNull);
      expect(ratingCnt, isNull);

      final breadcrumbs = scraper.scrapeBreadcrumbs(doc);
      expect(breadcrumbs.contains('Çevre Birimleri'), isTrue);
      expect(breadcrumbs.contains('Monitör'), isTrue);
    });

    test('Product #2 (Lian Li Sıvı Soğutucu - Normal İndirimli)', () async {
      final file = File('scratch/gamer_gen_2.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gamer_gen_2.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('LIAN LI Hydro-Shift'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(10899.0));

      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      expect(originalPrice, equals(11917.48));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('LIAN LI'));

      final image = scraper.scrape(
        document: doc,
        url: 'https://www.gamer.gen.tr/lian-li-hydro-shift-ii-lcd-c-360cl-360mm-argb-islemci-sivi-sogutucu_u57254',
        isLogoUrl: (u) => u.toLowerCase().contains('logo'),
        resolveImageUrl: (img, page) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image!.contains('1-1-9f0f90.png'), isTrue);

      final breadcrumbs = scraper.scrapeBreadcrumbs(doc);
      expect(breadcrumbs.contains('Soğutucular'), isTrue);
    });

    test('Product #3 (AMD Ryzen 7 5800X3D - Tek Fiyat)', () async {
      final file = File('scratch/gamer_gen_3.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gamer_gen_3.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('AMD Ryzen 7 5800X3D'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(23267.60));

      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      expect(originalPrice, isNull);

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('AMD'));
    });

    test('Product #4 (Intel Core Ultra 7 265KF - Sepette İndirimli)', () async {
      final file = File('scratch/gamer_gen_4.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gamer_gen_4.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('Core Ultra 7 265KF'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(15999.0));

      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      expect(originalPrice, equals(18896.22));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('INTEL'));
    });

    test('Product #5 (Intel Core i5 12400F - Normal İndirimli)', () async {
      final file = File('scratch/gamer_gen_5.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gamer_gen_5.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('Core i5 12400F'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(6799.0));

      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      expect(originalPrice, equals(8618.66));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('INTEL'));
    });

    test('Product #6 (GG Horizon 5070 V6 Hazır Sistem - _h58071)', () async {
      final file = File('scratch/gamer_gen_6.html');
      expect(file.existsSync(), isTrue, reason: 'scratch/gamer_gen_6.html bulunamadı');
      final html = await file.readAsString();
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.contains('GG HORIZON-5070 V6'), isTrue);

      final price = await scraper.scrapePrice(doc);
      expect(price, isNotNull);
      expect(price! >= 99998.98 && price <= 99999.0, isTrue);

      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      expect(originalPrice, isNull);

      final image = scraper.scrape(
        document: doc,
        url: 'https://www.gamer.gen.tr/gg-horizon-5070-v6-amd-ryzen-7-7800x3d-msi-geforce-rtx-5070-12g-16gb-ddr5-1tb-nvme-m2-ssd-_h58071',
        isLogoUrl: (u) => u.toLowerCase().contains('logo'),
        resolveImageUrl: (img, page) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image!.contains('1-24fa20.png'), isTrue);

      final breadcrumbs = scraper.scrapeBreadcrumbs(doc);
      expect(breadcrumbs.contains('Hazır Sistemler'), isTrue);
    });
  });
}
