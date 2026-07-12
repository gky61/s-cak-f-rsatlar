import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/hepsiburada_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/trendyol_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/vatan_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/teknosa_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/mediamarkt_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/pttavm_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/pazarama_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/itopya_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/idefix_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/mavi_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/defacto_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/amazon_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/n11_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/incehesap_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/mango_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/beymen_scraper.dart';
import 'package:sicak_firsatlar/services/scrapers/zara_scraper.dart';
import 'package:sicak_firsatlar/services/category_detection_service.dart';

void main() {
  group('Hepsiburada Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = HepsiburadaScraper();

    test('1. Parse breadcrumbs from JSON-LD BreadcrumbList format', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "breadcrumb": {
      "@context": "https://schema.org/",
      "@type": "BreadcrumbList",
      "numberOfItems": 6,
      "itemListElement": [
        {"@type": "ListItem", "position": 1, "name": "Anasayfa", "item": "https://www.hepsiburada.com"},
        {"@type": "ListItem", "position": 2, "name": "Ev Elektronik Ürünleri", "item": "https://www.hepsiburada.com/ev-elektronik-urunleri-c-2147483638"},
        {"@type": "ListItem", "position": 3, "name": "Elektrikli Ev Aletleri", "item": "https://www.hepsiburada.com/elektrikli-ev-aletleri-c-17071"},
        {"@type": "ListItem", "position": 4, "name": "Süpürge", "item": "https://www.hepsiburada.com/supurgeler-c-155123"},
        {"@type": "ListItem", "position": 5, "name": "Şarjlı Süpürgeler", "item": "https://www.hepsiburada.com/sarjli-supurgeler-c-159445"}
      ]
    }
  }
  </script>
</head>
<body></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 4);
      expect(breadcrumbs[0], 'Ev Elektronik Ürünleri');
      expect(breadcrumbs[1], 'Elektrikli Ev Aletleri');
      expect(breadcrumbs[2], 'Süpürge');
      expect(breadcrumbs[3], 'Şarjlı Süpürgeler');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Beyaz Eşya & Küçük Ev Aletleri');
    });

    test('2. Parse breadcrumbs from JSON-LD Product category property', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Product",
        "name": "Dyson V12",
        "category": "Ev Elektroniği > Elektrikli Ev Aletleri > Süpürgeler > Şarjlı Süpürge"
      }
    ]
  }
  </script>
