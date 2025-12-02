import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/deal.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';

class DealCard extends StatefulWidget {
  final Deal deal;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDeleteButton;
  final String viewMode; // 'list', 'grid', 'compact', 'small_list'

  const DealCard({
    super.key,
    required this.deal,
    this.onTap,
    this.onDelete,
    this.showDeleteButton = false,
    this.viewMode = 'list',
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
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      
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
    
    // Farklı görünüm modları için farklı layout'lar
    if (widget.viewMode == 'grid') {
      return _buildGridCard(deal, currencyFormat, isExpired, isDark);
    } else if (widget.viewMode == 'compact') {
      return _buildCompactCard(deal, currencyFormat, isExpired, isDark);
    } else if (widget.viewMode == 'small_list') {
      return _buildSmallListCard(deal, currencyFormat, isExpired, isDark);
    } else {
      return _buildListCard(deal, currencyFormat, isExpired, isDark);
    }
  }
  
  Widget _buildListCard(Deal deal, NumberFormat currencyFormat, bool isExpired, bool isDark) {
    
    final Border? highlightBorder = isExpired
        ? Border.all(color: Colors.red[400]!, width: 2.5)
        : deal.isEditorPick
            ? Border.all(color: Colors.orange[400]!, width: 2.5)
            : null;
    
    final borderColor = isDark 
        ? const Color(0xFF404040)  // Daha belirgin koyu mod border
        : const Color(0xFFC0C8D0); // Daha belirgin açık mod border
    final Border defaultBorder = Border.all(
      color: borderColor,
      width: 2.0, // 1.2'den 2.0'a çıkarıldı
    );
    
    final cardBackgroundColor = isDark
        ? (isExpired ? Colors.red[900]!.withOpacity(0.2) : AppTheme.darkSurface)
        : (isExpired ? Colors.red[50] : const Color(0xFFFBFCFE));

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 3), // Kartlar arası mesafe
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: highlightBorder ?? defaultBorder,
          boxShadow: [
            BoxShadow(
              color: isExpired
                  ? Colors.red.withValues(alpha: 0.15)
                  : deal.isEditorPick
                      ? Colors.orange.withValues(alpha: 0.2)
                      : (isDark 
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.08)),
              blurRadius: 12,
              offset: const Offset(0, 3),
              spreadRadius: 0.5,
            ),
            // İkinci shadow katmanı - daha yumuşak derinlik efekti
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
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
                // Admin silme butonu (sağ üst köşe)
                if (widget.showDeleteButton && widget.onDelete != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: SizedBox(
                    height: 90,
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
                                  width: 90,
                                  height: 90,
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
                                            memCacheWidth: 400, // Performans için cache boyutu
                                            memCacheHeight: 400,
                                            fadeInDuration: const Duration(milliseconds: 200),
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
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          // Üst Bilgi: Kategori ve Zaman
                          Row(
                            children: [
                              if (isExpired) ...[
                                _buildExpiredBadge(inline: true),
                                const SizedBox(width: 6),
                              ],
                              const Spacer(),
                              Text(
                                _formatRelativeTime(deal.createdAt),
                                key: ValueKey('time_${deal.id}'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isExpired 
                                      ? (isDark ? Colors.grey[400]!.withOpacity(0.6) : Colors.grey[500]!.withOpacity(0.6))
                                      : (isDark ? Colors.grey[300] : Colors.grey[600]),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          
                          // Başlık
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  deal.title,
                                  key: ValueKey('title_${deal.id}'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    color: isExpired 
                                        ? Colors.red[700]!.withOpacity(0.6)
                                        : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Fiyat Alanı
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (deal.originalPrice != null && deal.originalPrice! > deal.price)
                                    Text(
                                      currencyFormat.format(deal.originalPrice),
                                      key: ValueKey('originalPrice_${deal.id}'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isExpired
                                            ? (isDark ? AppTheme.darkTextSecondary.withOpacity(0.6) : AppTheme.textSecondary.withOpacity(0.6))
                                            : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  Text(
                                    currencyFormat.format(deal.price),
                                    key: ValueKey('price_${deal.id}'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isExpired ? Colors.red[700]!.withOpacity(0.6) : AppTheme.primary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              
                              // Mağaza ve Sıcaklık Göstergesi
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: _buildStoreWidget(deal.store, isDark),
                                  ),
                                  const SizedBox(width: 6),
                                  // Sıcaklık Göstergesi (Mini)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                                          key: ValueKey('votes_${deal.id}'),
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

  Widget _buildGridCard(Deal deal, NumberFormat currencyFormat, bool isExpired, bool isDark) {
    final Border? highlightBorder = isExpired
        ? Border.all(color: Colors.red[400]!, width: 2.5)
        : deal.isEditorPick
            ? Border.all(color: Colors.orange[400]!, width: 2.5)
            : null;
    
    final borderColor = isDark 
        ? const Color(0xFF404040)
        : const Color(0xFFC0C8D0);
    final Border defaultBorder = Border.all(
      color: borderColor,
      width: 2.0,
    );
    
    final cardBackgroundColor = isDark
        ? (isExpired ? Colors.red[900]!.withOpacity(0.2) : AppTheme.darkSurface)
        : (isExpired ? Colors.red[50] : const Color(0xFFFBFCFE));

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: highlightBorder ?? defaultBorder,
          boxShadow: [
            BoxShadow(
              color: isExpired
                  ? Colors.red.withValues(alpha: 0.15)
                  : deal.isEditorPick
                      ? Colors.orange.withValues(alpha: 0.2)
                      : (isDark 
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.08)),
              blurRadius: 12,
              offset: const Offset(0, 3),
              spreadRadius: 0.5,
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Görsel (üstte, tam genişlik)
                      Stack(
                        children: [
                          Hero(
                            tag: 'deal_${deal.id}_image',
                            child: Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isDark ? Colors.grey[800] : Colors.grey[100],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _effectiveImageUrl != null && _effectiveImageUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: _effectiveImageUrl!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 400,
                                        memCacheHeight: 400,
                                        placeholder: (context, url) => Container(
                                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                                          child: const Center(
                                            child: CircularProgressIndicator(strokeWidth: 2),
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
                          if (deal.discountRate != null && deal.discountRate! > 0)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: const BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.all(Radius.circular(6)),
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
                      const SizedBox(height: 10),
                      // Başlık
                      Text(
                        deal.title,
                        key: ValueKey('title_${deal.id}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: isExpired 
                              ? Colors.red[700]!.withOpacity(0.6)
                              : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Fiyat
                      Text(
                        currencyFormat.format(deal.price),
                        key: ValueKey('price_${deal.id}'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isExpired ? Colors.red[700]!.withOpacity(0.6) : AppTheme.primary,
                        ),
                      ),
                      const Spacer(),
                      // Store ve zaman
                      Row(
                        children: [
                          Expanded(
                            child: _buildStoreWidget(deal.store, isDark),
                          ),
                          Text(
                            _formatRelativeTime(deal.createdAt),
                            key: ValueKey('time_${deal.id}'),
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
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
      ),
    );
  }
  
  Widget _buildSmallListCard(Deal deal, NumberFormat currencyFormat, bool isExpired, bool isDark) {
    final Border? highlightBorder = isExpired
        ? Border.all(color: Colors.red[400]!, width: 2.5)
        : deal.isEditorPick
            ? Border.all(color: Colors.orange[400]!, width: 2.5)
            : null;
    
    final borderColor = isDark 
        ? const Color(0xFF404040)
        : const Color(0xFFC0C8D0);
    final Border defaultBorder = Border.all(
      color: borderColor,
      width: 1.5,
    );
    
    final cardBackgroundColor = isDark
        ? (isExpired ? Colors.red[900]!.withOpacity(0.2) : AppTheme.darkSurface)
        : (isExpired ? Colors.red[50] : const Color(0xFFFBFCFE));

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, top: 3, bottom: 3),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: highlightBorder ?? defaultBorder,
          boxShadow: [
            BoxShadow(
              color: isExpired
                  ? Colors.red.withValues(alpha: 0.1)
                  : (isDark 
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.05)),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _isPressed = v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Küçük görsel
                  Hero(
                    tag: 'deal_${deal.id}_image',
                    child: Opacity(
                      opacity: isExpired ? 0.5 : 1.0,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _effectiveImageUrl != null && _effectiveImageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _effectiveImageUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 300,
                                  memCacheHeight: 300,
                                  fadeInDuration: const Duration(milliseconds: 200),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.image_not_supported_rounded,
                                    color: isDark ? Colors.grey[600] : Colors.grey[300],
                                    size: 24,
                                  ),
                                )
                              : Icon(
                                  Icons.image_not_supported_rounded,
                                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // İçerik
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          deal.title,
                          key: ValueKey('title_${deal.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isExpired 
                                ? Colors.red[700]!.withOpacity(0.6)
                                : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              currencyFormat.format(deal.price),
                              key: ValueKey('price_${deal.id}'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isExpired ? Colors.red[700]!.withOpacity(0.6) : AppTheme.primary,
                              ),
                            ),
                            const Spacer(),
                            _buildStoreWidget(deal.store, isDark),
                            const SizedBox(width: 8),
                            Text(
                              _formatRelativeTime(deal.createdAt),
                              key: ValueKey('time_${deal.id}'),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey[500] : Colors.grey[400],
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
        ),
      ),
    );
  }

  Widget _buildCompactCard(Deal deal, NumberFormat currencyFormat, bool isExpired, bool isDark) {
    final Border? highlightBorder = isExpired
        ? Border.all(color: Colors.red[400]!, width: 2.5)
        : deal.isEditorPick
            ? Border.all(color: Colors.orange[400]!, width: 2.5)
            : null;
    
    final borderColor = isDark 
        ? const Color(0xFF404040)
        : const Color(0xFFC0C8D0);
    final Border defaultBorder = Border.all(
      color: borderColor,
      width: 1.5,
    );
    
    final cardBackgroundColor = isDark
        ? (isExpired ? Colors.red[900]!.withOpacity(0.2) : AppTheme.darkSurface)
        : (isExpired ? Colors.red[50] : const Color(0xFFFBFCFE));

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, top: 2, bottom: 2),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: highlightBorder ?? defaultBorder,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _isPressed = v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  // Küçük görsel
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _effectiveImageUrl != null && _effectiveImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _effectiveImageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              memCacheHeight: 200,
                              errorWidget: (context, url, error) => Icon(
                                Icons.image_not_supported_rounded,
                                color: isDark ? Colors.grey[600] : Colors.grey[300],
                                size: 20,
                              ),
                            )
                          : Icon(
                              Icons.image_not_supported_rounded,
                              color: isDark ? Colors.grey[600] : Colors.grey[300],
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // İçerik
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          deal.title,
                          key: ValueKey('title_${deal.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isExpired 
                                ? Colors.red[700]!.withOpacity(0.6)
                                : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              currencyFormat.format(deal.price),
                              key: ValueKey('price_${deal.id}'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isExpired ? Colors.red[700]!.withOpacity(0.6) : AppTheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatRelativeTime(deal.createdAt),
                              key: ValueKey('time_${deal.id}'),
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.grey[500] : Colors.grey[400],
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

  Widget _buildAmazonLogo(bool isDark) {
    // Dosya adı .svg.png olduğu için muhtemelen PNG formatında
    // Önce PNG olarak deneyelim
    return Image.asset(
      'assets/Amazon_logo.svg.png',
      height: 10,
      fit: BoxFit.contain,
      color: isDark ? Colors.grey[300] : Colors.grey[700],
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) {
        // PNG yüklenemezse SVG olarak dene
        try {
          return SvgPicture.asset(
            'assets/Amazon_logo.svg.png',
            height: 10,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              isDark ? Colors.grey[300]! : Colors.grey[700]!,
              BlendMode.srcIn,
            ),
            placeholderBuilder: (context) {
              return SizedBox(
                width: 50,
                height: 10,
                child: Center(
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1),
                  ),
                ),
              );
            },
          );
        } catch (e) {
          // Her iki format da yüklenemezse text göster
          return Text(
            'Amazon',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
      },
    );
  }

  Widget _buildStoreWidget(String store, bool isDark) {
    final storeLower = store.toLowerCase().trim();
    
    // Amazon logosu için
    if (storeLower == 'amazon' || storeLower.contains('amazon')) {
      return SizedBox(
        height: 10, // Amazon yazısının yüksekliği ile aynı
        width: 50, // Logo genişliği
        child: _buildAmazonLogo(isDark),
      );
    }
    
    // Diğer mağazalar için normal text
    return Text(
      store.isEmpty ? 'Bilinmeyen' : store,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.grey[300] : Colors.grey[700],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
