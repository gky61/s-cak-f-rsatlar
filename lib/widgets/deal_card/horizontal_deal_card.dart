import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/deal.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../screens/profile_screen.dart';
import '../money_badge.dart';
import 'deal_card_helpers.dart';

class HorizontalDealCard extends StatefulWidget {
  final Deal deal;
  final VoidCallback onTap;
  final String? effectiveImageUrl;
  final bool isLoadingImage;

  const HorizontalDealCard({
    super.key,
    required this.deal,
    required this.onTap,
    this.effectiveImageUrl,
    required this.isLoadingImage,
  });

  @override
  State<HorizontalDealCard> createState() => _HorizontalDealCardState();
}

class _HorizontalDealCardState extends State<HorizontalDealCard> {
  bool _showVoteCount = false; // Oy sayısını göster/gizle
  bool _isHovered = false; // Hover durumu takibi
  bool _isPressed = false; // Dokunma durumu takibi

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final isExpired = deal.isExpired;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardBgColor = isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9);
    final cardBorderColor = deal.isEditorPick 
        ? Colors.orange[600]! 
        : (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1));
    final borderWidth = deal.isEditorPick ? 2.2 : 1.5;

    final inceleButton = ElevatedButton(
      onPressed: () => openProductLink(context, deal.link),
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

    return Opacity(
      opacity: isExpired ? 0.8 : 1.0,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : (_isHovered ? 1.03 : 1.0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16), // rounded-2xl
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isDark 
                    ? (_isHovered ? 0.45 : 0.25) 
                    : (_isHovered ? 0.10 : 0.06)
              ),
              blurRadius: _isHovered ? 24 : 16,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(
                isDark 
                    ? (_isHovered ? 0.25 : 0.15) 
                    : (_isHovered ? 0.06 : 0.04)
              ),
              blurRadius: _isHovered ? 12 : 6,
              spreadRadius: _isHovered ? 2 : 1,
              offset: Offset.zero,
            ),
          ],
          border: Border.all(
            color: cardBorderColor,
            width: borderWidth,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onHover: (hovering) {
              setState(() {
                _isHovered = hovering;
              });
            },
            onHighlightChanged: (highlighted) {
              setState(() {
                _isPressed = highlighted;
              });
            },
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
                        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1),
                        width: 1.5,
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
                          (isExpired || widget.effectiveImageUrl == null || widget.effectiveImageUrl!.isEmpty)
                              ? Image.asset(getStoreAsset(deal.store), width: double.infinity, height: double.infinity, fit: BoxFit.contain)
                              : Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.effectiveImageUrl!,
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
                                      getStoreAsset(deal.store),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                          // 🔥 Fırsat Termometresi Emoji (Sol Alt) - Gerçek Zamanlı
                          Positioned(
                            bottom: 6,
                            left: 6,
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
                                            getThermometerEmoji(hotVotes, coldVotes),
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // İndirim Rozeti (Sağ Alt)
                          if (deal.effectiveDiscountRate != null && deal.effectiveDiscountRate! > 0)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? primaryColor.withValues(alpha: 0.9)
                                      : const Color(0xFFE53935),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDark ? primaryColor : const Color(0xFFE53935)).withValues(alpha: 0.3),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.trending_down,
                                      size: 10,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '%${deal.effectiveDiscountRate}',
                                      style: TextStyle(
                                        color: isDark ? Colors.black : Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
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
                                    Icons.local_fire_department,
                                    size: 9,
                                    color: Colors.deepOrange,
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
                                        getCategoryDisplayName(deal.category),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          buildStoreLogo(deal.store, size: 14, borderRadius: 3),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
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
                                                                    color: primaryColor.withValues(alpha: 0.1),
                                                                    child: Icon(Icons.person, size: 9, color: primaryColor),
                                                                  ),
                                                                  errorWidget: (context, url, error) => Container(
                                                                    width: 14,
                                                                    height: 14,
                                                                    color: primaryColor.withValues(alpha: 0.1),
                                                                    child: Icon(Icons.person, size: 9, color: primaryColor),
                                                                  ),
                                                                ))
                                                          : Container(
                                                              width: 14,
                                                              height: 14,
                                                              decoration: BoxDecoration(
                                                                color: primaryColor.withValues(alpha: 0.1),
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: Icon(Icons.person, size: 9, color: primaryColor),
                                                            ),
                                                    ),
                                                  );
                                                } catch (e) {
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
                                        painter: const StrikeThroughPainter(),
                                      ),
                                    ),
                                ],
                              ),
                              // Rating (Başlık altında)
                              if (deal.ratingValue != null || deal.ratingCount != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: Color(0xFFFFB800),
                                    ),
                                    const SizedBox(width: 2),
                                    if (deal.ratingValue != null)
                                      Text(
                                        deal.ratingValue!.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.grey[200] : AppTheme.textPrimary,
                                        ),
                                      ),
                                    if (deal.ratingCount != null) ...[
                                      const SizedBox(width: 2),
                                      Text(
                                        '(${deal.ratingCount})',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                          // Alt kısım: Fiyat ve Buton (Ortak Düzen)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (MoneyBadge.isMoneyDeal(deal)) ...[
                                  const MoneyBadge(
                                    fontSize: 8.5,
                                    iconSize: 11,
                                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                // Kampanya açıklaması varsa üstte gösterilir
                                if (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3E0), // Soft orange amber container
                                      borderRadius: BorderRadius.circular(6), // Rounded pill shape
                                      border: Border.all(
                                        color: const Color(0xFFFFB74D).withValues(alpha: 0.3),
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
                                            FormattedPriceText(
                                              value: deal.originalPrice,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.grey[500] : AppTheme.textSecondary,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          FormattedPriceText(
                                            value: deal.price,
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
      ),
    ),
  );
}
}