</head>
<body></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 4);
      expect(breadcrumbs[0], 'Ev Elektroniği');
      expect(breadcrumbs[1], 'Elektrikli Ev Aletleri');
      expect(breadcrumbs[2], 'Süpürgeler');
      expect(breadcrumbs[3], 'Şarjlı Süpürge');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Beyaz Eşya & Küçük Ev Aletleri');
    });

    test('3. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="breadcrumbs">
    <ul>
      <li><span itemprop="name">Anasayfa</span></li>
      <li><span itemprop="name">Moda</span></li>
      <li><span itemprop="name">Saat, Aksesuar & Takı</span></li>
      <li><span itemprop="name">Kolyeler</span></li>
    </ul>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 3);
      expect(breadcrumbs[0], 'Moda');
      expect(breadcrumbs[1], 'Saat, Aksesuar & Takı');
      expect(breadcrumbs[2], 'Kolyeler');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'moda');
      expect(categoryResult['subCategory'], 'Saat, Aksesuar & Takı');
    });
  });

  group('Trendyol Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = TrendyolScraper();

    test('1. Parse breadcrumbs from JSON-LD BreadcrumbList format', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "LG 65QNED70A6A QNED TV",
    "breadcrumb": {
      "@type": "BreadcrumbList",
      "numberOfItems": 6,
      "itemListElement": [
        {
          "@type": "ListItem",
          "position": 1,
          "item": {
            "@id": "https://www.trendyol.com",
            "name": "Trendyol"
          }
        },
        {
          "@type": "ListItem",
          "position": 2,
          "item": {
            "@id": "https://www.trendyol.com/elektronik-x-c104024",
            "name": "Elektronik"
          }
        },
        {
          "@type": "ListItem",
          "position": 3,
          "item": {
            "@id": "https://www.trendyol.com/tv-goruntu-ses-sistemleri-x-c104035",
            "name": "TV&Görüntü&Ses"
          }
        },
        {
          "@type": "ListItem",
          "position": 4,
          "item": {
            "@id": "https://www.trendyol.com/televizyon-x-c104156",
            "name": "Televizyon"
          }
        },
        {
          "@type": "ListItem",
          "position": 5,
          "item": {
            "@id": "https://www.trendyol.com/lg-televizyon-x-b791-c104156",
            "name": "LG Televizyon"
          }
        },
        {
          "@type": "ListItem",
          "position": 6,
          "item": {
            "@id": "https://www.trendyol.com",
            "name": "LG 65QNED70A6A QNED TV"
          }
        }
      ]
    }
  }
  </script>
</head>
<body><h1 class="product-title">LG 65QNED70A6A QNED TV</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 4);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'TV&Görüntü&Ses');
      expect(breadcrumbs[2], 'Televizyon');
      expect(breadcrumbs[3], 'LG Televizyon');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'TV & Ses Sistemleri');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="product-detail-breadcrumb">
    <a href="/elektronik">Elektronik</a>
    <a href="/bilgisayar">Bilgisayar & Tablet</a>
    <a href="/tasinabilir-bilgisayar">Dizüstü Bilgisayar (Laptop)</a>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 3);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'Bilgisayar & Tablet');
      expect(breadcrumbs[2], 'Dizüstü Bilgisayar (Laptop)');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Bilgisayar & Tablet');
    });
  });

  group('Vatan Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = VatanScraper();

    test('1. Parse breadcrumbs from JSON-LD and decode HTML entities', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {
        "@type": "ListItem",
        "position": 1,
        "item": {
          "@id": "https://www.vatanbilgisayar.com/tuketici-elektronigi/",
          "name": "T&#xFC;ketici Elektroni&#x11F;i"
        }
      },
      {
        "@type": "ListItem",
        "position": 2,
        "item": {
          "@id": "https://www.vatanbilgisayar.com/cep-telefonu-modelleri/",
          "name": "Cep Telefonu"
        }
      },
      {
        "@type": "ListItem",
        "position": 3,
        "item": {
          "@id": "https://www.vatanbilgisayar.com/akilli-telefon/",
          "name": "Ak&#x131;ll&#x131; Telefon"
        }
      },
      {
        "@type": "ListItem",
        "position": 4,
        "item": {
          "@id": "https://www.vatanbilgisayar.com/apple/akilli-telefon/",
          "name": "APPLE"
        }
      }
    ]
  }
  </script>
