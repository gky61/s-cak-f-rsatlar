import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/vatan_scraper.dart';

void main() {
  test('Vatan Original Price Scraper Test (All 5 Links)', () async {
    final scraper = VatanScraper();

    final testCases = [
      {
        'name': 'Link 1 (iPad A16 Tablet - İndirim Yok)',
        'url': 'https://www.vatanbilgisayar.com/ipad-a16-tablet.html',
        'expectedDiscounted': 24999.00,
        'expectedOriginal': null,
      },
      {
        'name': 'Link 2 (Philips PSG9050 Ütü)',
        'url': 'https://www.vatanbilgisayar.com/philips-psg9050-20-perfectcare-9000-serisi-buhar-kazanli-utu.html',
        'expectedDiscounted': 27499.00,
        'expectedOriginal': 32379.00,
      },
      {
        'name': 'Link 3 (Cougar Defansor Oyuncu Koltuğu)',
        'url': 'https://www.vatanbilgisayar.com/cougar-defansor-gold-f-siyah-sari-oyuncu-koltugu.html',
        'expectedDiscounted': 17499.00,
        'expectedOriginal': 20329.00,
      },
      {
        'name': 'Link 4 (MacBook Neo)',
        'url': 'https://www.vatanbilgisayar.com/macbook-neo-mhfe4tu-a-a18-pro-8gb-512gb-ssd-13inc-puslu-sari.html',
        'expectedDiscounted': 42299.00,
        'expectedOriginal': 46999.00,
      },
      {
        'name': 'Link 5 (JBL Charge 6 Hoparlör)',
        'url': 'https://www.vatanbilgisayar.com/jbl-charge6-bluetooth-hoparlor-kirmizi.html',
        'expectedDiscounted': 8456.00,
        'expectedOriginal': 9949.00,
      },
    ];

    for (final tc in testCases) {
      final url = tc['url'] as String;
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
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
