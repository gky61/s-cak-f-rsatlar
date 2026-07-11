import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/incehesap_scraper.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  group('IncehesapScraper Unit Tests', () {
    final scraper = IncehesapScraper();

    test('should scrape title, image, and price correctly from dataLayer (no basket discount)', () async {
      final html = '''
<!DOCTYPE html>
<html>
<head>
<script>
    dataLayer.push({ ecommerce: null });
    window.dataLayer.push({"event":"view_item","ecommerce":{"currency":"TRY","value":6899,"items":[{"id":87639,"item_id":87639,"item_name":"AOC 27G50Z 27″ 260Hz(OC) 0.3ms Full HD FreeSync Fast IPS Oyuncu Monitörü","item_brand":"AOC","image":"https:\\/\\/www.incehesap.com\\/resim\\/urun\\/202601\\/696f69921b4fd0.78483601_lfqinpjkgohme_500.webp","url":"https:\\/\\/www.incehesap.com\\/aoc-27g50z-27-260hzoc-0-3ms-full-hd-freesync-fast-ips-oyuncu-monitoru-fiyati-87639\\/","price":6899,"quantity":1,"index":0,"item_category":"Çevre Birimleri","item_category2":"Monitör"}]}});
</script>
<meta name="description" content="AOC 27G50Z 27 inç oyuncu monitörü açıklaması">
</head>
<body>
  <div class="price">6.899 TL</div>
</body>
</html>
''';

      final doc = html_parser.parse(html);

      // Title
      final title = scraper.scrapeTitle(doc);
      expect(title, equals('AOC 27G50Z 27″ 260Hz(OC) 0.3ms Full HD FreeSync Fast IPS Oyuncu Monitörü'));

      // Image
      final image = scraper.scrape(
        document: doc,
        url: 'https://www.incehesap.com/some-product',
        isLogoUrl: (u) => false,
        resolveImageUrl: (img, page) => img,
        log: (msg) => print(msg),
      );
      expect(image, equals('https://www.incehesap.com/resim/urun/202601/696f69921b4fd0.78483601_lfqinpjkgohme_500.webp'));

      // Description
      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('AOC 27G50Z 27 inç oyuncu monitörü açıklaması'));

      // Price (should use dataLayer, value is 6899)
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(6899.0));
    });

    test('should scrape price from DOM when basket discount class is present', () async {
      final html = '''
<!DOCTYPE html>
<html>
<head>
<script>
    dataLayer.push({ ecommerce: null });
    window.dataLayer.push({"event":"view_item","ecommerce":{"currency":"TRY","value":6899,"items":[{"id":87639,"item_id":87639,"item_name":"AOC 27G50Z","price":6899}]}});
</script>
</head>
<body>
  <div class="basketdiscount-label-detail">%6 indirim</div>
  <div class="price">6.485,06 TL</div>
</body>
</html>
''';

      final doc = html_parser.parse(html);

      // Price (should use DOM .price because of basket discount, value is 6485.06 instead of 6899)
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(6485.06));
    });

    test('Fetch real İncehesap URL using LinkPreviewService', () async {
      final url = "https://www.incehesap.com/aoc-27g50z-27-260hzoc-0-3ms-full-hd-freesync-fast-ips-flat-gaming-monitor-fiyati-87639/";
      print("Fetching $url via LinkPreviewService...");

      final service = LinkPreviewService();
      final result = await service.fetchMetadata(url);

      expect(result, isNotNull);
      print("Result title: ${result?.title}");
      print("Result price: ${result?.price}");
      print("Result imageUrl: ${result?.imageUrl}");
      print("Result description: ${result?.description}");

      expect(result?.title, contains("AOC"));
      expect(result?.price, isNotNull);
      expect(result?.price, greaterThan(0));
      expect(result?.imageUrl, isNotNull);
      expect(result?.imageUrl, contains("incehesap.com"));
    });
  });
}
