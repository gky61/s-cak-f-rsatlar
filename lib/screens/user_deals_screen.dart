import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _userDealsStream = _firestoreService.getUserDealsStream(widget.userId, limit: widget.limit);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;
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

                final deals = snapshot.data ?? [];

                if (deals.isEmpty) {
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

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _userDealsStream = _firestoreService.getUserDealsStream(widget.userId, limit: widget.limit);
                    });
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.61,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: deals.length,
                    itemBuilder: (context, index) {
                      final deal = deals[index];
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(bool isDark) {
    final bgColor = isDark 
        ? const Color(0xFF1E293B).withValues(alpha: 0.7) 
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
              'Son 30 güne ait paylaşımlar gösterilir. Süresi dolan eski fırsatlar sistemden otomatik temizlenir.',
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
        childAspectRatio: 0.61,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const DealCardSkeleton(viewMode: CardViewMode.vertical);
      },
    );
  }
}
