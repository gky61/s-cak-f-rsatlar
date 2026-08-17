import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/katalog.dart';

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
    final currentImageUrl = catalog.sayfaResimleri.isNotEmpty && currentPageIndex < catalog.sayfaResimleri.length
        ? catalog.sayfaResimleri[currentPageIndex]
        : catalog.kapakResmi;

    // Resim alt yazısı metni (reklam ve uygulama indirme yönlendirmesiyle)
    final shareCaptionText = '''📰 $storeName - ${catalog.katalogBasligi} (Sayfa $pageNum / $totalPages)
📅 Geçerlilik: $dateRangeStr

🔥 En güncel market kataloglarını, indirim broşürlerini ve sıcak fırsatları anında yakalamak için FırsatKolik uygulamasını yükle!
📱 Uygulamayı İndir: https://firsatkolik.app.link/aktuel''';

    // Kullanıcıya resim hazırlanıyor bildirimi göster
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Broşür görseli hazırlanıyor...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Arka planda görseli JPG dosyası olarak indirip geçici dizine kaydet
    try {
      final response = await http.get(Uri.parse(currentImageUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final sanitizedId = catalog.katalogId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final file = File('${tempDir.path}/katalog_${sanitizedId}_p$pageNum.jpg');
        await file.writeAsBytes(response.bodyBytes);

        // Bildirimi kapat ve doğrudan telefonun kendi natif paylaşım diyaloğunu aç
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/jpeg')],
          text: shareCaptionText,
        );
        return;
      }
    } catch (e) {
      debugPrint('Katalog görseli indirilemedi, yedek metin paylaşılıyor: $e');
    }

    // İndirme başarısız olursa yedek metin paylaşımı
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    await Share.share('$shareCaptionText\n🖼️ Görsel: $currentImageUrl');
  }
}
