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

    test('Price parsing and dynamic discount calculation logic', () {
      double? parseDouble(String input) {
        String cleaned = input
            .replaceAll('TL', '')
            .replaceAll('₺', '')
            .replaceAll(RegExp(r'\s+'), '')
            .replaceAll(RegExp('[^0-9,\\.]'), '')
            .trim();
        if (cleaned.isEmpty) return null;

        if (cleaned.contains('.') && cleaned.contains(',')) {
          cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
        } else if (cleaned.contains(',')) {
          cleaned = cleaned.replaceAll(',', '.');
        } else if (cleaned.contains('.')) {
          final parts = cleaned.split('.');
          if (parts.length == 2 && parts[1].length == 3) {
            cleaned = cleaned.replaceAll('.', '');
          } else if (parts.length > 2) {
            cleaned = cleaned.replaceAll('.', '');
          }
        }

        return double.tryParse(cleaned);
      }

      int? calculateDiscount(double? price, double? originalPrice) {
        if (originalPrice != null && price != null && originalPrice > price && price > 0) {
          final rate = (((originalPrice - price) / originalPrice) * 100).round();
          return rate > 0 ? rate : null;
        }
        return null;
      }

      // Test parseDouble with various Turkish formats
      expect(parseDouble('100'), 100.0);
      expect(parseDouble('99,99'), 99.99);
      expect(parseDouble('1.999,00 ₺'), 1999.00);
      expect(parseDouble('48.498,99 TL'), 48498.99);
      expect(parseDouble(''), isNull);

      // Test discount recalculation when price is updated
      // Old: 100 TL -> 80 TL (%20)
      expect(calculateDiscount(80, 100), 20);

      // User updates price to 50 TL -> (%50) automatically recalculated
      expect(calculateDiscount(50, 100), 50);

      // User updates price to 75 TL -> (%25) automatically recalculated
      expect(calculateDiscount(75, 100), 25);

      // User updates price higher than originalPrice -> discount is null
      expect(calculateDiscount(120, 100), isNull);

      // User updates price equal to originalPrice -> discount is null
      expect(calculateDiscount(100, 100), isNull);

      // User clears original price -> discount is null
      expect(calculateDiscount(50, null), isNull);

      // User clears price -> discount is null
      expect(calculateDiscount(null, 100), isNull);
    });
  });
}

