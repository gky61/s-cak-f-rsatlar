import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/mavi_scraper.dart';

void main() {
  group('MaviScraper Unit Tests', () {
    final scraper = MaviScraper();

    test('canHandle should match Mavi domains', () {
      expect(scraper.canHandle('https://www.mavi.com/lisbon-classic-denim-koyu-indigo-mavisi-jean-pantolon/p/0010039-A3934'), isTrue);
      expect(scraper.canHandle('https://mavi.com/something'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape title, image, description and price from Mavi JSON-LD HTML string', () async {
      final html = '''
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "WebPage",
        "name": "Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon",
        "url": "https://www.mavi.com/lisbon-classic-denim-koyu-indigo-mavisi-jean-pantolon/p/0010039-A3934",
        "mainEntity": {
          "@type": "WebPageElement",
          "offers": {
            "@type": "Offer",
            "itemOffered": [
              {
                "@type": "Product",
                "name": "Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon",
                "description": "Mavi nin denim koleksiyonundan Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon. Loose, bol kesim. Normal bel. Düz paçası ile sokak giyimi ve 9 lar ilhamlı Jean lerden biri.",
                "brand": {
                  "@type": "Brand",
                  "name": "Mavi"
                },
                "image": [
                  {
                    "@type": "ImageObject",
                    "contentUrl": "https://sky-static.mavi.com/mnresize/820/1162/0010039-A3934_image_1.jpg?v=1783678883967"
                  }
                ],
                "offers": {
                  "@type": "Offer",
                  "price": "1799.99",
                  "priceCurrency": "TRY"
                }
              }
            ]
          }
        }
      }
      </script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(1799.99));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, contains('Mavi nin denim koleksiyonundan Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon.'));

      final img = scraper.scrape(
        document: doc,
        url: 'https://www.mavi.com/lisbon-classic-denim-koyu-indigo-mavisi-jean-pantolon/p/0010039-A3934',
        isLogoUrl: (urlString) => urlString.contains('logo'),
        resolveImageUrl: (imgUrl, pageUrl) => imgUrl,
        log: (msg) => print(msg),
      );
      expect(img, equals('https://sky-static.mavi.com/mnresize/820/1162/0010039-A3934_image_1.jpg?v=1783678883967'));
    });
  });
}
