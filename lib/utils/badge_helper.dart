import 'package:flutter/material.dart';
import '../models/badge_model.dart';
import '../models/user.dart';

export '../models/badge_model.dart';

class BadgeHelper {
  // Kapsamlı ve zengin rozet kataloğu
  static const Map<String, BadgeInfo> badges = {
    // ─── 1. FIRSAT AVCILIĞI KATEGORİSİ ───
    'first_spark': BadgeInfo(
      id: 'first_spark',
      name: 'İlk Kıvılcım',
      icon: '🌱',
      iconData: Icons.wb_twilight_rounded,
      color: Color(0xFFCD7F32),
      tier: BadgeTier.bronze,
      category: BadgeCategory.dealSharing,
      thresholdType: ThresholdType.dealCount,
      thresholdValue: 1,
      description: 'Toplulukla ilk fırsatını paylaşan yeni avcı.',
      howToEarn: 'En az 1 adet onaylı fırsat paylaşın.',
    ),
    'hunter_apprentice': BadgeInfo(
      id: 'hunter_apprentice',
      name: 'Fırsat Çırağı',
      icon: '🏹',
      iconData: Icons.military_tech_outlined,
      color: Color(0xFF94A3B8),
      tier: BadgeTier.silver,
      category: BadgeCategory.dealSharing,
      thresholdType: ThresholdType.dealCount,
      thresholdValue: 10,
      description: 'Fırsat avcılığında deneyim kazanmaya başlayan hevesli üye.',
      howToEarn: 'Toplam 10 adet fırsat paylaşımına ulaşın.',
    ),
    'contributor': BadgeInfo(
      id: 'contributor',
      name: 'Katkıda Bulunan',
      icon: '🎯',
      iconData: Icons.track_changes_rounded,
      color: Color(0xFF2196F3),
      tier: BadgeTier.silver,
      category: BadgeCategory.dealSharing,
      thresholdType: ThresholdType.dealCount,
      thresholdValue: 20,
      description: 'Topluluğa düzenli fırsat kazandıran aktif üye.',
      howToEarn: 'Toplam 20 adet fırsat paylaşın.',
    ),
    'master_hunter': BadgeInfo(
      id: 'master_hunter',
      name: 'Usta Avcı',
      icon: '🦅',
      iconData: Icons.shield_rounded,
      color: Color(0xFFF59E0B),
      tier: BadgeTier.gold,
      category: BadgeCategory.dealSharing,
      thresholdType: ThresholdType.dealCount,
      thresholdValue: 50,
      description: 'Fırsatları kaçırmayan, platformun usta paylaşımcısı.',
      howToEarn: 'Toplam 50 adet fırsat paylaşımına ulaşın.',
    ),
    'legendary_hunter': BadgeInfo(
      id: 'legendary_hunter',
      name: 'Efsanevi Avcı',
      icon: '👑',
      iconData: Icons.workspace_premium_rounded,
      color: Color(0xFF06B6D4),
      tier: BadgeTier.diamond,
      category: BadgeCategory.dealSharing,
      thresholdType: ThresholdType.dealCount,
      thresholdValue: 150,
      description: 'FırsatKolik tarihine geçen en elit ve üretken avcılardan biri.',
      howToEarn: 'Toplam 150 adet fırsat paylaşımına ulaşın.',
    ),

    // ─── 2. SICAKLIK & OYLAR KATEGORİSİ ───
    'active_voter': BadgeInfo(
      id: 'active_voter',
      name: 'Aktif Seçmen',
      icon: '🌡️',
      iconData: Icons.how_to_vote_rounded,
      color: Color(0xFFCD7F32),
      tier: BadgeTier.bronze,
      category: BadgeCategory.temperatureVoting,
      thresholdType: ThresholdType.points,
      thresholdValue: 50,
      description: 'Fırsatların sıcaklığını belirleyen topluluk jürisi.',
      howToEarn: 'Fırsatları oylayarak en az 50 puana ulaşın.',
    ),
    'flame_master': BadgeInfo(
      id: 'flame_master',
      name: 'Alev Ustası',
      icon: '🔥',
      iconData: Icons.local_fire_department_rounded,
      color: Color(0xFFEA580C),
      tier: BadgeTier.gold,
      category: BadgeCategory.temperatureVoting,
      thresholdType: ThresholdType.points,
      thresholdValue: 150,
      description: 'Fırsatları alevlendiren ve yüksek sıcaklıklar yakalayan avcı.',
      howToEarn: 'Toplam 150 puan veya +150°C fırsat etkileşimine ulaşın.',
    ),
    'volcanic_record': BadgeInfo(
      id: 'volcanic_record',
      name: 'Volkanik Rekortmen',
      icon: '🌋',
      iconData: Icons.whatshot_rounded,
      color: Color(0xFF06B6D4),
      tier: BadgeTier.diamond,
      category: BadgeCategory.temperatureVoting,
      thresholdType: ThresholdType.points,
      thresholdValue: 500,
      description: 'Topluluğu kasıp kavuran rekor sıcaklıklara imza atan üye.',
      howToEarn: 'Toplam 500 puan veya rekor sıcaklık seviyesine ulaşın.',
    ),

    // ─── 3. TOPLULUK & YORUM KATEGORİSİ ───
    'voice_of_community': BadgeInfo(
      id: 'voice_of_community',
      name: 'Söz Sahibi',
      icon: '💬',
      iconData: Icons.chat_bubble_outline_rounded,
      color: Color(0xFFCD7F32),
      tier: BadgeTier.bronze,
      category: BadgeCategory.communityReviews,
      thresholdType: ThresholdType.points,
      thresholdValue: 35,
      description: 'Fikir ve değerlendirmeleriyle topluluğa katılan üye.',
      howToEarn: 'Yorumlar ve değerlendirmelerle en az 35 puana ulaşın.',
    ),
    'helpful': BadgeInfo(
      id: 'helpful',
      name: 'Yardımsever Avcı',
      icon: '🤝',
      iconData: Icons.volunteer_activism_rounded,
      color: Color(0xFF10B981),
      tier: BadgeTier.silver,
      category: BadgeCategory.communityReviews,
      thresholdType: ThresholdType.totalLikes,
      thresholdValue: 40,
      description: 'Soruları yanıtlayan ve diğer üyelere yardımcı olan dost canlısı avcı.',
      howToEarn: 'Yorumlarınızda veya paylaşımlarınızda 40 beğeni toplayın.',
    ),
    'top_reviewer': BadgeInfo(
      id: 'top_reviewer',
      name: 'Fikir Önderi',
      icon: '⭐',
      iconData: Icons.auto_awesome_rounded,
      color: Color(0xFFFF6B35),
      tier: BadgeTier.gold,
      category: BadgeCategory.communityReviews,
      thresholdType: ThresholdType.totalLikes,
      thresholdValue: 150,
      description: 'Yorumları ve ürün analizleriyle fırsatçılara rehberlik eden üye.',
      howToEarn: 'Toplamda 150 beğeniye veya yüksek yorum etkileşimine ulaşın.',
    ),

    // ─── 4. SADAKAT, DOĞRULAMA & ÖZEL UNVANLAR ───
    'verified': BadgeInfo(
      id: 'verified',
      name: 'Doğrulanmış Avcı',
      icon: '✓',
      iconData: Icons.verified_rounded,
      color: Color(0xFF00BCD4),
      tier: BadgeTier.special,
      category: BadgeCategory.loyaltySpecial,
      thresholdType: ThresholdType.manual,
      description: 'Topluluk güvenilirliği ve kimliği moderasyonca doğrulanmış hesap.',
      howToEarn: 'Moderasyon ekibi tarafından doğrulanmış avcılara verilir.',
    ),
    'early_bird': BadgeInfo(
      id: 'early_bird',
      name: 'Öncü Kurucu Üye',
      icon: '🚀',
      iconData: Icons.rocket_launch_rounded,
      color: Color(0xFF8B5CF6),
      tier: BadgeTier.special,
      category: BadgeCategory.loyaltySpecial,
      thresholdType: ThresholdType.manual,
      description: 'FırsatKolik\'in ilk döneminde aramıza katılan öncü topluluk üyesi.',
      howToEarn: 'Platformun ilk açılış döneminde üye olan kullanıcılara verilir.',
    ),
    'premium': BadgeInfo(
      id: 'premium',
      name: 'Premium',
      icon: '💎',
      iconData: Icons.diamond_rounded,
      color: Color(0xFF9C27B0),
      tier: BadgeTier.special,
      category: BadgeCategory.loyaltySpecial,
      thresholdType: ThresholdType.manual,
      description: 'Özel avantajlara ve prestijli statüye sahip üye.',
      howToEarn: 'Özel topluluk etkinlikleri veya üyelik programı ile kazanılır.',
    ),
    'gold': BadgeInfo(
      id: 'gold',
      name: 'Altın Avcı',
      icon: '🥇',
      iconData: Icons.military_tech_rounded,
      color: Color(0xFFFFD700),
      tier: BadgeTier.gold,
      category: BadgeCategory.loyaltySpecial,
      thresholdType: ThresholdType.points,
      thresholdValue: 300,
      description: 'Platformun en saygın ve yüksek puanlı üyelerinden biri.',
      howToEarn: 'Toplam 300 puana ulaşın.',
    ),
    'silver': BadgeInfo(
      id: 'silver',
      name: 'Gümüş Avcı',
      icon: '🥈',
      iconData: Icons.military_tech_rounded,
      color: Color(0xFFC0C0C0),
      tier: BadgeTier.silver,
      category: BadgeCategory.loyaltySpecial,
      thresholdType: ThresholdType.points,
      thresholdValue: 100,
      description: 'Platformda aktifliğiyle öne çıkan değerli üye.',
      howToEarn: 'Toplam 100 puana ulaşın.',
    ),
    'bronze': BadgeInfo(
      id: 'bronze',
      name: 'Bronz Avcı',
      icon: '🥉',
      iconData: Icons.military_tech_rounded,
      color: Color(0xFFCD7F32),
      tier: BadgeTier.bronze,
      category: BadgeCategory.loyaltySpecial,
      thresholdType: ThresholdType.points,
      thresholdValue: 15,
      description: 'FırsatKolik yolculuğuna başlayan aktif üye.',
      howToEarn: 'Toplam 15 puana ulaşın.',
    ),
  };

