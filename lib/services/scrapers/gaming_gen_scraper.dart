import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

/// Gaming Gen (gaming.gen.tr) Mağaza Kazıyıcı Sınıfı
/// WooCommerce altyapısını kullanır.
class GamingGenScraper extends BaseProductScraper {
  @override
  String get domain => 'gaming.gen.tr';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('gaming.gen.tr');
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
          log('✅ Gaming Gen görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty && !isLogoUrl(ogImage)) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Gaming Gen görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. WooCommerce Galeri Görselleri (DOM)
    final galleryImg = document.querySelector('.woocommerce-product-gallery__image img, .wp-post-image');
    if (galleryImg != null) {
      final src = galleryImg.attributes['data-large_image'] ??
                  galleryImg.attributes['data-src'] ??
                  galleryImg.attributes['src'];
      if (src != null && src.isNotEmpty && !isLogoUrl(src)) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Gaming Gen görseli DOM galeri ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. DOM Ürün başlığı (Öncelikli)
    final titleEl = document.querySelector('h1.product_title, h1.entry-title, .product_title') ??
                    document.querySelector('h1');
    if (titleEl != null) {
      final title = titleEl.text.trim();
      if (title.isNotEmpty) return title;
    }

    // 2. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      final name = productJson['name'].toString().trim();
      if (name.isNotEmpty) return name;
    }

    // 3. og:title Fallback
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (ogTitle != null && ogTitle.trim().isNotEmpty) {
      String clean = ogTitle.trim();
      clean = clean.replaceAll(RegExp(r'\s*[-|]\s*(?:Gaming\.Gen\.TR|Gaming Gen).*$', caseSensitive: false), '').trim();
      if (clean.isNotEmpty) return clean;
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. DOM Ana Ürün Fiyatı (.summary veya .entry-summary doğrudan altındaki .price)
    final summary = document.querySelector('.summary, .entry-summary, .product-summary');
    if (summary != null) {
      // Doğrudan child olan .price veya p.price elemanını ara
      final mainPriceEl = summary.children.firstWhere(
        (el) => el.classes.contains('price') || el.localName == 'p' && el.classes.contains('price'),
        orElse: () => summary.querySelector('.price') ?? dom.Element.tag('div'),
      );

      if (mainPriceEl.localName != 'div' || mainPriceEl.classes.contains('price')) {
        // İndirimli satış fiyatı ins içindedir
        final insEl = mainPriceEl.querySelector('ins .woocommerce-Price-amount, ins');
        if (insEl != null) {
          final val = parsePriceText(insEl.text);
          if (val != null && val > 0) return val;
        }

        // Normal veya tek fiyat (.woocommerce-Price-amount)
        final amountEl = mainPriceEl.querySelector('.woocommerce-Price-amount');
        if (amountEl != null) {
          final val = parsePriceText(amountEl.text);
          if (val != null && val > 0) return val;
        }

        // Düz metin (örn. "En Düşük: 99.999,00 ₺")
        final textVal = parsePriceText(mainPriceEl.text);
        if (textVal != null && textVal > 0) return textVal;
      }
    }

    // 2. Genel DOM Seçicileri (Fallback)
    final priceElements = document.querySelectorAll('p.price, .price');
    for (final el in priceElements) {
      // Paket/eklenti ürünlerini (bundled) atla
      if (el.parent?.classes.contains('bundled_product_optional_checkbox') == true) continue;

      final insEl = el.querySelector('ins .woocommerce-Price-amount, ins');
      if (insEl != null) {
        final val = parsePriceText(insEl.text);
        if (val != null && val > 0) return val;
      }
      final val = parsePriceText(el.text);
      if (val != null && val > 0) return val;
    }

    // 3. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) return priceLd;
    }

    return null;
  }

  @override
  double? scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    // 1. Ana ürün fiyat bloğundaki del etiketi (Öncelikli)
    final summary = document.querySelector('.summary, .entry-summary, .product-summary');
    if (summary != null) {
      final mainPriceEl = summary.children.firstWhere(
        (el) => el.classes.contains('price') || el.localName == 'p' && el.classes.contains('price'),
        orElse: () => summary.querySelector('.price') ?? dom.Element.tag('div'),
      );

      if (mainPriceEl.localName != 'div' || mainPriceEl.classes.contains('price')) {
        final delEl = mainPriceEl.querySelector('del .woocommerce-Price-amount, del');
        if (delEl != null) {
          final val = parsePriceText(delEl.text);
          if (val != null && val > currentPrice) return val;
        }
      }
    }

    // 2. DOM Fallback Aday Seçicileri
    final candidates = <double>[];
    final selectors = [
      'del .woocommerce-Price-amount',
      '.summary del',
      'del',
      's',
      '.old-price',
      '.original-price'
    ];

