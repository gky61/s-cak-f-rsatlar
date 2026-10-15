import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/deal.dart';
import '../../theme/app_theme.dart';
import '../../utils/asset_path_migration.dart';
import '../../screens/profile_screen.dart';
import '../store_price_badge.dart';
import 'deal_card_helpers.dart';
import 'deal_card_thermometer_pill.dart';
import '../skeletons/shimmer_box.dart';

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
    this.isLoadingImage = false,
  });

  @override
  State<VerticalDealCard> createState() => _VerticalDealCardState();
}

class _VerticalDealCardState extends State<VerticalDealCard> {
  bool _isHovered = false; // Hover durumu takibi
  bool _isPressed = false; // Dokunma durumu takibi
  
  Deal get deal => widget.deal;

  Widget _buildPriceSection(bool isDark, bool isExpired) {
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
              fontSize: 15.0,
              fontWeight: FontWeight.w900,
              color: isExpired ? const Color(0xFFDC2626) : AppTheme.primary,
              letterSpacing: -0.4,
              height: 1.0,
            ),
          ),
          if (hasOriginalPrice) ...[
            const SizedBox(width: 4.5),
            // İndirimsiz / Liste Fiyatı (Zarif üstü çizili gri ton)
            FormattedPriceText(
              value: deal.originalPrice,
              style: TextStyle(
                fontSize: 10.5,
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

  Widget _buildBottomBar(bool isDark, bool isExpired) {
    return SizedBox(
      height: 24,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _buildPriceSection(isDark, isExpired),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final isExpired = deal.isArchived;
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
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
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
              if (deal.isEditorPick)
                BoxShadow(
                  color: AppTheme.primary.withValues(
                    alpha: isDark ? 0.20 : 0.14,
                  ),
                  blurRadius: _isHovered ? 14 : 8,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 2),
                ),
            ],
            border: Border.all(
              color: deal.isRejected
                  ? const Color(0xFFEF4444)
                  : (deal.isApproved == false
                      ? const Color(0xFFF59E0B)
                      : (deal.isEditorPick 
                          ? AppTheme.primary // Editör seçimi için marka turuncusu çerçeve
                          : (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFCBD5E1)))),
              width: (deal.isRejected || deal.isApproved == false || deal.isEditorPick) ? 2.0 : 1.5,
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
                  SizedBox(
                    height: 138,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        // Görsel
                        Container(
                          width: double.infinity,
                          height: 138,
                          decoration: const BoxDecoration(
                            color: Colors.white, // Beyaz zemin
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                            child: (widget.effectiveImageUrl == null || widget.effectiveImageUrl!.isEmpty)
                                ? Image.asset(getStoreAsset(deal.store), fit: BoxFit.contain)
                                : CachedNetworkImage(
                                    imageUrl: widget.effectiveImageUrl!,
                                    fit: BoxFit.contain,
                                    memCacheWidth: 600,
                                    memCacheHeight: 600,
                                    maxHeightDiskCache: 600,
                                    maxWidthDiskCache: 600,
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
                            top: 7,
                            left: 7,
                            child: _buildBadgeCapsule(
                              text: 'REDDEDİLDİ',
                              icon: Icons.cancel_rounded,
                              colors: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                          )
                        else if (deal.isApproved == false)
                          Positioned(
                            top: 7,
                            left: 7,
                            child: _buildBadgeCapsule(
                              text: 'İNCELEMEDE',
                              icon: Icons.hourglass_top_rounded,
                              colors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                          )
                        else if (isExpired)
                          Positioned(
                            top: 7,
                            left: 7,
                            child: _buildBadgeCapsule(
                              text: 'KAÇTI',
                              icon: Icons.hourglass_bottom_rounded,
                              colors: const [Color(0xFFD32F2F), Color(0xFFC62828)],
                            ),
                          )
                        else if (!deal.hidePrice && deal.effectiveDiscountRate != null && deal.effectiveDiscountRate! > 0)
                          Positioned(
                            top: 7,
                            left: 7,
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

                        // ─── EDİTÖRÜN SEÇİMİ ROZETİ (Sağ Üst) ─────────────────
                        if (deal.isEditorPick)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: buildEditorChoiceStarBadge(isDark: isDark),
                          ),

                        // ─── CANLI TERMOMETRE ROZETİ (Görsel Sağ Alt) ─────────────────
                        if ((deal.hotVotes + deal.coldVotes) > 0)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: DealCardThermometerPill(
                              deal: deal,
                              isDark: isDark,
                              compact: true,
                              onImage: true,
                            ),
                          ),

                        // Resim ile alt gövde arasındaki ince sınır
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1.0,
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── ALT İÇERİK GÖVDESİ (SİMETRİK VE CETVEL HİZALI) ────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(11, 8.5, 11, 8.5),
                      child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1.1 Mağaza Logosu, Adı, Zaman ve Avatar
                              Row(
                                children: [
                                  buildStoreLogo(deal.store, size: 14, borderRadius: 3),
                                  const SizedBox(width: 4.5),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' · ${formatRelativeTimeCompact(deal.createdAt)}',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Paylaşan Kullanıcı Avatarı (Botkolik paylaşımlarında gösterilmez)
                                  if (!deal.isBotkolik && deal.isUserSubmitted && deal.postedBy.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    _buildAuthorAvatar(deal, primaryColor),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 7.0),

                              // 1.2 Başlık (Sabit 34px Yükseklik - Cetvel Hizası, nefes alan tipografi)
                              SizedBox(
                                height: 34,
                                child: Text(
                                  deal.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                    letterSpacing: -0.2,
                                    color: (isExpired || deal.expiredVotes >= 15)
                                        ? const Color(0xFFDC2626) 
                                        : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                                    decoration: (isExpired || deal.expiredVotes >= 15)
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7.0),

                              // 1.3 Puan, Sosyal Kanıt & Mağaza Rozetleri (Sabit 18px Yükseklik)
                              SizedBox(
                                height: 18,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (deal.hasMigrosPromoLabel) ...[
                                            // Migros kampanyalı ise: Kategori ve sade ikon yerine Money kampanya etiketi
                                            Flexible(
                                              child: buildMigrosPromoBadge(
                                                label: deal.priceLabel!.trim(),
                                                isDark: isDark,
                                              ),
                                            ),
                                          ] else if (deal.ratingValue != null) ...[
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 13.5,
                                              color: Color(0xFFF59E0B),
                                            ),
                                            const SizedBox(width: 2),
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
                                              const SizedBox(width: 2.5),
                                              Flexible(
                                                child: Text(
                                                  '(${deal.ratingCount})',
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                            if (deal.isAmazonWarehouse) ...[
                                              const SizedBox(width: 3),
                                              _buildWarehouseBadge(),
                                            ],
                                            if (StorePriceBadge.hasBadge(deal: deal)) ...[
                                              const SizedBox(width: 3),
                                              StorePriceBadge(deal: deal, compact: true),
                                            ],
                                          ] else ...[
                                            // Puan yoksa: zarif kategori etiketi (hizalama asla şaşmaz)
                                            Flexible(
                                              child: Text(
                                                getCategoryDisplayName(deal.category),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                            if (deal.isAmazonWarehouse) ...[
                                              const SizedBox(width: 3),
                                              _buildWarehouseBadge(),
                                            ],
                                            if (StorePriceBadge.hasBadge(deal: deal)) ...[
                                              const SizedBox(width: 3),
                                              StorePriceBadge(deal: deal, compact: true),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Yorum Sayısı Rozeti (Daima görünür)
                                    buildDealCommentBadge(
                                      count: deal.commentCount,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),

                              // 1.4 FİYAT VE CANLI TERMOMETRE (Cetvel hizalı alt taban)
                              _buildBottomBar(isDark, isExpired),
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

  Widget _buildWarehouseBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.4),
          width: 0.5,
        ),
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
    );
  }

  Widget _buildAuthorAvatar(Deal deal, Color primaryColor) {
    if (deal.isBotkolik) {
      // Botkolik paylaşımlarında anasayfa feed kartlarında avatar gösterilmez
      return const SizedBox.shrink();
    } else if (deal.isUserSubmitted && deal.postedBy.isNotEmpty) {
      return InkWell(
        key: ValueKey('user_avatar_widget_${deal.postedBy}'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: deal.postedBy),
            ),
          );
        },
        child: ClipOval(
          child: Builder(
            builder: (context) {
              final avatarUrl = migrateAssetPath(deal.postedByAvatar ?? '');
              if (avatarUrl.isNotEmpty) {
                if (avatarUrl.startsWith('assets/')) {
                  return Image.asset(
                    avatarUrl,
                    width: 16,
                    height: 16,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(primaryColor),
                  );
                }
                return CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 16,
                  height: 16,
                  fit: BoxFit.cover,
                  memCacheWidth: 32,
                  memCacheHeight: 32,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (context, url) => _buildDefaultAvatar(primaryColor),
                  errorWidget: (context, url, error) => _buildDefaultAvatar(primaryColor),
                );
              }
              return _buildDefaultAvatar(primaryColor);
            },
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDefaultAvatar(Color primaryColor) {
    return Container(
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
    );
  }
}

