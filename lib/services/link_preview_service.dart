import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

import 'domain_allowlist_service.dart';
import '../models/deal.dart';

// Scrapers
import 'scrapers/base_scraper.dart';
import 'scrapers/amazon_scraper.dart';
import 'scrapers/hepsiburada_scraper.dart';
import 'scrapers/n11_scraper.dart';
import 'scrapers/pazarama_scraper.dart';
import 'scrapers/vatan_scraper.dart';
import 'scrapers/trendyol_scraper.dart';
import 'scrapers/mediamarkt_scraper.dart';
import 'scrapers/idefix_scraper.dart';
import 'scrapers/itopya_scraper.dart';
import 'scrapers/teknosa_scraper.dart';
import 'scrapers/mavi_scraper.dart';
import 'scrapers/defacto_scraper.dart';
import 'scrapers/zara_scraper.dart';
import 'scrapers/mango_scraper.dart';
import 'scrapers/beymen_scraper.dart';
import 'scrapers/pttavm_scraper.dart';
import 'scrapers/incehesap_scraper.dart';
import 'scrapers/havit_scraper.dart';
import 'scrapers/migros_scraper.dart';
import 'scrapers/getir_scraper.dart';
import 'scrapers/boyner_scraper.dart';
import '../utils/test_logger.dart';

void _log(String message) {
  LinkPreviewLogger.log(message);
}

class LinkPreviewResult {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? provider;
  final double? price;
  final double? originalPrice;
  final List<String>? breadcrumbs;
  final String? priceLabel;
  final double? ratingValue;
  final int? ratingCount;
  final String? brand;
  final bool isAmazonWarehouse;

  LinkPreviewResult({
    String? title,
    String? description,
    String? imageUrl,
    String? provider,
    this.price,
    this.originalPrice,
    this.breadcrumbs,
    this.priceLabel,
    this.ratingValue,
    this.ratingCount,
    this.brand,
    this.isAmazonWarehouse = false,
  })  : title = (title == 'null' || title == 'NULL') ? null : title,
        description = (description == 'null' || description == 'NULL') ? null : description,
        imageUrl = (imageUrl == 'null' || imageUrl == 'NULL') ? null : imageUrl,
        provider = (provider == 'null' || provider == 'NULL') ? null : provider;
}

class LinkPreviewService {
  static final LinkPreviewService _instance = LinkPreviewService._internal();

  final List<BaseProductScraper> _scrapers = [
    AmazonScraper(),
    HepsiburadaScraper(),
    N11Scraper(),
    PazaramaScraper(),
    VatanScraper(),
    TrendyolScraper(),
    MediaMarktScraper(),
    IdefixScraper(),
    ItopyaScraper(),
    TeknosaScraper(),
    MaviScraper(),
    DefactoScraper(),
    ZaraScraper(),
    MangoScraper(),
    BeymenScraper(),
    PttavmScraper(),
    IncehesapScraper(),
    HavitScraper(),
    MigrosScraper(),
    GetirScraper(),
    BoynerScraper(),
  ];
  static const _defaultUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';

  bool _isLogoUrl(String urlString, String pageUrl) {
    final lowerUrl = urlString.toLowerCase();
    if (lowerUrl.endsWith('.svg') || lowerUrl.contains('.svg')) {
      return true;
    }
    if (lowerUrl.contains('logo') || 
        lowerUrl.contains('default') || 
        lowerUrl.contains('brand') || 
        lowerUrl.contains('banner') ||
        lowerUrl.contains('pwa') ||
        lowerUrl.contains('favicon') ||
        lowerUrl.contains('avatar') ||
        lowerUrl.contains('/icons/') ||
        lowerUrl.contains('/icon/')) {
      return true;
    }
    return false;
  }

