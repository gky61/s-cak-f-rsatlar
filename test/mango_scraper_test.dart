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

    test('should scrape modern Mango Product #1 (Keten Gömlek) with sr-only and SinglePrice', () async {
      final html = '''
      <head>
        <title>Dar kesim %100 keten gömlek - Erkek | MANGO Türkiye</title>
        <meta property="og:title" content="Dar kesim %100 keten gömlek - Erkek | MANGO Türkiye">
        <meta property="og:image" content="https://media.mango.com/is/image/punto/37081422-95-002?wid=1024">
        <meta property="og:description" content="Slim fit. 100% keten kumaş.">
      </head>
      <body>
        <div class="SinglePrice-module__y_asRG__container">
          <span class="srOnly-module__3MmknW__className">Üstü çizili ilk fiyat [2.999,99 TL ]</span>
          <span class="SinglePrice-module__y_asRG__nowrap" aria-hidden="true" itemProp="offers" itemScope="" itemType="https://schema.org/Offer">
            <meta itemProp="priceCurrency" content="TRY"/>
            <meta itemProp="price" content="2999.99"/>
            <span class="SinglePrice-module__y_asRG__crossed">2.999,99 TL</span>
          </span>
          <span class="srOnly-module__3MmknW__className">Güncel fiyat [2.299,99 TL ]</span>
          <span class="SinglePrice-module__y_asRG__nowrap" aria-hidden="true" itemProp="offers" itemScope="" itemType="https://schema.org/Offer">
            <meta itemProp="priceCurrency" content="TRY"/>
            <meta itemProp="price" content="2299.99"/>
            <span class="SinglePrice-module__y_asRG__discounted">2.299,99 TL</span>
          </span>
        </div>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Dar kesim %100 keten gömlek'));

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(2299.99));

      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      expect(originalPrice, equals(2999.99));

      final img = scraper.scrape(
        document: doc,
        url: 'https://shop.mango.com/tr/tr/p/37081422/95/00',
        isLogoUrl: (urlString) => urlString.contains('logo'),
        resolveImageUrl: (imgUrl, pageUrl) => imgUrl,
        log: (msg) {},
      );
      expect(img, equals('https://media.mango.com/is/image/punto/37081422-95-002?wid=1024'));
    });

    test('should scrape modern Mango Product #2 (Modal Ceket) with sr-only and SinglePrice', () async {
      final html = '''
      <head>
        <title>Fermuarlı modal ceket - Erkek | MANGO Türkiye</title>
        <meta property="og:title" content="Fermuarlı modal ceket - Erkek | MANGO Türkiye">
        <meta property="og:image" content="https://media.mango.com/is/image/punto/37031333-56-002?wid=1024">
        <meta property="og:description" content="Modal karışımlı kumaş. Düz kesim.">
      </head>
      <body>
        <div class="SinglePrice-module__y_asRG__container">
          <span class="srOnly-module__3MmknW__className">Üstü çizili ilk fiyat [4.499,99 TL ]</span>
          <span class="SinglePrice-module__y_asRG__nowrap" aria-hidden="true" itemProp="offers" itemScope="" itemType="https://schema.org/Offer">
            <meta itemProp="priceCurrency" content="TRY"/>
            <meta itemProp="price" content="4499.99"/>
            <span class="SinglePrice-module__y_asRG__crossed">4.499,99 TL</span>
          </span>
          <span class="srOnly-module__3MmknW__className">Güncel fiyat [2.999,99 TL ]</span>
          <span class="SinglePrice-module__y_asRG__nowrap" aria-hidden="true" itemProp="offers" itemScope="" itemType="https://schema.org/Offer">
            <meta itemProp="priceCurrency" content="TRY"/>
            <meta itemProp="price" content="2999.99"/>
            <span class="SinglePrice-module__y_asRG__discounted">2.999,99 TL</span>
          </span>
        </div>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Fermuarlı modal ceket'));

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(2999.99));

      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      expect(originalPrice, equals(4499.99));

      final img = scraper.scrape(
        document: doc,
        url: 'https://shop.mango.com/tr/tr/p/37031333/56/00?utm_source=product-share&utm_medium=social',
        isLogoUrl: (urlString) => urlString.contains('logo'),
        resolveImageUrl: (imgUrl, pageUrl) => imgUrl,
        log: (msg) {},
      );
      expect(img, equals('https://media.mango.com/is/image/punto/37031333-56-002?wid=1024'));
    });
  });
}