  /// Rozet ID'sine göre BadgeInfo döndürür
  static BadgeInfo? getBadgeInfo(String badgeId) {
    if (badges.containsKey(badgeId)) {
      return badges[badgeId];
    }
    // Tanımlı değilse fallback dinamik rozet
    return BadgeInfo(
      id: badgeId,
      name: badgeId,
      icon: '🏅',
      iconData: Icons.military_tech_rounded,
      color: const Color(0xFFFFA500),
      tier: BadgeTier.bronze,
      category: BadgeCategory.loyaltySpecial,
      description: badgeId,
      howToEarn: 'Özel topluluk rozeti.',
    );
  }

  /// Liste halindeki rozet ID'lerini BadgeInfo listesine çevirir
  static List<BadgeInfo> getBadgeInfos(List<String> badgeIds) {
    return badgeIds
        .map((id) => getBadgeInfo(id))
        .where((badge) => badge != null)
        .cast<BadgeInfo>()
        .toList();
  }

  /// Tüm kayıtlı rozet ID'lerini döndürür
  static List<String> getAllBadgeIds() {
    return badges.keys.toList();
  }

  /// Belirli bir kategoriye ait rozetleri döndürür
  static List<BadgeInfo> getBadgesByCategory(BadgeCategory? category) {
    if (category == null) return badges.values.toList();
    return badges.values.where((b) => b.category == category).toList();
  }

