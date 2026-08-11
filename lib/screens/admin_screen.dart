import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import '../firebase_options.dart';
import '../models/deal.dart';
import '../models/category.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/badge_helper.dart';
import '../utils/asset_path_migration.dart';
import '../theme/app_theme.dart';
import 'deal_detail_screen.dart';
import 'profile_screen.dart';
import 'message_screen.dart';
import '../widgets/admin_reports_list.dart';
import 'notification_debug_screen.dart';
import '../widgets/test_automation_widget.dart';
import '../utils/test_logger.dart';
import '../services/link_preview_service.dart';
import '../services/category_detection_service.dart';
import '../services/ai_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

// Affiliate Link Configuration
// Buraya kendi affiliate ID'lerinizi ekleyin
const Map<String, Map<String, String>> _affiliateConfig = {
  'trendyol': {
    'boutiqueId': '', // Trendyol Boutique ID'nizi buraya ekleyin
  },
  'hepsiburada': {
    'utmSource': 'linkgelir', // Hepsiburada Link Gelir için genellikle 'linkgelir' kullanılır
  },
  'n11': {
    'refId': '', // N11 Referans ID'nizi buraya ekleyin
  },
  'amazon': {
    'tag': '', // Amazon Associate Tag'inizi buraya ekleyin
  },
  'gittigidiyor': {
    'affiliateId': '', // GittiGidiyor Affiliate ID'nizi buraya ekleyin
  },
};

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

