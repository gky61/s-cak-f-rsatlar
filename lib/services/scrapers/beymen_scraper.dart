import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class BeymenScraper extends BaseProductScraper {
  @override
  String get domain => 'beymen.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('beymen.com');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. JSON-LD şemasından görsel çekmeyi dene (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['image'] != null) {
      final imgLd = extractImageFromProductJson(productJson['image']);
      if (imgLd != null && imgLd.isNotEmpty) {
        final resolved = resolveImageUrl(imgLd, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Beymen görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Beymen görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgElements = document.querySelectorAll('.product-detail-images img, img[class*="product"]');
    for (final img in imgElements) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Beymen görseli img etiketiyle bulundu: $resolved');
          return resolved;
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. Önce DOM seçicisini deneyelim çünkü HTML içerisinde inç (" gibi) işaretleri olsa dahi en temiz haliyle buradadır.
    final titleEl = document.querySelector('.o-productDetail__description');
    if (titleEl != null && titleEl.text.trim().isNotEmpty) {
      return titleEl.text.trim();
    }

    // 2. Script BEYMEN.productMain displayName eşleşmesini dene
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('BEYMEN.productMain')) {
        final match = RegExp(r'"displayName"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(text);
        if (match != null) {
          return match.group(1)!.replaceAll('\\"', '"').trim();
        }
      }
    }

    // 3. JSON-LD şemasından (Fallback 1)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      return productJson['name'].toString().trim();
    }

    // 4. Genel H1 (Fallback 2)
    final h1El = document.querySelector('h1.o-productDetail__title') ??
                 document.querySelector('h1');
    if (h1El != null) {
      return h1El.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. DOM Campaign / Sepette price (Öncelikli)
    final campaignPriceEl = document.querySelector('.m-price__campaignPrice') ??
                            document.querySelector('[id="priceCampaign"]');
    if (campaignPriceEl != null) {
      final val = parsePriceText(campaignPriceEl.text);
      if (val != null && val > 0) return val;
    }

    // 2. DOM Last Price (Son İndirimli / Ek İndirimli Fiyat - Örn: Dolce & Gabbana 44.195 TL)
    final lastPriceEl = document.querySelector('.m-price__lastPrice');
    if (lastPriceEl != null) {
      final val = parsePriceText(lastPriceEl.text);
      if (val != null && val > 0) return val;
    }

    // 3. DOM New price
    final newPriceEl = document.querySelector('ins.m-price__new') ??
                       document.querySelector('.m-price__new') ??
                       document.querySelector('[id="priceNew"]');
    if (newPriceEl != null) {
      final val = parsePriceText(newPriceEl.text);
      if (val != null && val > 0) return val;
    }

    // 4. Script BEYMEN.productMain promotedOrActualPrice
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('BEYMEN.productMain')) {
        final match = RegExp(r'"promotedOrActualPrice"\s*:\s*([0-9.]+)').firstMatch(text) ??
                      RegExp(r'"actualPrice"\s*:\s*([0-9.]+)').firstMatch(text);
        if (match != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 5. JSON-LD şemasından
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    // 6. DOM campaign/discount/Visa prices fallback
    final priceSelectors = [
      '.m-price__campaignPrice',
      '.m-price__lastPrice',
      'ins.m-price__new',
      '.m-price__new',
      '.m-productDetail__newPrice',
      '.o-productDetail__price',
    ];
    double? lowestPrice;
    for (final selector in priceSelectors) {
      final priceEl = document.querySelector(selector);
      if (priceEl != null) {
        final val = parsePriceText(priceEl.text);
        if (val != null && val > 0) {
          if (lowestPrice == null || val < lowestPrice) {
            lowestPrice = val;
          }
        }
      }
    }

    return lowestPrice;
  }

  @override
  double? scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    // 1. DOM old strikethrough price (.m-price__old, del.m-price__old)
    final oldPriceEl = document.querySelector('.m-price__old') ??
                       document.querySelector('del.m-price__old') ??
                       document.querySelector('[id="priceOld"]');
    if (oldPriceEl != null) {
      final val = parsePriceText(oldPriceEl.text);
      if (val != null && val > currentPrice) return val;
    }

    // 2. DOM .m-price__new (Eğer kampanya veya lastPrice fiyatı varsa, normal satış fiyatı .m-price__new üzerindedir)
    final newPriceEl = document.querySelector('ins.m-price__new') ??
                       document.querySelector('.m-price__new') ??
                       document.querySelector('[id="priceNew"]');
    if (newPriceEl != null) {
      final val = parsePriceText(newPriceEl.text);
      if (val != null && val > currentPrice) return val;
    }

    // 3. DOM .m-price__lastPrice (Eğer kampanya fiyatı varsa, ara indirimli fiyat .m-price__lastPrice üzerindedir)
    final lastPriceEl = document.querySelector('.m-price__lastPrice');
    if (lastPriceEl != null) {
      final val = parsePriceText(lastPriceEl.text);
      if (val != null && val > currentPrice) return val;
    }

    // 4. Script BEYMEN.productMain strikeThroughPrice veya actualPrice
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('BEYMEN.productMain')) {
        final strikeMatch = RegExp(r'"strikeThroughPriceText"\s*:\s*"([^"]+)"').firstMatch(text);
        if (strikeMatch != null) {
          final val = parsePriceText(strikeMatch.group(1)!);
          if (val != null && val > currentPrice) return val;
        }

        final actualMatch = RegExp(r'"actualPriceText"\s*:\s*"([^"]+)"').firstMatch(text);
        if (actualMatch != null) {
          final val = parsePriceText(actualMatch.group(1)!);
          if (val != null && val > currentPrice) return val;
        }
      }
    }

    // 5. Fallback selectors
    final candidates = <double>[];
    final selectors = [
      '.m-price__old',
      '.m-price__new',
      '.m-price__lastPrice',
      'del',
      's',
      '.old-price',
      '.original-price',
    ];
    for (final selector in selectors) {
      for (final el in document.querySelectorAll(selector)) {
        final txt = el.text.trim();
        if (txt.contains('TL') || txt.contains('₺')) {
          final parsed = parsePriceText(txt);
          if (parsed != null && parsed > currentPrice && parsed <= currentPrice * 5) {
            candidates.add(parsed);
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      return productJson['description'].toString().trim();
    }

    // 2. og:description veya description meta tag
    final descEl = document.querySelector('meta[name="description"]') ?? 
                   document.querySelector('meta[property="og:description"]');
    if (descEl != null) {
      final content = descEl.attributes['content']?.trim();
      if (content != null && content.isNotEmpty && content.toLowerCase() != 'null') {
        return content;
      }
    }
    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final productTitle = scrapeTitle(document) ?? '';

    // 1. Microdata / Schema.org BreadcrumbList
    final breadcrumbElements = document.querySelectorAll(
      '[itemprop="itemListElement"] [itemprop="name"], '
      'ol[itemtype*="BreadcrumbList"] span[itemprop="name"], '
      'ol[itemtype*="BreadcrumbList"] [itemprop="name"], '
      '[itemtype*="BreadcrumbList"] [itemprop="name"], '
      '#breadcrumb [itemprop="name"], '
      '.m-breadcrumb [itemprop="name"]'
    );

    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('beymen') && lower != productTitle.toLowerCase().trim() && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    // 2. DOM Fallback
    final fallbackElements = document.querySelectorAll('.breadcrumb a, .breadcrumbs a, .breadcrumb-item a, nav a, ol li a');
    if (fallbackElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in fallbackElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('beymen') && lower != productTitle.toLowerCase().trim() && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }
}
