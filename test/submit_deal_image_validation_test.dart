import 'package:flutter_test/flutter_test.dart';

bool isValidImageUrl(String url) {
  if (url.isEmpty) return false;
  if (!url.startsWith('http://') && !url.startsWith('https://')) return false;

  final lowerUrl = url.toLowerCase();

  // 1. URI analizi ile uzantı kontrolü (path .jpg, .png vb. ile bitiyor veya içeriyorsa kesinlikle görseldir)
  try {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.svg', '.avif', '.heic'];
    if (imageExtensions.any((ext) => path.endsWith(ext) || path.contains('$ext?') || path.contains('$ext&') || path.contains(ext))) {
      return true;
    }
  } catch (_) {}

    // 2. Dynamic Media / Scene7 veya /is/image/ endpoint'leri (Örn: Mango media.mango.com/is/image/...)
    if (lowerUrl.contains('/is/image/') || lowerUrl.contains('/images/') || lowerUrl.contains('/image/')) {
      const htmlPagePatterns = ['/urun/', '-p-', '/item/', '/detail/', '.html', '.htm', '.php'];
      if (!htmlPagePatterns.any((pattern) => lowerUrl.contains(pattern))) {
        return true;
      }
    }

    // 3. Özel Görsel CDN Alan Adları (Sadece görsel barındıran alt alan adları)
    const imageCdnPatterns = [
      'assets.mmsrg.com',      // MediaMarkt CDN
      'img.pzrmcdn.com',       // Pazarama CDN
      'cdn.dsmcdn.com',        // Trendyol CDN
      'hepsiburada.net',       // Hepsiburada CDN
      'images-amazon.com',     // Amazon CDN
      'images-na.ssl-images-amazon.com',
      'media-amazon.com',      // Amazon Media CDN
      'm.media-amazon.com',    // Amazon Mobile Media CDN
      'ssl-images-amazon.com',
      'n11scdn.akamaized.net',  // N11 CDN
      'cdn.vatanbilgisayar.com', // Vatan Bilgisayar CDN
      'yenieera22.com',          // Itopya Image CDN
      'teknosa-cloud-prod.mncdn.com', // Teknosa Image CDN
      'sky-static.mavi.com',    // Mavi CDN
      'dfcdn.net',              // DeFacto CDN
      'static.zara.net',        // Zara CDN
      'media.mango.com',        // Mango Media CDN
      'st.mango.com',           // Mango CDN
      'st-mango.mncdn.com',     // Mango Alternative CDN
      'cdn.beymen.com',         // Beymen CDN
      'cdn-s3.pttavm.com',      // PttAVM CDN
      'images.migrosone.com',   // Migros Image CDN
      'cdn.getir.com',          // Getir CDN
      'cdn.boyner.com.tr',      // Boyner CDN
      'cdn03.ciceksepeti.net',  // Çiçeksepeti CDN
      'imgbb.co',
      'imgur.com',
      'i.ibb.co',
      'images.unsplash.com',
      'i.imgur.com',
      'cloudinary.com',
      'cloudfront.net',
    ];
    if (imageCdnPatterns.any((pattern) => lowerUrl.contains(pattern))) {
      const htmlPagePatterns = ['/urun/', '-p-', '/item/', '/detail/', '.html', '.htm', '.php'];
      if (!htmlPagePatterns.any((pattern) => lowerUrl.contains(pattern)) || lowerUrl.contains('.jpg') || lowerUrl.contains('.png') || lowerUrl.contains('.webp')) {
        return true;
      }
    }

    return false;
  }

void main() {
  group('SubmitDealScreen Image URL Validation Tests', () {
    test('Mango media.mango.com Scene7 image without extension should be valid', () {
      const url = 'https://media.mango.com/is/image/punto/27034409-56-002?wid=1024';
      expect(isValidImageUrl(url), isTrue);
    });

    test('Migros product image ending in .jpg should be valid', () {
      const url = 'https://images.migrosone.com/sanalmarket/product/34013753/34013753_1-fab227.jpg';
      expect(isValidImageUrl(url), isTrue);
    });

    test('Trendyol image with cdn.dsmcdn.com should be valid', () {
      const url = 'https://cdn.dsmcdn.com/ty123/product/media/images/prod.jpg';
      expect(isValidImageUrl(url), isTrue);
    });

    test('Amazon image with media-amazon.com should be valid', () {
      const url = 'https://m.media-amazon.com/images/I/71xyz.jpg';
      expect(isValidImageUrl(url), isTrue);
    });

    test('Hepsiburada image with hepsiburada.net should be valid', () {
      const url = 'https://productimages.hepsiburada.net/s/123/500/123.jpg';
      expect(isValidImageUrl(url), isTrue);
    });

    test('Getir CDN image should be valid', () {
      const url = 'https://cdn.getir.com/product/5f12345_1600.jpg';
      expect(isValidImageUrl(url), isTrue);
    });

    test('Pure product webpage URL without image extension should be rejected as image', () {
      const url = 'https://www.migros.com.tr/sensodyne-tam-koruma-beyazlatici-dis-macunu-2-x-75-ml-p-2070239';
      expect(isValidImageUrl(url), isFalse);
    });

    test('Pure Trendyol product webpage URL should be rejected as image', () {
      const url = 'https://www.trendyol.com/sensodyne/tam-koruma-dis-macunu-p-123456';
      expect(isValidImageUrl(url), isFalse);
    });

    test('Pure Hepsiburada product webpage URL should be rejected as image', () {
      const url = 'https://www.hepsiburada.com/sensodyne-dis-macunu-p-HBV000123';
      expect(isValidImageUrl(url), isFalse);
    });
  });
}
