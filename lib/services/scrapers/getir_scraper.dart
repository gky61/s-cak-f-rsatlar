import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class GetirScraper extends BaseProductScraper {
  @override
  String get domain => 'getir.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('getir.com');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. Next.js JSON-LD/Next data (Öncelikli)
    final pData = _getProductData(document);
    if (pData != null) {
      // Önce picURLs listesindeki ilk resmi almayı dene
      final picUrls = pData['picURLs'];
      if (picUrls is List && picUrls.isNotEmpty) {
        final img = picUrls.first.toString();
        final resolved = resolveImageUrl(img, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('   - Getir görseli JSON picURLs ile bulundu: $resolved');
          return resolved;
        }
      }
      
      // Alternatif olarak squareThumbnailURL
      final sqThumb = pData['squareThumbnailURL'];
      if (sqThumb != null && sqThumb.toString().isNotEmpty) {
        final resolved = resolveImageUrl(sqThumb.toString(), url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('   - Getir görseli JSON squareThumbnailURL ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. og:image meta tag (Fallback)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                    document.querySelector('meta[name="twitter:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('   - Getir görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    final pData = _getProductData(document);
    if (pData != null) {
      final name = pData['name'];
      if (name is String && name.isNotEmpty) {
        return name.trim();
      }
      final shortName = pData['shortName'];
      if (shortName is String && shortName.isNotEmpty) {
        return shortName.trim();
      }
    }

    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'] ??
                    document.querySelector('title')?.text;
    if (ogTitle != null && ogTitle.isNotEmpty && ogTitle.toLowerCase() != 'null') {
      String title = ogTitle;
      if (title.contains(' - Getir')) {
        title = title.replaceAll(' - Getir', '');
      }
      if (title.contains(' | Getir')) {
        title = title.replaceAll(' | Getir', '');
      }
      return title.trim();
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    final pData = _getProductData(document);
    if (pData != null) {
      final priceVal = pData['price'];
      if (priceVal != null) {
        final parsed = double.tryParse(priceVal.toString());
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }
    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    final pData = _getProductData(document);
    if (pData != null) {
      final shortDesc = pData['shortDescription'];
      if (shortDesc is String && shortDesc.isNotEmpty) {
        return shortDesc.trim();
      }
    }

    final ogDesc = document.querySelector('meta[name="description"]')?.attributes['content'] ??
                   document.querySelector('meta[property="og:description"]')?.attributes['content'];
    if (ogDesc != null && ogDesc.isNotEmpty && ogDesc.toLowerCase() != 'null') {
      return ogDesc.trim();
    }

    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final pData = _getProductData(document);
    if (pData == null) return [];
    
    final List<String> breadcrumbs = [];
    
    // GetirListing altındaki kategorileri bulup product categoryIds/subCategoryIds ile eşleştirme
    final cats = _getCategoriesList(document);
    if (cats != null && cats.isNotEmpty) {
      final productCatIds = pData['categoryIds'];
      final productSubcatIds = pData['subCategoryIds'];
      if (productCatIds is List) {
        for (final cat in cats) {
          if (cat is Map && productCatIds.contains(cat['id'])) {
            final catName = cat['name'];
            if (catName is String && catName.isNotEmpty) {
              breadcrumbs.add(catName);
            }
            final subcats = cat['subCategories'];
            if (subcats is List && productSubcatIds is List) {
              for (final sub in subcats) {
                if (sub is Map && productSubcatIds.contains(sub['id'])) {
                  final subName = sub['name'];
                  if (subName is String && subName.isNotEmpty) {
                    breadcrumbs.add(subName);
                  }
                }
              }
            }
          }
        }
      }
    }
    
    return breadcrumbs;
  }

  Map<String, dynamic>? _getProductData(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final id = script.attributes['id'];
      if (id == '__NEXT_DATA__' || script.text.contains('"productDetail"')) {
        try {
          final data = jsonDecode(script.text);
          final pData = _findProductDetailData(data);
          if (pData != null) return pData;
        } catch (_) {}
      }
    }
    return null;
  }

  Map<String, dynamic>? _findProductDetailData(dynamic json) {
    if (json is Map) {
      if (json.containsKey('productDetail') && json['productDetail'] is Map) {
        final pd = json['productDetail'];
        if (pd is Map && pd.containsKey('data') && pd['data'] is Map) {
          final pData = pd['data'];
          if (pData.containsKey('name') && pData.containsKey('price')) {
            return Map<String, dynamic>.from(pData);
          }
        }
      }
      for (final value in json.values) {
        final res = _findProductDetailData(value);
        if (res != null) return res;
      }
    } else if (json is List) {
      for (final item in json) {
        final res = _findProductDetailData(item);
        if (res != null) return res;
      }
    }
    return null;
  }

  List<dynamic>? _getCategoriesList(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final id = script.attributes['id'];
      if (id == '__NEXT_DATA__' || script.text.contains('"getirListing"')) {
        try {
          final data = jsonDecode(script.text);
          return _findCategoriesList(data);
        } catch (_) {}
      }
    }
    return null;
  }

  List<dynamic>? _findCategoriesList(dynamic json) {
    if (json is Map) {
      if (json.containsKey('getirListing') && json['getirListing'] is Map) {
        final gl = json['getirListing'];
        if (gl is Map && gl.containsKey('categories') && gl['categories'] is Map) {
          final cats = gl['categories'];
          if (cats is Map && cats.containsKey('data') && cats['data'] is List) {
            return cats['data'] as List;
          }
        }
      }
      for (final value in json.values) {
        final res = _findCategoriesList(value);
        if (res != null) return res;
      }
    } else if (json is List) {
      for (final item in json) {
        final res = _findCategoriesList(item);
        if (res != null) return res;
      }
    }
    return null;
  }
}
