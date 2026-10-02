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
    // 1. og:image meta tag (media.mango.com / st.mngbcn.com)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                    document.querySelector('meta[name="twitter:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Mango görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 2. Modern DOM Seçicileri (ZoomableImage / product gallery)
    final imgSelectors = [
      'button[class*="ZoomableImage"] img',
      'img[class*="ZoomableImage"]',
      'img[src*="media.mango.com"]',
      'img[src*="st.mngbcn.com"]',
      '.product-image img',
      'img[class*="product"]',
      'main img',
    ];
    for (final selector in imgSelectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
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

    // 3. Fallback: URL içindeki ürün kodu ve renk kodundan deterministik CDN görseli üretimi
    // Örn: https://shop.mango.com/tr/tr/p/37081422/95/00 -> 37081422 ve 95
    final match = RegExp(r'/(3\d{7})/(\d{2})').firstMatch(url);
    if (match != null) {
      final productId = match.group(1);
      final colorId = match.group(2);
      final cdnUrl = 'https://st.mngbcn.com/rcs/pics/static/T3/fotos/S/${productId}_$colorId.jpg';
      log('✅ Mango görseli URL deseninden üretildi: $cdnUrl');
      return cdnUrl;
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. og:title / title meta tag
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'] ??
                    document.querySelector('title')?.text;
    if (ogTitle != null && ogTitle.isNotEmpty && ogTitle.toLowerCase() != 'null') {
      final cleaned = ogTitle
          .replaceAll(RegExp(r'\s*\|\s*MANGO.*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*MANGO.*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*(?:Erkek|Kadın|Çocuk|Teen|Home|Baby|Bebek).*$', caseSensitive: false), '')
          .trim();
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    // 2. DOM h1 / product-name
    final titleEl = document.querySelector('h1') ?? 
                    document.querySelector('[class*="ProductDetail"] h1') ??
                    document.querySelector('.product-name');
    if (titleEl != null && titleEl.text.trim().isNotEmpty) {
      return titleEl.text.trim();
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Yeni Mango CSS Sınıfı: [class*="SinglePrice"][class*="discounted"] veya [class*="discounted"]
    final discountedEl = document.querySelector('[class*="SinglePrice"][class*="discounted"]') ??
                         document.querySelector('span[class*="discounted"]');
    if (discountedEl != null) {
      final val = parsePriceText(discountedEl.text);
      if (val != null && val > 0) return val;
    }

    // 2. Yeni Mango DOM: "Güncel fiyat [2.299,99 TL ]" sr-only seçicisi
    final srOnlyElements = document.querySelectorAll('span[class*="srOnly"], span[class*="sr-only"]');
    final guncelRegex = RegExp(r'Güncel\s+fiyat\s*\[?([0-9.,]+)\s*TL', caseSensitive: false);
    for (final el in srOnlyElements) {
      final match = guncelRegex.firstMatch(el.text);
      if (match != null && match.group(1) != null) {
        final val = parsePriceText(match.group(1)!);
        if (val != null && val > 0) return val;
      }
    }

    // 3. Schema.org Offer (İndirimli ürün teklifi)
    final offerElements = document.querySelectorAll('[itemprop="offers"]');
    for (final offer in offerElements) {
      final isDiscounted = offer.querySelector('[class*="discounted"]') != null;
      if (isDiscounted) {
        final priceMeta = offer.querySelector('meta[itemprop="price"]')?.attributes['content'];
        if (priceMeta != null) {
          final val = double.tryParse(priceMeta);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 4. İndirimsiz tek fiyatlı ürünler için Schema.org Offer fiyatı (crossed yoksa)
    for (final offer in offerElements) {
      final isCrossed = offer.querySelector('[class*="crossed"]') != null;
      if (!isCrossed) {
        final priceMeta = offer.querySelector('meta[itemprop="price"]')?.attributes['content'];
        if (priceMeta != null) {
          final val = double.tryParse(priceMeta);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 5. DOM finalPrice (Eski sürüm uyumluluğu)
    final finalPriceEl = document.querySelector('span[class*="finalPrice"]') ??
                         document.querySelector('[class*="SinglePrice"][class*="finalPrice"]');
    if (finalPriceEl != null) {
      final val = parsePriceText(finalPriceEl.text);
      if (val != null && val > 0) return val;
    }

    // 6. Next.js script push data (Eski sayfa uyumluluğu)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('price')) {
        final match = RegExp(r'\\?"price\\?"\s*:\s*\{\s*\\?"amount\\?"\s*:\s*([0-9.]+)').firstMatch(text) ??
                      RegExp(r'\\?"price\\?"\s*:\s*\\?"?([0-9.]+)\\?"?').firstMatch(text);
        if (match != null && match.group(1) != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 7. JSON-LD şemasından (Fallback)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceVal = extractPriceFromProductJson(productJson);
      if (priceVal != null && priceVal > 0) {
        return priceVal;
      }
    }

    // 8. Genel DOM Seçicileri (Fallback)
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

    // 1. Yeni Mango CSS Sınıfı: [class*="SinglePrice"][class*="crossed"] veya [class*="crossed"]
    final crossedEl = document.querySelector('[class*="SinglePrice"][class*="crossed"]') ??
                      document.querySelector('span[class*="crossed"]');
    if (crossedEl != null) {
      final val = parsePriceText(crossedEl.text);
      if (val != null && val > currentPrice) return val;
    }

    // 2. Yeni Mango DOM: "Üstü çizili ilk fiyat [2.999,99 TL ]" sr-only seçicisi
    final srOnlyElements = document.querySelectorAll('span[class*="srOnly"], span[class*="sr-only"]');
    final crossedRegex = RegExp(r'Üstü\s+çizili\s+ilk\s+fiyat\s*\[?([0-9.,]+)\s*TL', caseSensitive: false);
    for (final el in srOnlyElements) {
      final match = crossedRegex.firstMatch(el.text);
      if (match != null && match.group(1) != null) {
        final val = parsePriceText(match.group(1)!);
        if (val != null && val > currentPrice) return val;
      }
    }

    // 3. Schema.org Offer (Üstü çizili / ilk fiyat meta etiketi)
    final offerElements = document.querySelectorAll('[itemprop="offers"]');
    for (final offer in offerElements) {
      final isCrossed = offer.querySelector('[class*="crossed"]') != null;
      if (isCrossed) {
        final priceMeta = offer.querySelector('meta[itemprop="price"]')?.attributes['content'];
        if (priceMeta != null) {
          final val = double.tryParse(priceMeta);
          if (val != null && val > currentPrice) return val;
        }
      }
    }

    // 4. Next.js script crossedOutPrices (Eski sayfa uyumluluğu)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('crossedOutPrices')) {
        final match = RegExp(r'\\?"crossedOutPrices\\?"\s*:\s*\[\{\s*\\?"amount\\?"\s*:\s*([0-9.]+)').firstMatch(text);
        if (match != null && match.group(1) != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null && val > currentPrice) return val;
        }
      }
    }

    // 5. Fallback etiketleri (del, s, .old-price vb.)
    final candidates = <double>[];
    final selectors = [
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
    final descEl = document.querySelector('meta[property="og:description"]') ?? 
                   document.querySelector('meta[name="description"]');
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
