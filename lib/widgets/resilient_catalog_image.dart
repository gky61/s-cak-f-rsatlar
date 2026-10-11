import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// FS-23 & FS-AKT-02: Aktüel Broşür Görselleri Dayanıklılık Bileşeni
/// Akakçe CDN, Referer kısıtı, Cloudflare WAF veya 403 engellerine karşı
/// özel HTTP başlıkları (User-Agent, Referer) ve otomatik images.weserv.nl proxy CDN fallback'i sağlar.
class ResilientCatalogImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showRetryButton;

  const ResilientCatalogImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.showRetryButton = true,
  });

  @override
  State<ResilientCatalogImage> createState() => _ResilientCatalogImageState();
}

class _ResilientCatalogImageState extends State<ResilientCatalogImage> {
  bool _useProxyFallback = false;
  int _retryKey = 0;

  static const Map<String, String> _standardHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://www.akakce.com/',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
  };

  String _getEffectiveUrl() {
    var cleanUrl = widget.imageUrl.trim();
    if (cleanUrl.startsWith('//')) {
      cleanUrl = 'https:$cleanUrl';
    }
    if (_useProxyFallback) {
      // images.weserv.nl proxy CDN fallback (SSL, WebP, hotlink bypass)
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(cleanUrl)}&output=webp&w=1400';
    }
    return cleanUrl;
  }

  void _handleRetry() {
    setState(() {
      _useProxyFallback = false;
      _retryKey++;
    });
  }

  void _handleImageError() {
    if (!_useProxyFallback) {
      setState(() {
        _useProxyFallback = true;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ResilientCatalogImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _useProxyFallback = false;
      _retryKey = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = widget.imageUrl.trim();
    if (cleanUrl.isEmpty) {
      if (widget.errorWidget != null) return widget.errorWidget!;
      return Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 36,
          color: Colors.grey[400],
        ),
      );
    }

    return KeyedSubtree(
      key: ValueKey('resilient_catalog_img_${widget.imageUrl}_$_useProxyFallback$_retryKey'),
      child: CachedNetworkImage(
        imageUrl: _getEffectiveUrl(),
        httpHeaders: _standardHeaders,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) {
          if (widget.placeholder != null) return widget.placeholder!;
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          );
        },
        errorWidget: (context, url, error) {
          if (!_useProxyFallback) {
            // İlk hata (örn: 403 Forbidden) anında derhal otomatik proxy fallback'e geç
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _handleImageError();
            });
            return widget.placeholder ??
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                );
          }

          if (widget.errorWidget != null) {
            return widget.errorWidget!;
          }

          if (!widget.showRetryButton) {
            return Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 36,
                color: Colors.grey[400],
              ),
            );
          }

          // Hem doğrudan hem yedek proxy başarısız olursa yeniden dene butonu
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white60,
                    size: 42,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Görsel yüklenemedi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _handleRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('Tekrar Dene'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
