import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/deal.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';

class DealCard extends StatefulWidget {
  final Deal deal;
  final VoidCallback? onTap;

  const DealCard({
    super.key,
    required this.deal,
    this.onTap,
  });

  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  bool _isPressed = false;
  String? _effectiveImageUrl;
  bool _isLoadingImage = false;
  bool _imageLoadAttempted = false; // Görsel yükleme denemesi yapıldı mı?

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final LinkPreviewService _linkPreviewService = LinkPreviewService();

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  @override
  void didUpdateWidget(DealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Deal değiştiyse görseli yeniden kontrol et
    if (oldWidget.deal.id != widget.deal.id || oldWidget.deal.imageUrl != widget.deal.imageUrl) {
      _checkImage();
    }
  }
    
  void _checkImage() {
    final dealImageUrl = widget.deal.imageUrl.trim();
    final isBlobUrl = dealImageUrl.startsWith('blob:');
    
    if (isBlobUrl) {
      _effectiveImageUrl = null;
    } else {
      _effectiveImageUrl = dealImageUrl.isNotEmpty ? dealImageUrl : null;
    }
    
    // Sadece bir kez deneme yap
    if (!_imageLoadAttempted && (_effectiveImageUrl == null || isBlobUrl) && widget.deal.link.isNotEmpty) {
      _imageLoadAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadImageFromLink();
      });
    }
  }
  
  Future<void> _loadImageFromLink() async {
    if (_isLoadingImage || !mounted) return;
    if (widget.deal.link.isEmpty) return;

    // setState'i minimize et - sadece görsel değiştiğinde çağır
    _isLoadingImage = true;

    try {
      final preview = await _linkPreviewService.fetchMetadata(widget.deal.link)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      
      if (mounted && preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty) {
        // Görsel bulundu, setState ile güncelle
        if (mounted) {
          setState(() {
            _effectiveImageUrl = preview.imageUrl;
            _isLoadingImage = false;
          });
        }
      } else if (mounted) {
        // Görsel bulunamadı, sessizce bitir
        _isLoadingImage = false;
      }
    } catch (e) {
      // Hata durumunda sessizce bitir, kartı kaybetme
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
    
    final Border? highlightBorder = isExpired
        ? Border.all(color: Colors.red[300]!, width: 2)
        : deal.isEditorPick
            ? Border.all(color: Colors.orange[200]!, width: 2)
            : null;
    
    final borderColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFD5DAE2);
    final Border defaultBorder = Border.all(
      color: borderColor,
      width: 1.2,
    );
    
    final cardBackgroundColor = isDark
        ? (isExpired ? Colors.red[900]!.withOpacity(0.2) : AppTheme.darkSurface)
        : (isExpired ? Colors.red[50] : const Color(0xFFFBFCFE));

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: highlightBorder ?? defaultBorder,
          boxShadow: [
            BoxShadow(
              color: isExpired
                  ? Colors.red.withOpacity(0.1)
                  : deal.isEditorPick
                      ? Colors.orange.withOpacity(0.15)
                      : (isDark 
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.03)),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _isPressed = v),
            child: Stack(
              children: [
                if (isExpired)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.red.withOpacity(0.05),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. GÖRSEL (Kare ve Sol Tarafta)
                        Stack(
                          children: [
                            Hero(
                              tag: 'deal_${deal.id}_image',
                              child: Opacity(
                                opacity: isExpired ? 0.5 : 1.0,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _effectiveImageUrl != null && _effectiveImageUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: _effectiveImageUrl!,
                                            fit: BoxFit.contain,
                                            placeholder: (context, url) => Container(
                                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                                              child: Icon(
                                                Icons.image_not_supported_rounded,
                                                color: isDark ? Colors.grey[600] : Colors.grey[300],
                                                size: 32,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                                            child: Icon(
                                              Icons.image_not_supported_rounded,
                                              color: isDark ? Colors.grey[600] : Colors.grey[300],
                                              size: 32,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            // İndirim Rozeti (Sol Üst)
                            if (deal.discountRate != null && deal.discountRate! > 0)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.error,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    '%${deal.discountRate}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // 2. İÇERİK (Sağ Taraf)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                          // Üst Bilgi: Kategori ve Mağaza
                          Opacity(
                            opacity: isExpired ? 0.6 : 1.0,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isExpired) ...[
                                  const SizedBox(width: 6),
                                  _buildExpiredBadge(inline: true),
                                ],
                                const Spacer(),
                                Text(
                                  _formatRelativeTime(deal.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 2),
                          
                          // Başlık
                          Opacity(
                            opacity: isExpired ? 0.6 : 1.0,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    deal.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      color: isExpired 
                                          ? Colors.red[700] 
                                          : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Fiyat Alanı
                          Opacity(
                            opacity: isExpired ? 0.6 : 1.0,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (deal.originalPrice != null && deal.originalPrice! > deal.price)
                                      Text(
                                        currencyFormat.format(deal.originalPrice),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    Text(
                                      currencyFormat.format(deal.price),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isExpired ? Colors.red[700] : AppTheme.primary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                
                                // Sıcaklık Göstergesi (Mini)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (deal.hotVotes - deal.coldVotes) >= 0 
                                        ? AppTheme.primary.withOpacity(isDark ? 0.2 : 0.1)
                                        : Colors.blue.withOpacity(isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        (deal.hotVotes - deal.coldVotes) >= 0 
                                            ? Icons.whatshot_rounded 
                                            : Icons.ac_unit_rounded,
                                        size: 14,
                                        color: (deal.hotVotes - deal.coldVotes) >= 0 
                                            ? AppTheme.primary
                                            : Colors.blue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${deal.hotVotes - deal.coldVotes}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: (deal.hotVotes - deal.coldVotes) >= 0 
                                              ? AppTheme.primary
                                              : Colors.blue,
                                        ),
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

  Widget _buildExpiredBadge({bool inline = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: inline ? 8 : 10,
        vertical: inline ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: inline ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.red[200]!),
        boxShadow: [
          if (!inline)
            BoxShadow(
              color: Colors.red.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_disabled_rounded,
            size: inline ? 12 : 14,
            color: Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            'Bitti',
            style: TextStyle(
              fontSize: inline ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: Colors.red,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Şimdi';
    if (difference.inMinutes < 60) return '${difference.inMinutes}dk';
    if (difference.inHours < 24) return '${difference.inHours}sa';
    return DateFormat('d MMM').format(date);
  }
}