  /// Kullanıcının belirli bir rozetteki ilerlemesini hesaplar
  static BadgeProgress calculateProgress(AppUser user, BadgeInfo badge) {
    final isUnlocked = user.badges.contains(badge.id);

    int current = 0;
    int target = badge.thresholdValue;

    switch (badge.thresholdType) {
      case ThresholdType.dealCount:
        current = user.dealCount;
        break;
      case ThresholdType.points:
        current = user.points;
        break;
      case ThresholdType.totalLikes:
        current = user.totalLikes;
        break;
      case ThresholdType.reputation:
        current = user.trustStars;
        break;
      case ThresholdType.manual:
        current = isUnlocked ? 1 : 0;
        target = 1;
        break;
    }

    if (target <= 0) {
      return BadgeProgress(
        currentValue: isUnlocked ? 1 : 0,
        targetValue: 1,
        percentage: isUnlocked ? 1.0 : 0.0,
        isUnlocked: isUnlocked,
        remaining: isUnlocked ? 0 : 1,
      );
    }

    final double pct = isUnlocked
        ? 1.0
        : (current / target).clamp(0.0, 1.0);
    final int remaining = isUnlocked ? 0 : (target - current).clamp(0, target);

    return BadgeProgress(
      currentValue: current,
      targetValue: target,
      percentage: pct,
      isUnlocked: isUnlocked,
      remaining: remaining,
    );
  }

  /// Kullanıcının mevcut istatistiklerine göre hak ettiği tüm rozet ID'lerini hesaplar
  static List<String> evaluateEligibleBadges(AppUser user) {
    final List<String> eligible = List.from(user.badges);

    for (final badge in badges.values) {
      if (badge.thresholdType == ThresholdType.manual) continue;

      bool qualifies = false;
      switch (badge.thresholdType) {
        case ThresholdType.dealCount:
          qualifies = user.dealCount >= badge.thresholdValue;
          break;
        case ThresholdType.points:
          qualifies = user.points >= badge.thresholdValue;
          break;
        case ThresholdType.totalLikes:
          qualifies = user.totalLikes >= badge.thresholdValue;
          break;
        case ThresholdType.reputation:
          qualifies = user.trustStars >= badge.thresholdValue;
          break;
        case ThresholdType.manual:
          break;
      }

      if (qualifies && !eligible.contains(badge.id)) {
        eligible.add(badge.id);
      }
    }

    return eligible;
  }
}
