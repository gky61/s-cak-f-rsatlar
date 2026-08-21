import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/user.dart';
import 'package:sicak_firsatlar/utils/badge_helper.dart';

void main() {
  group('Avcı Rozetleri & Gamification Mantık Testleri', () {
    test('Yeni kayıtlı bir kullanıcı için başlangıç ilerlemeleri doğru hesaplanmalı', () {
      final user = AppUser(
        uid: 'user_1',
        username: 'AcemiAvci',
        profileImageUrl: '',
        dealCount: 0,
        points: 0,
        totalLikes: 0,
        badges: [],
      );

      final firstSparkBadge = BadgeHelper.getBadgeInfo('first_spark')!;
      final progressFirst = BadgeHelper.calculateProgress(user, firstSparkBadge);

      expect(progressFirst.isUnlocked, isFalse);
      expect(progressFirst.currentValue, 0);
      expect(progressFirst.targetValue, 1);
      expect(progressFirst.percentage, 0.0);
      expect(progressFirst.remaining, 1);

      final masterHunterBadge = BadgeHelper.getBadgeInfo('master_hunter')!;
      final progressMaster = BadgeHelper.calculateProgress(user, masterHunterBadge);

      expect(progressMaster.isUnlocked, isFalse);
      expect(progressMaster.currentValue, 0);
      expect(progressMaster.targetValue, 25);
      expect(progressMaster.percentage, 0.0);
      expect(progressMaster.remaining, 25);
    });

    test('Kısmi ilerleme (Örn: 10/25 Fırsat) doğru yüzde ve kalan üretmeli', () {
      final user = AppUser(
        uid: 'user_2',
        username: 'HevesliAvci',
        profileImageUrl: '',
        dealCount: 10,
        points: 45,
        totalLikes: 15,
        badges: ['first_spark', 'hunter_apprentice', 'contributor'],
      );

      final masterHunterBadge = BadgeHelper.getBadgeInfo('master_hunter')!;
      final progress = BadgeHelper.calculateProgress(user, masterHunterBadge);

      expect(progress.isUnlocked, isFalse);
      expect(progress.currentValue, 10);
      expect(progress.targetValue, 25);
      expect(progress.percentage, 0.4); // %40
      expect(progress.remaining, 15);
    });

    test('Kazanılmış rozetler %100 ve isUnlocked = true dönmeli', () {
      final user = AppUser(
        uid: 'user_3',
        username: 'UstaAvci',
        profileImageUrl: '',
        dealCount: 28,
        points: 120,
        totalLikes: 60,
        badges: ['first_spark', 'hunter_apprentice', 'contributor', 'master_hunter', 'flame_master'],
      );

      final masterHunterBadge = BadgeHelper.getBadgeInfo('master_hunter')!;
      final progress = BadgeHelper.calculateProgress(user, masterHunterBadge);

      expect(progress.isUnlocked, isTrue);
      expect(progress.percentage, 1.0);
      expect(progress.remaining, 0);
    });

    test('evaluateEligibleBadges eşikleri aşan tüm rozetleri listelemeli', () {
      final user = AppUser(
        uid: 'user_4',
        username: 'AktifAvci',
        profileImageUrl: '',
        dealCount: 6, // first_spark (1), hunter_apprentice (5) hak eder
        points: 35,   // bronze (10), voice_of_community (20), active_voter (30) hak eder
        totalLikes: 26, // helpful (25) hak eder
        badges: [],
      );

      final eligible = BadgeHelper.evaluateEligibleBadges(user);

      expect(eligible.contains('first_spark'), isTrue);
      expect(eligible.contains('hunter_apprentice'), isTrue);
      expect(eligible.contains('bronze'), isTrue);
      expect(eligible.contains('voice_of_community'), isTrue);
      expect(eligible.contains('active_voter'), isTrue);
      expect(eligible.contains('helpful'), isTrue);

      // Henüz hak edilmeyenler
      expect(eligible.contains('master_hunter'), isFalse); // 25 fırsat gerekir
      expect(eligible.contains('legendary_hunter'), isFalse); // 100 fırsat gerekir
      expect(eligible.contains('volcanic_record'), isFalse); // 300 puan gerekir
    });

    test('Kategori filtreleme doğru rozet sayılarını döndürmeli', () {
      final dealBadges = BadgeHelper.getBadgesByCategory(BadgeCategory.dealSharing);
      final tempBadges = BadgeHelper.getBadgesByCategory(BadgeCategory.temperatureVoting);
      final communityBadges = BadgeHelper.getBadgesByCategory(BadgeCategory.communityReviews);
      final loyaltyBadges = BadgeHelper.getBadgesByCategory(BadgeCategory.loyaltySpecial);

      expect(dealBadges.isNotEmpty, isTrue);
      expect(tempBadges.isNotEmpty, isTrue);
      expect(communityBadges.isNotEmpty, isTrue);
      expect(loyaltyBadges.isNotEmpty, isTrue);

      final totalCategorized = dealBadges.length + tempBadges.length + communityBadges.length + loyaltyBadges.length;
      expect(totalCategorized, BadgeHelper.badges.length);
    });
  });
}