</head>
<body><h1 class="product_title">iPhone 15 Pro Max</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 4);
      expect(breadcrumbs[0], 'Tüketici Elektroniği');
      expect(breadcrumbs[1], 'Cep Telefonu');
      expect(breadcrumbs[2], 'Akıllı Telefon');
      expect(breadcrumbs[3], 'APPLE');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Telefon & Aksesuarları');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <ul class="breadcrumb">
    <li><a href="/tuketici-elektronigi/">T&#xFC;ketici Elektroni&#x11F;i</a></li>
    <li><a href="/bilgisayar/">Bilgisayar</a></li>
    <li><a href="/notebook/">Notebook</a></li>
  </ul>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 3);
      expect(breadcrumbs[0], 'Tüketici Elektroniği');
      expect(breadcrumbs[1], 'Bilgisayar');
      expect(breadcrumbs[2], 'Notebook');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Bilgisayar & Tablet');
    });
  });

  group('Teknosa Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = TeknosaScraper();

    test('1. Parse category breadcrumbs from custom schemaJSON structure', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script id="schemaJSON" type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "Sony Playstation Bakım Paketi",
    "breadcrumb": {
      "@type": "BreadcrumbList",
      "itemListElement": [
        {
          "@type": "ListItem",
          "position": 1,
          "name": "Anasayfa",
          "item": "https://www.teknosa.com"
        },
        {
          "@type": "ListItem",
          "position": 2,
          "name": "Bilgisayar & Tablet",
          "item": "https://www.teknosa.com/sony-playstation"
        },
        {
          "@type": "ListItem",
          "position": 3,
          "name": "Yazılım",
          "item": "https://www.teknosa.com/sony-playstation"
        },
        {
          "@type": "ListItem",
          "position": 4,
          "name": "Dijital Kurulum Paketleri",
          "item": "https://www.teknosa.com/sony-playstation"
        }
      ]
    },
    "@graph": {
      "@type": "Product",
      "name": "Sony Playstation Bakım Paketi",
      "category": {
        "@type": "Thing",
        "name": "Bilgisayar & Tablet>Yazılım>Dijital Kurulum Paketleri"
      }
    }
  }
  </script>
</head>
<body><h1 class="product-title">Sony Playstation Bakım Paketi</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      // It parses either breadcrumb schema or Product category. Since breadcrumb is found first, it gets mapped.
      expect(breadcrumbs.length, 3);
      expect(breadcrumbs[0], 'Bilgisayar & Tablet');
      expect(breadcrumbs[1], 'Yazılım');
      expect(breadcrumbs[2], 'Dijital Kurulum Paketleri');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'dijital_hizmetler');
      expect(categoryResult['subCategory'], 'Abonelik & Yazılım');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="breadcrumb">
    <a href="/elektronik">Elektronik</a>
    <a href="/televizyon">Televizyon</a>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'Televizyon');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'TV & Ses Sistemleri');
    });
  });

  group('MediaMarkt Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = MediaMarktScraper();

    test('1. Parse breadcrumbs from JSON-LD and filter home/leaf product', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json" data-rh="true">
  {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {"@type": "ListItem", "position": 1, "name": "home", "item": "https://www.mediamarkt.com.tr"},
      {"@type": "ListItem", "position": 2, "name": "Bilgisayar", "item": "https://www.mediamarkt.com.tr/tr/category/bilgisayar-504925.html"},
      {"@type": "ListItem", "position": 3, "name": "Laptop", "item": "https://www.mediamarkt.com.tr/tr/category/laptop-504926.html"},
      {"@type": "ListItem", "position": 4, "name": "Mac", "item": "https://www.mediamarkt.com.tr/tr/category/mac-645068.html"},
      {"@type": "ListItem", "position": 5, "name": "MacBook Air", "item": "https://www.mediamarkt.com.tr/tr/category/macbook-air-645070.html"},
      {"@type": "ListItem", "position": 6, "name": "APPLE MDHE4TU/A/MacBook Air/Apple M5...", "item": "https://www.mediamarkt.com.tr/tr/product/apple-1252857.html"}
    ]
  }
  </script>
</head>
<body><h1 class="mms-ui-title">APPLE MDHE4TU/A/MacBook Air/Apple M5...</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 4);
      expect(breadcrumbs[0], 'Bilgisayar');
      expect(breadcrumbs[1], 'Laptop');
      expect(breadcrumbs[2], 'Mac');
      expect(breadcrumbs[3], 'MacBook Air');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Bilgisayar & Tablet');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="mms-breadcrumb">
    <a href="/elektronik">Elektronik</a>
    <a href="/cep-telefonu">Cep Telefonu</a>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'Cep Telefonu');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Telefon & Aksesuarları');
    });
  });

  group('PttAVM Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = PttavmScraper();

    test('1. Parse breadcrumbs from JSON-LD and filter Anasayfa/leaf product', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {"@type": "ListItem", "position": 1, "name": "Anasayfa", "item": "https://www.pttavm.com"},
      {"@type": "ListItem", "position": 2, "name": "Elektronik", "item": "https://www.pttavm.com/elektronik-c-1"},
      {"@type": "ListItem", "position": 3, "name": "Elektrikli Ev & Mutfak Aletleri", "item": "https://www.pttavm.com/elektrikli-ev-ve-mutfak-aleti-c-19"},
      {"@type": "ListItem", "position": 4, "name": "Elektrikli Mutfak Aletleri", "item": "https://www.pttavm.com/elektrikli-mutfak-aleti-c-49"},
      {"@type": "ListItem", "position": 5, "name": "Kahve Makineleri", "item": "https://www.pttavm.com/kahve-makinesi-c-144"},
      {"@type": "ListItem", "position": 6, "name": "Cappuccino ve Espresso Makineleri", "item": "https://www.pttavm.com/cappuccino-ve-espresso-makinesi-c-307"},
      {"@type": "ListItem", "position": 7, "name": "Philips 5400 Tam Otomatik Espresso Makinesi", "item": "https://www.pttavm.com/philips-5400-p-1427219451"}
    ]
  }
  </script>
