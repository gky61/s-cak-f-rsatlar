import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deal.dart';
import '../theme/app_theme.dart';

class LinkCard extends StatelessWidget {
  final Deal deal;

  const LinkCard({
    super.key,
    required this.deal,
  });

  void _copyLinkToClipboard(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bağlantı panoya kopyalandı!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.transparent,
          width: isDark ? 1 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, color: primaryColor),
              const SizedBox(width: 10),
              Text(
                'Fırsat Bağlantısı',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deal.link.isNotEmpty ? deal.link : 'Bağlantı yakında eklenecek',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : Colors.black87,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: deal.link.isNotEmpty
                      ? () => _copyLinkToClipboard(context, deal.link)
                      : null,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Bağlantıyı Kopyala'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
