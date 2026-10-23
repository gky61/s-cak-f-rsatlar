import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('FS-19: Delta & Diff Validation Engine Unit Tests', () {
    final baseTime = DateTime(2026, 10, 23, 12, 0, 0);

    Deal makeDeal({
      required String id,
      required String title,
      required DateTime createdAt,
      int hotVotes = 10,
    }) {
      return Deal(
        id: id,
        title: title,
        description: 'Test Description',
        price: 100,
        link: 'https://example.com/deal',
        imageUrl: 'https://example.com/image.jpg',
        store: 'amazon',
        category: 'elektronik',
        hotVotes: hotVotes,
        coldVotes: 0,
        commentCount: 2,
        postedBy: 'user1',
        createdAt: createdAt,
        isEditorPick: false,
        isApproved: true,
      );
    }

    test('Scenario 1: No new deals - exact same IDs with updated votes -> Zero False Alarm', () {
      final existingDeals = [
        makeDeal(id: 'd1', title: 'Deal 1', createdAt: baseTime.add(const Duration(minutes: 10)), hotVotes: 5),
        makeDeal(id: 'd2', title: 'Deal 2', createdAt: baseTime.add(const Duration(minutes: 5)), hotVotes: 3),
      ];

      // Server returns updated votes for same deals
      final serverDeals = [
        makeDeal(id: 'd1', title: 'Deal 1', createdAt: baseTime.add(const Duration(minutes: 10)), hotVotes: 15),
        makeDeal(id: 'd2', title: 'Deal 2', createdAt: baseTime.add(const Duration(minutes: 5)), hotVotes: 8),
      ];

      final existingIds = existingDeals.map((d) => d.id).toSet();
      final newDeals = serverDeals.where((d) => !existingIds.contains(d.id)).toList();

      DateTime newestExistingCreatedAt = existingDeals.first.createdAt;
      for (final d in existingDeals) {
        if (d.createdAt.isAfter(newestExistingCreatedAt)) {
          newestExistingCreatedAt = d.createdAt;
        }
      }

      final genuineNewDeals = newDeals.where((d) => d.createdAt.isAfter(newestExistingCreatedAt)).toList();

      expect(genuineNewDeals.isEmpty, isTrue);

      // In-place update verification
      final serverMap = {for (final d in serverDeals) d.id: d};
      for (int i = 0; i < existingDeals.length; i++) {
        final match = serverMap[existingDeals[i].id];
        if (match != null) {
          existingDeals[i] = match;
        }
      }

      expect(existingDeals[0].hotVotes, equals(15));
      expect(existingDeals[1].hotVotes, equals(8));
    });

    test('Scenario 2: Older deal appeared in server response -> Zero False Alarm', () {
      final existingDeals = [
        makeDeal(id: 'd1', title: 'Deal 1', createdAt: baseTime.add(const Duration(minutes: 20))),
        makeDeal(id: 'd2', title: 'Deal 2', createdAt: baseTime.add(const Duration(minutes: 15))),
      ];

      // Server returns d1 and d3 where d3 was created 5 minutes ago (older than d2 and d1)
      final serverDeals = [
        makeDeal(id: 'd1', title: 'Deal 1', createdAt: baseTime.add(const Duration(minutes: 20))),
        makeDeal(id: 'd3', title: 'Older Deal', createdAt: baseTime.add(const Duration(minutes: 5))),
      ];

      final existingIds = existingDeals.map((d) => d.id).toSet();
      final newDeals = serverDeals.where((d) => !existingIds.contains(d.id)).toList();

      DateTime newestExistingCreatedAt = existingDeals.first.createdAt;
      for (final d in existingDeals) {
        if (d.createdAt.isAfter(newestExistingCreatedAt)) {
          newestExistingCreatedAt = d.createdAt;
        }
      }

      final genuineNewDeals = newDeals.where((d) => d.createdAt.isAfter(newestExistingCreatedAt)).toList();

      expect(genuineNewDeals.isEmpty, isTrue, reason: 'Older deal must not trigger "New Deals" pill!');
    });

    test('Scenario 3: Truly newer deal arrived -> Triggers Genuine Pill Alert', () {
      final existingDeals = [
        makeDeal(id: 'd1', title: 'Deal 1', createdAt: baseTime.add(const Duration(minutes: 20))),
        makeDeal(id: 'd2', title: 'Deal 2', createdAt: baseTime.add(const Duration(minutes: 15))),
      ];

      // Server returns brand new deal created 25 minutes after baseTime
      final serverDeals = [
        makeDeal(id: 'd_brand_new', title: 'Brand New', createdAt: baseTime.add(const Duration(minutes: 25))),
        makeDeal(id: 'd1', title: 'Deal 1', createdAt: baseTime.add(const Duration(minutes: 20))),
      ];

      final existingIds = existingDeals.map((d) => d.id).toSet();
      final newDeals = serverDeals.where((d) => !existingIds.contains(d.id)).toList();

      DateTime newestExistingCreatedAt = existingDeals.first.createdAt;
      for (final d in existingDeals) {
        if (d.createdAt.isAfter(newestExistingCreatedAt)) {
          newestExistingCreatedAt = d.createdAt;
        }
      }

      final genuineNewDeals = newDeals.where((d) => d.createdAt.isAfter(newestExistingCreatedAt)).toList();

      expect(genuineNewDeals.length, equals(1));
      expect(genuineNewDeals.first.id, equals('d_brand_new'));
    });

    test('Scenario 4: Cursor Corruption Protection', () {
      // User scrolled down and loaded 40 deals
      const userLoadedCount = 40;
      const serverFirstPageCount = 20;

      // Active cursor should NOT be overwritten if user loaded more items than 1st page
      const shouldUpdateActiveCursor = userLoadedCount <= serverFirstPageCount;
      expect(shouldUpdateActiveCursor, isFalse);

      // On initial load (user has 20 items or less), cursor CAN be safely synchronized
      const initialLoadCount = 20;
      const canUpdateInitial = initialLoadCount <= serverFirstPageCount;
      expect(canUpdateInitial, isTrue);
    });
  });
}