</head>
<body><h1 class="product-title">Philips 5400 Tam Otomatik Espresso Makinesi</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 5);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'Elektrikli Ev & Mutfak Aletleri');
      expect(breadcrumbs[2], 'Elektrikli Mutfak Aletleri');
      expect(breadcrumbs[3], 'Kahve Makineleri');
      expect(breadcrumbs[4], 'Cappuccino ve Espresso Makineleri');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Beyaz Eşya & Küçük Ev Aletleri');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="breadcrumbs">
    <a href="/elektronik">Elektronik</a>
    <a href="/foto-kamera">Foto & Kamera</a>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'Foto & Kamera');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Fotoğraf & Kamera');
    });
  });

  group('Pazarama Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = PazaramaScraper();

    test('1. Parse breadcrumbs from JSON-LD with data-n-head attribute', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script data-n-head="ssr" type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {"@type": "ListItem", "position": 1, "item": "https://www.pazarama.com", "name": "Anasayfa"},
      {"@type": "ListItem", "position": 2, "item": "https://www.pazarama.com/elektronik-k-K04", "name": "Elektronik"},
      {"@type": "ListItem", "position": 3, "item": "https://www.pazarama.com/televizyon-ve-ses-sistemleri-k-K04170", "name": "Televizyon ve Ses Sistemleri"},
      {"@type": "ListItem", "position": 4, "item": "https://www.pazarama.com/televizyon-k-K04188", "name": "Televizyon"},
      {"@type": "ListItem", "position": 5, "item": "https://www.pazarama.com/lg/televizyon-k-K04188", "name": "LG Televizyon"}
    ]
  }
  </script>
</head>
<body><h1 class="text-huge">LG OLED 65G4 4K Televizyon</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 4);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'Televizyon ve Ses Sistemleri');
      expect(breadcrumbs[2], 'Televizyon');
      expect(breadcrumbs[3], 'LG Televizyon');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'TV & Ses Sistemleri');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="pazarama-breadcrumb">
    <a href="/elektronik">Elektronik</a>
    <a href="/bilgisayar">Bilgisayar & Tablet</a>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'Bilgisayar & Tablet');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Bilgisayar & Tablet');
    });
  });

  group('Itopya Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = ItopyaScraper();

    test('1. Parse breadcrumbs from JSON-LD and filter Ana Sayfa/leaf product', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "http://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {
        "@type": "ListItem",
        "position": 1,
        "item": {
          "@id": "/",
          "name": "Ana Sayfa"
        }
      },
      {
        "@type": "ListItem",
        "position": 2,
        "item": {
          "@id": "https://www.itopya.com/cevre-birimleri_uk4",
          "name": "Çevre Birimleri"
        }
      },
      {
        "@type": "ListItem",
        "position": 3,
        "item": {
          "@id": "https://www.itopya.com/monitor_k5",
          "name": "Monitör"
        }
      },
      {
        "@type": "ListItem",
        "position": 4,
        "item": {
          "@id": "https://www.itopya.com/lenovo-legion-gaming-monitor-u33428",
          "name": "Lenovo Legion Gaming Monitör"
        }
      }
    ]
  }
  </script>
