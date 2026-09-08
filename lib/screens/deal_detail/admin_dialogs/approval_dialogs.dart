import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../../models/deal.dart';
import '../../../services/affiliate/affiliate_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/notification_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Onaylama akışını başlatan wrapper.
Future<void> confirmApproval({
  required BuildContext context,
  required String dealId,
  required Deal? currentDeal,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  await showApproveOptions(
    context: context,
    dealId: dealId,
    currentDeal: currentDeal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );
}

/// Onaylama seçenekleri dialog'u.
Future<void> showApproveOptions({
  required BuildContext context,
  required String dealId,
  required Deal? currentDeal,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  final option = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Onaylama Seçeneği'),
      content: const Text('Bu fırsatı nasıl onaylamak istersiniz?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'normal'),
          child: const Text('Normal Onayla'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'hide_price'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue[700],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off, size: 18),
              SizedBox(width: 4),
              Text('Fiyatı Gizle & Onayla'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'editor'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange[700],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 18),
              SizedBox(width: 4),
              Text('Editörün Seçimi'),
            ],
          ),
        ),
      ],
    ),
  );

  if (option == null || !context.mounted) return;

  if (option == 'normal') {
    await _approveDeal(
      context: context,
      dealId: dealId,
      currentDeal: currentDeal,
      firestoreService: firestoreService,
      onDealUpdated: onDealUpdated,
      isEditorPick: false,
    );
  } else if (option == 'hide_price') {
    await _approveDeal(
      context: context,
      dealId: dealId,
      currentDeal: currentDeal,
      firestoreService: firestoreService,
      onDealUpdated: onDealUpdated,
      isEditorPick: false,
      hidePrice: true,
    );
  } else if (option == 'editor') {
    await _approveDeal(
      context: context,
      dealId: dealId,
      currentDeal: currentDeal,
      firestoreService: firestoreService,
      onDealUpdated: onDealUpdated,
      isEditorPick: true,
    );
  }
}

