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

    test('Product #4 (Fabrika Polo T-Shirt) - Should scrape title, brand, prices and ratings (4.5/17) correctly', () async {
      final file = File('scratch/boyner_4.html');
      if (!file.existsSync()) return;
      final html = await file.readAsString();
      final document = html_parser.parse(html);
      const url = 'https://www.boyner.com.tr/siyah-erkek-100-pamuk-polo-t-shirt-nobro-cepsiz-nb-p-15784597?magaza=boyner';

      final image = scraper.scrape(
        document: document,
        url: url,
        isLogoUrl: (u) => u.contains('logo'),
        resolveImageUrl: (img, p) => img,
        log: (_) {},
      );
      expect(image, isNotNull);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Polo T-Shirt'));

      final brand = scraper.scrapeBrand(document);
      expect(brand, equals('Fabrika'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(649.95));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(1399.0));

      final ratingValue = await scraper.scrapeRatingValue(document);
      expect(ratingValue, equals(4.5));

      final ratingCount = await scraper.scrapeRatingCount(document);
      expect(ratingCount, equals(17));
    });

    test('Product #5 (Patrizia Pepe Loafer) - Should scrape exact 11999 TL price without truncation', () async {
      final file = File('scratch/boyner_issue1.html');
      final html = file.existsSync()
          ? await file.readAsString()
          : '''
            <html>
              <head>
                <script>
                  var data = {"PriceInfo":{"Price":"11.999","OldPrice":"23.299","CampaignInfo":"%48 İndirim"}};
                </script>
              </head>
              <body>
                <h1>Patrizia Pepe Ekru Kadın Deri Loafer</h1>
                <span class="price_priceMain__DrVVQ">
                  <span class="price_priceMainText__6p5Zp">Sepette</span>11.999 TL
                </span>
                <span class="price_priceOldPrice__test">23.299 TL</span>
              </body>
            </html>
          ''';
      final document = html_parser.parse(html);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Patrizia Pepe'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(11999.0));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(23299.0));

      final label = await scraper.scrapePriceLabel(document);
      expect(label, equals('%48 İndirim'));
    });

    test('Product #6 (Azzaro Wanted Absolu) - Should scrape exact 7910 TL price without truncation', () async {
      final file = File('scratch/boyner_issue2.html');
      final html = file.existsSync()
          ? await file.readAsString()
          : '''
            <html>
              <head>
                <script>
                  var data = {"PriceInfo":{"Price":"7.910","OldPrice":"11.300","CampaignInfo":"%30 İndirim"}};
                </script>
              </head>
              <body>
                <h1>Azzaro Wanted Absolu</h1>
                <span class="price_priceMain__DrVVQ">
                  <span class="price_priceMainText__6p5Zp">Sepette</span>7.910 TL
                </span>
                <span class="price_priceOldPrice__test">11.300 TL</span>
              </body>
            </html>
          ''';
      final document = html_parser.parse(html);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Azzaro'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(7910.0));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(11300.0));

      final label = await scraper.scrapePriceLabel(document);
      expect(label, equals('%30 İndirim'));
    });

    test('Product #7 (Tommy Hilfiger Blue Bag) - Should scrape 3014.25 TL and 4019 TL correctly', () async {
      final file = File('scratch/boyner_issue3.html');
      final html = file.existsSync()
          ? await file.readAsString()
          : '''
            <html>
              <head>
                <script>
                  var data = {"PriceInfo":{"Price":"3.014,25","OldPrice":"4.019","CampaignInfo":"%25 İndirim"}};
                </script>
              </head>
              <body>
                <h1>Tommy Hilfiger Mavi Kadın Çanta</h1>
                <span class="price_priceMain__DrVVQ">
                  <span class="price_priceMainText__6p5Zp">Sepette</span>3.014,25 TL
                </span>
                <span class="price_priceOldPrice__test">4.019 TL</span>
              </body>
            </html>
          ''';
      final document = html_parser.parse(html);

      final title = scraper.scrapeTitle(document);
      expect(title, contains('Tommy Hilfiger'));

      final price = await scraper.scrapePrice(document);
      expect(price, equals(3014.25));

      final originalPrice = await scraper.scrapeOriginalPrice(document, price);
      expect(originalPrice, equals(4019.0));

      final label = await scraper.scrapePriceLabel(document);
      expect(label, equals('%25 İndirim'));
    });
  });
}
