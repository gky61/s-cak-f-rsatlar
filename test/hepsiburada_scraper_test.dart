import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/hepsiburada_scraper.dart';

void main() {
  group('HepsiburadaScraper Unit Tests', () {
    final scraper = HepsiburadaScraper();

    test('canHandle should match Hepsiburada domains', () {
      expect(scraper.canHandle('https://www.hepsiburada.com/product-p-HBCV0000AHHOFE'), isTrue);
      expect(scraper.canHandle('https://hb.biz/some-short-url'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape normal price from hb-normal html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Apple iPhone 17 Pro Max 256 GB",
        "offers": {
          "price": "120499.00"
        }
      }
      </script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(120499.00));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Apple iPhone 17 Pro Max 256 GB'));
    });

    test('should scrape premium price from hb-premium html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Ant Home Asimetrik Ayna, Çerçeveli Ayna, Duvar Aynası, Konsol Aynası, Banyo Aynası, Çerçeveli"
      }
      </script>
      <span>Premium ile <b>344,49 TL</b></span>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(344.49));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Ant Home Asimetrik Ayna, Çerçeveli Ayna, Duvar Aynası, Konsol Aynası, Banyo Aynası, Çerçeveli'));
    });

    test('should scrape premium price from hb-premium-2 html string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Selpak® Kağıt Havlu"
      }
      </script>
      <span>Premium ile <b>282,67 TL</b></span>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(282.67));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Selpak® Kağıt Havlu'));
    });

    test('should scrape ratingValue, ratingCount, and brand from ld+json graph', () async {
      final html = '''
      <script type="application/ld+json">{"@context":"https://schema.org","@type":"WebPage","name":"Apple Watch Series 11","@graph":[{"@type":"Product","name":"Apple Watch Series 11","brand":{"@additionalType":"Organization","name":"Apple"},"aggregateRating":{"@type":"AggregateRating","ratingValue":4.8,"ratingCount":1173},"offers":{"@type":"Offer","price":"20999.00"}}]}</script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(20999.00));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Apple Watch Series 11'));

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.8));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(1173));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Apple'));
    });

    test('should NOT mark deal as Premium for generic coupon/installment tags (False Positive Prevention)', () async {
      final html = '''
      <script id="reduxStore" type="application/json">
      {
        "productState": {
          "product": {
            "name": "Pepsi Strawberries Zero Sugar",
            "tagList": [
              {"tagId": "premiumlulara-ozel-gida-icecek-urunlerinde-50-tl-uzeri-15-indirim"},
              {"tagId": "premium-a-ozel-supermarket-urunlerinde-750-tl-ye-150-tl-kupon-firsati"},
              {"tagId": "premiuma-gec-50-tl-indirim-kazanma-firsati"},
              {"tagId": "premium-vade-farksiz"}
            ],
            "mainProductTagList": [
              {"tagId": "premium-vade-farksiz"}
            ],
            "paymentTag": "premium-vade-farksiz"
          }
        }
      }
      </script>
      <header><a class="sf-TopLinks-P85WSaCVLc_4UmgwMQJt">Hepsiburada Premium</a></header>
      ''';
      final doc = html_parser.parse(html);

      final priceLabel = await scraper.scrapePriceLabel(doc);
      expect(priceLabel, isNull);
    });

    test('should mark deal as Premium when DOM contains direct Premium price or loyalty badge', () async {
      final htmlDom = '''
      <div>
        <span class="premium-price">Premium ile <b>1.411,83 TL</b></span>
      </div>
      ''';
      final docDom = html_parser.parse(htmlDom);
      final priceLabelDom = await scraper.scrapePriceLabel(docDom);
      expect(priceLabelDom, equals('Premium ile'));

      final htmlLoyalty = '''
      <div>
        <div data-test-id="premium-price">Hepsiburada Premium ile 299,90 TL</div>
      </div>
      ''';
      final docLoyalty = html_parser.parse(htmlLoyalty);
      final priceLabelLoyalty = await scraper.scrapePriceLabel(docLoyalty);
      expect(priceLabelLoyalty, equals('Premium ile'));
    });
  });
}

