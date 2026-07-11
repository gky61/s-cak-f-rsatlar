import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/beymen_scraper.dart';

void main() {
  group('BeymenScraper Unit Tests', () {
    final scraper = BeymenScraper();

    test('canHandle should match Beymen domains', () {
      expect(scraper.canHandle('https://www.beymen.com/tr/p_etro-lacivert-etnik-desenli-gomlek_1627505'), isTrue);
      expect(scraper.canHandle('https://beymen.com/something'), isTrue);
      expect(scraper.canHandle('https://www.google.com'), isFalse);
    });

    test('should scrape title, image, description and price from Beymen JSON-LD HTML', () async {
      final html = '''
      <head>
        <script type="application/ld+json">
        {
            "@context": "https://schema.org/",
            "@type": "Product",
            "name": "Lacivert Etnik Desenli Gömlek",
            "image": [
                "https://cdn.beymen.com/productimages/aj4ffhsd.rcf_IMG_01_2110099740461.jpg",
                "https://cdn.beymen.com/productimages/ewxgm15v.wb1_IMG_02_2110099740461.jpg"
            ],
            "description": "Düğmeli yaka, etnik desenli gömlek.",
            "sku": "102203894_500",
            "mpn": "102203894_500",
            "brand": {
                "@type": "Brand",
                "name": "Etro"
            },
            "offers": {
                "@type": "Offer",
                "url": "https://www.beymen.com/tr/p_etro-lacivert-etnik-desenli-gomlek_1627505",
                "priceCurrency": "TRY",
                "price": "30450.00",
                "availability": "https://schema.org/InStock"
            }
        }
        </script>
      </head>
      <body>
      </body>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(30450.0));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Lacivert Etnik Desenli Gömlek'));

      final desc = scraper.scrapeDescription(doc);
      expect(desc, equals('Düğmeli yaka, etnik desenli gömlek.'));

      final img = scraper.scrape(
        document: doc,
        url: 'https://www.beymen.com/tr/p_etro-lacivert-etnik-desenli-gomlek_1627505',
        isLogoUrl: (urlString) => urlString.contains('logo'),
        resolveImageUrl: (imgUrl, pageUrl) => imgUrl,
        log: (msg) => print(msg),
      );
      expect(img, equals('https://cdn.beymen.com/productimages/aj4ffhsd.rcf_IMG_01_2110099740461.jpg'));
    });

    test('should scrape title, price and description successfully from JSON-LD containing raw newlines', () async {
      final html = '''
      <head>
        <script type="application/ld+json">
        {
            "@context": "https://schema.org/",
            "@type": "Product",
            "name": "Playstation 5 Slim Standart Dijital Edition 1 TB Oyun Konsolu + 2. Beyaz Dualsense + Şarj  İstasyonu ",
            "image": ["https://cdn.beymen.com/productimages/ichycp2i.jvw_MP_81bfa6c7-8244-451d-93fb-a7b397071f52_1_70228984281662254105557926213_245.jpg"],
            "description": "• Paket içeriği: PlayStation 5 Slim Digital konsol + 2 beyaz DualSense kontrol cihazı + şarj istasyonu — iki oyunculu deneyime hazır |
•İthalatçı garantili — 24 ay |
•PlayStation 5 Slim, Digital sürüm — disk okuyucu içermez",
            "sku": "70228984281662254105557926213_245",
            "mpn": "70228984281662254105557926213_245",
            "brand": {
                "@type": "Brand",
                "name": "Sony"
            },
            "offers": {
                "@type": "Offer",
                "url": "https://www.beymen.com/tr/p_sony-playstation-5-slim-standart-dijital-edition-1-tb-oyun-konsolu-2-beyaz-dualsense-sarj-istasyonu_1878314",
                "priceCurrency": "TRY",
                "price": "43297.94",
                "availability": "https://schema.org/InStock"
            }
        }
        </script>
      </head>
      ''';
      final doc = html_parser.parse(html);

      final price = await scraper.scrapePrice(doc);
      expect(price, equals(43297.94));

      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Playstation 5 Slim Standart Dijital Edition 1 TB Oyun Konsolu + 2. Beyaz Dualsense + Şarj  İstasyonu'));

      final brand = doc.querySelector('meta[property="og:brand"]')?.attributes['content'];
      // brand is Sony, but title from JSON-LD should be the full name:
      expect(title, isNot(equals('Sony')));
    });

    test('should fall back to DOM selectors for title and lowest campaign price when JSON-LD is malformed (unescaped quotes)', () async {
      final html = '''
      <head>
        <script type="application/ld+json">
        {
            "@context": "https://schema.org/",
            "@type": "Product",
            "name": "iPad 11. Nesil A16 11" Wi-Fi 128GB Pembe Tablet MD4E4TU/A",
            "brand": {
                "@type": "Brand",
                "name": "Apple"
            }
        }
        </script>
        <meta name="description" content="Apple markalı Pembe renk Teknoloji iPad 11. Nesil A16 11">
      </head>
      <body>
        <h1 class="o-productDetail__title">Apple</h1>
        <span class="o-productDetail__description">iPad 11. Nesil A16 11" Wi-Fi 128GB Pembe Tablet MD4E4TU/A</span>
        
        <div class="m-priceWrapper">
          <ins class="m-price__new">22.679,38 TL</ins>
          <span class="m-price__campaignPrice">21.999,00 TL</span>
        </div>
      </body>
      ''';
      final doc = html_parser.parse(html);

      // JSON-LD is malformed due to unescaped double quotes after 11.
      // So name and price from JSON-LD should fail, and we must fall back to DOM.
      final title = scraper.scrapeTitle(doc);
      expect(title, equals('iPad 11. Nesil A16 11" Wi-Fi 128GB Pembe Tablet MD4E4TU/A'));

      final price = await scraper.scrapePrice(doc);
      // It should choose the lowest price among normal and campaign prices (21999.00 < 22679.38)
      expect(price, equals(21999.00));
    });

    test('should scrape price and displayName from BEYMEN.productMain script for Madras set', () async {
      final html = '''
      <head>
        <script type="text/javascript">
          BEYMEN.productMain = {"productId":1776595,"displayName":"Madras Altın Rengi Çelik Dekorlu 84 Parça 12 Kişilik Çatal Kaşık Bıçak Seti","promotedOrActualPrice":62926.5000};
        </script>
      </head>
      ''';
      final doc = html_parser.parse(html);
      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Madras Altın Rengi Çelik Dekorlu 84 Parça 12 Kişilik Çatal Kaşık Bıçak Seti'));
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(62926.5));
    });

    test('should scrape price and displayName from BEYMEN.productMain script for Beyaz Gomlek', () async {
      final html = '''
      <head>
        <script type="text/javascript">
          BEYMEN.productMain = {"productId":1654806,"displayName":"Beyaz Gömlek","promotedOrActualPrice":14995.0000};
        </script>
      </head>
      ''';
      final doc = html_parser.parse(html);
      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Beyaz Gömlek'));
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(14995.0));
    });

    test('should scrape price and displayName from BEYMEN.productMain script for Lacivert Etnik Desenli Gomlek', () async {
      final html = '''
      <head>
        <script type="text/javascript">
          BEYMEN.productMain = {"productId":1627505,"displayName":"Lacivert Etnik Desenli Gömlek","promotedOrActualPrice":30450.0000};
        </script>
      </head>
      ''';
      final doc = html_parser.parse(html);
      final title = scraper.scrapeTitle(doc);
      expect(title, equals('Lacivert Etnik Desenli Gömlek'));
      final price = await scraper.scrapePrice(doc);
      expect(price, equals(30450.0));
    });
  });
}
