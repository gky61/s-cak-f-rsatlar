import 'package:flutter/material.dart';

/// Rozet Nadirlik ve Prestij Kademeleri
enum BadgeTier {
  bronze,
  silver,
  gold,
  diamond,
  special,
}

extension BadgeTierExtension on BadgeTier {
  String get label {
    switch (this) {
      case BadgeTier.bronze:
        return 'Bronz';
      case BadgeTier.silver:
        return 'Gümüş';
      case BadgeTier.gold:
        return 'Altın';
      case BadgeTier.diamond:
        return 'Elmas';
      case BadgeTier.special:
        return 'Özel';
    }
  }

  Color get primaryColor {
    switch (this) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFF94A3B8);
      case BadgeTier.gold:
        return const Color(0xFFF59E0B);
      case BadgeTier.diamond:
        return const Color(0xFF06B6D4);
      case BadgeTier.special:
        return const Color(0xFF8B5CF6);
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case BadgeTier.bronze:
        return [const Color(0xFFB45309), const Color(0xFFD97706)];
      case BadgeTier.silver:
        return [const Color(0xFF64748B), const Color(0xFF94A3B8)];
      case BadgeTier.gold:
        return [const Color(0xFFD97706), const Color(0xFFFBBF24)];
      case BadgeTier.diamond:
        return [const Color(0xFF0284C7), const Color(0xFF38BDF8)];
      case BadgeTier.special:
        return [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];
    }
  }
}

/// Rozet Kategorileri
enum BadgeCategory {
  dealSharing,
  temperatureVoting,
  communityReviews,
  loyaltySpecial,
}

extension BadgeCategoryExtension on BadgeCategory {
  String get label {
    switch (this) {
      case BadgeCategory.dealSharing:
        return 'Fırsat Avcılığı';
      case BadgeCategory.temperatureVoting:
        return 'Sıcaklık & Oylar';
      case BadgeCategory.communityReviews:
        return 'Topluluk & Yorum';
      case BadgeCategory.loyaltySpecial:
        return 'Sadakat & Özel';
    }
  }

  IconData get icon {
    switch (this) {
      case BadgeCategory.dealSharing:
        return Icons.local_offer_rounded;
      case BadgeCategory.temperatureVoting:
        return Icons.local_fire_department_rounded;
      case BadgeCategory.communityReviews:
        return Icons.forum_rounded;
      case BadgeCategory.loyaltySpecial:
        return Icons.verified_rounded;
    }
  }
}

/// Rozet Kazanma Eşiği Tipi
enum ThresholdType {
  dealCount,
  points,
  totalLikes,
  reputation,
  manual,
}

/// Rozet Bilgisi Modeli
class BadgeInfo {
  final String id;
  final String name;
  final String icon; // Emoji / simge fallback
  final IconData iconData; // Modern vektör ikonu
  final Color color;
  final String description;
  final String howToEarn;
  final BadgeTier tier;
  final BadgeCategory category;
  final ThresholdType thresholdType;
  final int thresholdValue;
  final bool isHiddenBeforeUnlock;

  const BadgeInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconData,
    required this.color,
    required this.description,
    required this.howToEarn,
    required this.tier,
    required this.category,
    this.thresholdType = ThresholdType.manual,
    this.thresholdValue = 0,
    this.isHiddenBeforeUnlock = false,
  });
}

/// Kullanıcının Rozetteki İlerleme Durumu
class BadgeProgress {
  final int currentValue;
  final int targetValue;
  final double percentage; // 0.0 - 1.0 arası
  final bool isUnlocked;
  final int remaining;

  const BadgeProgress({
    required this.currentValue,
    required this.targetValue,
    required this.percentage,
    required this.isUnlocked,
    required this.remaining,
  });
}
