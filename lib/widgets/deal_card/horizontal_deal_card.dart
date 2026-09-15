import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/deal.dart';
import '../../theme/app_theme.dart';
import '../store_price_badge.dart';
import 'deal_card_helpers.dart';
import 'deal_card_thermometer_pill.dart';
import '../skeletons/shimmer_box.dart';

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
  bool _isHovered = false; // Hover durumu takibi
  bool _isPressed = false; // Dokunma durumu takibi

  Widget _buildPriceAndBadgeSection(bool isDark, bool isExpired) {
    final deal = widget.deal;
    if (deal.hidePrice) return const SizedBox.shrink();
    final hasOriginalPrice = deal.originalPrice != null && deal.originalPrice! > deal.price;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Güncel İndirimli Fiyat
          FormattedPriceText(
            value: deal.price,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isExpired ? const Color(0xFFDC2626) : AppTheme.primary,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          if (hasOriginalPrice) ...[
            const SizedBox(width: 5),
            // İndirimsiz / Liste Fiyatı
            FormattedPriceText(
              value: deal.originalPrice,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                decoration: TextDecoration.lineThrough,
                decorationColor: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                decorationThickness: 1.3,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final isExpired = deal.isExpired;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9);
    final cardBorderColor = deal.isRejected
        ? const Color(0xFFEF4444)
        : (deal.isApproved == false
            ? const Color(0xFFF59E0B)
            : (deal.isEditorPick 
                ? Colors.orange[600]! 
                : (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1))));
    final borderWidth = (deal.isRejected || deal.isApproved == false || deal.isEditorPick) ? 2.0 : 1.5;    final inceleButton = ElevatedButton(
      onPressed: () => openProductLink(context, deal.link, deal.store, deal),
      style: ElevatedButton.styleFrom(
        backgroundColor: isExpired ? const Color(0xFF64748B) : AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999), // rounded-full
        ),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isExpired ? 'Şansını Dene' : 'İncele',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: -0.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(
            Icons.arrow_outward_rounded,
            size: 12.5,
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
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16), // rounded-2xl
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark 
                    ? (_isHovered ? 0.45 : 0.25) 
                    : (_isHovered ? 0.10 : 0.06),
              ),
              blurRadius: _isHovered ? 24 : 16,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark 
                    ? (_isHovered ? 0.25 : 0.15) 
                    : (_isHovered ? 0.06 : 0.04),
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
              padding: const EdgeInsets.all(11),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sol tarafta görsel - Esnek ve yüksek kaliteli (min. 140px)
                    Container(
                      width: 135,
                      constraints: const BoxConstraints(minHeight: 140),
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
                            const Positioned.fill(
                              child: ColoredBox(color: Colors.white),
                            ),
                            // Görsel
                            Positioned.fill(
                              child: (widget.effectiveImageUrl == null || widget.effectiveImageUrl!.isEmpty)
                                  ? Image.asset(getStoreAsset(deal.store), fit: BoxFit.contain)
                                  : Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: CachedNetworkImage(
                                        imageUrl: widget.effectiveImageUrl!,
                                        fit: BoxFit.contain,
                                        memCacheWidth: 1000,
                                        memCacheHeight: 1000,
                                        maxHeightDiskCache: 1000,
                                        maxWidthDiskCache: 1000,
                                        fadeInDuration: const Duration(milliseconds: 300),
                                        fadeOutDuration: const Duration(milliseconds: 100),
                                        placeholder: (context, url) => const ShimmerBox(
                                          width: double.infinity,
                                          height: double.infinity,
                                          borderRadius: 0,
                                        ),
                                        errorWidget: (context, url, error) => Image.asset(
                                          getStoreAsset(deal.store),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                            ),
                            // ─── TEK ROZET ALANI (Sol Üst) ─────────────────────────
                            // Hiyerarşi: Reddedildi > İncelemede > KAÇTI > İndirim Oranı
                            if (deal.isRejected)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: _buildBadgeCapsule(
                                  text: 'REDDEDİLDİ',
                                  icon: Icons.cancel_rounded,
                                  colors: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                                ),
                              )
                            else if (deal.isApproved == false)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: _buildBadgeCapsule(
                                  text: 'İNCELEMEDE',
                                  icon: Icons.hourglass_top_rounded,
                                  colors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                                ),
                              )
                            else if (isExpired)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: _buildBadgeCapsule(
                                  text: 'KAÇTI',
                                  icon: Icons.hourglass_bottom_rounded,
                                  colors: const [Color(0xFFD32F2F), Color(0xFFC62828)],
                                ),
                              )
                            else if (!deal.hidePrice && deal.effectiveDiscountRate != null && deal.effectiveDiscountRate! > 0)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF4500), Color(0xFFDC2626)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                                        blurRadius: 3.5,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '%${deal.effectiveDiscountRate}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ),

                            // SÜRESİ DOLDU Yarı Saydam Kaplama (Sadece bitmişse)
                            if (isExpired)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.28),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    // Sağ tarafta içerik - Asla taşma yapmayan esnek ve ferah mimari
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Üst Bölüm: Kategori/Mağaza + Başlık + Değerlendirme & Termometre + Zaman & Yorum
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Kategori ve Mağaza Satırı
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      getCategoryDisplayName(deal.category),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    flex: 6,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        buildStoreLogo(deal.store, size: 13.5, borderRadius: 3.5),
                                        const SizedBox(width: 3.5),
                                        Flexible(
                                          child: Text(
                                            deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
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
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.inventory_2_rounded,
                                                  size: 9,
                                                  color: Color(0xFFD97706),
                                                ),
                                                SizedBox(width: 2),
                                                Text(
                                                  'Depo',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFD97706),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (StorePriceBadge.hasBadge(deal: deal)) ...[
                                          const SizedBox(width: 3.5),
                                          StorePriceBadge(deal: deal, compact: true),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // 2. Başlık Satırı (Maksimum 2 satır, temiz ve okunaklı)
                              Padding(
                                padding: const EdgeInsets.only(top: 1, bottom: 2),
                                child: Text(
                                  deal.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.22,
                                    letterSpacing: -0.2,
                                    color: (isExpired || deal.expiredVotes >= 15)
                                        ? const Color(0xFFDC2626) 
                                        : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                                    decoration: (isExpired || deal.expiredVotes >= 15)
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: const Color(0xFFDC2626),
                                    decorationThickness: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              // 3. Değerlendirme & Termometre Satırı (Mağaza Puanı + Canlı Termometre)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Sol: Mağaza Puanı ve Oy Adedi
                                  if (deal.ratingValue != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          size: 13.5,
                                          color: Color(0xFFF59E0B),
                                        ),
                                        const SizedBox(width: 2.0),
                                        Text(
                                          deal.ratingValue!.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                        if (deal.ratingCount != null) ...[
                                          const SizedBox(width: 2),
                                          Text(
                                            '(${deal.ratingCount})',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    )
                                  else
                                    const SizedBox.shrink(),

                                  // Sağ: Grid View'daki Termometre Kapsülü (HUD Pill)
                                  DealCardThermometerPill(
                                    deal: deal,
                                    isDark: isDark,
                                    compact: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3.5),
                              // 4. Zaman & Yorum Satırı (Kompakt "8sa", "3g" formatı - "önce" eki kaldırıldı)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Sol: Paylaşım Zamanı
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 10.5,
                                        color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        formatRelativeTimeCompact(deal.createdAt),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Sağ: Yorum Rozeti
                                  buildDealCommentBadge(
                                    count: deal.commentCount,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 5. Alt Bölüm: Fiyat ve İncele Butonu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _buildPriceAndBadgeSection(isDark, isExpired),
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
          ),
        ),
      ),
    ),
  );
}

  Widget _buildBadgeCapsule({
    required String text,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 3.5,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 9,
            color: Colors.white,
          ),
          const SizedBox(width: 2.5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
