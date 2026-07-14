import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/deal.dart';

/// Paylaşım bottom sheet ve sosyal medya paylaşım fonksiyonları.
class DealShareSheet {
  DealShareSheet._();

  /// Paylaşım bottom sheet'ini gösterir.
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

    // Zengin paylaşım metni
    final priceValText = deal.price == deal.price.toInt() 
        ? deal.price.toInt().toString() 
        : deal.price.toStringAsFixed(2);
    final priceText = deal.price > 0 ? '💰 $priceValText TL' : '';
    final discountText = deal.discountRate != null && deal.discountRate! > 0 
        ? ' (-%${deal.discountRate})' 
        : '';
    final shareText = '''🔥 ${deal.title}
🏪 ${deal.store}
$priceText$discountText

👉 ${deal.link}

📱 FIRSATKOLİK ile keşfet: https://firsatkolik.app.link/indirme''';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Paylaş',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  context,
                  icon: Icons.content_copy_rounded,
                  label: 'Kopyala',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    copyLinkToClipboard(context, link);
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    shareToWhatsApp(context, shareText);
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Twitter',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    shareToTwitter(context, shareText);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Paylaşım seçenek kartı widget'ı.
  static Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WhatsApp paylaşımı.
  static Future<void> shareToWhatsApp(BuildContext context, String text) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp açılamadı')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım hatası: $e')),
        );
      }
    }
  }

  /// Twitter paylaşımı.
  static Future<void> shareToTwitter(BuildContext context, String text) async {
    final uri = Uri.parse('https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Twitter açılamadı')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım hatası: $e')),
        );
      }
    }
  }

  /// Link kopyalama.
  static void copyLinkToClipboard(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bağlantı kopyalandı!'),
      ),
    );
  }
}
