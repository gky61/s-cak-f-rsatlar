import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('Admin Edit Sheet Fields Test', () {
    test('Deal model supports all edit fields properly', () {
      final deal = Deal(
        id: 'test_deal_1',
        title: 'Test Deal Title',
        description: 'Test Description',
        price: 99.99,
        originalPrice: 199.99,
        store: 'Hepsiburada',
        brand: 'Apple',
        category: 'elektronik',
        subCategory: 'telefon',
        link: 'https://hepsiburada.com/item',
        imageUrl: 'https://img.com/pic.jpg',
        discountRate: 50,
        ratingValue: 4.8,
        ratingCount: 120,
        isEditorPick: true,
        isApproved: true,
        isExpired: false,
        hidePrice: true,
        isAmazonWarehouse: true,
        hotVotes: 10,
        coldVotes: 2,
        commentCount: 0,
        postedBy: 'admin_1',
        createdAt: DateTime.now(),
      );

      final map = deal.toFirestore();
      expect(map['title'], 'Test Deal Title');
      expect(map['brand'], 'Apple');
      expect(map['ratingValue'], 4.8);
      expect(map['ratingCount'], 120);
      expect(map['hidePrice'], true);
      expect(map['isAmazonWarehouse'], true);
    });
  });
}
