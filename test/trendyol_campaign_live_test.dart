import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  test('Test Trendyol link https://ty.gl/5qmnrqfz6fk2x', () async {
    final service = LinkPreviewService();
    final result = await service.fetchMetadata('https://ty.gl/5qmnrqfz6fk2x');

    print('============================================================');
    print('Title:         ${result?.title}');
    print('Price:         ${result?.price}');
    print('OriginalPrice: ${result?.originalPrice}');
    print('ImageUrl:      ${result?.imageUrl}');
    print('Provider:      ${result?.provider}');
    print('PriceLabel:    ${result?.priceLabel}');
    print('============================================================');

    expect(result, isNotNull);
    expect(result!.title, contains('Astra Track 24'));
    expect(result.price, equals(6749.0));
    expect(result.originalPrice, equals(8250.0));
    expect(result.imageUrl, isNotNull);
  });
}
