import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/deal.dart';
import '../../models/category.dart';
import '../../theme/app_theme.dart';

// Kırmızı çizgi çizmek için CustomPainter
class StrikeThroughPainter extends CustomPainter {
  const StrikeThroughPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Metnin ortasından geçen kırmızı çizgi
    final startPoint = Offset(0, size.height / 2);
    final endPoint = Offset(size.width, size.height / 2);
    canvas.drawLine(startPoint, endPoint, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String getStoreAsset(String storeName) {
  final lower = storeName.toLowerCase().trim();
  if (lower.contains('trendyol')) return 'assets/trendyol.jpg';
  if (lower.contains('hepsiburada')) return 'assets/hepsiburada.jpg';
  if (lower.contains('n11')) return 'assets/n11.jpg';
  if (lower.contains('amazon')) return 'assets/amazon.jpg';
  if (lower.contains('pazarama')) return 'assets/pazarama.jpg';
  if (lower.contains('vatan')) return 'assets/vatan.jpg';
  if (lower.contains('mediamarkt') || lower.contains('media markt')) return 'assets/mediamarkt.jpg';
  if (lower.contains('incehesap') || lower.contains('ince hesap')) return 'assets/incehesap.jpg';
  if (lower.contains('itopya')) return 'assets/itopya.jpg';
  if (lower.contains('teknosa')) return 'assets/teknosa.jpg';
  if (lower.contains('zara')) return 'assets/zara.jpg';
  if (lower.contains('mango')) return 'assets/mango.jpg';
  if (lower.contains('mavi')) return 'assets/mavi.jpg';
  if (lower.contains('defacto')) return 'assets/defacto.jpg';
  if (lower.contains('beymen')) return 'assets/beymen.jpg';
  if (lower.contains('idefix')) return 'assets/idefix.jpg';
  if (lower.contains('havit')) return 'assets/havit.jpg';
  if (lower.contains('migros')) return 'assets/migros.jpg';
  if (lower.contains('getir')) return 'assets/getir.jpg';
  return 'assets/logo.jpg';
}

Widget buildStoreLogo(String storeName, {double size = 16, double borderRadius = 4}) {
  final assetPath = getStoreAsset(storeName);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.grey.withValues(alpha: 0.25),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius > 0.5 ? borderRadius - 0.5 : 0),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.storefront_rounded,
          size: size * 0.75,
          color: Colors.grey[600],
        ),
      ),
    ),
  );
}

String getCategoryDisplayName(String categoryIdOrName) {
  if (categoryIdOrName.isEmpty) {
    return 'Genel';
  }
  
  // Önce ID olarak kontrol et (case-insensitive)
  final categoryIdLower = categoryIdOrName.toLowerCase().trim();
  
  // "diğer" -> "diger" dönüşümü (eski bot formatı için)
  final normalizedId = categoryIdLower == 'diğer' ? 'diger' : categoryIdLower;
  
  try {
    final category = Category.categories.firstWhere(
      (cat) => cat.id.toLowerCase() == normalizedId,
      orElse: () => Category.categories.first, // Bulunamazsa "Tümü" döndür
    );
    return category.name;
  } catch (e) {
    // ID olarak bulunamazsa, name olarak kontrol et
    try {
      final category = Category.categories.firstWhere(
        (cat) => cat.name.toLowerCase() == categoryIdOrName.toLowerCase(),
        orElse: () => Category.categories.first,
      );
      return category.name;
    } catch (e2) {
      // Hiçbiri bulunamazsa, direkt döndür (eski format için)
      return categoryIdOrName;
    }
  }
}

String getThermometerEmoji(int hotVotes, int coldVotes) {
  final totalVotes = hotVotes + coldVotes;
  if (totalVotes == 0) return '🤷';
  
  final hotPercentage = (hotVotes / totalVotes * 100).round();
  
  if (hotPercentage >= 80) return '🔥';  // Efsane fırsat
  if (hotPercentage >= 60) return '👍';  // İyi fırsat
  if (hotPercentage >= 40) return '🤔';  // Eh işte
  if (hotPercentage >= 20) return '😬';  // Pek değil
  return '🥶';  // Kötü fırsat
}

String formatRelativeTime(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inMinutes < 1) return 'Şimdi';
  if (difference.inMinutes < 60) return '${difference.inMinutes} dakika önce';
  if (difference.inHours < 24) return '${difference.inHours} saat önce';
  if (difference.inDays == 1) return 'Dün';
  if (difference.inDays < 7) return '${difference.inDays} gün önce';
  return DateFormat('d MMM').format(date);
}

Future<void> openProductLink(BuildContext context, String url) async {
  if (url.isEmpty) return;
  
  try {
    // URL'yi düzelt - http:// veya https:// yoksa ekle
    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    
    final uri = Uri.parse(cleanUrl);
    
    try {
      // Önce external application ile dene
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (e) {
      // External başarısız, devam et
    }
    
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (launched) return;
    } catch (e) {
      // Platform default da başarısız
    }
    
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
      );
    } catch (e) {
      throw Exception('Bağlantı açılamadı');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bağlantı açılamadı: ${e.toString()}'),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void showExpiredBottomSheet(BuildContext context, Deal deal) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50] ?? const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timer_off_rounded,
                size: 40,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Fırsat Süresi Doldu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aradığınız fırsat yayından kaldırılmış veya silinmiş olabilir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Kapat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openProductLink(context, deal.link);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Şansını Dene / Mağazaya Git',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
