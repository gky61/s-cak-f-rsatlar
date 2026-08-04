import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/domain_allowlist_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('20 Mağaza 200 Gerçek Ürün Linki Doğrulama Testi', () async {
    final file = File('documentation/aktuel-logs/20_magaza_200_gercek_urun_linki.json');
    expect(file.existsSync(), isTrue, reason: '200 ürün linki JSON dosyası bulunamadı');

    final jsonStr = await file.readAsString();
    final Map<String, dynamic> data = json.decode(jsonStr);

    // Dynamic allowlist ve rules JSON dosyasını manuel oku
    final rulesFile = File('assets/data/domain_allowlist_extended.json');
    if (rulesFile.existsSync()) {
      final rulesJsonStr = await rulesFile.readAsString();
      final Map<String, dynamic> rulesData = json.decode(rulesJsonStr);
      // test ortamında da tam regex eşleşmesini test etmek için initialize mantığını doğrula
    }

    int total = 0;
    int passed = 0;
    int failed = 0;

    data.forEach((storeKey, urls) {
      if (urls is List) {
        for (final url in urls) {
          total++;
          final urlStr = url.toString();
          final isAllowed = DomainAllowlistService.isDomainAllowed(urlStr);
          final isProduct = DomainAllowlistService.isProductUrl(urlStr);

          if (isAllowed && isProduct) {
            passed++;
          } else {
            failed++;
            print('❌ FAILED [$storeKey]: $urlStr (isAllowed: $isAllowed, isProduct: $isProduct)');
          }
        }
      }
    });

    print('📊 Flutter Dart Test Sonucu: $passed/$total geçti (Hata: $failed)');
    expect(failed, equals(0), reason: '$failed adet link başarısız oldu!');
  });
}
