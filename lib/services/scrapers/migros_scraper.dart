import 'dart:async';
import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class MigrosScraper extends BaseProductScraper {
  static final Expando<Map<String, dynamic>> _infoExpando = Expando<Map<String, dynamic>>('migrosInfo');
  static final Expando<String> _urlExpando = Expando<String>('migrosUrl');

  Map<String, dynamic>? _lastProductInfo;
  String? _lastUrl;


  @override
  String get domain => 'migros.com.tr';

  Map<String, dynamic>? _getInfo(dom.Document document) {
    return _infoExpando[document] ?? _lastProductInfo;
  }

  String? _getUrl(dom.Document document) {
    return _urlExpando[document] ??
        _lastUrl ??
        document.querySelector('link[rel="canonical"]')?.attributes['href'];
  }

  /// URL veya DOM'dan Migros ürün ID'sini (SKU) çıkarır
  String? extractProductId(String url, [dom.Document? document]) {
    // 1. URL pattern: -p-([a-fA-F0-9]+) (query ve fragment öncesi path sınırı ile)
    final cleanPath = Uri.tryParse(url)?.path ?? '';
    final searchUrl = cleanPath.isNotEmpty ? cleanPath : url;

    final matchHex = RegExp(r'-p-([a-fA-F0-9]+)(?:[/?#]|$)', caseSensitive: false).firstMatch(searchUrl);
    if (matchHex != null) {
      final hexStr = matchHex.group(1)!;
      final dec = int.tryParse(hexStr, radix: 16);
      if (dec != null && dec > 0) return dec.toString();
      final decFallback = int.tryParse(hexStr);
      if (decFallback != null && decFallback > 0) return decFallback.toString();
    }

    // 2. Canonical URL (document varsa)
    if (document != null) {
      final canonical = document.querySelector('link[rel="canonical"]')?.attributes['href'] ?? '';
      final canonicalPath = Uri.tryParse(canonical)?.path ?? '';
      final searchCanonical = canonicalPath.isNotEmpty ? canonicalPath : canonical;

      final matchCanonical = RegExp(r'-p-([a-fA-F0-9]+)(?:[/?#]|$)', caseSensitive: false).firstMatch(searchCanonical);
      if (matchCanonical != null) {
        final hexStr = matchCanonical.group(1)!;
        final dec = int.tryParse(hexStr, radix: 16);
        if (dec != null && dec > 0) return dec.toString();
        final decFallback = int.tryParse(hexStr);
        if (decFallback != null && decFallback > 0) return decFallback.toString();
      }

      // 3. og:image or meta tag: product/(\d+)
      final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ?? '';
      final matchImg = RegExp(r'product\/(\d+)').firstMatch(ogImage);
      if (matchImg != null) return matchImg.group(1);
    }

    // 4. URL containing product/(\d+)
    final matchUrlProduct = RegExp(r'product\/(\d+)').firstMatch(url);
    if (matchUrlProduct != null) return matchUrlProduct.group(1);

    return null;
  }

  /// URL slug'ından temiz ve okunaklı başlık türetir (Örn: soke-un-1-kg -> Söke Un 1 Kg)
  String? parseSlugTitle(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;

      String lastSegment = segments.last;
      lastSegment = lastSegment.replaceAll(RegExp(r'-p-[a-fA-F0-9]+$', caseSensitive: false), '');
      lastSegment = lastSegment.replaceAll(RegExp(r'\.(html|htm|php)$', caseSensitive: false), '');

      if (lastSegment.trim().isEmpty) return null;

      final words = lastSegment.split(RegExp(r'[-_]')).where((w) => w.isNotEmpty).map((w) {
        if (w.isEmpty) return '';
        final lower = w.toLowerCase();
        // Türkçe özel harf eşlemeleri
        if (lower == 'soke') return 'Söke';
        if (lower == 'kadin') return 'Kadın';
        if (lower == 'erkek') return 'Erkek';
        if (lower == 'cikolata') return 'Çikolata';
        if (lower == 'sut') return 'Süt';
        if (lower == 'seker') return 'Şeker';
        if (lower == 'cay') return 'Çay';
        if (lower == 'yag') return 'Yağ';
        return lower[0].toUpperCase() + lower.substring(1);
      }).toList();

      if (words.isEmpty) return null;
      return words.join(' ');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> prepare({required dom.Document document, required String url}) async {
    _lastUrl = url;
    _urlExpando[document] = url;
    _lastProductInfo = null;

    final productId = extractProductId(url, document);
    if (productId != null) {
      final info = await _fetchScreensApi(productId, url: url);
      if (info != null) {
        _infoExpando[document] = info;
        _lastProductInfo = info;
      }
    }
  }

  double _extractCandidatePrice(Map<String, dynamic> info) {
    final prices = <double>[];
    for (final key in ['shownPrice', 'loyaltyPrice', 'salePrice']) {
      dynamic val = info[key];
      if (val is String) val = num.tryParse(val);
      if (val is num && val > 0) {
        prices.add(val.toDouble());
      }
    }
    if (prices.isEmpty) return double.infinity;
    prices.sort();
    return prices.first;
  }

  double _scoreCandidate(Map<String, dynamic> info) {
    dynamic shownPrice = info['shownPrice'];
    if (shownPrice is String) shownPrice = num.tryParse(shownPrice);
    dynamic regularPrice = info['regularPrice'];
    if (regularPrice is String) regularPrice = num.tryParse(regularPrice);
    dynamic loyaltyPrice = info['loyaltyPrice'];
    if (loyaltyPrice is String) loyaltyPrice = num.tryParse(loyaltyPrice);
    dynamic salePrice = info['salePrice'];
    if (salePrice is String) salePrice = num.tryParse(salePrice);
    dynamic discountRate = info['discountRate'];
    if (discountRate is String) discountRate = num.tryParse(discountRate);

    final effectivePrice = _extractCandidatePrice(info);

    final hasDiscount = (
      (loyaltyPrice is num && regularPrice is num && loyaltyPrice < regularPrice) ||
      (shownPrice is num && regularPrice is num && shownPrice < regularPrice) ||
      (loyaltyPrice is num && salePrice is num && loyaltyPrice < salePrice) ||
      (shownPrice is num && salePrice is num && shownPrice < salePrice) ||
      (discountRate is num && discountRate > 0) ||
      (info['badges'] is List && (info['badges'] as List).any((b) => b is Map && (b['name'] == 'PRICE_PROMOTED' || b['name'] == 'CROSS_PROMOTED'))) ||
      (info['crmDiscountTags'] is List && (info['crmDiscountTags'] as List).isNotEmpty)
    );

    double score = 0.0;
    if (hasDiscount) {
      score = 1000.0 + ((discountRate is num) ? discountRate.toDouble() : 1.0);
      if (regularPrice is num && effectivePrice < regularPrice) {
        score += (regularPrice.toDouble() - effectivePrice) / 100.0;
      }
    }
    return score;
  }

  void _mergeMissingFields(Map<String, dynamic> target, Map<String, dynamic> source) {
    if ((target['images'] == null || (target['images'] is List && (target['images'] as List).isEmpty)) &&
        source['images'] != null) {
      target['images'] = source['images'];
    }
    if (target['brand'] == null && source['brand'] != null) {
      target['brand'] = source['brand'];
    }
    if ((target['description'] == null || target['description'].toString().trim().isEmpty) &&
        source['description'] != null) {
      target['description'] = source['description'];
    }
    if ((target['badges'] == null || (target['badges'] is List && (target['badges'] as List).isEmpty)) &&
        source['badges'] != null) {
      target['badges'] = source['badges'];
    }
    if ((target['crmDiscountTags'] == null || (target['crmDiscountTags'] is List && (target['crmDiscountTags'] as List).isEmpty)) &&
        source['crmDiscountTags'] != null) {
      target['crmDiscountTags'] = source['crmDiscountTags'];
    }
    if (target['category'] == null && source['category'] != null) {
      target['category'] = source['category'];
    }
    if ((target['categoryAscendants'] == null || (target['categoryAscendants'] is List && (target['categoryAscendants'] as List).isEmpty)) &&
        source['categoryAscendants'] != null) {
      target['categoryAscendants'] = source['categoryAscendants'];
    }
  }

  Future<Map<String, dynamic>?> _fetchScreensApi(String productId, {String? url}) async {
    final effectiveUrl = url ?? _lastUrl ?? '';
    final isHemenUrl = effectiveUrl.toLowerCase().contains('/hemen/');

    Future<Map<String, dynamic>?> fetchSingle(String endpoint) async {
      try {
        final response = await http.get(
          Uri.parse(endpoint),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
            'X-Pwa': 'true',
          },
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json is Map && json['successful'] != false && json['data'] != null) {
            final data = json['data'];
            if (data is Map && data['storeProductInfoDTO'] != null) {
              return Map<String, dynamic>.from(data['storeProductInfoDTO'] as Map);
            }
          }
        }
      } catch (_) {}
      return null;
    }

    // Hem genel (/rest/products/) hem express/hemen (/rest/hemen/) kanallarını paralel sorgula.
    // Migros sadakat/Money kampanyaları bazı ürünlerde hemen kanalında, bazı ürünlerde genel kanalda yayımlanır.
    final results = await Future.wait([
      fetchSingle('https://www.migros.com.tr/rest/products/screens/$productId'),
      fetchSingle('https://www.migros.com.tr/rest/hemen/products/screens/$productId'),
    ]);

    var infoGeneral = results[0];
    var infoHemen = results[1];

    // Yedek kontrol: Eğer iki ana uç nokta da yanıt vermediyse sanalmarket ucunu dene
    if (infoGeneral == null && infoHemen == null) {
      infoGeneral = await fetchSingle('https://www.migros.com.tr/rest/sanalmarket/products/screens/$productId');
    }

    if (infoGeneral == null && infoHemen == null) return null;
    if (infoGeneral != null && infoHemen == null) return infoGeneral;
    if (infoGeneral == null && infoHemen != null) return infoHemen;

    // Her iki uç nokta da veri döndüyse: Money veya kampanya indirimi içeren kanalı seç
    final genScore = _scoreCandidate(infoGeneral!);
    final hemenScore = _scoreCandidate(infoHemen!);

    Map<String, dynamic> chosen;
    Map<String, dynamic> alternate;

    if (hemenScore > genScore) {
      chosen = infoHemen;
      alternate = infoGeneral;
    } else if (genScore > hemenScore) {
      chosen = infoGeneral;
      alternate = infoHemen;
    } else {
      final genPrice = _extractCandidatePrice(infoGeneral);
      final hemenPrice = _extractCandidatePrice(infoHemen);
      if (hemenPrice < genPrice) {
        chosen = infoHemen;
        alternate = infoGeneral;
      } else if (genPrice < hemenPrice) {
        chosen = infoGeneral;
        alternate = infoHemen;
      } else {
        if (isHemenUrl) {
          chosen = infoHemen;
          alternate = infoGeneral;
        } else {
          chosen = infoGeneral;
          alternate = infoHemen;
        }
      }
    }

    _mergeMissingFields(chosen, alternate);
    return chosen;
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. Screens API (Öncelikli - Sanal Market ve Hemen için gerçek yüksek çözünürlüklü ürün görseli)
    final info = _getInfo(document);
    if (info != null && info['images'] is List) {
      final images = info['images'] as List;
      for (final imgObj in images) {
        if (imgObj is Map && imgObj['urls'] is Map) {
          final urls = imgObj['urls'] as Map;
          final rawUrl = urls['PRODUCT_HD'] ?? urls['PRODUCT_DETAIL'] ?? urls['PRODUCT_LIST'];
          if (rawUrl != null && rawUrl.toString().isNotEmpty) {
            final resolved = resolveImageUrl(rawUrl.toString(), url);
            if (resolved != null && !isLogoUrl(resolved)) {
              log('✅ Migros görseli Screens API ile bulundu: $resolved');
              return resolved;
            }
          }
        }
      }
    }

    // 2. JSON-LD şemasından görsel çekmeyi dene (Hemen SSR veya SSR fallback)
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

    // 3. Open Graph meta tag'i dene (isLogoUrl ile sanalmarket-seo bannerları filtrelenir)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Migros görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 4. DOM Seçicileri (Fallback 2)
    final imgElements = document.querySelectorAll(
      'img[class*="product-image"], img.product-image, .product-details img, img[class*="product"]',
    );
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
    // 1. Screens API (En doğru ve tam ürün adı)
    final info = _getInfo(document);
    if (info != null && info['name'] != null) {
      final apiTitle = info['name'].toString().trim();
      final lower = apiTitle.toLowerCase();
      if (apiTitle.isNotEmpty && lower != 'migros' && lower != 'migros sanalmarket') {
        return apiTitle;
      }
    }

    // 2. JSON-LD şemasından
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      final ldTitle = productJson['name'].toString().trim();
      final lower = ldTitle.toLowerCase();
      if (ldTitle.isNotEmpty && lower != 'migros' && lower != 'migros sanalmarket') {
        return ldTitle;
      }
    }

    // 3. DOM Seçicileri
    final titleEl = document.querySelector('h1.product-title') ?? document.querySelector('h1');
    if (titleEl != null) {
      final domTitle = titleEl.text.trim();
      final lower = domTitle.toLowerCase();
      if (domTitle.isNotEmpty && lower != 'migros' && lower != 'migros sanalmarket') {
        return domTitle;
      }
    }

    // 4. URL slug'ından türetme (Sanalmarket SPA veya 404 sayfalarında 'Migros' başlığını engelleme)
    final effectiveUrl = _getUrl(document);
    if (effectiveUrl != null) {
      final slugTitle = parseSlugTitle(effectiveUrl);
      if (slugTitle != null && slugTitle.isNotEmpty) {
        return slugTitle;
      }
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Screens API (Cache veya doğrudan API çağrısı)
    Map<String, dynamic>? info = _getInfo(document);
    if (info == null) {
      final effectiveUrl = _getUrl(document);
      final productId = extractProductId(effectiveUrl ?? '', document);
      if (productId != null) {
        info = await _fetchScreensApi(productId, url: effectiveUrl);
        if (info != null) {
          _infoExpando[document] = info;
          _lastProductInfo = info;
        }
      }
    }

    if (info != null) {
      final prices = <double>[];
      for (final key in ['shownPrice', 'loyaltyPrice', 'salePrice']) {
        dynamic p = info[key];
        if (p is String) p = num.tryParse(p);
        if (p is num && p > 0) {
          prices.add(p.toDouble() / 100);
        }
      }
      if (prices.isNotEmpty) {
        prices.sort();
        return prices.first;
      }
    }

    // 2. JSON-LD şemasından fiyat çekmeyi dene
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    // 3. DOM Seçicileri (Fallback)
    final priceEl = document.querySelector('#new-amount') ?? document.querySelector('.amount');
    if (priceEl != null) {
      final val = parsePriceText(priceEl.text);
      if (val != null && val > 0) {
        return val;
      }
    }

    return null;
  }

  @override
  Future<double?> scrapeOriginalPrice(dom.Document document, double? currentPrice) async {
    if (currentPrice == null || currentPrice <= 0) return null;

    final candidates = <double>[];

    // 1. Screens API (Primary for Migros)
    Map<String, dynamic>? info = _getInfo(document);
    if (info == null) {
      final effectiveUrl = _getUrl(document);
      final productId = extractProductId(effectiveUrl ?? '', document);
      if (productId != null) {
        info = await _fetchScreensApi(productId, url: effectiveUrl);
        if (info != null) {
          _infoExpando[document] = info;
          _lastProductInfo = info;
        }
      }
    }

    if (info != null) {
      for (final k in ['regularPrice', 'salePrice']) {
        dynamic regVal = info[k];
        if (regVal is String) regVal = num.tryParse(regVal);
        if (regVal is num && regVal > 0) {
          final reg = regVal.toDouble() / 100;
          if (reg > currentPrice) candidates.add(reg);
        }
      }
      if (info['badges'] is List) {
        for (final badge in info['badges']) {
          if (badge is Map && badge['name'] == 'PRICE_PROMOTED' && badge['value'] != null) {
            final val = parsePriceText(badge['value'].toString());
            if (val != null && val > currentPrice) candidates.add(val);
          }
        }
      }
    }

    // 2. DOM: .single-price-amount (Migros specific non-Money price)
    final singlePriceElements = document.querySelectorAll(
      '.single-price-amount, [class*="single-price-amount"]',
    );
    for (final el in singlePriceElements) {
      final val = parsePriceText(el.text);
      if (val != null && val > currentPrice) {
        candidates.add(val);
      }
    }

    // 3. DOM: Standard strikethrough / old price selectors
    final strikeSelectors = [
      '.old-price',
      '[class*="old-price"]',
      '[class*="original-price"]',
      '[class*="crossed-price"]',
      'del',
      's',
    ];
    for (final selector in strikeSelectors) {
      for (final el in document.querySelectorAll(selector)) {
        final val = parsePriceText(el.text);
        if (val != null && val > currentPrice) {
          candidates.add(val);
        }
      }
    }

    if (candidates.isEmpty) return null;
    final filtered = candidates.where((c) => c > currentPrice && c <= currentPrice * 5).toList();
    if (filtered.isEmpty) return null;
    filtered.sort();
    return filtered.first;
  }

  String _cleanDescription(String desc) {
    String cleaned = desc.replaceAll(RegExp(r'<[^>]*>'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  @override
  Future<String?> scrapeDescription(dom.Document document) async {
    String crmPrefix = '';

    // 1. Screens API üzerinden CRM indirim etiketi
    Map<String, dynamic>? info = _getInfo(document);
    if (info == null) {
      final effectiveUrl = _getUrl(document);
      final productId = extractProductId(effectiveUrl ?? '', document);
      if (productId != null) {
        info = await _fetchScreensApi(productId, url: effectiveUrl);
        if (info != null) {
          _infoExpando[document] = info;
          _lastProductInfo = info;
        }
      }
    }

    if (info != null && info['crmDiscountTags'] is List) {
      final crmTags = info['crmDiscountTags'] as List;
      if (crmTags.isNotEmpty && crmTags[0] is Map && crmTags[0]['tag'] != null) {
        final crmText = crmTags[0]['tag'].toString().trim().toUpperCase();
        if (crmText.isNotEmpty && crmText != 'İYİ FİYAT' && crmText != 'IYI FIYAT' && !crmText.contains('SADECE MİGROS')) {
          crmPrefix = '**$crmText**';
        }
      }
    }

    // 2. DOM'dan CRM etiketi kontrolü
    if (crmPrefix.isEmpty) {
      final crmEl = document.querySelector('.product-label.crm');
      if (crmEl != null) {
        final crmText = crmEl.text.trim().toUpperCase();
        if (crmText.isNotEmpty && crmText != 'İYİ FİYAT' && crmText != 'IYI FIYAT' && !crmText.contains('SADECE MİGROS')) {
          crmPrefix = '**$crmText**';
        }
      }
    }

    String baseDesc = '';

    // 3. Screens API'den açıklama
    if (info != null && info['description'] != null && info['description'].toString().isNotEmpty) {
      baseDesc = _cleanDescription(info['description'].toString());
    }

    // 4. JSON-LD şemasından açıklama çekmeyi dene
    if (baseDesc.isEmpty) {
      final productJson = findProductJsonLd(document);
      if (productJson != null && productJson['description'] != null) {
        baseDesc = _cleanDescription(productJson['description'].toString());
      } else {
        final scripts = document.querySelectorAll('script');
        for (final script in scripts) {
          final type = script.attributes['type']?.trim().toLowerCase();
          if (type == 'application/ld+json') {
            try {
              final sanitizedText =
                  script.text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
              final data = jsonDecode(sanitizedText);
              if (data is Map && data['description'] != null) {
                baseDesc = _cleanDescription(data['description'].toString());
                break;
              }
            } catch (_) {}
          }
        }
      }
    }

    // 5. DOM meta description
    if (baseDesc.isEmpty) {
      final descEl =
          document.querySelector('meta[name="description"]') ??
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
  FutureOr<String?> scrapePriceLabel(dom.Document document) async {
    // 1. Screens API (En doğru ve net veri kaynağı)
    Map<String, dynamic>? info = _getInfo(document);
    if (info == null) {
      final effectiveUrl = _getUrl(document);
      final productId = extractProductId(effectiveUrl ?? '', document);
      if (productId != null) {
        info = await _fetchScreensApi(productId, url: effectiveUrl);
        if (info != null) {
          _infoExpando[document] = info;
          _lastProductInfo = info;
        }
      }
    }

    if (info != null) {
      // A. crmDiscountTags (Örn: "3 Al 2'si Money Hediye", "1 ALANA 1 BEDAVA", "50 TL Sepette İndirim")
      if (info['crmDiscountTags'] is List) {
        final crmTags = info['crmDiscountTags'] as List;
        if (crmTags.isNotEmpty && crmTags[0] is Map && crmTags[0]['tag'] != null) {
          final rawTag = crmTags[0]['tag'].toString().trim();
          final upperTag = rawTag.toUpperCase();
          if (upperTag != 'İYİ FİYAT' &&
              upperTag != 'IYI FIYAT' &&
              !upperTag.contains('SADECE MİGROS') &&
              rawTag.isNotEmpty) {
            return rawTag;
          }
        }
      }

      // B. badges listesi (CROSS_PROMOTED vs PRICE_PROMOTED)
      final badges = info['badges'] is List ? (info['badges'] as List) : [];
      for (final b in badges) {
        if (b is Map) {
          final bName = (b['name'] ?? '').toString();
          final bValue = (b['value'] ?? '').toString().trim();
          // 3 Al 2 Öde, 2 Al 1 Öde, 2.'si %50 İndirimli vb.
          if (bName == 'CROSS_PROMOTED' && bValue.isNotEmpty) {
            return bValue;
          }
          // Money indirimli fiyat rozeti
          if (bName == 'PRICE_PROMOTED') {
            return 'Money ile';
          }
        }
      }

      // C. Sadakat/Money fiyat farkı veya indirim oranı kontrolü
      dynamic shownPrice = info['shownPrice'];
      if (shownPrice is String) shownPrice = num.tryParse(shownPrice);
      dynamic regularPrice = info['regularPrice'];
      if (regularPrice is String) regularPrice = num.tryParse(regularPrice);
      dynamic salePrice = info['salePrice'];
      if (salePrice is String) salePrice = num.tryParse(salePrice);
      dynamic loyaltyPrice = info['loyaltyPrice'];
      if (loyaltyPrice is String) loyaltyPrice = num.tryParse(loyaltyPrice);
      dynamic discountRate = info['discountRate'];
      if (discountRate is String) discountRate = num.tryParse(discountRate);

      if ((loyaltyPrice is num && regularPrice is num && loyaltyPrice < regularPrice) ||
          (loyaltyPrice is num && salePrice is num && loyaltyPrice < salePrice) ||
          (shownPrice is num && salePrice is num && shownPrice < salePrice) ||
          (shownPrice is num && regularPrice is num && shownPrice < regularPrice) ||
          (discountRate is num && discountRate > 0)) {
        return 'Money ile';
      }
    }

    // 2. DOM Kontrolü (Header/Footer menüleri hariç ürünün kendi CRM etiketi)
    final crmEl = document.querySelector('.product-label.crm, .product-badges .badge');
    if (crmEl != null) {
      final rawText = crmEl.text.trim();
      final crmText = rawText.toUpperCase();
      if (crmText.isNotEmpty &&
          crmText != 'İYİ FİYAT' &&
          crmText != 'IYI FIYAT' &&
          !crmText.contains('SADECE MİGROS') &&
          crmText.length <= 50) {
        return rawText;
      }
    }

    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    // 1. Screens API
    final info = _getInfo(document);
    if (info != null && info['brand'] is Map) {
      final brandObj = info['brand'] as Map;
      if (brandObj['name'] != null && brandObj['name'].toString().trim().isNotEmpty) {
        return brandObj['name'].toString().trim();
      }
    }

    // 2. JSON-LD
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['brand'] != null) {
      if (productJson['brand'] is String) {
        return productJson['brand'].toString().trim();
      } else if (productJson['brand'] is Map && productJson['brand']['name'] != null) {
        return productJson['brand']['name'].toString().trim();
      }
    }

    // 3. DOM
    final brandEl = document.querySelector('a[class*="brand"], .brand-name');
    if (brandEl != null && brandEl.text.trim().isNotEmpty) {
      return brandEl.text.trim();
    }

    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    // 1. Screens API
    final info = _getInfo(document);
    if (info != null) {
      final List<String> list = [];
      if (info['categoryAscendants'] is List) {
        for (final c in info['categoryAscendants'] as List) {
          if (c is Map && c['name'] != null && c['name'].toString().trim().isNotEmpty) {
            list.add(c['name'].toString().trim());
          }
        }
      }
      if (info['category'] is Map) {
        final c = info['category'] as Map;
        if (c['name'] != null && c['name'].toString().trim().isNotEmpty) {
          list.add(c['name'].toString().trim());
        }
      }
      if (list.isNotEmpty) return list;
    }

    // 2. JSON-LD Fallback
    final scripts = document.querySelectorAll('script');
    final productTitle = scrapeTitle(document) ?? '';

    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
        try {
          final sanitizedText =
              script.text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
          final data = jsonDecode(sanitizedText);
          final breadcrumbs = _extractBreadcrumbsFromJson(data, productTitle);
          if (breadcrumbs.isNotEmpty) {
            return breadcrumbs;
          }
        } catch (_) {}
      }
    }

    // 3. DOM Fallback
    final breadcrumbElements = document.querySelectorAll(
      '.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a',
    );
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' &&
              lower != 'ana sayfa' &&
              !lower.contains('migros') &&
              text != productTitle &&
              text.length < 50) {
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

      if (json['@type'] == 'Product' ||
          json['@type'] == 'http://schema.org/Product' ||
          json['@type'] == 'ProductGroup' ||
          json['@type'] == 'http://schema.org/ProductGroup') {
        final categoryField = json['category'];
        if (categoryField is String && categoryField.isNotEmpty) {
          final parts = categoryField
              .split(RegExp(r'\s*>\s*|\s*/\s*'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .where((e) {
                final lower = e.toLowerCase();
                return lower != 'anasayfa' &&
                    lower != 'ana sayfa' &&
                    !lower.contains('migros') &&
                    e != productTitle &&
                    e.length < 50;
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
                  return lower != 'anasayfa' &&
                      lower != 'ana sayfa' &&
                      !lower.contains('migros') &&
                      e != productTitle &&
                      e.length < 50;
                })
                .toList();
            if (parts.isNotEmpty) return parts;
          }
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
