import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class MediaMarktScraper extends BaseProductScraper {
  @override
  String get domain => 'mediamarkt.com.tr';

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
      if (imgLd != null && imgLd.isNotEmpty && !isLogoUrl(imgLd)) {
        final resolved = resolveImageUrl(imgLd, url);
        if (resolved != null) {
          log('✅ MediaMarkt JSON-LD görseli bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph görseli (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                    document.querySelector('meta[name="og:image"]')?.attributes['content'];
                    
    if (ogImage != null && ogImage.isNotEmpty && !isLogoUrl(ogImage)) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null) {
        log('✅ MediaMarkt özel og:image görseli bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final mediaMarktSelectors = [
      'img[data-testid="product-image"]',
      '#product-image img',
      'img.product-image',
      '.product-details img',
    ];
    for (final selector in mediaMarktSelectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final src = element.attributes['src'] ?? element.attributes['data-src'] ?? element.attributes['data-lazy-src'];
        if (src != null && src.isNotEmpty && !src.startsWith('data:') && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ MediaMarkt özel görseli bulundu: $resolved');
            return resolved;
          }
        }
      }
    }
    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      return productJson['name'].toString().trim();
    }

    // 2. DOM Seçicileri (Fallback)
    final titleEl = document.querySelector('h1[class*="mms-ui-"]') ??
                    document.querySelector('h1') ??
                    document.querySelector('meta[property="og:title"]');
    if (titleEl != null) {
      if (titleEl.localName == 'meta') {
        return titleEl.attributes['content']?.trim();
      }
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceVal = extractPriceFromProductJson(productJson);
      if (priceVal != null && priceVal > 0) {
        return priceVal;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final priceEl = document.querySelector('[data-test="branded-price-whole-value"]') ??
                    document.querySelector('meta[property="product:price:amount"]') ??
                    document.querySelector('meta[property="og:price:amount"]');
                    
    if (priceEl != null) {
      if (priceEl.localName == 'meta') {
        return parsePriceText(priceEl.attributes['content'] ?? '');
      }
      return parsePriceText(priceEl.text);
    }
    return null;
  }
}
