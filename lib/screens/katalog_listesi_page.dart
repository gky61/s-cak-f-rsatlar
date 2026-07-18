import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/katalog.dart';
import '../theme/app_theme.dart';
import 'katalog_detay_page.dart';

class KatalogListesiPage extends StatelessWidget {
  final String magazaKodu;
  final String magazaAdi;

  const KatalogListesiPage({
    super.key,
    required this.magazaKodu,
    required this.magazaAdi,
  });

  String _formatDateRange(DateTime start, DateTime end) {
    try {
      final startStr = DateFormat('d MMMM', 'tr_TR').format(start);
      final endStr = DateFormat('d MMMM yyyy', 'tr_TR').format(end);
      return '$startStr - $endStr';
    } catch (e) {
      return '${start.day}.${start.month} - ${end.day}.${end.month}.${end.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          '$magazaAdi Katalogları',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('kataloglar')
            .where('magazaKodu', isEqualTo: magazaKodu)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Bir hata oluştu: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // Parse and filter in memory to avoid requiring complex composite indexes in Firestore
          final now = DateTime.now();
          final catalogs = snapshot.data?.docs
                  .map((doc) => Katalog.fromFirestore(doc))
                  .where((catalog) => 
                      catalog.bitisTarihi.isAfter(now) || 
                      catalog.bitisTarihi.year == now.year && 
                      catalog.bitisTarihi.month == now.month && 
                      catalog.bitisTarihi.day == now.day)
                  .toList() ?? [];

          // Sort by start date descending
          catalogs.sort((a, b) => b.baslangicTarihi.compareTo(a.baslangicTarihi));

          if (catalogs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 80,
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aktif Katalog Bulunmuyor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      '$magazaAdi için şu anda yayında olan bir kampanya broşürü bulunamadı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.65,
            ),
            itemCount: catalogs.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final catalog = catalogs[index];
              return _buildCatalogCard(context, catalog, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildCatalogCard(BuildContext context, Katalog catalog, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KatalogDetayPage(catalog: catalog),
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
                  : Colors.grey.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: isDark ? AppTheme.darkBackground : const Color(0xFFF0F2F5),
                  child: CachedNetworkImage(
                    imageUrl: catalog.kapakResmi,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                  ),
                ),
              ),
              // Content Info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.katalogBasligi,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDateRange(catalog.baslangicTarihi, catalog.bitisTarihi),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
