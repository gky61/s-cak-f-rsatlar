import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../utils/badge_helper.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class BadgesScreen extends StatefulWidget {
  final AppUser user;
  final bool isOwnProfile;

  const BadgesScreen({
    super.key,
    required this.user,
    this.isOwnProfile = true,
  });

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final UserService _userService = UserService();
  late AppUser _user;
  BadgeCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = AppTheme.primary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final backgroundColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final textSub = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    final totalCount = BadgeHelper.badges.length;
    final earnedCount = BadgeHelper.badges.values.where((b) => _user.badges.contains(b.id)).length;
    final completionRate = totalCount > 0 ? (earnedCount / totalCount) : 0.0;
    final filteredBadges = BadgeHelper.getBadgesByCategory(_selectedCategory);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textMain),
          onPressed: () => Navigator.pop(context, _user),
        ),
        title: Text(
          widget.isOwnProfile ? 'Avcı Başarımlarım' : '${_user.username} • Başarımlar',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: textMain,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Overview & Level Progress Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppTheme.darkSurfaceElevated, AppTheme.darkSurface]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.military_tech_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BAŞARIM İLERLEMESİ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$earnedCount / $totalCount Rozet Kazanıldı',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: textMain,
                              ),
                            ),
                            Text(
                              'Fırsat paylaştıkça ve toplulukta aktifleştikçe rozetleriniz açılır.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: completionRate,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '%${(completionRate * 100).toInt()} Tamamlandı',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        '${totalCount - earnedCount} Rozet Kilitli',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textSub,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildCategoryChip(
                    label: 'Tümü ($totalCount)',
                    isSelected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                    isDark: isDark,
                    primaryColor: primaryColor,
                    textSub: textSub,
                  ),
                  const SizedBox(width: 8),
                  ...BadgeCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCategoryChip(
                        label: cat.label,
                        icon: cat.icon,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedCategory = cat),
                        isDark: isDark,
                        primaryColor: primaryColor,
                        textSub: textSub,
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Badges Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: filteredBadges.map((badge) {
                    final isUnlocked = _user.badges.contains(badge.id);
                    final isPinned = _user.pinnedBadge == badge.id;
                    final progress = BadgeHelper.calculateProgress(_user, badge);

                    return SizedBox(
                      width: itemWidth,
                      child: _buildBadgeCard(
                        context,
                        badge: badge,
                        progress: progress,
                        isUnlocked: isUnlocked,
                        isPinned: isPinned,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textMain: textMain,
                        textSub: textSub,
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
    required Color textSub,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? AppTheme.darkSurfaceElevated : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : textSub,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
    BuildContext context, {
    required BadgeInfo badge,
    required BadgeProgress progress,
    required bool isUnlocked,
    required bool isPinned,
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    final tierColor = badge.tier.primaryColor;

    return InkWell(
      onTap: () => _showBadgeDetailModal(
        context,
        badge: badge,
        progress: progress,
        isUnlocked: isUnlocked,
        isPinned: isPinned,
        surfaceColor: surfaceColor,
        textMain: textMain,
        textSub: textSub,
        isDark: isDark,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnlocked
              ? (isDark ? AppTheme.darkSurface : Colors.white)
              : (isDark ? AppTheme.darkSurfaceElevated.withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? tierColor.withValues(alpha: isDark ? 0.45 : 0.35)
                : borderColor.withValues(alpha: isDark ? 0.4 : 0.6),
            width: isUnlocked ? 1.3 : 1,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: tierColor.withValues(alpha: isDark ? 0.12 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Badge Icon with Tier Halo
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? tierColor.withValues(alpha: isDark ? 0.22 : 0.14)
                        : (isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05)),
                    border: Border.all(
                      color: isUnlocked
                          ? tierColor.withValues(alpha: 0.5)
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      badge.iconData,
                      size: 17,
                      color: isUnlocked ? tierColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ),
                ),
                const Spacer(),
                // Status / Pin Chip
                if (isPinned) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tierColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded, size: 9, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'Vitrin',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ] else if (isUnlocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Açık',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ] else ...[
                  Icon(Icons.lock_outline_rounded, size: 13, color: textSub.withValues(alpha: 0.6)),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Badge Name
            Text(
              badge.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isUnlocked ? textMain : textSub,
              ),
            ),
            const SizedBox(height: 2),

            // Tier & Short hint
            Text(
              '${badge.tier.label} • ${badge.category.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isUnlocked ? tierColor : textSub.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),

            // Progress Bar if locked with threshold
            if (!isUnlocked && badge.thresholdValue > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.percentage,
                  minHeight: 4,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(tierColor.withValues(alpha: 0.8)),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${progress.currentValue}/${progress.targetValue} (%${(progress.percentage * 100).toInt()})',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: textSub.withValues(alpha: 0.8),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  void _showBadgeDetailModal(
    BuildContext context, {
    required BadgeInfo badge,
    required BadgeProgress progress,
    required bool isUnlocked,
    required bool isPinned,
    required Color surfaceColor,
    required Color textMain,
    required Color textSub,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Glowing Badge Amblem
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isUnlocked
                        ? badge.tier.gradientColors
                        : [
                            isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                            isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFCBD5E1),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: badge.color.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Icon(
                    badge.iconData,
                    size: 42,
                    color: isUnlocked ? Colors.white : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tier & Category Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badge.color.withValues(alpha: 0.3), width: 1),
                ),
                child: Text(
                  '${badge.tier.label.toUpperCase()} KADEME • ${badge.category.label.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: badge.color,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Badge Name
              Text(
                badge.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: textSub,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // How to earn box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isUnlocked ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          size: 16,
                          color: isUnlocked ? const Color(0xFF10B981) : AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isUnlocked ? 'Başarım Tamamlandı' : 'Nasıl Kazanılır?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isUnlocked ? const Color(0xFF10B981) : textMain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.howToEarn,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textSub,
                        height: 1.35,
                      ),
                    ),
                    if (!isUnlocked && badge.thresholdValue > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'İlerleme:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSub),
                          ),
                          Text(
                            '${progress.currentValue} / ${progress.targetValue} (%${(progress.percentage * 100).toInt()})',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress.percentage,
                          minHeight: 6,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Pin Action or Close Button
              if (isUnlocked && widget.isOwnProfile) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final newPinned = isPinned ? null : badge.id;
                      final success = await _userService.setPinnedBadge(_user.uid, newPinned);
                      if (success && mounted) {
                        setState(() {
                          _user = _user.copyWith(pinnedBadge: newPinned);
                        });
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              isPinned
                                  ? 'Vitrin rozeti kaldırıldı'
                                  : '⭐ "${badge.name}" vitrin rozetiniz olarak ayarlandı!',
                            ),
                            backgroundColor: isPinned ? const Color(0xFF475569) : const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    icon: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 18),
                    label: Text(
                      isPinned ? 'Vitrinden Kaldır' : 'Vitrinde Göster (Profil & Yorumlar)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPinned ? const Color(0xFF475569) : badge.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text('Kapat', style: TextStyle(color: textMain, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
