import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

/// Gamer Gen (gamer.gen.tr) Mağaza Kazıyıcı Sınıfı
class GamerGenScraper extends BaseProductScraper {
  @override
  String get domain => 'gamer.gen.tr';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('gamer.gen.tr');
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
          log('✅ Gamer Gen görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Eğer logo değilse)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty && !isLogoUrl(ogImage)) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Gamer Gen görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback)
    final imgElements = document.querySelectorAll(
      '.product-details-img img, #product-image img, img[class*="product"], .system-image img',
    );
    for (final img in imgElements) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Gamer Gen görseli DOM img etiketiyle bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 4. Hazır sistem veya genel sayfa için CDN regex fallback'i
    final html = document.outerHtml;
    final cdnMatches = RegExp(r'https://img\.yenieera22\.com/cdn/(?:1000|250)/[a-zA-Z0-9_\.\-]+(?:\.png|\.jpg|\.webp)', caseSensitive: false)
        .allMatches(html);
    for (final m in cdnMatches) {
      final matchedUrl = m.group(0);
      if (matchedUrl != null && !isLogoUrl(matchedUrl)) {
        // Tercihen 1000'lik yüksek çözünürlük versiyonuna yükselt
        final highRes = matchedUrl.replaceAll('/cdn/250/', '/cdn/1000/');
        final resolved = resolveImageUrl(highRes, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Gamer Gen görseli CDN regex ile bulundu: $resolved');
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
      final name = productJson['name'].toString().trim();
      if (name.isNotEmpty) return name;
    }

    // 2. DOM Seçicileri (Fallback)
    final titleEl = document.querySelector('h1.product-details-title') ??
                    document.querySelector('h1');
    if (titleEl != null) {
      // Çocuk elemanların (ör. "Paylaş" butonu) metnini filtrele
      String title = titleEl.text.trim();
      title = title.replaceAll(RegExp(r'\s*Paylaş\s*$', caseSensitive: false), '').trim();
      if (title.isNotEmpty) return title;
    }

    // 3. og:title fallback
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (ogTitle != null && ogTitle.trim().isNotEmpty) {
      String clean = ogTitle.trim();
      clean = clean.replaceAll(RegExp(r'\s*\|\s*(?:ITOPYA|GAMER\.GEN\.TR|Gamer Gen).*$', caseSensitive: false), '').trim();
      if (clean.isNotEmpty) return clean;
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. DOM Sepette indirimli fiyat (.text-price: ör. "Sepette 18.999,00 TL")
    final textPriceEl = document.querySelector('.text-price');
    if (textPriceEl != null) {
      final clean = textPriceEl.text.replaceAll(RegExp(r'sepette', caseSensitive: false), '');
      final val = parsePriceText(clean);
      if (val != null && val > 0) return val;
    }

    // 2. DOM normal satış fiyatı (.product-price: ör. "23.158,63 TL" veya "10.899,00 TL")
    final productPriceEl = document.querySelector('.product-price');
    if (productPriceEl != null) {
      final val = parsePriceText(productPriceEl.text);
      if (val != null && val > 0) return val;
    }

    // 3. JSON-LD şemasından fiyat çekmeyi dene
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) return priceLd;
    }

    // 4. Hazır sistem (_h...) ve script fallback'leri
    final html = document.outerHtml;
    // var toplamFiyat = '99998,99091000';
    final toplamFiyatMatch = RegExp(r'var\s+toplamFiyat\s*=\s*[\x27"]?([0-9.,]+)[\x27"]?', caseSensitive: false).firstMatch(html);
    if (toplamFiyatMatch != null) {
      final val = parsePriceText(toplamFiyatMatch.group(1)!);
      if (val != null && val > 0) return val;
    }

    // gtag("event", "view_item", { ... price: 99998.99 ... });
    final gtagMatch = RegExp(r'gtag\("event",\s*"view_item"[\s\S]*?price\s*:\s*([0-9.]+)', caseSensitive: false).firstMatch(html);
    if (gtagMatch != null) {
      final val = double.tryParse(gtagMatch.group(1)!);
      if (val != null && val > 0) return val;
    }

    return null;
  }

  @override
  double? scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    // 1. Eğer sepet indirimi varsa (.text-price), liste fiyatı .product-price içindedir
    final textPriceEl = document.querySelector('.text-price');
    if (textPriceEl != null && textPriceEl.text.trim().isNotEmpty) {
      final clean = textPriceEl.text.replaceAll(RegExp(r'sepette', caseSensitive: false), '');
      final sepetPrice = parsePriceText(clean);
      if (sepetPrice != null && currentPrice <= sepetPrice) {
        final productPriceEl = document.querySelector('.product-price');
        if (productPriceEl != null) {
          final val = parsePriceText(productPriceEl.text);
          if (val != null && val > currentPrice) return val;
        }
      }
    }

    // 2. Normal indirimli ürünlerde eski fiyat .product-old-price içindedir
    final oldPriceEl = document.querySelector('.product-old-price');
    if (oldPriceEl != null) {
      final val = parsePriceText(oldPriceEl.text);
      if (val != null && val > currentPrice) return val;
    }

    // 3. Fallback aday seçicileri
    final candidates = <double>[];
    final selectors = [
      '.product-old-price',
      '.product-price',
      '.detail-price-div',
      'del',
      's',
      '.old-price',
      '.original-price',
    ];

    for (final selector in selectors) {
      for (final el in document.querySelectorAll(selector)) {
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

    // currentPrice'a en yakın (en küçük) adayı seç
    candidates.sort();
    return candidates.first;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    // 1. JSON-LD
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['brand'] != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) return brand;
    }

    // 2. DOM Seçicileri
    final brandEl = document.querySelector('.product-details-brand') ??
                    document.querySelector('[itemprop="brand"]');
    if (brandEl != null && brandEl.text.trim().isNotEmpty) {
      return brandEl.text.trim();
    }

    // 3. Script regex fallback (örn. item_brand: "GamerGen" veya JSON-LD regex)
    final html = document.outerHtml;
    final brandMatch = RegExp(r'"brand"\s*:\s*\{\s*"@type"\s*:\s*"Brand"\s*,\s*"name"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(html) ??
                       RegExp(r'item_brand\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(html);
    if (brandMatch != null) {
      return brandMatch.group(1)!.trim();
    }

    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. JSON-LD şemasından açıklama çekmeyi dene
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      return productJson['description'].toString().trim();
    }

    // 2. DOM Seçicileri
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

    // 1. JSON-LD BreadcrumbList
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

    // 2. JSON-LD regex fallback (JSON.parse tırnak hatası verse dahi)
    final html = document.outerHtml;
    final bcBlock = RegExp(r'"itemListElement"\s*:\s*\[([\s\S]*?)\]', caseSensitive: false).firstMatch(html);
    if (bcBlock != null) {
      final itemMatches = RegExp(r'"name"\s*:\s*"([^"]+)"').allMatches(bcBlock.group(1)!);
      final List<String> list = [];
      for (final m in itemMatches) {
        final name = m.group(1)!.trim();
        final lower = name.toLowerCase();
        if (lower != 'ana sayfa' && lower != 'anasayfa' && !lower.contains('gamer') && !lower.contains('itopya') && name != productTitle && name.length < 50) {
          list.add(name);
        }
      }
      if (list.isNotEmpty) return list;
    }

    // 3. DOM Fallback
    final breadcrumbElements = document.querySelectorAll(
      '.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a, .breadcrumb-item a',
    );
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('gamer') && !lower.contains('itopya') && text != productTitle && text.length < 50) {
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
                if (lowerName != 'anasayfa' && lowerName != 'ana sayfa' && !lowerName.contains('gamer') && !lowerName.contains('itopya')) {
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
