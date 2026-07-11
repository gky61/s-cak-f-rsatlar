import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/defacto_scraper.dart';

void main() {
  group('DefactoScraper Unit Tests', () {
    final scraper = DefactoScraper();

    test('canHandle should match Defacto domains', () {
      expect(scraper.canHandle('https://www.defacto.com.tr/fitted-gomlek-yaka-burumcuk-kisa-kollu-gomlek-3152656'), isTrue);
      expect(scraper.canHandle('https://defacto.com.tr/something'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape title, image, description and price from normal Defacto product script HTML', () async {
      final html = '''
      <head>
        <meta property="og:image" content="https://dfcdn.net/mnresize/800/-/product/V7699AZ_26SP_WT32_01_04.jpg">
        <meta name="description" content="NEW REGULAR FIT Basic Tişört en iyi fiyatla DeFacto'da.">
      </head>
      <body>
        <script>
          var PRODUCT_DETAIL_INFO_3374112={name:"%100 Pamuk NEW REGULAR FIT Basic Tişört",id:"V7699AZ26SPWT32",price:"299,99",brand:"DeFacto",variant:"K&#x131;r&#x131;k Beyaz",list:"00000000-0000-0000-0000-000000000000",quantity:1,category:"Ti&#x15F;&#xF6;rt"};
          window.PRODUCT_DETAIL_LASTVISITED={
            ProductVariantMiniDiscountedPriceInclTax:"299.99",
            ProductVariantMiniProductName:"%100 Pamuk NEW REGULAR FIT Basic Ti&#x15F;&#xF6;rt"
          };
        </script>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(299.99));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('%100 Pamuk NEW REGULAR FIT Basic Tişört'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('NEW REGULAR FIT Basic Tişört en iyi fiyatla DeFacto\'da.'));

      final img = scraper.scrape(
        document: doc,
        url: 'https://www.defacto.com.tr/fitted-gomlek-yaka-burumcuk-kisa-kollu-gomlek-3152656',
        isLogoUrl: (urlString) => urlString.contains('logo'),
        resolveImageUrl: (imgUrl, pageUrl) => imgUrl,
        log: (msg) => print(msg),
      );
      expect(img, equals('https://dfcdn.net/mnresize/800/-/product/V7699AZ_26SP_WT32_01_04.jpg'));
    });

    test('should scrape title and price from campaign Defacto product script HTML', () async {
      final html = '''
      <body>
        <script>
          var PRODUCT_DETAIL_INFO_3454655={name:"Fitted Kırışık Dokulu Kumaş Gömlek",id:"D4520AX26SMTR111",price:"799,99",brand:"DeFacto",variant:"Deniz Mavisi",list:"00000000-0000-0000-0000-000000000000",quantity:1,category:"G&#xF6;mlek"};
          window.PRODUCT_DETAIL_LASTVISITED={
            ProductVariantMiniDiscountedPriceInclTax:"799.99",
            ProductVariantMiniProductName:"Fitted K&#x131;r&#x131;&#x15F;&#x131;k Dokulu Kuma&#x15F; G&#xF6;mlek",
            CampaignBadge:{"CampaignId":"30082587-eba3-4047-b7cd-3de4f24e7a2d","CampaignDescription":"Sepette","CalculationTypeId":"f48714a0-a719-4730-bf84-be6787bb27af","DiscountAmount":50,"DiscountPrice":399.99,"StartDate":"2023-12-14T10:00:00","EndDate":"2026-07-31T23:59:00","DiscountBadgeStartDate":null,"DiscountBadgeDescription":null,"DiscountBadgePrice":null}
          };
        </script>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(399.99));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Fitted Kırışık Dokulu Kumaş Gömlek'));
    });
  });
}
