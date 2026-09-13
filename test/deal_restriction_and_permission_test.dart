import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/widgets/deal_restriction_bottom_sheet.dart';

void main() {
  group('Deal Restriction & Maintenance UI/UX Modals', () {
    testWidgets('showDealSharingDisabledBottomSheet renders maintenance modal correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDealSharingDisabledBottomSheet(context),
                child: const Text('Open Maintenance Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Maintenance Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Fırsat Paylaşımı Şu Anda Bakımda 🛠️'), findsOneWidget);
      expect(find.text('Geçici Bakım Modu'), findsOneWidget);
      expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);
      expect(find.text('Anladım, Fırsatları Keşfet 🔥'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Anladım, Fırsatları Keşfet 🔥'));
      await tester.pumpAndSettle();

      expect(find.text('Fırsat Paylaşımı Şu Anda Bakımda 🛠️'), findsNothing);
    });

    testWidgets('showDealBannedBottomSheet renders deal ban modal correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDealBannedBottomSheet(context),
                child: const Text('Open Ban Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Ban Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Fırsat Paylaşım İzniniz Kısıtlandı 🛡️'), findsOneWidget);
      expect(find.text('Paylaşım Kısıtlaması'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_bad_rounded), findsOneWidget);
      expect(find.text('Anladım'), findsOneWidget);

      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();

      expect(find.text('Fırsat Paylaşım İzniniz Kısıtlandı 🛡️'), findsNothing);
    });

    testWidgets('showCommentBannedBottomSheet renders comment ban modal correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCommentBannedBottomSheet(context),
                child: const Text('Open Comment Ban Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Comment Ban Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Yorum Yapma İzniniz Kısıtlandı 💬'), findsOneWidget);
      expect(find.text('Yorum Kısıtlaması'), findsOneWidget);
      expect(find.byIcon(Icons.comments_disabled_rounded), findsOneWidget);
      expect(find.text('Anladım'), findsOneWidget);

      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();

      expect(find.text('Yorum Yapma İzniniz Kısıtlandı 💬'), findsNothing);
    });

    testWidgets('showAccountBlockedBottomSheet renders account suspension modal correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAccountBlockedBottomSheet(context),
                child: const Text('Open Account Blocked Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Account Blocked Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Hesabınız Askıya Alındı 🛡️'), findsOneWidget);
      expect(find.text('Hesap Kısıtlaması'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_bad_rounded), findsOneWidget);
      expect(find.text('Anladım'), findsOneWidget);

      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();

      expect(find.text('Hesabınız Askıya Alındı 🛡️'), findsNothing);
    });
  });

  group('Permission Denied & Error String Sanitization', () {
    test('Raw cloud_firestore permission-denied pattern is detected and mapped', () {
      const rawError = '[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.';
      
      final isPermissionError = rawError.contains('permission-denied') ||
          rawError.contains('yetkiniz kaldırılmış') ||
          rawError.contains('paylaşım izniniz kısıtlanmış') ||
          rawError.contains('yetkiniz bulunmamaktadır');

      expect(isPermissionError, isTrue);

      final cleanError = rawError
          .replaceAll('Exception: ', '')
          .replaceAll(RegExp(r'\[cloud_firestore\/.*?\]'), '')
          .replaceAll(RegExp(r'\[.*?\/.*?\]'), '')
          .trim();

      expect(cleanError.contains('cloud_firestore'), isFalse);
    });
  });
}