    for (final selector in selectors) {
      for (final el in document.querySelectorAll(selector)) {
        if (el.parent?.classes.contains('bundled_product_optional_checkbox') == true) continue;

        final txt = el.text.trim();
        if (txt.contains('TL') || txt.contains('₺') || RegExp(r'\d').hasMatch(txt)) {
          final parsed = parsePriceText(txt);
          if (parsed != null && parsed > currentPrice && parsed <= currentPrice * 5) {
            candidates.add(parsed);
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort();
    return candidates.first;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    // 1. JSON-LD Şeması (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['brand'] != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) return brand;
    }

    // 2. DOM Seçicileri (.product_meta a[href*="marka/"])
    final brandTag = document.querySelector('.product_meta a[href*="marka/"], .product_meta a[href*="brand/"]');
    if (brandTag != null && brandTag.text.trim().isNotEmpty) {
      return brandTag.text.trim();
    }

    // 3. Script regex fallback
    final html = document.outerHtml;
    final brandMatch = RegExp(r'"brand"\s*:\s*\{\s*"@type"\s*:\s*"Brand"\s*,\s*"name"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(html);
    if (brandMatch != null) {
      return brandMatch.group(1)!.trim();
    }

    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      return productJson['description'].toString().trim();
    }

    // 2. DOM Seçicileri
    final descEl = document.querySelector('meta[name="description"]') ??
                   document.querySelector('meta[property="og:description"]') ??
                   document.querySelector('.woocommerce-product-details__short-description');
    if (descEl != null) {
      final desc = descEl.attributes['content'] ?? descEl.text;
      if (desc.trim().isNotEmpty) return desc.trim();
    }

    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final productTitle = scrapeTitle(document) ?? '';

    // 1. DOM WooCommerce Breadcrumb (Öncelikli)
    final bcElements = document.querySelectorAll('nav.woocommerce-breadcrumb a, .woocommerce-breadcrumb a');
    if (bcElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in bcElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && lower != 'gaming.gen.tr' && lower != 'gaming gen' && lower != 'gaming.gen' && text != productTitle && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    // 2. JSON-LD BreadcrumbList (Fallback)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
        try {
          final sanitizedText = script.text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
          final data = jsonDecode(sanitizedText);
          final breadcrumbs = _extractBreadcrumbsFromJson(data, productTitle);
          if (breadcrumbs.isNotEmpty) return breadcrumbs;
        } catch (_) {}
      }
    }

    return [];
  }

  @override
  Future<double?> scrapeRatingValue(dom.Document document) async {
    // 1. JSON-LD Şeması (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['aggregateRating'] != null) {
      final agg = productJson['aggregateRating'];
      if (agg is Map && agg['ratingValue'] != null) {
        final countRaw = agg['reviewCount'] ?? agg['ratingCount'];
        final cnt = countRaw != null ? int.tryParse(countRaw.toString()) : null;
        if (cnt != null && cnt > 0) {
          final val = double.tryParse(agg['ratingValue'].toString().replaceAll(',', '.'));
          if (val != null && val > 0) {
            return (val * 10).roundToDouble() / 10;
          }
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final countEl = document.querySelector('.summary .woocommerce-product-rating span.count, .entry-summary .woocommerce-product-rating span.count');
    final cnt = countEl != null ? int.tryParse(countEl.text.trim()) : null;
    if (cnt != null && cnt > 0) {
      final ratingEl = document.querySelector('.summary .woocommerce-product-rating strong.rating, .entry-summary .woocommerce-product-rating strong.rating');
      if (ratingEl != null) {
        final val = double.tryParse(ratingEl.text.trim().replaceAll(',', '.'));
        if (val != null && val > 0) {
          return (val * 10).roundToDouble() / 10;
        }
      }
    }

    return null;
  }

  @override
  Future<int?> scrapeRatingCount(dom.Document document) async {
    // 1. JSON-LD Şeması (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['aggregateRating'] != null) {
      final agg = productJson['aggregateRating'];
      if (agg is Map) {
        final countRaw = agg['reviewCount'] ?? agg['ratingCount'];
        if (countRaw != null) {
          final cnt = int.tryParse(countRaw.toString());
          if (cnt != null && cnt > 0) return cnt;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final countEl = document.querySelector('.summary .woocommerce-product-rating span.count, .entry-summary .woocommerce-product-rating span.count');
    if (countEl != null) {
      final cnt = int.tryParse(countEl.text.trim());
      if (cnt != null && cnt > 0) return cnt;
    }

    return null;
  }

  List<String> _extractBreadcrumbsFromJson(dynamic json, String productTitle) {
    if (json is Map) {
      if (json['@type'] == 'BreadcrumbList' || json['@type'] == 'http://schema.org/BreadcrumbList') {
        final items = json['itemListElement'];
        if (items is List) {
          final List<String> breadcrumbs = [];
          for (final item in items) {
            if (item is Map) {
              String? name;
              if (item['name'] != null) {
                name = item['name'].toString().trim();
              } else if (item['item'] is Map && item['item']['name'] != null) {
                name = item['item']['name'].toString().trim();
              }

              if (name != null && name.isNotEmpty) {
                final lowerName = name.toLowerCase();
                if (lowerName != 'anasayfa' && lowerName != 'ana sayfa' && !lowerName.contains('gaming')) {
                  if (name != productTitle && name.length < 50) {
                    breadcrumbs.add(name);
                  }
                }
              }
            }
          }
          if (breadcrumbs.isNotEmpty) return breadcrumbs;
        }
      }

      for (final value in json.values) {
        if (value is Map || value is List) {
          final res = _extractBreadcrumbsFromJson(value, productTitle);
          if (res.isNotEmpty) return res;
        }
      }
    } else if (json is List) {
      for (final item in json) {
        final res = _extractBreadcrumbsFromJson(item, productTitle);
        if (res.isNotEmpty) return res;
      }
    }
    return [];
  }
}
