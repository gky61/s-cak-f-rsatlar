import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/widgets/app_snack_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSnackBar & UniqueSnackBarContent Tests', () {
    test('UniqueSnackBarContent should always produce unique toString tags', () {
      final item1 = UniqueSnackBarContent(child: const Text('Test 1'));
      final item2 = UniqueSnackBarContent(child: const Text('Test 2'));
      final item3 = UniqueSnackBarContent(child: const Text('Test 1'));

      final tag1 = item1.toString();
      final tag2 = item2.toString();
      final tag3 = item3.toString();

      expect(tag1, startsWith('snack_'));
      expect(tag2, startsWith('snack_'));
      expect(tag3, startsWith('snack_'));

      expect(tag1, isNot(equals(tag2)));
      expect(tag1, isNot(equals(tag3)));
      expect(tag2, isNot(equals(tag3)));
    });

    testWidgets('AppSnackBar renders correctly in a Widget tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.show(
                    context: context,
                    message: 'Fırsat Başarıyla Paylaşıldı!',
                    icon: Icons.check_circle,
                    backgroundColor: Colors.green,
                  );
                },
                child: const Text('Tıkla'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tıkla'));
      await tester.pump(); // SnackBar start animation
      await tester.pump(const Duration(milliseconds: 300)); // Visible

      expect(find.text('Fırsat Başarıyla Paylaşıldı!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
