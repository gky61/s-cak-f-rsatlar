import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/teknosa_scraper.dart';

void main() {
  test('Teknosa Original Price Scraper Test (All 4 Links)', () async {
    final scraper = TeknosaScraper();

    final testCases = [
      {
        'name': 'Link 1 (Honor Magic 8 Lite 5G)',
        'url': 'https://www.teknosa.com/honor-magic-8-lite-5g-8512gb-kizil-kahve-akilli-telefon-p-100000060344?shopId=teknosa',
        'expectedDiscounted': 25999.00,
        'expectedOriginal': 29999.00,
      },
      {
        'name': 'Link 2 (Samsung Galaxy S26 Ultra 5G)',
        'url': 'https://www.teknosa.com/samsung-galaxy-s26-ultra-5g-12512gb-mor-akilli-telefon-p-100000061511?shopId=teknosa',
        'expectedDiscounted': 99999.00,
        'expectedOriginal': 105999.00,
      },
      {
        'name': 'Link 3 (Philips 55PUS900062 TV)',
        'url': 'https://www.teknosa.com/philips-55pus900062-55-139-ekran-4k-uhd-titan-os-ambilight-tv-p-100000055139?shopId=teknosa',
        'expectedDiscounted': 43299.00,
        'expectedOriginal': 49999.00,
      },
      {
        'name': 'Link 4 (TCL 55 C6K TV)',
        'url': 'https://www.teknosa.com/tcl-55-c6k-premium-qd-mini-led-tv-p-100000055042?shopId=teknosa',
        'expectedDiscounted': 49999.00,
        'expectedOriginal': 56999.00,
      },
    ];

    for (final tc in testCases) {
      final url = tc['url'] as String;
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'WhatsApp/2.23.4.15 A',
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
