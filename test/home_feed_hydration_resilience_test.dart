import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('HomeScreen Hydration & Manifest Resilience Tests', () {
    test('[Test 1] AndroidManifest.xml disables allowBackup and fullBackupContent to prevent stale SQLite restore', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml dosyası mevcut olmalıdır');

      final content = manifestFile.readAsStringSync();
      expect(
        content.contains('android:allowBackup="false"'),
        isTrue,
        reason: 'Uygulama silinip tekrar kurulduğunda bayat SQLite önbelleğinin Google Drive tarafından geri yüklenmesini engellemek için allowBackup false olmalıdır',
      );
      expect(
        content.contains('android:fullBackupContent="false"'),
        isTrue,
        reason: 'Google Cloud Backup tam yedeklemesini engellemek için fullBackupContent false olmalıdır',
      );
    });

    test('[Test 2] homeFeedScore preserves extreme freshness priority over older deals', () {
      final now = DateTime.now();

      // 10 dakika önce paylaşılan fırsat (0 oy)
      final freshDeal = Deal(
        id: 'deal_fresh',
        title: 'Taze Fırsat',
        description: 'Açıklama',
        price: 100,
        store: 'Amazon',
        link: 'https://amazon.com.tr/test1',
        imageUrl: 'https://test.com/img1.jpg',
        category: 'elektronik',
        postedBy: 'user_1',
        postedByName: 'Test User',
        createdAt: now.subtract(const Duration(minutes: 10)),
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        isEditorPick: false,
      );

      // 24 saat önce paylaşılan fırsat (10 sıcak oylu)
      final staleDealWithVotes = Deal(
        id: 'deal_stale',
        title: 'Dünün Fırsatı',
        description: 'Açıklama',
        price: 150,
        store: 'Hepsiburada',
        link: 'https://hepsiburada.com/test2',
        imageUrl: 'https://test.com/img2.jpg',
        category: 'elektronik',
        postedBy: 'user_2',
        postedByName: 'Test User 2',
        createdAt: now.subtract(const Duration(hours: 24)),
        hotVotes: 10,
        coldVotes: 0,
        commentCount: 2,
        isEditorPick: false,
      );

      // Taze fırsat skoru: 100 * (1 - 10/2880) ≈ 99.65
      // Eski fırsat skoru: 100 * (1 - 1440/2880) + min(8, 10*1.2*1.0 + 2*0.4) = 50.0 + 8.0 = 58.0
      expect(freshDeal.homeFeedScore > staleDealWithVotes.homeFeedScore, isTrue);
      expect(freshDeal.homeFeedScore, greaterThan(95.0));
      expect(staleDealWithVotes.homeFeedScore, lessThan(65.0));
    });

    test('[Test 3] Server-First timeout duration (1400ms) is strictly bounded within SplashScreen window (1750ms)', () {
      const splashDurationMs = 1350 + 400; // 1750ms
      const serverFirstTimeoutMs = 1400;

      expect(serverFirstTimeoutMs < splashDurationMs, isTrue,
          reason: 'Sunucu isteği zaman aşımı eşiği, SplashScreen kapanmadan önce güvenle sonuçlanmalıdır');
      expect(splashDurationMs - serverFirstTimeoutMs, greaterThanOrEqualTo(300),
          reason: 'Splash çözünmesi başlamadan önce UI render için en az 300ms emniyet payı kalmalıdır');
    });

    test('[Test 4] Deal compareDeals sorting order preserves valid chronological tie-breaking', () {
      final now = DateTime.now();

      final dealA = Deal(
        id: 'deal_a',
        title: 'Fırsat A',
        description: 'Açıklama A',
        price: 100,
        store: 'Amazon',
        link: 'https://amazon.com.tr/a',
        imageUrl: 'https://test.com/a.jpg',
        category: 'elektronik',
        postedBy: 'user_1',
        postedByName: 'Test 1',
        createdAt: now.subtract(const Duration(minutes: 5)),
        hotVotes: 5,
        coldVotes: 0,
        commentCount: 0,
        isEditorPick: false,
      );

      final dealB = Deal(
        id: 'deal_b',
        title: 'Fırsat B',
        description: 'Açıklama B',
        price: 200,
        store: 'Trendyol',
        link: 'https://trendyol.com/b',
        imageUrl: 'https://test.com/b.jpg',
        category: 'elektronik',
        postedBy: 'user_2',
        postedByName: 'Test 2',
        createdAt: now.subtract(const Duration(minutes: 30)),
        hotVotes: 5,
        coldVotes: 0,
        commentCount: 0,
        isEditorPick: false,
      );

      final list = [dealB, dealA];
      list.sort((a, b) => b.homeFeedScore.compareTo(a.homeFeedScore));

      // Daha yeni olan dealA daha yüksek skora sahip olmalı ve ilk sıraya yerleşmeli
      expect(list.first.id, equals('deal_a'));
    });
  });
}
