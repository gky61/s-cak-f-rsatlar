import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'link_preview_service.dart';
import '../utils/deal_url_detector.dart';

enum UrlValidationResult {
  valid,
  invalidFormat,
  domainNotAllowed,
  notProductUrl,
}

class _ParsedAllowlistData {
  final Map<String, List<String>> stores;
  final Set<String> domains;
  final Map<String, List<String>> rawRules;

  const _ParsedAllowlistData({
    required this.stores,
    required this.domains,
    required this.rawRules,
  });
}

_ParsedAllowlistData _parseAllowlistJson(String jsonStr) {
  final Map<String, dynamic> data = json.decode(jsonStr) as Map<String, dynamic>;
  final Map<String, List<String>> parsedStores = {};
  final Set<String> parsedDomains = {};
  final Map<String, List<String>> parsedRawRules = {};

  if (data.containsKey('stores') && data['stores'] is Map) {
    final Map<String, dynamic> storesJson = data['stores'] as Map<String, dynamic>;
    storesJson.forEach((key, value) {
      if (value is List) {
        final domainList = value.map((e) => e.toString().toLowerCase()).toList();
        parsedStores[key] = domainList;
        parsedDomains.addAll(domainList);
      }
    });
  }

  if (data.containsKey('product_path_rules') && data['product_path_rules'] is Map) {
    final Map<String, dynamic> rulesJson = data['product_path_rules'] as Map<String, dynamic>;
    rulesJson.forEach((storeKey, patterns) {
      if (patterns is List) {
        parsedRawRules[storeKey] = patterns.map((p) => p.toString()).toList();
      }
    });
  }

  return _ParsedAllowlistData(
    stores: parsedStores,
    domains: parsedDomains,
    rawRules: parsedRawRules,
  );
}

class DomainAllowlistService {
  /// Fallback (yedek) 20 mağaza tanımı
  static const Map<String, List<String>> _fallbackStores = {
    "trendyol": ["trendyol.com"],
    "hepsiburada": ["hepsiburada.com"],
    "amazon_tr": ["amazon.com.tr"],
    "n11": ["n11.com"],
    "pazarama": ["pazarama.com"],
    "idefix": ["idefix.com"],
    "pttavm": ["pttavm.com"],
    "teknosa": ["teknosa.com"],
    "mediamarkt_tr": ["mediamarkt.com.tr"],
    "vatan_bilgisayar": ["vatanbilgisayar.com"],
    "itopya": ["itopya.com"],
    "incehesap": ["incehesap.com"],
    "mavi": ["mavi.com"],
    "defacto_tr": ["defacto.com.tr"],
    "zara_tr": ["zara.com"],
    "mango_tr": ["mango.com"],
    "beymen": ["beymen.com"],
    "migros": ["migros.com.tr"],
    "getir": ["getir.com"],
    "havit_turkiye": ["havitstore.com.tr"],
    "boyner": ["boyner.com.tr"],
    "gamer_gen": ["gamer.gen.tr"],
    "gaming_gen": ["gaming.gen.tr"]
  };

  static final Set<String> _fallbackAllowedDomains = _fallbackStores.values
      .expand((domains) => domains)
      .map((d) => d.toLowerCase())
      .toSet();

  static Future<void>? _initFuture;
  static Map<String, List<String>>? _dynamicStores;
  static Set<String>? _dynamicAllowedDomains;
  static Map<String, List<String>>? _rawProductPathRules;
  static final Map<String, List<RegExp>> _compiledProductPathRules = {};

  /// Aktif kullanılan mağazalar haritası
  static Map<String, List<String>> get stores => _dynamicStores ?? _fallbackStores;

  /// Aktif kullanılan izin verilen domain'ler kümesi
  static Set<String> get allowedDomains => _dynamicAllowedDomains ?? _fallbackAllowedDomains;

