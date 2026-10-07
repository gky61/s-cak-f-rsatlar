import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KuponFormPage Keyboard & UI/UX Optimization Tests', () {
    late String sourceCode;

    setUpAll(() {
      final file = File('lib/screens/kupon_form_page.dart');
      expect(file.existsSync(), isTrue, reason: 'kupon_form_page.dart dosyası mevcut olmalıdır');
      sourceCode = file.readAsStringSync();
    });

    test('Scaffold resizeToAvoidBottomInset is explicitly enabled', () {
      expect(
        sourceCode.contains('resizeToAvoidBottomInset: true'),
        isTrue,
        reason: 'Scaffold klavye açılışlarını gövdeye iletmek için resizeToAvoidBottomInset: true içermelidir',
      );
    });

    test('GestureDetector with HitTestBehavior.opaque wraps the body for root tap-to-dismiss', () {
      expect(
        sourceCode.contains('HitTestBehavior.opaque'),
        isTrue,
        reason: 'Boşluklara dokunulduğunda klavyeyi kapatmak için HitTestBehavior.opaque bulunmalıdır',
      );
      expect(
        sourceCode.contains('onTap: () => FocusScope.of(context).unfocus()'),
        isTrue,
        reason: 'Ekrana dokunulduğunda klavyeyi kapatmak için FocusScope.of(context).unfocus çağrılmalıdır',
      );
    });

    test('ListView has onDrag keyboard dismissal behavior', () {
      expect(
        sourceCode.contains('keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag'),
        isTrue,
        reason: 'Form kaydırıldığında klavyenin otomatik kapanması için ScrollViewKeyboardDismissBehavior.onDrag bulunmalıdır',
      );
    });

    test('Single-line text inputs configure TextInputAction.done and field submission unfocus', () {
      // _baslikController
      expect(
        sourceCode.contains('controller: _baslikController'),
        isTrue,
      );
      // _kodController
      expect(
        sourceCode.contains('controller: _kodController'),
        isTrue,
      );

      final doneMatches = RegExp(r'textInputAction:\s*TextInputAction\.done').allMatches(sourceCode);
      expect(
        doneMatches.length,
        greaterThanOrEqualTo(2),
        reason: 'Başlık ve Kupon kodu alanları TextInputAction.done tanımlamalıdır',
      );

      final unfocusMatches = RegExp(r'onFieldSubmitted:\s*\(_\)\s*=>\s*FocusScope\.of\(context\)\.unfocus\(\)').allMatches(sourceCode);
      expect(
        unfocusMatches.length,
        greaterThanOrEqualTo(2),
        reason: 'Başlık ve Kupon kodu tamamlandığında FocusScope.of(context).unfocus çağrılmalıdır',
      );
    });

    test('Clipboard paste functionality is implemented and dismisses keyboard', () {
      expect(
        sourceCode.contains('_pasteKuponKoduFromClipboard'),
        isTrue,
        reason: 'Panodan kupon kodu yapıştırma metodu bulunmalıdır',
      );
      expect(
        sourceCode.contains('Clipboard.getData(Clipboard.kTextPlain)'),
        isTrue,
        reason: 'Panodan metin okuma gerçekleştirilmelidir',
      );
    });

    test('Submit bar is in Column/Expanded flow instead of Scaffold bottomNavigationBar', () {
      expect(
        sourceCode.contains('bottomNavigationBar: _buildStickySubmitBar'),
        isFalse,
        reason: 'Klavye arkasında ezilmeyi önlemek için bottomNavigationBar kullanılmamalıdır',
      );
      expect(
        sourceCode.contains('Expanded('),
        isTrue,
        reason: 'Form alanı klavye geldikçe daralacak şekilde Expanded içine alınmalıdır',
      );
    });

    test('Sticky submit bar has dynamic keyboard awareness and double-inset prevention', () {
      expect(
        sourceCode.contains('MediaQuery.of(context).viewInsets.bottom'),
        isTrue,
        reason: 'Klavye yüksekliği viewInsets.bottom üzerinden okunmalıdır',
      );
      expect(
        sourceCode.contains('bottom: !isKeyboardOpen'),
        isTrue,
        reason: 'Klavye açıkken çift SafeArea boşluğunu önlemek için bottom: !isKeyboardOpen kullanılmalıdır',
      );
      expect(
        sourceCode.contains('isKeyboardOpen ? 8 : 16'),
        isTrue,
        reason: 'Klavye açıkken dikey alan tasarrufu için dinamik alt padding kullanılmalıdır',
      );
    });

    test('DatePicker unfocuses keyboard before opening modal dialog', () {
      final normalized = sourceCode.replaceAll('\r\n', '\n');
      expect(
        normalized.contains('FocusScope.of(context).unfocus();\n                              final secilen = await showDatePicker'),
        isTrue,
        reason: 'Tarih seçici açılırken klavye odağı bırakılmalıdır',
      );
    });
  });
}
