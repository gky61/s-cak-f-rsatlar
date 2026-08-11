import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('Deal.hidePrice Unit Tests', () {
    test('Default hidePrice should be false', () {
      final deal = Deal(
        id: 'test_1',
        title: 'Standart Ürün',
        price: 100.0,
        store: 'Trendyol',
        category: 'elektronik',
        link: 'https://trendyol.com/p-1',
        imageUrl: 'https://img.com/1.jpg',
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        postedBy: 'user_1',
        createdAt: DateTime.now(),
        isEditorPick: false,
      );

      expect(deal.hidePrice, false);
      expect(deal.toFirestore()['hidePrice'], false);
    });

    test('hidePrice = true should be serialized and deserialized correctly', () {
      final deal = Deal(
        id: 'test_campaign',
        title: 'Kampanya Fırsatı (Fiyatsız)',
        price: 0.0,
        store: 'Amazon',
        category: 'finans_kampanyalar',
        link: 'https://amazon.com.tr/b/123',
        imageUrl: 'https://img.com/camp.jpg',
        hotVotes: 5,
        coldVotes: 0,
        commentCount: 2,
        postedBy: 'admin_1',
        createdAt: DateTime.now(),
        isEditorPick: true,
        hidePrice: true,
      );

      final map = deal.toFirestore();
      expect(map['hidePrice'], true);

      // Map'ten tekrar Deal oluşturmayı simüle et
      final reconstructed = Deal(
        id: deal.id,
        title: map['title'],
        description: map['description'],
        price: (map['price'] as num).toDouble(),
        store: map['store'],
        category: map['category'],
        link: map['link'],
        imageUrl: map['imageUrl'],
        hotVotes: map['hotVotes'],
        coldVotes: map['coldVotes'],
        commentCount: map['commentCount'],
        postedBy: map['postedBy'],
        createdAt: DateTime.now(),
        isEditorPick: map['isEditorPick'],
        hidePrice: map['hidePrice'] == true,
      );

      expect(reconstructed.hidePrice, true);
    });
  });
}
