import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/deal.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../screens/profile_screen.dart';
import '../money_badge.dart';
import 'deal_card_helpers.dart';

class VerticalDealCard extends StatefulWidget {
  final Deal deal;
  final VoidCallback onTap;
  final String? effectiveImageUrl;
  final bool isLoadingImage;

  const VerticalDealCard({
    super.key,
    required this.deal,
    required this.onTap,
    this.effectiveImageUrl,
    required this.isLoadingImage,
  });

  @override
  State<VerticalDealCard> createState() => _VerticalDealCardState();
}

class _VerticalDealCardState extends State<VerticalDealCard> {
  bool _showVoteCount = false; // Oy sayısını göster/gizle
  bool _isHovered = false; // Hover durumu takibi
  bool _isPressed = false; // Dokunma durumu takibi

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final isExpired = deal.isExpired;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Opacity(
      opacity: isExpired ? 0.8 : 1.0,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : (_isHovered ? 1.03 : 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
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
              color: deal.isEditorPick 
                  ? Colors.orange[600]! // Editör seçimi için turuncu çerçeve
                  : (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1)),
              width: deal.isEditorPick ? 2.2 : 1.5,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Görsel Container (Aspect Square yerine modern dikdörtgen)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: AspectRatio(
                      aspectRatio: 1.15, // Fixed aspect ratio for perfect card symmetry
                      child: Stack(
                        children: [
                          // Görsel
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white, // Beyaz arka plan
                            ),
                            child: (widget.effectiveImageUrl == null || widget.effectiveImageUrl!.isEmpty)
                                ? Image.asset(getStoreAsset(deal.store), fit: BoxFit.contain)
                                : Padding(
                                    padding: const EdgeInsets.all(8.0), // Elegant floating padding
                                    child: CachedNetworkImage(
                                      imageUrl: widget.effectiveImageUrl!,
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
                                        getStoreAsset(deal.store),
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
                                    formatRelativeTime(deal.createdAt),
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
                          // Amazon Depo Rozeti (Sol Üst - Zaman Rozetinin Altında)
                          if (deal.isAmazonWarehouse)
                            Positioned(
                              top: 28,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFD97706), Color(0xFFB45309)],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_rounded,
                                      size: 9,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 2.5),
                                    Text(
                                      'AMAZON DEPO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // FOMO Rozeti (Sağ Üst - Biten / Tükenen Fırsatlar İçin)
                          if (isExpired)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.hourglass_bottom_rounded,
                                      size: 9,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'KAÇTI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // İndirim Rozeti (Sağ Alt)
                          if (deal.effectiveDiscountRate != null && deal.effectiveDiscountRate! > 0)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? primaryColor 
                                      : const Color(0xFFE53935),
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
                                  '%${deal.effectiveDiscountRate}',
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
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
                                            getThermometerEmoji(hotVotes, coldVotes),
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
                                    Icons.local_fire_department,
                                    size: 10,
                                    color: Colors.deepOrange,
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
                          // Resim ile kart bilgileri arasındaki geçiş çizgisi (daha belirgin sınır)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 1.5,
                              color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // İçerik
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mağaza logosu, mağaza adı ve Paylaşan Kullanıcı Avatarı (aynı satırda)
                              Row(
                                children: [
                                  buildStoreLogo(deal.store, size: 14, borderRadius: 3),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.grey[300] : AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (deal.isAmazonWarehouse) ...[
                                          const SizedBox(width: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(3),
                                              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4), width: 0.5),
                                            ),
                                            child: const Text(
                                              'Depo',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
                                                            color: primaryColor.withValues(alpha: 0.1),
                                                            child: Icon(
                                                              Icons.person,
                                                              size: 10,
                                                              color: primaryColor,
                                                            ),
                                                          ),
                                                          errorWidget: (context, url, error) => Container(
                                                            width: 16,
                                                            height: 16,
                                                            color: primaryColor.withValues(alpha: 0.1),
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
                                                        color: primaryColor.withValues(alpha: 0.1),
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
                                          return const SizedBox.shrink();
                                        }
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8), // Başlık için üst padding artırıldı
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
                                        painter: const StrikeThroughPainter(),
                                      ),
                                    ),
                                ],
                              ),
                              // Rating (Başlık altında, fiyat üstünde)
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
                               if (MoneyBadge.isMoneyDeal(deal)) ...[
                                 const SizedBox(height: 4),
                                 const MoneyBadge(
                                   fontSize: 9,
                                   iconSize: 11,
                                   padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                 ),
                               ],
                               const SizedBox(height: 6),
                               // Fiyat ve İndirimsiz Fiyat (Eski Fiyat)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  FormattedPriceText(
                                    value: deal.price,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: isExpired 
                                          ? Colors.red[700] 
                                          : AppTheme.primary,
                                    ),
                                  ),
                                  if (deal.originalPrice != null && deal.originalPrice! > deal.price)
                                    FormattedPriceText(
                                      value: deal.originalPrice,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                        decoration: TextDecoration.lineThrough,
                                        decorationThickness: 1.5,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (deal.priceLabel != null && deal.priceLabel!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                                    fontSize: 10.5, // Font size bumped from 9 to 10.5 to stand out
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.1,
                                    color: Color(0xFFE65100), // Clean deep orange tone
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
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
    );
  }
}
