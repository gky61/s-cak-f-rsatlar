import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import '../base_affiliate_adapter.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// İncehesap Paylaştıkça Kazan (Affiliate / /u/{code}/) gelir ortaklığı adaptörü.
/// Doğrudan WAF bypass (WhatsApp User-Agent) ve canlı AJAX oturumu (PHPSESSID) ile dinamik link üretir.
class IncehesapAffiliateAdapter extends BaseAffiliateAdapter {
  /// Varsayılan doğrulanmış İncehesap Paylaştıkça Kazan oturum çerezi
  static const String defaultSessionCookie =
      'PHPSESSID=4jcp9cn663qg4mah0vqd3a1rkb; cki1=ao2er02bt4kj918fssb3i16svn;';

  /// İncehesap Paylaştıkça Kazan oturum çerezi (PHPSESSID)
  final String sessionCookie;

  IncehesapAffiliateAdapter({
    String? sessionCookie,
    bool enabled = true,
  })  : sessionCookie = (sessionCookie?.trim().isNotEmpty ?? false)
            ? sessionCookie!.trim()
            : defaultSessionCookie {
    isEnabled = enabled;
  }

  @override
  String get storeName => 'İncehesap';

  @override
  String get storeKey => 'incehesap';

  @override
  bool get isAffiliateReady => true;

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('incehesap.com');
  }

  @override
  bool isAlreadyAffiliate(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!host.contains('incehesap.com')) return false;

    // /u/{10-karakterli-kod}/ formatı İncehesap'ın Paylaştıkça Kazan imza linkidir
    final path = uri.path;
    final match = RegExp(r'^/u/([a-zA-Z0-9_-]+)/?$', caseSensitive: false).firstMatch(path);
    return match != null;
  }

  @override
  String convert(Uri uri) {
    // 1. Kill-switch: Eğer adaptör kapalıysa temiz kanonik linke fallback yap
    if (!isEnabled) {
      _log('🛑 [AFFILIATE-TEST] İncehesap affiliate şalteri KAPALI. Temiz kanonik URL\'e dönüştürülüyor.');
      return cleanProductUrl(uri);
    }

    // 2. Link zaten bir Paylaştıkça Kazan kısa linki ise (/u/{kod}/) aynen koru
    if (isAlreadyAffiliate(uri)) {
      _log('✨ [AFFILIATE-TEST] Link zaten İncehesap Paylaştıkça Kazan linki: $uri');
      var path = uri.path;
      if (!path.endsWith('/')) path = '$path/';
      return '${uri.scheme}://${uri.host}$path';
    }

    // 3. Senkron convert çağrısında varsayılan olarak temiz kanonik linki dön (Canlı üretim asenkron generateAffiliateLink ile yapılır)
    return cleanProductUrl(uri);
  }

  /// Verilen ürün ID için İncehesap AJAX API'si üzerinden oturum çereziyle canlı /u/ linki üretir.
  Future<String?> generateAffiliateLink(String productId, {String? customCookie}) async {
    final effectiveCookie = (customCookie?.trim().isNotEmpty ?? false)
        ? customCookie!.trim()
        : (sessionCookie.isNotEmpty ? sessionCookie : defaultSessionCookie);

    try {
      _log('🔄 [AFFILIATE-TEST] İncehesap AJAX ile ürün ID $productId için canlı Paylaştıkça Kazan linki üretiliyor...');
      final uri = Uri.parse('https://www.incehesap.com/uye/paylastikca-kazan/ajax/update.php');
      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Content-Type': 'application/json;charset=UTF-8',
          'User-Agent': 'WhatsApp/2.23.4.15 A',
          'Origin': 'https://www.incehesap.com',
          'Referer': 'https://www.incehesap.com/',
          'Cookie': effectiveCookie.startsWith('PHPSESSID=') ? effectiveCookie : 'PHPSESSID=$effectiveCookie',
        },
        body: jsonEncode({
          'action': 'getSingleProductLink',
          'urunId': int.tryParse(productId) ?? productId,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = response.body;
        try {
          final jsonData = jsonDecode(body);
          if (jsonData is Map) {
            final rawLink = (jsonData['url'] ?? jsonData['link'] ?? jsonData['affiliateUrl'])?.toString();
            if (rawLink != null && rawLink.isNotEmpty) {
              final jsonMatch = RegExp(r'/u/([a-zA-Z0-9_-]+)/?', caseSensitive: false).firstMatch(rawLink);
              if (jsonMatch != null) {
                final code = jsonMatch.group(1)!;
                final generatedUrl = 'https://www.incehesap.com/u/$code/';
                _log('🎉 [AFFILIATE-TEST] İncehesap AJAX başarılı: $generatedUrl (${jsonData['text'] ?? ''})');
                return generatedUrl;
              }
            }
          }
        } catch (_) {}

        final match = RegExp(r'(?:/|\\/)u(?:/|\\/)([a-zA-Z0-9_-]+)(?:/|\\/)?', caseSensitive: false).firstMatch(body);
        if (match != null) {
          final code = match.group(1)!;
          final generatedUrl = 'https://www.incehesap.com/u/$code/';
          _log('🎉 [AFFILIATE-TEST] İncehesap AJAX regex başarılı: $generatedUrl');
          return generatedUrl;
        }
      }
    } catch (e) {
      _log('⚠️ [AFFILIATE-TEST] İncehesap doğrudan istek hatası: $e');
    }

    return null;
  }

  /// URL'den İncehesap benzersiz ürün ID'sini ayıklar (ör. ...-fiyati-91918/ -> "91918")
  String? extractProductId(Uri uri) {
    // 1. Path pattern: -fiyati-12345/
    final path = uri.path;
    final match = RegExp(r'-fiyati-(\d+)(?:/|$)', caseSensitive: false).firstMatch(path);
    if (match != null) {
      return match.group(1);
    }

    // 2. Query params: urunId, id, productId
    final queryParams = uri.queryParameters;
    if (queryParams.containsKey('urunId')) return queryParams['urunId'];
    if (queryParams.containsKey('productId')) return queryParams['productId'];
    if (queryParams.containsKey('id')) return queryParams['id'];

    return null;
  }

  /// URL'deki takip ve sorgu parametrelerini temizleyerek kanonik ürün URL'sini döner
  String cleanProductUrl(Uri uri) {
    try {
      final cleanPath = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
      final cleanUri = Uri(
        scheme: uri.scheme.isNotEmpty ? uri.scheme : 'https',
        host: uri.host.isNotEmpty ? uri.host : 'www.incehesap.com',
        path: cleanPath,
      );
      return cleanUri.toString();
    } catch (_) {
      return uri.toString();
    }
  }
}
