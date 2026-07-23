import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/trendyol_scraper.dart';

void main() {
  group('TrendyolScraper Unit Tests', () {
    final scraper = TrendyolScraper();

    test('should scrape title, image, and price correctly from ProductGroup JSON-LD', () async {
      final html = '''
<!DOCTYPE html>
<html>
<head>
<script type="application/ld+json">{
 "@context": "https://schema.org",
 "@type": "ProductGroup",
 "productGroupID": "898167691",
 "@id": "https://www.trendyol.com/robeve/550-ml-otomatik-hava-nemlendirici-buhar-makinesi-oda-nemlendirici-aroma-difuzor-beyaz-p-898167691",
 "name": "ROBEVE 550 ml Otomatik Hava Nemlendirici Buhar Makinesi Oda Nemlendirici Aroma Difüzör Beyaz",
 "manufacturer": "ROBEVE",
 "image": {
  "type": "ImageObject",
  "contentUrl": [
   "https://cdn.dsmcdn.com/ty1783/prod/QC_ENRICHMENT/20251103/21/e1fbb2d1-553b-3dec-af2f-076c33520c1c/1_org_zoom.jpg",
   "https://cdn.dsmcdn.com/ty1783/prod/QC_ENRICHMENT/20251103/21/d782ab2a-076b-3a6b-b469-2fd15e44fff3/1_org_zoom.jpg"
  ]
 },
 "description": "ROBEVE 550 ml Otomatik Hava Nemlendirici Buhar Makinesi Oda Nemlendirici Aroma Difüzör Beyaz yorumlarını inceleyin.",
 "sku": "898167691",
 "brand": {
  "@type": "Brand",
  "name": "ROBEVE"
 },
 "offers": {
  "@type": "Offer",
  "url": "https://www.trendyol.com/robeve/550-ml-otomatik-hava-nemlendirici-buhar-makinesi-oda-nemlendirici-aroma-difuzor-beyaz-p-898167691",
  "priceCurrency": "TRY",
  "price": "486.67",
  "availability": "https://schema.org/InStock"
 },
 "hasVariant": [
  {
   "@type": "Product",
   "name": "ROBEVE 550 ml Hava Nemlendirici Buhar Makinesi Ultrasonik Aroma Difüzör Oda Nemlendirici Işıklı Zamanlayıcı",
   "image": "https://cdn.dsmcdn.com/ty1784/prod/QC_ENRICHMENT/20251103/21/0bff9063-b164-3b03-b47f-3907d105a6bd/1_org_zoom.jpg",
   "sku": "364313731",
   "color": "ahsap",
   "offers": {
    "@type": "Offer",
    "price": "505.85"
   }
  }
 ]
}</script>
</head>
<body>
</body>
</html>
''';

      final doc = html_parser.parse(html);

      // Scrape Title
      final title = scraper.scrapeTitle(doc);
      expect(title, equals('ROBEVE 550 ml Otomatik Hava Nemlendirici Buhar Makinesi Oda Nemlendirici Aroma Difüzör Beyaz'));

      // Scrape Image
      final image = scraper.scrape(
        document: doc,
        url: 'https://www.trendyol.com/some-product',
        isLogoUrl: (u) => false,
        resolveImageUrl: (img, page) => img,
        log: (msg) => print(msg),
      );
      expect(image, equals('https://cdn.dsmcdn.com/ty1783/prod/QC_ENRICHMENT/20251103/21/e1fbb2d1-553b-3dec-af2f-076c33520c1c/1_org_zoom.jpg'));

      // Scrape Price
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(486.67));
    });

    test('should parse ratingValue, ratingCount, and brand from Trendyol ld+json string', () async {
      const html = '''
      <script type="application/ld+json">{
       "@context": "https://schema.org",
       "@type": "Product",
       "name": "KTC H27T22C 27″ 1Ms(GtG) 200Hz (210Hz O.C.) 2K QHD Fast IPS Gaming Monitör",
       "brand": {
        "@type": "Brand",
        "name": "KTC"
       },
       "offers": {
        "@type": "Offer",
        "price": "7899.00"
       },
       "aggregateRating": {
        "@type": "AggregateRating",
        "ratingValue": 4.5,
        "ratingCount": 33,
        "reviewCount": 21
       }
      }</script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(7899.00));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('KTC H27T22C 27″ 1Ms(GtG) 200Hz (210Hz O.C.) 2K QHD Fast IPS Gaming Monitör'));

      final ratingVal = scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.5));

      final ratingCnt = scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(33));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('KTC'));
    });
  });
}
