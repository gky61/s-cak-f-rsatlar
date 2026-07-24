import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/hepsiburada_scraper.dart';

void main() {
  test('Hepsiburada Original Price Scraper Test (All 6 Links)', () async {
    final scraper = HepsiburadaScraper();

    final testCases = [
      {
        'name': 'Link 1 (Seduna Skagen Plus)',
        'url': 'https://www.hepsiburada.com/seduna-skagen-plus-calisma-sandalyesi-ofis-koltugu-p-HBV00000NDU7K',
        'expectedDiscounted': 4013.86,
        'expectedOriginal': 4138.00,
      },
      {
        'name': 'Link 2 (Magly Magnetic Cars)',
        'url': 'https://www.hepsiburada.com/magly-magnetic-cars-manyetik-arac-oyun-seti-manyetik-yapi-bloklari-araba-eklentisi-p-HBCV0000E3NYHR',
        'expectedDiscounted': 336.00,
        'expectedOriginal': 545.00,
      },
      {
        'name': 'Link 3 (Philips 8000 Kahve Makinesi)',
        'url': 'https://www.hepsiburada.com/philips-8000-serisi-caf-aromis-kahve-makinesi-evde-kafe-kalitesi-54-farkli-icecek-ep8757-92-p-HBCV0000F9H40O',
        'expectedDiscounted': 42999.00,
        'expectedOriginal': 47999.00,
      },
      {
        'name': 'Link 4 (Lego Technic Kazıcı)',
        'url': 'https://www.hepsiburada.com/lego-technic-kazici-yukleyici-42197-7-yas-uzeri-cocuklar-icin-yaratici-oyuncak-model-yapim-seti-104-parca-p-HBCV00007GPXE2',
        'expectedDiscounted': 399.01,
        'expectedOriginal': 498.76,
      },
      {
        'name': 'Link 5 (Apple MacBook Pro M5 - İndirim Yok)',
        'url': 'https://www.hepsiburada.com/apple-macbook-pro-m5-pro-24gb-2tb-ssd-macos-14-tasinabilir-bilgisayar-uzay-siyahi-mjlw4tua-p-HBCV0000D5WX1P?url_src=and-product-detail',
        'expectedDiscounted': 166499.00,
        'expectedOriginal': null,
      },
      {
        'name': 'Link 6 (Lego Futbol Topu - İndirim Yok)',
        'url': 'https://www.hepsiburada.com/lego--editions-futbol-topu-43019---10-cocuklar-icin-yaratici-oyuncak-yapim-seti---dunya-kupasi-koleksiyonu-1498-parca-p-HBCV0000CT57NP?magaza=Toyzz+Shop&url_src=and-product-detail',
        'expectedDiscounted': 5699.00,
        'expectedOriginal': null,
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
