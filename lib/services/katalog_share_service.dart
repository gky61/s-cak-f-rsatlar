import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/katalog.dart';
import '../utils/share_helper.dart';

/// Minimalist ve doğrudan telefonun natif paylaşım ekranını açan Aktüel Katalog Paylaşım Servisi.
class KatalogShareService {
  KatalogShareService._();

  /// Mağaza koduna göre okunabilir mağaza adını döndürür.
  static String _getMagazaAdi(String magazaKodu) {
    switch (magazaKodu.toLowerCase()) {
      case 'bim':
        return 'BİM';
      case 'a101':
        return 'A-101';
      case 'sok':
        return 'ŞOK';
      case 'migros':
        return 'Migros';
      case 'carrefoursa':
        return 'CarrefourSA';
      case 'metro':
        return 'Metro';
      case 'macrocenter':
        return 'MacroCenter';
      case 'getirbuyuk':
        return 'GetirBüyük';
      case 'bizim':
        return 'Bizim Toptan';
      case 'file':
        return 'File';
      case 'happycenter':
        return 'Happy Center';
      case 'hakmar':
        return 'Hakmar';
      case 'hakmarexpress':
        return 'Hakmar Express';
      case 'cagri':
        return 'Çağrı Hipermarket';
      case 'kooperatifmarket':
      case 'kooperatif':
      case 'tarimkredi':
        return 'Kooperatif Market';
      case 'watsons':
        return 'Watsons';
      case 'gratis':
        return 'Gratis';
      case 'rossmann':
        return 'Rossmann';
      case 'cetinkaya':
        return 'Çetinkaya';
      case 'civil':
        return 'Civil';
      case 'evkur':
        return 'Evkur';
      case 'mrdiy':
        return 'MR.DIY';
      case 'teknosa':
        return 'Teknosa';
      case 'vatan':
        return 'Vatan Bilgisayar';
      case 'vestel':
        return 'Vestel';
      default:
        return 'Aktüel Mağaza';
    }
  }

  /// Aktif broşür sayfasını tek tıkla doğrudan telefonun natif paylaşım menüsüne resim dosyası olarak gönderir.
  static Future<void> shareCatalogPage(
    BuildContext context, {
    required Katalog catalog,
    required int currentPageIndex,
  }) async {
    final pageNum = currentPageIndex + 1;
    final totalPages = catalog.sayfaResimleri.length;
    final storeName = _getMagazaAdi(catalog.magazaKodu);

    // Tarih formatlama
    String dateRangeStr = '';
    try {
      final startStr = DateFormat('d MMMM', 'tr_TR').format(catalog.baslangicTarihi);
      final endStr = DateFormat('d MMMM yyyy', 'tr_TR').format(catalog.bitisTarihi);
      dateRangeStr = '$startStr - $endStr';
    } catch (_) {
      dateRangeStr = '${catalog.baslangicTarihi.day}.${catalog.baslangicTarihi.month} - ${catalog.bitisTarihi.day}.${catalog.bitisTarihi.month}.${catalog.bitisTarihi.year}';
    }

    // Aktif sayfa resim bağlantısı
    var currentImageUrl = catalog.sayfaResimleri.isNotEmpty && currentPageIndex < catalog.sayfaResimleri.length
        ? catalog.sayfaResimleri[currentPageIndex]
        : catalog.kapakResmi;
    currentImageUrl = currentImageUrl.trim();
    if (currentImageUrl.startsWith('//')) {
      currentImageUrl = 'https:$currentImageUrl';
    }

    // Resim alt yazısı metni (reklam ve uygulama indirme yönlendirmesiyle)
    final shareCaptionText = '''📰 $storeName - ${catalog.katalogBasligi} (Sayfa $pageNum / $totalPages)
📅 Geçerlilik: $dateRangeStr

🔥 En güncel market kataloglarını, indirim broşürlerini ve sıcak fırsatları anında yakalamak için FırsatKolik uygulamasını yükle!
📱 Uygulamayı İndir: https://firsatkolik.app.link/aktuel''';

    if (currentImageUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await ShareHelper.shareText(shareCaptionText, context: context);
      } else {
        await ShareHelper.shareText(shareCaptionText);
      }
      return;
    }

    // Kullanıcıya resim hazırlanıyor bildirimi göster
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            key: UniqueKey(),
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Broşür görseli hazırlanıyor...'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Arka planda görseli JPG dosyası olarak indirip geçici dizine kaydet
    // FS-AKT-04: Standart Referer/UA başlıkları ve Weserv proxy fallback'i ile 403 Forbidden engeli aşılır.
    Uint8List? imageBytes;
    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Referer': 'https://www.akakce.com/',
      'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    };

    try {
      final response = await http
          .get(Uri.parse(currentImageUrl), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        imageBytes = response.bodyBytes;
      }
    } catch (_) {}

    // Doğrudan istek 403 Forbidden alırsa veya hata verirse otomatik Weserv CDN proxy fallback'ine geç
    if (imageBytes == null) {
      try {
        final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(currentImageUrl)}&output=jpg&w=1400';
        final proxyResponse = await http
            .get(Uri.parse(proxyUrl))
            .timeout(const Duration(seconds: 8));
        if (proxyResponse.statusCode == 200 && proxyResponse.bodyBytes.isNotEmpty) {
          imageBytes = proxyResponse.bodyBytes;
        }
      } catch (e) {
        debugPrint('Proxy ile indirme de başarısız: $e');
      }
    }

    if (imageBytes != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final sanitizedId = catalog.katalogId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final file = File('${tempDir.path}/katalog_${sanitizedId}_p$pageNum.jpg');
        await file.writeAsBytes(imageBytes);

        // Bildirimi kapat ve doğrudan telefonun kendi natif paylaşım diyaloğunu aç
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          await ShareHelper.shareFiles(
            [XFile(file.path, mimeType: 'image/jpeg')],
            text: shareCaptionText,
            context: context,
          );
        } else {
          await ShareHelper.shareFiles(
            [XFile(file.path, mimeType: 'image/jpeg')],
            text: shareCaptionText,
          );
        }
        return;
      } catch (e) {
        debugPrint('Katalog görseli yazılamadı veya paylaşılamadı: $e');
      }
    }

    // İndirme başarısız olursa yedek metin paylaşımı
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await ShareHelper.shareText(
        '$shareCaptionText\n🖼️ Görsel: $currentImageUrl',
        context: context,
      );
    } else {
      await ShareHelper.shareText(
        '$shareCaptionText\n🖼️ Görsel: $currentImageUrl',
      );
    }
  }
}
