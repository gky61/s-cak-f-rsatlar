import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/widgets/offline_banner.dart';

void main() {
  group('OfflineBanner Widget Tests', () {
    testWidgets('OfflineBanner builds cleanly without assertion errors or overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OfflineBanner(),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byType(ClipRect), findsWidgets);
      expect(find.byType(AnimatedContainer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
