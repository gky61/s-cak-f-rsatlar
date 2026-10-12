import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/deal_service.dart';
import 'package:sicak_firsatlar/services/firestore_service.dart';

void main() {
  group('Hata #1 Doğrulama: DealBusinessException Mimari Testleri', () {
    test('DealPendingApprovalException beklenen tiplere ve formata sahip olmalıdır', () {
      const dealId = 'GGnSLq3QF8fkcDj5LYSW';
      const exception = DealPendingApprovalException(dealId);

      // Tip hiyerarşisi doğrulaması
      expect(exception, isA<DealBusinessException>());
      expect(exception, isA<Exception>());
      expect(exception.existingDealId, equals(dealId));
      expect(exception.dealId, equals(dealId));

      // String format ve geriye dönük uyumluluk doğrulaması
      expect(exception.toString(), equals('pending_approval:$dealId'));
      expect(exception.toString().contains('pending_approval:'), isTrue);
    });

    test('DealAlreadySharedException beklenen tiplere ve formata sahip olmalıdır', () {
      const dealId = 'ABC123XYZ456';
      const exception = DealAlreadySharedException(dealId);

      // Tip hiyerarşisi doğrulaması
      expect(exception, isA<DealBusinessException>());
      expect(exception, isA<Exception>());
      expect(exception.existingDealId, equals(dealId));
      expect(exception.dealId, equals(dealId));

      // String format ve geriye dönük uyumluluk doğrulaması
      expect(exception.toString(), equals('already_shared:$dealId'));
      expect(exception.toString().contains('already_shared:'), isTrue);
    });

    test('FirestoreService export sözleşmesi sınıfları dışa aktarmalıdır', () {
      const approvalEx = DealPendingApprovalException('test-doc-1');
      const sharedEx = DealAlreadySharedException('test-doc-2');

      expect(approvalEx.existingDealId, equals('test-doc-1'));
      expect(approvalEx.dealId, equals('test-doc-1'));
      expect(sharedEx.existingDealId, equals('test-doc-2'));
      expect(sharedEx.dealId, equals('test-doc-2'));
    });

    test('Polimorfik yakalama (sealed class pattern) hatasız çalışmalıdır', () {
      DealBusinessException createException(bool isPending, String id) {
        if (isPending) {
          return DealPendingApprovalException(id);
        } else {
          return DealAlreadySharedException(id);
        }
      }

      final ex1 = createException(true, 'doc-1');
      final ex2 = createException(false, 'doc-2');

      String handle(DealBusinessException ex) {
        return switch (ex) {
          DealPendingApprovalException(dealId: final id) => 'pending:$id',
          DealAlreadySharedException(dealId: final id) => 'shared:$id',
        };
      }

      expect(handle(ex1), equals('pending:doc-1'));
      expect(handle(ex2), equals('shared:doc-2'));
    });
  });
}
