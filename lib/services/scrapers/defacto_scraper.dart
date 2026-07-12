import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class DefactoScraper extends BaseProductScraper {
  @override
  String get domain => 'defacto.com.tr';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('defacto.com.tr');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. og:image tag'i dene (Defacto için son derece güvenlidir)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Defacto görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final imgSelectors = [
      '.product-card__image img',
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
            log('✅ Defacto görseli DOM ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. Script bloğundan çekmeyi dene (Öncelikli)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('PRODUCT_DETAIL_LASTVISITED') || text.contains('PRODUCT_DETAIL_INFO')) {
        final match = RegExp(r'"?ProductVariantMiniProductName"?\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"?Name"?\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"?name"?\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final title = match.group(1);
          if (title != null && title.isNotEmpty) {
            return _decodeUnicode(title);
          }
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final titleEl = document.querySelector('h1.product-card__title') ?? 
                    document.querySelector('.product-title') ?? 
                    document.querySelector('h1');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Script bloğundan (Öncelikli)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('PRODUCT_DETAIL_LASTVISITED') || text.contains('CampaignBadge')) {
        // Fiyat belirleme algoritması:
        // A) Sepette indirimli fiyat (DiscountPrice) varsa bunu kullan
        final discountPriceMatch = RegExp(r'"?DiscountPrice"?\s*:\s*([0-9.]+)').firstMatch(text);
        if (discountPriceMatch != null) {
          final val = double.tryParse(discountPriceMatch.group(1)!);
          if (val != null && val > 0) return val;
        }

        // B) DataLayer altındaki CampaignDiscountedPrice varsa bunu kullan
        final campaignDiscountMatch = RegExp(r'"?CampaignDiscountedPrice"?\s*:\s*([0-9.]+)').firstMatch(text);
        if (campaignDiscountMatch != null) {
          final val = double.tryParse(campaignDiscountMatch.group(1)!);
          if (val != null && val > 0) return val;
        }

        // C) Ürünün standart indirimli fiyatı (ProductVariantMiniDiscountedPriceInclTax)
        final miniDiscountMatch = RegExp(r'"?ProductVariantMiniDiscountedPriceInclTax"?\s*:\s*"([0-9.]+)"').firstMatch(text);
        if (miniDiscountMatch != null) {
          final val = double.tryParse(miniDiscountMatch.group(1)!);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final priceSelectors = [
      '.product-price__discount',
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
    return null;
  }

  String _decodeUnicode(String input) {
    var text = input;
    text = text.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      final hexCode = match.group(1)!;
      final charCode = int.parse(hexCode, radix: 16);
      return String.fromCharCode(charCode);
    });
    text = text
      .replaceAll('&#x131;', 'ı')
      .replaceAll('&#x130;', 'İ')
      .replaceAll('&#x15F;', 'ş')
      .replaceAll('&#x15E;', 'Ş')
      .replaceAll('&#xE7;', 'ç')
      .replaceAll('&#xC7;', 'Ç')
      .replaceAll('&#xF6;', 'ö')
      .replaceAll('&#xD6;', 'Ö')
      .replaceAll('&#xFC;', 'ü')
      .replaceAll('&#xDC;', 'Ü')
      .replaceAll('&#x11F;', 'ğ')
      .replaceAll('&#x11E;', 'Ğ')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&');
    return text;
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
    final breadcrumbElements = document.querySelectorAll('.breadcrumb a, .breadcrumbs a, .defacto-breadcrumb a, .breadcrumb-list a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('defacto') && text.toLowerCase() != productTitle.toLowerCase().trim() && text.length < 50) {
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
                if (lowerName != 'anasayfa' && lowerName != 'ana sayfa' && !lowerName.contains('defacto')) {
                  if (lowerName != productTitle.toLowerCase().trim() && name.length < 50) {
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
                return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('defacto') && lower != productTitle.toLowerCase().trim() && e.length < 50;
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
                  return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('defacto') && lower != productTitle.toLowerCase().trim() && e.length < 50;
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
