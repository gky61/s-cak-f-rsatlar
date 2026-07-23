import 'dart:async';
import 'dart:convert';
import 'package:html/dom.dart' as dom;

/// Mağaza özelinde HTML kazıma arayüzü
abstract class BaseProductScraper {
  /// Scraper'ın sorumlu olduğu alan adı (domain keyword)
  String get domain;
  
  /// Verilen URL'in bu scraper tarafından işlenip işlenemeyeceğini denetler
  bool canHandle(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains(domain);
  }

  /// Belgeyi analiz ederek ürün görsel URL'sini döndürür
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  });

  /// Belgeyi analiz ederek ürün başlığını döndürür
  String? scrapeTitle(dom.Document document) => null;

  /// Belgeyi analiz ederek ürün fiyatını döndürür
  Future<double?> scrapePrice(dom.Document document) async => null;

  /// Belgeyi analiz ederek ürün açıklamasını döndürür
  FutureOr<String?> scrapeDescription(dom.Document document) => null;

  /// Belgeyi analiz ederek ürün fiyatının altında gösterilecek kampanya/CRM etiketini döndürür
  FutureOr<String?> scrapePriceLabel(dom.Document document) => null;

  /// Belgeyi analiz ederek ürünün indirimsiz (eski/liste) fiyatını döndürür
  FutureOr<double?> scrapeOriginalPrice(dom.Document document, double? currentPrice) => null;

  /// Belgeyi analiz ederek ürün puanını döndürür (ör. 4.8)
  FutureOr<double?> scrapeRatingValue(dom.Document document) => null;

  /// Belgeyi analiz ederek ürün değerlendirme sayısını döndürür (ör. 1173)
  FutureOr<int?> scrapeRatingCount(dom.Document document) => null;

  /// Belgeyi analiz ederek ürün markasını döndürür (ör. Apple)
  String? scrapeBrand(dom.Document document) => null;

  /// Fiyat metnini temizleyip double değere dönüştüren yardımcı metot
  double? parsePriceText(String priceText) {
    String cleaned = priceText
        .replaceAll('TL', '')
        .replaceAll('₺', '')
        .replaceAll(r'$', '')
        .replaceAll('€', '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
        
    if (cleaned.isEmpty) return null;
    
    if (cleaned.contains('.') && cleaned.contains(',')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    } else if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length == 2 && parts[1].length == 3) {
        cleaned = cleaned.replaceAll('.', '');
      }
    }
    
    return double.tryParse(cleaned);
  }

  /// JSON-LD şemasından Product nesnesini bulur
  Map<String, dynamic>? findProductJsonLd(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
        try {
          // Sunucuların JSON-LD içerisine hatalı yerleştirdiği raw satır sonu (\n, \r, \t) karakterlerini temizliyoruz.
          final sanitizedText = script.text
              .replaceAll('\r\n', ' ')
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll('\t', ' ');
          final data = jsonDecode(sanitizedText);
          final product = findProductInJson(data);
          if (product != null) return product;
        } catch (e) {
          print('[aggregateRating] JSON-LD parse uyarısı: $e (Uzunluk: ${script.text.length})');
        }
      }
    }
    return null;
  }

  /// JSON içinde recursive olarak Product tipindeki nesneyi arar
  Map<String, dynamic>? findProductInJson(dynamic json) {
    if (json is Map) {
      if (json['@type'] == 'Product' || json['@type'] == 'http://schema.org/Product' ||
          json['@type'] == 'ProductGroup' || json['@type'] == 'http://schema.org/ProductGroup') {
        return Map<String, dynamic>.from(json);
      }
      if (json['@graph'] != null && json['@graph'] is List) {
        for (final item in json['@graph'] as List) {
          final res = findProductInJson(item);
          if (res != null) return res;
        }
      }
      for (final value in json.values) {
        if (value is Map || value is List) {
          final res = findProductInJson(value);
          if (res != null) return res;
        }
      }
    } else if (json is List) {
      for (final item in json) {
        final res = findProductInJson(item);
        if (res != null) return res;
      }
    }
    return null;
  }

  /// Product şemasından görsel URL'sini çeker
  String? extractImageFromProductJson(dynamic imageField) {
    if (imageField is String) return imageField;
    if (imageField is List && imageField.isNotEmpty) {
      return extractImageFromProductJson(imageField.first);
    }
    if (imageField is Map) {
      final urlVal = imageField['url'] ?? imageField['contentUrl'];
      if (urlVal != null) {
        return extractImageFromProductJson(urlVal);
      }
    }
    return null;
  }

  /// Product şemasından fiyatı çeker
  double? extractPriceFromProductJson(Map<String, dynamic> product) {
    final offers = product['offers'];
    if (offers == null) return null;
    
    if (offers is Map) {
      final priceVal = offers['price'] ?? offers['lowPrice'] ?? offers['highPrice'];
      if (priceVal != null) {
        final parsed = double.tryParse(priceVal.toString());
        if (parsed != null) return parsed;
        return parsePriceText(priceVal.toString());
      }
    } else if (offers is List && offers.isNotEmpty) {
      double? lowest;
      for (final offer in offers) {
        if (offer is Map) {
          final priceVal = offer['price'];
          if (priceVal != null) {
            final p = double.tryParse(priceVal.toString()) ?? parsePriceText(priceVal.toString());
            if (p != null && (lowest == null || p < lowest)) {
              lowest = p;
            }
          }
        }
      }
      return lowest;
    }
    return null;
  }

  /// Belgeyi analiz ederek ürünün kırıntı (breadcrumb) listesini döndürür
  List<String> scrapeBreadcrumbs(dom.Document document) => [];

  /// Product JSON-LD'den aggregateRating nesnesini ve ratingValue/ratingCount değerlerini çeker
  Map<String, dynamic>? extractRatingFromProductJson(Map<String, dynamic> product) {
    final ratingObj = product['aggregateRating'];
    if (ratingObj is Map) {
      final rawValue = ratingObj['ratingValue'];
      final rawCount = ratingObj['ratingCount'] ?? ratingObj['reviewCount'];
      
      final double? value = rawValue != null ? double.tryParse(rawValue.toString().replaceAll(',', '.')) : null;
      final int? count = rawCount != null ? int.tryParse(rawCount.toString()) : null;
      
      return {
        'ratingValue': value,
        'ratingCount': count,
      };
    }
    return null;
  }

  /// Product JSON-LD'den brand (marka) ismini çeker
  String? extractBrandFromProductJson(Map<String, dynamic> product) {
    final brandObj = product['brand'];
    if (brandObj is String && brandObj.trim().isNotEmpty) {
      return brandObj.trim();
    }
    if (brandObj is Map) {
      final nameVal = brandObj['name'] ?? brandObj['@name'];
      if (nameVal != null && nameVal.toString().trim().isNotEmpty) {
        return nameVal.toString().trim();
      }
    }
    return null;
  }
}
