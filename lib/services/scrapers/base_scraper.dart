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

  /// Kazıma öncesinde hazırlık yapabilmesi (ör. SPA veya REST API sorgusu) için çağrılır
  Future<void> prepare({required dom.Document document, required String url}) async {}

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

  /// Belgeyi analiz ederek kanonik ürün URL'sini döndürür (<link rel="canonical"> veya <meta property="og:url">)
  String? scrapeCanonicalUrl(dom.Document document, String url) {
    try {
      String? canonical = document.querySelector('link[rel="canonical"]')?.attributes['href'];
      if (canonical == null || canonical.trim().isEmpty) {
        canonical = document.querySelector('meta[property="og:url"]')?.attributes['content'];
      }
      if (canonical == null || canonical.trim().isEmpty) return null;
      canonical = canonical.trim();

      String? resolved;
      if (canonical.startsWith('http://') || canonical.startsWith('https://')) {
        resolved = canonical;
      } else if (canonical.startsWith('//')) {
        resolved = 'https:$canonical';
      } else {
        try {
          final base = Uri.parse(url);
          resolved = base.resolve(canonical).toString();
        } catch (_) {
          return null;
        }
      }

      final pageHost = Uri.parse(url).host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
      final canonHost = Uri.parse(resolved).host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
      final isDomainMatch = pageHost == canonHost ||
          pageHost.endsWith('.$canonHost') ||
          canonHost.endsWith('.$pageHost');
      if (!isDomainMatch) {
        return null;
      }
      return resolved;
    } catch (_) {
      return null;
    }
  }

  // --- Fiyat Ayrıştırma için Performans ve DoS/ReDoS Korumalı Statik Regex Tanımları ---
  static final RegExp _rawDupRegex = RegExp(r'^(.+?(?:TL|₺|TRY|\$|€))\s*\1+$', caseSensitive: false);
  static final RegExp _currencyPriceRegex = RegExp(r'(?:^|[^\d])((?:\d{1,3}(?:\.\d{3})+|\d+)(?:[.,]\d{1,2})?)\s*(?:TL|₺|TRY|\$|€)', caseSensitive: false);
  static final RegExp _cleanCurrencyRegex = RegExp(r'[₺$€\s]|TL|tl|Tl|TRY|try', caseSensitive: false);
  static final RegExp _decimalDupRegex = RegExp(r'^(\d+[.,]\d{1,2})\1+$');
  static final RegExp _integerDupRegex = RegExp(r'^(\d{4,})\1+$');
  static final RegExp _hasLettersOrWordsRegex = RegExp(r'[^\d.,]');
  static final RegExp _genericPriceRegex = RegExp(r'(?:^|[^\d])((?:\d{1,3}(?:\.\d{3})+|\d+)(?:[.,]\d{1,2})?)(?=[^\d]|$)');

  /// Fiyat metnini temizleyip double değere dönüştüren yardımcı metot
  double? parsePriceText(String priceText) {
    final trimmed = priceText.trim();
    if (trimmed.isEmpty || trimmed.length > 300) return null;

    // 1. Ham metin üzerinde para birimli tekrar kontrolü:
    // Örn: '269,91TL269,91TL' veya '99TL99TL' veya '38160 ₺ 38160 ₺'
    final rawDupMatch = _rawDupRegex.firstMatch(trimmed);
    if (rawDupMatch != null && rawDupMatch.group(1) != null) {
      return parsePriceText(rawDupMatch.group(1)!);
    }

    // 2. Para birimi ve gereksiz karakterleri temizle
    String cleaned = trimmed.replaceAll(_cleanCurrencyRegex, '').trim();
    if (cleaned.isEmpty) return null;

    // 3. Dublike fiyat savunması:
    // a) Ondalıklı dublike: örn. 269,91269,91 veya 299.90299.90 (ondalık ayırıcı ZORUNLU)
    final decDupMatch = _decimalDupRegex.firstMatch(cleaned);
    if (decDupMatch != null && decDupMatch.group(1) != null) {
      cleaned = decDupMatch.group(1)!;
    } else {
      // b) Tam sayı dublike: Yalnızca en az 4 basamaklı tam sayılar tekrar ettiğinde (örn. 3816038160 -> 38160)
      // 99, 88, 999, 1010, 2525 gibi geçerli perakende fiyatlarının bozulmasını kesinlikle engeller.
      final intDupMatch = _integerDupRegex.firstMatch(cleaned);
      if (intDupMatch != null && intDupMatch.group(1) != null) {
        cleaned = intDupMatch.group(1)!;
      }
    }

    // 4. Metin içinde halen yabancı harfler/kelimeler kalmışsa (örn: 'Sepette %10 indirimle 150 TL' veya 'Sepette 269,91'):
    if (_hasLettersOrWordsRegex.hasMatch(cleaned)) {
      // A) Öncelikle yanında para birimi olan gerçek fiyat kalıbını ara (yüzde indirimleri '%10' vb. elenir)
      final currencyMatches = _currencyPriceRegex.allMatches(trimmed).toList();
      if (currencyMatches.isNotEmpty) {
        final lastMatch = currencyMatches.last.group(1);
        if (lastMatch != null && lastMatch.trim() != trimmed) {
          return parsePriceText(lastMatch);
        }
      }

      // B) Para birimsiz genel sayı kalıbı (metindeki en son geçerli fiyat adayı)
      final genericMatches = _genericPriceRegex.allMatches(trimmed).toList();
      if (genericMatches.isNotEmpty) {
        for (int i = genericMatches.length - 1; i >= 0; i--) {
          final candidate = genericMatches[i].group(1);
          if (candidate != null && candidate.isNotEmpty) {
            final parsedCandidate = parsePriceText(candidate);
            if (parsedCandidate != null && parsedCandidate > 0) {
              return parsedCandidate;
            }
          }
        }
      }
    }

    // 5. Sayısal Ayrıştırma (Türkçe / Uluslararası Format Uyumu)
    final hasDot = cleaned.contains('.');
    final hasComma = cleaned.contains(',');

    if (hasDot && hasComma) {
      final lastDotIndex = cleaned.lastIndexOf('.');
      final lastCommaIndex = cleaned.lastIndexOf(',');
      if (lastCommaIndex > lastDotIndex) {
        // Türkçe format: 1.234,56 veya 1.234.567,89 -> noktalar binlik, virgül ondalık
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Uluslararası/ABD formatı: 1,234.56 veya 1,234,567.89 -> virgüller binlik, nokta ondalık
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.length == 2) {
        if (parts[1].length == 3 && parts[0].isNotEmpty && parts[0].length <= 3) {
          // Binlik ayırıcı: 6,447 -> 6447
          cleaned = cleaned.replaceAll(',', '');
        } else {
          // Ondalık ayırıcı: 423,99 -> 423.99 veya 75,5 -> 75.5
          cleaned = cleaned.replaceAll(',', '.');
        }
      } else {
        // Çoklu virgül örn: 1,234,567
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length == 2) {
        if (parts[1].length == 3 && parts[0].isNotEmpty && parts[0].length <= 3) {
          // Binlik ayırıcı: 1.798 -> 1798 veya 48.020 -> 48020
          cleaned = cleaned.replaceAll('.', '');
        }
      } else {
        // Çoklu nokta örn: 1.234.567
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    final val = double.tryParse(cleaned);
    if (val == null || val.isNaN || val.isInfinite) return null;
    return val;
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
          // ignore: avoid_print
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
        final str = priceVal.toString();
        if (str.contains(',')) {
          return parsePriceText(str);
        }
        final parsed = double.tryParse(str);
        if (parsed != null) return parsed;
        return parsePriceText(str);
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
