import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/deal.dart';

/// Fırsat detay paylaşım servisi - doğrudan natif telefon paylaşım menüsünü açar.
class DealShareSheet {
  DealShareSheet._();

  /// Fırsatı doğrudan telefonun yerel natif paylaşım ekranı (Share Sheet) ile paylaşır.
  static Future<void> showShareOptions(BuildContext context, Deal deal) async {
    final link = deal.link;
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı henüz eklenmedi'),
        ),
      );
      return;
    }

    // Zengin ve profesyonel paylaşım metni
    final priceValText = DynamicCurrencyFormatter().format(deal.price);
    final priceText = deal.price > 0 ? '💰 $priceValText' : '';
    final discountText = deal.discountRate != null && deal.discountRate! > 0 
        ? ' (-%${deal.discountRate})' 
        : '';

    final shareText = '''🔥 ${deal.title}
🏪 ${deal.store}
$priceText$discountText

👉 ${deal.link}

📱 FIRSATKOLİK ile keşfet: https://firsatkolik.app.link/indirme''';

    // Doğrudan işletim sisteminin yerel paylaşım diyaloğunu aç
    await Share.share(shareText);
  }
}
