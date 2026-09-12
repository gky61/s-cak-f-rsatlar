import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/deal.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../screens/deal_detail_screen.dart';
import '../screens/deal_detail/admin_dialogs/admin_edit_sheet.dart';
import '../widgets/deal_card_skeleton.dart';

class AdminExpiredDealsView extends StatefulWidget {
  const AdminExpiredDealsView({super.key});

  @override
  State<AdminExpiredDealsView> createState() => _AdminExpiredDealsViewState();
}

class _AdminExpiredDealsViewState extends State<AdminExpiredDealsView> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _activeFilter = 'all'; // 'all', 'community', 'bot', 'approved', 'unapproved'
  bool _isSelectionMode = false;
  final Set<String> _selectedDealIds = {};
  bool _isPerformingBatch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) {
      return 'Az önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} sa önce';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return DateFormat('dd.MM.yyyy', 'tr_TR').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Deal>>(
      stream: _firestoreService.getExpiredDealsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const DealCardSkeleton(viewMode: CardViewMode.horizontal),
          );
        }

        final allDeals = snapshot.data ?? [];

        // Filtre sayıları hesaplama
        final int allCount = allDeals.length;
        final int communityCount = allDeals.where((d) => d.isUserSubmitted || !d.isBotkolik).length;
        final int botCount = allDeals.where((d) => d.isBotkolik).length;
        final int approvedCount = allDeals.where((d) => d.isApproved == true).length;
        final int unapprovedCount = allDeals.where((d) => d.isApproved != true).length;

        // Filtreleme
        final filteredDeals = allDeals.where((deal) {
          // Filtre Çipi
          if (_activeFilter == 'community' && deal.isBotkolik) return false;
          if (_activeFilter == 'bot' && !deal.isBotkolik) return false;
          if (_activeFilter == 'approved' && deal.isApproved != true) return false;
          if (_activeFilter == 'unapproved' && deal.isApproved == true) return false;

          // Arama Sorgusu
          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.trim().toLowerCase();
            final title = deal.title.toLowerCase();
            final store = deal.store.toLowerCase();
            final brand = (deal.brand ?? '').toLowerCase();
            final category = (deal.category).toLowerCase();
            final matches = title.contains(query) ||
                store.contains(query) ||
                brand.contains(query) ||
                category.contains(query);
            if (!matches) return false;
          }

          return true;
        }).toList();

        return Column(
          children: [
            // 🔍 Arama ve Filtreleme Başlığı
            _buildSearchAndFilterHeader(
              isDark: isDark,
              allCount: allCount,
              communityCount: communityCount,
              botCount: botCount,
              approvedCount: approvedCount,
              unapprovedCount: unapprovedCount,
            ),

            // ⚡ Toplu İşlem & Çoklu Seçim Çubuğu
            if (allDeals.isNotEmpty)
              _buildBatchActionBar(
                isDark: isDark,
                filteredDeals: filteredDeals,
                allDeals: allDeals,
              ),

            // 📋 Fırsat Listesi veya Boş Durum
            Expanded(
              child: _isPerformingBatch
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Toplu işlem gerçekleştiriliyor...', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : filteredDeals.isEmpty
                      ? _buildEmptyState(isDark: isDark, hasQuery: _searchQuery.isNotEmpty || _activeFilter != 'all')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                          itemCount: filteredDeals.length,
                          itemBuilder: (context, index) {
                            final deal = filteredDeals[index];
                            return _buildExpiredDealCard(deal, isDark);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  // Arama ve Filtre Başlığı
  Widget _buildSearchAndFilterHeader({
    required bool isDark,
    required int allCount,
    required int communityCount,
    required int botCount,
    required int approvedCount,
    required int unapprovedCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          // Arama Girişi
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Süresi bitenlerde ara (ürün, mağaza, marka)...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 17),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Yatay Filtre Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tümü ($allCount)', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('bot', '🤖 Botkolik ($botCount)', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('community', '👤 Topluluk ($communityCount)', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('approved', '📦 Eski Yayında ($approvedCount)', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('unapproved', '⏳ Onaysız Biten ($unapprovedCount)', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _activeFilter == filterKey;
    const primary = AppTheme.primary;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _activeFilter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primary
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? const Color(0xFFFF8C5A) : primary)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // Toplu İşlem & Çoklu Seçim Çubuğu
  Widget _buildBatchActionBar({
    required bool isDark,
    required List<Deal> filteredDeals,
    required List<Deal> allDeals,
  }) {
    if (_isSelectionMode) {
      final selectedCount = _selectedDealIds.length;
      final bool allSelected = filteredDeals.isNotEmpty &&
          filteredDeals.every((d) => _selectedDealIds.contains(d.id));

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        child: Row(
          children: [
            // Tümünü Seç Checkbox
            InkWell(
              onTap: () {
                setState(() {
                  if (allSelected) {
                    _selectedDealIds.clear();
                  } else {
                    _selectedDealIds.addAll(filteredDeals.map((d) => d.id));
                  }
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$selectedCount Seçildi',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),

            // Seçilenleri Yayına Al
            if (selectedCount > 0) ...[
              TextButton.icon(
                onPressed: () => _showBatchReactivateModal(
                  filteredDeals.where((d) => _selectedDealIds.contains(d.id)).toList(),
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 16, color: Colors.green),
                label: Text('Yayına Al ($selectedCount)', style: const TextStyle(fontSize: 11.5, color: Colors.green, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 6),
              // Seçilenleri Sil
              TextButton.icon(
                onPressed: () => _batchDeleteSelected(
                  filteredDeals.where((d) => _selectedDealIds.contains(d.id)).toList(),
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.red),
                label: Text('Sil ($selectedCount)', style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Seçimden Çık
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 19),
              tooltip: 'Seçimden Çık',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedDealIds.clear();
                });
              },
            ),
          ],
        ),
      );
    }

    // Normal Mod Toolbar
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '${filteredDeals.length} Süresi Biten İlan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          const Spacer(),

          // Çoklu Seçim Modunu Aç
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isSelectionMode = true;
                _selectedDealIds.clear();
              });
            },
            icon: const Icon(Icons.checklist_rounded, size: 16),
            label: const Text('Çoklu Seç', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              foregroundColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              backgroundColor: (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 6),

          // Tümünü Temizle (Batch Delete)
          TextButton.icon(
            onPressed: () => _confirmDeleteAll(allDeals),
            icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
            label: const Text('Tümünü Sil', style: TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              backgroundColor: Colors.red.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  // Süresi Biten İlan Kartı
  Widget _buildExpiredDealCard(Deal deal, bool isDark) {
    final bool isBot = deal.isBotkolik;
    final bool isSelected = _selectedDealIds.contains(deal.id);
    final String sourceName = deal.sourceDisplayName;
    final String timeAgoStr = _formatTimeAgo(deal.createdAt);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedDealIds.remove(deal.id);
              } else {
                _selectedDealIds.add(deal.id);
              }
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: deal.id)),
            );
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🏷️ Kart Üst Barı: Kaynak, Bitiş Sebebi & Zaman
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Çoklu Seçim Checkbox
                  if (_isSelectionMode) ...[
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isSelected ? AppTheme.primary : (isDark ? Colors.grey[500] : Colors.grey[400]),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Kaynak Rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isBot ? const Color(0xFF3B82F6) : const Color(0xFFA855F7)).withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
                          size: 12,
                          color: isBot
                              ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                              : (isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sourceName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isBot
                                ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                : (isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Bitiş Durum Sebebi
                  Flexible(
                    child: _buildExpirationReasonBadge(deal, isDark),
                  ),
                  const SizedBox(width: 4),

                  // Zaman
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        timeAgoStr,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 📦 Ana Ürün Gövdesi
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ürün Resmi + "KAÇTI" Rozeti
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        deal.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: deal.imageUrl,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  child: const Icon(Icons.image_not_supported_rounded, size: 24, color: Colors.grey),
                                ),
                              )
                            : Container(
                                width: 72,
                                height: 72,
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                child: const Icon(Icons.image_not_supported_rounded, size: 24, color: Colors.grey),
                              ),
                        // Karartma & "KAÇTI" Pill
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hourglass_disabled_rounded, size: 9, color: Colors.white),
                                SizedBox(width: 2.5),
                                Text(
                                  'KAÇTI',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Ürün Detayları
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Başlık
                        Text(
                          deal.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Mağaza ve Kategori
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                deal.store.isNotEmpty ? deal.store : 'Mağaza Yok',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('•', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[600] : Colors.grey[400])),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                Category.getNameById(deal.category),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Fiyat Satırı
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (deal.hidePrice)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Fiyat Gizli',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              )
                            else ...[
                              Text(
                                '${deal.price.toStringAsFixed(deal.price.truncateToDouble() == deal.price ? 0 : 2)} ₺',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                ),
                              ),
                              if (deal.originalPrice != null && deal.originalPrice! > deal.price) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${deal.originalPrice!.toStringAsFixed(0)} ₺',
                                  style: TextStyle(
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                                  ),
                                ),
                              ],
                              if (deal.discountRate != null && deal.discountRate! > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '%${deal.discountRate}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🛠️ Ergonomik Aksiyon Butonları (RenderFlex Overflow Önleyici)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  // Sil Butonu
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDeleteSingle(deal),
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                        label: const Text('Sil', style: TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Düzenle Butonu
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: () => showAdminEditSheet(
                          context: context,
                          deal: deal,
                          firestoreService: _firestoreService,
                          onDealUpdated: () => setState(() {}),
                        ),
                        icon: Icon(Icons.edit_outlined, size: 15, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                        label: Text(
                          'Düzenle',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)).withValues(alpha: 0.4)),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Yayına Al Butonu (Seçenek Modalı Tetikler)
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: () => _showReactivateOptionsModal(deal),
                        icon: const Icon(Icons.rocket_launch_rounded, size: 15),
                        label: const Text('Yayına Al', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bitiş Durum Sebebi Rozeti
  Widget _buildExpirationReasonBadge(Deal deal, bool isDark) {
    if (deal.expiredVotes > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.how_to_vote_rounded, size: 11, color: Colors.amber),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                '${deal.expiredVotes} Oy ile Bitti',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            ),
          ],
        ),
      );
    } else if (deal.isApproved == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_outlined, size: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                'Eski Yayında',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_bottom_rounded, size: 11, color: Color(0xFFD97706)),
            SizedBox(width: 3),
            Flexible(
              child: Text(
                'Onaysız Bitti',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Boş Durum Görünümü
  Widget _buildEmptyState({required bool isDark, required bool hasQuery}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (hasQuery ? Colors.blue : Colors.green).withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasQuery ? Icons.search_off_rounded : Icons.check_circle_outline_rounded,
                size: 38,
                color: hasQuery ? Colors.blue : Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'Eşleşen Fırsat Bulunamadı' : 'Süresi Biten İlan Yok',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Arama kriterlerinize veya filtreye uygun süresi biten ilan bulunamadı.'
                  : 'Süresi biten tüm ilanlar temizlenmiş veya tekrar yayına alınmış.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            if (hasQuery) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _activeFilter = 'all';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Filtreleri Temizle'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tekli Yayına Alma Seçenek Modalı
  void _showReactivateOptionsModal(Deal deal) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Fırsatı Tekrar Yayına Al',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // Seçenek 1: Hemen Yayına Al (Normal)
                _buildOptionTile(
                  icon: Icons.check_circle_rounded,
                  iconColor: Colors.green,
                  title: 'Hemen Yayına Al (Normal)',
                  subtitle: 'Fırsatı aktif eder ve süresi bitti oylarını sıfırlar.',
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeReactivate(deal, refreshTimestamp: false);
                  },
                ),
                const SizedBox(height: 8),

                // Seçenek 2: Tarihi Şimdiye Güncelle & En Üste Al (Öne Çıkar)
                _buildOptionTile(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Tarihi Şimdiye Güncelle & En Üste Al',
                  subtitle: 'Tarihi yenileyerek Wilson Score algoritmasında anasayfanın en tepesine taşır.',
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeReactivate(deal, refreshTimestamp: true);
                  },
                ),
                const SizedBox(height: 8),

                // Seçenek 3: Fiyatı Gizle & Yayına Al
                _buildOptionTile(
                  icon: Icons.visibility_off_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Fiyatı Gizle & Yayına Al',
                  subtitle: 'Değişken fiyatlı genel kampanya veya kupon fırsatı olarak yayına alır.',
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeReactivate(deal, hidePrice: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // Tekli Yayına Alma İcra Fonksiyonu
  Future<void> _executeReactivate(
    Deal deal, {
    bool refreshTimestamp = false,
    bool hidePrice = false,
  }) async {
    final success = await _firestoreService.unexpireDeal(
      deal.id,
      refreshTimestamp: refreshTimestamp,
      hidePrice: hidePrice,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              refreshTimestamp
                  ? 'Fırsat tarihi yenilenerek en üstte yayına alındı 🚀'
                  : 'Fırsat başarıyla yayına alındı ✅',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşlem sırasında hata oluştu ❌'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Toplu Yayına Alma Modalı
  void _showBatchReactivateModal(List<Deal> selectedDeals) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Seçilen ${selectedDeals.length} Fırsatı Yayına Al',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                _buildOptionTile(
                  icon: Icons.check_circle_rounded,
                  iconColor: Colors.green,
                  title: 'Mevcut Tarihleriyle Yayına Al',
                  subtitle: '${selectedDeals.length} fırsatın süresi bitti oylarını sıfırlar ve yayına açar.',
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeBatchReactivate(selectedDeals, refreshTimestamp: false);
                  },
                ),
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Tarihleri Yenile & En Üste Al',
                  subtitle: 'Tüm seçili fırsatları bugünün taze fırsatları gibi feed\'in en tepesine dizer.',
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeBatchReactivate(selectedDeals, refreshTimestamp: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeBatchReactivate(List<Deal> selectedDeals, {required bool refreshTimestamp}) async {
    setState(() {
      _isPerformingBatch = true;
    });

    final ids = selectedDeals.map((d) => d.id).toList();
    final success = await _firestoreService.unexpireDealsBatch(ids, refreshTimestamp: refreshTimestamp);

    if (mounted) {
      setState(() {
        _isPerformingBatch = false;
        _isSelectionMode = false;
        _selectedDealIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${ids.length} fırsat başarıyla yayına alındı 🚀'
                : 'Toplu yayına alma sırasında hata oluştu ❌',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Tekli Silme Onayı
  Future<void> _confirmDeleteSingle(Deal deal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fırsatı Kalıcı Olarak Sil'),
        content: Text(
          'Bu süresi biten fırsatı veritabanından tamamen silmek istediğinize emin misiniz?\n\n"${deal.title}"\n\nBu işlem geri alınamaz.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Fırsat başarıyla silindi 🗑️' : 'Silme başarısız ❌'),
          backgroundColor: success ? Colors.red[700] : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Seçilenleri Toplu Silme
  Future<void> _batchDeleteSelected(List<Deal> selectedDeals) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seçilen ${selectedDeals.length} Fırsatı Sil'),
        content: Text(
          'İşaretlediğiniz ${selectedDeals.length} fırsat veritabanından kalıcı olarak silinecektir.\n\nBu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Seçilenleri Sil'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isPerformingBatch = true;
    });

    final ids = selectedDeals.map((d) => d.id).toList();
    final success = await _firestoreService.deleteDealsBatch(ids);

    if (mounted) {
      setState(() {
        _isPerformingBatch = false;
        _isSelectionMode = false;
        _selectedDealIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${ids.length} fırsat kalıcı olarak silindi 🗑️'
                : 'Toplu silme sırasında hata oluştu ❌',
          ),
          backgroundColor: success ? Colors.red[700] : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Tümünü Sil Onayı (Atomic Batch Delete)
  Future<void> _confirmDeleteAll(List<Deal> allDeals) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tümünü Kalıcı Olarak Sil'),
        content: Text(
          'Süresi biten ${allDeals.length} fırsatın tümü veritabanından kalıcı olarak silinecektir.\n\nBu işlem geri alınamaz.',
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

    if (confirm != true || !mounted) return;

    setState(() {
      _isPerformingBatch = true;
    });

    final ids = allDeals.map((d) => d.id).toList();
    final success = await _firestoreService.deleteDealsBatch(ids);

    if (mounted) {
      setState(() {
        _isPerformingBatch = false;
        _isSelectionMode = false;
        _selectedDealIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${ids.length} fırsat tamamen temizlendi 🗑️'
                : 'Toplu silme sırasında hata oluştu ❌',
          ),
          backgroundColor: success ? Colors.red[700] : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
