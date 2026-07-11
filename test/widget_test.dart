import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Simple widget smoke test', (WidgetTester tester) async {
    // Build a simple mock widget.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Fırsat Kolik'),
        ),
      ),
    );
    expect(find.text('Fırsat Kolik'), findsOneWidget);
  });
}
