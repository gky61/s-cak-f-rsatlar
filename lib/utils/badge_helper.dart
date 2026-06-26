import 'package:flutter/material.dart';

class BadgeHelper {
  // Mevcut rozetler ve özellikleri
  static const Map<String, BadgeInfo> badges = {
    'gold': BadgeInfo(
      name: 'Altın Üye',
      icon: '🥇',
      color: Color(0xFFFFD700),
      description: 'Özel üye',
    ),
    'silver': BadgeInfo(
      name: 'Gümüş Üye',
      icon: '🥈',
      color: Color(0xFFC0C0C0),
      description: 'Değerli üye',
    ),
    'bronze': BadgeInfo(
      name: 'Bronz Üye',
      icon: '🥉',
      color: Color(0xFFCD7F32),
      description: 'Aktif üye',
    ),
    'top_reviewer': BadgeInfo(
      name: 'En İyi Yorumcu',
      icon: '⭐',
      color: Color(0xFFFF6B35),
      description: 'Çok yorum yapan',
    ),
    'helpful': BadgeInfo(
      name: 'Yardımsever',
      icon: '🤝',
      color: Color(0xFF4CAF50),
      description: 'Yardımsever kullanıcı',
    ),
    'contributor': BadgeInfo(
      name: 'Katkıda Bulunan',
      icon: '🎯',
      color: Color(0xFF2196F3),
      description: 'Fırsat paylaşan',
    ),
    'verified': BadgeInfo(
      name: 'Doğrulanmış',
      icon: '✓',
      color: Color(0xFF00BCD4),
      description: 'Doğrulanmış hesap',
    ),
    'premium': BadgeInfo(
      name: 'Premium',
      icon: '💎',
      color: Color(0xFF9C27B0),
      description: 'Premium üye',
    ),
  };

  static BadgeInfo? getBadgeInfo(String badgeId) {
    // Önce tanımlı rozetleri kontrol et
    if (badges.containsKey(badgeId)) {
      return badges[badgeId];
    }
    // Tanımlı değilse, dinamik rozet oluştur (web'deki gibi)
    return BadgeInfo(
      name: badgeId, // Rozet adını direkt kullan
      icon: '🏅', // Varsayılan ikon
      color: const Color(0xFFFFA500), // Varsayılan turuncu renk
      description: badgeId, // Açıklama olarak rozet adı
    );
  }

  static List<BadgeInfo> getBadgeInfos(List<String> badgeIds) {
    return badgeIds
        .map((id) => getBadgeInfo(id))
        .where((badge) => badge != null)
        .cast<BadgeInfo>()
        .toList();
  }

  static List<String> getAllBadgeIds() {
    return badges.keys.toList();
  }
}

class BadgeInfo {
  final String name;
  final String icon;
  final Color color;
  final String description;

  const BadgeInfo({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}


