import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class MangoScraper extends BaseProductScraper {
  @override
  String get domain => 'mango.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('mango.com');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. og:image meta tag (En güvenli ve net)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                    document.querySelector('meta[name="twitter:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Mango görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final imgSelectors = [
      '.product-image img',
      'img[class*="product"]',
      'main img',
    ];
    for (final selector in imgSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final src = element.attributes['src'] ?? element.attributes['data-src'];
        if (src != null && src.isNotEmpty && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ Mango görseli DOM ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. DOM h1 (Varsa en yalın ürün adıdır)
    final titleEl = document.querySelector('h1') ?? 
                    document.querySelector('.product-name');
    if (titleEl != null && titleEl.text.trim().isNotEmpty) {
      return titleEl.text.trim();
    }

    // 2. og:title meta tag (Next.js server-side render eder)
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'] ??
                    document.querySelector('title')?.text;
    if (ogTitle != null && ogTitle.isNotEmpty && ogTitle.toLowerCase() != 'null') {
      return ogTitle
          .replaceAll(RegExp(r'\s*\|\s*MANGO.*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*MANGO.*$', caseSensitive: false), '')
          .trim();
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. DOM finalPrice (İndirimli yeni fiyat)
    final finalPriceEl = document.querySelector('span[class*="finalPrice"]') ??
                         document.querySelector('[class*="SinglePrice"][class*="finalPrice"]');
    if (finalPriceEl != null) {
      final val = parsePriceText(finalPriceEl.text);
      if (val != null && val > 0) return val;
    }

    // 2. Next.js script push data
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('price')) {
        final match = RegExp(r'\\?"price\\?"\s*:\s*\{\s*\\?"amount\\?"\s*:\s*([0-9.]+)').firstMatch(text) ??
                      RegExp(r'\\?"price\\?"\s*:\s*\\?"?([0-9.]+)\\?"?').firstMatch(text);
        if (match != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 3. JSON-LD şemasından
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceVal = extractPriceFromProductJson(productJson);
      if (priceVal != null && priceVal > 0) {
        return priceVal;
      }
    }

    // 4. DOM Seçicileri (Fallback)
    final priceSelectors = [
      '[data-testid="pdp.productInfo.price"]',
      '.pdp-price',
      '.product-price',
      'span[class*="price"]',
    ];
    for (final selector in priceSelectors) {
      final priceEl = document.querySelector(selector);
      if (priceEl != null) {
        final parsed = parsePriceText(priceEl.text);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    return null;
  }

  @override
  double? scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    // 1. DOM crossed out price (İndirimsiz çizili fiyat)
    final crossedEl = document.querySelector('span[class*="crossed"]') ??
                      document.querySelector('[class*="SinglePrice"][class*="crossed"]');
    if (crossedEl != null) {
      final val = parsePriceText(crossedEl.text);
      if (val != null && val > currentPrice) return val;
    }

    // 2. Next.js script crossedOutPrices
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('crossedOutPrices')) {
        final match = RegExp(r'\\?"crossedOutPrices\\?"\s*:\s*\[\{\s*\\?"amount\\?"\s*:\s*([0-9.]+)').firstMatch(text);
        if (match != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null && val > currentPrice) return val;
        }
      }
    }

    // 3. Fallback selectors
    final candidates = <double>[];
    final selectors = [
      'span[class*="crossed"]',
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
    // 1. og:description veya description meta tag
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
      '[itemtype*="BreadcrumbList"] [itemprop="name"]'
    );

    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('mango') && lower != productTitle.toLowerCase().trim() && text.length < 50) {
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
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('mango') && lower != productTitle.toLowerCase().trim() && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }
}
