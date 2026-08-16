import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/widgets/deal_card/deal_card_helpers.dart';

void main() {
  group('DealCard Helper Unit Tests', () {
    test('getStoreAsset should return correct asset for known stores', () {
      expect(getStoreAsset('Trendyol'), 'assets/trendyol.webp');
      expect(getStoreAsset('Hepsiburada'), 'assets/hepsiburada.webp');
      expect(getStoreAsset('Amazon TR'), 'assets/amazon.webp');
      expect(getStoreAsset('n11'), 'assets/n11.webp');
      expect(getStoreAsset('Pazarama'), 'assets/pazarama.webp');
      expect(getStoreAsset('PttAVM'), 'assets/pttavm.webp');
      expect(getStoreAsset('Migros Hemen'), 'assets/migros.webp');
      expect(getStoreAsset('Bilinmeyen Magaza'), 'assets/logo.webp');
    });

    test('getCategoryDisplayName should resolve category display names', () {
      expect(getCategoryDisplayName(''), 'Genel');
      expect(getCategoryDisplayName('Diger'), 'Diğer');
      expect(getCategoryDisplayName('Kozmetik'), 'Kozmetik & Bakım');
      expect(getCategoryDisplayName('Bilinmeyen Kategori'), 'Tümü');
    });

    test('getThermometerEmoji should return correct emoji based on votes', () {
      // No votes -> 🤷
      expect(getThermometerEmoji(0, 0), '🤷');

      // 100% hot -> 🔥
      expect(getThermometerEmoji(10, 0), '🔥');
      
      // 80% hot -> 🔥
      expect(getThermometerEmoji(8, 2), '🔥');

      // 60% hot -> 👍
      expect(getThermometerEmoji(6, 4), '👍');

      // 40% hot -> 🤔
      expect(getThermometerEmoji(4, 6), '🤔');

      // 20% hot -> 😬
      expect(getThermometerEmoji(2, 8), '😬');

      // 0% hot -> 🥶
      expect(getThermometerEmoji(0, 10), '🥶');
    });

    test('formatRelativeTime should calculate relative time strings correctly', () {
      final now = DateTime.now();
      
      final justNow = now.subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(justNow), 'Şimdi');

      final minutesAgo = now.subtract(const Duration(minutes: 15));
      expect(formatRelativeTime(minutesAgo), '15 dakika önce');

      final hoursAgo = now.subtract(const Duration(hours: 3));
      expect(formatRelativeTime(hoursAgo), '3 saat önce');

      final yesterday = now.subtract(const Duration(days: 1));
      expect(formatRelativeTime(yesterday), 'Dün');

      final daysAgo = now.subtract(const Duration(days: 4));
      expect(formatRelativeTime(daysAgo), '4 gün önce');
    });
  });
}
