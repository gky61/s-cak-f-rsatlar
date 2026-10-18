import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:sicak_firsatlar/services/scrapers/migros_scraper.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  group('Migros Sanalmarket & Marketplace Tests', () {
    final scraper = MigrosScraper();

    test('extractProductId should correctly convert hex product suffixes to decimal SKU', () {
      // 1. Nestle Hemen (-p-6b6158 -> 7037272)
      expect(scraper.extractProductId('https://www.migros.com.tr/hemen/nestle-beyaz-kare-cikolata-60-g-p-6b6158'), '7037272');

      // 2. Söke Un Sanal Market (-p-4c73e1 -> 5010401)
      expect(scraper.extractProductId('https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1'), '5010401');

      // 3. UGG Bot Sanal Market (-p-3150731 -> 51709745)
      expect(scraper.extractProductId('https://www.migros.com.tr/grocery-mp/ugg-1116109-mnl-classic-ultra-mini-kadin-bot-bej-36-p-3150731'), '51709745');

      // 4. Crocs Sanal Market (-p-315835c -> 51741532)
      expect(scraper.extractProductId('https://www.migros.com.tr/grocery-mp/crocs-baya-platform-glitter-kadin-terlik-pembe-36-40-p-315835c'), '51741532');
    });

    test('parseSlugTitle should extract clean, human-readable title from URL slug', () {
      expect(
        scraper.parseSlugTitle('https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1'),
        'Söke Un 1 Kg',
      );
      expect(
        scraper.parseSlugTitle('https://www.migros.com.tr/grocery-mp/ugg-1116109-mnl-classic-ultra-mini-kadin-bot-bej-36-p-3150731'),
        'Ugg 1116109 Mnl Classic Ultra Mini Kadın Bot Bej 36',
      );
    });

    test('prepare & scrape should extract title, image, price and details for Söke Un', () async {
      const url = 'https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1';
      const spaShellHtml = '''
        <!DOCTYPE html>
        <html>
          <head>
            <title>Migros</title>
            <meta property="og:title" content="Migros">
            <meta property="og:image" content="https://images.migrosone.com/sanalmarket/custom/sanalmarket-seo-34706362.png">
            <link rel="canonical" href="https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1">
          </head>
          <body>
            <div id="app"></div>
          </body>
        </html>
      ''';

      final doc = parser.parse(spaShellHtml);
      await scraper.prepare(document: doc, url: url);

      // 1. Title must NOT be 'Migros'
      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title, contains('Söke Un'));

      // 2. Image must NOT be the placeholder banner
      final img = scraper.scrape(
        document: doc,
        url: url,
        isLogoUrl: (u) => u.contains('sanalmarket-seo') || u.contains('logo'),
        resolveImageUrl: (u, _) => u,
        log: (_) {},
      );
      expect(img, isNotNull);
      expect(img, isNot(contains('sanalmarket-seo')));
      expect(img, contains('images.migrosone.com/sanalmarket/product'));

      // 3. Price
      final price = await scraper.scrapePrice(doc);
      expect(price, isNotNull);
      expect(price, greaterThan(0));

      // 4. Original Price (if discounted)
      final origPrice = await scraper.scrapeOriginalPrice(doc, price);
      expect(origPrice, isNotNull);
      expect(origPrice, greaterThan(price!));

      // 5. Price Label
      final priceLabel = await scraper.scrapePriceLabel(doc);
      expect(priceLabel, isNotNull);
      expect(priceLabel, 'Money ile');

      // 6. Brand
      final brand = scraper.scrapeBrand(doc);
      expect(brand, 'Söke');
    });

    test('prepare & scrape should extract title, image, and price for UGG marketplace item', () async {
      const url = 'https://www.migros.com.tr/grocery-mp/ugg-1116109-mnl-classic-ultra-mini-kadin-bot-bej-36-p-3150731';
      const spaShellHtml = '''
        <!DOCTYPE html>
        <html>
          <head>
            <title>Migros</title>
            <meta property="og:title" content="Migros">
            <meta property="og:image" content="https://images.migrosone.com/sanalmarket/custom/sanalmarket-seo-34706362.png">
          </head>
          <body></body>
        </html>
      ''';

      final doc = parser.parse(spaShellHtml);
      await scraper.prepare(document: doc, url: url);

      // Title
      final title = scraper.scrapeTitle(doc);
      expect(title, isNotNull);
      expect(title!.toLowerCase(), contains('ugg'));

      // Image
      final img = scraper.scrape(
        document: doc,
        url: url,
        isLogoUrl: (u) => u.contains('sanalmarket-seo') || u.contains('logo'),
        resolveImageUrl: (u, _) => u,
        log: (_) {},
      );
      expect(img, isNotNull);
      expect(img, isNot(contains('sanalmarket-seo')));
      expect(img, contains('images.migrosone.com'));
      expect(img, contains('/product/'));

      // Price (Money indirimli: 11.999,95 TL)
      final price = await scraper.scrapePrice(doc);
      expect(price, isNotNull);
      expect(price, closeTo(11999.95, 0.01));

      // Original Price (İndirimsiz: 13.999,95 TL)
      final origPrice = await scraper.scrapeOriginalPrice(doc, price);
      expect(origPrice, isNotNull);
      expect(origPrice, closeTo(13999.95, 0.01));

      // Price Label (Money ile)
      final priceLabel = await scraper.scrapePriceLabel(doc);
      expect(priceLabel, 'Money ile');
    });

    test('LinkPreviewService.fetchMetadata should scrape Söke Un sanal market link end-to-end', () async {
      final service = LinkPreviewService();
      final preview = await service.fetchMetadata('https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1');

      expect(preview, isNotNull);
      expect(preview!.title, contains('Söke Un'));
      expect(preview.imageUrl, isNotNull);
      expect(preview.imageUrl, isNot(contains('sanalmarket-seo')));
      expect(preview.imageUrl, contains('images.migrosone.com'));
      expect(preview.price, isNotNull);
      expect(preview.price, greaterThan(0));
      expect(preview.originalPrice, isNotNull);
      expect(preview.originalPrice, greaterThan(preview.price!));
      expect(preview.brand, 'Söke');
      expect(preview.priceLabel, 'Money ile');
    });

    test('LinkPreviewService.fetchMetadata should scrape Nestle Hemen link end-to-end', () async {
      final service = LinkPreviewService();
      final preview = await service.fetchMetadata('https://www.migros.com.tr/hemen/nestle-beyaz-kare-cikolata-60-g-p-6b6158');

      expect(preview, isNotNull);
      expect(preview!.title, contains('Nestle'));
      expect(preview.imageUrl, isNotNull);
      expect(preview.imageUrl, isNot(contains('sanalmarket-seo')));
      expect(preview.imageUrl, contains('images.migrosone.com'));
      expect(preview.price, isNotNull);
      expect(preview.price, greaterThan(0));
      expect(preview.brand, 'Nestle');
    });

    test('LinkPreviewService.fetchMetadata should scrape UGG marketplace link end-to-end with Money price', () async {
      final service = LinkPreviewService();
      final preview = await service.fetchMetadata('https://www.migros.com.tr/grocery-mp/ugg-1116109-mnl-classic-ultra-mini-kadin-bot-bej-36-p-3150731');

      expect(preview, isNotNull);
      expect(preview!.title!.toLowerCase(), contains('ugg'));
      expect(preview.imageUrl, isNotNull);
      expect(preview.imageUrl, isNot(contains('sanalmarket-seo')));
      expect(preview.imageUrl, contains('images.migrosone.com'));
      expect(preview.price, isNotNull);
      expect(preview.price, closeTo(11999.95, 0.01));
      expect(preview.originalPrice, isNotNull);
      expect(preview.originalPrice, closeTo(13999.95, 0.01));
      expect(preview.priceLabel, 'Money ile');
      expect(preview.brand, 'Ugg');
    });

    test('LinkPreviewService.fetchMetadata should scrape Gepettoys sanal market link end-to-end with Money price', () async {
      final service = LinkPreviewService();
      final preview = await service.fetchMetadata('https://www.migros.com.tr/grocery-mp/gepettoys-catch-ball-set-18-cm-p-229439a');

      expect(preview, isNotNull);
      expect(preview!.title!.toLowerCase(), contains('gepettoys'));
      expect(preview.imageUrl, isNotNull);
      expect(preview.imageUrl, isNot(contains('sanalmarket-seo')));
      expect(preview.imageUrl, contains('images.migrosone.com'));
      expect(preview.price, isNotNull);
      expect(preview.price, closeTo(71.97, 0.01));
      expect(preview.originalPrice, isNotNull);
      expect(preview.originalPrice, closeTo(119.95, 0.01));
      expect(preview.priceLabel, 'Money ile');
    });

    test('extractProductId should handle query parameters, trailing slashes and hash fragments', () {
      expect(scraper.extractProductId('https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1?recom=personal&page=1'), '5010401');
      expect(scraper.extractProductId('https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1/'), '5010401');
      expect(scraper.extractProductId('https://www.migros.com.tr/hemen/nestle-beyaz-kare-cikolata-60-g-p-6b6158#section-reviews'), '7037272');
    });

    test('Expando concurrency isolation should ensure separate documents do not cross-bleed cached data', () async {
      final doc1 = parser.parse('<html><head><title>Migros</title></head><body></body></html>');
      final doc2 = parser.parse('<html><head><title>Migros</title></head><body></body></html>');

      // Interleaved prepare
      await scraper.prepare(document: doc1, url: 'https://www.migros.com.tr/grocery-mp/soke-un-1-kg-p-4c73e1');
      await scraper.prepare(document: doc2, url: 'https://www.migros.com.tr/grocery-mp/ugg-1116109-mnl-classic-ultra-mini-kadin-bot-bej-36-p-3150731');

      // doc1 must still yield Söke Un
      final title1 = scraper.scrapeTitle(doc1);
      final price1 = await scraper.scrapePrice(doc1);
      expect(title1, contains('Söke Un'));
      expect(price1, lessThan(200));

      // doc2 must yield Ugg Bot
      final title2 = scraper.scrapeTitle(doc2);
      final price2 = await scraper.scrapePrice(doc2);
      expect(title2!.toLowerCase(), contains('ugg'));
      expect(price2, greaterThan(1000));
    });

    test('parseSlugTitle should work as pure offline fallback when HTML is generic', () {
      final title = scraper.parseSlugTitle('https://www.migros.com.tr/grocery-mp/organik-sut-1-l-p-abcdef');
      expect(title, 'Organik Süt 1 L');
    });
  });
}
