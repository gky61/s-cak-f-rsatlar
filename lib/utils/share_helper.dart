import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// iOS, iPadOS ve Android platformları arasında natif paylaşımı sorunsuz kılan yardımcı sınıf.
///
/// iOS ve iPadOS üzerinde çalışan `UIActivityViewController` (popover),
/// `sharePositionOrigin` parametresinin boş olmayan (non-zero: {{x, y}, {w, h}})
/// ve ekran koordinatları dahilinde bir `Rect` olmasını şart koşar.
/// Aksi halde iOS `PlatformException(error, sharePositionOrigin: argument must be set...)`
/// fırlatır. Bu yardımcı, her koşulda geçerli ve güvenli bir Rect üreterek hatayı %100 önler.
class ShareHelper {
  ShareHelper._();

  /// Verilen BuildContext veya ekran boyutlarına göre geçerli, sıfır olmayan
  /// ve ekran sınırları içinde bir `sharePositionOrigin` (Rect) hesaplar.
  static Rect calculateOrigin(BuildContext? context) {
    double screenWidth = 430.0;
    double screenHeight = 932.0;

    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view != null) {
        final size = view.physicalSize / view.devicePixelRatio;
        if (size.width > 0 && size.height > 0) {
          screenWidth = size.width;
          screenHeight = size.height;
        }
      }
    } catch (_) {}

    if (context != null && context.mounted) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
          final pos = box.localToGlobal(Offset.zero);
          // Ekran koordinat sınırları içinde tut
          final left = pos.dx.clamp(0.0, (screenWidth - 20.0).clamp(0.0, screenWidth));
          final top = pos.dy.clamp(0.0, (screenHeight - 20.0).clamp(0.0, screenHeight));
          final width = box.size.width.clamp(10.0, screenWidth - left);
          final height = box.size.height.clamp(10.0, screenHeight - top);
          return Rect.fromLTWH(left, top, width, height);
        }
      } catch (_) {}
    }

    // Güvenli ekran alt / orta alanı (Non-zero ve kesinlikle ekran koordinatları içinde)
    return Rect.fromLTWH(
      0.0,
      screenHeight * 0.5,
      screenWidth,
      (screenHeight * 0.4).clamp(50.0, screenHeight),
    );
  }

  /// iOS ve Android uyumlu güvenli metin ve bağlantı paylaşımı.
  static Future<ShareResult> shareText(
    String text, {
    String? subject,
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    final origin = sharePositionOrigin ?? calculateOrigin(context);
    return await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: origin,
    );
  }

  /// iOS ve Android uyumlu güvenli dosya (görsel vb.) paylaşımı.
  static Future<ShareResult> shareFiles(
    List<XFile> files, {
    String? text,
    String? subject,
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    final origin = sharePositionOrigin ?? calculateOrigin(context);
    return await Share.shareXFiles(
      files,
      text: text,
      subject: subject,
      sharePositionOrigin: origin,
    );
  }
}
