import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('DynamicCurrencyFormatter Turkish Lira (TL) Rules', () {
    final formatter = DynamicCurrencyFormatter();

    test('Case 1: Whole numbers (Kuruşsuz)', () {
      expect(formatter.format(75), equals('₺75'));
      expect(formatter.format(1500), equals('₺1.500'));
      expect(formatter.format(25000), equals('₺25.000'));
      expect(formatter.format(1500.0), equals('₺1.500'));
      expect(formatter.format(25000.00), equals('₺25.000'));
    });

    test('Case 2: Decimal numbers (Kuruşlu)', () {
      expect(formatter.format(75.5), equals('₺75,50'));
      expect(formatter.format(75.50), equals('₺75,50'));
      expect(formatter.format(1999.9), equals('₺1.999,90'));
      expect(formatter.format(9509.5), equals('₺9.509,50'));
      expect(formatter.format(12.99), equals('₺12,99'));
    });
  });
}
