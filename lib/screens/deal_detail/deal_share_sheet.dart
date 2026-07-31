import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/deal.dart';

/// Fırsat Detay ekranı için doğrudan telefonun yerel (natif) paylaşım menüsünü açan servis.
class DealShareSheet {
  DealShareSheet._();

  /// Fırsatı tek tıkla doğrudan telefonun kendi natif paylaşım ekranında paylaşır.
  static Future<void> showShareOptions(BuildContext context, Deal deal) async {
    final link = deal.link.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı henüz eklenmedi'),
        ),
      );
      return;
    }

    // Fırsat fiyat ve indirim metni
    final priceValText = DynamicCurrencyFormatter().format(deal.price);
    final priceText = deal.price > 0 ? '💰 $priceValText' : '';
    final discountText = (deal.discountRate != null && deal.discountRate! > 0) 
        ? ' (-%${deal.discountRate})' 
        : '';

    // Zengin ve temiz metin (Yinelenen ekstra URL satırı olmadan, görsel kart önizlemesi oluşturan ürün bağlantısı)
    final shareText = '''🔥 ${deal.title}
🏪 ${deal.store}
$priceText$discountText

$link

📱 FIRSATKOLİK ile keşfet: https://firsatkolik.app.link/indirme''';

    try {
      // Doğrudan telefonun yerel (natif) paylaşım penceresini aç
      await Share.share(
        shareText,
        subject: deal.title,
      );
    } catch (e) {
      debugPrint('Fırsat paylaşım hatası: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım başlatılamadı: $e')),
        );
      }
    }
  }
}
