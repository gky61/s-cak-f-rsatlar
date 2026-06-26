import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class LinkPreviewResult {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? provider;

  LinkPreviewResult({
    this.title,
    this.description,
    this.imageUrl,
    this.provider,
  });
}

class LinkPreviewService {
  static final LinkPreviewService _instance = LinkPreviewService._internal();
  static const _defaultUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';

  LinkPreviewService._internal();

  factory LinkPreviewService() => _instance;

  Future<LinkPreviewResult?> fetchMetadata(String url) async {
    try {
      _log('🔍 LinkPreviewService: URL çekiliyor: $url');
      
      // Timeout ile metadata_fetch dene
      Metadata? metadata;
      try {
        metadata = await MetadataFetch.extract(url)
            .timeout(const Duration(seconds: 10));
        _log('✅ Metadata fetch başarılı: ${metadata?.title ?? "başlık yok"}');
      } catch (e) {
        _log('⚠️ Metadata fetch hatası: $e');
      }
      
      // Eğer görsel bulunamazsa, custom headers ile tekrar dene
      if (metadata == null || metadata.image == null || metadata.image!.isEmpty) {
        _log('🔄 Custom headers ile tekrar deneniyor...');
        try {
          metadata = await _extractWithCustomHeaders(url)
              .timeout(const Duration(seconds: 10));
          _log('✅ Custom headers başarılı: ${metadata?.image ?? "görsel yok"}');
        } catch (e) {
          _log('⚠️ Custom headers hatası: $e');
        }
      }

      // Hala görsel yoksa, manuel HTML parsing yap
      String? imageUrl = metadata?.image;
      if (imageUrl == null || imageUrl.isEmpty) {
        _log('🔄 HTML parsing ile görsel aranıyor...');
        try {
          imageUrl = await _extractImageFromHtml(url)
              .timeout(const Duration(seconds: 15));
          _log('✅ HTML parsing sonucu: ${imageUrl ?? "görsel yok"}');
        } catch (e) {
          _log('⚠️ HTML parsing hatası: $e');
        }
      }

      final resolvedImage = _resolveImageUrl(imageUrl, url);
      final provider = metadata != null ? _inferProvider(metadata, url) : _cleanHost(url);

      _log('✅ LinkPreviewService sonuç:');
      _log('   - Başlık: ${metadata?.title ?? "yok"}');
      _log('   - Görsel: ${resolvedImage ?? "yok"}');
      _log('   - Provider: ${provider ?? "yok"}');

      return LinkPreviewResult(
        title: metadata?.title,
        description: metadata?.description,
        imageUrl: resolvedImage,
        provider: provider,
      );
    } catch (e, stackTrace) {
      _log('❌ LinkPreviewService error: $e');
      _log('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  Future<Metadata?> _extractWithCustomHeaders(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': _defaultUserAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      );

      final document = MetadataFetch.responseToDocument(response);
      if (document == null) return null;

      return MetadataParser.parse(document, url: url);
    } catch (_) {
      return null;
    }
  }

