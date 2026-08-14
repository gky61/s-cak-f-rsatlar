import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('Botkolik Attribution & Deal Model Tests', () {
    test('Non-user-submitted deal should be identified as Botkolik', () {
      final deal = Deal(
        id: 'deal_1',
        title: 'Sensodyne Diş Macunu',
        price: 99.90,
        store: 'Migros',
        category: 'supermarket',
        link: 'https://www.migros.com.tr/sensodyne',
        imageUrl: 'https://images.migrosone.com/img.jpg',
        hotVotes: 10,
        coldVotes: 0,
        commentCount: 2,
        postedBy: 'telegram_firsat_kanali',
        createdAt: DateTime.now(),
        isEditorPick: false,
        isUserSubmitted: false,
      );

      expect(deal.isBotkolik, isTrue);
    });

    test('Deal with postedBy=botkolik should be identified as Botkolik', () {
      final deal = Deal(
        id: 'deal_2',
        title: 'iPhone 15 Pro Max',
        price: 65000,
        store: 'Amazon',
        category: 'elektronik',
        link: 'https://amazon.com.tr/dp/B001',
        imageUrl: 'https://media-amazon.com/images/I/img.jpg',
        hotVotes: 50,
        coldVotes: 1,
        commentCount: 15,
        postedBy: 'botkolik',
        createdAt: DateTime.now(),
        isEditorPick: true,
        isUserSubmitted: false,
      );

      expect(deal.isBotkolik, isTrue);
    });

    test('Deal with empty postedBy should fallback to Botkolik', () {
      final deal = Deal(
        id: 'deal_3',
        title: 'Dyson V15',
        price: 22000,
        store: 'Trendyol',
        category: 'elektronik',
        link: 'https://trendyol.com/dyson',
        imageUrl: 'https://cdn.dsmcdn.com/img.jpg',
        hotVotes: 25,
        coldVotes: 2,
        commentCount: 5,
        postedBy: '',
        createdAt: DateTime.now(),
        isEditorPick: false,
        isUserSubmitted: false,
      );

      expect(deal.isBotkolik, isTrue);
    });

    test('User submitted deal by regular user should NOT be identified as Botkolik', () {
      final deal = Deal(
        id: 'deal_4',
        title: 'Kahve Makinesi',
        price: 1500,
        store: 'Hepsiburada',
        category: 'ev_yasam',
        link: 'https://hepsiburada.com/kahve',
        imageUrl: 'https://productimages.hepsiburada.net/img.jpg',
        hotVotes: 12,
        coldVotes: 0,
        commentCount: 4,
        postedBy: 'user_regular_uid_12345',
        createdAt: DateTime.now(),
        isEditorPick: false,
        isUserSubmitted: true,
      );

      expect(deal.isBotkolik, isFalse);
    });

    test('Botkolik asset should exist in webp format and old png removed', () {
      final webpFile = File('assets/botkolik.webp');
      final pngFile = File('assets/botkolik.png');

      expect(webpFile.existsSync(), isTrue, reason: 'assets/botkolik.webp must exist');
      expect(pngFile.existsSync(), isFalse, reason: 'assets/botkolik.png must be deleted');
    });
  });
}
