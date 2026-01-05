import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deal.dart';
import '../models/category.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/badge_helper.dart';
import '../theme/app_theme.dart';
import 'deal_detail_screen.dart';
import 'profile_screen.dart';
import 'message_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

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
    _tabController = TabController(length: 5, vsync: this);
    _loadTabCounts();
  }
  
  void _loadTabCounts() {
    // Onay bekleyen (bot fırsatları)
    _firestoreService.getPendingDealsStream().listen((deals) {
      if (mounted) {
        setState(() {
          _pendingCount = deals.length;
        });
      }
    });
    
    // Paylaşılanlar (kullanıcı fırsatları)
    _firestoreService.getUserSubmittedPendingDealsStream().listen((deals) {
      if (mounted) {
        setState(() {
          _userSubmittedCount = deals.length;
        });
      }
    });
    
    // Süresi bitenler
    _firestoreService.getExpiredDealsStream().listen((deals) {
      if (mounted) {
        setState(() {
          _expiredCount = deals.length;
        });
      }
    });
    
    // Kullanıcılar
    FirebaseFirestore.instance
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
    _firestoreService.getAllMessagesStream().listen((messages) {
      if (mounted) {
        setState(() {
          _unreadMessagesCount = messages.where((m) => !m.isReadByAdmin).length;
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
        ],
      ),
    );
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
    final currencyFormat = NumberFormat.currency(symbol: '₺', decimalDigits: 0);
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
                          deal.isApproved 
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
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(deal.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
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
    } else if (option == 'editor') {
      await _approveDeal(id, isEditorPick: true);
    }
  }

  Future<void> _approveDeal(String id, {bool isEditorPick = false}) async {
    await _firestoreService.updateDeal(id, {
      'isApproved': true,
      'isEditorPick': isEditorPick,
    });
    
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

  Future<void> _showEditDialog(Deal deal) async {
    final titleController = TextEditingController(text: deal.title);
    final descriptionController = TextEditingController(text: deal.description);
    final priceController = TextEditingController(text: deal.price.toStringAsFixed(2));
    final originalPriceController = TextEditingController(
      text: deal.originalPrice?.toStringAsFixed(2) ?? '',
    );
    final storeController = TextEditingController(text: deal.store);
    final linkController = TextEditingController(text: deal.link);
    final imageUrlController = TextEditingController(text: deal.imageUrl);

    // Kategori eşleştirmesi: Firestore'da kategori adı saklanıyor, dropdown'da ID kullanılıyor
    String? selectedCategoryId;
    String? selectedSubCategory = deal.subCategory;
    
    // Kategori adından ID'yi bul
    for (final cat in Category.categories) {
      if (cat.name == deal.category || cat.id == deal.category) {
        selectedCategoryId = cat.id;
        break;
      }
    }
    // Bulunamazsa varsayılan olarak 'elektronik' kullan
    selectedCategoryId ??= 'elektronik';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    
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
                    controller: linkController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Ürün URL',
                      border: OutlineInputBorder(),
                      hintText: 'https://...',
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                    keyboardType: TextInputType.url,
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
                if (price == null || price <= 0) {
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
                  'price': price,
                  'store': storeController.text.trim(),
                  'link': linkController.text.trim(),
                  'imageUrl': imageUrlController.text.trim(),
                  // Kategori ID'sinden kategori adına çevir (Firestore'da kategori adı saklanıyor)
                  'category': Category.getNameById(selectedCategoryId!),
                };

                // Eski fiyat varsa ekle
                final originalPrice = originalPriceController.text.trim();
                if (originalPrice.isNotEmpty) {
                  final origPrice = double.tryParse(originalPrice.replaceAll(',', '.'));
                  if (origPrice != null && origPrice > price) {
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
                        setState(() {
                          _userSearchController.clear();
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
                _userSearchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        // Kullanıcı listesi
        Expanded(
          child: StreamBuilder<List<DocumentSnapshot>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('points', descending: true)
                .limit(200)
                .snapshots()
                .map((snapshot) => snapshot.docs),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = snapshot.data ?? [];
              
              // Arama filtreleme
              final users = _userSearchQuery.isEmpty
                  ? allUsers
                  : allUsers.where((doc) {
                      final data = doc.data() as Map<String, dynamic>?;
                      final username = (data?['username'] ?? '').toString().toLowerCase();
                      final nickname = (data?['nickname'] ?? '').toString().toLowerCase();
                      final uid = doc.id.toLowerCase();
                      return username.contains(_userSearchQuery) ||
                             nickname.contains(_userSearchQuery) ||
                             uid.contains(_userSearchQuery);
                    }).toList();

              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _userSearchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userSearchQuery.isEmpty 
                            ? 'Kullanıcı bulunamadı'
                            : '"$_userSearchQuery" ile eşleşen kullanıcı yok',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userDoc = users[index];
                  final user = AppUser.fromFirestore(userDoc);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: user.uid),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  backgroundImage: user.profileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(user.profileImageUrl)
                      : null,
                  child: user.profileImageUrl.isEmpty
                      ? Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.username,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Rozetler
                    ...BadgeHelper.getBadgeInfos(user.badges).map(
                      (badge) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Tooltip(
                          message: badge.name,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badge.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: badge.color.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badge.icon,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text('${user.points} Puan • ${user.totalLikes} Beğeni'),
                trailing: IconButton(
                  icon: const Icon(Icons.workspace_premium),
                  onPressed: () => _showBadgeDialog(user),
                  tooltip: 'Rozet Ver',
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
}
