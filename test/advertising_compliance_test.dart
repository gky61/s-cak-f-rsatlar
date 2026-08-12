import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/advertising_compliance_service.dart';

void main() {
  group('AdvertisingComplianceService Tests (#tanıtım Dönüşümü)', () {
    test('Var olan #reklam etiketini #tanıtım olarak dönüştürür', () {
      const text = 'Airpods Pro 2. Nesil çok iyi fiyata indi!\n\n#reklam';
      expect(
        AdvertisingComplianceService.ensureDisclosure(text),
        equals('Airpods Pro 2. Nesil çok iyi fiyata indi!\n\n#tanıtım'),
      );
    });

    test('Var olan #işbirliği etiketini #tanıtım olarak dönüştürür', () {
      const text = 'Zara Keten Gömlek İndirimi #işbirliği';
      expect(
        AdvertisingComplianceService.ensureDisclosure(text),
        equals('Zara Keten Gömlek İndirimi\n\n#tanıtım'),
      );
    });

    test('Büyük harfli [REKLAM] ibaresini #tanıtım olarak dönüştürür', () {
      const text = 'DeFacto Kazak Fırsatı [REKLAM]';
      expect(
        AdvertisingComplianceService.ensureDisclosure(text),
        equals('DeFacto Kazak Fırsatı\n\n#tanıtım'),
      );
    });

    test('Zaten #tanıtım olan metni mükerrerlik olmadan korur', () {
      const text = 'Dyson V15 Süpürge Sepette %20 İndirimli\n\n#tanıtım';
      expect(
        AdvertisingComplianceService.ensureDisclosure(text),
        equals('Dyson V15 Süpürge Sepette %20 İndirimli\n\n#tanıtım'),
      );
    });

    test('Etiketsiz açıklamaya otomatik olarak #tanıtım ekler', () {
      const text = 'Dyson V15 Süpürge Sepette %20 İndirimli';
      expect(
        AdvertisingComplianceService.ensureDisclosure(text),
        equals('Dyson V15 Süpürge Sepette %20 İndirimli\n\n#tanıtım'),
      );
    });

    test('Boş veya null açıklamayı doğru şekilde ele alır', () {
      expect(AdvertisingComplianceService.ensureDisclosure(''), equals('#tanıtım'));
      expect(AdvertisingComplianceService.ensureDisclosure(null), equals('#tanıtım'));
      expect(AdvertisingComplianceService.ensureDisclosure('#reklam'), equals('#tanıtım'));
    });
  });
}
