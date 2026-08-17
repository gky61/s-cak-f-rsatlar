import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/katalog.dart';
import '../theme/app_theme.dart';
import 'katalog_detay_page.dart';

enum KatalogSortOption {
  defaultNewest('En Yeni', Icons.calendar_month_rounded),
  expirySoonest('Bitişi Yaklaşanlar', Icons.hourglass_bottom_rounded),
  expiryLatest('En Uzun Süreli', Icons.event_available_rounded);

  final String label;
  final IconData icon;
  const KatalogSortOption(this.label, this.icon);
}

class KatalogListesiPage extends StatefulWidget {
  final String magazaKodu;
  final String magazaAdi;

  const KatalogListesiPage({
    super.key,
    required this.magazaKodu,
    required this.magazaAdi,
  });

  @override
  State<KatalogListesiPage> createState() => _KatalogListesiPageState();
}

class _KatalogListesiPageState extends State<KatalogListesiPage> {
  KatalogSortOption _currentSort = KatalogSortOption.defaultNewest;

  String _formatDateRange(DateTime start, DateTime end) {
    try {
      final startStr = DateFormat('d MMMM', 'tr_TR').format(start);
      final endStr = DateFormat('d MMMM yyyy', 'tr_TR').format(end);
      return '$startStr - $endStr';
    } catch (e) {
      return '${start.day}.${start.month} - ${end.day}.${end.month}.${end.year}';
    }
  }

  String _getStoreAsset(String storeName) {
    final lower = storeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final map = {
      'bim': 'assets/bim.webp',
      'a101': 'assets/a101.webp',
      'sok': 'assets/sok.webp',
      'migros': 'assets/migros.webp',
      'carrefoursa': 'assets/carrefoursa.webp',
      'metro': 'assets/metro.webp',
      'macrocenter': 'assets/macrocenter.webp',
      'getirbuyuk': 'assets/getirbuyuk.webp',
      'bizim': 'assets/bizim.webp',
      'file': 'assets/file.webp',
      'happycenter': 'assets/happycenter.webp',
      'hakmarexpress': 'assets/hakmar-express.webp',
      'hakmar': 'assets/hakmar.webp',
      'cagri': 'assets/cagri.webp',
      'kooperatifmarket': 'assets/kooperatif.webp',
      'watsons': 'assets/watsons.webp',
      'gratis': 'assets/gratis.webp',
      'rossmann': 'assets/rossmann.webp',
      'cetinkaya': 'assets/cetinkaya.webp',
      'civil': 'assets/civil.webp',
      'evkur': 'assets/evkur.webp',
      'mrdiy': 'assets/mrdiy.webp',
      'teknosa': 'assets/teknosa.webp',
      'vatan': 'assets/vatan.webp',
      'vestel': 'assets/vestel.webp',
    };
    return map[lower] ?? 'assets/store-icon.png';
  }

