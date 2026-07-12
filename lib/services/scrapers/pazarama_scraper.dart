import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class PazaramaScraper extends BaseProductScraper {
  @override
  String get domain => 'pazarama.com';

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
          log('✅ Pazarama JSON-LD görseli bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final pazaramaSelectors = [
      '.product-detail-slider img',
      '.product-image img',
      'picture img',
      'img[class*="object-contain"]',
      'img[src*="pzrmcdn.com"]',
      'img[src*="asset/"][src*="images/"]',
      'img[src*="product"]',
      'main img',
      '#product-image-gallery img',
    ];
    for (final selector in pazaramaSelectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final src = element.attributes['src'] ?? element.attributes['data-src'] ?? element.attributes['data-lazy-src'] ?? element.attributes['data-old-hires'];
        if (src != null && src.isNotEmpty && !src.startsWith('data:') && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ Pazarama özel görseli bulundu: $resolved');
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
    final titleEl = document.querySelector('h1.text-huge.text-gray-600.font-bold') ??
                    document.querySelector('h1.text-huge') ??
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
    // 1. Pazarama Plus Fiyat Kontrolü (Plus'a özel indirimli fiyat önceliklidir)
    final plusImgs = document.querySelectorAll('img[alt="plus-icon"], img[src*="pz-plus-icon"]');
    for (final plusImg in plusImgs) {
      var parent = plusImg.parent;
      while (parent != null && parent.localName != 'div') {
        parent = parent.parent;
      }
      if (parent != null) {
        final spans = parent.querySelectorAll('span');
        for (final span in spans) {
          final text = span.text.trim();
          if (text.contains('TL') && !text.contains('ile')) {
            final parsedPrice = parsePriceText(text);
            if (parsedPrice != null && parsedPrice > 0) {
              return parsedPrice;
            }
          }
        }
      }
    }

    // 2. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceVal = extractPriceFromProductJson(productJson);
      if (priceVal != null && priceVal > 0) {
        return priceVal;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final selectors = [
      'div[class*="text-4xl"][class*="text-black"][class*="font-bold"]',
      'div.text-4xl.text-black.font-bold',
      'div.text-4xl.text-black',
      'span[class*="text-lg"][class*="font-bold"][class*="text-red-600"]',
      'span.text-lg.font-bold.text-red-600',
      'meta[property="product:price:amount"]',
    ];
    
    for (final selector in selectors) {
      final priceEl = document.querySelector(selector);
      if (priceEl != null) {
        final text = priceEl.localName == 'meta' ? (priceEl.attributes['content'] ?? '') : priceEl.text;
        final val = parsePriceText(text);
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    final metaDesc = document.querySelector('meta[name="description"]') ??
                     document.querySelector('meta[data-hid="description"]') ??
                     document.querySelector('meta[property="og:description"]');
    if (metaDesc != null) {
      final desc = metaDesc.attributes['content']?.trim();
      if (desc != null && desc.isNotEmpty && desc.toLowerCase() != 'null') {
        return desc;
      }
    }
    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    final productTitle = scrapeTitle(document) ?? '';

    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json' || script.attributes['data-n-head'] == 'ssr') {
        try {
          final sanitizedText = script.text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
          final data = jsonDecode(sanitizedText);
          final breadcrumbs = _extractBreadcrumbsFromJson(data, productTitle);
          if (breadcrumbs.isNotEmpty) {
            return breadcrumbs;
          }
        } catch (_) {}
      }
    }

    // DOM Fallback
    final breadcrumbElements = document.querySelectorAll('.breadcrumb a, .breadcrumbs a, .pazarama-breadcrumb a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && !lower.contains('pazarama') && text != productTitle && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }

  List<String> _extractBreadcrumbsFromJson(dynamic json, String productTitle) {
    if (json is Map) {
      // 1. BreadcrumbList kontrolü
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
                if (lowerName != 'anasayfa' && !lowerName.contains('pazarama')) {
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

      // 2. Product category kontrolü
      if (json['@type'] == 'Product' || json['@type'] == 'http://schema.org/Product' ||
          json['@type'] == 'ProductGroup' || json['@type'] == 'http://schema.org/ProductGroup') {
        final categoryField = json['category'];
        if (categoryField is String && categoryField.isNotEmpty) {
          final parts = categoryField
              .split(RegExp(r'\s*>\s*|\s*/\s*'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .where((e) {
                final lower = e.toLowerCase();
                return lower != 'anasayfa' && !lower.contains('pazarama') && e != productTitle && e.length < 50;
              })
              .toList();
          if (parts.isNotEmpty) return parts;
        } else if (categoryField is Map) {
          final nameVal = categoryField['name'];
          if (nameVal is String && nameVal.isNotEmpty) {
            final parts = nameVal
                .split(RegExp(r'\s*>\s*|\s*/\s*'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .where((e) {
                  final lower = e.toLowerCase();
                  return lower != 'anasayfa' && !lower.contains('pazarama') && e != productTitle && e.length < 50;
                })
                .toList();
            if (parts.isNotEmpty) return parts;
          }
        }
      }

      // Recursive arama
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
