import 'dart:async';
import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class MigrosScraper extends BaseProductScraper {

  @override
  String get domain => 'migros.com.tr';

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
          log('✅ Migros görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Migros görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgElements = document.querySelectorAll('img[class*="product-image"], img.product-image, .product-details img, img[class*="product"]');
    for (final img in imgElements) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Migros görseli img etiketiyle bulundu: $resolved');
          return resolved;
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
                    document.querySelector('h1');
    if (titleEl != null) {
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
    final priceEl = document.querySelector('#new-amount') ??
                    document.querySelector('.amount');
    if (priceEl != null) {
      final val = parsePriceText(priceEl.text);
      if (val != null && val > 0) {
        return val;
      }
    }

    return null;
  }

  String _cleanDescription(String desc) {
    // Strip HTML tags
    String cleaned = desc.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Clean up multiple spaces, newlines, etc.
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }


  @override
  Future<String?> scrapeDescription(dom.Document document) async {
    final crmEl = document.querySelector('.product-label.crm');
    String crmPrefix = '';
    if (crmEl != null) {
      final crmText = crmEl.text.trim().toUpperCase();
      if (crmText.isNotEmpty) {
        crmPrefix = '**$crmText**';
      }
    }

    if (crmPrefix.isEmpty) {
      try {
        String imageUrl = '';
        final productJson = findProductJsonLd(document);
        if (productJson != null && productJson['image'] != null) {
          imageUrl = extractImageFromProductJson(productJson['image']) ?? '';
        }
        if (imageUrl.isEmpty) {
          final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
          if (ogImage != null) {
            imageUrl = ogImage;
          }
        }

        if (imageUrl.isNotEmpty) {
          final regExp = RegExp(r'product\/(\d+)');
          final match = regExp.firstMatch(imageUrl);
          if (match != null) {
            final productId = match.group(1);
            if (productId != null) {
              final response = await http.get(
                Uri.parse('https://www.migros.com.tr/rest/hemen/products/screens/$productId'),
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
                },
              ).timeout(const Duration(seconds: 4));
              if (response.statusCode == 200) {
                final json = jsonDecode(response.body);
                if (json is Map && json['data'] != null) {
                  final data = json['data'];
                  if (data is Map && data['storeProductInfoDTO'] != null) {
                    final info = data['storeProductInfoDTO'];
                    if (info is Map && info['crmDiscountTags'] != null) {
                      final crmTags = info['crmDiscountTags'];
                      if (crmTags is List && crmTags.isNotEmpty) {
                        final tagObj = crmTags[0];
                        if (tagObj is Map && tagObj['tag'] != null) {
                          final crmText = tagObj['tag'].toString().trim().toUpperCase();
                          if (crmText.isNotEmpty) {
                            crmPrefix = crmText;
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    String baseDesc = '';

    // 1. JSON-LD şemasından açıklama çekmeyi dene (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      baseDesc = _cleanDescription(productJson['description'].toString());
    } else {
      // 2. JSON-LD Kök seviyesindeki açıklamayı dene
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
        final type = script.attributes['type']?.trim().toLowerCase();
        if (type == 'application/ld+json') {
          try {
            final sanitizedText = script.text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
            final data = jsonDecode(sanitizedText);
            if (data is Map && data['description'] != null) {
              baseDesc = _cleanDescription(data['description'].toString());
              break;
            }
          } catch (_) {}
        }
      }
    }

    // 3. DOM Seçicileri (Fallback if still empty)
    if (baseDesc.isEmpty) {
      final descEl = document.querySelector('meta[name="description"]') ??
                     document.querySelector('meta[property="og:description"]');
      if (descEl != null) {
        final content = descEl.attributes['content'];
        if (content != null) {
          baseDesc = _cleanDescription(content);
        }
      }
    }

    if (crmPrefix.isNotEmpty) {
      return baseDesc.isNotEmpty ? '$crmPrefix\n\n$baseDesc' : crmPrefix;
    }
    return baseDesc.isNotEmpty ? baseDesc : null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    final productTitle = scrapeTitle(document) ?? '';

    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
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
    final breadcrumbElements = document.querySelectorAll('.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('migros') && text != productTitle && text.length < 50) {
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
                if (lowerName != 'anasayfa' && lowerName != 'ana sayfa' && !lowerName.contains('migros')) {
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
                return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('migros') && e != productTitle && e.length < 50;
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
                  return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('migros') && e != productTitle && e.length < 50;
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