/// Fırsatı onaylama.
Future<void> _approveDeal({
  required BuildContext context,
  required String dealId,
  required Deal? currentDeal,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
  bool isEditorPick = false,
  bool hidePrice = false,
}) async {
  final updates = <String, dynamic>{
    'isApproved': true,
    'isEditorPick': isEditorPick,
  };
  if (hidePrice) {
    updates['hidePrice'] = true;
  }

  bool wasConverted = false;
  if (currentDeal != null) {
    final currentUrl = currentDeal.link;
    _log('═══════════════════════════════════════════════════════════');
    _log('👑 [AFFILIATE-TEST] Mobil Fırsat Detay Onay: Fırsat Onaylanıyor');
    _log('   🆔 Fırsat ID: $dealId');
    _log('   🏷️ Başlık: ${currentDeal.title}');
    _log('   🔗 Mevcut Link: $currentUrl');
    if (currentUrl.isNotEmpty) {
      final adapter = AffiliateService.getAdapter(currentUrl);
      try {
        final settingsDoc = await firestoreService.firestore.collection('settings').doc('app').get();
        if (settingsDoc.exists && settingsDoc.data() != null) {
          AffiliateService.syncFromMap(settingsDoc.data()!);
        }
      } catch (_) {}

      final uri = Uri.tryParse(currentUrl);
      final isAlreadyAffiliate = adapter != null && uri != null && adapter.isAlreadyAffiliate(uri);

      if (adapter != null && !adapter.isEnabled) {
        // 🛑 Kill-Switch Aktif (Şalter Kapalı): Eğer linkte affiliate kalmışsa organik temiz linke unwrap et
        _log('🛑 [AFFILIATE-TEST] ${adapter.storeName} affiliate şalteri KAPALI (enabled=false).');
        _log('   🛡️ Fırsat onaylanırken organik temiz ürün linkine unwrap ediliyor: $currentUrl');
        final cleanUrl = uri != null ? adapter.convert(uri) : Deal.cleanProductUrl(currentUrl);
        updates['url'] = cleanUrl;
        updates['link'] = cleanUrl;
        updates['cleanUrl'] = cleanUrl;
        wasConverted = true;
      } else if (isAlreadyAffiliate) {
        // ⚡ Hızlı Yol (Fast-Path): Link zaten paylaşım anında affiliate yapılmış ve hazır.
        // Tekrar hesaplama yapılmaz; hazır link doğrudan "Mağazaya Git" butonu arkasında yayına girer.
        _log('⚡ [AFFILIATE-TEST] Hızlı Yol (Fast-Path): Link zaten hazır affiliate linki, mükerrer hesaplama yapılmadı.');
        _log('   👉 Aktif Link: $currentUrl');
      } else {
        // 🛡️ Emniyet Ağı (Safety Net): Yalnızca eski/organik kalmış linkler için tek seferlik dönüşüm
        _log('🔄 [AFFILIATE-TEST] Emniyet Ağı: Link henüz affiliate değil, dönüştürülüyor...');

        try {
          final convertedUrl = await AffiliateService.resolveAndConvertToAffiliate(currentUrl);
          if (convertedUrl != currentUrl) {
            updates['url'] = convertedUrl;
            updates['link'] = convertedUrl;
            wasConverted = true;
            _log('🎉 [AFFILIATE-TEST] Fırsat onaylandı ve affiliate linke dönüştürüldü!');
            _log('   👉 Eski: $currentUrl');
            _log('   👉 Yeni: $convertedUrl');
          } else {
            _log('ℹ️ [AFFILIATE-TEST] Link dönüştürülmedi (Şalter kapalı veya desteklenmeyen mağaza): $convertedUrl');
          }
        } catch (e) {
          _log('⚠️ [AFFILIATE-TEST] Onay sırasında link dönüştürme hatası, mevcut link korundu: $e');
        }
      }

      // cleanUrl eksik veya affiliate yönlendirme linki ise organik temiz URL'i Firestore'a kaydet
      if (currentDeal.cleanUrl.trim().isEmpty ||
          currentDeal.cleanUrl.contains('btrck.com') ||
          currentDeal.cleanUrl.contains('7t4g.adj.st') ||
          currentDeal.cleanUrl.contains('adj.st')) {
        final clean = Deal.cleanProductUrl(currentDeal.displayUrl.isNotEmpty ? currentDeal.displayUrl : currentUrl);
        if (clean.isNotEmpty &&
            !clean.contains('btrck.com') &&
            !clean.contains('7t4g.adj.st') &&
            !clean.contains('adj.st')) {
          updates['cleanUrl'] = clean;
          _log('✨ [AFFILIATE-TEST] cleanUrl Firestore alanına eklendi: $clean');
        }
      }
    }
    _log('═══════════════════════════════════════════════════════════');
  }

  await firestoreService.updateDeal(dealId, updates);
  
  if (currentDeal != null) {
    try {
      final notificationService = NotificationService();
      await notificationService.checkKeywordsAndNotify(
        dealId,
        currentDeal.title,
        currentDeal.description,
      );
      _log('✅ Anahtar kelime kontrolü yapıldı: ${currentDeal.title}');

      if (currentDeal.isUserSubmitted && currentDeal.postedBy.isNotEmpty) {
        _log('ℹ️ Takip bildirimi Cloud Function tarafından gönderilecek: ${currentDeal.postedBy}');
      }
    } catch (e) {
      _log('❌ Anahtar kelime kontrolü hatası: $e');
    }
  }
  
  onDealUpdated();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasConverted
              ? (isEditorPick
                  ? 'Fırsat Editörün Seçimi & Affiliate Linkiyle Onaylandı ⭐🔗'
                  : 'Fırsat Onaylandı & Affiliate Linke Dönüştürüldü! ✅🔗')
              : (isEditorPick
                  ? 'Fırsat Editörün Seçimi olarak onaylandı ⭐'
                  : 'Fırsat Onaylandı ✅'),
        ),
        backgroundColor: isEditorPick ? Colors.orange[700] : Colors.green,
      ),
    );
  }
}

/// Yayından kaldırma.
Future<void> unpublishDeal({
  required BuildContext context,
  required String dealId,
  required FirestoreService firestoreService,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Fırsatı Kaldır'),
      content: const Text('Bu fırsatı kaldırmak istediğinize emin misiniz?\n\nFırsat "Süresi Bitenler" bölümüne taşınacak.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.orange),
          child: const Text('Evet, Kaldır'),
        ),
      ],
    ),
  );

  if (confirm != true || !context.mounted) return;

  await firestoreService.updateDeal(dealId, {'isExpired': true});
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fırsat kaldırıldı ve süresi bitenler bölümüne taşındı ⚠️'),
        backgroundColor: Colors.orange,
      ),
    );
    Navigator.of(context).pop();
  }
}

/// Fırsatı reddetme.
Future<void> rejectDeal({
  required BuildContext context,
  required String dealId,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Fırsatı Reddet'),
      content: const Text('Bu fırsatı reddetmek istediğinize emin misiniz?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Evet, Reddet'),
        ),
      ],
    ),
  );

  if (confirm != true || !context.mounted) return;

  await firestoreService.updateDeal(dealId, {'isExpired': true});
  onDealUpdated();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fırsat Reddedildi ❌'), backgroundColor: Colors.red),
    );
  }
}
