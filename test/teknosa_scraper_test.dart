import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/teknosa_scraper.dart';

void main() {
  group('TeknosaScraper Unit Tests', () {
    final scraper = TeknosaScraper();

    test('canHandle should match Teknosa domains', () {
      expect(scraper.canHandle('https://www.teknosa.com/apple-iphone-17-pro-max-256gb-kozmik-turuncu-akilli-telefon-p-100000058776'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse price, title, ratingValue (4.3), reviewCount (39), and brand (Apple) from Teknosa ld+json string', () async {
      const html = '''
      <script id="schemaJSON" type="application/ld+json" async="">
        {
          "@context": "https://schema.org",
          "@type": "WebPage",
          "name": "Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon",
          "description": "Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon özelliklerini incelemek ve en uygun fiyata satın almak için hemen tıkla!",
          "url": "https://www.teknosa.com/apple-iphone-17-pro-max-256gb-kozmik-turuncu-akilli-telefon-p-100000058776",
          "breadcrumb": {
          "@type": "BreadcrumbList",
          "itemListElement": [{
              "@type": "ListItem",
              "position": 1,
              "name": "Anasayfa",
              "item": "https://www.teknosa.com"
          },
              {
              "@type": "ListItem",
              "position": 2,
              "name": "Telefon",
              "item": "https://www.teknosa.com/telefon-c-100"
              },
              {
              "@type": "ListItem",
              "position": 3,
              "name": "Cep Telefonu",
              "item": "https://www.teknosa.com/cep-telefonu-c-100001"
              },
              {
              "@type": "ListItem",
              "position": 4,
              "name": "iOS Telefon",
              "item": "https://www.teknosa.com/ios-telefon-c-100001001"
              },
              {
              "@type": "ListItem",
              "position": 5,
              "name": "iPhone 17 Pro Max",
              "item": "https://www.teknosa.com/iphone-17-pro-max-c-100001001037"
              }
           ]},
          "@graph":{
          "@type": "Product",
          "name": "Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon",
          "description": "Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon özelliklerini incelemek ve en uygun fiyata satın almak için hemen tıkla!",
          "category":  {
          "@type": "Thing",
          "name": "Telefon>Cep Telefonu>iOS Telefon>iPhone 17 Pro Max"
          },
          "sku":"100000058776",
          "brand": {
          "@type": "Brand",
          "name": "Apple"
          },
          "image":[ 
            "https://reimg-teknosa-cloud-prod.mncdn.com/mnresize/600/600/productimage/100000058776/100000058776_0_MC/117159602.jpg" 
          ],
          "aggregateRating":{
            "@type":"AggregateRating",
            "ratingValue":"4.3",
            "reviewCount":"39"
          },
          "offers": {
            "@type": "Offer",
            "url": "https://www.teknosa.com/apple-iphone-17-pro-max-256gb-kozmik-turuncu-akilli-telefon-p-100000058776",
            "availability": "https://schema.org/InStock",
            "price": "122499.00",
            "priceCurrency": "TRY",
            "itemCondition": "https://schema.org/NewCondition",
            "seller": {
              "@type": "organization",
              "name": "TEKNOSA"
            }
          }}
        }
        </script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(122499.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals("Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon"));

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.3));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(39));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Apple'));
    });
  });
}