  String? _resolveImageUrl(String? imageUrl, String pageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final uri = Uri.parse(imageUrl);
      if (uri.hasScheme) {
        return imageUrl;
      }
      final baseUri = Uri.parse(pageUrl);
      return baseUri.resolveUri(uri).toString();
    } catch (_) {
      return imageUrl;
    }
  }

  String? _inferProvider(Metadata metadata, String url) {
    if (metadata.url != null) {
      return _cleanHost(metadata.url!);
    }

    return _cleanHost(url);
  }

  String? _cleanHost(String inputUrl) {
    try {
      final host = Uri.parse(inputUrl).host;
      if (host.startsWith('www.')) {
        return host.substring(4);
      }
      return host.isEmpty ? null : host;
    } catch (_) {
      return null;
    }
  }

  // Amazon kısa linkini (amzn.eu) uzun linke (amazon.com.tr/dp/...) çevir
  Future<String?> getFullAmazonUrl(String shortUrl) async {
    try {
      // Sadece amzn.eu linklerini çevir
      if (!shortUrl.contains('amzn.eu') && !shortUrl.contains('amzn.to')) {
        return shortUrl; // Zaten uzun link ise direkt döndür
      }

      _log('🔗 Amazon kısa link çözülüyor: $shortUrl');
      
      // 1. Basit bir istek atarak linkin bizi nereye yönlendirdiğine bakıyoruz
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(shortUrl))
        ..followRedirects = false; // Otomatik yönlenmeyi kapatıyoruz ki header'ı okuyalım
      
      final response = await client.send(request).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _log('⏱️ Amazon link çözümleme timeout');
          throw TimeoutException('Amazon link çözümleme timeout');
        },
      );
      
      // 2. Yönlendirme adresini (Location) alıyoruz
      // HTTP header'ları case-insensitive olabilir, hem küçük hem büyük harfle kontrol et
      String? longUrl = response.headers['location'] ?? response.headers['Location'];
      
      // Eğer relative URL gelirse, absolute URL'e çevir
      if (longUrl != null && longUrl.isNotEmpty) {
        if (longUrl.startsWith('/')) {
          // Relative URL ise, Amazon domain'ini ekle
          final uri = Uri.parse(shortUrl);
          longUrl = '${uri.scheme}://${uri.host}$longUrl';
        } else if (!longUrl.startsWith('http')) {
          // Protocol yoksa https ekle
          longUrl = 'https://$longUrl';
        }
        
        _log('✅ Amazon uzun link bulundu: $longUrl');
        client.close();
        return longUrl;
      }
      
      // Eğer location boşsa, orijinal linki döndür
      _log('⚠️ Amazon link çözümleme başarısız (Location header bulunamadı), orijinal link kullanılıyor');
      client.close();
      return shortUrl;
      
    } catch (e) {
      _log("❌ Amazon link çözümleme hatası: $e");
      return shortUrl; // Hata olursa orijinalini döndür
    }
  }

  // Amazon URL'den ASIN kodunu çıkar ve görsel URL'si oluştur (eski fonksiyon, geriye uyumluluk için)
  Future<String?> getAmazonImageFromUrl(String url) async {
    return getAmazonImageSmart(url);
  }

  // Amazon görselini akıllıca çek (kısa linkleri de destekler)
  Future<String?> getAmazonImageSmart(String url) async {
    try {
      String targetUrl = url;

      // 1. Eğer link kısaltılmış Amazon linki ise (amzn.eu veya amzn.to)
      // Bu formatlar desteklenir: amzn.eu/d/xxx, amzn.to/xxx, amzn.eu/xxx
      if (url.contains("amzn.eu") || url.contains("amzn.to")) {
        _log('🔄 Amazon kısa link tespit edildi ($url), uzun linke çevriliyor...');
        final fullUrl = await getFullAmazonUrl(url);
        if (fullUrl != null && fullUrl.isNotEmpty && fullUrl != url && !fullUrl.contains("amzn.eu") && !fullUrl.contains("amzn.to")) {
          targetUrl = fullUrl; // Artık elimizde uzun link var!
          _log('✅ Amazon kısa link çözüldü: $targetUrl');
        } else {
          _log('⚠️ Amazon kısa link çözülemedi veya hala kısa link formatında, orijinal link kullanılıyor');
        }
      }

      // 2. Şimdi uzun linkin içinden ASIN kodunu (B0...) çekiyoruz
      // Bu regex hem "/dp/" hem de "/gp/product/" hem de mobil linkler için çalışır
      // Mobil linkler: amazon.com.tr/gp/product/B0... veya amazon.com.tr/product/B0...
      // Desktop linkler: amazon.com.tr/dp/B0... veya amazon.com.tr/gp/product/B0...
      final regExp = RegExp(r'/(?:dp|gp\/product|product|aw\/d)/([A-Z0-9]{10})');
      final match = regExp.firstMatch(targetUrl);

      if (match != null) {
        final asin = match.group(1); // Örn: B085YBJT9R
        
        // Amazon görsel linkini oluştur
        final amazonImageUrl = "https://images-na.ssl-images-amazon.com/images/P/$asin.01._SCLZZZZZZZ_.jpg";
        _log('✅ Amazon ASIN bulundu: $asin, Görsel URL: $amazonImageUrl');
        return amazonImageUrl;
      } else {
        _log('⚠️ Amazon URL\'de ASIN bulunamadı: $targetUrl');
      }
    } catch (e) {
      _log("❌ Amazon görsel çekme hatası: $e");
    }
    return null; // Bulamazsa null döner
  }

  Future<String?> _extractImageFromHtml(String url) async {
    try {
      _log('🔍 HTML parsing başlatılıyor: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': 'https://www.google.com/',
          'Accept-Encoding': 'gzip, deflate, br',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _log('⚠️ HTTP Status: ${response.statusCode}');
        return null;
      }
      
      _log('✅ HTML başarıyla indirildi (${response.bodyBytes.length} bytes)');

      final htmlContent = utf8.decode(response.bodyBytes);
      final document = html_parser.parse(htmlContent);
      if (document == null) return null;

      // Önce JSON-LD schema'dan görsel bul (Hepsiburada için önemli)
      final jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
      for (final script in jsonLdScripts) {
        try {
          final jsonContent = script.text;
          final jsonData = jsonDecode(jsonContent);
          final imageUrl = _extractImageFromJson(jsonData);
          if (imageUrl != null && imageUrl.isNotEmpty) {
            final resolved = _resolveImageUrl(imageUrl, url);
            if (resolved != null) return resolved;
          }
        } catch (e) {
          // JSON parse hatası, devam et
        }
      }

      // Öncelik sırasına göre görsel arama
      final selectors = [
        // Open Graph
        'meta[property="og:image"]',
        'meta[name="og:image"]',
        // Twitter Card
        'meta[name="twitter:image"]',
        'meta[property="twitter:image"]',
        // Schema.org
        'img[itemprop="image"]',
        // Yaygın görsel class'ları
        'img.product-image',
        'img.main-image',
        'img.hero-image',
        'img[class*="product"]',
        'img[class*="main"]',
        'img[class*="hero"]',
        // İlk büyük görsel
        'img[width]',
        'img[height]',
      ];

      // Meta tag'lerden görsel bul
      for (final selector in selectors) {
        final elements = document.querySelectorAll(selector);
        for (final element in elements) {
          String? imageUrl;
          
          if (element.localName == 'meta') {
            imageUrl = element.attributes['content'];
          } else if (element.localName == 'img') {
            imageUrl = element.attributes['src'] ?? element.attributes['data-src'] ?? element.attributes['data-lazy-src'];
          }

          if (imageUrl != null && imageUrl.isNotEmpty) {
            // Base64 veya data URL'leri atla
            if (imageUrl.startsWith('data:')) continue;
            
            // Relative URL'leri resolve et
            final resolved = _resolveImageUrl(imageUrl, url);
            if (resolved != null && resolved.isNotEmpty) {
              return resolved;
            }
          }
        }
      }

      // Amazon özel kontrolleri
      if (url.contains('amazon.') || url.contains('amazon.com.tr') || url.contains('amazon.com')) {
        _log('🛒 Amazon URL tespit edildi, özel görsel çekme başlatılıyor...');
        
        // Amazon'un data-a-dynamic-image attribute'u (en güvenilir yöntem)
        final amazonDynamicImages = document.querySelectorAll('[data-a-dynamic-image]');
        for (final element in amazonDynamicImages) {
          try {
            final dynamicImageData = element.attributes['data-a-dynamic-image'];
            if (dynamicImageData != null && dynamicImageData.isNotEmpty) {
              final jsonData = jsonDecode(dynamicImageData);
              if (jsonData is Map) {
                // İlk görseli al (en büyük genellikle)
                final firstKey = jsonData.keys.first;
                if (firstKey != null && firstKey is String) {
                  _log('✅ Amazon dynamic image bulundu: $firstKey');
                  return firstKey;
                }
              }
            }
          } catch (e) {
            _log('⚠️ Amazon dynamic image parse hatası: $e');
          }
        }
        
        // Amazon'un ürün görseli için özel selector'lar
        final amazonSelectors = [
          '#landingImage',
          '#imgBlkFront',
          '#main-image',
          '#imageBlock_feature_div img',
          '#imageBlock img',
          '#altImages img',
          '.a-dynamic-image',
          '[id*="landingImage"]',
          '[id*="main-image"]',
        ];
        
        for (final selector in amazonSelectors) {
          final images = document.querySelectorAll(selector);
          for (final img in images) {
            String? imageUrl = img.attributes['src'] ?? 
                             img.attributes['data-src'] ?? 
                             img.attributes['data-a-dynamic-image'] ??
                             img.attributes['data-old-src'];
            
            if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('data:')) {
              // Amazon'un placeholder görsellerini atla
              if (imageUrl.contains('pixel') || 
                  imageUrl.contains('placeholder') ||
                  imageUrl.contains('spinner') ||
                  imageUrl.contains('loading')) {
                continue;
              }
              
              // Amazon CDN görsellerini tercih et
              if (imageUrl.contains('images-na.ssl-images-amazon.com') ||
                  imageUrl.contains('images-eu.ssl-images-amazon.com') ||
                  imageUrl.contains('images-amazon.com')) {
                final resolved = _resolveImageUrl(imageUrl, url);
                if (resolved != null) {
                  _log('✅ Amazon görsel bulundu: $resolved');
                  return resolved;
                }
              }
            }
          }
        }
        
        // Amazon JSON-LD schema'dan görsel çek
        final amazonJsonLd = document.querySelectorAll('script[type="application/ld+json"]');
        for (final script in amazonJsonLd) {
          try {
            final jsonContent = script.text;
            if (jsonContent.contains('Product') || jsonContent.contains('image')) {
              final jsonData = jsonDecode(jsonContent);
              final imageUrl = _extractImageFromJson(jsonData);
              if (imageUrl != null && imageUrl.isNotEmpty) {
                final resolved = _resolveImageUrl(imageUrl, url);
                if (resolved != null) {
                  _log('✅ Amazon JSON-LD görsel bulundu: $resolved');
                  return resolved;
                }
              }
            }
          } catch (e) {
            // JSON parse hatası, devam et
          }
        }
        
        _log('⚠️ Amazon özel görsel çekme başarısız, genel yöntem deneniyor...');
      }
      
      // Hepsiburada özel kontrolleri
      if (url.contains('hepsiburada.com')) {
        // Hepsiburada kampanya görselleri genellikle bu attribute'larda
        final hepsiburadaImages = document.querySelectorAll('[data-image], [data-srcset], [data-original-src]');
        for (final element in hepsiburadaImages) {
          final imageUrl = element.attributes['data-image'] ?? 
                          element.attributes['data-srcset']?.split(',').first.trim() ??
                          element.attributes['data-original-src'];
          if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('data:')) {
            final resolved = _resolveImageUrl(imageUrl, url);
            if (resolved != null) return resolved;
          }
        }

        // Hepsiburada banner görselleri
        final banners = document.querySelectorAll('.banner-image, .campaign-image, [class*="banner"], [class*="campaign"]');
        for (final banner in banners) {
          final img = banner.querySelector('img');
          if (img != null) {
            final src = img.attributes['src'] ?? 
                       img.attributes['data-src'] ?? 
                       img.attributes['data-lazy-src'];
            if (src != null && src.isNotEmpty && !src.startsWith('data:')) {
              final resolved = _resolveImageUrl(src, url);
              if (resolved != null) return resolved;
            }
          }
        }
      }

      // Son çare: tüm img tag'lerini kontrol et
      final allImages = document.querySelectorAll('img');
      for (final img in allImages) {
        final src = img.attributes['src'] ?? 
                   img.attributes['data-src'] ?? 
                   img.attributes['data-lazy-src'] ??
                   img.attributes['data-original'] ??
                   img.attributes['data-image'];
        
        if (src != null && src.isNotEmpty && !src.startsWith('data:')) {
          // Küçük icon'ları ve placeholder'ları atla
          if (src.contains('icon') || 
              src.contains('logo') || 
              src.contains('placeholder') ||
              src.contains('avatar') ||
              src.contains('spinner') ||
              src.contains('loading')) {
            continue;
          }
          
          // Amazon için özel filtreleme
          if (url.contains('amazon.') || url.contains('amazon.com.tr') || url.contains('amazon.com')) {
            // Amazon CDN görsellerini tercih et
            if (src.contains('images-na.ssl-images-amazon.com') ||
                src.contains('images-eu.ssl-images-amazon.com') ||
                src.contains('images-amazon.com')) {
              // Placeholder'ları atla
              if (!src.contains('pixel') && 
                  !src.contains('placeholder') &&
                  !src.contains('spinner') &&
                  !src.contains('loading')) {
                final resolved = _resolveImageUrl(src, url);
                if (resolved != null && resolved.isNotEmpty) {
                  _log('✅ Amazon genel görsel bulundu: $resolved');
                  return resolved;
                }
              }
            }
          }
          // Hepsiburada için özel filtreleme
          else if (url.contains('hepsiburada.com')) {
            // Sadece ürün/kampanya görsellerini al
            if (src.contains('product') || 
                src.contains('campaign') || 
                src.contains('banner') ||
                src.contains('hepsiburada.com')) {
              final resolved = _resolveImageUrl(src, url);
              if (resolved != null && resolved.isNotEmpty) {
                return resolved;
              }
            }
          } else {
            final resolved = _resolveImageUrl(src, url);
            if (resolved != null && resolved.isNotEmpty) {
              return resolved;
            }
          }
        }
      }

      return null;
    } catch (e) {
      _log('_extractImageFromHtml error: $e');
      return null;
    }
  }

  String? _extractImageFromJson(dynamic jsonData) {
    if (jsonData is Map) {
      // image field'ını kontrol et
      if (jsonData['image'] != null) {
        if (jsonData['image'] is String) {
          return jsonData['image'] as String;
        } else if (jsonData['image'] is Map && jsonData['image']['url'] != null) {
          return jsonData['image']['url'] as String;
        } else if (jsonData['image'] is List && jsonData['image'].isNotEmpty) {
          final firstImage = jsonData['image'][0];
          if (firstImage is String) {
            return firstImage;
          } else if (firstImage is Map && firstImage['url'] != null) {
            return firstImage['url'] as String;
          }
        }
      }

      // @graph veya itemListElement içinde ara
      if (jsonData['@graph'] != null && jsonData['@graph'] is List) {
        for (final item in jsonData['@graph'] as List) {
          final image = _extractImageFromJson(item);
          if (image != null) return image;
        }
      }

      if (jsonData['itemListElement'] != null && jsonData['itemListElement'] is List) {
        for (final item in jsonData['itemListElement'] as List) {
          final image = _extractImageFromJson(item);
          if (image != null) return image;
        }
      }

      // Tüm key'leri kontrol et
      for (final value in jsonData.values) {
        final image = _extractImageFromJson(value);
        if (image != null) return image;
      }
    } else if (jsonData is List) {
      for (final item in jsonData) {
        final image = _extractImageFromJson(item);
        if (image != null) return image;
      }
    }

    return null;
  }
}

