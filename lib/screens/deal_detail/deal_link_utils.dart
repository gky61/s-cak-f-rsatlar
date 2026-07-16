import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_app_check/firebase_app_check.dart';

import '../../firebase_options.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Affiliate link dönüştürme, mağaza tespiti ve kısa link çözme yardımcıları.
class DealLinkUtils {
  DealLinkUtils._();

  // Affiliate Link Configuration
  static const Map<String, Map<String, String>> affiliateConfig = {
    'trendyol': {
      'boutiqueId': '', // Trendyol Boutique ID'nizi buraya ekleyin
    },
    'hepsiburada': {
      'utmSource': 'linkgelir', // Hepsiburada Link Gelir için genellikle 'linkgelir' kullanılır
    },
    'n11': {
      'refId': '', // N11 Referans ID'nizi buraya ekleyin
    },
    'amazon': {
      'tag': '', // Amazon Associate Tag'inizi buraya ekleyin
    },
    'gittigidiyor': {
      'affiliateId': '', // GittiGidiyor Affiliate ID'nizi buraya ekleyin
    },
  };

  /// Kısa linki Cloud Function aracılığıyla çözer.
  static Future<String?> resolveShortLink(String shortUrl) async {
    try {
      final projectId = DefaultFirebaseOptions.flavorProjectId;
      final functionsUrl =
          'https://us-central1-$projectId.cloudfunctions.net/resolveShortLink';
      final uri = Uri.parse('$functionsUrl?url=${Uri.encodeComponent(shortUrl)}');
      
      String? token;
      try {
        token = await FirebaseAppCheck.instance.getToken();
      } catch (e) {
        _log('App Check token alınamadı: $e');
      }

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'X-Firebase-AppCheck': token,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['resolvedUrl'] != null) {
          return data['resolvedUrl'] as String;
        }
      }
      return null;
    } catch (e) {
      _log('Kısa link çözme hatası: $e');
      return null;
    }
  }

  /// URL'den mağaza ismini tespit eder.
  static String detectStoreFromUrl(String url) {
    if (url.isEmpty) return 'Bilinmeyen';

    try {
      final uri = Uri.parse(url);
      final hostname = uri.host.toLowerCase();

      if (hostname.contains('trendyol.com')) return 'Trendyol';
      if (hostname.contains('hepsiburada.com')) return 'Hepsiburada';
      if (hostname.contains('n11.com')) return 'N11';
      if (hostname.contains('amazon.com')) return 'Amazon';
      if (hostname.contains('gittigidiyor.com')) return 'GittiGidiyor';
      if (hostname.contains('havitstore.com.tr')) return 'Havit';
      if (hostname.contains('migros.com.tr')) return 'Migros';
      if (hostname.contains('getir.com')) return 'Getir';

      return 'Bilinmeyen';
    } catch (e) {
      return 'Bilinmeyen';
    }
  }

  /// Orijinal URL'yi affiliate linkine dönüştürür.
  static String convertToAffiliateLink(String originalUrl) {
    if (originalUrl.isEmpty) return originalUrl;

    try {
      final uri = Uri.parse(originalUrl);
      final hostname = uri.host.toLowerCase();

      // Hepsiburada kısa link kontrolü
      if (hostname.contains('hb.biz') || hostname.contains('app.hb.biz')) {
        _log('ℹ️ Kısa link tespit edildi: $originalUrl');
        return originalUrl;
      }

      // Trendyol
      if (hostname.contains('trendyol.com')) {
        final boutiqueId = affiliateConfig['trendyol']?['boutiqueId'];
        if (boutiqueId != null && boutiqueId.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('boutiqueId');
          newQueryParams['boutiqueId'] = boutiqueId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // Hepsiburada (Link Gelir)
      if (hostname.contains('hepsiburada.com')) {
        final utmSource = affiliateConfig['hepsiburada']?['utmSource'];
        if (utmSource != null && utmSource.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('utm_source');
          newQueryParams['utm_source'] = utmSource;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // N11
      if (hostname.contains('n11.com')) {
        final refId = affiliateConfig['n11']?['refId'];
        if (refId != null && refId.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('ref');
          newQueryParams['ref'] = refId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // Amazon
      if (hostname.contains('amazon.com.tr') || hostname.contains('amazon.com')) {
        final tag = affiliateConfig['amazon']?['tag'];
        if (tag != null && tag.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('tag');
          newQueryParams['tag'] = tag;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // GittiGidiyor
      if (hostname.contains('gittigidiyor.com')) {
        final affiliateId = affiliateConfig['gittigidiyor']?['affiliateId'];
        if (affiliateId != null && affiliateId.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('affiliateId');
          newQueryParams['affiliateId'] = affiliateId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      return originalUrl;
    } catch (e) {
      _log('Link dönüştürme hatası: $e');
      return originalUrl;
    }
  }
}
