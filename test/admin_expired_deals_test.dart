import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/models/category.dart';

void main() {
  group('Admin Expired Deals Logic & Model Tests', () {
    test('Deal properly recognizes expired state and reason badges', () {
      final expiredDeal = Deal(
        id: 'exp_1',
        title: 'Sony Kulaklık WH-1000XM5',
        description: 'Kablosuz gürültü engelleyici',
        price: 9999.0,
        originalPrice: 12999.0,
        store: 'Amazon',
        brand: 'Sony',
        category: 'elektronik',
        link: 'https://amazon.com.tr/dp/B09XS7JWHH',
        imageUrl: 'https://m.media-amazon.com/images/I/sony.jpg',
        discountRate: 23,
        hotVotes: 12,
        coldVotes: 1,
        expiredVotes: 16,
        commentCount: 4,
        postedBy: 'bot',
        telegramChatUsername: 'dhsicakfirsatlar',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isApproved: true,
        isExpired: true,
        isEditorPick: false,
      );

      // Doğrulamalar
      expect(expiredDeal.isExpired, isTrue);
      expect(expiredDeal.isBotkolik, isTrue);
      expect(expiredDeal.expiredVotes, 16);
      expect(expiredDeal.isApproved, isTrue);
      expect(Category.getNameById(expiredDeal.category), 'Elektronik');

      // Topluluk fırsatı testi
      final userExpiredDeal = Deal(
        id: 'exp_2',
        title: 'Nike Air Max 270',
        price: 2499.0,
        store: 'Boyner',
        brand: 'Nike',
        category: 'moda',
        link: 'https://boyner.com.tr/item',
        imageUrl: 'https://img.boyner.com/item.jpg',
        hotVotes: 5,
        coldVotes: 0,
        expiredVotes: 0,
        commentCount: 1,
        postedBy: 'user_123',
        postedByName: 'Ahmet Yılmaz',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        isApproved: false,
        isExpired: true,
        isUserSubmitted: true,
        isEditorPick: false,
      );

      expect(userExpiredDeal.isExpired, isTrue);
      expect(userExpiredDeal.isBotkolik, isFalse);
      expect(userExpiredDeal.isUserSubmitted, isTrue);
      expect(userExpiredDeal.postedByName, 'Ahmet Yılmaz');
      expect(userExpiredDeal.isApproved, isFalse);
    });

    test('Expired deals filter criteria works accurately', () {
      final deals = [
        Deal(
          id: '1',
          title: 'Apple iPad 9. Nesil',
          price: 9000,
          store: 'Teknosa',
          brand: 'Apple',
          category: 'elektronik',
          link: '',
          imageUrl: '',
          hotVotes: 0,
          coldVotes: 0,
          commentCount: 0,
          postedBy: 'bot',
          createdAt: DateTime.now(),
          isApproved: true,
          isExpired: true,
          isEditorPick: false,
        ),
        Deal(
          id: '2',
          title: 'Adidas Koşu Ayakkabısı',
          price: 1500,
          store: 'Trendyol',
          brand: 'Adidas',
          category: 'moda',
          link: '',
          imageUrl: '',
          hotVotes: 0,
          coldVotes: 0,
          commentCount: 0,
          postedBy: 'user_456',
          postedByName: 'Mehmet',
          createdAt: DateTime.now(),
          isApproved: false,
          isExpired: true,
          isUserSubmitted: true,
          isEditorPick: false,
        ),
      ];

      // Filtreler
      final allCount = deals.length;
      final botDeals = deals.where((d) => d.isBotkolik).toList();
      final userDeals = deals.where((d) => !d.isBotkolik).toList();
      final approvedDeals = deals.where((d) => d.isApproved == true).toList();
      final unapprovedDeals = deals.where((d) => d.isApproved != true).toList();

      expect(allCount, 2);
      expect(botDeals.length, 1);
      expect(botDeals.first.id, '1');
      expect(userDeals.length, 1);
      expect(userDeals.first.id, '2');
      expect(approvedDeals.length, 1);
      expect(approvedDeals.first.id, '1');
      expect(unapprovedDeals.length, 1);
      expect(unapprovedDeals.first.id, '2');

      // Arama
      const query = 'ipad';
      final searchResults = deals.where((d) => d.title.toLowerCase().contains(query)).toList();
      expect(searchResults.length, 1);
      expect(searchResults.first.title, contains('iPad'));
    });
  });
}