  Map<String, String> _getHeadersForUrl(String url) {
    final lowerUrl = url.toLowerCase();
    String userAgent = _defaultUserAgent;
    
    if (lowerUrl.contains('incehesap.com')) {
      userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';
    } else if (lowerUrl.contains('n11.com') || 
        lowerUrl.contains('teknosa.com') ||
        lowerUrl.contains('amazon.') ||
        lowerUrl.contains('amzn.') ||
        lowerUrl.contains('link.amazon') ||
        lowerUrl.contains('hepsiburada.com') ||
        lowerUrl.contains('mavi.com') ||
        lowerUrl.contains('defacto.com.tr') ||
        lowerUrl.contains('zara.com') ||
        lowerUrl.contains('mango.com') ||
        lowerUrl.contains('beymen.com') ||
        lowerUrl.contains('hb.biz') ||
        lowerUrl.contains('trendyol.com') ||
        lowerUrl.contains('ty.gl') ||
        lowerUrl.contains('pttavm.com')) {
      userAgent = 'WhatsApp/2.23.4.15 A';
    } else if (lowerUrl.contains('vatanbilgisayar.com') || lowerUrl.contains('pazarama.com') || lowerUrl.contains('idefix.com') || lowerUrl.contains('havitstore.com.tr')) {
      userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
    }

    final headers = {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      'Cache-Control': 'max-age=0',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Referer': 'https://www.google.com/',
    };

    // Getir lokasyon bazlı teslimat servisi: location cookie'si olmadan
    // depo-özel ürünler (sandviç, dondurma vb.) 404 döner.
    // İstanbul merkez koordinatları ile tüm ürünlerin çözümlenmesi sağlanır.
    if (lowerUrl.contains('getir.com')) {
      headers['Cookie'] = 'locale=tr; language=tr; countryCode=TR; appType=GETIR';
    }

    return headers;
  }

  static const _nativeHttpChannel = MethodChannel('com.sicakfirsatlar.app/native_http');

  Future<String?> _fetchHtml(String url) async {
    final lowerUrl = url.toLowerCase();
    
    // Akamai Bot Manager ve AWS WAF gibi sıkı korumaları aşmak için Android ve iOS'ta native HTTP kütüphanesini kullanıyoruz.
    if ((defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) && 
        (lowerUrl.contains('zara.com') || lowerUrl.contains('getir.com') || lowerUrl.contains('itopya.com') || lowerUrl.contains('mango.com') || lowerUrl.contains('beymen.com') || lowerUrl.contains('defacto.com.tr') || lowerUrl.contains('mavi.com') || lowerUrl.contains('pttavm.com') || lowerUrl.contains('incehesap.com') || lowerUrl.contains('teknosa.com') || lowerUrl.contains('vatanbilgisayar.com') || lowerUrl.contains('pazarama.com') || lowerUrl.contains('idefix.com') || lowerUrl.contains('n11.com') || lowerUrl.contains('hepsiburada.com') || lowerUrl.contains('trendyol.com'))) {
      _log('🚀 Native HTTP istemcisi çağrılıyor: $url');
      try {
        final headers = _getHeadersForUrl(url);
        final String? html = await _nativeHttpChannel.invokeMethod<String>('fetchUrl', {
          'url': url,
          'userAgent': headers['User-Agent'],
          'cookie': headers['Cookie'],
        });
        if (html != null && html.isNotEmpty) {
          _log('✅ Native HTTP istemcisi başarılı (HTML Boyutu: ${html.length})');
          return html;
        }
      } catch (e) {
        _log('⚠️ Native HTTP istemcisi hata verdi: $e, standart Dart HTTP istemcisine geçiliyor...');
      }
    }

    // Standart Dart HTTP İstemcisi
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeadersForUrl(url),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      } else {
        _log('❌ Dart HTTP istemcisi hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('⚠️ Dart HTTP istemcisi hata verdi: $e');
      return null;
    }
  }

  LinkPreviewService._internal();

  factory LinkPreviewService() => _instance;

