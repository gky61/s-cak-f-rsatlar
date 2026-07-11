import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/deal.dart';

/// Fırsat detay sayfası görsel bileşeni ve tam ekran görüntüleyici.
class DealDetailImage extends StatelessWidget {
  final Deal deal;
  final String? fetchedImageUrl;
  final bool originalImageFailed;
  final bool isFetchingImage;
  final bool hasTriedFetching;
  final VoidCallback? onFetchImage;
  final ValueChanged<bool> onOriginalImageFailed;
  final ValueChanged<String> onFullScreen;

  const DealDetailImage({
    super.key,
    required this.deal,
    this.fetchedImageUrl,
    this.originalImageFailed = false,
    this.isFetchingImage = false,
    this.hasTriedFetching = false,
    this.onFetchImage,
    required this.onOriginalImageFailed,
    required this.onFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    // Eğer görsel yoksa ve henüz çekilmeye çalışılmadıysa, çekmeyi dene
    if (deal.imageUrl.isEmpty && !hasTriedFetching && !isFetchingImage && deal.link.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onFetchImage?.call();
      });
    }
    
    // Görsel seçim mantığı:
    // 1. Önce orijinal görseli dene (eğer başarısız olmadıysa)
    // 2. Orijinal görsel yoksa veya başarısız olduysa, linkten çekileni kullan
    
    String? imageUrl;
    final fetchedUrl = fetchedImageUrl;
    
    // Önce orijinal görseli kontrol et
    if (!originalImageFailed && deal.imageUrl.isNotEmpty) {
      imageUrl = deal.imageUrl;
    } 
    // Orijinal görsel yoksa veya başarısız olduysa, linkten çekileni kullan
    else if (fetchedUrl != null && fetchedUrl.isNotEmpty) {
      imageUrl = fetchedUrl;
    }
    
    // Görsel yükleniyorsa loading göster
    if (isFetchingImage && imageUrl == null) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
          ),
        ),
      );
    }
    
    // Görsel varsa göster - Contain fit ile tam görünsün
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () => onFullScreen(imageUrl!),
        child: Container(
          color: Colors.grey[100], // Arka plan rengi
          child: Center(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain, // Görseli çerçeveye sığdır, tam görünsün
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                // Eğer orijinal görsel yüklenemediyse
                if (!originalImageFailed && imageUrl == deal.imageUrl && deal.imageUrl.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onOriginalImageFailed(true);
                  });
                }
                // Eğer linkten çekilen görsel varsa, onu göster
                final currentFetchedUrl = fetchedImageUrl;
                if (currentFetchedUrl != null && currentFetchedUrl.isNotEmpty && currentFetchedUrl != imageUrl) {
                  return Container(
                    color: Colors.grey[100],
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: currentFetchedUrl,
                        fit: BoxFit.contain, // Contain fit
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget: (context, url, error) => _buildImageFallback(),
                      ),
                    ),
                  );
                }
                return _buildImageFallback();
              },
            ),
          ),
        ),
      );
    }
    
    // Görsel yoksa fallback göster
    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.image_outlined,
        size: 80,
        color: Colors.grey,
      ),
    );
  }

  /// Tam ekran görsel dialog'u.
  static void showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Görsel - Pinch to zoom özelliği ile
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                      strokeWidth: 3,
                color: Colors.white,
              ),
            ),
                  errorWidget: (context, url, error) => const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.white,
                      size: 64,
              ),
            ),
          ),
              ),
            ),
            // Kapat butonu
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
