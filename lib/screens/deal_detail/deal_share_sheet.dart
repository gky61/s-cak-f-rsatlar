import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/deal.dart';
import '../../widgets/deal_forward_bottom_sheet.dart';

/// Fırsat Detay ekranı için hem uygulama içi mesajlaşma hem de yerel (natif) paylaşım seçeneklerini sunan servis.
class DealShareSheet {
  DealShareSheet._();

  /// Fırsat Paylaşım & İletme ekranını (In-App Chat Forward + Native Share) açar.
  static Future<void> showShareOptions(BuildContext context, Deal deal) async {
    await DealForwardBottomSheet.show(context, deal);
  }

  /// Doğrudan uygulama içi mesajlaşma iletme ekranını açar.
  static Future<void> showForwardSheet(BuildContext context, Deal deal) async {
    await DealForwardBottomSheet.show(context, deal);
  }

  /// Fırsatın FırsatKolik uygulama içi bağlantısını panoya kopyalar.
  static Future<void> copyDealLink(BuildContext context, Deal deal) async {
    final dealUrl = 'https://firsatkolik.app/deal/${deal.id}';
    await Clipboard.setData(ClipboardData(text: dealUrl));
    HapticFeedback.lightImpact();

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'FırsatKolik bağlantısı panoya kopyalandı!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
  }

  /// Ürünün orijinal mağaza (Amazon, Trendyol, Hepsiburada vb.) bağlantısını panoya kopyalar.
  static Future<void> copyStoreLink(BuildContext context, Deal deal) async {
    final link = deal.link.trim();
    if (link.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu fırsat için mağaza bağlantısı bulunamadı.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            duration: const Duration(milliseconds: 2000),
          ),
        );
      }
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));
    HapticFeedback.lightImpact();

    if (context.mounted) {
      final storeName = deal.store.isNotEmpty ? deal.store : 'Mağaza';
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$storeName ürün linki panoya kopyalandı!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
  }

  /// Fırsatı tek tıkla doğrudan telefonun kendi natif paylaşım ekranında paylaşır (WhatsApp, Telegram vb.).
  static Future<void> shareToNativeApps(BuildContext context, Deal deal) async {
    final link = deal.link.trim().isNotEmpty 
        ? deal.link.trim() 
        : 'https://firsatkolik.app/deal/${deal.id}';

    // Fırsat fiyat ve indirim metni
    final priceValText = DynamicCurrencyFormatter().format(deal.price);
    final priceText = deal.price > 0 ? '💰 $priceValText' : '';
    final discountText = (deal.discountRate != null && deal.discountRate! > 0) 
        ? ' (-%${deal.discountRate})' 
        : '';

    // Zengin ve temiz metin
    final shareText = '''🔥 ${deal.title}
🏪 ${deal.store}
$priceText$discountText

$link

📱 FIRSATKOLİK ile incele: https://firsatkolik.app/deal/${deal.id}''';

    try {
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
