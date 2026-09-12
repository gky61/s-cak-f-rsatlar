import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/hepsiburada_scraper.dart';

void main() {
  group('User Reported Hepsiburada Links Verification', () {
    final scraper = HepsiburadaScraper();

    Future<String> resolveHbBiz(String url) async {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url))..followRedirects = false;
        request.headers['User-Agent'] = 'WhatsApp/2.23.4.15 A';
        request.headers['Accept'] = 'text/html';
        final response = await client.send(request);
        final location = response.headers['location'];
        if (location != null) {
          final uri = Uri.parse(location);
          final fallback = uri.queryParameters['adjust_fallback'] ?? uri.queryParameters['adj_fallback'];
          if (fallback != null) {
            return Uri.decodeComponent(fallback);
          }
          return location;
        }
      } catch (e) {
        // Fallback
      } finally {
        client.close();
      }
      return url;
    }

    test('Link 1: https://app.hb.biz/zOqd6X8KNBul (Lego Kozmos - Sepete Özel %15 İndirim)', () async {
      final shortUrl = 'https://app.hb.biz/zOqd6X8KNBul';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      print('Link 1 Final Scraped Results:');
      print('  Price: $price (Expected: 598.99)');
      print('  Original Price: $originalPrice (Expected: ~705)');
      print('  Price Label: $priceLabel (Expected: null)');

      expect(price, equals(598.99));
      expect(originalPrice, isIn([704.7, 705.0]));
      expect(priceLabel, isNull);
    });

    test('Link 2: https://app.hb.biz/FjaVvFsSlT9I (Lego Papatyalar - Sepete Özel %5 İndirim)', () async {
      final shortUrl = 'https://app.hb.biz/FjaVvFsSlT9I';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final originalPrice = scraper.scrapeOriginalPrice(doc, price);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      print('Link 2 Final Scraped Results:');
      print('  Price: $price (Expected: 711.55)');
      print('  Original Price: $originalPrice (Expected: 749.0)');
      print('  Price Label: $priceLabel (Expected: null)');

      expect(price, equals(711.55));
      expect(originalPrice, equals(749.0));
      expect(priceLabel, isNull);
    });
  });
}
