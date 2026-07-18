import 'package:cloud_firestore/cloud_firestore.dart';

class Katalog {
  final String katalogId;
  final String magazaKodu;
  final String katalogBasligi;
  final DateTime baslangicTarihi;
  final DateTime bitisTarihi;
  final List<String> sayfaResimleri;
  final String kapakResmi;

  Katalog({
    required this.katalogId,
    required this.magazaKodu,
    required this.katalogBasligi,
    required this.baslangicTarihi,
    required this.bitisTarihi,
    required this.sayfaResimleri,
    required this.kapakResmi,
  });

  factory Katalog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse baslangicTarihi
    DateTime start = DateTime.now();
    if (data['baslangicTarihi'] != null) {
      if (data['baslangicTarihi'] is Timestamp) {
        start = (data['baslangicTarihi'] as Timestamp).toDate();
      } else if (data['baslangicTarihi'] is String) {
        start = DateTime.tryParse(data['baslangicTarihi']) ?? start;
      }
    }

    // Parse bitisTarihi
    DateTime end = DateTime.now().add(const Duration(days: 7));
    if (data['bitisTarihi'] != null) {
      if (data['bitisTarihi'] is Timestamp) {
        end = (data['bitisTarihi'] as Timestamp).toDate();
      } else if (data['bitisTarihi'] is String) {
        end = DateTime.tryParse(data['bitisTarihi']) ?? end;
      }
    }

    return Katalog(
      katalogId: doc.id,
      magazaKodu: data['magazaKodu'] ?? '',
      katalogBasligi: data['katalogBasligi'] ?? '',
      baslangicTarihi: start,
      bitisTarihi: end,
      sayfaResimleri: List<String>.from(data['sayfaResimleri'] ?? []),
      kapakResmi: data['kapakResmi'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'katalogId': katalogId,
      'magazaKodu': magazaKodu,
      'katalogBasligi': katalogBasligi,
      'baslangicTarihi': Timestamp.fromDate(baslangicTarihi),
      'bitisTarihi': Timestamp.fromDate(bitisTarihi),
      'sayfaResimleri': sayfaResimleri,
      'kapakResmi': kapakResmi,
    };
  }

  /// Kampanya geçerlilik metnini döndürür.
  String getValidityText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final start = DateTime(
      baslangicTarihi.year,
      baslangicTarihi.month,
      baslangicTarihi.day,
    );

    final expiry = DateTime(
      bitisTarihi.year,
      bitisTarihi.month,
      bitisTarihi.day,
    );

    if (today.isBefore(start)) {
      final daysToStart = start.difference(today).inDays;
      if (daysToStart == 1) {
        return 'Yarın başlıyor';
      } else if (daysToStart >= 2 && daysToStart <= 14) {
        return '$daysToStart gün sonra başlayacak';
      } else if (daysToStart >= 15 && daysToStart <= 29) {
        final weeks = (daysToStart / 7).round();
        return '$weeks hafta sonra başlayacak';
      } else {
        final months = (daysToStart / 30).round();
        return '$months ay sonra başlayacak';
      }
    }

    final daysToExpiry = expiry.difference(today).inDays;

    if (daysToExpiry < 0) {
      return 'Süresi Doldu';
    } else if (daysToExpiry <= 3) {
      if (daysToExpiry == 3) {
        return '3 gün sonra bitiyor';
      } else if (daysToExpiry == 2) {
        return '2 gün sonra bitiyor';
      } else if (daysToExpiry == 1) {
        return 'Yarın bitiyor';
      } else {
        return 'Bugün bitiyor';
      }
    } else {
      if (daysToExpiry >= 4 && daysToExpiry <= 14) {
        return '$daysToExpiry gün sonra bitecek';
      } else if (daysToExpiry >= 15 && daysToExpiry <= 29) {
        final weeks = (daysToExpiry / 7).round();
        return '$weeks hafta sonra bitecek';
      } else {
        final months = (daysToExpiry / 30).round();
        return '$months ay sonra bitecek';
      }
    }
  }
}