  /// JSON dosyasından dinamik allowlist yükleme (Arka plan isolate + memoized paylaşımlı Future)
  static Future<void> initialize() {
    if (_dynamicStores != null) return Future.value();
    if (_initFuture != null) return _initFuture!;

    _initFuture = _doInitialize().then((_) {
      // Başarıyla tamamlandı
    }).catchError((e) {
      _initFuture = null; // Hata durumunda yeniden denemeye izin ver
      if (kDebugMode) {
        print('⚠️ DomainAllowlistService initialize hatası: $e');
      }
    });

    return _initFuture!;
  }

  static Future<void> _doInitialize() async {
    const candidatePaths = [
      'assets/data/domain_allowlist_extended.json',
    ];

    for (final path in candidatePaths) {
      try {
        final jsonStr = await rootBundle.loadString(path);
        final parsedData = await compute(_parseAllowlistJson, jsonStr);

        if (parsedData.stores.isNotEmpty) {
          _dynamicStores = parsedData.stores;
          _dynamicAllowedDomains = parsedData.domains;
          _rawProductPathRules = parsedData.rawRules;
          _compiledProductPathRules.clear();

          if (kDebugMode) {
            print('✅ DomainAllowlistService dinamik olarak yüklendi ($path): '
                '${parsedData.stores.length} mağaza, ${parsedData.domains.length} domain, '
                '${parsedData.rawRules.length} kural (arka plan isolate)');
          }
          break;
        }
      } catch (e) {
        // Test ortamında Flutter binding yoksa veya dosya yoksa sessizce sıradakine geç
      }
    }
  }

  /// Bilinen kısa link veya yönlendirme domainleri listesi
  static const List<String> _shortLinkDomains = [
    'ty.gl',
    'hb.biz',
    'amzn.eu',
    'amzn.to',
    'link.amazon',
    'amzlinks.in',
    'sl.n11.com',
    'n11.com/n/',
    'publicis.link',
    'bit.ly',
    'tinyurl.com',
    't.co',
    'rebrand.ly',
    'rdrtr.com',
    'onelink.me',
    'paylaskazan.teknosa.com',
    'rdr.btrck.com',
    'incehesap.com/u/'
  ];

