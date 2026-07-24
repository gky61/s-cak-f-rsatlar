import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/idefix_scraper.dart';

void main() {
  test('idefix Original Price Scraper Test (All 4 Links)', () async {
    final scraper = IdefixScraper();

    final testCases = [
      {
        'name': 'Link 1 (Sony DualSense 007 LE)',
        'url': 'https://www.idefix.com/sony-playstation-dualsensebond-007-le-bilkom-garantili-p-25934572',
        'expectedDiscounted': 6047.90,
        'expectedOriginal': 6234.95,
      },
      {
        'name': 'Link 2 (Lenovo XT62 Kulaklık)',
        'url': 'https://www.idefix.com/lenovo-xt62-kulaklik-bluetooth-53-kablosuz-kulakici-kulaklik-hd-cagri-siyah-p-3442168',
        'expectedDiscounted': 793.90,
        'expectedOriginal': 850.00,
      },
      {
        'name': 'Link 3 (Ray-Ban Güneş Gözlüğü)',
        'url': 'https://www.idefix.com/ray-ban-2186-90171-49-20-kadin-gunes-gozlugu-p-7613778',
        'expectedDiscounted': 4307.53,
        'expectedOriginal': 5334.40,
      },
      {
        'name': 'Link 4 (Samsung Süpürge)',
        'url': 'https://www.idefix.com/samsung-vc07r302mvr-kirmizi-750-w-toz-torbasiz-supurge-p-771736',
        'expectedDiscounted': 4560.00,
        'expectedOriginal': 7290.00,
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
