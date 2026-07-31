import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/katalog.dart';
import '../theme/app_theme.dart';

/// Modern, profesyonel ve gerçek JPG görsel dosyalı Aktüel Katalog paylaşım bottom sheet bileşeni.
class KatalogShareSheet {
  KatalogShareSheet._();

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
      case 'cagri':
        return 'Çağrı Hipermarket';
      case 'kooperatifmarket':
        return 'Kooperatif Market';
      case 'watsons':
        return 'Watsons';
      case 'gratis':
        return 'Gratis';
      case 'teknosa':
        return 'Teknosa';
      case 'vatan':
        return 'Vatan Bilgisayar';
      default:
        return 'Aktüel Mağaza';
    }
  }

  /// Görsel URL'ini geçici dizine JPG dosyası olarak indirir.
  static Future<File?> _downloadImageFile(String imageUrl, String catalogId, int pageNum) async {
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final sanitizedId = catalogId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final file = File('${tempDir.path}/katalog_${sanitizedId}_p$pageNum.jpg');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('Katalog sayfa görseli indirilemedi: $e');
    }
    return null;
  }

  /// Aktüel katalog sayfasını gerçek JPG görsel dosyası ve viral reklam metniyle paylaşır.
  static Future<void> showShareOptions(
    BuildContext context, {
    required Katalog catalog,
    required int currentPageIndex,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = catalog.sayfaResimleri.length;
    final pageNum = currentPageIndex + 1;
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

    // Resim linki barındırmayan, doğrudan resmi altyazı olarak takip edecek temiz reklamlı metin
    final shareCaptionText = '''📰 $storeName - ${catalog.katalogBasligi} (Sayfa $pageNum / $totalPages)
📅 Geçerlilik: $dateRangeStr

🔥 En güncel market kataloglarını, indirim broşürlerini ve sıcak fırsatları anında yakalamak için FırsatKolik uygulamasını yükle!
📱 Uygulamayı İndir: https://firsatkolik.app.link/aktuel''';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Üst tutamaç çizgisi (Drag Handle)
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // Üst Başlık & Kapat Butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.share_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Kataloğu Paylaş',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Paylaşılacak Broşür Kart Önizlemesi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBackground : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Küçük Önizleme Görseli
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          currentImageUrl,
                          width: 54,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 54,
                            height: 68,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported_outlined, size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    storeName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sayfa $pageNum / $totalPages',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              catalog.katalogBasligi,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📅 $dateRangeStr',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Paylaşım Seçenekleri Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 1. Genel / Yerel Paylaşım (Resim dosyası + Altyazı metni)
                    _buildShareOption(
                      context,
                      icon: Icons.share_rounded,
                      label: 'Görsel Paylaş',
                      color: AppTheme.primary,
                      isDark: isDark,
                      onTap: () async {
                        Navigator.pop(context);
                        _shareImageWithNativeSheet(
                          context,
                          imageUrl: currentImageUrl,
                          catalogId: catalog.katalogId,
                          pageNum: pageNum,
                          caption: shareCaptionText,
                        );
                      },
                    ),

                    // 2. WhatsApp (Doğrudan Görsel Dosyası + Altyazı metni)
                    _buildShareOption(
                      context,
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366), // WhatsApp Green
                      isDark: isDark,
                      onTap: () async {
                        Navigator.pop(context);
                        _shareImageWithNativeSheet(
                          context,
                          imageUrl: currentImageUrl,
                          catalogId: catalog.katalogId,
                          pageNum: pageNum,
                          caption: shareCaptionText,
                        );
                      },
                    ),

                    // 3. Telegram
                    _buildShareOption(
                      context,
                      icon: Icons.send_rounded,
                      label: 'Telegram',
                      color: const Color(0xFF229ED9), // Telegram Blue
                      isDark: isDark,
                      onTap: () async {
                        Navigator.pop(context);
                        _shareImageWithNativeSheet(
                          context,
                          imageUrl: currentImageUrl,
                          catalogId: catalog.katalogId,
                          pageNum: pageNum,
                          caption: shareCaptionText,
                        );
                      },
                    ),

                    // 4. Bağlantıyı Kopyala
                    _buildShareOption(
                      context,
                      icon: Icons.content_copy_rounded,
                      label: 'Kopyala',
                      color: const Color(0xFF6B7280), // Neutral Grey
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(context);
                        final copyText = '$shareCaptionText\n🖼️ Görsel: $currentImageUrl';
                        Clipboard.setData(ClipboardData(text: copyText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Katalog metni ve bağlantısı kopyalandı!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Resmi arka planda indirip yerel JPG dosyası olarak WhatsApp/Telegram/Sistem paylaşım penceresiyle açar.
  static Future<void> _shareImageWithNativeSheet(
    BuildContext context, {
    required String imageUrl,
    required String catalogId,
    required int pageNum,
    required String caption,
  }) async {
    // İlerleme göstergesi Toast / SnackBar
    if (context.mounted) {
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

    final imageFile = await _downloadImageFile(imageUrl, catalogId, pageNum);

    if (imageFile != null && await imageFile.exists()) {
      // Gerçek JPG dosyasını metin altyazısı ile birlikte yerel paylaşım diyaloğuyla paylaş
      await Share.shareXFiles(
        [XFile(imageFile.path, mimeType: 'image/jpeg')],
        text: caption,
      );
    } else {
      // Görsel indirilemezse yedek metin paylaşımı yap
      final fallbackText = '$caption\n🖼️ Görsel: $imageUrl';
      await Share.share(fallbackText);
    }
  }

  /// Tekil paylaşım seçeneği düğmesi
  static Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