  /// Verilen URL'nin domain'inin (hostname) allowlist'te olup olmadığını kontrol eder.
  /// Hostname exact match ("trendyol.com") veya subdomain match (".trendyol.com") olmalıdır.
  static bool isDomainAllowed(String urlStr) {
    if (urlStr.trim().isEmpty) return false;

    if (_dynamicStores == null && _initFuture == null) {
      unawaited(initialize());
    }

    try {
      final normalized = DealUrlDetector.extractUrl(urlStr) ?? urlStr.trim();
      Uri uri = Uri.parse(normalized);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$normalized');
      }
      final host = uri.host.toLowerCase();
      if (host.isEmpty) return false;

      for (final allowed in allowedDomains) {
        if (host == allowed || host.endsWith('.$allowed')) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  static Future<UrlValidationResult> validateUrl(String urlStr) async {
    if (urlStr.trim().isEmpty) return UrlValidationResult.invalidFormat;
    
    await initialize();

    final normalized = DealUrlDetector.extractUrl(urlStr) ?? urlStr.trim();

    try {
      final trimmed = normalized.trim();
      Uri uri = Uri.parse(trimmed);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$trimmed');
      }
      final host = uri.host.toLowerCase();
      if (host.isEmpty) return UrlValidationResult.invalidFormat;
    } catch (_) {
      return UrlValidationResult.invalidFormat;
    }

    // Kısa link veya yönlendirmeleri çöz
    String resolved = normalized;
    try {
      final linkPreviewService = LinkPreviewService();
      resolved = linkPreviewService.extractAdjustFallback(normalized);
      if (resolved.toLowerCase().contains('sl.n11.com/n/') || resolved.toLowerCase().contains('n11.com/n/')) {
        resolved = await linkPreviewService.resolveN11ShortLink(resolved);
      }
      
      final lowerResolved = resolved.toLowerCase();
      final isShort = _shortLinkDomains.any((domain) => lowerResolved.contains(domain));
      if (isShort) {
        resolved = await linkPreviewService.resolveUrlRedirects(resolved);
      }
    } catch (_) {
      return UrlValidationResult.invalidFormat;
    }

    if (!isDomainAllowed(resolved)) {
      return UrlValidationResult.domainNotAllowed;
    }

    if (!isProductUrl(resolved)) {
      return UrlValidationResult.notProductUrl;
    }

    return UrlValidationResult.valid;
  }

  /// URL bir kısa link ise yönlendirmeyi çözer ve nihai URL'yi allowlist ile kontrol eder.
  /// Ayrıca ürün sayfası kontrolü de yapar.
  static Future<bool> isResolvedUrlAllowed(String urlStr) async {
    final result = await validateUrl(urlStr);
    return result == UrlValidationResult.valid;
  }

  /// URL'ye karşılık gelen mağaza adını verir
  static String? getStoreNameForUrl(String urlStr) {
    if (urlStr.trim().isEmpty) return null;
    try {
      final normalized = DealUrlDetector.extractUrl(urlStr) ?? urlStr.trim();
      final trimmed = normalized.trim();
      Uri uri = Uri.parse(trimmed);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$trimmed');
      }
      final host = uri.host.toLowerCase();
      if (host.isEmpty) return null;

      for (final entry in stores.entries) {
        for (final allowed in entry.value) {
          if (host == allowed || host.endsWith('.$allowed')) {
            return entry.key;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// URL'nin bir ürün sayfası olup olmadığını kontrol eder.
  /// 
  /// Çalışma mantığı:
  /// 1. URL'den pathname çıkarılır
  /// 2. storeKey tespit edilir (getStoreNameForUrl)
  /// 3. product_path_rules[storeKey] kuralları alınır
  /// 4. Kural tanımlı DEĞİLSE → BYPASS (izin ver)
  /// 5. Kural boş diziyse → BYPASS (bilinçli bypass, izin ver)
  /// 6. Kural varsa → pathname ANY regex ile eşleşiyor mu? Evet → ürün sayfası, Hayır → değil
  static bool isProductUrl(String urlStr) {
    if (urlStr.trim().isEmpty) return false;

    if (_dynamicStores == null && _initFuture == null) {
      unawaited(initialize());
    }

    try {
      final normalized = DealUrlDetector.extractUrl(urlStr) ?? urlStr.trim();
      final trimmed = normalized.trim();
      Uri uri = Uri.parse(trimmed);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$trimmed');
      }

      final storeKey = getStoreNameForUrl(trimmed);
      if (storeKey == null) {
        // Allowlist'te domain bulunamadı, bu aşamaya gelmemeli ama güvenlik için false
        return false;
      }

      // product_path_rules yüklenmemişse → BYPASS
      if (_rawProductPathRules == null) {
        return true;
      }

      // İlgili mağaza için regex'leri sadece talep edildiğinde (lazy) derle ve önbelleğe al
      List<RegExp>? rules = _compiledProductPathRules[storeKey];
      if (rules == null) {
        final rawPatterns = _rawProductPathRules![storeKey];
        if (rawPatterns == null) {
          return true; // Kural tanımlanmamış mağaza → bypass
        }
        if (rawPatterns.isEmpty) {
          _compiledProductPathRules[storeKey] = const [];
          return true; // Bilinçli olarak boş bırakılmış → bypass
        }
        rules = rawPatterns
            .map((p) => RegExp(p, caseSensitive: false))
            .toList(growable: false);
        _compiledProductPathRules[storeKey] = rules;
      }

      if (rules.isEmpty) {
        return true;
      }

      // Pathname'e regex uygula (query parametreleri ve hash hariç)
      final pathname = uri.path;
      for (final regex in rules) {
        if (regex.hasMatch(pathname)) {
          return true;
        }
      }

      // Hiçbir regex eşleşmedi → ürün sayfası değil
      return false;
    } catch (_) {
      return false;
    }
  }
}
