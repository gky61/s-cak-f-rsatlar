import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../utils/store_asset_helper.dart';
import 'katalog_listesi_page.dart';

enum MagazaKategori {
  tumu('Tümü', Icons.apps_rounded),
  market('Süpermarket', Icons.shopping_cart_rounded),
  kozmetik('Kozmetik & Bakım', Icons.face_retouching_natural_rounded),
  giyimYasam('Ev & Yaşam', Icons.chair_rounded),
  teknoloji('Elektronik', Icons.devices_rounded);

  final String label;
  final IconData icon;
  const MagazaKategori(this.label, this.icon);
}

class Magaza {
  final String code;
  final String name;
  final String logoAsset;
  final Color brandColor;
  final MagazaKategori kategori;

  const Magaza({
    required this.code,
    required this.name,
    required this.logoAsset,
    required this.brandColor,
    required this.kategori,
  });
}

class AktuelMagazalarPage extends StatefulWidget {
  const AktuelMagazalarPage({super.key});

  @override
  State<AktuelMagazalarPage> createState() => _AktuelMagazalarPageState();
}

class _AktuelMagazalarPageState extends State<AktuelMagazalarPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<QuerySnapshot> _kataloglarStream;
  String _searchQuery = '';
  MagazaKategori _selectedCategory = MagazaKategori.tumu;
  bool _hideHeroBanner = false;

  static const List<Magaza> _magazalar = [
    // 1. Öncelik – Süpermarket / Marketler
    Magaza(code: 'bim', name: 'BİM', logoAsset: 'assets/bim.webp', brandColor: Color(0xFF005691), kategori: MagazaKategori.market),
    Magaza(code: 'a101', name: 'A-101', logoAsset: 'assets/a101.webp', brandColor: Color(0xFF14B4C8), kategori: MagazaKategori.market),
    Magaza(code: 'sok', name: 'ŞOK', logoAsset: 'assets/sok.webp', brandColor: Color(0xFFFFD200), kategori: MagazaKategori.market),
    Magaza(code: 'migros', name: 'Migros', logoAsset: 'assets/migros.webp', brandColor: Color(0xFFEE7C11), kategori: MagazaKategori.market),
    Magaza(code: 'carrefoursa', name: 'CarrefourSA', logoAsset: 'assets/carrefoursa.webp', brandColor: Color(0xFF0F4C81), kategori: MagazaKategori.market),
    Magaza(code: 'metro', name: 'Metro', logoAsset: 'assets/metro.webp', brandColor: Color(0xFF002F6C), kategori: MagazaKategori.market),
    Magaza(code: 'macrocenter', name: 'MacroCenter', logoAsset: 'assets/macrocenter.webp', brandColor: Color(0xFF1B1B1B), kategori: MagazaKategori.market),
    Magaza(code: 'getirbuyuk', name: 'GetirBüyük', logoAsset: 'assets/getirbuyuk.webp', brandColor: Color(0xFF5D3EBC), kategori: MagazaKategori.market),
    Magaza(code: 'bizim', name: 'Bizim Toptan', logoAsset: 'assets/bizim.webp', brandColor: Color(0xFFFFCC00), kategori: MagazaKategori.market),
    Magaza(code: 'file', name: 'File', logoAsset: 'assets/file.webp', brandColor: Color(0xFF3498DB), kategori: MagazaKategori.market),
    Magaza(code: 'happycenter', name: 'Happy Center', logoAsset: 'assets/happycenter.webp', brandColor: Color(0xFF8DC63F), kategori: MagazaKategori.market),
    Magaza(code: 'hakmarexpress', name: 'Hakmar Express', logoAsset: 'assets/hakmar-express.webp', brandColor: Color(0xFFD32F2F), kategori: MagazaKategori.market),
    Magaza(code: 'hakmar', name: 'Hakmar', logoAsset: 'assets/hakmar.webp', brandColor: Color(0xFFD32F2F), kategori: MagazaKategori.market),
    Magaza(code: 'cagri', name: 'Çağrı Hipermarket', logoAsset: 'assets/cagri.webp', brandColor: Color(0xFFE31B23), kategori: MagazaKategori.market),
    Magaza(code: 'kooperatifmarket', name: 'Kooperatif Market', logoAsset: 'assets/kooperatif.webp', brandColor: Color(0xFF00755F), kategori: MagazaKategori.market),

    // 2. Öncelik – Makyaj / Kişisel Bakım
    Magaza(code: 'watsons', name: 'Watsons', logoAsset: 'assets/watsons.webp', brandColor: Color(0xFF00A19B), kategori: MagazaKategori.kozmetik),
    Magaza(code: 'gratis', name: 'Gratis', logoAsset: 'assets/gratis.webp', brandColor: Color(0xFF8B1E87), kategori: MagazaKategori.kozmetik),
    Magaza(code: 'rossmann', name: 'Rossmann', logoAsset: 'assets/rossmann.webp', brandColor: Color(0xFFE2001A), kategori: MagazaKategori.kozmetik),

    // 3. Öncelik – Giyim / Ev / Yaşam / Anne & Bebek
    Magaza(code: 'cetinkaya', name: 'Çetinkaya', logoAsset: 'assets/cetinkaya.webp', brandColor: Color(0xFFE31E24), kategori: MagazaKategori.giyimYasam),
    Magaza(code: 'civil', name: 'Civil', logoAsset: 'assets/civil.webp', brandColor: Color(0xFFFF6600), kategori: MagazaKategori.giyimYasam),
    Magaza(code: 'evkur', name: 'Evkur', logoAsset: 'assets/evkur.webp', brandColor: Color(0xFF003399), kategori: MagazaKategori.giyimYasam),
    Magaza(code: 'mrdiy', name: 'MR.DIY', logoAsset: 'assets/mrdiy.webp', brandColor: Color(0xFFFFD100), kategori: MagazaKategori.giyimYasam),

    // 4. Öncelik – Teknoloji & Elektronik
    Magaza(code: 'teknosa', name: 'Teknosa', logoAsset: 'assets/teknosa.webp', brandColor: Color(0xFFFF5F00), kategori: MagazaKategori.teknoloji),
    Magaza(code: 'vatan', name: 'Vatan Bilgisayar', logoAsset: 'assets/vatan.webp', brandColor: Color(0xFF005691), kategori: MagazaKategori.teknoloji),
    Magaza(code: 'vestel', name: 'Vestel', logoAsset: 'assets/vestel.webp', brandColor: Color(0xFFCC0000), kategori: MagazaKategori.teknoloji),
  ];

  @override
  void initState() {
    super.initState();
    _kataloglarStream = FirebaseFirestore.instance.collection('kataloglar').snapshots();
    _loadBannerPreference();
  }

  Future<void> _loadBannerPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hideHeroBanner = prefs.getBool('hide_aktuel_hero_banner') ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _dismissBanner() async {
    HapticFeedback.lightImpact();
    setState(() {
      _hideHeroBanner = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hide_aktuel_hero_banner', true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Aktüel Kataloglar',
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
        stream: _kataloglarStream,
        builder: (context, snapshot) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final activeStoreCatalogCounts = <String, int>{};
          int totalActiveCatalogs = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final bitisTimestamp = data['bitisTarihi'] as Timestamp?;
                if (bitisTimestamp != null) {
                  final bitis = bitisTimestamp.toDate();
                  final expiryDay = DateTime(bitis.year, bitis.month, bitis.day);
                  if (!expiryDay.isBefore(today)) {
                    final magazaKodu = data['magazaKodu'] as String?;
                    if (magazaKodu != null && magazaKodu.isNotEmpty) {
                      final codeLower = magazaKodu.toLowerCase();
                      activeStoreCatalogCounts[codeLower] = (activeStoreCatalogCounts[codeLower] ?? 0) + 1;
                      totalActiveCatalogs++;
                    }
                  }
                }
              } catch (_) {}
            }
          }

          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          // Filter by Active Catalogs
          var visibleStores = _magazalar.where((m) => activeStoreCatalogCounts.containsKey(m.code.toLowerCase())).toList();

          // Filter by Category
          if (_selectedCategory != MagazaKategori.tumu) {
            visibleStores = visibleStores.where((m) => m.kategori == _selectedCategory).toList();
          }

          // Filter by Search Query
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            visibleStores = visibleStores.where((m) => m.name.toLowerCase().contains(q) || m.code.toLowerCase().contains(q)).toList();
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. HERO BANNER
              if (!_hideHeroBanner)
                SliverToBoxAdapter(
                  child: _buildHeroBanner(isDark, totalActiveCatalogs),
                ),

              // 2. SEARCH BAR & CATEGORY FILTER CHIPS
              SliverToBoxAdapter(
                child: _buildSearchAndCategoryFilters(isDark),
              ),

              // 3. SECTION HEADER
              if (!isLoading && visibleStores.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildSectionHeader(visibleStores.length, isDark),
                ),

              // 4. STORE GRID OR SHIMMER OR EMPTY STATE
              if (isLoading)
                SliverToBoxAdapter(
                  child: _buildShimmerStoreGrid(isDark),
                )
              else if (visibleStores.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(isDark),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.86,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final magaza = visibleStores[index];
                        return KeyedSubtree(
                          key: ValueKey(magaza.code),
                          child: _buildMagazaCard(context, magaza, isDark),
                        );
                      },
                      childCount: visibleStores.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // --- 1. HERO BANNER ---
  Widget _buildHeroBanner(bool isDark, int totalActiveCatalogs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Glowing Gradient Icon Badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF5000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Haftalık Aktüel Broşürleri',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'YENİ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Popüler mağazalardaki ürün katalogları ve broşürleri günlük düzenli taranarak yayına alınmaktadır.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Dismiss Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _dismissBanner,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. SEARCH & CATEGORY FILTERS ---
  Widget _buildSearchAndCategoryFilters(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Mağaza veya market ara... (Örn: BİM, Gratis)',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppTheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 17),
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Category Filter Chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: MagazaKategori.values.length,
            itemBuilder: (context, index) {
              final cat = MagazaKategori.values[index];
              final isSelected = _selectedCategory == cat;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : (isDark ? AppTheme.darkSurface : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.2 : 0.9,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            size: 14,
                            color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155)),
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
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
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  // --- 3. SECTION HEADER STRIP ---
  Widget _buildSectionHeader(int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _selectedCategory == MagazaKategori.tumu
                    ? 'Popüler Mağazalar'
                    : _selectedCategory.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Text(
              '$count Mağaza',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. MODERN STORE CARD ---
  Widget _buildMagazaCard(BuildContext context, Magaza magaza, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KatalogListesiPage(
                magazaKodu: magaza.code,
                magazaAdi: magaza.name,
              ),
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
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: magaza.brandColor.withValues(alpha: isDark ? 0.08 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.025),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                // Brand Color Accent Indicator
                Container(
                  height: 3.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        magaza.brandColor,
                        magaza.brandColor.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),

                // Store Logo Tile
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFFAFAFA),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 5,
                              offset: Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          StoreAssetHelper.getStoreAsset(magaza.code, magaza.logoAsset),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.storefront_rounded,
                              size: 26,
                              color: magaza.brandColor,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Store Name
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Center(
                      child: Text(
                        magaza.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. SKELETON SHIMMER STORE GRID ---
  Widget _buildShimmerStoreGrid(bool isDark) {
    final shimmerBase = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE2E8F0);
    final shimmerHighlight = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8FAFC);

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemCount: 9,
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

  // --- 6. EMPTY STATE ---
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 34,
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aradığınız Mağaza Bulunamadı',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Filtreleri değiştirerek veya arama terimini temizleyerek tekrar deneyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedCategory != MagazaKategori.tumu) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedCategory = MagazaKategori.tumu;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Filtreleri Sıfırla', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
