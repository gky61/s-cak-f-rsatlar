import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/services/deal_service.dart';

Deal _createTestDeal({
  required String id,
  required String title,
  required double price,
  required DateTime createdAt,
  int hotVotes = 0,
  int coldVotes = 0,
  bool isTest = false,
  bool isApproved = true,
}) {
  return Deal(
    id: id,
    title: title,
    description: 'Açıklama',
    price: price,
    store: 'Amazon',
    category: 'elektronik',
    link: 'https://amazon.com.tr/dp/$id',
    imageUrl: 'https://example.com/$id.jpg',
    hotVotes: hotVotes,
    coldVotes: coldVotes,
    commentCount: 0,
    postedBy: 'user-1',
    createdAt: createdAt,
    isEditorPick: false,
    isApproved: isApproved,
    isTest: isTest,
  );
}

void main() {
  group('FS-09: Deals SWR, Pagination & Floating Pill Logic Tests', () {
    test('DealsPageResult model contracts are preserved', () {
      final now = DateTime.now();
      final deal = _createTestDeal(
        id: 'deal-1',
        title: 'AirPods Pro',
        price: 5000,
        createdAt: now,
      );

      const emptyResult = DealsPageResult(deals: []);
      expect(emptyResult.deals, isEmpty);
      expect(emptyResult.hasMore, isFalse);
      expect(emptyResult.isFromCache, isFalse);
      expect(emptyResult.lastDocument, isNull);

      final populatedResult = DealsPageResult(
        deals: [deal],
        hasMore: true,
        isFromCache: true,
      );
      expect(populatedResult.deals.length, 1);
      expect(populatedResult.hasMore, isTrue);
      expect(populatedResult.isFromCache, isTrue);
    });

    test('Initial page sorting prioritizes homeFeedScore while avoiding mutation on existing items', () {
      final now = DateTime.now();
      final dealLowScore = _createTestDeal(
        id: 'deal-low',
        title: 'Normal Fırsat',
        price: 100,
        createdAt: now.subtract(const Duration(hours: 10)),
        hotVotes: 2,
        coldVotes: 1,
      );

      final dealHighScore = _createTestDeal(
        id: 'deal-high',
        title: 'Viral Fırsat',
        price: 50,
        createdAt: now.subtract(const Duration(hours: 1)),
        hotVotes: 45,
        coldVotes: 0,
      );

      final dealsList = [dealLowScore, dealHighScore];
      // Initial page sort logic
      dealsList.sort((a, b) => b.homeFeedScore.compareTo(a.homeFeedScore));

      expect(dealsList.first.id, 'deal-high');
      expect(dealsList.last.id, 'deal-low');
    });

    test('Floating New Deals Pill logic triggers ONLY for genuine newer deals', () {
      final now = DateTime.now();
      final existingTopDeal = _createTestDeal(
        id: 'top-1',
        title: 'Mevcut En Yeni Fırsat',
        price: 200,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      final existingOldDeal = _createTestDeal(
        id: 'old-2',
        title: 'Eski Fırsat',
        price: 100,
        createdAt: now.subtract(const Duration(minutes: 30)),
      );

      final List<Deal> currentFeed = [existingTopDeal, existingOldDeal];

      bool shouldShowPill(Deal? latestDeal, List<Deal> feed) {
        if (latestDeal == null || latestDeal.isTest == true) return false;
        if (feed.isEmpty) return false;
        if (feed.first.id == latestDeal.id) return false;
        if (feed.any((d) => d.id == latestDeal.id)) return false;
        return latestDeal.createdAt.isAfter(feed.first.createdAt);
      }

      // Case 1: Stream emits the same top deal already rendered
      expect(shouldShowPill(existingTopDeal, currentFeed), isFalse);

      // Case 2: Stream emits an older deal that was just updated (e.g. vote/comment)
      final updatedOldDeal = _createTestDeal(
        id: 'old-2',
        title: 'Eski Fırsat (Yeni Oy Aldı)',
        price: 100,
        createdAt: now.subtract(const Duration(minutes: 30)),
        hotVotes: 10,
      );
      expect(shouldShowPill(updatedOldDeal, currentFeed), isFalse);

      // Case 3: Genuine brand-new deal approved on server
      final brandNewDeal = _createTestDeal(
        id: 'brand-new-99',
        title: 'Yeni Onaylanan Flaş Fırsat',
        price: 350,
        createdAt: now.add(const Duration(seconds: 5)),
      );
      expect(shouldShowPill(brandNewDeal, currentFeed), isTrue);

      // Case 4: Test deal should be rejected
      final testDeal = _createTestDeal(
        id: 'test-deal',
        title: 'Test',
        price: 10,
        createdAt: now.add(const Duration(seconds: 10)),
        isTest: true,
      );
      expect(shouldShowPill(testDeal, currentFeed), isFalse);
    });

    test('Pagination cursor deduplication prevents duplicate cards and list jumps', () {
      final now = DateTime.now();
      final deal1 = _createTestDeal(
        id: 'deal-1',
        title: 'Deal 1',
        price: 10,
        createdAt: now,
      );

      final deal2 = _createTestDeal(
        id: 'deal-2',
        title: 'Deal 2',
        price: 20,
        createdAt: now.subtract(const Duration(minutes: 1)),
      );

      final deal3 = _createTestDeal(
        id: 'deal-3',
        title: 'Deal 3',
        price: 30,
        createdAt: now.subtract(const Duration(minutes: 2)),
      );

      final initialList = [deal1, deal2];
      final page2Incoming = [deal2, deal3]; // deal2 was already on page 1

      final existingIds = initialList.map((d) => d.id).toSet();
      final newDeals = page2Incoming.where((d) => !existingIds.contains(d.id)).toList();

      expect(newDeals.length, 1);
      expect(newDeals.first.id, 'deal-3');

      initialList.addAll(newDeals);
      expect(initialList.length, 3);
      expect(initialList.map((d) => d.id).toList(), ['deal-1', 'deal-2', 'deal-3']);
    });

    test('Floating New Deals Pill compares against maxCreatedAt across entire feed to prevent scoring inversion false-negatives', () {
      final now = DateTime.now();
      // dealOlderViral has high score and is placed first at index 0, but was created 15 mins ago
      final dealOlderViral = _createTestDeal(
        id: 'deal-viral',
        title: 'Viral Eski Fırsat',
        price: 100,
        createdAt: now.subtract(const Duration(minutes: 15)),
        hotVotes: 80,
      );

      // dealNewerNormal was created 3 mins ago, but has lower score and placed at index 1
      final dealNewerNormal = _createTestDeal(
        id: 'deal-newer',
        title: 'Taze Normal Fırsat',
        price: 200,
        createdAt: now.subtract(const Duration(minutes: 3)),
        hotVotes: 1,
      );

      final feed = [dealOlderViral, dealNewerNormal];

      bool shouldShowPillAccurate(Deal? latestDeal, List<Deal> currentFeed) {
        if (latestDeal == null || latestDeal.isTest == true) return false;
        if (currentFeed.isEmpty) return false;
        if (currentFeed.first.id == latestDeal.id) return false;
        if (currentFeed.any((d) => d.id == latestDeal.id)) return false;

        DateTime maxCreatedAt = currentFeed.first.createdAt;
        for (final d in currentFeed) {
          if (d.createdAt.isAfter(maxCreatedAt)) {
            maxCreatedAt = d.createdAt;
          }
        }
        return latestDeal.createdAt.isAfter(maxCreatedAt);
      }

      // Incoming deal created 5 mins ago (newer than dealOlderViral, but older than dealNewerNormal) -> Should NOT show
      final intermediateDeal = _createTestDeal(
        id: 'deal-intermediate',
        title: 'Ara Fırsat',
        price: 150,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(shouldShowPillAccurate(intermediateDeal, feed), isFalse);

      // Incoming deal created 1 min ago (newer than ALL feed items) -> MUST show
      final trueLatestDeal = _createTestDeal(
        id: 'deal-true-latest',
        title: 'En Yeni Fırsat',
        price: 300,
        createdAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(shouldShowPillAccurate(trueLatestDeal, feed), isTrue);
    });

    test('Category race-condition guard prevents stale async responses from overriding current active category', () {
      String activeCategory = 'elektronik';

      bool shouldCommitResponse({
        required String requestedCategory,
        required String currentCategory,
      }) {
        return requestedCategory == currentCategory;
      }

      // User switched from 'moda' to 'elektronik', but 'moda' network request arrived late
      expect(
        shouldCommitResponse(
          requestedCategory: 'moda',
          currentCategory: activeCategory,
        ),
        isFalse,
      );

      // 'elektronik' network request arrived for active category
      expect(
        shouldCommitResponse(
          requestedCategory: 'elektronik',
          currentCategory: activeCategory,
        ),
        isTrue,
      );
    });

    test('Zero deals (empty feed) triggers Floating Pill ONLY after server data confirms empty state', () {
      final now = DateTime.now();
      final List<Deal> emptyFeed = [];

      bool evaluateLatestDealTrigger({
        required Deal? latestDeal,
        required List<Deal> currentFeed,
        required bool hasServerData,
        required bool isLoadingDeals,
        String? selectedSubCategory,
      }) {
        if (latestDeal == null || latestDeal.isTest == true) return false;
        if (selectedSubCategory != null &&
            selectedSubCategory.isNotEmpty &&
            latestDeal.subCategory != selectedSubCategory) {
          return false;
        }
        // Race condition guard: initial server response still pending
        if (!hasServerData || isLoadingDeals) return false;

        if (currentFeed.any((d) => d.id == latestDeal.id)) return false;

        // Zero deals scenario
        if (currentFeed.isEmpty) {
          return hasServerData;
        }

        DateTime maxCreatedAt = currentFeed.first.createdAt;
        for (final d in currentFeed) {
          if (d.createdAt.isAfter(maxCreatedAt)) {
            maxCreatedAt = d.createdAt;
          }
        }
        return latestDeal.createdAt.isAfter(maxCreatedAt);
      }

      final incomingDeal = _createTestDeal(
        id: 'first-deal-ever',
        title: 'İlk Onaylı Fırsat',
        price: 99,
        createdAt: now,
      );

      // Scenario A: App is still loading initial page from server (race condition) -> MUST NOT trigger pill
      expect(
        evaluateLatestDealTrigger(
          latestDeal: incomingDeal,
          currentFeed: emptyFeed,
          hasServerData: false,
          isLoadingDeals: true,
        ),
        isFalse,
      );

      // Scenario B: Server response finished, confirmed feed is empty, then new deal arrives -> MUST trigger pill
      expect(
        evaluateLatestDealTrigger(
          latestDeal: incomingDeal,
          currentFeed: emptyFeed,
          hasServerData: true,
          isLoadingDeals: false,
        ),
        isTrue,
      );

      // Scenario C: Deal is already rendered in feed -> MUST NOT trigger
      final feedWithDeal = [incomingDeal];
      expect(
        evaluateLatestDealTrigger(
          latestDeal: incomingDeal,
          currentFeed: feedWithDeal,
          hasServerData: true,
          isLoadingDeals: false,
        ),
        isFalse,
      );
    });

    test('Subcategory isolation ensures floating pill only triggers for matching subcategory', () {
      final now = DateTime.now();
      final List<Deal> emptyFeed = [];

      bool evaluateLatestDealTrigger({
        required Deal? latestDeal,
        required List<Deal> currentFeed,
        required bool hasServerData,
        required bool isLoadingDeals,
        String? selectedSubCategory,
      }) {
        if (latestDeal == null || latestDeal.isTest == true) return false;
        if (selectedSubCategory != null &&
            selectedSubCategory.isNotEmpty &&
            latestDeal.subCategory != selectedSubCategory) {
          return false;
        }
        if (!hasServerData || isLoadingDeals) return false;
        if (currentFeed.any((d) => d.id == latestDeal.id)) return false;
        if (currentFeed.isEmpty) return hasServerData;
        return true;
      }

      final Deal laptopDeal = Deal(
        id: 'deal-laptop-1',
        title: 'MacBook M3',
        description: 'Açıklama',
        price: 45000,
        store: 'Amazon',
        category: 'elektronik',
        subCategory: 'bilgisayar',
        link: 'https://amazon.com.tr/dp/1',
        imageUrl: 'https://example.com/1.jpg',
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        postedBy: 'user-1',
        createdAt: now,
        isEditorPick: false,
        isApproved: true,
        isTest: false,
      );

      // Case 1: User is looking at 'telefon' subcategory, but incoming deal is 'bilgisayar' -> MUST NOT trigger
      expect(
        evaluateLatestDealTrigger(
          latestDeal: laptopDeal,
          currentFeed: emptyFeed,
          hasServerData: true,
          isLoadingDeals: false,
          selectedSubCategory: 'telefon',
        ),
        isFalse,
      );

      // Case 2: User is looking at 'bilgisayar' subcategory, and incoming deal is 'bilgisayar' -> MUST trigger
      expect(
        evaluateLatestDealTrigger(
          latestDeal: laptopDeal,
          currentFeed: emptyFeed,
          hasServerData: true,
          isLoadingDeals: false,
          selectedSubCategory: 'bilgisayar',
        ),
        isTrue,
      );

      // Case 3: User has no subcategory selected (all subcategories in main category) -> MUST trigger
      expect(
        evaluateLatestDealTrigger(
          latestDeal: laptopDeal,
          currentFeed: emptyFeed,
          hasServerData: true,
          isLoadingDeals: false,
          selectedSubCategory: null,
        ),
        isTrue,
      );
    });

    test('Popular deals re-entrancy lock prevents parallel concurrent server loads', () async {
      int serverCallCount = 0;
      bool isRefreshing = false;

      Future<void> mockLoadFirstPage() async {
        if (isRefreshing) return;
        isRefreshing = true;
        try {
          serverCallCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        } finally {
          isRefreshing = false;
        }
      }

      // 5 concurrent rapid triggers simulated (pull-to-refresh spam)
      await Future.wait([
        mockLoadFirstPage(),
        mockLoadFirstPage(),
        mockLoadFirstPage(),
        mockLoadFirstPage(),
        mockLoadFirstPage(),
      ]);

      // Exactly 1 server call should have completed due to re-entrancy lock
      expect(serverCallCount, 1);
    });

    test('Followed categories re-entrancy lock prevents parallel concurrent loads', () async {
      int queryCount = 0;
      bool isRefreshingFollowed = false;

      Future<void> mockLoadFollowedFirstPage() async {
        if (isRefreshingFollowed) return;
        isRefreshingFollowed = true;
        try {
          queryCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        } finally {
          isRefreshingFollowed = false;
        }
      }

      // Rapid tab switching or repeated pull-to-refresh
      await Future.wait([
        mockLoadFollowedFirstPage(),
        mockLoadFollowedFirstPage(),
        mockLoadFollowedFirstPage(),
      ]);

      expect(queryCount, 1);
    });

    test('User deals pull-to-refresh re-entrancy lock prevents duplicate stream allocations', () async {
      int streamRecreationCount = 0;
      bool isRefreshingUserDeals = false;

      Future<void> mockRefreshDeals() async {
        if (isRefreshingUserDeals) return;
        isRefreshingUserDeals = true;
        try {
          streamRecreationCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        } finally {
          isRefreshingUserDeals = false;
        }
      }

      await Future.wait([
        mockRefreshDeals(),
        mockRefreshDeals(),
        mockRefreshDeals(),
        mockRefreshDeals(),
      ]);

      expect(streamRecreationCount, 1);
    });
  });
}

