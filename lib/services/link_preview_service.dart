import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

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
      print('🔍 LinkPreviewService: URL çekiliyor: $url');
      
      // Timeout ile metadata_fetch dene
      Metadata? metadata;
      try {
        metadata = await MetadataFetch.extract(url)
            .timeout(const Duration(seconds: 10));
        print('✅ Metadata fetch başarılı: ${metadata?.title ?? "başlık yok"}');
      } catch (e) {
        print('⚠️ Metadata fetch hatası: $e');
      }
      
      // Eğer görsel bulunamazsa, custom headers ile tekrar dene
      if (metadata == null || metadata.image == null || metadata.image!.isEmpty) {
        print('🔄 Custom headers ile tekrar deneniyor...');
        try {
          metadata = await _extractWithCustomHeaders(url)
              .timeout(const Duration(seconds: 10));
          print('✅ Custom headers başarılı: ${metadata?.image ?? "görsel yok"}');
        } catch (e) {
          print('⚠️ Custom headers hatası: $e');
        }
      }

      // Hala görsel yoksa, manuel HTML parsing yap
      String? imageUrl = metadata?.image;
      if (imageUrl == null || imageUrl.isEmpty) {
        print('🔄 HTML parsing ile görsel aranıyor...');
        try {
          imageUrl = await _extractImageFromHtml(url)
              .timeout(const Duration(seconds: 15));
          print('✅ HTML parsing sonucu: ${imageUrl ?? "görsel yok"}');
        } catch (e) {
          print('⚠️ HTML parsing hatası: $e');
        }
      }

      final resolvedImage = _resolveImageUrl(imageUrl, url);
      final provider = metadata != null ? _inferProvider(metadata, url) : _cleanHost(url);

      print('✅ LinkPreviewService sonuç:');
      print('   - Başlık: ${metadata?.title ?? "yok"}');
      print('   - Görsel: ${resolvedImage ?? "yok"}');
      print('   - Provider: ${provider ?? "yok"}');

      return LinkPreviewResult(
        title: metadata?.title,
        description: metadata?.description,
        imageUrl: resolvedImage,
        provider: provider,
      );
    } catch (e, stackTrace) {
      print('❌ LinkPreviewService error: $e');
      print('❌ Stack trace: $stackTrace');
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

  Future<String?> _extractImageFromHtml(String url) async {
    try {
      print('🔍 HTML parsing başlatılıyor: $url');
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
        print('⚠️ HTTP Status: ${response.statusCode}');
        return null;
      }
      
      print('✅ HTML başarıyla indirildi (${response.bodyBytes.length} bytes)');

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
          
          // Hepsiburada için özel filtreleme
          if (url.contains('hepsiburada.com')) {
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
      print('_extractImageFromHtml error: $e');
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

