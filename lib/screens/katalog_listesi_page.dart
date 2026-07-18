import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/katalog.dart';
import '../theme/app_theme.dart';
import 'katalog_detay_page.dart';

enum KatalogSortOption {
  defaultNewest,
  expirySoonest,
  expiryLatest,
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

  String _getValidityText(Katalog catalog) {
    return catalog.getValidityText();
  }

  Widget _buildValidityTextRow(Katalog catalog, bool isDark) {
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

    Color textColor;
    IconData icon;

    if (today.isBefore(start)) {
      textColor = isDark ? Colors.blue[300]! : const Color(0xFF2563EB); // Blue 600
      icon = Icons.date_range;
    } else {
      final diff = expiry.difference(today).inDays;
      if (diff < 0) {
        textColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
        icon = Icons.event_busy;
      } else if (diff <= 1) {
        textColor = const Color(0xFFDC2626); // Red 600
        icon = Icons.alarm;
      } else if (diff <= 3) {
        textColor = const Color(0xFFD97706); // Orange 600
        icon = Icons.hourglass_empty;
      } else {
        textColor = isDark ? Colors.blue[300]! : const Color(0xFF2563EB); // Blue 600
        icon = Icons.event_available;
      }
    }

    return Row(
      children: [
        Icon(
          icon,
          size: 11,
          color: textColor,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _getValidityText(catalog),
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          '${widget.magazaAdi} Aktüel',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          PopupMenuButton<KatalogSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sırala',
            onSelected: (option) {
              setState(() {
                _currentSort = option;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: KatalogSortOption.defaultNewest,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 18,
                      color: _currentSort == KatalogSortOption.defaultNewest ? AppTheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Yayınlanma Tarihine Göre (Yeni)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: KatalogSortOption.expirySoonest,
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_bottom,
                      size: 18,
                      color: _currentSort == KatalogSortOption.expirySoonest ? AppTheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Süresi En Yakın Bitenler'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: KatalogSortOption.expiryLatest,
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_top,
                      size: 18,
                      color: _currentSort == KatalogSortOption.expiryLatest ? AppTheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Süresi En Geç Bitenler'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('kataloglar')
            .where('magazaKodu', isEqualTo: widget.magazaKodu)
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

          // Sort catalogs dynamically
          if (_currentSort == KatalogSortOption.defaultNewest) {
            catalogs.sort((a, b) => b.baslangicTarihi.compareTo(a.baslangicTarihi));
          } else if (_currentSort == KatalogSortOption.expirySoonest) {
            catalogs.sort((a, b) => a.bitisTarihi.compareTo(b.bitisTarihi));
          } else if (_currentSort == KatalogSortOption.expiryLatest) {
            catalogs.sort((a, b) => b.bitisTarihi.compareTo(a.bitisTarihi));
          }

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
                      '${widget.magazaAdi} için şu anda yayında olan bir kampanya broşürü bulunamadı.',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.60, // Adjusted to fit the extra status row neatly
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
            color: isDark 
                ? Colors.white.withValues(alpha: 0.08) 
                : Colors.grey[300]!,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.3) 
                  : Colors.grey.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                  height: double.infinity,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.katalogBasligi,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
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
                              fontSize: 10,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildValidityTextRow(catalog, isDark),
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
