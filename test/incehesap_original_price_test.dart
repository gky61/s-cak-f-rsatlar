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

    const whatsappUA = 'WhatsApp/2.23.4.15 A';

    for (final tc in testCases) {
      final url = tc['url'] as String;
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': whatsappUA,
          'Accept-Language': 'tr-TR,tr;q=0.9',
        },
      );

      expect(response.statusCode, equals(200));
      final doc = html_parser.parse(response.body);

      final price = await scraper.scrapePrice(doc);
      final originalPrice = scraper.scrapeOriginalPrice(doc, price);

      print('--- ${tc['name']} ---');
      print('Discounted Price: $price');
      print('Original Price:   $originalPrice');

      expect(price, isNotNull);
      expect(price!, greaterThan(0));
      
      if (originalPrice != null) {
        expect(originalPrice, greaterThan(price));
        final discountPercent = (((originalPrice - price) / originalPrice) * 100).round();
        print('Discount Percentage: %$discountPercent');
      }
      print('✅ PASSED: ${tc['name']}\n');
    }
  });
}
