import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// P0-16 (R-MOB-08): Zorunlu Minimum Sürüm ve Sözleşme Emeklilik Kapısı
class AppVersionService {
  AppVersionService._();
  static final AppVersionService instance = AppVersionService._();

  /// Mevcut uygulamanın derleme numarası (pubspec.yaml 1.1.0+2)
  static const int currentBuildNumber = 2;
  static const String currentVersionName = '1.1.0';

  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.firsatkolik.app';
  static const String appStoreUrl = 'https://apps.apple.com/app/id6740032906';

  bool _isDialogShowing = false;

  /// Açılışta veya ana sayfada sürüm kontrolü yapar
  Future<bool> checkVersion(BuildContext context) async {
    if (kIsWeb) return true; // Web admin/showcase için atla

    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app')
          .get()
          .timeout(const Duration(seconds: 4));
      if (!doc.exists) return true;

      final data = doc.data() ?? {};
      final int minSupportedBuild = (data['minSupportedBuild'] as num?)?.toInt() ?? 1;
      final int latestBuild = (data['latestBuild'] as num?)?.toInt() ?? currentBuildNumber;
      final String updateMessage = data['updateMessage'] as String? ?? 
          'Uygulamamızın en güncel ve güvenli sürümünü kullanabilmeniz için güncelleme gereklidir.';

      if (kDebugMode) {
        print('📱 [AppVersionService] Mevcut Build: $currentBuildNumber, Min: $minSupportedBuild, En Güncel: $latestBuild');
      }

      // Zorunlu güncelleme kontrolü
      if (currentBuildNumber < minSupportedBuild) {
        if (context.mounted && !_isDialogShowing) {
          _isDialogShowing = true;
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PopScope(
              canPop: false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.system_update_rounded, color: Colors.deepOrange, size: 28),
                    SizedBox(width: 10),
                    Text('Güncelleme Gerekli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(updateMessage, style: const TextStyle(fontSize: 14, height: 1.4)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Bu sürüm artık desteklenmemektedir. Devam etmek için lütfen mağazadan güncelleyin.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Mağazaya Git ve Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _openStore,
                  ),
                ],
              ),
            ),
          );
          _isDialogShowing = false;
        }
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [AppVersionService] Sürüm kontrol hatası (atlandı): $e');
      }
      return true;
    }
  }

  Future<void> _openStore() async {
    final url = Platform.isIOS ? appStoreUrl : playStoreUrl;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) print('Mağaza açma hatası: $e');
    }
  }
}
