import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'link_preview_service.dart';

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
    "boyner": ["boyner.com.tr"]
  };

  static final Set<String> _fallbackAllowedDomains = _fallbackStores.values
      .expand((domains) => domains)
      .map((d) => d.toLowerCase())
      .toSet();

  static Map<String, List<String>>? _dynamicStores;
  static Set<String>? _dynamicAllowedDomains;
  static Map<String, List<RegExp>>? _productPathRules;
  static bool _isInitializing = false;

  /// Aktif kullanılan mağazalar haritası
  static Map<String, List<String>> get stores => _dynamicStores ?? _fallbackStores;

  /// Aktif kullanılan izin verilen domain'ler kümesi
  static Set<String> get allowedDomains => _dynamicAllowedDomains ?? _fallbackAllowedDomains;

  /// JSON dosyasından dinamik allowlist yükleme
  static Future<void> initialize() async {
    if (_dynamicStores != null || _isInitializing) return;
    _isInitializing = true;

    final candidatePaths = [
      'assets/data/domain_allowlist_extended.json',
    ];

    for (final path in candidatePaths) {
      try {
        final jsonStr = await rootBundle.loadString(path);
        final Map<String, dynamic> data = json.decode(jsonStr);
        if (data.containsKey('stores') && data['stores'] is Map) {
          final Map<String, dynamic> storesJson = data['stores'];
          final Map<String, List<String>> parsedStores = {};
          final Set<String> parsedDomains = {};

          storesJson.forEach((key, value) {
            if (value is List) {
              final domainList = value.map((e) => e.toString().toLowerCase()).toList();
              parsedStores[key] = domainList;
              parsedDomains.addAll(domainList);
            }
          });

          if (parsedStores.isNotEmpty) {
            _dynamicStores = parsedStores;
            _dynamicAllowedDomains = parsedDomains;

            // product_path_rules alanını da yükle
            if (data.containsKey('product_path_rules') && data['product_path_rules'] is Map) {
              final Map<String, dynamic> rulesJson = data['product_path_rules'];
              final Map<String, List<RegExp>> parsedRules = {};
              rulesJson.forEach((storeKey, patterns) {
                if (patterns is List) {
                  parsedRules[storeKey] = patterns
                      .map((p) => RegExp(p.toString(), caseSensitive: false))
                      .toList();
                }
              });
              _productPathRules = parsedRules;
              if (kDebugMode) {
                print('✅ Product Path Rules yüklendi: ${parsedRules.length} mağaza kuralı');
              }
            }

            if (kDebugMode) {
              print('✅ DomainAllowlistService dinamik olarak yüklendi ($path): ${parsedStores.length} mağaza, ${parsedDomains.length} domain');
            }
            break;
          }
        }
      } catch (e) {
        // Test ortamında Flutter binding yoksa veya dosya yoksa sessizce sıradakine geç
      }
    }

    _isInitializing = false;
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
    'onelink.me'
  ];

  /// Verilen URL'nin domain'inin (hostname) allowlist'te olup olmadığını kontrol eder.
  /// Hostname exact match ("trendyol.com") veya subdomain match (".trendyol.com") olmalıdır.
  static bool isDomainAllowed(String urlStr) {
    if (urlStr.trim().isEmpty) return false;

    if (_dynamicStores == null && !_isInitializing) {
      unawaited(initialize());
    }

    try {
      final trimmed = urlStr.trim();
      Uri uri = Uri.parse(trimmed);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$trimmed');
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

  /// URL bir kısa link ise yönlendirmeyi çözer ve nihai URL'yi allowlist ile kontrol eder.
  /// Ayrıca ürün sayfası kontrolü de yapar.
  static Future<bool> isResolvedUrlAllowed(String urlStr) async {
    if (urlStr.trim().isEmpty) return false;
    
    await initialize();

    // Doğrudan eşleşiyorsa çözmeye gerek kalmadan onay ver
    if (isDomainAllowed(urlStr)) {
      // Domain allowlist'te ama ürün sayfası mı kontrol et
      if (!isProductUrl(urlStr)) {
        if (kDebugMode) {
          print('🛑 [PRODUCT PATH REJECT] URL bir ürün sayfası değil: $urlStr');
        }
        return false;
      }
      return true;
    }

    // Kısa link yönlendirmesini çöz ve tekrar kontrol et
    try {
      final linkPreviewService = LinkPreviewService();
      String resolved = linkPreviewService.extractAdjustFallback(urlStr);
      if (resolved.toLowerCase().contains('sl.n11.com/n/') || resolved.toLowerCase().contains('n11.com/n/')) {
        resolved = await linkPreviewService.resolveN11ShortLink(resolved);
      }
      
      final lowerResolved = resolved.toLowerCase();
      final isShort = _shortLinkDomains.any((domain) => lowerResolved.contains(domain));
      if (isShort) {
        resolved = await linkPreviewService.resolveUrlRedirects(resolved);
      }
      
      if (!isDomainAllowed(resolved)) return false;

      // Çözülen URL ürün sayfası mı kontrol et
      if (!isProductUrl(resolved)) {
        if (kDebugMode) {
          print('🛑 [PRODUCT PATH REJECT] Çözülen URL bir ürün sayfası değil: $resolved');
        }
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// URL'ye karşılık gelen mağaza adını verir
  static String? getStoreNameForUrl(String urlStr) {
    if (urlStr.trim().isEmpty) return null;
    try {
      final trimmed = urlStr.trim();
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

    if (_dynamicStores == null && !_isInitializing) {
      unawaited(initialize());
    }

    try {
      final trimmed = urlStr.trim();
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
      if (_productPathRules == null) {
        return true;
      }

      final rules = _productPathRules![storeKey];

      // Kural tanımlı değilse → BYPASS (tanımlanmamış mağaza, filtre yok)
      if (rules == null) {
        return true;
      }

      // Kural boş diziyse → BYPASS (bilinçli olarak filtresiz bırakılmış)
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
