import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/category_detection_service.dart';

void main() {
  group('Getir & Migros Category Detection Tests (Dart)', () {
    test('1. Getir URL should automatically classify as supermarket', () {
      final res = CategoryDetectionService.detectCategory(
        'Rastgele Ürün Paket',
        url: 'https://getir.com/urun/some-product-123/',
      );
      expect(res, isNotNull);
      expect(res!['categoryId'], equals('supermarket'));
      expect(res['subCategory'], equals('Gıda Ürünleri'));
    });

    test('2. Migros URL should automatically classify as supermarket', () {
      final res = CategoryDetectionService.detectCategory(
        'Migros Süt 1 L',
        url: 'https://www.migros.com.tr/migros-sut-1-l-p-12345',
      );
      expect(res, isNotNull);
      expect(res!['categoryId'], equals('supermarket'));
      expect(res['subCategory'], equals('Gıda Ürünleri'));
    });

    test('3. Getir store param with detergent should classify as supermarket > Deterjan & Temizlik', () {
      final res = CategoryDetectionService.detectCategory(
        'Ariel Sıvı Çamaşır Deterjanı 1.5 L',
        store: 'Getir',
      );
      expect(res, isNotNull);
      expect(res!['categoryId'], equals('supermarket'));
      expect(res['subCategory'], equals('Deterjan & Temizlik'));
    });

    test('4. Migros store param with random product should classify as supermarket', () {
      final res = CategoryDetectionService.detectCategory(
        'Özel Paket Ürünü 500 gr',
        store: 'Migros',
      );
      expect(res, isNotNull);
      expect(res!['categoryId'], equals('supermarket'));
      expect(res['subCategory'], equals('Gıda Ürünleri'));
    });
  });
}
