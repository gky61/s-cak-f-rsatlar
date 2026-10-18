import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/services/scrapers/carrefoursa_scraper.dart';

void main() {
  group('CarrefoursaScraper Tests', () {
    final scraper = CarrefoursaScraper();

    test('canHandle should return true for carrefoursa.com URLs', () {
      expect(scraper.canHandle('https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671'), isTrue);
      expect(scraper.canHandle('https://carrefoursa.com/smile-kedi-kumu-p-30498020'), isTrue);
      expect(scraper.canHandle('https://www.migros.com.tr/item-p-123'), isFalse);
      expect(scraper.canHandle('https://www.trendyol.com/item-p-456'), isFalse);
    });

    test('Product #1 (Heinz Tatlı Ketçap) - İndirimsiz: 169,95 TL, CarrefourSA Kart ile: 127,46 TL', () async {
      File file = File('cloud-run-bot/tests/fixtures/carrefoursa/sample_0.html');
      if (!file.existsSync()) {
        file = File('C:/Users/murat/.gemini/antigravity-ide/brain/22eb7131-e5b0-4e91-8eab-721314a82678/scratch/sample_0.html');
      }
      expect(file.existsSync(), isTrue, reason: 'Sample 0 fixture file must exist');

      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671';

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Heinz Tatlı Ketçap 570 g'));

      final brand = scraper.scrapeBrand(document);
      expect(brand, equals('HEINZ'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(127.46));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(169.95));

      final priceLabel = await scraper.scrapePriceLabel(document);
      expect(priceLabel, equals('CarrefourSA Kart ile'));

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo') || u.contains('banner'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image, contains('images.csfour.com'));

      final breadcrumbs = scraper.scrapeBreadcrumbs(document);
      expect(breadcrumbs, equals(['Temel Gıda', 'Soslar', 'Ketçap']));
    });

    test('Product #2 (Smile Kedi Kumu) - 129,50 TL, CarrefourSA Kart ile 2 Al 1 Öde', () async {
      File file = File('cloud-run-bot/tests/fixtures/carrefoursa/sample_1.html');
      if (!file.existsSync()) {
        file = File('C:/Users/murat/.gemini/antigravity-ide/brain/22eb7131-e5b0-4e91-8eab-721314a82678/scratch/sample_1.html');
      }
      expect(file.existsSync(), isTrue, reason: 'Sample 1 fixture file must exist');

      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.carrefoursa.com/smile-bentonit-kedi-kumu-natural-5-l-p-30498020';

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Smile Bentonit Kedi Kumu Natural 5 L'));

      final brand = scraper.scrapeBrand(document);
      expect(brand, equals('SMİLE'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(129.50));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, isNull);

      final priceLabel = await scraper.scrapePriceLabel(document);
      expect(priceLabel, equals('CarrefourSA Kart ile 2 Al 1 Öde'));

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo') || u.contains('banner'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image, contains('images.csfour.com'));

      final breadcrumbs = scraper.scrapeBreadcrumbs(document);
      expect(breadcrumbs, equals(['Pet Shop', 'Kedi', 'Kedi Kumu']));
    });

    test('Product #3 (Dana Kıyma) - İndirimsiz: 879,90 TL, CarrefourSA Kart ile: 749,90 TL', () async {
      File file = File('cloud-run-bot/tests/fixtures/carrefoursa/sample_2.html');
      if (!file.existsSync()) {
        file = File('C:/Users/murat/.gemini/antigravity-ide/brain/22eb7131-e5b0-4e91-8eab-721314a82678/scratch/sample_2.html');
      }
      expect(file.existsSync(), isTrue, reason: 'Sample 2 fixture file must exist');

      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.carrefoursa.com/dana-kiyma-14-20-yag-kg-p-30054577';

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Dana Kıyma'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(749.90));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(879.90));

      final priceLabel = await scraper.scrapePriceLabel(document);
      expect(priceLabel, equals('CarrefourSA Kart ile'));

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo') || u.contains('banner'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image, contains('images.csfour.com'));

      final breadcrumbs = scraper.scrapeBreadcrumbs(document);
      expect(breadcrumbs, equals(['Et, Tavuk, Balık', 'Kırmızı Et', 'Dana']));
    });

    test('Product #4 (Yudum Ayçiçek Yağı 5 L) - Tek Fiyat: 599,95 TL', () async {
      File file = File('cloud-run-bot/tests/fixtures/carrefoursa/sample_3.html');
      if (!file.existsSync()) {
        file = File('C:/Users/murat/.gemini/antigravity-ide/brain/22eb7131-e5b0-4e91-8eab-721314a82678/scratch/sample_3.html');
      }
      expect(file.existsSync(), isTrue, reason: 'Sample 3 fixture file must exist');

      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.carrefoursa.com/yudum-aycicek-yagi-5-l-p-30088639';

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Yudum Ayçiçek Yağı 5 L'));

      final brand = scraper.scrapeBrand(document);
      expect(brand, equals('YUDUM'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(599.95));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, isNull);

      final priceLabel = await scraper.scrapePriceLabel(document);
      expect(priceLabel, isNull);

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo') || u.contains('banner'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image, contains('images.csfour.com'));

      final breadcrumbs = scraper.scrapeBreadcrumbs(document);
      expect(breadcrumbs, equals(['Temel Gıda', 'Sıvı Yağlar', 'Ayçiçek Yağı']));
    });

    test('Product #5 (Çaykur Rize Turist Çay 1 kg) - Tek Fiyat: 339,95 TL', () async {
      File file = File('cloud-run-bot/tests/fixtures/carrefoursa/sample_4.html');
      if (!file.existsSync()) {
        file = File('C:/Users/murat/.gemini/antigravity-ide/brain/22eb7131-e5b0-4e91-8eab-721314a82678/scratch/sample_4.html');
      }
      expect(file.existsSync(), isTrue, reason: 'Sample 4 fixture file must exist');

      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.carrefoursa.com/caykur-rize-turist-cay-1-kg-p-30037044';

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Çaykur Rize Turist Çay 1 kg'));

      final brand = scraper.scrapeBrand(document);
      expect(brand, equals('ÇAYKUR'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(339.95));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, isNull);

      final priceLabel = await scraper.scrapePriceLabel(document);
      expect(priceLabel, isNull);

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo') || u.contains('banner'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);
      expect(image, contains('images.csfour.com'));

      final breadcrumbs = scraper.scrapeBreadcrumbs(document);
      expect(breadcrumbs, contains('İçecekler'));
      expect(breadcrumbs, contains('Çay'));
    });

    test('Product #6 (Nescafe Xpress) - İndirimsiz: 80,00 TL, CarrefourSA Kart ile: 60,00 TL', () async {
      final file = File('cloud-run-bot/tests/fixtures/carrefoursa/nescafe.html');
      expect(file.existsSync(), isTrue, reason: 'Nescafe fixture file must exist');

      final html = await file.readAsString();
      final document = html_parser.parse(html);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Nescafe Xpress'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(60.00));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(80.00));

      final priceLabel = await scraper.scrapePriceLabel(document);
      expect(priceLabel, equals('CarrefourSA Kart ile'));
    });

    test('Product #7 (Kızılay Maden Suyu) - Kartsız: 66,70 TL, CarrefourSA Kart ile: 49,95 TL', () async {
      final file = File('cloud-run-bot/tests/fixtures/carrefoursa/kizilay.html');
      expect(file.existsSync(), isTrue, reason: 'Kizilay fixture file must exist');

      final html = await file.readAsString();
      final document = html_parser.parse(html);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Kızılay'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(49.95));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(66.70));

      final priceLabel = await scraper.scrapePriceLabel(document);
      expect(priceLabel, equals('CarrefourSA Kart ile'));
    });

    test('Deal.cleanProductUrl strips query parameters for CarrefourSA URLs', () {
      const dirtyUrl = 'https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671?utm_source=google&utm_medium=cpc&utm_campaign=xyz';
      final cleaned = Deal.cleanProductUrl(dirtyUrl);
      expect(cleaned, equals('https://www.carrefoursa.com/heinz-tatli-ketcap-570-g-p-30455671'));
    });
  });
}
