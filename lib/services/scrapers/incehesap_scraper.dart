import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class IncehesapScraper extends BaseProductScraper {
  @override
  String get domain => 'incehesap.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('incehesap.com');
  }

  Map<String, dynamic>? _findDataLayerEcommerce(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('window.dataLayer.push(') && text.contains('ecommerce') && text.contains('items')) {
        try {
          final match = RegExp(r'window\.dataLayer\.push\((.*?)\);', dotAll: true).firstMatch(text);
          if (match != null) {
            final jsonStr = match.group(1)!.trim();
            final decoded = jsonDecode(jsonStr);
            if (decoded is Map && decoded['ecommerce'] != null) {
              return Map<String, dynamic>.from(decoded['ecommerce']);
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. dataLayer şemasından görsel çekmeyi dene (Öncelikli)
    final ecommerce = _findDataLayerEcommerce(document);
    if (ecommerce != null && ecommerce['items'] is List) {
      final items = ecommerce['items'] as List;
      if (items.isNotEmpty && items.first is Map) {
        final imgUrl = items.first['image']?.toString();
        if (imgUrl != null && imgUrl.isNotEmpty) {
          final resolved = resolveImageUrl(imgUrl, url);
          if (resolved != null && !isLogoUrl(resolved)) {
            log('✅ İncehesap görseli dataLayer ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ İncehesap görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgSelectors = [
      '.product-image img',
      '.product-detail img',
      '#product-gallery img',
      'img[class*="product"]',
    ];
    for (final selector in imgSelectors) {
      final imgElements = document.querySelectorAll(selector);
      for (final img in imgElements) {
        final src = img.attributes['src'] ?? img.attributes['data-src'];
        if (src != null && src.isNotEmpty) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null && !isLogoUrl(resolved)) {
            log('✅ İncehesap görseli img etiketiyle bulundu ($selector): $resolved');
            return resolved;
          }
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. dataLayer şemasından (Öncelikli)
    final ecommerce = _findDataLayerEcommerce(document);
    if (ecommerce != null && ecommerce['items'] is List) {
      final items = ecommerce['items'] as List;
      if (items.isNotEmpty && items.first is Map) {
        final title = items.first['item_name']?.toString().trim();
        if (title != null && title.isNotEmpty) {
          return title;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final titleEl = document.querySelector('h1.product-title') ??
                    document.querySelector('.product-name') ??
                    document.querySelector('h1') ??
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
    // Sepette indirim etiketi var mı kontrol et
    final hasBasketDiscount = document.querySelector('.basketdiscount-label-detail') != null;

    if (hasBasketDiscount) {
      // Sepette indirim varsa fiyatı doğrudan DOM'dan çek
      final priceEl = document.querySelector('div.price') ??
                      document.querySelector('.price') ??
                      document.querySelector('[class*="price"]');
      if (priceEl != null) {
        final val = parsePriceText(priceEl.text);
        if (val != null && val > 0) {
          return val;
        }
      }
    }

    // Sepette indirim yoksa veya DOM'dan çekilemediyse, dataLayer şemasından çekmeyi dene
    final ecommerce = _findDataLayerEcommerce(document);
    if (ecommerce != null) {
      final items = ecommerce['items'];
      if (items is List && items.isNotEmpty && items.first is Map) {
        final priceVal = items.first['price'];
        if (priceVal != null) {
          final val = double.tryParse(priceVal.toString());
          if (val != null && val > 0) return val;
        }
      }
      
      final valueVal = ecommerce['value'];
      if (valueVal != null) {
        final val = double.tryParse(valueVal.toString());
        if (val != null && val > 0) return val;
      }
    }

    // Fallback: dataLayer'da yoksa ve yukarıda çekilmediyse normal fiyat etiketini DOM'dan çek
    final priceEl = document.querySelector('div.price') ??
                    document.querySelector('.price') ??
                    document.querySelector('[class*="price"]');
    if (priceEl != null) {
      final val = parsePriceText(priceEl.text);
      if (val != null && val > 0) {
        return val;
      }
    }

    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
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
      'nav[itemtype*="BreadcrumbList"] span[itemprop="name"], '
      'nav[itemtype*="BreadcrumbList"] [itemprop="name"]'
    );

    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('incehesap') && lower != productTitle.toLowerCase().trim() && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    // 2. DOM Fallback
    final fallbackElements = document.querySelectorAll('.breadcrumb a, .breadcrumbs a, .breadcrumb-item a, nav a');
    if (fallbackElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in fallbackElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('incehesap') && lower != productTitle.toLowerCase().trim() && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }

  @override
  double? scrapeRatingValue(dom.Document document) {
    print('[aggregateRating] IncehesapScraper: ratingValue aranıyor...');
    
    // 1. DOM Microdata (Öncelikli - İncehesap'ta rating JSON-LD'de yok)
    final ratingEl = document.querySelector('[itemprop="ratingValue"]') ??
                     document.querySelector('meta[property="product:rating:value"]') ??
                     document.querySelector('.rating-score') ??
                     document.querySelector('.pdp-rating-value');
    if (ratingEl != null) {
      final text = ratingEl.localName == 'meta'
          ? (ratingEl.attributes['content'] ?? '')
          : ratingEl.text;
      final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
      if (parsed != null && parsed > 0 && parsed <= 5.0) {
        print('[aggregateRating] IncehesapScraper: DOM (itemprop) ile ratingValue bulundu: $parsed');
        return parsed;
      }
    }

    // 2. JSON-LD Fallback
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] IncehesapScraper: JSON-LD fallback ile ratingValue bulundu: $val');
        return val;
      }
    }

    // 3. Script Regex Fallback
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('aggregateRating') || text.contains('ratingValue')) {
        final match = RegExp(r'ratingValue["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?').firstMatch(text);
        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '.');
          final parsed = raw != null ? double.tryParse(raw) : null;
          if (parsed != null && parsed > 0 && parsed <= 5.0) {
            print('[aggregateRating] IncehesapScraper: Regex fallback ile ratingValue bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] IncehesapScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    print('[aggregateRating] IncehesapScraper: ratingCount/reviewCount aranıyor...');
    
    // 1. DOM Microdata (Öncelikli - İncehesap'ta rating JSON-LD'de yok)
    final countEl = document.querySelector('[itemprop="reviewCount"]') ??
                    document.querySelector('[itemprop="ratingCount"]') ??
                    document.querySelector('.review-count') ??
                    document.querySelector('.rating-count');
    if (countEl != null) {
      final text = countEl.localName == 'meta'
          ? (countEl.attributes['content'] ?? '')
          : countEl.text;
      final match = RegExp(r'(\d+)').firstMatch(text);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > 0) {
          print('[aggregateRating] IncehesapScraper: DOM (itemprop) ile ratingCount bulundu: $parsed');
          return parsed;
        }
      }
    }

    // 2. JSON-LD Fallback
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] IncehesapScraper: JSON-LD fallback ile ratingCount bulundu: $cnt');
        return cnt;
      }
    }

    // 3. Script Regex Fallback
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('aggregateRating') || text.contains('reviewCount') || text.contains('ratingCount')) {
        final match = RegExp(r'(?:reviewCount|ratingCount)["\\]*\s*:\s*"?(\d+)"?').firstMatch(text);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null && parsed > 0) {
            print('[aggregateRating] IncehesapScraper: Regex fallback ile ratingCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] IncehesapScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] IncehesapScraper: brand (marka) aranıyor...');
    
    // 1. DOM Microdata (Öncelikli - itemprop="brand" > meta[itemprop="name"])
    final brandDiv = document.querySelector('[itemprop="brand"]');
    if (brandDiv != null) {
      // İç meta etiketi: <meta itemprop="name" content="James Donkey">
      final metaName = brandDiv.querySelector('meta[itemprop="name"]');
      if (metaName != null) {
        final content = metaName.attributes['content']?.trim();
        if (content != null && content.isNotEmpty) {
          print('[aggregateRating] IncehesapScraper: DOM (itemprop brand > meta) ile brand bulundu: $content');
          return content;
        }
      }
      // Fallback: span veya text
      final text = brandDiv.text.trim();
      if (text.isNotEmpty) {
        print('[aggregateRating] IncehesapScraper: DOM (itemprop brand text) ile brand bulundu: $text');
        return text;
      }
    }

    // 2. JSON-LD Fallback
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] IncehesapScraper: JSON-LD fallback ile brand bulundu: $brand');
        return brand;
      }
    }

    // 3. Diğer DOM / Meta Tag
    final brandMeta = document.querySelector('meta[property="product:brand"]') ??
                      document.querySelector('meta[name="brand"]') ??
                      document.querySelector('.product-brand') ??
                      document.querySelector('[data-brand]');
    if (brandMeta != null) {
      final text = brandMeta.localName == 'meta'
          ? (brandMeta.attributes['content'] ?? '')
          : (brandMeta.attributes['data-brand'] ?? brandMeta.text);
      final clean = text.trim();
      if (clean.isNotEmpty) {
        print('[aggregateRating] IncehesapScraper: DOM meta fallback ile brand bulundu: $clean');
        return clean;
      }
    }

    print('[aggregateRating] IncehesapScraper: brand bulunamadı (null)');
    return null;
  }
}
