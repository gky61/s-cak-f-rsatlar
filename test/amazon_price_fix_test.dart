import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/amazon_scraper.dart';

void main() {
  group('AmazonScraper & parsePriceText Güvenlik ve Savunma Testleri', () {
    late AmazonScraper scraper;

    setUp(() {
      scraper = AmazonScraper();
    });

    test('canHandle: fenom.io ve tüm amazon alan adlarını tanır', () {
      expect(scraper.canHandle('https://fenom.io/amzn-vd612'), isTrue);
      expect(scraper.canHandle('https://fenom.io/amzn-zrllz'), isTrue);
      expect(scraper.canHandle('https://www.amazon.com.tr/dp/B0FNNBH3YT'), isTrue);
      expect(scraper.canHandle('https://amzn.to/3example'), isTrue);
      expect(scraper.canHandle('https://amzn.eu/d/12345'), isTrue);
      expect(scraper.canHandle('https://trendyol.com/urun-p-123'), isFalse);
    });

    test('parsePriceText: Dublike fiyat metinlerini başarıyla tekil değere indirger', () {
      // Çift offscreen + aria-hidden birleşmesi vakası
      expect(scraper.parsePriceText('269,91TL269,91TL'), 269.91);
      expect(scraper.parsePriceText('269,91269,91'), 269.91);
      expect(scraper.parsePriceText('299,90TL299,90TL'), 299.90);
      expect(scraper.parsePriceText('38160TL38160TL'), 38160.0);
      expect(scraper.parsePriceText('30000TL30000TL'), 30000.0);

      // Metinsel etiket içeren fiyatlar (Accessibility label)
      expect(scraper.parsePriceText('Yüzde 10 tasarruf ile 269,91 TL'), 269.91);
      expect(scraper.parsePriceText('Sepette %20 indirimle 1.250,50 TL'), 1250.50);

      // Standart fiyatlar
      expect(scraper.parsePriceText('269,91 TL'), 269.91);
      expect(scraper.parsePriceText('1.234,56 TL'), 1234.56);
      expect(scraper.parsePriceText('299,90 ₺'), 299.90);
    });

    test('scrapePrice: Accordion / apex-pricetopay-value yapısından 269.91 çeker', () async {
      const htmlSnippet = '''
        <div id="apex_desktop">
          <div class="a-section">
            <span class="a-price a-text-normal aok-align-center reinventPriceAccordionT2 apex-pricetopay-value" data-a-size="l">
              <span class="a-offscreen">269,91TL</span>
              <span aria-hidden="true">
                <span class="a-price-whole">269<span class="a-price-decimal">,</span></span>
                <span class="a-price-fraction">91</span>
                <span class="a-price-symbol">TL</span>
              </span>
            </span>
          </div>
          <div class="basisPrice">
            <span class="a-price a-text-price apex-basisprice-value">
              <span class="a-offscreen">299,90TL</span>
              <span aria-hidden="true">299,90TL</span>
            </span>
          </div>
        </div>
      ''';

      final doc = html_parser.parse(htmlSnippet);
      final price = await scraper.scrapePrice(doc);
      final originalPrice = scraper.scrapeOriginalPrice(doc, price);

      expect(price, 269.91);
      expect(originalPrice, 299.90);
    });
  });
}
