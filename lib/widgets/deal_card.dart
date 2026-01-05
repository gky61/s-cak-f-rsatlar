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
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/profile_screen.dart';

void _log(String message) {
  if (kDebugMode) _log(message);
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

  final LinkPreviewService _linkPreviewService = LinkPreviewService();
  final AuthService _authService = AuthService();

  // Kategori ID'sini kategori adına çevir
  String _getCategoryDisplayName(String categoryIdOrName) {
    // Önce ID olarak kontrol et
    try {
      final category = Category.categories.firstWhere(
        (cat) => cat.id.toLowerCase() == categoryIdOrName.toLowerCase(),
        orElse: () => Category.categories.first, // Bulunamazsa "Tümü" döndür
      );
      return category.name;
    } catch (e) {
      // ID olarak bulunamazsa, zaten name olabilir, direkt döndür
      return categoryIdOrName;
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
    final currencyFormat = NumberFormat.currency(symbol: '₺', decimalDigits: 0);
    final isExpired = deal.isExpired;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    // View mode'a göre farklı layout
    if (widget.viewMode == CardViewMode.horizontal) {
      return _buildHorizontalCard(context, deal, currencyFormat, isExpired, isDark);
    }
    
    // HTML tasarımına göre kart yapısı (grid 2 sütun)
    return Container(
        decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F5F0), // card-bg: #F5F5F0 (daha açık kırık beyaz)
        borderRadius: BorderRadius.circular(12), // rounded-xl
          boxShadow: [
            BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
          width: 2, // border-2
        ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
          borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Görsel Container (Aspect Square)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: AspectRatio(
                  aspectRatio: 1.0, // aspect-square
            child: Stack(
              children: [
                      // Görsel
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white, // Beyaz arka plan
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                              width: 2,
                            ),
                          ),
                        ),
                        child: _effectiveImageUrl != null && _effectiveImageUrl!.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(12.0), // Kenarlardan boşluk
                                child: CachedNetworkImage(
                                  imageUrl: _effectiveImageUrl!,
                                  fit: BoxFit.contain, // Tam ürün görünsün, kırpma yok
                                  memCacheWidth: 800,
                                  memCacheHeight: 800,
                                  maxHeightDiskCache: 800,
                                  maxWidthDiskCache: 800,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.image_not_supported_rounded,
                                    color: Colors.grey[300],
                                    size: 48,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.grey[300],
                                size: 48,
                              ),
                      ),
                      // Zaman Rozeti (Sol Üst)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                      // Editör Seçimi Rozeti (Sağ Alt)
                      if (deal.isEditorPick)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange[700]!, Colors.orange[500]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      // İndirim Rozeti (Sağ Alt)
                      if (deal.discountRate != null && deal.discountRate! > 0)
                        Positioned(
                          bottom: 8,
                          right: deal.isEditorPick ? 32 : 8,
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
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getThermometerEmoji(hotVotes, coldVotes),
                                style: const TextStyle(fontSize: 14),
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
                    ],
                  ),
                ),
              ),
              // İçerik
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Mağaza ve Kullanıcı adı (aynı satırda)
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
                        // Kullanıcı adı (sadece kullanıcı paylaşımı ise, sağda)
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
                                
                                // Kullanıcı bilgisini parse et
                                final user = AppUser.fromFirestore(snapshot.data!);
                                
                                // Display name'i doğrudan Firestore'dan al
                                // Sadece username kullanıyoruz (en güncel değer)
                                final displayName = userData['username']?.toString() ?? 'Kullanıcı';
                                
                                // Key'e snapshot hash'ini ekleyerek her snapshot değişikliğinde rebuild garantisi
                                final snapshotHash = snapshot.data?.data().toString().hashCode ?? 0;
                                
                                return InkWell(
                                  key: ValueKey('user_widget_${deal.postedBy}_${displayName}_$snapshotHash'),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(userId: user.uid),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ClipOval(
                                        child: user.profileImageUrl.isNotEmpty
                                            ? CachedNetworkImage(
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
                                              )
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
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          displayName,
                                          key: ValueKey('username_text_${deal.postedBy}_$displayName'),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: primaryColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
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
                    ],
                  ),
                ),
              ),
            ],
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
  Widget _buildHorizontalCard(BuildContext context, Deal deal, NumberFormat currencyFormat, bool isExpired, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F5F0), // card-bg: #F5F5F0 (daha açık kırık beyaz)
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
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
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
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
                        _effectiveImageUrl != null && _effectiveImageUrl!.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CachedNetworkImage(
                                  imageUrl: _effectiveImageUrl!,
                                  width: 124,
                                  height: 124,
                                  fit: BoxFit.contain,
                                  memCacheWidth: 560,
                                  memCacheHeight: 560,
                                  maxHeightDiskCache: 560,
                                  maxWidthDiskCache: 560,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.image_not_supported_rounded,
                                    color: Colors.grey[300],
                                    size: 32,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.grey[300],
                                size: 32,
                              ),
                        // Editör Seçimi Rozeti (Sağ Üst)
                        if (deal.isEditorPick)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange[700]!, Colors.orange[500]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.5),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 10,
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
                            right: deal.isEditorPick ? 28 : 6,
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
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getThermometerEmoji(hotVotes, coldVotes),
                                  style: const TextStyle(fontSize: 12),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                // Sağ tarafta içerik
                Expanded(
                  child: SizedBox(
                    height: 128, // Padding için yükseklik artırıldı (112 + 16)
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
                                      ],
                                    ),
                                  ],
                                ),
                                // Kullanıcı adı (sadece kullanıcı paylaşımı ise, mağaza altında sağda)
                                if (deal.isUserSubmitted && deal.postedBy.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: StreamBuilder<DocumentSnapshot>(
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
                                          
                                          // Kullanıcı bilgisini parse et
                                          final user = AppUser.fromFirestore(snapshot.data!);
                                          
                                          // Display name'i doğrudan Firestore'dan al
                                          // Sadece username kullanıyoruz (en güncel değer)
                                          final displayName = userData['username']?.toString() ?? 'Kullanıcı';
                                          
                                          // Key'e snapshot hash'ini ekleyerek her snapshot değişikliğinde rebuild garantisi
                                          final snapshotHash2 = snapshot.data?.data().toString().hashCode ?? 0;
                                          
                                          final primaryColor = Theme.of(context).colorScheme.primary;
                                          return Padding(
                                            key: ValueKey('user_list_widget_${deal.postedBy}_${displayName}_$snapshotHash2'),
                                            padding: const EdgeInsets.only(top: 2),
                                            child: InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ProfileScreen(userId: user.uid),
                                                  ),
                                                );
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ClipOval(
                                                    child: user.profileImageUrl.isNotEmpty
                                                        ? CachedNetworkImage(
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
                                                              child: Icon(
                                                                Icons.person,
                                                                size: 9,
                                                                color: primaryColor,
                                                              ),
                                                            ),
                                                            errorWidget: (context, url, error) => Container(
                                                              width: 14,
                                                              height: 14,
                                                              color: primaryColor.withOpacity(0.1),
                                                              child: Icon(
                                                                Icons.person,
                                                                size: 9,
                                                                color: primaryColor,
                                                              ),
                                                            ),
                                                          )
                                                        : Container(
                                                            width: 14,
                                                            height: 14,
                                                            decoration: BoxDecoration(
                                                              color: primaryColor.withOpacity(0.1),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(
                                                              Icons.person,
                                                              size: 9,
                                                              color: primaryColor,
                                                            ),
                                                          ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      displayName,
                                                      key: ValueKey('username_list_text_${deal.postedBy}_$displayName'),
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w500,
                                                        color: primaryColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          _log('Kullanıcı bilgisi yükleme hatası: $e');
                                          return const SizedBox.shrink();
                                        }
                                      },
                                    ),
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
                        // Alt kısım: Fiyat ve Buton (aynı hizada)
                        Padding(
                          padding: const EdgeInsets.only(top: 16), // Daha aşağıya çek
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center, // Fiyat ile aynı hizada
                            children: [
                            // Fiyat
                            Column(
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
                                    fontSize: 18,
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
                            // İncele Butonu (fiyatla aynı hizada)
                            ElevatedButton(
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
                              child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                    'İncele',
                                        style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_outward,
                                    size: 16,
                                    color: Colors.white,
                                ),
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