  Widget _buildValidityBadge(Katalog catalog, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final start = DateTime(
      catalog.baslangicTarihi.year,
      catalog.baslangicTarihi.month,
      catalog.baslangicTarihi.day,
    );
    
    final expiry = DateTime(
      catalog.bitisTarihi.year,
      catalog.bitisTarihi.month,
      catalog.bitisTarihi.day,
    );

    Color badgeBg;
    Color textColor;
    IconData icon;
    String text = catalog.getValidityText();

    if (today.isBefore(start)) {
      badgeBg = const Color(0xFF2563EB);
      textColor = Colors.white;
      icon = Icons.date_range_rounded;
    } else {
      final diff = expiry.difference(today).inDays;
      if (diff < 0) {
        badgeBg = isDark ? const Color(0xFF3F3F46) : const Color(0xFF71717A);
        textColor = Colors.white;
        icon = Icons.event_busy_rounded;
      } else if (diff <= 1) {
        badgeBg = const Color(0xFFDC2626);
        textColor = Colors.white;
        icon = Icons.local_fire_department_rounded;
      } else if (diff <= 3) {
        badgeBg = const Color(0xFFD97706);
        textColor = Colors.white;
        icon = Icons.hourglass_top_rounded;
      } else {
        badgeBg = const Color(0xFF16A34A);
        textColor = Colors.white;
        icon = Icons.check_circle_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 3.5),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '${widget.magazaAdi} Aktüel',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Geri',
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('kataloglar')
            .where('magazaKodu', isEqualTo: widget.magazaKodu)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerCatalogGrid(isDark);
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Bir hata oluştu: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // Parse and filter active catalogs
          final now = DateTime.now();
          final catalogs = snapshot.data?.docs
                  .map((doc) => Katalog.fromFirestore(doc))
                  .where((catalog) => 
                      catalog.bitisTarihi.isAfter(now) || 
                      catalog.bitisTarihi.year == now.year && 
                      catalog.bitisTarihi.month == now.month && 
                      catalog.bitisTarihi.day == now.day)
                  .toList() ?? [];

          // Sort catalogs dynamically
          if (_currentSort == KatalogSortOption.defaultNewest) {
            catalogs.sort((a, b) => b.baslangicTarihi.compareTo(a.baslangicTarihi));
          } else if (_currentSort == KatalogSortOption.expirySoonest) {
            catalogs.sort((a, b) => a.bitisTarihi.compareTo(b.bitisTarihi));
          } else if (_currentSort == KatalogSortOption.expiryLatest) {
            catalogs.sort((a, b) => b.bitisTarihi.compareTo(a.bitisTarihi));
          }

          if (catalogs.isEmpty) {
            return _buildEmptyCatalogState(isDark);
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. STORE HERO HEADER CARD
              SliverToBoxAdapter(
                child: _buildStoreHeroHeader(catalogs.length, isDark),
              ),

              // 2. SORT PILL CHIPS
              SliverToBoxAdapter(
                child: _buildSortPills(isDark),
              ),

              // 3. CATALOG GRID
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.58,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final catalog = catalogs[index];
                      return _buildCatalogCard(context, catalog, isDark);
                    },
                    childCount: catalogs.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- STORE HERO HEADER ---
  Widget _buildStoreHeroHeader(int catalogCount, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Image.asset(
                _getStoreAsset(widget.magazaAdi),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 28, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.magazaAdi,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              '$catalogCount Yayında',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Resmi İndirim Kataloğu',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SORT PILL CHIPS ---
  Widget _buildSortPills(bool isDark) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: KatalogSortOption.values.length,
        itemBuilder: (context, index) {
          final sortOption = KatalogSortOption.values[index];
          final isSelected = _currentSort == sortOption;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currentSort = sortOption);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.12)
                        : (isDark ? AppTheme.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.2 : 0.9,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sortOption.icon,
                        size: 14,
                        color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        sortOption.label,
                        style: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.white : AppTheme.primary)
                              : (isDark ? const Color(0xFFD4D4D8) : const Color(0xFF475569)),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MODERN CATALOG CARD ---
  Widget _buildCatalogCard(BuildContext context, Katalog catalog, bool isDark) {
    final pageCount = catalog.sayfaResimleri.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KatalogDetayPage(catalog: catalog),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Image with Overlay Badges
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                          child: CachedNetworkImage(
                            imageUrl: catalog.kapakResmi,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 350),
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.white38 : AppTheme.primary,
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 36,
                                color: isDark ? Colors.grey[700] : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Top Left: Validity Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildValidityBadge(catalog, isDark),
                      ),
                      // Bottom Right: Page Count Badge (Separated from validity badge to prevent overlap)
                      if (pageCount > 0)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.file_copy_rounded, size: 9.5, color: Colors.white),
                                const SizedBox(width: 3.5),
                                Text(
                                  '$pageCount Sayfa',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Info Area
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catalog.katalogBasligi,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10.5,
                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDateRange(catalog.baslangicTarihi, catalog.bitisTarihi),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Examine Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Broşürü İncele',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppTheme.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SKELETON SHIMMER CATALOG GRID ---
  Widget _buildShimmerCatalogGrid(bool isDark) {
    final shimmerBase = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE2E8F0);
    final shimmerHighlight = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8FAFC);

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.58,
          ),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  // --- EMPTY CATALOG STATE ---
  Widget _buildEmptyCatalogState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 38,
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aktif Broşür Bulunmuyor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.magazaAdi} için şu anda yayında olan güncel bir kampanya broşürü bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text(
                'Diğer Mağazalara Bak',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
