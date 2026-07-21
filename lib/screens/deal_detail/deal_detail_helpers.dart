import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/deal.dart';
import '../../theme/app_theme.dart';

/// Fırsat detay sayfası için yardımcı widget'lar ve fonksiyonlar.
class DealDetailHelpers {
  DealDetailHelpers._();

  /// Oylama stat butonu widget'ı.
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.18 : 0.10)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.6)
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[300]!),
              width: isSelected ? 1.2 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top Row: Icon + Count
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  else
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? color : (isDark ? Colors.grey[300] : AppTheme.textPrimary),
                    ),
                  if (count >= 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? color : (isDark ? Colors.white : AppTheme.textPrimary),
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              // Bottom Row: Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : (isDark ? Colors.grey[400] : AppTheme.textSecondary),
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
          Text(
            'Editörün Seçimi',
            style: const TextStyle(
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
                style: TextStyle(
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
                style: TextStyle(
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
}
