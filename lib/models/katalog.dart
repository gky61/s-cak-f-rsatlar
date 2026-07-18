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
}
