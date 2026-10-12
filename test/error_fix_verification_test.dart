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

    test('Onay bekleyen fırsat kalkanı (Pending Guard) fiyat düşüşünden önce değerlendirilmelidir', () {
      // Simülasyon: Veritabanındaki belge onay bekliyor mu yoksa onaylı mı?
      DealBusinessException? evaluateDuplicate({
        required bool isApproved,
        required double existingPrice,
        required double newPrice,
        required String docId,
      }) {
        // Kural 1: Onay bekleyen kalkanı
        if (!isApproved) {
          return DealPendingApprovalException(docId);
        }

        // Kural 2: Fiyat düşüşü toleransı (yalnızca onaylılar için)
        if (newPrice > 0 && existingPrice > 0 && newPrice <= (existingPrice * 0.95)) {
          return null; // Fiyat düşüşü geçerli, paylaşıma izin verildi
        }

        return DealAlreadySharedException(docId);
      }

      // Vaka A: Ürün zaten admin onayında (isApproved: false), kullanıcı daha düşük fiyat girse bile
      // ikinci onay kartı açılmamalı ve DealPendingApprovalException fırlatılmalıdır
      final resultA = evaluateDuplicate(
        isApproved: false,
        existingPrice: 819.0,
        newPrice: 619.0, // Fiyat daha düşük olsa bile!
        docId: 'deal-haluk-aydin-pending',
      );
      expect(resultA, isA<DealPendingApprovalException>());
      expect((resultA as DealPendingApprovalException).existingDealId, equals('deal-haluk-aydin-pending'));

      // Vaka B: Ürün onaylı (isApproved: true) ve kullanıcı aynı/yüksek fiyat giriyor
      final resultB = evaluateDuplicate(
        isApproved: true,
        existingPrice: 819.0,
        newPrice: 819.0,
        docId: 'deal-haluk-aydin-approved',
      );
      expect(resultB, isA<DealAlreadySharedException>());

      // Vaka C: Ürün onaylı (isApproved: true) ve kullanıcı gerçek %50 indirimli fiyat giriyor
      final resultC = evaluateDuplicate(
        isApproved: true,
        existingPrice: 1000.0,
        newPrice: 500.0,
        docId: 'deal-headphone-approved',
      );
      expect(resultC, isNull); // Fiyat düşüşü izin verildi
    });
  });
}

