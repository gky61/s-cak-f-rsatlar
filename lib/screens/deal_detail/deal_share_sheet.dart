import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/deal.dart';

/// Tek tıkla doğrudan telefonun natif paylaşım ekranını açan Fırsat Paylaşım Servisi.
class DealShareSheet {
  DealShareSheet._();

  /// Fırsatı doğrudan telefonun natif paylaşım diyaloğuyla resimli/metinli paylaşır.
  static Future<void> showShareOptions(
    BuildContext context,
    Deal deal, {
    String? fetchedImageUrl,
  }) async {
    final link = deal.link;
    if (link.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı henüz eklenmedi')),
        );
      }
      return;
    }

    // Zengin paylaşım metni
    final priceStr = deal.price > 0 ? (deal.price % 1 == 0 ? deal.price.toInt().toString() : deal.price.toStringAsFixed(2)) : '';
    final priceText = deal.price > 0 ? '💰 $priceStr TL' : '';
    final discountText = (deal.discountRate != null && deal.discountRate! > 0)
        ? ' (-%${deal.discountRate})'
        : '';

    final shareText = '''🔥 ${deal.title}
🏪 ${deal.store}
$priceText$discountText

👉 ${deal.link}

📱 FIRSATKOLİK ile keşfet: https://firsatkolik.app.link/indirme''';

    // Kullanılacak görsel adresi
    final imageUrl = (deal.imageUrl.isNotEmpty)
        ? deal.imageUrl
        : (fetchedImageUrl ?? '');

    // Görsel varsa indirip natif resimli paylaşım yap
    if (imageUrl.isNotEmpty) {
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
                Text('Fırsat görseli hazırlanıyor...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      try {
        final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final sanitizedId = deal.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
          final file = File('${tempDir.path}/deal_$sanitizedId.jpg');
          await file.writeAsBytes(response.bodyBytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }

          // Doğrudan yerel telefon paylaşım diyaloğunu aç (Resim + Altyazı metni)
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'image/jpeg')],
            text: shareText,
          );
          return;
        }
      } catch (e) {
        debugPrint('Fırsat görseli indirilemedi, metin olarak paylaşılıyor: $e');
      }
    }

    // Görsel yoksa veya indirme başarısızsa doğrudan metin paylaş
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    await Share.share(shareText);
  }
}