</head>
<body><h1 class="product-details-title">Lenovo Legion Gaming Monitör</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Çevre Birimleri');
      expect(breadcrumbs[1], 'Monitör');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Bilgisayar & Tablet');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <ul class="breadcrumb">
    <li><a href="/bilgisayar">Bilgisayar</a></li>
    <li><a href="/ekran-karti">Ekran Kartı</a></li>
  </ul>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Bilgisayar');
      expect(breadcrumbs[1], 'Ekran Kartı');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Bilgisayar & Tablet');
    });
  });

  group('Idefix Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = IdefixScraper();

    test('1. Parse breadcrumbs from JSON-LD and filter Ana sayfa', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org/",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {"@type": "ListItem", "position": 0, "name": "Ana sayfa", "item": "https://www.idefix.com/"},
      {"@type": "ListItem", "position": 1, "name": "Teknoloji", "item": "https://www.idefix.com/teknoloji-c-23"},
      {"@type": "ListItem", "position": 2, "name": "Isıtma ve Soğutma", "item": "https://www.idefix.com/isitma-ve-sogutma-c-2310"},
      {"@type": "ListItem", "position": 3, "name": "Klimalar", "item": "https://www.idefix.com/klimalar-c-2310782580"},
      {"@type": "ListItem", "position": 4, "name": "Duvar Tipi Klimalar", "item": "https://www.idefix.com/duvar-tipi-klimalar-c-231078694"}
    ]
  }
  </script>