enum _AdminListType { pending, userSubmitted, published, expired, messages }

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  
  // Tab bildirim sayıları
  int _pendingCount = 0;
  int _userSubmittedCount = 0;
  int _expiredCount = 0;
  int _usersCount = 0;
  int _unreadMessagesCount = 0;
  int _pendingReportsCount = 0;
  int _testDealsCount = 0;
  
  // Stream Subscriptions - Bellek sızıntısını önlemek için
  StreamSubscription? _pendingSubscription;
  StreamSubscription? _userSubmittedSubscription;
  StreamSubscription? _expiredSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _reportsSubscription;
  StreamSubscription? _testDealsSubscription;
  StreamSubscription? _mobileTestCommandSubscription;
  
  // Kullanıcı arama
  String _userSearchQuery = '';
  final TextEditingController _userSearchController = TextEditingController();

  // Tab'a bildirim badge'i ile widget oluştur
  Widget _buildTabWithBadge(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Kategori ID'sini kategori adına çevir
  String _getCategoryDisplayName(String categoryIdOrName) {
    final normalizedValue = categoryIdOrName.toLowerCase().trim();
    // Önce ID olarak kontrol et (bot'tan ID geliyor)
    for (final cat in Category.categories) {
      if (cat.id.toLowerCase() == normalizedValue && cat.id != 'tumu') {
        return cat.name;
      }
    }
    // ID bulunamazsa, name olarak kontrol et
    for (final cat in Category.categories) {
      if (cat.name.toLowerCase() == normalizedValue && cat.id != 'tumu') {
        return cat.name;
      }
    }
    // Hiçbir şey bulunamazsa, orijinal değeri döndür
    return categoryIdOrName;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadTabCounts();
    _loadReportCounts();
    // Admin paneli her açıldığında admin_deals topic'ine abone ol (bildirimlerin gelmesi için)
    _ensureAdminNotificationSubscription();
    _startMobileTestCommandListener();
  }

  /// Admin bildirimlerine (onay bekleyen fırsatlar) abone olmayı garanti et
  Future<void> _ensureAdminNotificationSubscription() async {
    try {
      await NotificationService().subscribeToAdminTopic();
      if (kDebugMode) _log('✅ Admin bildirim aboneliği doğrulandı');
    } catch (e) {
      if (kDebugMode) _log('⚠️ Admin bildirim aboneliği: $e');
    }
  }

  /// Kullanıcı manuel olarak admin bildirim aboneliğini yeniler
  Future<void> _refreshAdminNotificationSubscription() async {
    try {
      await NotificationService().subscribeToAdminTopic();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin bildirimleri yenilendi. Yeni onay bekleyen fırsatlarda bildirim alacaksınız.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abonelik yenilenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  @override
  void dispose() {
    // Tüm stream subscription'ları iptal et
    _pendingSubscription?.cancel();
    _userSubmittedSubscription?.cancel();
    _expiredSubscription?.cancel();
    _usersSubscription?.cancel();
    _messagesSubscription?.cancel();
    _reportsSubscription?.cancel();
    _testDealsSubscription?.cancel();
    _mobileTestCommandSubscription?.cancel();
    _tabController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  void _loadTabCounts() {
    // Onay bekleyen (bot fırsatları)
    _pendingSubscription = _firestoreService.getPendingDealsStream().listen((deals) {
      if (mounted) {
        setState(() {
          _pendingCount = deals.length;
        });
      }
    });
    
    // Paylaşılanlar (kullanıcı fırsatları)
    _userSubmittedSubscription = _firestoreService.getUserSubmittedPendingDealsStream().listen((deals) {
      if (mounted) {
        setState(() {
          _userSubmittedCount = deals.length;
        });
      }
    });
    
    // Süresi bitenler
    _expiredSubscription = _firestoreService.getExpiredDealsStream().listen((deals) {
      if (mounted) {
        setState(() {
          _expiredCount = deals.length;
        });
      }
    });
    
    // Kullanıcılar
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _usersCount = snapshot.docs.length;
        });
      }
    });

    // Okunmamış mesajlar (admin tarafından okunmamış)
    _messagesSubscription = _firestoreService.getAllMessagesStream().listen((messages) {
      if (mounted) {
        setState(() {
          _unreadMessagesCount = messages.where((m) => !m.isReadByAdmin).length;
        });
      }
    });

    // Test Fırsatları sayısı
    _testDealsSubscription = FirebaseFirestore.instance
        .collection('deals')
        .where('isTest', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _testDealsCount = snapshot.docs.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetici Paneli'),
        actions: [
          Tooltip(
            message: 'Admin bildirim aboneliğini yenile',
            child: IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: _refreshAdminNotificationSubscription,
            ),
          ),
          Tooltip(
            message: 'Bildirim Tanı Aracı',
            child: IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.red),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationDebugScreen()),
                );
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: [
            _buildTabWithBadge('Onay Bekleyen', _pendingCount),
            _buildTabWithBadge('Paylaşılanlar', _userSubmittedCount),
            _buildTabWithBadge('Süresi Biten', _expiredCount),
            _buildTabWithBadge('Kullanıcılar', _usersCount),
            _buildTabWithBadge('Mesajlar', _unreadMessagesCount),
            _buildTabWithBadge('Raporlar', _pendingReportsCount),
            _buildTabWithBadge('Test Otomasyonu', _testDealsCount),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDealList(_AdminListType.pending),
          _buildDealList(_AdminListType.userSubmitted),
          _buildDealList(_AdminListType.expired),
          _buildUsersList(),
          _buildMessagesList(),
          const AdminReportsList(),
          const TestAutomationWidget(),
        ],
      ),
    );
  }

  // Rapor sayısı için yeni metod
  void _loadReportCounts() {
     _reportsSubscription = _firestoreService.reportsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingReportsCount = snapshot.docs.length;
        });
      }
    });
  }

  Widget _buildDealList(_AdminListType type) {
    final bool isPending = type == _AdminListType.pending;
    final bool isUserSubmitted = type == _AdminListType.userSubmitted;
    final bool isPublished = type == _AdminListType.published;
    final bool isExpiredList = type == _AdminListType.expired;

    return StreamBuilder<List<Deal>>(
      stream: switch (type) {
        _AdminListType.pending => _firestoreService.getPendingDealsStream(),
        _AdminListType.userSubmitted => _firestoreService.getUserSubmittedPendingDealsStream(),
        _AdminListType.published => _firestoreService.getApprovedDealsStream(),
        _AdminListType.expired => _firestoreService.getExpiredDealsStream(),
        _AdminListType.messages => Stream.value(<Deal>[]), // Messages için ayrı widget kullanılıyor
      },
      builder: (context, snapshot) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final deals = snapshot.data ?? [];

        if (deals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPending 
                      ? Icons.check_circle_outline 
                      : isUserSubmitted
                          ? Icons.people_outline
                          : isPublished
                              ? Icons.published_with_changes
                              : Icons.hourglass_disabled_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  isPending 
                      ? 'Onay bekleyen yok' 
                      : isUserSubmitted
                          ? 'Paylaşım bekleyen yok'
                          : isPublished
                              ? 'Yayında fırsat yok'
                              : 'Süresi biten ilan yok',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Deal Paylaşım Durdur/Devam Et butonu (sadece Paylaşılanlar tab'ı için)
            if (isUserSubmitted)
              StreamBuilder<bool>(
                stream: _firestoreService.dealSharingEnabledStream(),
                builder: (context, snapshot) {
                  final isEnabled = snapshot.data ?? true;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleDealSharing(!isEnabled),
                        icon: Icon(isEnabled ? Icons.stop_circle : Icons.play_circle, size: 20),
                        label: Text(isEnabled ? 'Paylaşımı Durdur' : 'Paylaşıma Devam Et'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEnabled ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            // Tümünü Reddet butonu (sadece onay bekleyenler için - bot fırsatları)
            if (isPending && deals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectAllPendingDeals(deals),
                    icon: const Icon(Icons.close, size: 20),
                    label: Text('Tümünü Reddet (${deals.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            // Tümünü Reddet butonu (kullanıcı paylaşımları için)
            if (isUserSubmitted && deals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectAllPendingDeals(deals),
                    icon: const Icon(Icons.close, size: 20),
                    label: Text('Tümünü Reddet (${deals.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            // Tümünü Sil butonu (sadece süresi bitenler için)
            if (isExpiredList && deals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteAllExpiredDeals(deals),
                    icon: const Icon(Icons.delete_forever, size: 20),
                    label: Text('Tümünü Sil (${deals.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: deals.length,
          itemBuilder: (context, index) {
            return _buildAdminCard(
              deals[index],
              type,
            );
          },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminCard(Deal deal, _AdminListType type) {
    final bool isPending = type == _AdminListType.pending;
    final bool isUserSubmitted = type == _AdminListType.userSubmitted;
    final bool isPublished = type == _AdminListType.published;
    final bool isExpiredCard = type == _AdminListType.expired;
    final currencyFormat = DynamicCurrencyFormatter();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          if (isExpiredCard)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (deal.isApproved == true)
                              ? 'Bu fırsat onaylanmış ve yayınlanmıştı, süresi dolduğu için pasife alınmış.'
                              : 'Bu fırsat onaylanmamış ve süresi dolduğu için pasife alınmış.',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: deal.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: deal.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: Colors.grey[200]),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
            ),
            title: Text(
              deal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${deal.store} • ${_getCategoryDisplayName(deal.category)}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (deal.brand != null && deal.brand!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Marka: ${deal.brand}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                ],
                if (deal.ratingValue != null || deal.ratingCount != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                      const SizedBox(width: 2),
                      if (deal.ratingValue != null)
                        Text(
                          deal.ratingValue!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      if (deal.ratingCount != null) ...[
                        const SizedBox(width: 2),
                        Text(
                          '(${deal.ratingCount})',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ],
                if (deal.isAmazonWarehouse) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4), width: 0.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_rounded, size: 11, color: Color(0xFFD97706)),
                        SizedBox(width: 3),
                        Text(
                          'Depo',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (deal.hidePrice)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_off, size: 12, color: Colors.blue),
                        SizedBox(width: 3),
                        Text(
                          'Fiyat Gizli (Kampanya)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      FormattedPriceText(
                        value: deal.price,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      if (deal.originalPrice != null && deal.originalPrice! > deal.price) ...[
                        const SizedBox(width: 6),
                        FormattedPriceText(
                          value: deal.originalPrice,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        if (deal.effectiveDiscountRate != null && deal.effectiveDiscountRate! > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          child: Text(
                            '%${deal.effectiveDiscountRate}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                if (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECB3), // Açık sarı/turuncu arka plan
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      deal.priceLabel!,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100), // Koyu turuncu/kahverengi yazı
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DealDetailScreen(dealId: deal.id),
              ),
            ),
          ),
          if (isPending || isUserSubmitted) ...[
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _rejectDeal(deal.id),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reddet', style: TextStyle(color: Colors.red)),
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey[200]),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showEditDialog(deal),
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    label: const Text('Düzenle', style: TextStyle(color: Colors.blue)),
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey[200]),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showApproveOptions(deal.id),
                    icon: const Icon(Icons.check, color: Colors.green),
                    label: const Text('Onayla', style: TextStyle(color: Colors.green)),
                  ),
                ),
              ],
            ),
          ],
          if (isPublished) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _unpublishDeal(deal.id),
                  icon: const Icon(Icons.visibility_off, size: 20),
                  label: const Text('Yayından Kaldır'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (isExpiredCard)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Detay sayfasından bilgileri güncelleyebilir veya tekrar aktifleştirebilirsiniz.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _reactivateDeal(deal.id),
                      icon: const Icon(Icons.restore, size: 20),
                      label: const Text('Tekrar Yayına Al'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showApproveOptions(String id) async {
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

    if (option == null) return;

    if (option == 'normal') {
      await _approveDeal(id, isEditorPick: false);
    } else if (option == 'hide_price') {
      await _approveDeal(id, isEditorPick: false, hidePrice: true);
    } else if (option == 'editor') {
      await _approveDeal(id, isEditorPick: true);
    }
  }

  Future<void> _approveDeal(String id, {bool isEditorPick = false, bool hidePrice = false}) async {
    final updates = <String, dynamic>{
      'isApproved': true,
      'isEditorPick': isEditorPick,
    };
    if (hidePrice) {
      updates['hidePrice'] = true;
    }
    await _firestoreService.updateDeal(id, updates);
    
    // Anahtar kelime kontrolü yap - onaylanan fırsat için
    try {
      final dealDoc = await _firestoreService.getDeal(id);
      if (dealDoc != null) {
        final notificationService = NotificationService();
        await notificationService.checkKeywordsAndNotify(
          id,
          dealDoc.title,
          dealDoc.description,
        );
        _log('✅ Anahtar kelime kontrolü yapıldı: ${dealDoc.title}');
        
        // Takip bildirimi artık Cloud Function tarafından otomatik gönderiliyor
        // Deal onaylandığında Firestore trigger tetiklenir ve Cloud Function bildirimleri gönderir
        if (dealDoc.isUserSubmitted && dealDoc.postedBy.isNotEmpty) {
          _log('ℹ️ Takip bildirimi Cloud Function tarafından gönderilecek: ${dealDoc.postedBy}');
        }
      }
    } catch (e) {
      _log('❌ Anahtar kelime kontrolü hatası: $e');
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditorPick
                ? 'Fırsat Editörün Seçimi olarak onaylandı ⭐'
                : 'Fırsat Onaylandı ✅',
          ),
          backgroundColor: isEditorPick ? Colors.orange[700] : Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectDeal(String id) async {
    await _firestoreService.updateDeal(id, {'isExpired': true}); // Reddedileni bitmiş sayalım veya silebiliriz
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fırsat Reddedildi ❌'), backgroundColor: Colors.red),
      );
    }
  }

  // Deal paylaşımını durdur/devam ettir
  Future<void> _toggleDealSharing(bool enabled) async {
    final success = await _firestoreService.setDealSharingEnabled(enabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? (enabled ? 'Paylaşım devam ediyor ✅' : 'Paylaşım durduruldu ⏸️')
                : 'Bir hata oluştu',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _rejectAllPendingDeals(List<Deal> deals) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tümünü Reddet'),
        content: Text(
          'Onay bekleyen ${deals.length} fırsatın tümünü reddetmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Tümünü Reddet'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Tüm bekleyen fırsatları reddet
    int successCount = 0;
    int failCount = 0;

    for (final deal in deals) {
      try {
        await _firestoreService.updateDeal(deal.id, {'isExpired': true});
        successCount++;
      } catch (e) {
        _log('Fırsat reddetme hatası (${deal.id}): $e');
        failCount++;
      }
    }

    if (mounted) {
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount fırsat reddedildi ❌'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount fırsat reddedildi, $failCount fırsat için hata oluştu ⚠️'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _unpublishDeal(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yayından Kaldır'),
        content: const Text('Bu fırsatı yayından kaldırmak istediğinize emin misiniz? Fırsat ana ekrandan kaldırılacak.'),
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

    if (confirm != true) return;

    await _firestoreService.updateDeal(id, {'isApproved': false});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat yayından kaldırıldı ⚠️'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _reactivateDeal(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fırsatı Aktif Et'),
        content: const Text('Bu fırsatı tekrar aktif etmek istediğinize emin misiniz? Tüm kullanıcılar görebilecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Aktif Et'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _firestoreService.unexpireDeal(id);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fırsat tekrar yayına alındı ✅'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir hata oluştu ❌'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAllExpiredDeals(List<Deal> deals) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tümünü Sil'),
        content: Text(
          'Süresi biten ${deals.length} fırsatın tümünü kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz ve tüm fırsatlar veritabanından tamamen kaldırılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Tümünü Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Tüm süresi biten fırsatları sil
    int successCount = 0;
    int failCount = 0;

    for (final deal in deals) {
      try {
        await _firestoreService.deleteDeal(deal.id);
        successCount++;
      } catch (e) {
        _log('Fırsat silme hatası (${deal.id}): $e');
        failCount++;
      }
    }

    if (mounted) {
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount fırsat kalıcı olarak silindi 🗑️'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount fırsat silindi, $failCount fırsat için hata oluştu ⚠️'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }



  // Kısa link çözme (Firebase Function çağrısı)
  Future<String?> _resolveShortLink(String shortUrl) async {
    try {
      final projectId = DefaultFirebaseOptions.flavorProjectId;
      final functionsUrl =
          'https://us-central1-$projectId.cloudfunctions.net/resolveShortLink';
      final uri = Uri.parse('$functionsUrl?url=${Uri.encodeComponent(shortUrl)}');
      
      String? token;
      try {
        token = await FirebaseAppCheck.instance.getToken();
      } catch (e) {
        _log('App Check token alınamadı: $e');
      }

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'X-Firebase-AppCheck': token,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['resolvedUrl'] != null) {
          return data['resolvedUrl'] as String;
        }
      }
      return null;
    } catch (e) {
      _log('Kısa link çözme hatası: $e');
      return null;
    }
  }

  // Mağaza tespit etme
  String _detectStoreFromUrl(String url) {
    if (url.isEmpty) return 'Bilinmeyen';

    try {
      final uri = Uri.parse(url);
      final hostname = uri.host.toLowerCase();

      if (hostname.contains('trendyol.com')) return 'Trendyol';
      if (hostname.contains('hepsiburada.com')) return 'Hepsiburada';
      if (hostname.contains('n11.com')) return 'N11';
      if (hostname.contains('amazon.') || hostname.contains('amzn.') || hostname.contains('link.amazon')) return 'Amazon';
      if (hostname.contains('gittigidiyor.com')) return 'GittiGidiyor';
      if (hostname.contains('havitstore.com.tr')) return 'Havit';
      if (hostname.contains('migros.com.tr')) return 'Migros';
      if (hostname.contains('getir.com')) return 'Getir';
      if (hostname.contains('boyner.com.tr')) return 'Boyner';

      return 'Bilinmeyen';
    } catch (e) {
      return 'Bilinmeyen';
    }
  }

  // Affiliate link'e dönüştürme
  String _convertToAffiliateLink(String originalUrl) {
    if (originalUrl.isEmpty) return originalUrl;

    try {
      final uri = Uri.parse(originalUrl);
      final hostname = uri.host.toLowerCase();

      // Hepsiburada kısa link kontrolü
      if (hostname.contains('hb.biz') || hostname.contains('app.hb.biz')) {
        _log('ℹ️ Kısa link tespit edildi: $originalUrl');
        // Kısa linkler zaten çözülmüş olmalı, eğer hala kısa linkse olduğu gibi bırak
        return originalUrl;
      }

      // Trendyol
      if (hostname.contains('trendyol.com')) {
        final boutiqueId = _affiliateConfig['trendyol']?['boutiqueId'];
        if (boutiqueId != null && boutiqueId.isNotEmpty) {
          // Mevcut boutiqueId'yi temizle
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('boutiqueId');
          // Kendi boutiqueId'yi ekle
          newQueryParams['boutiqueId'] = boutiqueId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // Hepsiburada (Link Gelir) - Normal ürün linkleri
      if (hostname.contains('hepsiburada.com')) {
        final utmSource = _affiliateConfig['hepsiburada']?['utmSource'];
        if (utmSource != null && utmSource.isNotEmpty) {
          // Mevcut affiliate parametrelerini kontrol et
          final existingUtmSource = uri.queryParameters['utm_source'];
          if (existingUtmSource == utmSource) {
            _log('ℹ️ Link zaten kendi affiliate linkiniz: $originalUrl');
            return originalUrl; // Kendi linkiniz, değiştirme
          }

          // Başkasının affiliate linkini kendi affiliate linkimize dönüştür
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('utm_source');
          newQueryParams.remove('utm_medium');
          newQueryParams.remove('utm_campaign');
          newQueryParams.remove('utm_content');
          newQueryParams.remove('wt_inf');

          // Kendi affiliate parametrelerini ekle
          newQueryParams['utm_source'] = utmSource;
          newQueryParams['utm_medium'] = 'referral';
          newQueryParams['utm_campaign'] = 'urun_paylasim';

          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // N11
      if (hostname.contains('n11.com')) {
        final refId = _affiliateConfig['n11']?['refId'];
        if (refId != null && refId.isNotEmpty) {
          // Mevcut ref parametresini temizle
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('ref');
          // Kendi ref ID'sini ekle
          newQueryParams['ref'] = refId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // Amazon
      if (hostname.contains('amazon.com.tr') || hostname.contains('amazon.com') || hostname.contains('amazon.') || hostname.contains('amzn.') || hostname.contains('link.amazon')) {
        final tag = _affiliateConfig['amazon']?['tag'];
        if (tag != null && tag.isNotEmpty) {
          // Mevcut tag parametresini temizle
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('tag');
          // Kendi tag'ini ekle
          newQueryParams['tag'] = tag;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // GittiGidiyor
      if (hostname.contains('gittigidiyor.com')) {
        final affiliateId = _affiliateConfig['gittigidiyor']?['affiliateId'];
        if (affiliateId != null && affiliateId.isNotEmpty) {
          // Mevcut affiliateId parametresini temizle
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('affiliateId');
          // Kendi affiliateId'yi ekle
          newQueryParams['affiliateId'] = affiliateId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // Desteklenmeyen site veya affiliate ID yoksa orijinal linki döndür
      return originalUrl;
    } catch (e) {
      _log('Link dönüştürme hatası: $e');
      return originalUrl;
    }
  }

  Future<void> _showEditDialog(Deal deal) async {
    final titleController = TextEditingController(text: deal.title);
    final descriptionController = TextEditingController(text: deal.description);
    final priceController = TextEditingController(
      text: deal.price == deal.price.toInt()
          ? deal.price.toInt().toString()
          : deal.price.toStringAsFixed(2),
    );
    final originalPriceController = TextEditingController(
      text: deal.originalPrice != null
          ? (deal.originalPrice == deal.originalPrice!.toInt()
              ? deal.originalPrice!.toInt().toString()
              : deal.originalPrice!.toStringAsFixed(2))
          : '',
    );
    final storeController = TextEditingController(text: deal.store);
    final brandController = TextEditingController(text: deal.brand ?? '');
    final ratingValueController = TextEditingController(
      text: deal.ratingValue != null ? deal.ratingValue.toString() : '',
    );
    final ratingCountController = TextEditingController(
      text: deal.ratingCount != null ? deal.ratingCount.toString() : '',
    );
    final linkController = TextEditingController(text: deal.link);
    final imageUrlController = TextEditingController(text: deal.imageUrl);

    // Kategori eşleştirmesi: Firestore'da kategori adı veya ID'si saklanıyor olabilir
    String? selectedCategoryId;
    String? selectedSubCategory = deal.subCategory;
    
    final normalizedDealCategory = deal.category.toLowerCase().trim();

    // 1. Adım: ID ile tam eşleşme kontrolü
    for (final cat in Category.categories) {
      if (cat.id.toLowerCase() == normalizedDealCategory) {
        selectedCategoryId = cat.id;
        break;
      }
    }

    // 2. Adım: İsim ile eşleşme kontrolü (case-insensitive)
    if (selectedCategoryId == null) {
      for (final cat in Category.categories) {
        if (cat.name.toLowerCase() == normalizedDealCategory) {
          selectedCategoryId = cat.id;
          break;
        }
      }
    }

    // 3. Adım: Özel eşleştirmeler (eski veriler veya farklı formatlar için)
    if (selectedCategoryId == null) {
      if (normalizedDealCategory.contains('giyim') || normalizedDealCategory.contains('moda')) {
        selectedCategoryId = 'moda';
      } else if (normalizedDealCategory.contains('ev') || normalizedDealCategory.contains('yasam')) {
        selectedCategoryId = 'ev_yasam';
      } else if (normalizedDealCategory.contains('bebek') || normalizedDealCategory.contains('anne')) {
        selectedCategoryId = 'anne_bebek';
      } else if (normalizedDealCategory.contains('kozmetik') || normalizedDealCategory.contains('bakim')) {
        selectedCategoryId = 'kozmetik';
      } else if (normalizedDealCategory.contains('spor')) {
        selectedCategoryId = 'spor_outdoor';
      } else if (normalizedDealCategory.contains('market') && !normalizedDealCategory.contains('yapi')) {
        selectedCategoryId = 'supermarket';
      } else if (normalizedDealCategory.contains('yapi') || normalizedDealCategory.contains('oto')) {
        selectedCategoryId = 'yapi_oto';
      } else if (normalizedDealCategory.contains('kitap') || normalizedDealCategory.contains('hobi')) {
        selectedCategoryId = 'kitap_hobi';
      } else if (normalizedDealCategory.contains('elektronik') || normalizedDealCategory.contains('telefon') || normalizedDealCategory.contains('bilgisayar')) {
        selectedCategoryId = 'elektronik';
      }
    }

    // Bulunamazsa varsayılan olarak 'diger' kullan (listede varsa)
    if (selectedCategoryId == null) {
       // 'diger' kategorisi var mı kontrol et, yoksa 'elektronik' yap
       final hasDiger = Category.categories.any((c) => c.id == 'diger');
       selectedCategoryId = hasDiger ? 'diger' : 'elektronik';
    }
    
    // Alt kategori kontrolü: Eğer mevcut alt kategori, seçili kategorinin subcategories listesinde yoksa null yap
    if (selectedSubCategory != null && selectedCategoryId != null) {
      final category = Category.categories.firstWhere(
        (cat) => cat.id == selectedCategoryId,
        orElse: () => Category.categories.first,
      );
      if (!category.subcategories.contains(selectedSubCategory)) {
        selectedSubCategory = null; // Geçersiz alt kategori, null yap
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final primaryColor = Theme.of(context).colorScheme.primary;
    bool isAmazonWarehouse = deal.isAmazonWarehouse;
    bool hidePrice = deal.hidePrice;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: Text(
            'Ürün Bilgilerini Düzenle',
            style: TextStyle(color: textColor),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Fiyat (₺)',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: originalPriceController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Eski Fiyat (₺)',
                            border: OutlineInputBorder(),
                            hintText: 'Opsiyonel',
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Link alanı ve Affiliate Link'e Dönüştür butonu - ÜSTTE GÖSTER
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.link, color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Ürün Linki',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: linkController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Ürün URL',
                            border: OutlineInputBorder(),
                            hintText: 'https://...',
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                            suffixIcon: linkController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        linkController.clear();
                                      });
                                    },
                                    tooltip: 'Linki Temizle',
                                  )
                                : null,
                          ),
                          keyboardType: TextInputType.url,
                          onChanged: (value) {
                            setState(() {}); // Trigger rebuild to show/hide clear button
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final currentUrl = linkController.text.trim();
                              if (currentUrl.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Lütfen önce bir URL girin'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              // Loading göster
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              try {
                                String urlToConvert = currentUrl;

                                // Kısa link kontrolü (Hepsiburada kısa linkleri)
                                if (urlToConvert.contains('hb.biz') ||
                                    urlToConvert.contains('app.hb.biz')) {
                                  try {
                                    final resolvedUrl = await _resolveShortLink(urlToConvert);
                                    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                                      urlToConvert = resolvedUrl;
                                      _log('✅ Kısa link çözüldü: $urlToConvert');
                                    }
                                  } catch (e) {
                                    _log('⚠️ Kısa link çözülemedi: $e');
                                  }
                                }

                                // Affiliate link'e dönüştür
                                final convertedUrl = _convertToAffiliateLink(urlToConvert);

                                if (context.mounted) {
                                  Navigator.pop(context); // Loading dialog'u kapat

                                  if (convertedUrl != urlToConvert) {
                                    linkController.text = convertedUrl;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Affiliate link\'e dönüştürüldü!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    // Link zaten affiliate link veya dönüştürülemedi
                                    final store = _detectStoreFromUrl(urlToConvert);
                                    if (store == 'Bilinmeyen') {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('⚠️ Bu mağaza desteklenmiyor'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'ℹ️ Link zaten affiliate link veya $store için affiliate ID yapılandırılmamış'),
                                          backgroundColor: Colors.blue,
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context); // Loading dialog'u kapat
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ Hata: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.swap_horiz, size: 20),
                            label: const Text(
                              'Affiliate Link\'e Dönüştür',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: storeController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Mağaza',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: brandController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Marka (Opsiyonel)',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ratingValueController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Rating Puanı (ör. 4.8)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: ratingCountController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Oy Sayısı (ör. 1173)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: imageUrlController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Görsel URL',
                      border: OutlineInputBorder(),
                      hintText: 'https://...',
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: Category.categories
                        .where((cat) => cat.id != 'tumu')
                        .map((category) => DropdownMenuItem(
                              value: category.id,
                              child: Text('${category.icon} ${category.name}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategoryId = value;
                        selectedSubCategory = null; // Kategori değişince alt kategoriyi sıfırla
                      });
                    },
                  ),
                  if (selectedCategoryId != null) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: selectedSubCategory,
                      decoration: const InputDecoration(
                        labelText: 'Alt Kategori',
                        border: OutlineInputBorder(),
                        hintText: 'Opsiyonel',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Alt kategori seçiniz (opsiyonel)'),
                        ),
                        ...Category.categories
                            .firstWhere((cat) => cat.id == selectedCategoryId)
                            .subcategories
                            .map((sub) => DropdownMenuItem(
                                  value: sub,
                                  child: Text(sub),
                                )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedSubCategory = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Amazon Depo Ürünü Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAmazonWarehouse
                          ? const Color(0xFFD97706).withOpacity(0.08)
                          : (isDark ? AppTheme.darkSurfaceElevated : Colors.grey[50]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAmazonWarehouse
                            ? const Color(0xFFD97706).withOpacity(0.3)
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: 1,
                      ),
                    ),
                    child: SwitchListTile(
                      value: isAmazonWarehouse,
                      onChanged: (value) {
                        setState(() {
                          isAmazonWarehouse = value;
                        });
                      },
                      title: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 18,
                            color: isAmazonWarehouse ? const Color(0xFFD97706) : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Amazon Depo Ürünü',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isAmazonWarehouse ? const Color(0xFFD97706) : textColor,
                            ),
                          ),
                        ],
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fiyatı Gizle (Kampanya) Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: hidePrice
                          ? Colors.blue.withOpacity(0.08)
                          : (isDark ? AppTheme.darkSurfaceElevated : Colors.grey[50]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hidePrice
                            ? Colors.blue.withOpacity(0.3)
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: 1,
                      ),
                    ),
                    child: SwitchListTile(
                      value: hidePrice,
                      onChanged: (value) {
                        setState(() {
                          hidePrice = value;
                        });
                      },
                      title: Row(
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 18,
                            color: hidePrice ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Fiyatı Gizle (Kampanya / Fiyatsız Fırsat)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: hidePrice ? Colors.blue : textColor,
                            ),
                          ),
                        ],
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validasyon
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Başlık boş olamaz')),
                  );
                  return;
                }

                final price = double.tryParse(priceController.text.replaceAll(',', '.'));
                if (!hidePrice && (price == null || price <= 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir fiyat giriniz')),
                  );
                  return;
                }

                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kategori seçiniz')),
                  );
                  return;
                }

                // Güncelleme verilerini hazırla
                final updates = <String, dynamic>{
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': price ?? 0.0,
                  'hidePrice': hidePrice,
                  'store': storeController.text.trim(),
                  'brand': brandController.text.trim().isNotEmpty ? brandController.text.trim() : null,
                  'link': linkController.text.trim(),
                  'imageUrl': imageUrlController.text.trim(),
                  // Kategori ID'sinden kategori adına çevir (Firestore'da kategori adı saklanıyor)
                  'category': Category.getNameById(selectedCategoryId!),
                };

                final ratingValStr = ratingValueController.text.trim();
                if (ratingValStr.isNotEmpty) {
                  final parsedVal = double.tryParse(ratingValStr.replaceAll(',', '.'));
                  updates['ratingValue'] = parsedVal;
                } else {
                  updates['ratingValue'] = null;
                }

                final ratingCntStr = ratingCountController.text.trim();
                if (ratingCntStr.isNotEmpty) {
                  final parsedCnt = int.tryParse(ratingCntStr);
                  updates['ratingCount'] = parsedCnt;
                } else {
                  updates['ratingCount'] = null;
                }

                // Eski fiyat varsa ekle
                final originalPrice = originalPriceController.text.trim();
                if (originalPrice.isNotEmpty) {
                  final origPrice = double.tryParse(originalPrice.replaceAll(',', '.'));
                  if (origPrice != null && price != null && origPrice > price) {
                    updates['originalPrice'] = origPrice;
                    // İndirim oranını hesapla
                    final discountRate = ((origPrice - price) / origPrice * 100).round();
                    updates['discountRate'] = discountRate;
                  } else {
                    updates['originalPrice'] = null;
                    updates['discountRate'] = null;
                  }
                } else {
                  updates['originalPrice'] = null;
                  updates['discountRate'] = null;
                }

                // Alt kategori varsa ekle
                if (selectedSubCategory != null && selectedSubCategory!.isNotEmpty) {
                  updates['subCategory'] = selectedSubCategory;
                } else {
                  updates['subCategory'] = null;
                }

                // Amazon Depo durumu
                updates['isAmazonWarehouse'] = isAmazonWarehouse;

                // Firestore'a güncelle
                final success = await _firestoreService.updateDeal(deal.id, updates);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ürün bilgileri güncellendi ✅'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Arama kutusu
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              hintText: 'Kullanıcı ara...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _userSearchController.clear();
                        setState(() {
                          _userSearchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
            ),
            onChanged: (value) {
              setState(() {
                _userSearchQuery = value.toLowerCase().trim();
              });
            },
          ),
        ),
        // Kullanıcı listesi
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('points', descending: true)
                .limit(200)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Hata: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kullanıcı bulunamadı',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final allDocs = snapshot.data!.docs;
              
              // Arama filtreleme
              List<DocumentSnapshot> filteredDocs;
              if (_userSearchQuery.isEmpty) {
                filteredDocs = allDocs;
              } else {
                filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  
                  final username = (data['username'] ?? '').toString().toLowerCase();
                  final nickname = (data['nickname'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final uid = doc.id.toLowerCase();
                  
                  return username.contains(_userSearchQuery) ||
                         nickname.contains(_userSearchQuery) ||
                         email.contains(_userSearchQuery) ||
                         uid.contains(_userSearchQuery);
                }).toList();
              }

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '"$_userSearchQuery" ile eşleşen kullanıcı yok',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final userDoc = filteredDocs[index];
                  final userData = userDoc.data() as Map<String, dynamic>?;
                  
                  if (userData == null) {
                    return const SizedBox.shrink();
                  }
                  
                  // Verileri güvenli şekilde al
                  final username = (userData['username'] ?? 'Kullanıcı').toString();
                  final nickname = (userData['nickname'] ?? '').toString();
                  final displayName = nickname.isNotEmpty ? nickname : username;
                  final profileImageUrl = migrateAssetPath((userData['profileImageUrl'] ?? '').toString());
                  final points = (userData['points'] ?? 0) as int;
                  final totalLikes = (userData['totalLikes'] ?? 0) as int;
                  final badges = (userData['badges'] ?? []) as List<dynamic>;
                  final badgeIds = badges.map((e) => e.toString()).toList();
                  final userId = userDoc.id;
                  
                  final email = userData['email']?.toString() ?? 'E-posta bilinmiyor';
                  final createdAtVal = userData['createdAt'];
                  String formattedSignUpDate = 'Bilinmiyor';
                  if (createdAtVal is Timestamp) {
                    formattedSignUpDate = DateFormat('dd.MM.yyyy HH:mm').format(createdAtVal.toDate());
                  } else if (createdAtVal is String) {
                    try {
                      formattedSignUpDate = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(createdAtVal));
                    } catch (_) {}
                  }
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: userId),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                              backgroundImage: profileImageUrl.isNotEmpty
                                  ? (profileImageUrl.startsWith('assets/')
                                      ? AssetImage(profileImageUrl) as ImageProvider
                                      : CachedNetworkImageProvider(profileImageUrl))
                                  : null,
                              child: profileImageUrl.isEmpty
                                  ? Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            // Kullanıcı bilgileri
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Rozetler
                                      ...BadgeHelper.getBadgeInfos(badgeIds).take(3).map(
                                        (badge) => Padding(
                                          padding: const EdgeInsets.only(left: 4),
                                          child: Tooltip(
                                            message: badge.name,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: badge.color.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: badge.color.withValues(alpha: 0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                badge.icon,
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (badgeIds.length > 3)
                                        Tooltip(
                                          message: '${badgeIds.length - 3} rozet daha',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '+${badgeIds.length - 3}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.stars,
                                        size: 14,
                                        color: Colors.amber[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$points Puan',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.favorite,
                                        size: 14,
                                        color: Colors.red[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$totalLikes Beğeni',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // E-posta adresi
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.email_outlined,
                                        size: 13,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          email,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Üyelik Tarihi
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_month_outlined,
                                        size: 13,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Üyelik: $formattedSignUpDate',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (username != displayName) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '@$username',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Rozet yönetim butonu
                            IconButton(
                              icon: const Icon(Icons.workspace_premium),
                              color: primaryColor,
                              onPressed: () {
                                try {
                                  final user = AppUser(
                                    uid: userId,
                                    username: username,
                                    nickname: nickname,
                                    profileImageUrl: profileImageUrl,
                                    points: points,
                                    totalLikes: totalLikes,
                                    badges: badgeIds,
                                  );
                                  _showBadgeDialog(user);
                                } catch (e) {
                                  _log('Kullanıcı oluşturma hatası: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Hata: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              tooltip: 'Rozet Yönet',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showBadgeDialog(AppUser user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text(
          '${user.username} - Rozet Yönetimi',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mevcut Rozetler:',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.badges.map((badgeId) {
                  final badge = BadgeHelper.getBadgeInfo(badgeId);
                  if (badge == null) return const SizedBox.shrink();
                  return Chip(
                    avatar: Text(badge.icon),
                    label: Text(badge.name),
                    backgroundColor: badge.color.withValues(alpha: 0.2),
                    deleteIcon: Icon(Icons.close, size: 16, color: badge.color),
                    onDeleted: () => _removeBadge(user.uid, badgeId),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Rozet Ekle:',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BadgeHelper.getAllBadgeIds()
                    .where((badgeId) => !user.badges.contains(badgeId))
                    .map((badgeId) {
                  final badge = BadgeHelper.getBadgeInfo(badgeId)!;
                  return ActionChip(
                    avatar: Text(badge.icon),
                    label: Text(badge.name),
                    backgroundColor: badge.color.withValues(alpha: 0.1),
                    onPressed: () => _addBadge(user.uid, badgeId),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Kapat',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addBadge(String userId, String badgeId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userRef.get();
      
      if (userDoc.exists) {
        final currentBadges = List<String>.from(userDoc.data()?['badges'] ?? []);
        if (!currentBadges.contains(badgeId)) {
          currentBadges.add(badgeId);
          await userRef.update({'badges': currentBadges});
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Rozet eklendi ✅'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      _log('Rozet ekleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeBadge(String userId, String badgeId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userRef.get();
      
      if (userDoc.exists) {
        final currentBadges = List<String>.from(userDoc.data()?['badges'] ?? []);
        currentBadges.remove(badgeId);
        await userRef.update({'badges': currentBadges});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rozet kaldırıldı ✅'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _log('Rozet kaldırma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllMessages(int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Mesajları Sil'),
        content: Text(
          'Toplam $count adet mesajı kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final deletedCount = await _firestoreService.deleteAllMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount mesaj silindi 🗑️'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Admin için mesaj listesi
  Widget _buildMessagesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<List<Message>>(
      stream: _firestoreService.getAllMessagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Hata: ${snapshot.error}'),
          );
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz mesaj yok',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _deleteAllMessages(messages.length),
                  icon: const Icon(Icons.delete_sweep, size: 20),
                  label: Text('Tüm Mesajları Sil (${messages.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isUnreadByAdmin = !message.isReadByAdmin;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isUnreadByAdmin
                        ? (isDark
                            ? primaryColor.withValues(alpha: 0.15)
                            : primaryColor.withValues(alpha: 0.1))
                        : null,
                    child: InkWell(
                      onTap: () {
                        // Mesaj detayını göster
                        _showMessageDetail(message);
                        // Admin tarafından okundu olarak işaretle
                        if (isUnreadByAdmin) {
                          _firestoreService.markMessageAsReadByAdmin(message.id);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipOval(
                                  child: message.senderImageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: message.senderImageUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const CircularProgressIndicator(strokeWidth: 2),
                                          errorWidget: (context, url, error) =>
                                              const Icon(Icons.person, size: 40),
                                        )
                                      : const Icon(Icons.person, size: 40),
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
                                              '${message.senderName} → ${message.receiverName}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isUnreadByAdmin
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (isUnreadByAdmin)
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(message.createdAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                message.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  message.isRead ? Icons.done_all : Icons.done,
                                  size: 16,
                                  color: message.isRead
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  message.isRead ? 'Okundu' : 'Gönderildi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                const Spacer(),
                                if (isUnreadByAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Yeni',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Mesaj detayını göster
  void _showMessageDetail(Message message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Row(
          children: [
            ClipOval(
              child: message.senderImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: message.senderImageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, size: 40),
                    )
                  : const Icon(Icons.person, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '→ ${message.receiverName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gönderilme: ${DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(message.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 16,
                    color: message.isRead ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.isRead ? 'Alıcı tarafından okundu' : 'Gönderildi',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: message.senderId),
                ),
              );
            },
            child: const Text('Gönderen Profili'),
          ),
        ],
      ),
    );
  }

  void _startMobileTestCommandListener() {
    _mobileTestCommandSubscription?.cancel();
    _mobileTestCommandSubscription = FirebaseFirestore.instance
        .collection('mobileTestCommands')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final url = data['url'] as String?;
        if (url == null || url.isEmpty) continue;

        // Initialize logs list and write initial running state
        final localLogs = <String>[];
        localLogs.add('[Mobile App] Test komutu alındı. Kazıcı başlatılıyor...');
        await doc.reference.update({
          'status': 'running',
          'logs': localLogs,
        });

        // Set up periodic timer to flush logs to Firestore
        bool needsUpdate = false;
        final timer = Timer.periodic(const Duration(milliseconds: 500), (t) {
          if (needsUpdate) {
            doc.reference.update({'logs': localLogs});
            needsUpdate = false;
          }
        });

        // Redirect logs locally
        final subscription = LinkPreviewLogger.logStream.listen((logLine) {
          localLogs.add(logLine);
          needsUpdate = true;
        });

        try {
          // Fetch metadata
          final preview = await LinkPreviewService().fetchMetadata(url).timeout(
            const Duration(seconds: 15),
          );

          if (preview == null) {
            throw Exception("Kazıma başarısız oldu (Preview boş).");
          }

          // Category detection
          String category = 'diger';
          String? subCategory;
          final titleToClassify = '${preview.breadcrumbs?.join(" ") ?? ""} ${preview.title ?? ""}';
          final catResult = CategoryDetectionService.detectCategory(titleToClassify);
          if (catResult != null) {
            category = catResult['categoryId']!;
            subCategory = catResult['subCategory'];
          }

          // AI Analysis
          final aiResult = await AIService.analyzeProduct(
            url: url,
            title: preview.title ?? "",
            description: preview.description ?? "",
          );

          String finalTitle = preview.title ?? "Fırsat Ürünü";
          double finalPrice = preview.price ?? 0.0;
          String finalStore = preview.provider ?? "Diğer";

          if (aiResult['success'] == true) {
            if (aiResult.containsKey('title') && aiResult['title'] != null) {
              finalTitle = aiResult['title'];
            }
            if (aiResult.containsKey('price') && aiResult['price'] != null) {
              finalPrice = double.tryParse(aiResult['price'].toString()) ?? finalPrice;
            }
            if (aiResult.containsKey('store') && aiResult['store'] != null) {
              finalStore = aiResult['store'];
            }
            if (aiResult.containsKey('category') && aiResult['category'] != null) {
              category = aiResult['category'];
              subCategory = null;
            }
          }

          // Save test deal to Firestore
          final deal = Deal(
            id: '',
            title: finalTitle,
            description: preview.description ?? 'Mobil test açıklaması',
            price: finalPrice,
            originalPrice: finalPrice > 0 ? finalPrice * 1.2 : 0.0,
            discountRate: finalPrice > 0 ? 20 : 0,
            store: finalStore,
            category: category,
            subCategory: subCategory,
            link: url,
            imageUrl: preview.imageUrl ?? '',
            hotVotes: 0,
            coldVotes: 0,
            commentCount: 0,
            postedBy: 'admin_test_mobil',
            createdAt: DateTime.now(),
            isEditorPick: false,
            isApproved: false,
            isUserSubmitted: false,
            isTest: true,
          );

          await FirebaseFirestore.instance.collection('deals').add(deal.toFirestore());

          localLogs.add('[Mobile App] Test başarıyla tamamlandı ve Firestore\'a kaydedildi.');
          await doc.reference.update({
            'status': 'completed',
            'logs': localLogs,
          });
        } catch (e) {
          localLogs.add('[Mobile App] HATA: $e');
          await doc.reference.update({
            'status': 'failed',
            'logs': localLogs,
          });
        } finally {
          subscription.cancel();
          timer.cancel();
        }
      }
    });
  }
}
