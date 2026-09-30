import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../services/app_badge_service.dart';
import '../widgets/skeletons/notification_list_skeleton.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import 'deal_detail_screen.dart';
import 'message_screen.dart';
import 'kuponlar_page.dart';

class AdminNotificationsScreen extends StatefulWidget {
  final String? initialTab; // 'all', 'admin', 'replies'
  final String? highlightNotificationId;
  final String? highlightDealId;

  const AdminNotificationsScreen({
    super.key,
    this.initialTab,
    this.highlightNotificationId,
    this.highlightDealId,
  });

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late String _selectedTab; // 'all', 'admin', 'replies'
  bool _hasAutoOpened = false;
  final Set<String> _locallyDismissedIds = {};
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab ?? 'all';
    AppBadgeService.instance.syncBadgeWithFirestore();
    _authSub = _authService.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    try {
      return DateFormat('d MMMM yyyy • HH:mm', 'tr_TR').format(dt);
    } catch (_) {
      return DateFormat('d MMM yyyy • HH:mm').format(dt);
    }
  }

  /// Akıllı bildirim zaman damgası formatlayıcı (bugün, dün veya geçmiş tarih)
  String _formatNotificationTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);
    final differenceInDays = today.difference(itemDate).inDays;

    if (differenceInDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (differenceInDays == 1) {
      return 'Dün ${DateFormat('HH:mm').format(dt)}';
    } else if (now.year == dt.year) {
      try {
        return DateFormat('d MMM • HH:mm', 'tr_TR').format(dt);
      } catch (_) {
        return DateFormat('d MMM • HH:mm').format(dt);
      }
    } else {
      try {
        return DateFormat('d MMM yyyy', 'tr_TR').format(dt);
      } catch (_) {
        return DateFormat('d MMM yyyy').format(dt);
      }
    }
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    // Okundu işaretle
    if (!(item['read'] as bool? ?? false)) {
      await _firestoreService.markNotificationAsRead(currentUserId, item['id'] as String);
      AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: currentUserId);
    }

    final type = (item['type'] ?? 'deal').toString();
    final dealId = (item['dealId'] ?? '').toString().trim();
    final commentId = (item['commentId'] ?? '').toString().trim();

    // Akıllı ve karşılıklı dışlayan (mutually exclusive) durum tespiti
    final rawStatus = (item['status'] as String? ?? '').toLowerCase();
    final titleLower = (item['title'] as String? ?? '').toLowerCase();
    final bool isApproved;
    final bool isRejected;
    if (rawStatus == 'approved') {
      isApproved = true;
      isRejected = false;
    } else if (rawStatus == 'rejected') {
      isApproved = false;
      isRejected = true;
    } else {
      isApproved = titleLower.contains('onaylandı') || titleLower.contains('onaylandi');
      isRejected = !isApproved && (titleLower.contains('reddedildi') || titleLower.contains('red'));
    }

    if (type == 'deal') {
      if (dealId.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(dealId: dealId),
          ),
        );
      } else if (mounted) {
        _showModernNotificationDetailDialog(context, item);
      }
    } else if (type == 'comment_reply' || type == 'comment') {
      // Hem yoruma cevap hem de fırsata ana yorum doğrudan ilgili yoruma scroll eder
      if (dealId.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(
              dealId: dealId,
              scrollToCommentId: commentId.isNotEmpty ? commentId : null,
            ),
          ),
        );
      } else if (mounted) {
        _showModernNotificationDetailDialog(context, item);
      }
    } else if (type == 'submission_status') {
      if (isApproved && dealId.isNotEmpty && mounted) {
        // Onaylanan fırsat tıklandığında doğrudan canlı fırsat detayına git!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(dealId: dealId),
          ),
        );
      } else if (mounted) {
        _showModernNotificationDetailDialog(
          context,
          item,
          isApproved: isApproved,
          isRejected: isRejected,
        );
      }
    } else if (type == 'admin_message') {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MessageScreen(
              otherUserId: 'admin',
              otherUserName: 'FırsatKolik Yönetim',
              otherUserImageUrl: 'assets/logo.webp',
              isAdminMessage: true,
            ),
          ),
        );
      }
    } else if (type == 'coupon' || type == 'community_coupon') {
      // Topluluk kuponu bildiriminde Kuponlar sayfasının Topluluk sekmesine git
      if (mounted) {
        final kId = (item['kuponId'] ?? item['kupon_id'] ?? '').toString().trim();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KuponlarPage(
              initialTabIndex: 1,
              highlightKuponId: kId.isNotEmpty ? kId : null,
            ),
          ),
        );
      }
    } else if (type == 'marketing' || type == 'manual_notification' || type == 'admin') {
      // Bir fırsata işaret ediyorsa ve görsel/uzun kampanya metni yoksa doğrudan fırsata git
      final hasImage = (item['imageUrl'] as String? ?? '').trim().isNotEmpty;
      final bodyText = (item['body'] as String? ?? '').trim();
      if (dealId.isNotEmpty && !hasImage && bodyText.length < 80 && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(dealId: dealId),
          ),
        );
      } else if (mounted) {
        _showModernNotificationDetailDialog(context, item);
      }
    } else {
      if (dealId.isNotEmpty && !isRejected && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(dealId: dealId),
          ),
        );
      } else if (mounted) {
        _showModernNotificationDetailDialog(context, item);
      }
    }
  }

  /// Modern ve içeriğe duyarlı bildirim detay modalı (İlkel AlertDialog yerine)
  Future<void> _showModernNotificationDetailDialog(
    BuildContext context,
    Map<String, dynamic> item, {
    bool isApproved = false,
    bool isRejected = false,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dealId = (item['dealId'] ?? '').toString().trim();
    final dealTitle = (item['dealTitle'] ?? '').toString().trim();
    final commentId = (item['commentId'] ?? '').toString().trim();
    final imageUrl = (item['imageUrl'] as String? ?? '').trim();
    final title = (item['title'] ?? 'Bildirim Detayı').toString().trim();
    final body = (item['body'] ?? '').toString().trim();
    final type = (item['type'] ?? '').toString();
    final createdAt = item['createdAt'] as DateTime?;

    IconData headerIcon = Icons.notifications_active_rounded;
    Color headerColor = primaryColor;
    Color headerBg = isDark ? primaryColor.withValues(alpha: 0.18) : primaryColor.withValues(alpha: 0.1);
    String headerBadgeText = 'BİLDİRİM';

    if (isApproved) {
      headerIcon = Icons.verified_rounded;
      headerColor = const Color(0xFF10B981);
      headerBg = isDark ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFECFDF5);
      headerBadgeText = 'ONAYLANDI';
    } else if (isRejected) {
      headerIcon = Icons.info_outline_rounded;
      headerColor = const Color(0xFFF59E0B);
      headerBg = isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : const Color(0xFFFFFBEB);
      headerBadgeText = 'REDDEDİLDİ';
    } else if (type == 'admin_message') {
      headerIcon = Icons.campaign_rounded;
      headerColor = const Color(0xFFFF5722);
      headerBg = isDark ? const Color(0xFFFF5722).withValues(alpha: 0.2) : const Color(0xFFFBE9E7);
      headerBadgeText = 'YÖNETİCİ DUYURUSU';
    } else if (type == 'comment_reply' || type == 'comment') {
      headerIcon = Icons.chat_bubble_outline_rounded;
      headerColor = const Color(0xFF2196F3);
      headerBg = isDark ? const Color(0xFF2196F3).withValues(alpha: 0.2) : const Color(0xFFEFF6FF);
      headerBadgeText = 'TOPLULUK';
    } else if (type == 'marketing') {
      headerIcon = Icons.local_offer_rounded;
      headerColor = const Color(0xFFFF6B35);
      headerBg = isDark ? const Color(0xFFFF6B35).withValues(alpha: 0.2) : const Color(0xFFFFF3EE);
      headerBadgeText = 'KAMPANYA';
    } else if (type == 'coupon' || type == 'community_coupon') {
      headerIcon = Icons.confirmation_number_rounded;
      headerColor = const Color(0xFF8E24AA);
      headerBg = isDark ? const Color(0xFF8E24AA).withValues(alpha: 0.2) : const Color(0xFFF3E5F5);
      headerBadgeText = 'TOPLULUK KUPONU';
    } else if (type == 'deal') {
      headerIcon = Icons.local_fire_department_rounded;
      headerColor = const Color(0xFFFF6B35);
      headerBg = isDark ? const Color(0xFFFF6B35).withValues(alpha: 0.2) : const Color(0xFFFFF3EE);
      headerBadgeText = 'FIRSAT';
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sürükleme çizgisi
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(headerIcon, color: headerColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: headerBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          headerBadgeText,
                          style: TextStyle(
                            color: headerColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (createdAt != null)
                        Text(
                          _formatDateTime(createdAt),
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            if (dealTitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  dealTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 180,
                    color: isDark ? Colors.white10 : Colors.black12,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.grey[300] : const Color(0xFF4B5563),
              ),
            ),
            if (isRejected) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.help_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (item['moderationReason'] != null && (item['moderationReason'] as String).trim().isNotEmpty)
                            ? (item['moderationReason'] as String).trim()
                            : 'Paylaşılan fırsat topluluk kurallarımıza, fiyat/stok kriterlerine veya mükerrer paylaşımlara göre incelenerek onaylanmamıştır.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if (dealId.isNotEmpty && !isRejected) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DealDetailScreen(
                                dealId: dealId,
                                scrollToCommentId: commentId.isNotEmpty ? commentId : null,
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        (type == 'comment' || type == 'comment_reply')
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.launch_rounded,
                        size: 18,
                      ),
                      label: Text(
                        (type == 'comment' || type == 'comment_reply')
                            ? 'Yorumu Gör'
                            : 'Fırsatı Görüntüle',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (type == 'admin_message') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MessageScreen(
                                otherUserId: 'admin',
                                otherUserName: 'FırsatKolik Yönetim',
                                otherUserImageUrl: 'assets/logo.webp',
                                isAdminMessage: true,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Mesajlara Git'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (type == 'coupon' || type == 'community_coupon') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          final kId = (item['kuponId'] ?? item['kupon_id'] ?? '').toString().trim();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KuponlarPage(
                                initialTabIndex: 1,
                                highlightKuponId: kId.isNotEmpty ? kId : null,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.confirmation_number_rounded, size: 18),
                      label: const Text('Kuponu Gör'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E24AA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Kapat',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Güvenli, tekil Hero etiketli ve mükerrer çakışmayı önleyen SnackBar gösterici
  void _showFeedbackSnackBar({
    required Widget content,
    Color backgroundColor = const Color(0xFF10B981),
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Eski SnackBar'ı animasyon beklemeden anında temizle (Hero tag çakışmasını kesin önler)
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: KeyedSubtree(
          key: UniqueKey(),
          child: content,
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _markAllAsRead(String currentUserId) async {
    try {
      HapticFeedback.lightImpact();
      await _firestoreService.markAllNotificationsAsRead(currentUserId);
      AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: currentUserId);
      if (!mounted) return;
      _showFeedbackSnackBar(
        content: const Row(
          children: [
            Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Tüm bildirimler okundu olarak işaretlendi'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackBar(
        content: Text('Hata oluştu: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = _authService.currentUser?.uid;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (currentUserId == null) {
      final textMain = isDark ? Colors.white : AppTheme.textPrimary;
      final textSub = isDark ? Colors.grey[400] : AppTheme.textSecondary;
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Bildirimler', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          foregroundColor: textMain,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_none_rounded, size: 54, color: primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bildirimler İçin Giriş Yapın',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textMain),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fırsat bildirimlerinizi, yorum yanıtlarını ve yönetici mesajlarını takip etmek için lütfen giriş yapın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: textSub, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    showGuestLoginBottomSheet(
                      context,
                      title: 'Bildirimler İçin Giriş Yap! 🔔',
                      message: 'Kişiselleştirilmiş fırsat bildirimlerinizi görmek ve yönetmek için hemen giriş yapın.',
                      primaryButtonText: '🚀 Google ile Giriş Yap',
                    );
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Giriş Yap', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getUserNotificationsStream(currentUserId),
      builder: (context, snapshot) {
        final rawItems = snapshot.data ?? [];
        if (_locallyDismissedIds.isNotEmpty) {
          _locallyDismissedIds.removeWhere((id) => !rawItems.any((i) => i['id'] == id));
        }
        final allItems = rawItems.where((i) => !_locallyDismissedIds.contains(i['id'])).toList();

        // Sekme bazlı okunmamış sayıları
        final unreadAll = allItems.where((i) => !(i['read'] as bool? ?? false)).length;
        final unreadAdmin = allItems.where((i) {
          final isUnread = !(i['read'] as bool? ?? false);
          final type = i['type'] as String? ?? '';
          return isUnread &&
              (type == 'admin_message' ||
                  type == 'admin' ||
                  type == 'marketing' ||
                  type == 'manual_notification' ||
                  type == 'submission_status');
        }).length;
        final unreadReplies = allItems.where((i) {
          final isUnread = !(i['read'] as bool? ?? false);
          final type = i['type'] as String? ?? '';
          return isUnread && (type == 'comment_reply' || type == 'comment');
        }).length;

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
          appBar: AppBar(
            title: const Text('Bildirimler'),
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
            actions: [
              // Tümünü okundu işaretle butonu (Modern, anlaşılır ve belirgin kapsül)
              if (unreadAll > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _markAllAsRead(currentUserId),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF10B981).withValues(alpha: 0.16)
                              : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.45),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.done_all_rounded,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Tümünü Oku',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Tümünü sil butonu
              if (allItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6, right: 12),
                  child: IconButton(
                    onPressed: () => _showDeleteAllDialog(currentUserId),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                    tooltip: 'Tümünü Sil',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        'all',
                        'Tümü',
                        isDark,
                        primaryColor,
                        unreadCount: unreadAll,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        'admin',
                        'Admin',
                        isDark,
                        primaryColor,
                        unreadCount: unreadAdmin,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        'replies',
                        'Yorumlar',
                        isDark,
                        primaryColor,
                        unreadCount: unreadReplies,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _buildNotificationsContent(
                  allItems,
                  snapshot.connectionState,
                  snapshot.error,
                  currentUserId,
                  isDark,
                  primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton(
    String tab,
    String label,
    bool isDark,
    Color primaryColor, {
    int unreadCount = 0,
  }) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDark ? Colors.red.withValues(alpha: 0.3) : const Color(0xFFFFEBEE)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.red[700],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsContent(
    List<Map<String, dynamic>> allItems,
    ConnectionState connectionState,
    Object? error,
    String currentUserId,
    bool isDark,
    Color primaryColor,
  ) {
    if (connectionState == ConnectionState.waiting && allItems.isEmpty) {
      return const NotificationListSkeleton();
    }
    if (error != null) {
      return Center(child: Text('Hata: $error'));
    }

    // Otomatik odaklama / detay açma (Push veya in-app bildirimine tıklanıp gelindiyse)
    if (!_hasAutoOpened && (widget.highlightNotificationId != null || widget.highlightDealId != null)) {
      final target = allItems.cast<Map<String, dynamic>?>().firstWhere(
        (it) =>
            (widget.highlightNotificationId != null && it?['id'] == widget.highlightNotificationId) ||
            (widget.highlightDealId != null && it?['dealId'] == widget.highlightDealId),
        orElse: () => null,
      );
      if (target != null) {
        _hasAutoOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openNotification(target);
          }
        });
      }
    }

    // Tab filtrelemesi
    final items = allItems.where((item) {
      final type = item['type'] as String? ?? '';
      if (_selectedTab == 'admin') {
        return type == 'admin_message' ||
            type == 'admin' ||
            type == 'marketing' ||
            type == 'manual_notification' ||
            type == 'submission_status';
      } else if (_selectedTab == 'replies') {
        return type == 'comment_reply' || type == 'comment';
      }
      return true;
    }).toList();

    if (items.isEmpty) {
      IconData emptyIcon = Icons.notifications_none_rounded;
      String emptyTitle = 'Henüz bildirim yok';
      String emptySubtitle = 'İlginizi çeken fırsatları, indirimleri ve duyuruları buradan takip edebilirsiniz.';

      if (_selectedTab == 'admin') {
        emptyIcon = Icons.campaign_outlined;
        emptyTitle = 'Yönetici bildirimi yok';
        emptySubtitle = 'Paylaştığınız fırsatların onay durumları ve resmi sistem duyuruları burada listelenir.';
      } else if (_selectedTab == 'replies') {
        emptyIcon = Icons.chat_bubble_outline_rounded;
        emptyTitle = 'Yorum cevabı yok';
        emptySubtitle = 'Fırsatlara ve yorumlarınıza gelen yanıtlar burada listelenir.';
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(emptyIcon, size: 40, color: Colors.grey[400]),
              ),
              const SizedBox(height: 18),
              Text(
                emptyTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isUnread = !(item['read'] as bool? ?? false);
        final type = (item['type'] ?? 'deal').toString();

        // Akıllı ve karşılıklı dışlayan (mutually exclusive) durum tespiti
        final rawStatus = (item['status'] as String? ?? '').toLowerCase();
        final titleLower = (item['title'] as String? ?? '').toLowerCase();
        final bool isAppr;
        final bool isRej;
        if (rawStatus == 'approved') {
          isAppr = true;
          isRej = false;
        } else if (rawStatus == 'rejected') {
          isAppr = false;
          isRej = true;
        } else {
          isAppr = titleLower.contains('onaylandı') || titleLower.contains('onaylandi');
          isRej = !isAppr && (titleLower.contains('reddedildi') || titleLower.contains('red'));
        }

        // İkon ve renk belirleme (Profesyonel, pozitif ve bağlamsal)
        IconData icon = Icons.local_fire_department_rounded;
        Color iconColor = const Color(0xFFFF6B35);
        Color iconBg = isDark
            ? const Color(0xFFFF6B35).withValues(alpha: 0.15)
            : const Color(0xFFFFF3EE);

        if (type == 'submission_status') {
          if (isAppr) {
            // Onaylanan fırsat için yeşil kutlama rozeti (Kırmızı çarpı KESİNLİKLE YOK)
            icon = Icons.verified_rounded;
            iconColor = const Color(0xFF10B981);
            iconBg = isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.18)
                : const Color(0xFFECFDF5);
          } else if (isRej) {
            // Reddedilen fırsat için yumuşak kehribar/amber bilgilendirme rozeti
            icon = Icons.info_outline_rounded;
            iconColor = const Color(0xFFF59E0B);
            iconBg = isDark
                ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                : const Color(0xFFFFFBEB);
          } else {
            icon = Icons.assignment_outlined;
            iconColor = Colors.blue;
            iconBg = isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50]!;
          }
        } else if (type == 'comment_reply' || type == 'comment') {
          icon = Icons.chat_bubble_outline_rounded;
          iconColor = const Color(0xFF2196F3);
          iconBg = isDark
              ? const Color(0xFF2196F3).withValues(alpha: 0.18)
              : const Color(0xFFEFF6FF);
        } else if (type == 'marketing') {
          icon = Icons.local_offer_rounded;
          iconColor = const Color(0xFFFF6B35);
          iconBg = isDark
              ? const Color(0xFFFF6B35).withValues(alpha: 0.18)
              : const Color(0xFFFFF3EE);
        } else if (type == 'coupon' || type == 'community_coupon') {
          icon = Icons.confirmation_number_rounded;
          iconColor = const Color(0xFF8E24AA);
          iconBg = isDark
              ? const Color(0xFF8E24AA).withValues(alpha: 0.18)
              : const Color(0xFFF3E5F5);
        } else if (type == 'admin_message' ||
            type == 'admin' ||
            type == 'manual_notification') {
          icon = Icons.campaign_rounded;
          iconColor = const Color(0xFFFF5722);
          iconBg = isDark
              ? const Color(0xFFFF5722).withValues(alpha: 0.18)
              : const Color(0xFFFBE9E7);
        } else {
          // Fırsat bildirimleri: sebebe göre özelleştir
          final reason = (item['reason'] as String? ?? '').toLowerCase();
          if (reason == 'keyword') {
            icon = Icons.saved_search_rounded;
            iconColor = const Color(0xFFFF9800);
            iconBg = isDark
                ? const Color(0xFFFF9800).withValues(alpha: 0.18)
                : const Color(0xFFFFF8E1);
          } else if (reason == 'author') {
            icon = Icons.person_pin_circle_rounded;
            iconColor = const Color(0xFF10B981);
            iconBg = isDark
                ? const Color(0xFF10B981).withValues(alpha: 0.18)
                : const Color(0xFFE8F5E9);
          }
        }

        final notifId = item['id'] as String;
        final itemImageUrl = (item['imageUrl'] as String? ?? '').trim();
        final itemMerchant = (item['merchant'] ?? '').toString().trim();
        final itemPrice = (item['price'] ?? '').toString().trim();

        // Başlık metnini biçimlendir (Topluluk bildirimlerindeki mükerrer 💬 emojisini temizle)
        String displayTitle = (item['title'] as String? ?? 'Bildirim').trim();
        if ((type == 'comment' || type == 'comment_reply') && displayTitle.startsWith('💬')) {
          displayTitle = displayTitle.replaceFirst('💬', '').trim();
        }

        // Gövde metnini biçimlendir (dealTitle mükerrerliğini temizle)
        final rawBody = (item['body'] as String? ?? '').trim();
        String displayBody = rawBody;
        final itemDealTitle = (item['dealTitle'] ?? '').toString().trim();

        if (itemDealTitle.isNotEmpty && displayBody.startsWith(itemDealTitle)) {
          displayBody = displayBody.substring(itemDealTitle.length).trim();
          if (displayBody.startsWith(':') || displayBody.startsWith('-')) {
            displayBody = displayBody.substring(1).trim();
          }
        }
        if (type == 'submission_status') {
          if (isAppr) {
            displayBody = 'Fırsatınız başarıyla onaylandı ve yayına alındı.';
          } else if (isRej) {
            final modReason = (item['moderationReason'] as String? ?? '').trim();
            displayBody = modReason.isNotEmpty
                ? 'Red sebebi: $modReason'
                : 'Fırsatınız topluluk kurallarımıza uymadığı için reddedildi.';
          }
        }

        // Dismissible yön ve arka plan mimarisi:
        // Flutter Dismissible sözleşmesinde 'secondaryBackground == null || background != null' zorunludur.
        // isUnread == true:
        //   direction: DismissDirection.horizontal (Sağa: Okundu [background], Sola: Sil [secondaryBackground])
        // isUnread == false:
        //   direction: DismissDirection.endToStart (Yalnızca sola kaydır: Sil [background])
        //   secondaryBackground = null (Assertion hatasını %100 önler)
        final dismissDirection = isUnread ? DismissDirection.horizontal : DismissDirection.endToStart;

        final okunduBackground = Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.done_all_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Okundu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );

        final silBackground = Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF5350), Color(0xFFD32F2F)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Sil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        );

        return Dismissible(
          key: Key(notifId),
          direction: dismissDirection,
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.3,
            DismissDirection.endToStart: 0.3,
          },
          // Okunmamışta sağa kaydırma 'Okundu', okunmuşta tek yön sola kaydırma 'Sil'
          background: isUnread ? okunduBackground : silBackground,
          // Okunmamışta sola kaydırma 'Sil', okunmuşta null (assertion ihlali oluşturmaz)
          secondaryBackground: isUnread ? silBackground : null,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // ─── Sağa Kaydırma: Yalnızca Okunmamış Bildirimleri Okundu İşaretle ───
              if (!isUnread) return false;
              HapticFeedback.lightImpact();
              await _firestoreService.markNotificationAsRead(currentUserId, notifId);
              AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: currentUserId);

              if (context.mounted) {
                _showFeedbackSnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Okundu olarak işaretlendi'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(milliseconds: 1500),
                );
              }
              // Kart yaylanarak yerine döner; 'read: true' verisi geldiğinde otomatik olarak
              // sadece sola kaydırılarak silinebilir (endToStart) moduna geçer.
              return false;
            } else if (direction == DismissDirection.endToStart) {
              // ─── Sola Kaydırma: Silme İşlemini Onayla ───
              HapticFeedback.lightImpact();
              return true;
            }
            return false;
          },
          onDismissed: (direction) async {
            if (direction == DismissDirection.endToStart) {
              setState(() {
                _locallyDismissedIds.add(notifId);
              });
              final notifTitle = item['title'] as String? ?? 'Bildirim';

              try {
                // Firestore'dan tamamen sil
                await _firestoreService.deleteNotification(currentUserId, notifId);
                AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: currentUserId);
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _locallyDismissedIds.remove(notifId);
                  });
                }
              }

              if (context.mounted) {
                _showFeedbackSnackBar(
                  content: Text('"$notifTitle" silindi'),
                  backgroundColor: const Color(0xFF334155),
                  duration: const Duration(seconds: 2),
                );
              }
            }
          },
          child: InkWell(
            onTap: () => _openNotification(item),
            onLongPress: () => _showDeleteNotificationDialog(currentUserId, item),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnread
                    ? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F6FF))
                    : (isDark ? AppTheme.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (type == 'submission_status' && (isAppr || isRej)) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAppr
                                      ? (isDark
                                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                          : const Color(0xFFECFDF5))
                                      : (isDark
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                          : const Color(0xFFFFFBEB)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isAppr
                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  isAppr ? 'Onaylandı' : 'Reddedildi',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isAppr ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            if (item['createdAt'] != null)
                              Text(
                                _formatNotificationTime(item['createdAt'] as DateTime),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (itemDealTitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: Text(
                              itemDealTitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (itemMerchant.isNotEmpty || itemPrice.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3.0),
                            child: Row(
                              children: [
                                if (itemMerchant.isNotEmpty)
                                  Text(
                                    itemMerchant,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                if (itemMerchant.isNotEmpty && itemPrice.isNotEmpty)
                                  Text(
                                    ' • ',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                if (itemPrice.isNotEmpty)
                                  Text(
                                    itemPrice,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (displayBody.isNotEmpty)
                          Text(
                            displayBody,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                              height: 1.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (itemImageUrl.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: itemImageUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 44,
                          height: 44,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (isUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteNotificationDialog(
    String userId,
    Map<String, dynamic> item,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildirimi Sil'),
        content: const Text('Bu bildirimi silmek istediğinize emin misiniz?'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firestoreService.deleteNotification(userId, item['id'] as String);
        AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: userId);
        if (!mounted) return;
        _showFeedbackSnackBar(
          content: const Text('Bildirim silindi'),
          backgroundColor: const Color(0xFF10B981),
        );
      } catch (e) {
        if (!mounted) return;
        _showFeedbackSnackBar(
          content: Text('Silme hatası: $e'),
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _showDeleteAllDialog(String userId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tümünü Sil'),
        content: const Text('Tüm bildirimleri silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'İptal',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Tümünü Sil',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await _firestoreService.deleteAllNotifications(userId);
        AppBadgeService.instance.syncBadgeWithFirestore(targetUserId: userId);

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        _showFeedbackSnackBar(
          content: const Text('Tüm bildirimler silindi'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
        _showFeedbackSnackBar(
          content: Text('Bildirimler silinirken hata oluştu: $cleanMsg'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }
}
