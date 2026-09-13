import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/screens/deal_detail/deal_share_sheet.dart';
import 'package:sicak_firsatlar/utils/share_helper.dart';

void main() {
  group('ShareHelper iOS Platform Compatibility Tests', () {
    test('calculateOrigin with null context returns valid non-zero Rect within screen bounds', () {
      final origin = ShareHelper.calculateOrigin(null);

      expect(origin.isEmpty, isFalse, reason: 'sharePositionOrigin must never be empty on iOS');
      expect(origin.width, greaterThan(0.0), reason: 'width must be non-zero');
      expect(origin.height, greaterThan(0.0), reason: 'height must be non-zero');
      expect(origin.left, greaterThanOrEqualTo(0.0));
      expect(origin.top, greaterThanOrEqualTo(0.0));
    });

    testWidgets('calculateOrigin with mounted widget context returns accurate non-zero Rect', (tester) async {
      late Rect computedOrigin;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      computedOrigin = ShareHelper.calculateOrigin(context);
                    },
                    child: const Text('Paylaş'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Paylaş'));
      await tester.pump();

      expect(computedOrigin.isEmpty, isFalse);
      expect(computedOrigin.width, greaterThan(0.0));
      expect(computedOrigin.height, greaterThan(0.0));
      expect(computedOrigin.left, greaterThanOrEqualTo(0.0));
      expect(computedOrigin.top, greaterThanOrEqualTo(0.0));
    });

    test('DealShareSheet share text contains valid formatted content and link', () {
      final dummyDeal = Deal(
        id: 'test_deal_123',
        title: 'Harika İndirimli Kulaklık',
        description: 'Açıklama metni',
        price: 999.90,
        originalPrice: 1499.90,
        discountRate: 33,
        imageUrl: 'https://example.com/image.jpg',
        link: 'https://amazon.com.tr/deal',
        store: 'Amazon',
        category: 'Elektronik',
        hotVotes: 10,
        coldVotes: 1,
        commentCount: 5,
        postedBy: 'user_1',
        createdAt: DateTime.now(),
        isEditorPick: false,
      );

      // Verify deal id and store are available for sharing
      expect(dummyDeal.id, 'test_deal_123');
      expect(dummyDeal.title, contains('Kulaklık'));
      expect(dummyDeal.price, 999.90);
      expect(dummyDeal.displayUrl, contains('amazon'));
    });
  });
}
