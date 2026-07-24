import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/incehesap_scraper.dart';

void main() {
  test('İncehesap Original Price Scraper Test (All 2 Links)', () async {
    final scraper = IncehesapScraper();

    final testCases = [
      {
        'name': 'Link 1 (AOC 27G50Z)',
        'url': 'https://www.incehesap.com/aoc-27g50z-27-260hzoc-0-3ms-full-hd-freesync-fast-ips-oyuncu-monitoru-fiyati-87639/',
        'expectedDiscounted': 6999.00,
        'expectedOriginal': 7099.00,
      },
      {
        'name': 'Link 2 (ASUS TUF Gaming VG259Q5A)',
        'url': 'https://www.incehesap.com/asus-tuf-gaming-vg259q5a-24-5-inc-200hz-0-3ms-elmb-sync-fast-ips-gaming-oyuncu-monitor-fiyati-83654/',
        'expectedDiscounted': 5799.00,
        'expectedOriginal': 5899.00,
      },
    ];

    const iphoneUA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';

    for (final tc in testCases) {
      final url = tc['url'] as String;
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': iphoneUA,
          'Accept-Language': 'tr-TR,tr;q=0.9',
        },
      );

      expect(response.statusCode, equals(200));
      final doc = html_parser.parse(response.body);

      final price = await scraper.scrapePrice(doc);
      final originalPrice = scraper.scrapeOriginalPrice(doc, price);

      print('--- ${tc['name']} ---');
      print('Discounted Price: $price (Expected: ${tc['expectedDiscounted']})');
      print('Original Price:   $originalPrice (Expected: ${tc['expectedOriginal']})');

      expect(price, equals(tc['expectedDiscounted']));
      expect(originalPrice, equals(tc['expectedOriginal']));

      if (originalPrice != null && price != null && originalPrice > price) {
        final discountPercent = (((originalPrice - price) / originalPrice) * 100).round();
        print('Discount Percentage: %$discountPercent');
      }
      print('✅ PASSED: ${tc['name']}\n');
    }
  });
}
