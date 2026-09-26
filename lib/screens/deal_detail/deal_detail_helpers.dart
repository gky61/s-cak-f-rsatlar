import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/deal.dart';
import '../../theme/app_theme.dart';

/// Fırsat detay sayfası için yardımcı widget'lar ve fonksiyonlar.
class DealDetailHelpers {
  DealDetailHelpers._();

  /// Oylama stat butonu widget'ı (Kaydet, Yorum, Fırsat Bitti).
  static Widget buildStatButton({
    required BuildContext context,
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    bool isSelected = false,
    bool isLoading = false,
  }) {
    // 1. Canlı ve Net Aktif Renk Sistemi
    final Color activeColor = isDark
        ? (color == const Color(0xFFF59E0B)
            ? const Color(0xFFFBBF24) // Amber 400
            : (color == const Color(0xFFEF4444)
                ? const Color(0xFFF87171) // Red 400
                : const Color(0xFF60A5FA))) // Blue 400
        : (color == const Color(0xFFF59E0B)
            ? const Color(0xFFD97706) // Amber 600
            : (color == const Color(0xFFEF4444)
                ? const Color(0xFFDC2626) // Red 600
                : const Color(0xFF2563EB))); // Blue 600

    // 2. Seçili Durumda Temiz ve Ferah Zemin (Boğukluk Önleyici)
    final Color selectedBgColor = isDark
        ? (color == const Color(0xFFF59E0B)
            ? const Color(0xFF241B10) // Koyu Amber Yüzey
            : (color == const Color(0xFFEF4444)
                ? const Color(0xFF261214) // Koyu Kırmızı Yüzey
                : const Color(0xFF101C2E))) // Koyu Mavi Yüzey
        : (color == const Color(0xFFF59E0B)
            ? const Color(0xFFFFFBEB) // Ferah Bal/Krem Tint
            : (color == const Color(0xFFEF4444)
                ? const Color(0xFFFEF2F2) // Ferah Açık Kırmızı Tint
                : const Color(0xFFEFF6FF))); // Ferah Açık Mavi Tint

    // 3. Modern ve Minimalist Kart Dekorasyonu
    final BoxDecoration buttonDecoration = isSelected
        ? BoxDecoration(
            color: selectedBgColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark
                  ? activeColor.withValues(alpha: 0.65)
                  : activeColor.withValues(alpha: 0.75),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          )
        : BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark
                  ? AppTheme.darkBorder
                  : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1.5),
              ),
            ],
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(15),
        splashColor: activeColor.withValues(alpha: isDark ? 0.20 : 0.12),
        highlightColor: activeColor.withValues(alpha: isDark ? 0.10 : 0.05),
        hoverColor: activeColor.withValues(alpha: isDark ? 0.12 : 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 56,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          decoration: buttonDecoration,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Üst Satır: Canlı İkon (Seçiliyse Mikro Rozet) + Sayaç
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                      ),
                    )
                  else if (isSelected)
                    // Seçili Durumda Canlı Mikro Rozet (Canlı & Belirgin)
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: isDark ? 0.40 : 0.30),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: 11.5,
                        color: Colors.white,
                      ),
                    )
                  else
                    // Seçili Olmayan Durumda Minimalist İkon
                    Icon(
                      icon,
                      size: 16.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  if (count >= 0) ...[
                    const SizedBox(width: 4.5),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        height: 1.1,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3.5),
              // Alt Satır: Başlık / Durum Metni
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? activeColor
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  letterSpacing: 0.1,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cam efektli buton.
  static Widget buildGlassButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurface.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: color ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.accent),
        ),
        onPressed: onPressed,
      ),
    );
  }

  /// Kompakt bilgi chip'i.
  static Widget buildCompactInfoChip({
    required BuildContext context,
    bool showEditIcon = false,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showEditIcon) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.edit,
              size: 14,
              color: color.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
  }

  /// Kompakt istatistik gösterimi.
  static Widget buildCompactStat({
    required BuildContext context,
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    bool isSelected = false,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          )
        else
          Icon(
            icon,
            color: isSelected ? color : color.withValues(alpha: 0.7),
            size: 20,
          ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? color
                : (isDark ? AppTheme.darkTextPrimary : AppTheme.accent),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? color
                : (isDark ? AppTheme.darkTextSecondary : Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  /// Editör seçimi rozeti.
  static Widget buildEditorTag(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: primaryColor, size: 20),
          const SizedBox(width: 6),
          const Text(
            'Editörün Seçimi',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  /// Detaylı bilgi chip'i.
  static Widget buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// İstatistik bölümü.
  static Widget buildStatsSection(Deal deal, Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: buildStatCard(
            title: 'Sıcak Oylar',
            icon: Icons.local_fire_department_rounded,
            color: primaryColor,
            count: deal.hotVotes,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: buildStatCard(
            title: 'Soğuk Oylar',
            icon: Icons.ac_unit_rounded,
            color: const Color(0xFF3A86FF),
            count: deal.coldVotes,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: buildStatCard(
            title: 'Yorumlar',
            icon: Icons.chat_rounded,
            color: Colors.grey[700] ?? Colors.grey,
            count: deal.commentCount,
          ),
        ),
      ],
    );
  }

  /// İstatistik kartı.
  static Widget buildStatCard({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hatırlatma kartı.
  static Widget buildReminderCard(ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alarm kurmayı unutma',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Takip ettiğin kategoriler için bildirimleri açarak yeni fırsatlardan hemen haberdar ol.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hata durumu ekranı.
  static Widget buildErrorState(BuildContext context) {
          return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Fırsat bulunamadı',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fırsat kaldırılmış veya bağlantı hatalı olabilir.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Geri dön'),
          ),
        ],
      ),
    );
  }

  /// Paylaşan kişi formatı.
  static String formatPostedBy(String postedBy) {
    if (postedBy.isEmpty) {
      return 'Topluluk Üyesi';
    }

    final safeLength = postedBy.length >= 6 ? 6 : postedBy.length;
    return '#${postedBy.substring(0, safeLength).toUpperCase()}';
  }

  /// Göreceli zaman formatı.
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    }

    return DateFormat('d MMM').format(date);
  }

  /// Oy sayısı metni.
  static String getVoteCountText(Deal deal) {
    if (deal.expiredVotes >= 10) {
      return '10/10';
    } else {
      final remaining = 10 - deal.expiredVotes;
      return '$remaining oy daha';
    }
  }

  /// Fırsat Detay Sayfasında süresi dolmuş (isExpired) fırsatlar için
  /// hafif sıcak sarı/amber dokunuşlu, arşiv hissiyatını veren ancak göz yormayan minimalist bilgi şeridi.
  static Widget buildArchivedCampaignBanner({
    required BuildContext context,
    required bool isDark,
    VoidCallback? onActionTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF221A11) // Koyu modda sıcak amber/kahve alt tonlu zemin
            : const Color(0xFFFFFBEB), // Açık modda ferah bal/krem rengi
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFD97706).withValues(alpha: 0.38)
              : const Color(0xFFFDE68A),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onActionTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                // Arşiv İkon Kutucuğu
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFB45309).withValues(alpha: 0.28)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                          : const Color(0xFFFDE68A),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 10),
                // Metin Alanı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Arşiv Kampanyası',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 1.5),
                      Text.rich(
                        TextSpan(
                          text: 'Süresi dolduğu için akıştan kaldırılmıştır. İndirim geçerliliği için ',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: isDark
                                ? const Color(0xFFE2E8F0).withValues(alpha: 0.88)
                                : const Color(0xFF78350F).withValues(alpha: 0.88),
                          ),
                          children: [
                            TextSpan(
                              text: '"Şansını Dene"',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                              ),
                            ),
                            const TextSpan(
                              text: '\'yi kullanabilirsiniz.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onActionTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: isDark
                        ? const Color(0xFFFBBF24).withValues(alpha: 0.7)
                        : const Color(0xFFD97706).withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ürün görseli üzerinde (Hero Image) sol alt köşede yer alan şık, amber cam efektli arşiv pulu / etiketi.
  static Widget buildImageArchivalSticker({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1308).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: Color(0xFFFBBF24),
            size: 13.5,
          ),
          SizedBox(width: 4.5),
          Text(
            'ARŞİV',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFEF3C7),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Fırsat Detay Sayfasında ürün değerlendirmesini (puan ve değerlendirme sayısı)
  /// gösteren canlı, minimalist ve profesyonel rozet (Rating Badge).
  static Widget buildRatingBadge({
    required Deal deal,
    required bool isDark,
  }) {
    if (deal.ratingValue == null && deal.ratingCount == null) {
      return const SizedBox.shrink();
    }

    final hasRatingValue = deal.ratingValue != null;
    final hasRatingCount = deal.ratingCount != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        hasRatingValue ? 4.5 : 8,
        3.5,
        hasRatingCount ? 10 : (hasRatingValue ? 4.5 : 8),
        3.5,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E38) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF0F172A)).withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Canlı Altın Yıldız ve Puan Kapsülü
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                if (hasRatingValue) ...[
                  const SizedBox(width: 3.5),
                  Text(
                    deal.ratingValue!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasRatingCount) ...[
            const SizedBox(width: 7.5),
            Text(
              '${deal.ratingCount} değerlendirme',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

