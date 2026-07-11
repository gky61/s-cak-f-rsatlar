import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class ZaraScraper extends BaseProductScraper {
  @override
  String get domain => 'zara.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('zara.com');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. og:image meta etiketi (En yüksek öncelikli ve en güvenli)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                    document.querySelector('meta[name="twitter:image"]')?.attributes['content'] ??
                    document.querySelector('link[rel="image_src"]')?.attributes['href'];
    if (ogImage != null && ogImage.isNotEmpty && ogImage.toLowerCase() != 'null') {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Zara görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 2. Script bloğu içinden regex ile görsel ara
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('image') || text.contains('contentUrl')) {
        // hasVariant veya genel image dizisindeki ilk resmi bul
        final imgMatch = RegExp(r'"image"\s*:\s*\[\s*"([^"]+)"').firstMatch(text) ??
                         RegExp(r'"contentUrl"\s*:\s*"([^"]+)"').firstMatch(text);
        if (imgMatch != null) {
          final imgStr = imgMatch.group(1);
          final resolved = resolveImageUrl(imgStr, url);
          if (resolved != null && !isLogoUrl(resolved)) {
            log('✅ Zara görseli Script regex ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    // 3. DOM Seçicileri (Fallback)
    final imgSelectors = [
      '.media-image__image',
      '.product-detail-images img',
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
            log('✅ Zara görseli DOM ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. DOM Başlık etiketi (Zara canlı sayfada h1.product-detail-info__header-name kullanır)
    final titleEl = document.querySelector('h1.product-detail-info__header-name') ?? 
                    document.querySelector('.product-name') ?? 
                    document.querySelector('h1');
    if (titleEl != null) {
      final text = titleEl.text.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    // 2. og:title meta etiketi
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (ogTitle != null && ogTitle.isNotEmpty && ogTitle.toLowerCase() != 'null') {
      return ogTitle.trim();
    }

    // 3. Script bloğu regex araması
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('productName') || text.contains('name')) {
        final match = RegExp(r'"productName"\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final val = match.group(1);
          if (val != null && val.isNotEmpty && val.toLowerCase() != 'null') {
            return val.trim();
          }
        }
      }
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Script bloğu regex aramaları (Tüm script varyasyonları için ortak ve güvenli)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      
      // A) mainPrice (analyticsData script bloğu)
      final mainPriceMatch = RegExp(r'"mainPrice"\s*:\s*([0-9.]+)').firstMatch(text);
      if (mainPriceMatch != null) {
        final val = double.tryParse(mainPriceMatch.group(1)!);
        if (val != null && val > 0) return val;
      }

      // B) Offers içindeki price (JSON-LD script bloğu)
      final priceMatch = RegExp(r'"price"\s*:\s*"([0-9.]+)"').firstMatch(text) ??
                         RegExp(r'"price"\s*:\s*([0-9.]+)').firstMatch(text);
      if (priceMatch != null) {
        final val = double.tryParse(priceMatch.group(1)!);
        if (val != null && val > 0) return val;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final priceSelectors = [
      '.price-current__amount',
      '.price__amount',
      '.price',
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
  String? scrapeDescription(dom.Document document) {
    // 1. DOM meta description
    final descEl = document.querySelector('meta[name="description"]') ?? 
                   document.querySelector('meta[property="og:description"]');
    if (descEl != null) {
      final content = descEl.attributes['content']?.trim();
      if (content != null && content.isNotEmpty && content.toLowerCase() != 'null') {
        return content;
      }
    }

    // 2. Script bloğu regex araması
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('description')) {
        final match = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final val = match.group(1);
          if (val != null && val.isNotEmpty && val.toLowerCase() != 'null') {
            return val.replaceAll(r'\n', '\n').trim();
          }
        }
      }
    }

    return null;
  }
}
