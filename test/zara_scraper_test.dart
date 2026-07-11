import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/zara_scraper.dart';

void main() {
  group('ZaraScraper Unit Tests', () {
    final scraper = ZaraScraper();

    test('canHandle should match Zara domains', () {
      expect(scraper.canHandle('https://www.zara.com/tr/tr/soyut-desenli-dokumlu-gomlek-p04206102.html'), isTrue);
      expect(scraper.canHandle('https://zara.com/something'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape title, image, description and price from Zara JSON-LD ProductGroup HTML', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@context": "https://schema.org/",
        "@type": "ProductGroup",
        "name": "SOYUT DESENLİ DÖKÜMLÜ GÖMLEK",
        "url": "https://www.zara.com/tr/tr/soyut-desenli-dokumlu-gomlek-p04206102.html",
        "productGroupID": "04206102",
        "brand": {
          "@type": "Brand",
          "name": "ZARA"
        },
        "description": "Viskoz, liyosel ve %18 keten karışımlı kumaştan relaxed fit gömlek.",
        "image": [
          "https://static.zara.net/assets/public/952d/21a3/97354a2baf15/cc4c9a95e115/04206102112-p/04206102112-p.jpg?ts=1779785865421&w=1920"
        ],
        "hasVariant": [
          {
            "@type": "Product",
            "name": "SOYUT DESENLİ DÖKÜMLÜ GÖMLEK - Maviler - S (US S)",
            "sku": "567184878-112-2",
            "offers": {
              "@type": "Offer",
              "priceCurrency": "TRY",
              "price": "1090"
            }
          }
        ]
      }
      </script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(1090.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('SOYUT DESENLİ DÖKÜMLÜ GÖMLEK'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('Viskoz, liyosel ve %18 keten karışımlı kumaştan relaxed fit gömlek.'));

      final img = scraper.scrape(
        document: doc,
        url: 'https://www.zara.com/tr/tr/soyut-desenli-dokumlu-gomlek-p04206102.html',
        isLogoUrl: (urlString) => urlString.contains('logo'),
        resolveImageUrl: (imgUrl, pageUrl) => imgUrl,
        log: (msg) => print(msg),
      );
      expect(img, equals('https://static.zara.net/assets/public/952d/21a3/97354a2baf15/cc4c9a95e115/04206102112-p/04206102112-p.jpg?ts=1779785865421&w=1920'));
    });

    test('should scrape title, image, description and price from Zara script analyticsData and meta tags HTML', () async {
      final html = '''
      <head>
        <meta property="og:image" content="https://static.zara.net/assets/public/952d/21a3/97354a2baf15/cc4c9a95e115/04206102112-p/04206102112-p.jpg?ts=1779785865421&w=560">
        <meta name="description" content="Viskoz, liyosel ve %18 keten karışımlı kumaştan relaxed fit gömlek.">
      </head>
      <body>
        <script>
          var zara = window.zara || {};
          zara.analyticsData = {
            "appVersion": "9.2.0",
            "pageType": "PRODUCT_DETAILS",
            "mainPrice": 1090,
            "productName": "SOYUT DESENLİ DÖKÜMLÜ GÖMLEK"
          };
        </script>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(1090.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('SOYUT DESENLİ DÖKÜMLÜ GÖMLEK'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('Viskoz, liyosel ve %18 keten karışımlı kumaştan relaxed fit gömlek.'));

      final img = scraper.scrape(
        document: doc,
        url: 'https://www.zara.com/tr/tr/soyut-desenli-dokumlu-gomlek-p04206102.html',
        isLogoUrl: (urlString) => urlString.contains('logo'),
        resolveImageUrl: (imgUrl, pageUrl) => imgUrl,
        log: (msg) => print(msg),
      );
      expect(img, equals('https://static.zara.net/assets/public/952d/21a3/97354a2baf15/cc4c9a95e115/04206102112-p/04206102112-p.jpg?ts=1779785865421&w=560'));
    });
  });
}
