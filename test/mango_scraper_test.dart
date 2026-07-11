import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/mango_scraper.dart';

void main() {
  group('MangoScraper Unit Tests', () {
    final scraper = MangoScraper();

    test('canHandle should match Mango domains', () {
      expect(scraper.canHandle('https://shop.mango.com/tr/kadin/ceketler-ve-blazerler/deri-ceket_37082888'), isTrue);
      expect(scraper.canHandle('https://mango.com/something'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape title, image, description and price from Mango normal product script HTML', () async {
      final html = '''
      <head>
        <meta property="og:title" content="Dökümlü Trençkot">
        <meta property="og:image" content="https://st.mango.com/rcs/pics/static/T3/fotos/S20/37082888_30.jpg">
        <meta name="description" content="Kemer detaylı dökümlü pamuklu trençkot.">
      </head>
      <body>
        <script>
          self.__next_f.push([1,"67:[\"\$,\"\$L85\",null,{\"showAdditionalCurrencies\":\"\$undefined\",\"discountRate\":\"\$undefined\",\"hideSaleOrPromoPrice\":false,\"price\":{\"amount\":2999.99,\"formatted\":\"2.999,99 TL\",\"additionalPrices\":[]},\"crossedOutPrices\":[]}]\n"]);
        </script>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(2999.99));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Dökümlü Trençkot'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('Kemer detaylı dökümlü pamuklu trençkot.'));

      final img = scraper.scrape(
        document: doc,
        url: 'https://shop.mango.com/tr/kadin/ceketler-ve-blazerler/deri-ceket_37082888',
        isLogoUrl: (urlString) => urlString.contains('logo'),
        resolveImageUrl: (imgUrl, pageUrl) => imgUrl,
        log: (msg) => print(msg),
      );
      expect(img, equals('https://st.mango.com/rcs/pics/static/T3/fotos/S20/37082888_30.jpg'));
    });

    test('should scrape title and price from Mango discounted product script HTML', () async {
      final html = '''
      <body>
        <script>
          self.__next_f.push([1,"66:[\"\$,\"\$L82\",null,{\"showAdditionalCurrencies\":\"\$undefined\",\"discountRate\":47,\"hideSaleOrPromoPrice\":false,\"price\":{\"amount\":1599.99,\"formatted\":\"1.599,99 TL\",\"additionalPrices\":[]},\"crossedOutPrices\":[{\"amount\":2999.99}]}]\n"]);
        </script>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(1599.99));
    });

    test('should scrape price with escaped quotes from real Next.js payload HTML', () async {
      final html = r'''
      <body>
        <script>
          self.__next_f.push([1,"T001\":{\"compositionId\":\"T001\",\"prices\":{\"price\":3699.99,\"starPrice\":false,\"type\":\"PVP\"}}],\"id\":\"37061358\""]);
        </script>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(3699.99));
    });

    test('should scrape price with nested escaped amount from real Next.js payload HTML', () async {
      final html = r'''
      <body>
        <script>
          self.__next_f.push([1,"country\":\"$4:props:children:1\",\"channel\":\"shop\",\"price\":{\"amount\":1599.99,\"formatted\":\"1.599,99 TL\"}"]);
        </script>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(1599.99));
    });
  });
}
