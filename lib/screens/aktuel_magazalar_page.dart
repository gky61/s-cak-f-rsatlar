import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'katalog_listesi_page.dart';

class Magaza {
  final String code;
  final String name;
  final String logoAsset;
  final Color brandColor;

  const Magaza({
    required this.code,
    required this.name,
    required this.logoAsset,
    required this.brandColor,
  });
}

class AktuelMagazalarPage extends StatelessWidget {
  const AktuelMagazalarPage({super.key});

  static const List<Magaza> _magazalar = [
    // 1. Öncelik – Süpermarket / Marketler
    Magaza(code: 'bim', name: 'BİM', logoAsset: 'assets/bim.webp', brandColor: Color(0xFF005691)),
    Magaza(code: 'a101', name: 'A-101', logoAsset: 'assets/a101.webp', brandColor: Color(0xFF14B4C8)),
    Magaza(code: 'sok', name: 'ŞOK', logoAsset: 'assets/sok.webp', brandColor: Color(0xFFFFD200)),
    Magaza(code: 'migros', name: 'Migros', logoAsset: 'assets/migros.webp', brandColor: Color(0xFFEE7C11)),
    Magaza(code: 'carrefoursa', name: 'CarrefourSA', logoAsset: 'assets/carrefoursa.webp', brandColor: Color(0xFF0F4C81)),
    Magaza(code: 'metro', name: 'Metro', logoAsset: 'assets/metro.webp', brandColor: Color(0xFF002F6C)),
    Magaza(code: 'macrocenter', name: 'MacroCenter', logoAsset: 'assets/macrocenter.webp', brandColor: Color(0xFF1B1B1B)),
    Magaza(code: 'getirbuyuk', name: 'GetirBüyük', logoAsset: 'assets/getirbuyuk.webp', brandColor: Color(0xFF5D3EBC)),
    Magaza(code: 'bizim', name: 'Bizim Toptan', logoAsset: 'assets/bizim.webp', brandColor: Color(0xFFFFCC00)),
    Magaza(code: 'file', name: 'File', logoAsset: 'assets/file.webp', brandColor: Color(0xFF3498DB)),
    Magaza(code: 'happycenter', name: 'Happy Center', logoAsset: 'assets/happycenter.webp', brandColor: Color(0xFF8DC63F)),
    Magaza(code: 'hakmar', name: 'Hakmar', logoAsset: 'assets/hakmar-express.webp', brandColor: Color(0xFFD32F2F)),
    Magaza(code: 'cagri', name: 'Çağrı Hipermarket', logoAsset: 'assets/cagri.webp', brandColor: Color(0xFFE31B23)),
    Magaza(code: 'kooperatifmarket', name: 'Kooperatif Market', logoAsset: 'assets/kooperatif.webp', brandColor: Color(0xFF00755F)),
    // 2. Öncelik – Makyaj / Kişisel Bakım
    Magaza(code: 'watsons', name: 'Watsons', logoAsset: 'assets/watsons.webp', brandColor: Color(0xFF00A19B)),
    Magaza(code: 'gratis', name: 'Gratis', logoAsset: 'assets/gratis.webp', brandColor: Color(0xFF8B1E87)),
    // 3. Öncelik – Teknoloji
    Magaza(code: 'teknosa', name: 'Teknosa', logoAsset: 'assets/teknosa.webp', brandColor: Color(0xFFFF5F00)),
    Magaza(code: 'vatan', name: 'Vatan Bilgisayar', logoAsset: 'assets/vatan.webp', brandColor: Color(0xFF005691)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Aktüel',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hoş geldiniz / Açıklama bannerı
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mağazaları Keşfet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'En güncel indirim kataloglarını ve broşürlerini seçtiğin mağazaya tıklayarak anında incele.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Mağaza Grid'i
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final magaza = _magazalar[index];
                  return _buildMagazaCard(context, magaza, isDark);
                },
                childCount: _magazalar.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMagazaCard(BuildContext context, Magaza magaza, bool isDark) {
    return GestureDetector(
      onTap: () {
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
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.2) 
                  : Colors.grey.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Logo alanı
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: isDark ? AppTheme.darkBackground : const Color(0xFFFAFAFA),
                  child: Center(
                    child: Image.asset(
                      magaza.logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.store_outlined, 
                          size: 32, 
                          color: magaza.brandColor,
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Marka renk çizgisi
              Container(
                height: 3,
                color: magaza.brandColor,
              ),
              // İsim alanı
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  child: Text(
                    magaza.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
