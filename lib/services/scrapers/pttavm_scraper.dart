import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class PttavmScraper extends BaseProductScraper {
  @override
  String get domain => 'pttavm.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('pttavm.com');
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
          log('✅ Pttavm görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Pttavm görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgSelectors = [
      '.product-detail-images img',
      '.product-images img',
      'img[class*="product"]',
      '#product-image',
    ];
    for (final selector in imgSelectors) {
      final imgElements = document.querySelectorAll(selector);
      for (final img in imgElements) {
        final src = img.attributes['src'] ?? img.attributes['data-src'];
        if (src != null && src.isNotEmpty) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null && !isLogoUrl(resolved)) {
            log('✅ Pttavm görseli img etiketiyle bulundu ($selector): $resolved');
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
    final titleEl = document.querySelector('h1.product-title') ??
                    document.querySelector('.product-name') ??
                    document.querySelector('meta[property="og:title"]');
    if (titleEl != null) {
      if (titleEl is dom.Element && titleEl.localName == 'meta') {
        return titleEl.attributes['content']?.trim();
      }
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. JSON-LD şemasından fiyat çekmeyi dene (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final priceSelectors = [
      '.product-price',
      '.price-box',
      '.discount-price',
      '.current-price',
    ];
    for (final selector in priceSelectors) {
      final priceEl = document.querySelector(selector);
      if (priceEl != null) {
        final val = parsePriceText(priceEl.text);
        if (val != null && val > 0) {
          return val;
        }
      }
    }

    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      final desc = productJson['description'].toString().trim();
      if (desc.isNotEmpty && desc.toLowerCase() != 'null') {
        return desc;
      }
    }

    // 2. Özel DOM tag (data-rh="true" name="description")
    final rhDescEl = document.querySelector('meta[data-rh="true"][name="description"]');
    if (rhDescEl != null) {
      final content = rhDescEl.attributes['content']?.trim();
      if (content != null && content.isNotEmpty && content.toLowerCase() != 'null') {
        return content;
      }
    }

    // 3. Genel og:description veya description meta tag
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
}
