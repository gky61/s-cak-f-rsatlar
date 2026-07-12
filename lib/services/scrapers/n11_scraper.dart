import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class N11Scraper extends BaseProductScraper {
  @override
  String get domain => 'n11.com';

  Map<String, dynamic>? _getN11Model(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('window.model =')) {
        final modelIndex = text.indexOf('window.model =');
        if (modelIndex != -1) {
          final startJson = text.indexOf('{', modelIndex);
          final endJson = text.lastIndexOf('}');
          if (startJson != -1 && endJson != -1 && endJson > startJson) {
            try {
              final jsonStr = text.substring(startJson, endJson + 1);
              return jsonDecode(jsonStr);
            } catch (_) {}
          }
        }
      }
    }
    return null;
  }

  dynamic _findValueRecursive(dynamic json, String targetKey) {
    if (json is Map) {
      if (json.containsKey(targetKey)) {
        return json[targetKey];
      }
      for (final value in json.values) {
        if (value is Map || value is List) {
          final res = _findValueRecursive(value, targetKey);
          if (res != null) return res;
        }
      }
    } else if (json is List) {
      for (final item in json) {
        final res = _findValueRecursive(item, targetKey);
        if (res != null) return res;
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
    // 1. window.model JSON'ından görseli çekmeyi dene (Öncelikli)
    final model = _getN11Model(document);
    if (model != null) {
      final images = model['product']?['images'];
      if (images is List && images.isNotEmpty) {
        final firstImgPath = images[0]['path']?.toString();
        if (firstImgPath != null && firstImgPath.isNotEmpty) {
          // {0} boyut belirtecini standart 400_570 boyutuyla değiştir
          final resolvedPath = firstImgPath.replaceAll('{0}', '400_570');
          final resolved = resolveImageUrl(resolvedPath, url);
          if (resolved != null && !isLogoUrl(resolved)) {
            log('✅ N11 görseli window.model ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final n11Selectors = [
      '.big-image-wrapper img',
      'img.swiper-image',
      'img.swiper-lazy',
      'img[class*="swiper"]',
      '#product-image img',
      '.product-images img',
    ];
    for (final selector in n11Selectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final src = element.attributes['src'] ?? element.attributes['data-src'] ?? element.attributes['data-lazy-src'];
        if (src != null && src.isNotEmpty && !src.startsWith('data:') && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ N11 özel görseli DOM ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }
    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. window.model JSON'ından başlığı çekmeyi dene (Öncelikli)
    final model = _getN11Model(document);
    if (model != null) {
      final title = model['product']?['name'] ?? model['seoMetaData']?['title'];
      if (title != null && title.toString().isNotEmpty) {
        return title.toString().trim();
      }
    }

    // 2. window.model içinden regex ile başlık çekmeyi dene (Live sayfalar için fallback 1)
    final html = document.outerHtml;
    final titleReg = RegExp(r'"title"\s*:\s*"([^"]+)"');
    final titleMatch = titleReg.firstMatch(html);
    if (titleMatch != null) {
      final matched = titleMatch.group(1);
      if (matched != null && matched.isNotEmpty) {
        return matched.trim();
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final titleEl = document.querySelector('.titleArea h1.title') ??
                    document.querySelector('h1.title') ??
                    document.querySelector('h1.proName') ??
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
    // 1. window.model JSON'ından fiyatı çekmeyi dene (Öncelikli)
    final model = _getN11Model(document);
    if (model != null) {
      // En öncelikli: Sepetteki nihai indirimli fiyat float değeri (finalPriceFloat)
      final finalPriceFloat = _findValueRecursive(model, 'finalPriceFloat');
      if (finalPriceFloat != null) {
        final val = double.tryParse(finalPriceFloat.toString());
        if (val != null && val > 0) return val;
      }

      // İkinci öncelik: Sepetteki nihai indirimli fiyat metin değeri (finalPrice)
      final finalPrice = _findValueRecursive(model, 'finalPrice');
      if (finalPrice != null) {
        final val = parsePriceText(finalPrice.toString());
        if (val != null && val > 0) return val;
      }

      // Üçüncü öncelik: İndirimli gerçek fiyat float değeri (priceFloat)
      final priceFloat = _findValueRecursive(model, 'priceFloat');
      if (priceFloat != null) {
        final val = double.tryParse(priceFloat.toString());
        if (val != null && val > 0) return val;
      }

      // Dördüncü öncelik: İndirimli gerçek fiyat metin değeri (price)
      final price = _findValueRecursive(model, 'price');
      if (price != null) {
        final val = parsePriceText(price.toString());
        if (val != null && val > 0) return val;
      }

      // Beşinci öncelik: Liste fiyatı float değeri (displayPriceFloat)
      final displayPriceFloat = _findValueRecursive(model, 'displayPriceFloat');
      if (displayPriceFloat != null) {
        final val = double.tryParse(displayPriceFloat.toString());
        if (val != null && val > 0) return val;
      }

      // Altıncı öncelik: Liste fiyatı metin değeri (displayPrice)
      final displayPrice = _findValueRecursive(model, 'displayPrice');
      if (displayPrice != null) {
        final val = parsePriceText(displayPrice.toString());
        if (val != null && val > 0) return val;
      }
    }

    // 2. window.model içinden regex ile fiyat çekmeyi dene (Fallback 1)
    final html = document.outerHtml;
    final finalPriceReg = RegExp(r'"finalPrice"\s*:\s*"([^"]+)"');
    final finalPriceMatch = finalPriceReg.firstMatch(html);
    if (finalPriceMatch != null) {
      final val = parsePriceText(finalPriceMatch.group(1)!);
      if (val != null && val > 0) return val;
    }
    
    final priceReg = RegExp(r'"price"\s*:\s*"([^"]+)"');
    final priceMatch = priceReg.firstMatch(html);
    if (priceMatch != null) {
      final val = parsePriceText(priceMatch.group(1)!);
      if (val != null && val > 0) return val;
    }

    // 3. DOM Seçicileri (Fallback 2)
    final priceEl = document.querySelector('.newPrice ins') ??
                    document.querySelector('ins') ??
                    document.querySelector('.newPrice') ??
                    document.querySelector('meta[property="product:price:amount"]');
                    
    if (priceEl != null) {
      if (priceEl.localName == 'meta') {
        return parsePriceText(priceEl.attributes['content'] ?? '');
      }
      return parsePriceText(priceEl.text);
    }
    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. window.model JSON'ından açıklamayı çekmeyi dene (Öncelikli)
    final model = _getN11Model(document);
    if (model != null) {
      final desc = model['seoMetaData']?['description'];
      if (desc != null && desc.toString().isNotEmpty) {
        return desc.toString().trim();
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final descEl = document.querySelector('meta[name="description"]') ??
                   document.querySelector('meta[property="og:description"]');
    if (descEl != null) {
      return descEl.attributes['content']?.trim();
    }
    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final productTitle = scrapeTitle(document) ?? '';

    // window.model JSON'ından aramayı dene
    final model = _getN11Model(document);
    if (model != null) {
      final categoryField = model['category'] ?? model['categories'];
      if (categoryField is String && categoryField.isNotEmpty) {
        final parts = categoryField
            .split(RegExp(r'\s*>\s*|\s*/\s*'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .where((e) {
              final lower = e.toLowerCase();
              return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('n11') && lower != productTitle.toLowerCase().trim() && e.length < 50;
            })
            .toList();
        if (parts.isNotEmpty) return parts;
      } else if (categoryField is List) {
        final List<String> list = [];
        for (final cat in categoryField) {
          if (cat is Map && cat['name'] != null) {
            final name = cat['name'].toString().trim();
            final lower = name.toLowerCase();
            if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('n11') && lower != productTitle.toLowerCase().trim() && name.length < 50) {
              list.add(name);
            }
          } else if (cat is String) {
            final name = cat.trim();
            final lower = name.toLowerCase();
            if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('n11') && lower != productTitle.toLowerCase().trim() && name.length < 50) {
              list.add(name);
            }
          }
        }
        if (list.isNotEmpty) return list;
      }
    }

    // DOM Fallback
    final breadcrumbElements = document.querySelectorAll('.breadcrumb-item a, .breadcrumb a, .breadcrumb-group a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('n11') && lower != productTitle.toLowerCase().trim() && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }
}
