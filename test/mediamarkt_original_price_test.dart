import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/mediamarkt_scraper.dart';

void main() {
  test('MediaMarkt Original Price Scraper Test (All 6 Links)', () async {
    final scraper = MediaMarktScraper();

    final testCases = [
      {
        'name': 'Link 1 (ASUS TUF Gaming F16)',
        'url': 'https://www.mediamarkt.com.tr/tr/product/_asus-tuf-gaming-f16-fx608jhr-rv047wintelr-coretm-i7-14650hx16-gb-ram512-gb-ssdrtx-505016w11-laptop-1247804.html',
        'expectedDiscounted': 66999.00,
        'expectedOriginal': 69999.00,
      },
      {
        'name': 'Link 2 (Momax iPhone 15 Pro Kılıf)',
        'url': 'https://www.mediamarkt.com.tr/tr/product/_momax-mrap23me-iphone-15-pro-roller-magsafe-kilif-uzay-grisi-1237656.html',
        'expectedDiscounted': 99.00,
        'expectedOriginal': 399.00,
      },
      {
        'name': 'Link 3 (ASUS Zenbook 14 - Sepette İndirim)',
        'url': 'https://www.mediamarkt.com.tr/tr/product/_asus-zenbook14-ux3405ca-st825wcore-u9-285h32114w11-1252868.html',
        'expectedDiscounted': 71999.10,
        'expectedOriginal': 79999.00,
      },
      {
        'name': 'Link 4 (Logitech G Pro X2 - Sepette İndirim)',
        'url': 'https://www.mediamarkt.com.tr/tr/product/_logitech-g-pro-x2-superstrike-kablosuz-oyuncu-mouse-beyaz-910-007777-1252130.html',
        'expectedDiscounted': 9499.05,
        'expectedOriginal': 9999.00,
      },
      {
        'name': 'Link 5 (Philips Fan Isıtıcı 3ü1)',
        'url': 'https://www.mediamarkt.com.tr/tr/product/_philips-amf87015-1-fan-isitici-3u-arada-hava-temizleyici-1228048.html',
        'expectedDiscounted': 22199.00,
        'expectedOriginal': 23999.00,
      },
      {
        'name': 'Link 6 (Dyson V10 Submarine)',
        'url': 'https://www.mediamarkt.com.tr/tr/product/_dyson-cyclone-v10-submarine-islak-kuru-sarjli-dikey-supurge-1251854.html',
        'expectedDiscounted': 23999.00,
        'expectedOriginal': 27999.00,
      },
    ];

    for (final tc in testCases) {
      final url = tc['url'] as String;
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Googlebot/2.1 (+http://www.google.com/bot.html)',
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

      expect((price! - (tc['expectedDiscounted'] as double)).abs() < 0.1, isTrue);
      expect(originalPrice, equals(tc['expectedOriginal']));

      if (originalPrice != null && price != null && originalPrice > price) {
        final discountPercent = (((originalPrice - price) / originalPrice) * 100).round();
        print('Discount Percentage: %$discountPercent');
      }
      print('✅ PASSED: ${tc['name']}\n');
    }
  });
}
