import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/havit_scraper.dart';

void main() {
  group('HavitScraper Unit Tests', () {
    final scraper = HavitScraper();

    test('canHandle should match Havit domains', () {
      expect(scraper.canHandle('https://www.havitstore.com.tr/havit-hv-ms745-gaming-mouse'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (4.75) from .comment-count and ratingCount (328) from .comment-count-left', () async {
      const html = '''
      <span class="comment-count-left">328</span>
      <div class="right-stars">
        <div class="comment-count" style="margin-right:8px;font-size:32px;">4.75</div>
      </div>
      ''';
      final doc = html_parser.parse(html);

      final ratingVal = await scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.75));

      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(328));
    });

    test('should parse ratingValue (4.8), ratingCount (15) and brand (Havit) from Ticimax script model', () async {
      const html = '''
      <span id="divYorumSayisi">(15)</span>
      <script type="text/javascript">
        var productDetailModel = {"productId":375,"productName":"Havit Gamenote GK60 PRO","rating":4.8,"brandName":"Havit"};
      </script>
      ''';
      final doc = html_parser.parse(html);

      final ratingVal = await scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.8));

      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(15));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Havit'));
    });
  });
}
