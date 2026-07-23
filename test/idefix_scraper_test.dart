import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/idefix_scraper.dart';

void main() {
  group('IdefixScraper Unit Tests', () {
    final scraper = IdefixScraper();

    test('canHandle should match Idefix domains', () {
      expect(scraper.canHandle('https://www.idefix.com/onvo-tv-p-17490103'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should parse ratingValue (5), reviewCount (1), and brand (Onvo) from Sample 1', () async {
      const html = '''
      <script type="application/ld+json">{"@context":"https://schema.org/","@type":"Product","name":"Onvo 65VQ90F3UA 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Google Smart QLED TV","image":"https://image01.idefix.com/resize/{size}product/17490103/65vq90f3ua-65-165-ekran-uydu-alicili-4k-ultra-hd-google-smart-qled-tv-6a0af4f5324dd.jpg","description":"Onvo 65VQ90F3UA 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Google Smart QLED TV yorumlarını inceleyin, idefix’e özel indirimli fiyata satın alın.","brand":{"@type":"Organization","name":"Onvo"},"sku":"8682655704117","gtin13":"8682655704117","aggregateRating":{"@type":"AggregateRating","ratingValue":5,"reviewCount":1,"bestRating":5},"offers":{"@type":"Offer","url":"https://www.idefix.com/onvo-65vq90f3ua-65-165-ekran-uydu-alicili-4k-ultra-hd-google-smart-qled-tv-p-17490103","priceCurrency":"TRY","price":26935.09,"priceSpecification":{"@type":"UnitPriceSpecification","priceCurrency":"TRY","price":29599,"priceType":"https://schema.org/ListPrice"},"itemCondition":"https://schema.org/NewCondition","availability":"https://schema.org/InStock"},"review":[{"@type":"Review","reviewBody":"Çok iyi televizyon,çok memnun kaldım.Sipariş verdikten 24 saat sonra teslim edildi.","author":{"@type":"Person","name":"M************ A****"},"name":"M************ A****","datePublished":"2026-04-29T12:12:22+03:00","reviewRating":{"@type":"Rating","ratingValue":5,"bestRating":5,"worstRating":1}}]}</script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(26935.09));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals("Onvo 65VQ90F3UA 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Google Smart QLED TV"));

      final ratingVal = await scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(5.0));

      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(1));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('Onvo'));
    });

    test('should parse ratingValue (4.8), reviewCount (32), and brand (LG) from Sample 2 with unescaped newlines', () async {
      const html = '''
      <script type="application/ld+json">{"@context":"https://schema.org/","@type":"Product","name":"LG  65QNED70A6A 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Smart QNED TV","image":"https://image01.idefix.com/resize/{size}product/13804573/lg65qned70a6a-65-165-ekran-uydu-alicili-4k-ultra-hd-smart-qned-tv-68c039269bb96.jpg","description":"LG  65QNED70A6A 65'' 165 Ekran Uydu Alıcılı 4K Ultra HD Smart QNED TV yorumlarını inceleyin, idefix’e özel indirimli fiyata satın alın.","brand":{"@type":"Organization","name":"LG"},"sku":"8806096434611","gtin13":"8806096434611","aggregateRating":{"@type":"AggregateRating","ratingValue":4.8,"reviewCount":32,"bestRating":5},"offers":{"@type":"Offer","url":"https://www.idefix.com/lg-65qned70a6a-65-165-ekran-uydu-alicili-4k-ultra-hd-smart-qned-tv-p-13804573","priceCurrency":"TRY","price":46449,"itemCondition":"https://schema.org/NewCondition","availability":"https://schema.org/InStock"},"review":[{"@type":"Review","reviewBody":"Satıcı tv’yi ilk iş günü gönderdi; kargo firması da ertesi gün ankara’ya ulaştırdı.
tv’yi beğendim. tv+, tod, beinconnect, apple music, apple tv, nvidia geforce now,  boosteroid gibi bu seviyede olması gereken uygulamalar var. tivibu go yok.
Uygulama açıkken ana ekrana basınca uygulamalar arka planda duruyor ve bekliyor, bu da güzel.
Renk ayarını tv’nin gece sadece tv açık, ışıklarınız kapalıylen “yapay zeka destekli resim modu” ile yaparsanız istediğin parlaklık ve konstrastı alırsınız.
Soundbar alacaksanız da muhakkak lg alın ki lg sync özelliği sayesinde iki cihazı tek kumanda ile kullanabilirsiniz. Tv açıldığında ve kapandığında lg sound bar da aynı tepkiyi verir.
Ben uydu ile değil sadece uygulamalarını kullanıyorum. Smart özelliği bir android box’e göre hızlı; ama apple tv 4k cihazına göre yavaş. O kadar da olur tabi.","author":{"@type":"Person","name":"e******** e*******"},"name":"e******** e*******","datePublished":"2026-02-25T21:50:21+03:00","reviewRating":{"@type":"Rating","ratingValue":5,"bestRating":5,"worstRating":1}}]}</script>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(46449.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, contains('65QNED70A6A'));

      final ratingVal = await scraper.scrapeRatingValue(doc);
      expect(ratingVal, equals(4.8));

      final ratingCnt = await scraper.scrapeRatingCount(doc);
      expect(ratingCnt, equals(32));

      final brand = scraper.scrapeBrand(doc);
      expect(brand, equals('LG'));
    });
  });
}
