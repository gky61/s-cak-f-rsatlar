import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/pazarama_scraper.dart';

void main() {
  group('PazaramaScraper Unit Tests', () {
    final scraper = PazaramaScraper();

    test('should parse normal price from pazarama-normal html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Normal Pazarama Urunu",
        "offers": {
          "price": "47879.00"
        }
      }
      </script>
      <meta name="description" content="Normal pazarama urun aciklamasi">
      ''';
      final doc = html_parser.parse(html);
      
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(47879.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Normal Pazarama Urunu'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('Normal pazarama urun aciklamasi'));
    });

    test('should parse plus price from pazarama-plus html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Plus Pazarama Urunu"
      }
      </script>
      <meta name="description" content="Plus pazarama urun aciklamasi">
      <div>
        <img src="pz-plus-icon" alt="plus-icon">
        <span>455,24 TL</span>
      </div>
      ''';
      final doc = html_parser.parse(html);
      
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(455.24));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Plus Pazarama Urunu'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('Plus pazarama urun aciklamasi'));
    });

    test('should parse ratingValue, ratingCount, and brand from Pazarama ld+json string', () async {
      const html = '''
      <script data-n-head="ssr" type="application/ld+json">{"@context":"https://schema.org","@type":"Product","sku":"8855f485-cec1-40f9-84f9-08dd9ef7b3d2","url":"https://www.pazarama.com/apple-airpods-4-mxp63tua-p-195949688553","name":"Apple AirPods 4. Nesil MXP63TU/A Bluetooth Kulaklık","brand":{"@type":"Brand","name":"Apple"},"image":"https://img.pzrmcdn.com/asset/195949688553/images/appleairpods4mxp63tua-6.jpg","aggregateRating":{"@type":"AggregateRating","bestRating":"5","worstRating":"1","reviewCount":158,"ratingValue":4.5},"offers":{"@type":"Offer","price":5999,"priceCurrency":"TRY"}}</script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(5999.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Apple AirPods 4. Nesil MXP63TU/A Bluetooth Kulaklık'));

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.5));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(158));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Apple'));
    });

    test('should NOT mark deal as Plus for generic menu links or script payloads (False Positive Prevention)', () async {
      const html = '''
      <html>
        <body>
          <div class="bg-gradient-to-r Pazarama Plus">Pazarama Plus</div>
          <span class="text-xxs text-pink-500">Plus'ı Keşfet</span>
          <a href="https://www.pazarama.com/pazarama-plus">Pazarama Plus</a>
          <script>window.__NUXT__ = { plusPrice: { currency: "TL" }, CART_BASKET_PLUS_PROMO: true };</script>
          <div>Standart Fiyat: 1.500 TL</div>
        </body>
      </html>
      ''';
      final doc = html_parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(priceLabel, isNull);
    });

    test('should mark deal as Plus when DOM contains pz-plus-icon or Şimdi Plus\'lı Ol CTA', () async {
      const html = '''
      <html>
        <body>
          <div class="product-price">
            <img src="https://img.pzrmcdn.com/asset/_pzweb/img/pz-plus-icon.634982094b1176b6.png" alt="plus-icon" />
            <a class="btn">Şimdi Plus'lı Ol</a>
          </div>
        </body>
      </html>
      ''';
      final doc = html_parser.parse(html);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(priceLabel, equals('Plus ile'));
    });
  });
}

