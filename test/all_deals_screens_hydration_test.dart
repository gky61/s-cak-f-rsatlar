import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('All Deal Feeds Hydration & Single-Flight Consistency Tests', () {
    test('[Test 1] AndroidManifest.xml disables backup to eliminate stale SQLite cold-start restore', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content.contains('android:allowBackup="false"'), isTrue,
          reason: 'allowBackup false olmalıdır');
      expect(content.contains('android:fullBackupContent="false"'), isTrue,
          reason: 'fullBackupContent false olmalıdır');
    });

    test('[Test 2] PopularDealsScreen implements Server-First Single-Flight Hydration with 1400ms timeout', () {
      final popFile = File('lib/screens/popular_deals_screen.dart');
      expect(popFile.existsSync(), isTrue);

      final content = popFile.readAsStringSync();
      expect(content.contains('_serverTimeout = Duration(milliseconds: 1400)'), isTrue,
          reason: 'PopularDealsScreen 1400ms timeout süresine sahip olmalıdır');
      expect(content.contains('_activeServerFuture'), isTrue,
          reason: 'PopularDealsScreen Single-Flight kalkanına sahip olmalıdır');
      expect(content.contains('_attachBackgroundServerListener'), isTrue,
          reason: 'PopularDealsScreen Scroll-Aware arka plan dinleyicisine sahip olmalıdır');
    });

    test('[Test 3] FavoritesScreen (Followed Categories) implements Server-First Single-Flight Hydration with 1400ms timeout', () {
      final favFile = File('lib/screens/favorites_screen.dart');
      expect(favFile.existsSync(), isTrue);

      final content = favFile.readAsStringSync();
      expect(content.contains('_followedServerTimeout = Duration(milliseconds: 1400)'), isTrue,
          reason: 'FavoritesScreen 1400ms timeout süresine sahip olmalıdır');
      expect(content.contains('_activeFollowedServerFuture'), isTrue,
          reason: 'FavoritesScreen Single-Flight kalkanına sahip olmalıdır');
      expect(content.contains('_attachBackgroundFollowedServerListener'), isTrue,
          reason: 'FavoritesScreen Scroll-Aware arka plan dinleyicisine sahip olmalıdır');
    });

    test('[Test 4] HomeScreen retains Server-First Single-Flight Hydration', () {
      final homeFile = File('lib/screens/home_screen.dart');
      expect(homeFile.existsSync(), isTrue);

      final content = homeFile.readAsStringSync();
      expect(content.contains('serverFuture.timeout(const Duration(milliseconds: 1400))'), isTrue,
          reason: 'HomeScreen 1400ms timeout ile korunmalıdır');
      expect(content.contains('Source.server'), isTrue);
      expect(content.contains('Source.cache'), isTrue);
    });

    test('[Test 5] Popularity score sorting and Home feed score sorting are mutually orthogonal and mathematically sound', () {
      final now = DateTime.now();

      final highVotesOldDeal = Deal(
        id: 'deal_pop_old',
        title: 'Eski Ama Çok Popüler',
        description: 'Açıklama',
        price: 500,
        store: 'Amazon',
        link: 'https://amazon.com.tr/test_pop',
        imageUrl: 'https://test.com/pop.jpg',
        category: 'elektronik',
        postedBy: 'user_pop',
        postedByName: 'Pop User',
        createdAt: now.subtract(const Duration(hours: 6)),
        hotVotes: 30,
        coldVotes: 1,
        commentCount: 15,
        isEditorPick: false,
      );

      final freshZeroVotesDeal = Deal(
        id: 'deal_fresh_new',
        title: 'Çok Taze Fırsat',
        description: 'Açıklama',
        price: 200,
        store: 'Trendyol',
        link: 'https://trendyol.com/test_fresh',
        imageUrl: 'https://test.com/fresh.jpg',
        category: 'elektronik',
        postedBy: 'user_fresh',
        postedByName: 'Fresh User',
        createdAt: now.subtract(const Duration(minutes: 5)),
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        isEditorPick: false,
      );

      // Ana sayfada (Home Feed) 5 dakikalık taze fırsat üstte çıkmalıdır
      expect(freshZeroVotesDeal.homeFeedScore > highVotesOldDeal.homeFeedScore, isTrue,
          reason: 'Home Feed en taze içeriğe öncelik vermelidir');

      // Popüler sekmesinde (Popular Deals) 85 oylu popüler fırsat üstte çıkmalıdır
      expect(highVotesOldDeal.popularityScore > freshZeroVotesDeal.popularityScore, isTrue,
          reason: 'Popüler sekmesi yüksek ilgi gören fırsatlara öncelik vermelidir');
    });
  });
}