  Future<LinkPreviewResult?> fetchMetadata(String url) async {
    try {
      // Kısa linkler veya yönlendirme/takip linkleri için nihai uzun linki bul
      String targetUrl = extractAdjustFallback(url);
      if (targetUrl.toLowerCase().contains('sl.n11.com/n/') || targetUrl.toLowerCase().contains('n11.com/n/')) {
        targetUrl = await resolveN11ShortLink(targetUrl);
      }
      final lowerUrl = targetUrl.toLowerCase();
      final isShortOrRedirect = lowerUrl.contains('amzn.eu') || 
                               lowerUrl.contains('amzn.to') || 
                               lowerUrl.contains('link.amazon') || 
                               lowerUrl.contains('hb.biz') ||
                               lowerUrl.contains('publicis.link') ||
                               lowerUrl.contains('bit.ly') ||
                               lowerUrl.contains('tinyurl.com') ||
                               lowerUrl.contains('t.co') ||
                               lowerUrl.contains('rebrand.ly') ||
                               lowerUrl.contains('rdrtr.com') ||
                               lowerUrl.contains('onelink.me') ||
                               lowerUrl.contains('ty.gl');

      if (isShortOrRedirect) {
        final resolved = await resolveUrlRedirects(targetUrl);
        if (resolved.isNotEmpty) {
          targetUrl = resolved;
        }
      }

      targetUrl = _normalizeGetirUrl(targetUrl);

      _log('🔍 LinkPreviewService: URL çekiliyor: $targetUrl');

      // Domain Allowlist Kontrolü
      if (!DomainAllowlistService.isDomainAllowed(targetUrl)) {
        _log('🛑 [ALLOWLIST REJECT] URL desteklenen mağaza domain allowlist\'inde bulunamadı: $targetUrl');
        return null;
      }

      // 🛡️ Ürün Sayfası Doğrulaması (Product Path Validation)
      if (!DomainAllowlistService.isProductUrl(targetUrl)) {
        _log('🛑 [PRODUCT PATH REJECT] URL bir ürün sayfası değil (kampanya/arama/kategori sayfası olabilir): $targetUrl');
        return null;
      }
      
      // Eşleşen bir scraper var mı kontrol et
      BaseProductScraper? matchedScraper;
      for (final scraper in _scrapers) {
        if (scraper.canHandle(targetUrl)) {
          matchedScraper = scraper;
          break;
        }
      }

      if (matchedScraper != null) {
        _log('⚡ Özel Scraper eşleşti (${matchedScraper.domain}), özel istek yapılıyor...');
        try {
          final htmlContent = await _fetchHtml(targetUrl);

          if (htmlContent != null) {
            if (targetUrl.toLowerCase().contains('zara.com')) {
              _log('🔍 Zara DEBUG: Body Length = ${htmlContent.length}');
              _log('🔍 Zara DEBUG: Contains zara.analyticsData = ${htmlContent.contains('zara.analyticsData')}');
              _log('🔍 Zara DEBUG: Contains ProductGroup = ${htmlContent.contains('ProductGroup')}');
              _log('🔍 Zara DEBUG: Title H1 exist = ${htmlContent.contains('product-detail-info__header-name')}');
              _log('🔍 Zara DEBUG: Body preview = ${htmlContent.length > 1000 ? htmlContent.substring(0, 1000) : htmlContent}');
            }
            final document = html_parser.parse(htmlContent);
            if (document != null) {
              final imageUrl = matchedScraper.scrape(
                document: document,
                url: targetUrl,
                isLogoUrl: (img) => _isLogoUrl(img, targetUrl),
                resolveImageUrl: _resolveImageUrl,
                log: _log,
              );
              
              final title = matchedScraper.scrapeTitle(document) ?? 
                            MetadataParser.parse(document, url: targetUrl)?.title;
                            
              final description = await matchedScraper.scrapeDescription(document) ??
                                  MetadataParser.parse(document, url: targetUrl)?.description;
                            
              final price = await matchedScraper.scrapePrice(document);
              final originalPrice = await matchedScraper.scrapeOriginalPrice(document, price);
              final breadcrumbs = matchedScraper.scrapeBreadcrumbs(document);
              final priceLabel = await matchedScraper.scrapePriceLabel(document);
              final ratingValue = await matchedScraper.scrapeRatingValue(document);
              final ratingCount = await matchedScraper.scrapeRatingCount(document);
              final brand = matchedScraper.scrapeBrand(document);
              
              final resolvedImage = _resolveImageUrl(imageUrl, targetUrl);
              final provider = _cleanHost(targetUrl);
              
              _log('✅ Özel Scraper sonuç:');
              _log('   - Başlık: $title');
              _log('   - Açıklama: $description');
              _log('   - Görsel: $resolvedImage');
              _log('   - Fiyat: $price');
              if (originalPrice != null && originalPrice > (price ?? 0)) {
                _log('   - İndirimsiz (Eski) Fiyat: $originalPrice');
              }
              _log('   - Kırıntı (Breadcrumbs): $breadcrumbs');
              _log('   - Provider: $provider');
              if (priceLabel != null && priceLabel.isNotEmpty) {
                _log('   - Fiyat Etiketi/CRM Notu: $priceLabel');
              }
              if (ratingValue != null || ratingCount != null) {
                _log('   - Rating: $ratingValue ($ratingCount oy)');
                print('[aggregateRating] LinkPreviewService -> ratingValue: $ratingValue, ratingCount: $ratingCount');
              } else {
                print('[aggregateRating] LinkPreviewService -> ratingValue/ratingCount bulunamadı (null)');
              }
              if (brand != null && brand.isNotEmpty) {
                _log('   - Marka: $brand');
                print('[aggregateRating] LinkPreviewService -> Marka: $brand');
              } else {
                print('[aggregateRating] LinkPreviewService -> Marka bulunamadı (null)');
              }

              final isAmazonWarehouse = Deal.checkIsAmazonWarehouse(targetUrl) || Deal.checkIsAmazonWarehouse(url);
              if (isAmazonWarehouse) {
                _log('📦 Amazon Depo tespiti yapıldı! (smid=A215JX4S9CANSO)');
              }

              return LinkPreviewResult(
                title: title,
                description: description,
                imageUrl: resolvedImage,
                provider: provider,
                price: price,
                originalPrice: originalPrice,
                breadcrumbs: breadcrumbs,
                priceLabel: priceLabel,
                ratingValue: ratingValue,
                ratingCount: ratingCount,
                brand: brand,
                isAmazonWarehouse: isAmazonWarehouse,
              );
            }
          }
        } catch (e) {
          _log('⚠️ Özel Scraper hata verdi: $e, normal akışa geçiliyor...');
        }
      }
      
      // Timeout ile metadata_fetch dene
      Metadata? metadata;
      try {
        metadata = await MetadataFetch.extract(targetUrl)
            .timeout(const Duration(seconds: 10));
        _log('✅ Metadata fetch başarılı: ${metadata?.title ?? "başlık yok"}');
      } catch (e) {
        _log('⚠️ Metadata fetch hatası: $e');
      }
      
      // Eğer görsel bulunamazsa veya bulunan görsel bir logo ise, custom headers ile tekrar dene
      bool isLogo = false;
      if (metadata != null && metadata.image != null) {
        if (_isLogoUrl(metadata.image!, targetUrl)) {
          isLogo = true;
        }
      }

      if (metadata == null || metadata.image == null || metadata.image!.isEmpty || isLogo) {
        _log('🔄 Custom headers ile tekrar deneniyor...');
        try {
          metadata = await _extractWithCustomHeaders(targetUrl)
              .timeout(const Duration(seconds: 10));
          _log('✅ Custom headers başarılı: ${metadata?.image ?? "görsel yok"}');
        } catch (e) {
          _log('⚠️ Custom headers hatası: $e');
        }
      }

      // Hala görsel yoksa veya logo ise, manuel HTML parsing yap
      String? imageUrl = metadata?.image;
      
      bool isLogoImage = false;
      if (imageUrl != null) {
        if (_isLogoUrl(imageUrl, targetUrl)) {
          isLogoImage = true;
        }
      }

      if (imageUrl == null || imageUrl.isEmpty || isLogoImage) {
        _log('🔄 HTML parsing ile görsel aranıyor...');
        try {
          imageUrl = await _extractImageFromHtml(targetUrl)
              .timeout(const Duration(seconds: 15));
          _log('✅ HTML parsing sonucu: ${imageUrl ?? "görsel yok"}');
        } catch (e) {
          _log('⚠️ HTML parsing hatası: $e');
        }
      }

      final resolvedImage = _resolveImageUrl(imageUrl, targetUrl);
      final provider = metadata != null ? _inferProvider(metadata, targetUrl) : _cleanHost(targetUrl);
      final isAmazonWarehouseFallback = Deal.checkIsAmazonWarehouse(targetUrl) || Deal.checkIsAmazonWarehouse(url);

      _log('✅ LinkPreviewService sonuç:');
      _log('   - Başlık: ${metadata?.title ?? "yok"}');
      _log('   - Görsel: ${resolvedImage ?? "yok"}');
      _log('   - Provider: ${provider ?? "yok"}');

      return LinkPreviewResult(
        title: metadata?.title,
        description: metadata?.description,
        imageUrl: resolvedImage,
        provider: provider,
        isAmazonWarehouse: isAmazonWarehouseFallback,
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
        headers: _getHeadersForUrl(url),
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
    
    // Köşeli parantezleri (brackets) temizle
    final cleanedUrl = imageUrl.replaceAll('[', '').replaceAll(']', '').trim();
    if (cleanedUrl.isEmpty) return null;

    try {
      final uri = Uri.parse(cleanedUrl);
      if (uri.hasScheme) {
        return cleanedUrl;
      }
      final baseUri = Uri.parse(pageUrl);
      return baseUri.resolveUri(uri).toString();
    } catch (_) {
      return cleanedUrl;
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

  String _normalizeGetirUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('getir.com') && uri.path.contains('/urun/')) {
        var path = uri.path;
        if (!path.endsWith('/')) {
          path = '$path/';
        }
        path = path.replaceAll('//', '/');
        final cleanUri = Uri(
          scheme: uri.scheme,
          host: uri.host,
          path: path,
        );
        return cleanUri.toString();
      }
    } catch (_) {}
    return url;
  }

  String extractAdjustFallback(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('adj.st') || uri.host.contains('adjust.com')) {
        final params = ['adjust_redirect', 'adj_redirect', 'adjust_fallback', 'adj_fallback', 'fallback'];
        for (final param in params) {
          final value = uri.queryParameters[param];
          if (value != null && value.isNotEmpty) {
            _log('🎯 Adjust URL tespit edildi, $param çözülüyor: $value');
            return value;
          }
        }
      }
    } catch (e) {
      _log('⚠️ Adjust fallback çözme hatası: $e');
    }
    return url;
  }


  // Amazon kısa linkini (amzn.eu) uzun linke (amazon.com.tr/dp/...) çevir
  // Herhangi bir URL'nin yönlendirmelerini (redirects) takip ederek nihai adresi bulur
  Future<String> resolveUrlRedirects(String url) async {
    try {
      var currentUrl = extractAdjustFallback(url);
      if (currentUrl.toLowerCase().contains('sl.n11.com/n/') || currentUrl.toLowerCase().contains('n11.com/n/')) {
        currentUrl = await resolveN11ShortLink(currentUrl);
      }
      if (currentUrl != url) {
        _log('🎯 Adjust yönlendirmesi hemen çözüldü: $currentUrl');
        return currentUrl;
      }
      _log('🔗 Yönlendirmeler çözülüyor: $currentUrl');
      final client = http.Client();
      var redirectCount = 0;
      const maxRedirects = 8; // Amazon/Publicis zinciri 4-5 adımı bulabiliyor

      while (redirectCount < maxRedirects) {
        final request = http.Request('GET', Uri.parse(currentUrl))
          ..followRedirects = false;
        
        final response = await client.send(request).timeout(
          const Duration(seconds: 4),
        );
        
        final location = response.headers['location'] ?? response.headers['Location'];
        if (location != null && location.isNotEmpty) {
          var nextUrl = location;
          if (nextUrl.startsWith('/')) {
            final uri = Uri.parse(currentUrl);
            nextUrl = '${uri.scheme}://${uri.host}$nextUrl';
          } else if (!nextUrl.startsWith('http')) {
            nextUrl = 'https://$nextUrl';
          }
          currentUrl = nextUrl;
          redirectCount++;
          _log('   -> Yönlendi ($redirectCount): $currentUrl');
        } else {
          break;
        }
      }
      client.close();
      currentUrl = extractAdjustFallback(currentUrl);
      _log('✅ Yönlendirme zinciri çözüldü. Nihai URL: $currentUrl');
      return currentUrl;
    } catch (e) {
      _log('⚠️ Yönlendirme çözme hatası: $e, orijinal URL kullanılıyor');
      return url;
    }
  }

  // N11 kısa linklerini (sl.n11.com/n/...) uzun ürün linkine çözer
  Future<String> resolveN11ShortLink(String url) async {
    try {
      var targetUrl = url;
      if (targetUrl.toLowerCase().contains('sl.n11.com/n/')) {
        targetUrl = targetUrl.replaceAll('sl.n11.com', 'www.n11.com');
      }
      _log('🔗 N11 kısa linki çözülüyor: $targetUrl');
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(targetUrl))
        ..followRedirects = false;
      final response = await client.send(request).timeout(const Duration(seconds: 4));
      final location = response.headers['location'] ?? response.headers['Location'];
      client.close();
      if (location != null && location.isNotEmpty) {
        _log('✅ N11 kısa linki çözüldü: $location');
        return location;
      }
    } catch (e) {
      _log('⚠️ N11 kısa link çözme hatası: $e');
    }
    return url;
  }

  // Amazon kısa linkini (amzn.eu) uzun linke (amazon.com.tr/dp/...) çevir
  Future<String?> getFullAmazonUrl(String shortUrl) async {
    return resolveUrlRedirects(shortUrl);
  }

  // Amazon URL'den ASIN kodunu çıkar ve görsel URL'si oluştur (eski fonksiyon, geriye uyumluluk için)
  Future<String?> getAmazonImageFromUrl(String url) async {
    return getAmazonImageSmart(url);
  }

  // Amazon görselini akıllıca çek (kısa linkleri de destekler)
  Future<String?> getAmazonImageSmart(String url) async {
    try {
      String targetUrl = url;

      // 1. Eğer link kısaltılmış Amazon linki veya yönlendirme linki ise çöz
      final lowerUrl = url.toLowerCase();
      final isShortOrRedirect = lowerUrl.contains('amzn.eu') || 
                               lowerUrl.contains('amzn.to') || 
                               lowerUrl.contains('link.amazon') || 
                               lowerUrl.contains('hb.biz') ||
                               lowerUrl.contains('publicis.link') ||
                               lowerUrl.contains('bit.ly') ||
                               lowerUrl.contains('tinyurl.com') ||
                               lowerUrl.contains('t.co') ||
                               lowerUrl.contains('rebrand.ly') ||
                               lowerUrl.contains('rdrtr.com');

      if (isShortOrRedirect) {
        _log('🔄 Yönlendirmeli link tespit edildi ($url), çözülüyor...');
        final fullUrl = await resolveUrlRedirects(url);
        if (fullUrl.isNotEmpty && fullUrl != url) {
          targetUrl = fullUrl;
          _log('✅ Link çözüldü: $targetUrl');
        } else {
          _log('⚠️ Link çözülemedi, orijinal link kullanılıyor');
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
        
        // Boyut kontrolü yaparak 1x1 veya boş görsel (43 byte) olmasını engelle
        try {
          final res = await http.get(Uri.parse(amazonImageUrl))
              .timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final len = res.bodyBytes.length;
            _log('ℹ️ Amazon ASIN görsel boyutu: $len bytes');
            if (len > 1000) {
              return amazonImageUrl; // Gerçek görsel
            } else {
              _log('⚠️ Amazon ASIN görseli geçersiz/boş (boyut: $len bytes), html parsing\'e yönlendiriliyor.');
            }
          }
        } catch (e) {
          _log('⚠️ Amazon görsel boyut kontrolü hatası: $e');
        }
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
      final htmlContent = await _fetchHtml(url);
      if (htmlContent == null || htmlContent.isEmpty) {
        return null;
      }
      _log('✅ HTML başarıyla indirildi (${htmlContent.length} chars)');
      final document = html_parser.parse(htmlContent);
      if (document == null) return null;

      // Mağazaya özel scraper'lar ile görsel aramayı dene
      for (final scraper in _scrapers) {
        if (scraper.canHandle(url)) {
          final imageUrl = scraper.scrape(
            document: document,
            url: url,
            isLogoUrl: (img) => _isLogoUrl(img, url),
            resolveImageUrl: _resolveImageUrl,
            log: _log,
          );
          if (imageUrl != null) {
            return imageUrl;
          }
        }
      }

      // Önce JSON-LD schema'dan görsel bul (Hepsiburada için önemli)
      final jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
      for (final script in jsonLdScripts) {
        try {
          final jsonContent = script.text;
          final jsonData = jsonDecode(jsonContent);
          final imageUrl = _extractImageFromJson(jsonData);
          if (imageUrl != null && imageUrl.isNotEmpty) {
            if (_isLogoUrl(imageUrl, url)) {
              continue;
            }
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
        // Amazon özel ana görseli
        'img#landingImage',
        'img[id="landingImage"]',
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
            
            // Logo Filtresi (Merkezi kontrol)
            if (_isLogoUrl(imageUrl, url)) {
              continue;
            }
            
            // Relative URL'leri resolve et
            final resolved = _resolveImageUrl(imageUrl, url);
            if (resolved != null && resolved.isNotEmpty) {
              return resolved;
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