</head>
<body><h1>Duvar Tipi Klima</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 4);
      expect(breadcrumbs[0], 'Teknoloji');
      expect(breadcrumbs[1], 'Isıtma ve Soğutma');
      expect(breadcrumbs[2], 'Klimalar');
      expect(breadcrumbs[3], 'Duvar Tipi Klimalar');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Beyaz Eşya & Küçük Ev Aletleri');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="breadcrumb">
    <a href="/kitap">Kitap</a>
    <a href="/edebiyat">Edebiyat</a>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Kitap');
      expect(breadcrumbs[1], 'Edebiyat');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'kitap_hobi');
      expect(categoryResult['subCategory'], 'Kitap & Dergi');
    });
  });

  group('Mavi Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = MaviScraper();

    test('1. Parse breadcrumbs from JSON-LD WebPage breadcrumb key', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "Sunmade Baskılı Bordo Tişört",
    "url": "https://www.mavi.com/sunmade-baskili-bordo-tisort/p/0613620-70426",
    "inLanguage": "tr",
    "breadcrumb": {
      "@type": "BreadcrumbList",
      "numberOfItems": "5",
      "itemListElement": [
        {"@type": "ListItem", "position": 1, "item": {"@id": "https://www.mavi.com", "name": "Anasayfa"}},
        {"@type": "ListItem", "position": 2, "item": {"@id": "https://www.mavi.com/erkek/c/2/", "name": "Erkek"}},
        {"@type": "ListItem", "position": 3, "item": {"@id": "https://www.mavi.com/erkek/tisort/c/2/", "name": "Tişört"}},
        {"@type": "ListItem", "position": 4, "item": {"@id": "https://www.mavi.com/erkek/tisort/baskili/c/2/", "name": "Baskılı"}},
        {"@type": "ListItem", "position": 5, "item": {"@id": "https://www.mavi.com/sunmade-bordo-tisort", "name": "Sunmade Baskılı Bordo Tişört"}}
      ]
    }
  }
  </script>
</head>
<body><h1>Sunmade Baskılı Bordo Tişört</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 3);
      expect(breadcrumbs[0], 'Erkek');
      expect(breadcrumbs[1], 'Tişört');
      expect(breadcrumbs[2], 'Baskılı');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'moda');
      expect(categoryResult['subCategory'], 'Erkek Giyim');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="mavi-breadcrumb">
    <a href="/kadin">Kadın</a>
    <a href="/elbise">Elbise</a>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Kadın');
      expect(breadcrumbs[1], 'Elbise');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'moda');
      expect(categoryResult['subCategory'], 'Kadın Giyim');
    });
  });

  group('Defacto Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = DefactoScraper();

    test('1. Parse breadcrumbs from JSON-LD and filter product title', () {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org/",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {"@type": "ListItem", "position": 1, "name": "Ana Sayfa", "item": "https://www.defacto.com.tr"},
      {"@type": "ListItem", "position": 2, "name": "Erkek", "item": "https://www.defacto.com.tr/erkek"},
      {"@type": "ListItem", "position": 3, "name": "Giyim", "item": "https://www.defacto.com.tr/erkek-giyim"},
      {"@type": "ListItem", "position": 4, "name": "Pantolon", "item": "https://www.defacto.com.tr/erkek-pantolon"},
      {"@type": "ListItem", "position": 5, "name": "Relax Fit Siyah Pantolon", "item": "https://www.defacto.com.tr/pantolon-3402850"}
    ]
  }
  </script>
</head>
<body><h1>Relax Fit Siyah Pantolon</h1></body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 3);
      expect(breadcrumbs[0], 'Erkek');
      expect(breadcrumbs[1], 'Giyim');
      expect(breadcrumbs[2], 'Pantolon');

      // Verify category matching on joined breadcrumbs
      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'moda');
      expect(categoryResult['subCategory'], 'Erkek Giyim');
    });

    test('2. DOM Fallback parsing if JSON-LD is missing', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="defacto-breadcrumb">
    <a href="/kiz-cocuk">Kız Çocuk</a>
    <a href="/mont">Mont</a>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Kız Çocuk');
      expect(breadcrumbs[1], 'Mont');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'moda');
      expect(categoryResult['subCategory'], 'Çocuk Giyim');
    });
  });

  group('Amazon Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = AmazonScraper();

    test('1. Parse active nav link from nav-subnav', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div id="nav-subnav" data-category="electronics">
    <ul class="subnav-ul">
      <li class="subnav-li ">
        <div class="subnav-div">
          <a href="/bilgisayar" class="nav-a nav-b">
            <span class="nav-a-content">Dizüstü Bilgisayar</span>
          </a>
        </div>
      </li>
    </ul>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 1);
      expect(breadcrumbs[0], 'Dizüstü Bilgisayar');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Bilgisayar & Tablet');
    });

    test('2. Parse wayfinding breadcrumbs', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div id="wayfinding-breadcrumbs_feature_div">
    <ul class="a-unordered-list a-horizontal">
      <li><span class="a-list-item"><a class="a-link-normal" href="#">Elektronik</a></span></li>
      <li><span class="a-list-item"><a class="a-link-normal" href="#">Cep Telefonları ve Aksesuarlar</a></span></li>
    </ul>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Elektronik');
      expect(breadcrumbs[1], 'Cep Telefonları ve Aksesuarlar');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Telefon & Aksesuarları');
    });
  });

  group('N11 Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = N11Scraper();

    test('1. Parse breadcrumbs from DOM', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="breadcrumb-group">
    <div class="breadcrumb">
      <a href="/" title="Homepage"></a>
      <div class="horizontal-overflow">
        <div class="horizontal-overflow__body">
          <ul>
            <li class="breadcrumb-item"><a href="/kozmetik" title="Kozmetik &amp; Kişisel Bakım">Kozmetik &amp; Kişisel Bakım</a></li>
            <li class="breadcrumb-item"><a href="/cilt" title="Cilt Bakımı">Cilt Bakımı</a></li>
            <li class="breadcrumb-item"><a href="/gunes" title="Güneş &amp; Bronzluk Ürünleri">Güneş &amp; Bronzluk Ürünleri</a></li>
            <li class="breadcrumb-item"><a href="/kremler" title="Güneş Kremleri">Güneş Kremleri</a></li>
            <li class="breadcrumb-item">
              <a href="/marka" title="Nivea Güneş Kremleri">Nivea Güneş Kremleri</a>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 5);
      expect(breadcrumbs[0], 'Kozmetik & Kişisel Bakım');
      expect(breadcrumbs[1], 'Cilt Bakımı');
      expect(breadcrumbs[2], 'Güneş & Bronzluk Ürünleri');
      expect(breadcrumbs[3], 'Güneş Kremleri');
      expect(breadcrumbs[4], 'Nivea Güneş Kremleri');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'kozmetik');
      expect(categoryResult['subCategory'], 'Cilt & Yüz Bakımı');
    });
  });

  group('Incehesap Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = IncehesapScraper();

    test('1. Parse microdata breadcrumbs from DOM', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <nav itemscope="" itemtype="https://schema.org/BreadcrumbList" class="container flex relative">
    <div itemprop="itemListElement" itemscope="" itemtype="https://schema.org/ListItem">
      <a href="/" itemprop="item">
        <span itemprop="name">Ana Sayfa</span>
      </a>
      <meta itemprop="position" content="1">
    </div>
    <div itemprop="itemListElement" itemscope="" itemtype="https://schema.org/ListItem" class="flex">
      <a itemprop="item" href="/bilgisayar-tablet-fiyatlari/">
        <span itemprop="name">Bilgisayar</span>
      </a>
      <meta itemprop="position" content="2">
    </div>
    <div itemprop="itemListElement" itemscope="" itemtype="https://schema.org/ListItem" class="flex">
      <a itemprop="item" href="/pc-bilgisayar-fiyatlari/">
        <span itemprop="name">PC Bilgisayar</span>
      </a>
      <meta itemprop="position" content="3">
    </div>
    <div itemprop="itemListElement" itemscope="" itemtype="https://schema.org/ListItem" class="flex">
      <a itemprop="item" href="/mini-pc-fiyatlari/">
        <span itemprop="name">Mini PC</span>
      </a>
      <meta itemprop="position" content="4">
    </div>
  </nav>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 3);
      expect(breadcrumbs[0], 'Bilgisayar');
      expect(breadcrumbs[1], 'PC Bilgisayar');
      expect(breadcrumbs[2], 'Mini PC');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'elektronik');
      expect(categoryResult['subCategory'], 'Bilgisayar & Tablet');
    });
  });

  group('Mango Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = MangoScraper();

    test('1. Parse microdata breadcrumbs from DOM', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <ol class="BreadcrumbBase-module__BI6n-W__list" itemtype="https://schema.org/BreadcrumbList" itemscope="">
    <li itemscope="" itemprop="itemListElement" itemtype="https://schema.org/ListItem" class="BreadcrumbBase-module__BI6n-W__listItem">
      <a class="SiteCrumb-module" href="/tr/tr/h/erkek" itemprop="item">
        <span class="text"><span itemprop="name">Erkek</span></span>
      </a>
      <meta itemprop="position" content="1">
    </li>
    <li itemscope="" itemprop="itemListElement" itemtype="https://schema.org/ListItem" class="BreadcrumbBase-module__BI6n-W__listItem">
      <a class="SiteCrumb-module" href="/tr/tr/c/erkek/pantolon" itemprop="item">
        <span class="text"><span itemprop="name">Pantolon</span></span>
      </a>
      <meta itemprop="position" content="2">
    </li>
  </ol>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Erkek');
      expect(breadcrumbs[1], 'Pantolon');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'moda');
      expect(categoryResult['subCategory'], 'Erkek Giyim');
    });
  });

  group('Beymen Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = BeymenScraper();

    test('1. Parse microdata breadcrumbs from DOM', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <div class="o-productDetail__description">Linden Anthracite Small Yan Sehpa</div>
  <div id="breadcrumb" class="m-breadcrumb">
    <ol itemscope="itemscope" itemtype="http://schema.org/BreadcrumbList">
      <li itemprop="itemListElement" itemscope="itemscope" itemtype="http://schema.org/ListItem">
        <a itemprop="item" href="https://www.beymen.com/tr">
          <span itemprop="name">Ana Sayfa</span>
        </a>
        <meta itemprop="position" content="1">
      </li>
      <li itemprop="itemListElement" itemscope="itemscope" itemtype="http://schema.org/ListItem">
        <a itemprop="item" href="/tr/ev-mobilya-96069">
          <span itemprop="name">Ev &amp; Yaşam</span>
        </a>
        <meta itemprop="position" content="2">
      </li>
      <li itemprop="itemListElement" itemscope="itemscope" itemtype="http://schema.org/ListItem">
        <a itemprop="item" href="/tr/mobilya-96080">
          <span itemprop="name">Mobilya</span>
        </a>
        <meta itemprop="position" content="3">
      </li>
      <li itemprop="itemListElement" itemscope="itemscope" itemtype="http://schema.org/ListItem">
        <span itemprop="name">Linden Anthracite Small Yan Sehpa</span>
        <meta itemprop="position" content="4">
      </li>
    </ol>
  </div>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'Ev & Yaşam');
      expect(breadcrumbs[1], 'Mobilya');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'ev_yasam');
      expect(categoryResult['subCategory'], 'Mobilya');
    });
  });

  group('Zara Scraper Category & Breadcrumb Detection Tests', () {
    final scraper = ZaraScraper();

    test('1. Parse intermediate breadcrumbs from DOM', () {
      final html = '''
<!DOCTYPE html>
<html>
<body>
  <h1 class="product-detail-info__header-name">SOYUT DESENLİ DÖKÜMLÜ GÖMLEK</h1>
  <ol class="layout-footer-breadcrumbs__items" itemscope="" itemtype="https://schema.org/BreadcrumbList">
    <li class="layout-footer-breadcrumbs__item" itemprop="ItemListElement" itemscope="" itemtype="https://schema.org/ListItem">
      <a class="layout-footer-breadcrumbs__link link" href="https://www.zara.com/" itemprop="item">
        <span itemprop="name">ZARA</span>
      </a>
      <meta content="1" itemprop="position">
    </li>
    <li class="layout-footer-breadcrumbs__item" itemprop="ItemListElement" itemscope="" itemtype="https://schema.org/ListItem">
      <a class="layout-footer-breadcrumbs__link link" href="/tr/tr/woman" itemprop="item">
        <span itemprop="name">KADIN</span>
      </a>
      <meta content="2" itemprop="position">
    </li>
    <li class="layout-footer-breadcrumbs__item" itemprop="ItemListElement" itemscope="" itemtype="https://schema.org/ListItem">
      <a class="layout-footer-breadcrumbs__link link" href="/tr/tr/woman-shirts" itemprop="item">
        <span itemprop="name">GÖMLEK</span>
      </a>
      <meta content="3" itemprop="position">
    </li>
    <li class="layout-footer-breadcrumbs__item" itemprop="ItemListElement" itemscope="" itemtype="https://schema.org/ListItem">
      <span itemprop="name">SOYUT DESENLİ DÖKÜMLÜ GÖMLEK</span>
      <meta content="4" itemprop="position">
    </li>
  </ol>
</body>
</html>
''';

      final document = html_parser.parse(html);
      final breadcrumbs = scraper.scrapeBreadcrumbs(document);

      expect(breadcrumbs, isNotNull);
      expect(breadcrumbs.length, 2);
      expect(breadcrumbs[0], 'KADIN');
      expect(breadcrumbs[1], 'GÖMLEK');

      final joined = breadcrumbs.join(' ');
      final categoryResult = CategoryDetectionService.detectCategory(joined);
      expect(categoryResult, isNotNull);
      expect(categoryResult!['categoryId'], 'moda');
      expect(categoryResult['subCategory'], 'Kadın Giyim');
    });
  });
}
