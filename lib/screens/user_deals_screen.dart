import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deal.dart';
import '../services/firestore_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import 'deal_detail_screen.dart';

class UserDealsScreen extends StatefulWidget {
  final String userId;
  final String username;
  final bool isOwnProfile;
  final int? limit;

  const UserDealsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.isOwnProfile,
    this.limit,
  });

  @override
  State<UserDealsScreen> createState() => _UserDealsScreenState();
}

class _UserDealsScreenState extends State<UserDealsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  late Stream<List<Deal>> _userDealsStream;
  String _filterStatus = 'all'; // 'all', 'active', 'pending'
  bool _dealApprovalRequired = true;
  StreamSubscription? _settingsSub;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _userDealsStream = _firestoreService.getUserDealsStream(
      widget.userId,
      limit: widget.limit,
      onlyApproved: !widget.isOwnProfile,
    );
    if (widget.isOwnProfile) {
      _settingsSub = _firestoreService.firestore.collection('settings').doc('app').snapshots().listen((snap) {
        if (snap.exists && snap.data() != null && mounted) {
          setState(() {
            _dealApprovalRequired = snap.data()!['dealApprovalRequired'] ?? true;
          });
        }
      });
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.isOwnProfile ? 'Paylaştığım Fırsatlar' : '${widget.username} Fırsatları';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
      body: Column(
        children: [
          _buildInfoBanner(isDark),
          Expanded(
            child: StreamBuilder<List<Deal>>(
              stream: _userDealsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingGrid();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fırsatlar yüklenirken bir hata oluştu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allDeals = snapshot.data ?? [];

                if (allDeals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isOwnProfile
                              ? 'Henüz hiçbir fırsat paylaşmadınız'
                              : '${widget.username} henüz fırsat paylaşmamış',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.isOwnProfile)
                          Text(
                            'Fırsat paylaşarak topluluğa katkıda bulunabilirsiniz!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  );
                }

                final activeDeals = allDeals.where((d) => d.isApproved == true).toList();
                final pendingDeals = allDeals.where((d) => d.isApproved == false).toList();

                List<Deal> filteredDeals;
                if (!widget.isOwnProfile || _filterStatus == 'active') {
                  filteredDeals = activeDeals;
                } else if (_filterStatus == 'pending') {
                  filteredDeals = pendingDeals;
                } else {
                  filteredDeals = allDeals;
                }

                return Column(
                  children: [
                    if (widget.isOwnProfile && pendingDeals.isNotEmpty)
                      _buildStatusFilterBar(
                        isDark: isDark,
                        allCount: allDeals.length,
                        activeCount: activeDeals.length,
                        pendingCount: pendingDeals.length,
                      ),
                    Expanded(
                      child: filteredDeals.isEmpty
                          ? _buildFilterEmptyState(isDark)
                          : RefreshIndicator(
                              onRefresh: () async {
                                setState(() {
                                  _userDealsStream = _firestoreService.getUserDealsStream(
                                    widget.userId,
                                    limit: widget.limit,
                                    onlyApproved: !widget.isOwnProfile,
                                  );
                                });
                              },
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.635,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 11,
                                ),
                                itemCount: filteredDeals.length,
                                itemBuilder: (context, index) {
                                  final deal = filteredDeals[index];
                                  return DealCard(
                                    deal: deal,
                                    viewMode: CardViewMode.vertical,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DealDetailScreen(dealId: deal.id),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterBar({
    required bool isDark,
    required int allCount,
    required int activeCount,
    required int pendingCount,
  }) {
    final filters = [
      {'id': 'all', 'label': 'Tümü', 'count': allCount, 'icon': Icons.grid_view_rounded},
      {'id': 'active', 'label': 'Yayında', 'count': activeCount, 'icon': Icons.check_circle_outline_rounded},
      {'id': 'pending', 'label': 'İncelemede', 'count': pendingCount, 'icon': Icons.hourglass_top_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: filters.map((f) {
          final id = f['id'] as String;
          final label = f['label'] as String;
          final count = f['count'] as int;
          final icon = f['icon'] as IconData;
          final isSelected = _filterStatus == id;
          final isPendingChip = id == 'pending';

          Color chipBg;
          Color chipBorder;
          Color chipText;

          if (isSelected) {
            chipBg = isPendingChip ? const Color(0xFFD97706) : AppTheme.primary;
            chipBorder = chipBg;
            chipText = Colors.white;
          } else {
            chipBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);
            chipBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
            chipText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _filterStatus = id);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: chipBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 12.5, color: isSelected ? Colors.white : (isPendingChip ? const Color(0xFFD97706) : chipText)),
                      const SizedBox(width: 4),
                      Text(
                        '$label ($count)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: chipText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _filterStatus == 'pending'
                ? Icons.verified_outlined
                : Icons.hourglass_empty_rounded,
            size: 52,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            _filterStatus == 'pending'
                ? 'İnceleme bekleyen fırsatınız yok'
                : 'Bu filtreye uygun fırsat bulunamadı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(bool isDark) {
    final bgColor = isDark 
        ? AppTheme.darkSurfaceElevated 
        : const Color(0xFFF0F7FF);
    final borderColor = isDark 
        ? Colors.blue.withValues(alpha: 0.22) 
        : const Color(0xFFBAE6FD).withValues(alpha: 0.8);
    final iconColor = isDark 
        ? const Color(0xFF60A5FA) 
        : const Color(0xFF0284C7);
    final textColor = isDark 
        ? const Color(0xFF94A3B8) 
        : const Color(0xFF475569);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isOwnProfile
                  ? (_dealApprovalRequired
                      ? 'Paylaşımlarınız incelendikten sonra tüm topluluğa duyurulur. Son 30 güne ait paylaşımlar gösterilir.'
                      : 'Paylaşımlarınız anında tüm topluluğa duyurulur. Son 30 güne ait paylaşımlar gösterilir.')
                  : 'Son 30 güne ait onaylanmış paylaşımlar gösterilir. Süresi dolan eski fırsatlar sistemden otomatik temizlenir.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: textColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.635,
        crossAxisSpacing: 12,
        mainAxisSpacing: 11,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const DealCardSkeleton(viewMode: CardViewMode.vertical);
      },
    );
  }
}
