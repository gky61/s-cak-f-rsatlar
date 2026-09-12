import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/deal.dart';
import '../models/category.dart';
import '../models/user.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/message_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../utils/badge_helper.dart';
import '../utils/asset_path_migration.dart';
import '../theme/app_theme.dart';
import 'deal_detail_screen.dart';
import 'deal_detail/admin_dialogs/admin_edit_sheet.dart';
import 'profile_screen.dart';
import '../widgets/deal_card_skeleton.dart';
import '../widgets/skeletons/user_list_skeleton.dart';
import '../widgets/admin_reports_list.dart';
import '../widgets/admin_expired_deals_view.dart';
import 'notification_debug_screen.dart';
import '../services/affiliate/affiliate_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}


class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

enum _AdminListType { pending, userSubmitted, published, expired }

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final UserService _userService = UserService();
  final MessageService _messageService = MessageService();
  late TabController _tabController;
  
  // Tab bildirim sayıları
  int _pendingCount = 0;
  int _userSubmittedCount = 0;
  int _expiredCount = 0;
  int _usersCount = 0;
  int _pendingReportsCount = 0;
  int _pendingComplaintsCount = 0;
  int _unreadAutoModCount = 0;
  
  // Stream Subscriptions - Bellek sızıntısını önlemek için
  StreamSubscription? _pendingSubscription;
  StreamSubscription? _userSubmittedSubscription;
  StreamSubscription? _expiredSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _reportsSubscription;
  StreamSubscription? _autoModSubscription;
  
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
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Kategori adını kategori ID'sinden bul
  String _getCategoryDisplayName(String categoryIdOrName) {
    // Önce standart kategorilerde ID ile ara
    for (var cat in Category.categories) {
      if (cat.id == categoryIdOrName) {
        return cat.name;
      }
    }
    // Bulunamazsa, name ile ara (belki zaten isimdir)
    for (var cat in Category.categories) {
      if (cat.name.toLowerCase() == categoryIdOrName.toLowerCase()) {
        return cat.name;
      }
    }
    // Hiçbir şey bulunamazsa, orijinal değeri döndür
    return categoryIdOrName;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTabCounts();
    _loadReportCounts();
    // Admin paneli her açıldığında admin_deals topic'ine abone ol (bildirimlerin gelmesi için)
    _ensureAdminNotificationSubscription();
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
    _reportsSubscription?.cancel();
    _autoModSubscription?.cancel();
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
            _buildTabWithBadge('Raporlar', _pendingReportsCount),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDealList(_AdminListType.pending),
          _buildDealList(_AdminListType.userSubmitted),
          const AdminExpiredDealsView(),
          _buildUsersList(),
          const AdminReportsList(),
        ],
      ),
    );
  }

  // Rapor sayısı için metod (Kullanıcı şikayetleri + Otomatik moderasyon alarmları toplamı)
  void _loadReportCounts() {
    _reportsSubscription = _firestoreService.reportsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingComplaintsCount = snapshot.docs.length;
          _pendingReportsCount = _pendingComplaintsCount + _unreadAutoModCount;
        });
      }
    });

    _autoModSubscription = FirebaseFirestore.instance
        .collection('adminMessages')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadAutoModCount = snapshot.docs.length;
          _pendingReportsCount = _pendingComplaintsCount + _unreadAutoModCount;
        });
      }
    });
  }

  Widget _buildDealList(_AdminListType type) {
    final bool isPending = type == _AdminListType.pending;
    final bool isUserSubmitted = type == _AdminListType.userSubmitted;
    final bool isPublished = type == _AdminListType.published;

    return StreamBuilder<List<Deal>>(
      stream: switch (type) {
        _AdminListType.pending => _firestoreService.getPendingDealsStream(),
        _AdminListType.userSubmitted => _firestoreService.getUserSubmittedPendingDealsStream(),
        _AdminListType.published => _firestoreService.getApprovedDealsStream(),
        _AdminListType.expired => _firestoreService.getExpiredDealsStream(),
      },
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => const DealCardSkeleton(viewMode: CardViewMode.horizontal),
          );
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

  String _formatDealTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) {
      return 'Az önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return DateFormat('dd.MM.yyyy', 'tr_TR').format(dt);
    }
  }

  Widget _buildAdminCard(Deal deal, _AdminListType type) {
    final bool isPending = type == _AdminListType.pending;
    final bool isUserSubmitted = type == _AdminListType.userSubmitted;
    final bool isPublished = type == _AdminListType.published;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isBot = deal.isBotkolik;
    final String sourceName = deal.sourceDisplayName;

    final String timeAgoStr = _formatDealTimeAgo(deal.createdAt);
    final String fullDateStr = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(deal.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 🕒 Üst Bilgi Çubuğu: Kaynak (Bot/Sayfa/Kullanıcı) & Gönderilme Zamanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                // Kaynak Rozeti (Bot Kazıma Sayfası / Kanalı veya Kullanıcı)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: (isBot ? const Color(0xFF3B82F6) : const Color(0xFFA855F7)).withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
                          size: 13,
                          color: isBot
                              ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                              : (isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA)),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            sourceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isBot
                                  ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                  : (isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Gönderilme Zamanı (X dk önce • dd.MM.yyyy HH:mm)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgoStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($fullDateStr)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteSingleDeal(deal);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Fırsatı Kalıcı Sil', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ],
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
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4), width: 0.5),
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
            Builder(
              builder: (context) {
                final dealUrl = deal.link.isNotEmpty ? deal.link : deal.displayUrl;
                final isSupported = AffiliateService.isStoreSupported(deal.store.isNotEmpty ? deal.store : dealUrl);
                if (!isSupported) return const SizedBox.shrink();

                final adapter = AffiliateService.getAdapter(dealUrl);
                if (adapter == null) return const SizedBox.shrink();

                final uri = Uri.tryParse(dealUrl);
                final isAlreadyAffiliate = uri != null && adapter.isAlreadyAffiliate(uri);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAlreadyAffiliate
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAlreadyAffiliate
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAlreadyAffiliate ? Icons.verified_rounded : Icons.auto_fix_high_rounded,
                        size: 16,
                        color: isAlreadyAffiliate ? Colors.green : Colors.orange[800],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isAlreadyAffiliate
                              ? '${adapter.storeName} Affiliate linki hazır'
                              : '${adapter.storeName} linki (Onaylanınca otomatik affiliate\'e dönüştürülür)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isAlreadyAffiliate ? Colors.green[800] : Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
                    onPressed: () => showAdminEditSheet(
                      context: context,
                      deal: deal,
                      firestoreService: _firestoreService,
                      onDealUpdated: () => setState(() {}),
                    ),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteSingleDeal(deal),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      label: const Text('Sil', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showAdminEditSheet(
                        context: context,
                        deal: deal,
                        firestoreService: _firestoreService,
                        onDealUpdated: () => setState(() {}),
                      ),
                      icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                      label: const Text('Düzenle', style: TextStyle(color: Colors.blue)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _unpublishDeal(deal.id),
                      icon: const Icon(Icons.visibility_off, size: 18),
                      label: const Text('Kaldır'),
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
                ],
              ),
            ),
          ],
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
    final dealDoc = await _firestoreService.getDeal(id);
    final updates = <String, dynamic>{
      'isApproved': true,
      'isRejected': false,
      'isExpired': false,
      'status': 'active',
      'isEditorPick': isEditorPick,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (hidePrice) {
      updates['hidePrice'] = true;
    }

    bool wasConverted = false;
    if (dealDoc != null) {
      final currentUrl = dealDoc.link;
      _log('═══════════════════════════════════════════════════════════');
      _log('👑 [AFFILIATE-TEST] Mobil Admin Onay Ekranı: Fırsat Onaylanıyor');
      _log('   🆔 Fırsat ID: $id');
      _log('   🏷️ Başlık: ${dealDoc.title}');
      _log('   🔗 Mevcut Link: $currentUrl');
      if (currentUrl.isNotEmpty) {
        final adapter = AffiliateService.getAdapter(currentUrl);
        final uri = Uri.tryParse(currentUrl);
        final isAlreadyAffiliate = adapter != null && uri != null && adapter.isAlreadyAffiliate(uri);

        if (isAlreadyAffiliate) {
          // ⚡ Hızlı Yol (Fast-Path): Link zaten paylaşım anında affiliate yapılmış ve hazır.
          // Tekrar hesaplama yapılmaz; hazır link doğrudan "Mağazaya Git" butonu arkasında yayına girer.
          _log('⚡ [AFFILIATE-TEST] Hızlı Yol (Fast-Path): Link zaten hazır affiliate linki, mükerrer hesaplama yapılmadı.');
          _log('   👉 Aktif Link: $currentUrl');
        } else {
          // 🛡️ Emniyet Ağı (Safety Net): Yalnızca eski/organik kalmış linkler için tek seferlik dönüşüm
          _log('🔄 [AFFILIATE-TEST] Emniyet Ağı: Link henüz affiliate değil, dönüştürülüyor...');
          try {
            final settingsDoc = await _firestoreService.firestore.collection('settings').doc('app').get();
            if (settingsDoc.exists && settingsDoc.data() != null) {
              AffiliateService.syncFromMap(settingsDoc.data()!);
              _log('⚙️ [AFFILIATE-TEST] Firestore settings/app şalterleri senkronize edildi');
            }
          } catch (_) {}

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
        if (dealDoc.cleanUrl.trim().isEmpty ||
            dealDoc.cleanUrl.contains('btrck.com') ||
            dealDoc.cleanUrl.contains('7t4g.adj.st') ||
            dealDoc.cleanUrl.contains('adj.st')) {
          final clean = Deal.cleanProductUrl(dealDoc.displayUrl.isNotEmpty ? dealDoc.displayUrl : currentUrl);
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

    await _firestoreService.updateDeal(id, updates);
    
    // Anahtar kelime kontrolü yap - onaylanan fırsat için
    try {
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

  Future<void> _rejectDeal(String id) async {
    await _firestoreService.updateDeal(id, {
      'isRejected': true,
      'isApproved': false,
      'isExpired': true,
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
        await _firestoreService.updateDeal(deal.id, {
          'isRejected': true,
          'isApproved': false,
          'isExpired': true,
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
        content: const Text('Bu fırsatı yayından kaldırmak istediğinize emin misiniz? Fırsat ana ekrandan kaldırılıp süresi bitenler bölümüne taşınacak.'),
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

    await _firestoreService.updateDeal(id, {
      'isExpired': true,
      'status': 'expired',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat yayından kaldırıldı ve süresi bitenlere taşındı ⚠️'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteSingleDeal(Deal deal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fırsatı Sil'),
        content: Text(
          'Bu fırsatı kalıcı olarak silmek istediğinize emin misiniz?\n\n"${deal.title}"\n\nBu işlem geri alınamaz ve fırsat tamamen kaldırılacaktır.',
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

    if (confirm != true || !mounted) return;

    final success = await _firestoreService.deleteDeal(deal.id);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fırsat başarıyla silindi 🗑️'), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silme işlemi başarısız ❌'), backgroundColor: Colors.red),
        );
      }
    }
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
                return const UserListSkeleton(itemCount: 6, padding: EdgeInsets.all(16));
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
                  final isAdmin = userData['isAdmin'] == true || userData['isadmin'] == true || userData['isAdmin'] == 'true' || userData['isadmin'] == 'true';
                  
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
                      onTap: () => _showUserAdminSheet(context, userData, userId),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Avatar (Güvenli: onBackgroundImageError sadece backgroundImage varken verilir)
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                              backgroundImage: profileImageUrl.isNotEmpty
                                  ? (profileImageUrl.startsWith('assets/')
                                      ? AssetImage(profileImageUrl) as ImageProvider
                                      : CachedNetworkImageProvider(profileImageUrl))
                                  : null,
                              onBackgroundImageError: profileImageUrl.isNotEmpty ? (exception, stackTrace) {} : null,
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
                                      if (isAdmin)
                                        Container(
                                          margin: const EdgeInsets.only(left: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                                          ),
                                          child: const Text(
                                            '👮 Admin',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                            // Yönetim butonu
                            IconButton(
                              icon: const Icon(Icons.admin_panel_settings_outlined),
                              color: primaryColor,
                              onPressed: () => _showUserAdminSheet(context, userData, userId),
                              tooltip: 'Kullanıcıyı Yönet',
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

  /// Kullanıcı için Yönetim ve Moderasyon Bottom Sheet'i
  void _showUserAdminSheet(BuildContext context, Map<String, dynamic> userData, String userId) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final username = (userData['username'] ?? 'Kullanıcı').toString();
    final nickname = (userData['nickname'] ?? '').toString();
    final displayName = nickname.isNotEmpty ? nickname : username;
    final profileImageUrl = migrateAssetPath((userData['profileImageUrl'] ?? '').toString());
    final email = userData['email']?.toString() ?? 'E-posta bilinmiyor';
    final points = (userData['points'] ?? 0) as int;
    final dealCount = (userData['dealCount'] ?? 0) as int;
    final totalLikes = (userData['totalLikes'] ?? 0) as int;
    final badges = (userData['badges'] ?? []) as List<dynamic>;
    final badgeIds = badges.map((e) => e.toString()).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<List<bool>>(
              future: Future.wait([
                _userService.isUserBlocked(userId),
                _userService.isUserCommentBanned(userId),
                _userService.isUserDealBanned(userId),
                FirebaseFirestore.instance.collection('users').doc(userId).get().then((d) {
                  final data = d.data();
                  return data?['isAdmin'] == true || data?['isadmin'] == true || data?['isAdmin'] == 'true' || data?['isadmin'] == 'true';
                }),
              ]),
              builder: (context, snapshot) {
                final isBlocked = snapshot.data?[0] ?? false;
                final isCommentBanned = snapshot.data?[1] ?? false;
                final isDealBanned = snapshot.data?[2] ?? false;
                final isAdmin = snapshot.data?[3] ?? (userData['isAdmin'] == true || userData['isadmin'] == true || userData['isAdmin'] == 'true');

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      // Header Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: primaryColor.withValues(alpha: 0.12),
                              backgroundImage: profileImageUrl.isNotEmpty
                                  ? (profileImageUrl.startsWith('assets/')
                                      ? AssetImage(profileImageUrl) as ImageProvider
                                      : CachedNetworkImageProvider(profileImageUrl))
                                  : null,
                              onBackgroundImageError: profileImageUrl.isNotEmpty ? (exception, stackTrace) {} : null,
                              child: profileImageUrl.isEmpty
                                  ? Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
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
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isAdmin)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                                          ),
                                          child: const Text(
                                            '👮 Admin',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@$username • $email',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: userId));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Kullanıcı ID panoya kopyalandı 📋'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'ID: $userId',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.copy, size: 12, color: Colors.grey[500]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Stat chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _buildStatBadge(Icons.stars, '$points Puan', Colors.amber[700]!, isDark),
                            const SizedBox(width: 8),
                            _buildStatBadge(Icons.local_offer, '$dealCount Fırsat', const Color(0xFF10B981), isDark),
                            const SizedBox(width: 8),
                            _buildStatBadge(Icons.favorite, '$totalLikes Beğeni', Colors.red[400]!, isDark),
                          ],
                        ),
                      ),
                      
                      // Active status alerts
                      if (isBlocked || isCommentBanned || isDealBanned)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (isBlocked)
                                _buildWarningTag('🚫 Hesap Engelli', Colors.red),
                              if (isCommentBanned)
                                _buildWarningTag('💬 Yorum Engelli', Colors.orange),
                              if (isDealBanned)
                                _buildWarningTag('🏷️ Paylaşım Engelli', Colors.deepOrange),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),
                      Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),

                      // Action Items List
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            // 1. Admin Rolü
                            _buildActionTile(
                              icon: isAdmin ? Icons.no_accounts : Icons.admin_panel_settings,
                              iconColor: isAdmin ? Colors.grey : Colors.blue,
                              title: isAdmin ? 'Admin Yetkisini Kaldır' : 'Admin Yetkisi Ver',
                              subtitle: isAdmin
                                  ? 'Kullanıcının yönetim paneline erişimini sonlandırır'
                                  : 'Kullanıcıya yönetim paneline erişim yetkisi verir',
                              onTap: () async {
                                final confirm = await _showConfirmDialog(
                                  context: context,
                                  title: isAdmin ? 'Admin Yetkisini Kaldır' : 'Admin Yetkisi Ver',
                                  message: '$displayName adlı kullanıcının admin yetkisini ${isAdmin ? 'kaldırmak' : 'vermek'} istediğinize emin misiniz?',
                                  confirmColor: isAdmin ? Colors.red : Colors.blue,
                                );
                                if (confirm == true) {
                                  final success = await _userService.toggleUserAdminStatus(userId, !isAdmin);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? 'Admin yetkisi güncellendi ✅' : 'Yetki güncellenemedi ❌'),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                    setSheetState(() {});
                                  }
                                }
                              },
                            ),

                            // 2. Kullanıcı Engelle / Kaldır
                            _buildActionTile(
                              icon: isBlocked ? Icons.check_circle_outline : Icons.block,
                              iconColor: isBlocked ? Colors.green : Colors.red,
                              title: isBlocked ? 'Kullanıcı Engelini Kaldır' : 'Kullanıcıyı Engelle',
                              subtitle: isBlocked
                                  ? 'Kullanıcının uygulamaya erişimini yeniden açar'
                                  : 'Kullanıcının uygulamayı kullanmasını tamamen engeller',
                              onTap: () async {
                                final confirm = await _showConfirmDialog(
                                  context: context,
                                  title: isBlocked ? 'Engeli Kaldır' : 'Kullanıcıyı Engelle',
                                  message: isBlocked
                                      ? '$displayName kullanıcısının engelini kaldırmak istiyor musunuz?'
                                      : '$displayName kullanıcısını engellemek istediğinize emin misiniz? Uygulamayı kullanamayacak.',
                                  confirmColor: isBlocked ? Colors.green : Colors.red,
                                );
                                if (confirm == true) {
                                  final success = isBlocked
                                      ? await _userService.unblockUser(userId)
                                      : await _userService.blockUser(userId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? (isBlocked ? 'Engel kaldırıldı ✅' : 'Kullanıcı engellendi 🚫') : 'İşlem başarısız ❌'),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                    setSheetState(() {});
                                  }
                                }
                              },
                            ),

                            // 3. Yorum Engeli
                            _buildActionTile(
                              icon: isCommentBanned ? Icons.chat : Icons.comments_disabled,
                              iconColor: isCommentBanned ? Colors.green : Colors.orange,
                              title: isCommentBanned ? 'Yorum İzni Ver' : 'Yorum Yapmasını Engelle',
                              subtitle: isCommentBanned
                                  ? 'Kullanıcının fırsatlara yorum yazmasına izin verir'
                                  : 'Kullanıcının yorum yazmasını kısıtlar',
                              onTap: () async {
                                final confirm = await _showConfirmDialog(
                                  context: context,
                                  title: isCommentBanned ? 'Yorum İzni Ver' : 'Yorumu Engelle',
                                  message: isCommentBanned
                                      ? '$displayName kullanıcısına tekrar yorum yapma izni verilsin mi?'
                                      : '$displayName kullanıcısının yorum yapmasını engellemek istiyor musunuz?',
                                  confirmColor: isCommentBanned ? Colors.green : Colors.orange,
                                );
                                if (confirm == true) {
                                  final success = isCommentBanned
                                      ? await _userService.unbanUserComments(userId)
                                      : await _userService.banUserComments(userId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? (isCommentBanned ? 'Yorum izni verildi ✅' : 'Yorum yapması engellendi 🚫') : 'İşlem başarısız ❌'),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                    setSheetState(() {});
                                  }
                                }
                              },
                            ),

                            // 4. Paylaşım Engeli
                            _buildActionTile(
                              icon: isDealBanned ? Icons.add_circle_outline : Icons.remove_circle_outline,
                              iconColor: isDealBanned ? Colors.green : Colors.deepOrange,
                              title: isDealBanned ? 'Paylaşım İzni Ver' : 'Fırsat Paylaşımını Engelle',
                              subtitle: isDealBanned
                                  ? 'Kullanıcının yeni fırsat paylaşmasına izin verir'
                                  : 'Kullanıcının fırsat paylaşmasını kısıtlar',
                              onTap: () async {
                                final confirm = await _showConfirmDialog(
                                  context: context,
                                  title: isDealBanned ? 'Paylaşım İzni Ver' : 'Paylaşımı Engelle',
                                  message: isDealBanned
                                      ? '$displayName kullanıcısına tekrar fırsat paylaşma izni verilsin mi?'
                                      : '$displayName kullanıcısının fırsat paylaşmasını engellemek istiyor musunuz?',
                                  confirmColor: isDealBanned ? Colors.green : Colors.deepOrange,
                                );
                                if (confirm == true) {
                                  final success = isDealBanned
                                      ? await _userService.unbanUserDeals(userId)
                                      : await _userService.banUserDeals(userId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? (isDealBanned ? 'Paylaşım izni verildi ✅' : 'Paylaşım yapması engellendi 🚫') : 'İşlem başarısız ❌'),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                    setSheetState(() {});
                                  }
                                }
                              },
                            ),

                            // 5. Admin Mesajı Gönder
                            _buildActionTile(
                              icon: Icons.mail_outline,
                              iconColor: Colors.blueAccent,
                              title: 'Yönetici Mesajı Gönder',
                              subtitle: 'Kullanıcıya resmi bildirim ve in-box sistem mesajı iletir',
                              onTap: () {
                                _showAdminSendMessageDialog(context, userId, displayName);
                              },
                            ),

                            // 6. Rozet Yönetimi ve Otomatik Eşitle
                            _buildActionTile(
                              icon: Icons.workspace_premium,
                              iconColor: Colors.amber[700] ?? Colors.amber,
                              title: 'Rozet Yönetimi & Otomatik Eşitle',
                              subtitle: '${badgeIds.length} rozet tanımlı • Otomatik kontrol et veya katalogdan ver',
                              onTap: () {
                                Navigator.pop(ctx);
                                final appUser = AppUser(
                                  uid: userId,
                                  username: username,
                                  nickname: nickname,
                                  profileImageUrl: profileImageUrl,
                                  points: points,
                                  dealCount: dealCount,
                                  totalLikes: totalLikes,
                                  badges: badgeIds,
                                );
                                _showBadgeDialog(appUser);
                              },
                            ),

                            // 7. Profil Sayfası
                            _buildActionTile(
                              icon: Icons.person_outline,
                              iconColor: isDark ? Colors.grey[300]! : Colors.grey[700]!,
                              title: 'Kullanıcı Profilini Aç',
                              subtitle: 'Paylaşımlar, takipçiler ve profil detaylarını incele',
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
                                );
                              },
                            ),

                            const SizedBox(height: 8),
                            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                            const SizedBox(height: 8),

                            // 8. Hesabı ve Tüm Verileri Sil
                            _buildActionTile(
                              icon: Icons.delete_forever,
                              iconColor: Colors.red,
                              title: 'Hesabı ve Tüm Verileri Kalıcı Sil',
                              subtitle: 'Profil, fırsatlar, yorumlar, mesajlar ve giriş hesabı tamamen yok edilir',
                              isDestructive: true,
                              onTap: () async {
                                final first = await _showConfirmDialog(
                                  context: context,
                                  title: '⚠️ Hesabı Silmek İstediğinize Emin Misiniz?',
                                  message: '$displayName adlı kullanıcının tüm profilini, paylaştığı tüm fırsatları, yorumlarını ve giriş hesabını KALICI olarak silmek üzeresiniz. Bu işlem geri alınamaz!',
                                  confirmColor: Colors.red,
                                  confirmText: 'Devam Et',
                                );
                                if (first != true) return;

                                if (!context.mounted) return;
                                final second = await _showConfirmDialog(
                                  context: context,
                                  title: '🚨 SON UYARI',
                                  message: 'Bu kullanıcının hesabı Firebase Auth ve Firestore üzerinden tamamen yok edilecektir. Onaylıyor musunuz?',
                                  confirmColor: Colors.red,
                                  confirmText: 'Kalıcı Olarak Sil',
                                );
                                if (second != true) return;
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);

                                try {
                                  final success = await _userService.deleteUserAccountAdmin(userId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? 'Kullanıcı hesabı başarıyla silindi 🗑️' : 'Silme başarısız'),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Silme hatası: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatBadge(IconData icon, String label, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? Colors.red
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    Color confirmColor = Colors.blue,
    String confirmText = 'Onayla',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('İptal', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdminSendMessageDialog(BuildContext context, String targetUserId, String targetDisplayName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Row(
          children: [
            Icon(Icons.mail_outline, color: primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Admin Mesajı: $targetDisplayName',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  hintText: 'Örn: Uyarı, Bilgilendirme veya Hediye',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Başlık zorunludur' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mesaj İçeriği',
                  hintText: 'Kullanıcıya iletilecek mesajı yazın...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Mesaj içeriği zorunludur' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'İptal',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Gönder'),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final currentAdmin = FirebaseAuth.instance.currentUser;
              final adminName = currentAdmin?.displayName ?? 'FırsatKolik Yönetimi';
              final adminId = currentAdmin?.uid ?? 'admin';

              final success = await _messageService.sendAdminToUserMessage(
                targetUserId: targetUserId,
                adminId: adminId,
                adminName: adminName,
                title: titleController.text.trim(),
                content: contentController.text.trim(),
              );

              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Mesaj kullanıcıya iletildi 📨' : 'Mesaj gönderilemedi',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBadgeDialog(AppUser user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: Text(
            'Rozet Yönetimi: ${user.displayName}',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final awarded = await _userService.checkAndAwardBadges(user.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              awarded.isNotEmpty
                                  ? 'Otomatik kontrol tamamlandı. ${awarded.length} yeni rozet verildi!'
                                  : 'Yeni rozet koşulu sağlanmadı.',
                            ),
                            backgroundColor: awarded.isNotEmpty ? Colors.green : Colors.grey[700],
                          ),
                        );
                        Navigator.pop(dialogCtx);
                      }
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Otomatik Rozet Kontrolü Yap'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mevcut Rozetler:',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (user.badges.isEmpty)
                    Text(
                      'Henüz rozet yok',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                    )
                  else
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
                          onDeleted: () async {
                            await _removeBadge(user.uid, badgeId);
                            setDialogState(() {
                              user.badges.remove(badgeId);
                            });
                          },
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
                        onPressed: () async {
                          await _addBadge(user.uid, badgeId);
                          setDialogState(() {
                            if (!user.badges.contains(badgeId)) {
                              user.badges.add(badgeId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Kapat',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ),
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
              const SnackBar(
                content: Text('Rozet eklendi ✅'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      _log('Rozet ekleme hatası: $e');
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rozet eklenirken hata oluştu: $cleanMsg'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
            const SnackBar(
              content: Text('Rozet kaldırıldı ✅'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _log('Rozet kaldırma hatası: $e');
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rozet kaldırılırken hata oluştu: $cleanMsg'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

