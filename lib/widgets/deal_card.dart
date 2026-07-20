import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/deal.dart';
import '../models/category.dart';
import '../models/user.dart';
import '../services/link_preview_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../screens/profile_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class DealCard extends StatefulWidget {
  final Deal deal;
  final VoidCallback? onTap;
  final CardViewMode viewMode;

  const DealCard({
    super.key,
    required this.deal,
    this.onTap,
    this.viewMode = CardViewMode.vertical,
  });

  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  String? _effectiveImageUrl;
  bool _isLoadingImage = false;
  bool _imageLoadAttempted = false;
  bool _showVoteCount = false; // Oy sayısını göster/gizle

  final LinkPreviewService _linkPreviewService = LinkPreviewService();

  String _getStoreAsset(String storeName) {
    final lower = storeName.toLowerCase().trim();
    if (lower.contains('trendyol')) return 'assets/trendyol.jpg';
    if (lower.contains('hepsiburada')) return 'assets/hepsiburada.jpg';
    if (lower.contains('n11')) return 'assets/n11.jpg';
    if (lower.contains('amazon')) return 'assets/amazon.jpg';
    if (lower.contains('pazarama')) return 'assets/pazarama.jpg';
    if (lower.contains('vatan')) return 'assets/vatan.jpg';
    if (lower.contains('mediamarkt') || lower.contains('media markt')) return 'assets/mediamarkt.jpg';
    if (lower.contains('incehesap') || lower.contains('ince hesap')) return 'assets/incehesap.jpg';
    if (lower.contains('itopya')) return 'assets/itopya.jpg';
    if (lower.contains('pttavm') || lower.contains('ptt avm')) return 'assets/pttavm.jpg';
    if (lower.contains('teknosa')) return 'assets/teknosa.jpg';
    if (lower.contains('zara')) return 'assets/zara.jpg';
    if (lower.contains('mango')) return 'assets/mango.jpg';
    if (lower.contains('mavi')) return 'assets/mavi.jpg';
    if (lower.contains('defacto')) return 'assets/defacto.jpg';
    if (lower.contains('beymen')) return 'assets/beymen.jpg';
    if (lower.contains('idefix')) return 'assets/idefix.jpg';
    if (lower.contains('havit')) return 'assets/havit.jpg';
    if (lower.contains('migros')) return 'assets/migros.jpg';
    if (lower.contains('getir')) return 'assets/getir.jpg';
    return 'assets/logo.jpg';
  }
  void _handleOnTap() {
    if (widget.deal.isExpired) {
      _showExpiredBottomSheet(context, widget.deal);
    } else {
      widget.onTap?.call();
    }
  }

  void _showExpiredBottomSheet(BuildContext context, Deal deal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle Indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Warning Icon Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50] ?? const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timer_off_rounded,
                  size: 40,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Fırsat Süresi Doldu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                'Aradığınız fırsat yayından kaldırılmış veya silinmiş olabilir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              // Action Buttons
              Row(
                children: [
                  // Close Button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Kapat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Go to Store Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openProductLink(deal.link);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Şansını Dene / Mağazaya Git',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_outward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  // Kategori ID'sini kategori adına çevir
  String _getCategoryDisplayName(String categoryIdOrName) {
    if (categoryIdOrName.isEmpty) {
      return 'Genel';
    }
    
    // Önce ID olarak kontrol et (case-insensitive)
    final categoryIdLower = categoryIdOrName.toLowerCase().trim();
    
    // "diğer" -> "diger" dönüşümü (eski bot formatı için)
    final normalizedId = categoryIdLower == 'diğer' ? 'diger' : categoryIdLower;
    
    try {
      final category = Category.categories.firstWhere(
        (cat) => cat.id.toLowerCase() == normalizedId,
        orElse: () => Category.categories.first, // Bulunamazsa "Tümü" döndür
      );
      return category.name;
    } catch (e) {
      // ID olarak bulunamazsa, name olarak kontrol et
      try {
        final category = Category.categories.firstWhere(
          (cat) => cat.name.toLowerCase() == categoryIdOrName.toLowerCase(),
          orElse: () => Category.categories.first,
        );
        return category.name;
      } catch (e2) {
        // Hiçbiri bulunamazsa, direkt döndür (eski format için)
        return categoryIdOrName;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  @override
  void didUpdateWidget(DealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.id != widget.deal.id || oldWidget.deal.imageUrl != widget.deal.imageUrl) {
      _checkImage();
      // Deal değiştiğinde oy sayısı gösterimini sıfırla
      _showVoteCount = false;
    }
  }
    
  void _checkImage() async {
    final dealImageUrl = widget.deal.imageUrl.trim();
    final isBlobUrl = dealImageUrl.startsWith('blob:');
    
    if (isBlobUrl) {
      _effectiveImageUrl = null;
    } else {
      _effectiveImageUrl = dealImageUrl.isNotEmpty ? dealImageUrl : null;
    }
    
    if (!_imageLoadAttempted && (_effectiveImageUrl == null || isBlobUrl) && widget.deal.link.isNotEmpty) {
      _imageLoadAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadImageFromLink();
      });
    }
  }
  
  Future<void> _loadImageFromLink() async {
    if (_isLoadingImage || !mounted) return;
    final link = widget.deal.link.trim();
    if (link.isEmpty) return;

    // --- AMAZON ÖZEL KONTROLÜ BAŞLANGIÇ ---
    // Amazon linki mi? (Hem kısa hem uzun hem mobil linkleri kapsar)
    if (link.contains("amazon") || link.contains("amzn")) {
      final amazonImage = await _linkPreviewService.getAmazonImageSmart(link);
      
      if (amazonImage != null && mounted) {
        _log('✅ DealCard: Amazon görsel bulundu (ASIN yöntemi): $amazonImage');
        setState(() {
          _effectiveImageUrl = amazonImage;
          _isLoadingImage = false;
        });
        return; // Amazon görseli bulundu, scraper'a gerek yok
      } else {
        _log('⚠️ DealCard: Amazon ASIN bulunamadı, normal scraper yöntemi deneniyor...');
      }
    }
    // --- AMAZON ÖZEL KONTROLÜ BİTİŞ ---

    _isLoadingImage = true;

    try {
      final preview = await _linkPreviewService.fetchMetadata(link)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      
      if (mounted && preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _effectiveImageUrl = preview.imageUrl;
            _isLoadingImage = false;
          });
        }
      } else if (mounted) {
        _isLoadingImage = false;
      }
    } catch (e) {
      if (mounted) {
        _isLoadingImage = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final currencyFormat = DynamicCurrencyFormatter();
    final isExpired = deal.isExpired;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    // View mode'a göre farklı layout
    if (widget.viewMode == CardViewMode.horizontal) {
      return Opacity(
        opacity: isExpired ? 0.5 : 1.0,
        child: _buildHorizontalCard(context, deal, currencyFormat, isExpired, isDark),
      );
    }
    
    // HTML tasarımına göre kart yapısı (grid 2 sütun)
    return Opacity(
      opacity: isExpired ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: deal.isEditorPick 
                ? Colors.orange[600]! // Editör seçimi için turuncu çerçeve
                : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08)),
            width: deal.isEditorPick ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _handleOnTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Görsel Container (Aspect Square yerine modern dikdörtgen)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: AspectRatio(
                    aspectRatio: (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ? 1.25 : 1.05, // dynamic aspect ratio to eliminate extra whitespace at bottom
                    child: Stack(
                      children: [
                        // Görsel
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white, // Beyaz arka plan
                          ),
                          child: (isExpired || _effectiveImageUrl == null || _effectiveImageUrl!.isEmpty)
                              ? Image.asset(_getStoreAsset(deal.store), fit: BoxFit.contain)
                              : Padding(
                                  padding: const EdgeInsets.all(8.0), // Elegant floating padding
                                  child: CachedNetworkImage(
                                    imageUrl: _effectiveImageUrl!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                    memCacheWidth: 800,
                                    memCacheHeight: 800,
                                    maxHeightDiskCache: 800,
                                    maxWidthDiskCache: 800,
                                    fadeInDuration: const Duration(milliseconds: 250),
                                    fadeOutDuration: const Duration(milliseconds: 100),
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[50],
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (context, url, error) => Image.asset(
                                      _getStoreAsset(deal.store),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                        ),
                        // Zaman Rozeti (Sol Üst)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 8,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatRelativeTime(deal.createdAt),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // İndirim Rozeti (Sağ Alt)
                      if (deal.discountRate != null && deal.discountRate! > 0)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '%${deal.discountRate}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      // 🔥 Fırsat Termometresi Emoji (Sol Alt) - Gerçek Zamanlı
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('deals')
                              .doc(deal.id)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int hotVotes = deal.hotVotes;
                            int coldVotes = deal.coldVotes;
                            
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>?;
                              hotVotes = data?['hotVotes'] ?? deal.hotVotes;
                              coldVotes = data?['coldVotes'] ?? deal.coldVotes;
                            }
                            
                            final totalVotes = hotVotes + coldVotes;
                            if (totalVotes == 0) return const SizedBox.shrink();
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showVoteCount = true;
                                });
                                // 2 saniye sonra emoji'ye geri dön
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (mounted) {
                                    setState(() {
                                      _showVoteCount = false;
                                    });
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: _showVoteCount
                                    ? Text(
                                        '$totalVotes',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _getThermometerEmoji(hotVotes, coldVotes),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Favorite ve Comment Rozeti (Sağ Üst - Glassmorphism)
                      Positioned(
                        top: 8,
                        right: 8,
                    child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.black.withOpacity(0.6) 
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark 
                                  ? Colors.white.withOpacity(0.1) 
                                  : Colors.grey[200]!.withOpacity(0.5),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite,
                                size: 10,
                                color: Colors.red[500],
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${deal.hotVotes}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                    ),
                  ),
                              Container(
                                width: 0.5,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                color: isDark 
                                    ? Colors.white.withOpacity(0.2) 
                                    : Colors.grey[300],
                              ),
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 10,
                                color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${deal.commentCount}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // SÜRESİ DOLDU Overlay
                      if (isExpired)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.4),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.red[700],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SÜRESİ DOLDU',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // İçerik
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 8, 10, (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ? 6 : 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Mağaza adı ve Paylaşan Kullanıcı Avatarı (aynı satırda)
                    Row(
                      children: [
                        Icon(
                          Icons.storefront,
                          size: 11,
                          color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Sadece Profil Resmi (sadece kullanıcı paylaşımı ise, sağda)
                        if (deal.isUserSubmitted && deal.postedBy.isNotEmpty)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(deal.postedBy)
                                .snapshots(includeMetadataChanges: false),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }
                              
                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                return const SizedBox.shrink();
                              }
                              
                              try {
                                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                if (userData == null) {
                                  return const SizedBox.shrink();
                                }
                                
                                final user = AppUser.fromFirestore(snapshot.data!);
                                final displayName = userData['username']?.toString() ?? 'Kullanıcı';
                                final snapshotHash = snapshot.data?.data().toString().hashCode ?? 0;
                                
                                return InkWell(
                                  key: ValueKey('user_avatar_widget_${deal.postedBy}_${displayName}_$snapshotHash'),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(userId: user.uid),
                                      ),
                                    );
                                  },
                                  child: ClipOval(
                                    child: user.profileImageUrl.isNotEmpty
                                        ? (user.profileImageUrl.startsWith('assets/')
                                            ? Image.asset(
                                                user.profileImageUrl,
                                                width: 16,
                                                height: 16,
                                                fit: BoxFit.cover,
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: user.profileImageUrl,
                                                width: 16,
                                                height: 16,
                                                fit: BoxFit.cover,
                                                memCacheWidth: 32,
                                                memCacheHeight: 32,
                                                fadeInDuration: const Duration(milliseconds: 200),
                                                placeholder: (context, url) => Container(
                                                  width: 16,
                                                  height: 16,
                                                  color: primaryColor.withOpacity(0.1),
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 10,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  width: 16,
                                                  height: 16,
                                                  color: primaryColor.withOpacity(0.1),
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 10,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ))
                                        : Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              size: 10,
                                              color: primaryColor,
                                            ),
                                          ),
                                  ),
                                );
                              } catch (e) {
                                _log('Kullanıcı bilgisi yükleme hatası: $e');
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Başlık
                    Stack(
                      children: [
                        Text(
                          deal.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: (isExpired || deal.expiredVotes >= 15)
                                ? Colors.red[700] 
                                : (isDark ? Colors.white : AppTheme.textPrimary),
                          ),
                        ),
                        // Kırmızı çizgi (expiredVotes >= 15 veya isExpired ise)
                        if (isExpired || deal.expiredVotes >= 15)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _StrikeThroughPainter(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Fiyat
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            currencyFormat.format(deal.price),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isExpired 
                                  ? Colors.red[700] 
                                  : AppTheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (deal.originalPrice != null && deal.originalPrice! > deal.price) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              currencyFormat.format(deal.originalPrice),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.grey[500] : AppTheme.textSecondary,
                                decoration: TextDecoration.lineThrough,
                                decorationThickness: 1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ...[
                      const SizedBox(height: 6), // Increased spacing between price and label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0), // Soft orange amber container
                          borderRadius: BorderRadius.circular(6), // Rounded pill shape
                          border: Border.all(
                            color: const Color(0xFFFFB74D).withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          deal.priceLabel!,
                          style: const TextStyle(
                            fontSize: 10.5, // Font size bumped from 9 to 10.5 to stand out
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.1,
                            color: Color(0xFFE65100), // Clean deep orange tone
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    ],
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

  /// 🔥 Fırsat Termometresi Emoji'sini hesapla
  String _getThermometerEmoji(int hotVotes, int coldVotes) {
    final totalVotes = hotVotes + coldVotes;
    if (totalVotes == 0) return '🤷';
    
    final hotPercentage = (hotVotes / totalVotes * 100).round();
    
    if (hotPercentage >= 80) return '🔥';  // Efsane fırsat
    if (hotPercentage >= 60) return '👍';  // İyi fırsat
    if (hotPercentage >= 40) return '🤔';  // Eh işte
    if (hotPercentage >= 20) return '😬';  // Pek değil
    return '🥶';  // Kötü fırsat
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Şimdi';
    if (difference.inMinutes < 60) return '${difference.inMinutes} dakika önce';
    if (difference.inHours < 24) return '${difference.inHours} saat önce';
    if (difference.inDays == 1) return 'Dün';
    if (difference.inDays < 7) return '${difference.inDays} gün önce';
    return DateFormat('d MMM').format(date);
  }

  Future<void> _openProductLink(String url) async {
    if (url.isEmpty) return;
    
    try {
      // URL'yi düzelt - http:// veya https:// yoksa ekle
      String cleanUrl = url.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      final uri = Uri.parse(cleanUrl);
      
      // canLaunchUrl kontrolü yapmadan direkt dene - daha güvenilir
      try {
        // Önce external application ile dene
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (e) {
        // External başarısız, devam et
      }
      
      // External başarısız olduysa platform default dene
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (launched) return;
      } catch (e) {
        // Platform default da başarısız
      }
      
      // Son çare: inAppWebView (eğer destekleniyorsa)
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );
      } catch (e) {
        // Tüm yöntemler başarısız oldu
        throw Exception('Bağlantı açılamadı');
      }
    } catch (e) {
      _log('❌ URL açma hatası: $e');
      _log('❌ URL: $url');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı açılamadı: ${e.toString()}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Horizontal kart layout'u (HTML'deki yeni tasarım)
  Widget _buildHorizontalCard(BuildContext context, Deal deal, DynamicCurrencyFormatter currencyFormat, bool isExpired, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final inceleButton = ElevatedButton(
      onPressed: () => _openProductLink(deal.link),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999), // rounded-full
        ),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isExpired ? 'Şansını Dene' : 'İncele',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_outward,
            size: 16,
            color: Colors.white,
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: deal.isEditorPick 
              ? Colors.orange[600]! // Editör seçimi için turuncu çerçeve
              : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08)),
          width: deal.isEditorPick ? 1.5 : 1, // Tutarlı kalınlık
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleOnTap,
          child: Padding(
            padding: const EdgeInsets.all(10), // p-2.5
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // Sol tarafta görsel - Daha büyük ve kaliteli (140x140px)
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white, // Beyaz arka plan
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Beyaz arka plan
                        Container(
                          width: 140,
                          height: 140,
                          color: Colors.white,
                        ),
                        // Görsel
                        (isExpired || _effectiveImageUrl == null || _effectiveImageUrl!.isEmpty)
                            ? Image.asset(_getStoreAsset(deal.store), width: double.infinity, height: double.infinity, fit: BoxFit.contain)
                            : Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: CachedNetworkImage(
                                  imageUrl: _effectiveImageUrl!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                  memCacheWidth: 1000,
                                  memCacheHeight: 1000,
                                  maxHeightDiskCache: 1000,
                                  maxWidthDiskCache: 1000,
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  fadeOutDuration: const Duration(milliseconds: 100),
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[100],
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (context, url, error) => Image.asset(
                                    _getStoreAsset(deal.store),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                        // Zaman Rozeti (Sol Alt)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 9,
                                  color: Colors.white,
                                  ),
                                const SizedBox(width: 2),
                                Text(
                                  _formatRelativeTime(deal.createdAt),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                        // İndirim Rozeti (Sağ Alt)
                        if (deal.discountRate != null && deal.discountRate! > 0)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.trending_down,
                                    size: 10,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '%${deal.discountRate}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // 🔥 Fırsat Termometresi Emoji (Sağ Alt) - Gerçek Zamanlı
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('deals')
                                .doc(deal.id)
                                .snapshots(),
                            builder: (context, snapshot) {
                              int hotVotes = deal.hotVotes;
                              int coldVotes = deal.coldVotes;
                              
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final data = snapshot.data!.data() as Map<String, dynamic>?;
                                hotVotes = data?['hotVotes'] ?? deal.hotVotes;
                                coldVotes = data?['coldVotes'] ?? deal.coldVotes;
                              }
                              
                              final totalVotes = hotVotes + coldVotes;
                              if (totalVotes == 0) return const SizedBox.shrink();
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showVoteCount = true;
                                  });
                                  // 2 saniye sonra emoji'ye geri dön
                                  Future.delayed(const Duration(seconds: 2), () {
                                    if (mounted) {
                                      setState(() {
                                        _showVoteCount = false;
                                      });
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: _showVoteCount
                                      ? Text(
                                          '$totalVotes',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _getThermometerEmoji(hotVotes, coldVotes),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Favorite ve Comment Rozeti (Sağ Üst - Glassmorphism)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.black.withOpacity(0.6) 
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark 
                                    ? Colors.white.withOpacity(0.1) 
                                    : Colors.grey[200]!.withOpacity(0.5),
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 9,
                                  color: Colors.red[500],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${deal.hotVotes}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Container(
                                  width: 0.5,
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  color: isDark 
                                      ? Colors.white.withOpacity(0.2) 
                                      : Colors.grey[300],
                                ),
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 9,
                                  color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${deal.commentCount}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // SÜRESİ DOLDU Overlay
                        if (isExpired)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.4),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.red[700],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SÜRESİ DOLDU',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                // Sağ tarafta içerik
                Expanded(
                  child: SizedBox(
                    height: 140, // Height matched with the 140x140 image container
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Üst kısım: Kategori, Mağaza ve Başlık
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kategori ve Mağaza
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _getCategoryDisplayName(deal.category),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.storefront,
                                          size: 12,
                                          color: isDark ? Colors.grey[300] : AppTheme.textPrimary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.grey[300] : AppTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Sadece Profil Resmi (sadece kullanıcı paylaşımı ise, sağda)
                                        if (deal.isUserSubmitted && deal.postedBy.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          StreamBuilder<DocumentSnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(deal.postedBy)
                                                .snapshots(includeMetadataChanges: false),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const SizedBox.shrink();
                                              }
                                              
                                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                                return const SizedBox.shrink();
                                              }
                                              
                                              try {
                                                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                                if (userData == null) {
                                                  return const SizedBox.shrink();
                                                }
                                                
                                                final user = AppUser.fromFirestore(snapshot.data!);
                                                final displayName = userData['username']?.toString() ?? 'Kullanıcı';
                                                final snapshotHash2 = snapshot.data?.data().toString().hashCode ?? 0;
                                                
                                                final primaryColor = Theme.of(context).colorScheme.primary;
                                                return InkWell(
                                                  key: ValueKey('user_avatar_list_widget_${deal.postedBy}_${displayName}_$snapshotHash2'),
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => ProfileScreen(userId: user.uid),
                                                      ),
                                                    );
                                                  },
                                                  child: ClipOval(
                                                    child: user.profileImageUrl.isNotEmpty
                                                        ? (user.profileImageUrl.startsWith('assets/')
                                                            ? Image.asset(
                                                                user.profileImageUrl,
                                                                width: 14,
                                                                height: 14,
                                                                fit: BoxFit.cover,
                                                              )
                                                            : CachedNetworkImage(
                                                                imageUrl: user.profileImageUrl,
                                                                width: 14,
                                                                height: 14,
                                                                fit: BoxFit.cover,
                                                                memCacheWidth: 28,
                                                                memCacheHeight: 28,
                                                                fadeInDuration: const Duration(milliseconds: 200),
                                                                placeholder: (context, url) => Container(
                                                                  width: 14,
                                                                  height: 14,
                                                                  color: primaryColor.withOpacity(0.1),
                                                                  child: Icon(Icons.person, size: 9, color: primaryColor),
                                                                ),
                                                                errorWidget: (context, url, error) => Container(
                                                                  width: 14,
                                                                  height: 14,
                                                                  color: primaryColor.withOpacity(0.1),
                                                                  child: Icon(Icons.person, size: 9, color: primaryColor),
                                                                ),
                                                              ))
                                                        : Container(
                                                            width: 14,
                                                            height: 14,
                                                            decoration: BoxDecoration(
                                                              color: primaryColor.withOpacity(0.1),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(Icons.person, size: 9, color: primaryColor),
                                                          ),
                                                  ),
                                                );
                                              } catch (e) {
                                                _log('Kullanıcı bilgisi yükleme hatası: $e');
                                                return const SizedBox.shrink();
                                              }
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Başlık
                            Stack(
                              children: [
                                Text(
                                  deal.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                    color: (isExpired || deal.expiredVotes >= 15)
                                        ? Colors.red[700] 
                                        : (isDark ? Colors.white : AppTheme.textPrimary),
                                  ),
                                ),
                                // Kırmızı çizgi (expiredVotes >= 15 veya isExpired ise)
                                if (isExpired || deal.expiredVotes >= 15)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _StrikeThroughPainter(),
                                    ),
                                  ),
                              ],
                            ),
                              ],
                            ),
                        // Alt kısım: Fiyat ve Buton (Ortak Düzen)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Kampanya açıklaması varsa üstte gösterilir
                              if (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0), // Soft orange amber container
                                    borderRadius: BorderRadius.circular(6), // Rounded pill shape
                                    border: Border.all(
                                      color: const Color(0xFFFFB74D).withOpacity(0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    deal.priceLabel!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.1,
                                      color: Color(0xFFE65100), // Clean deep orange tone
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 8), // Kampanya açıklaması ile fiyat/buton arası boşluk
                              ],
                              // Fiyat ve İncele butonu daima aynı row'da ve dikeyde ortalıdır
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center, // Tam dikey hizalama
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (deal.originalPrice != null && deal.originalPrice! > deal.price)
                                          Text(
                                            currencyFormat.format(deal.originalPrice),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.grey[500] : AppTheme.textSecondary,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        Text(
                                          currencyFormat.format(deal.price),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: isExpired
                                                ? Colors.red[700]
                                                : AppTheme.primary,
                                            letterSpacing: -0.5,
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  inceleButton,
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

// Kırmızı çizgi çizmek için CustomPainter
class _StrikeThroughPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Metnin ortasından geçen kırmızı çizgi
    final startPoint = Offset(0, size.height / 2);
    final endPoint = Offset(size.width, size.height / 2);
    canvas.drawLine(startPoint, endPoint, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
