import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/deal.dart';
import '../../widgets/affiliate/store_redirect_dialog.dart';
import '../analytics_service.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'adapters/hepsiburada_affiliate_adapter.dart';
import 'adapters/amazon_affiliate_adapter.dart';
import 'affiliate_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Mağaza yönlendirmelerini yöneten merkezi profesyonel hibrit servis.
/// 
/// 1. Şalter Kontrolü (Kill-Switch): Mağaza şalteri kapalıysa doğrudan organik linki açar (%100 eski dünya).
/// 2. Hepsiburada: Cihazda Hepsiburada uygulaması yüklüyse `hbapp://` derin linki ile 
///    **0 ms doğrudan native uygulamayı açar** (Tarayıcı YOK, Popup YOK, Gecikme YOK).
///    Adjust takip parametreleri (`adjust_tracker`, `adj_adgroup`) doğrudan uygulama içine teslim edilir.
/// 3. Amazon: Amazon linkleri doğrudan amazon.com.tr kanonik domaininde `tag=firsatkolik-21` parametresi taşır.
///    Herhangi bir aracı 302 yönlendirme sunucusu bulunmadığından ve Android App Links
///    doğrudan com.amazon.mShop.android.shopping tarafından dinlendiğinden,
///    **0 ms doğrudan resmi Amazon uygulamasına (veya tarayıcıya)** fırlatılır (Tarayıcı YOK, Popup YOK).
/// 4. Teknosa & Diğer Mağazalar: Ekranda 1.2 sn StoreRedirectDialog HUD'ı gösterilir; diyalog arka planda
///    rdr.btrck.com 302 yönlendirmesini çözerek TUNE tıklamasını kaydeder ve yakalanan kanonik
///    teknosa.com adresini doğrudan yerel Teknosa uygulamasına (com.tmob.teknosa) fırlatır (CHROME HİÇ AÇILMAZ).
/// 5. Fallback (Uygulama Yüklü Değilse): Kullanıcıda mağaza uygulaması yoksa, modern StoreRedirectDialog
///    HUD'ı eşliğinde temiz web deneyimine aktarır.
class StoreRedirectService {
  StoreRedirectService._();

