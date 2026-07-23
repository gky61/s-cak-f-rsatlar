import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class HavitScraper extends BaseProductScraper {
  @override
  String get domain => 'havitstore.com.tr';

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
          log('✅ Havit görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Havit görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgElements = document.querySelectorAll('.sub-image img, #product-image img, .product-details img, img[class*="product"]');
    for (final img in imgElements) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Havit görseli img etiketiyle bulundu: $resolved');
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
    final priceEl = document.querySelector('#fiyat2 .spanFiyat') ??
                    document.querySelector('.indirimliFiyat .spanFiyat');
    if (priceEl != null) {
      final val = parsePriceText(priceEl.text);
      if (val != null && val > 0) {
        return val;
      }
    }

    return null;
  }

  String _cleanDescription(String desc) {
    // 1. Remove @import statements
    String cleaned = desc.replaceAll(RegExp(r'@import\s+url\([^)]+\);?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'@import\s+[^;]+;', caseSensitive: false), '');
    
    // 2. Remove CSS rule blocks like selector { ... }
    cleaned = cleaned.replaceAll(RegExp(r'[^{]+{[^}]+}'), '');
    
    // 3. Strip any HTML tags that might be left
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), ' ');
    
    // 4. Remove leftover braces or orphan CSS properties
    cleaned = cleaned.replaceAll(RegExp(r'[\w-]+\s*:\s*[^;]+;'), '');
    
    // 5. Clean up multiple spaces, newlines, etc.
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned.trim();
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. JSON-LD şemasından açıklama çekmeyi dene (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      return _cleanDescription(productJson['description'].toString());
    }

    // 2. DOM Seçicileri (Fallback)
    final descEl = document.querySelector('meta[name="description"]') ??
                   document.querySelector('meta[property="og:description"]');
    if (descEl != null) {
      final content = descEl.attributes['content'];
      if (content != null) {
        return _cleanDescription(content);
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
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('havit') && text != productTitle && text.length < 50) {
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
                if (lowerName != 'anasayfa' && lowerName != 'ana sayfa' && !lowerName.contains('havit')) {
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
                return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('havit') && e != productTitle && e.length < 50;
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
                  return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('havit') && e != productTitle && e.length < 50;
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

  // Cache YG Digital API response per document invocation to avoid duplicate calls
  Map<String, dynamic>? _ygRatingCache;
  dom.Document? _cachedDoc;

  Future<Map<String, dynamic>?> _fetchYgDigitalRating(dom.Document document) async {
    if (_cachedDoc == document && _ygRatingCache != null) {
      return _ygRatingCache;
    }

    try {
      String? barcode;
      // 1. DOM barkod
      final barEl = document.querySelector('#divBarkod #spnBarkod') ?? document.querySelector('#spnBarkod');
      if (barEl != null && barEl.text.trim().isNotEmpty) {
        barcode = barEl.text.trim();
      }

      // 2. script stockCode
      if (barcode == null || barcode.isEmpty) {
        final scripts = document.getElementsByTagName('script');
        for (final script in scripts) {
          final text = script.text + ' ' + script.innerHtml;
          final match = RegExp(r'"stockCode"\s*:\s*"([^"]+)"').firstMatch(text);
          if (match != null) {
            barcode = match.group(1)?.trim();
            break;
          }
        }
      }

      final hddnInput = document.querySelector('#hddnUrunID');
      final hddnVal = hddnInput?.attributes['value'];

      final uri = Uri.parse('https://api.yg.digital/trendyol_api/api/commentDetail.php');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://www.havitstore.com.tr',
          'Referer': 'https://www.havitstore.com.tr/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        body: jsonEncode({
          'barcode': barcode ?? hddnVal ?? '',
          'productUrl': '',
          'page': 0,
          'rateFilter': 0,
          'photoFilter': 0,
          'sortOrder': 'DESC',
          'searchText': '',
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['product'] != null) {
          final prod = data['product'] as Map;
          final avgRate = (prod['avg_rate'] as num?)?.toDouble();
          final rateCount = (prod['rate_count'] as num?)?.toInt();
          _cachedDoc = document;
          _ygRatingCache = {
            'ratingValue': (avgRate != null && avgRate > 0) ? avgRate : null,
            'ratingCount': (rateCount != null && rateCount > 0) ? rateCount : null,
          };
          if (_ygRatingCache!['ratingValue'] != null || _ygRatingCache!['ratingCount'] != null) {
            print('[aggregateRating] HavitScraper: YG Digital API ile rating bulundu -> ratingValue: ${_ygRatingCache!['ratingValue']}, ratingCount: ${_ygRatingCache!['ratingCount']}');
          }
          return _ygRatingCache;
        }
      }
    } catch (e) {
      print('[aggregateRating] HavitScraper: YG Digital API isteğinde hata: $e');
    }
    return null;
  }

  @override
  Future<double?> scrapeRatingValue(dom.Document document) async {
    print('[aggregateRating] HavitScraper: ratingValue aranıyor...');
    
    // 1. Havit/Ticimax Özel DOM Seçicileri (.ctgry-avg, .comment-count.ctgry-avg, .right-stars .comment-count)
    final ratingSelectors = [
      '.comment-count.ctgry-avg',
      '.ctgry-avg',
      '.right-stars .comment-count',
      '.comment-stars-container .comment-count',
      '.yg-comment-rating-score',
    ];

    for (final sel in ratingSelectors) {
      final el = document.querySelector(sel);
      if (el != null) {
        final text = el.text.trim().replaceAll(',', '.');
        if (!text.startsWith('(')) {
          final parsed = double.tryParse(text);
          if (parsed != null && parsed > 0 && parsed <= 5.0) {
            print('[aggregateRating] HavitScraper: DOM ($sel) ile ratingValue bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    // Fallback: Tüm .comment-count elementleri arasından parantez içermeyen ilk geçerli puanı bul
    final allCommentCounts = document.querySelectorAll('.comment-count');
    for (final el in allCommentCounts) {
      final text = el.text.trim().replaceAll(',', '.');
      if (!text.startsWith('(') && !text.endsWith(')')) {
        final parsed = double.tryParse(text);
        if (parsed != null && parsed > 0 && parsed <= 5.0) {
          print('[aggregateRating] HavitScraper: DOM (.comment-count) ile ratingValue bulundu: $parsed');
          return parsed;
        }
      }
    }

    // 2. Ticimax Script Model (var productDetailModel = {"rating": 4.75, ...})
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('productDetailModel') && text.contains('rating')) {
        final match = RegExp(r'"rating"\s*:\s*([\d]+(?:[.,]\d+)?)').firstMatch(text);
        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '.');
          final parsed = raw != null ? double.tryParse(raw) : null;
          if (parsed != null && parsed > 0 && parsed <= 5.0) {
            print('[aggregateRating] HavitScraper: Ticimax script ile ratingValue bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    // 3. YG Digital API (Ham HTML'de widget olmadığı için API'den doğrudan çek)
    final ygRating = await _fetchYgDigitalRating(document);
    if (ygRating != null && ygRating['ratingValue'] != null) {
      return ygRating['ratingValue'] as double;
    }

    // 4. Genel DOM microdata fallback
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
        print('[aggregateRating] HavitScraper: DOM (itemprop) ile ratingValue bulundu: $parsed');
        return parsed;
      }
    }

    // 5. JSON-LD Fallback
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] HavitScraper: JSON-LD fallback ile ratingValue bulundu: $val');
        return val;
      }
    }

    print('[aggregateRating] HavitScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  Future<int?> scrapeRatingCount(dom.Document document) async {
    print('[aggregateRating] HavitScraper: ratingCount/reviewCount aranıyor...');
    
    // 1. DOM Seçicileri (.comment-count-left, #divYorumSayisi, .comment-count parantezli)
    final countElList = [
      document.querySelector('.comment-count-left'),
      document.querySelector('#divYorumSayisi'),
      document.querySelector('[itemprop="reviewCount"]'),
      document.querySelector('[itemprop="ratingCount"]'),
      document.querySelector('.review-count'),
      document.querySelector('.rating-count'),
    ];

    for (final el in countElList) {
      if (el != null) {
        final text = el.localName == 'meta'
            ? (el.attributes['content'] ?? '')
            : el.text;
        final match = RegExp(r'(\d+)').firstMatch(text);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null && parsed > 0) {
            print('[aggregateRating] HavitScraper: DOM (${el.attributes['id'] ?? el.className}) ile ratingCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    // Parantez içindeki yorum sayısını ara: e.g. <div class="comment-count">(26)</div>
    final allCommentCounts = document.querySelectorAll('.comment-count');
    for (final el in allCommentCounts) {
      final text = el.text.trim();
      if (text.contains('(') || text.contains(')')) {
        final match = RegExp(r'(\d+)').firstMatch(text);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null && parsed > 0) {
            print('[aggregateRating] HavitScraper: DOM (.comment-count parantezli) ile ratingCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    // Yorum kartlarının sayısını say (.yg-comment-review)
    final reviews = document.querySelectorAll('.yg-comment-review');
    if (reviews.isNotEmpty) {
      print('[aggregateRating] HavitScraper: DOM (.yg-comment-review list) ile ratingCount bulundu: ${reviews.length}');
      return reviews.length;
    }

    // 2. YG Digital API (Ham HTML'de widget olmadığı için API'den doğrudan çek)
    final ygRating = await _fetchYgDigitalRating(document);
    if (ygRating != null && ygRating['ratingCount'] != null) {
      return ygRating['ratingCount'] as int;
    }

    // 3. JSON-LD Fallback
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] HavitScraper: JSON-LD fallback ile ratingCount bulundu: $cnt');
        return cnt;
      }
    }

    print('[aggregateRating] HavitScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] HavitScraper: brand (marka) aranıyor...');
    
    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] HavitScraper: JSON-LD ile brand bulundu: $brand');
        return brand;
      }
    }

    // 2. Ticimax Script Model ("brandName":"Havit")
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('brandName')) {
        final match = RegExp(r'"brandName"\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final bName = match.group(1)?.trim();
          if (bName != null && bName.isNotEmpty) {
            print('[aggregateRating] HavitScraper: Ticimax script ile brand bulundu: $bName');
            return bName;
          }
        }
      }
    }

    // 3. DOM Microdata
    final brandDiv = document.querySelector('[itemprop="brand"]');
    if (brandDiv != null) {
      final metaName = brandDiv.querySelector('meta[itemprop="name"]');
      if (metaName != null) {
        final content = metaName.attributes['content']?.trim();
        if (content != null && content.isNotEmpty) {
          print('[aggregateRating] HavitScraper: DOM (itemprop brand) ile brand bulundu: $content');
          return content;
        }
      }
      final text = brandDiv.text.trim();
      if (text.isNotEmpty) {
        print('[aggregateRating] HavitScraper: DOM (itemprop brand text) ile brand bulundu: $text');
        return text;
      }
    }

    // 4. Meta Tag / Diğer DOM
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
        print('[aggregateRating] HavitScraper: DOM meta fallback ile brand bulundu: $clean');
        return clean;
      }
    }

    print('[aggregateRating] HavitScraper: brand bulunamadı (null)');
    return null;
  }
}