  /// Verilen URL'yi mağazaya yönlendirir.
  static Future<void> launchStore(
    BuildContext context, {
    required String rawUrl,
    String? storeName,
    String? dealId,
    String? category,
    double? price,
  }) async {
    if (rawUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı henüz eklenmedi')),
        );
      }
      return;
    }

    Trace? redirectTrace;
    try {
      redirectTrace = FirebasePerformance.instance.newTrace('store_redirect_latency');
      await redirectTrace.start();
    } catch (_) {}

    try {
      // 1. URL Temizleme / Normalizasyon
      String cleanUrl = rawUrl.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }

      // 2. Kill-Switch Kontrolü (Web Admin Ayarı)
      final adapter = AffiliateService.getAdapter(cleanUrl);
      final bool isAffiliateEnabled = adapter != null && adapter.isEnabled;

      final effectiveStoreName = storeName?.isNotEmpty == true 
          ? storeName! 
          : (adapter?.storeName ?? 'Mağaza');

      // Observability: "Fırsata Git" Outbound Affiliate Tıklaması
      AnalyticsService.instance.logDealOutboundClick(
        dealId: dealId ?? 'unknown',
        storeName: effectiveStoreName,
        category: category ?? 'diger',
        price: price,
        url: cleanUrl,
      );

      if (adapter != null && !adapter.isEnabled) {
        _log('🛑 [AFFILIATE-KILLSWITCH] ${adapter.storeName} affiliate şalteri KAPALI. Organik linke unwrap ediliyor: $cleanUrl');
        final cleanOrganic = adapter.convert(Uri.parse(cleanUrl));
        if (cleanOrganic.isNotEmpty && cleanOrganic.startsWith('http')) {
          cleanUrl = cleanOrganic;
        } else {
          cleanUrl = Deal.cleanProductUrl(cleanUrl);
        }
        _log('   👉 Açılacak Organik Hedef: $cleanUrl');
        await _launchDirect(Uri.parse(cleanUrl));
        return;
      }

      final uri = Uri.parse(cleanUrl);

      // 3. Şalter KAPALI veya Desteklenmeyen Normal Mağaza ise:
      // Eskisi gibi organik link doğrudan açılır (0 ms native app veya browser; geçiş HUD'ı açılmaz).
      if (!isAffiliateEnabled) {
        _log('ℹ️ [STORE-REDIRECT] Standart Organik Yönlendirme: $cleanUrl');
        await _launchDirect(uri);
        return;
      }

      // 4. Şalter AÇIK ve Affiliate Aktif:

      // A) HEPSİBURADA: Cihazda yerel uygulama yüklüyse hbapp:// ile 0 ms doğrudan native açılış!
      // (Adjust parametreleri doğrudan intent deeplink olarak teslim edilir; sahte bot pinglemesi yapılmaz)
      if (adapter is HepsiburadaAffiliateAdapter) {
        final hbNativeUrl = adapter.buildNativeAppUrl(uri);
        if (hbNativeUrl != null && hbNativeUrl.isNotEmpty) {
          final hbUri = Uri.parse(hbNativeUrl);
          if (await canLaunchUrl(hbUri)) {
            _log('⚡ [HEPSIBURADA-DIRECT] 0 ms doğrudan native hbapp:// açılıyor (Tarayıcı ve popup atlandı): $hbNativeUrl');
            final launched = await launchUrl(
              hbUri,
              mode: LaunchMode.externalApplication,
            );
            if (launched) return;
          }
        }
      }

      // B) AMAZON: Amazon linkleri doğrudan amazon.com.tr kanonik alan adı üzerinde tag parametresi taşır.
      // Herhangi bir aracı yönlendirme sunucusu (302) veya harici reklam ağı bulunmadığından,
      // ve Android App Links doğrudan com.amazon.mShop.android.shopping tarafından dinlendiğinden,
      // 0 ms LaunchMode.externalApplication ile doğrudan yerel Amazon uygulamasına (veya tarayıcıya) fırlatılır!
      if (adapter is AmazonAffiliateAdapter) {
        final affiliateUrl = adapter.convert(uri);
        final targetUri = Uri.parse(affiliateUrl.isNotEmpty ? affiliateUrl : cleanUrl);
        _log('⚡ [AMAZON-DIRECT] 0 ms doğrudan Amazon App Link fırlatılıyor: $targetUri');
        await _launchDirect(targetUri);
        return;
      }

      // C) TEKNOSA & DİĞER MAĞAZALAR (Veya Hepsiburada uygulaması yüklü olmayan durumlar):
      // TUNE HasOffers (Teknosa) takip ağında, ara tarayıcı açılışını ve çirkin takip URL'sini önlemek için
      // 1.2 saniyelik kurumsal StoreRedirectDialog HUD'ı açılır; diyalog arka planda rdr.btrck.com 302 yönlendirmesini
      // sessizce çözerek TUNE tıklamasını kaydeder ve yakalanan hedef adresi doğrudan yerel mağaza uygulamasına fırlatır (Chrome açılmaz).
      final affiliateUrl = adapter.convert(uri);
      final targetAffiliateUri = Uri.parse(affiliateUrl.isNotEmpty ? affiliateUrl : cleanUrl);

      _log('🌟 [STORE-REDIRECT-HUD] $effectiveStoreName Güvenli Geçiş HUD\'ı ile yönlendiriliyor: $targetAffiliateUri');
      if (context.mounted) {
        await StoreRedirectDialog.show(
          context: context,
          storeName: effectiveStoreName,
          targetUri: targetAffiliateUri,
        );
      } else {
        await _launchDirect(targetAffiliateUri);
      }
    } catch (e) {
      _log('❌ [STORE-REDIRECT] Hata: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mağaza bağlantısı açılamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      try {
        await redirectTrace?.stop();
      } catch (_) {}
    }
  }

  /// Organik linkler veya fallback için doğrudan harici açılış
  static Future<void> _launchDirect(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (launched) return;
    } catch (_) {}

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
      );
    } catch (_) {
      throw Exception('Bağlantı açılamadı');
    }
  }
}
