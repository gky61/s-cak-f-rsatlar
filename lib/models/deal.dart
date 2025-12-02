import 'package:cloud_firestore/cloud_firestore.dart';

class Deal {
  final String id;
  final String title;
  final String description;
  final double price;
  final double? originalPrice; // Eski Fiyat
  final int? discountRate; // İndirim Oranı
  final String store;
  final String category;
  final String? subCategory;
  final String link;
  final String imageUrl;
  final int hotVotes;
  final int coldVotes;
  final int expiredVotes;
  final int commentCount;
  final String postedBy;
  final DateTime createdAt;
  final bool isEditorPick;
  final bool isApproved;
  final bool isExpired;

  Deal({
    required this.id,
    required this.title,
    this.description = '',
    required this.price,
    this.originalPrice,
    this.discountRate,
    required this.store,
    required this.category,
    this.subCategory,
    required this.link,
    required this.imageUrl,
    required this.hotVotes,
    required this.coldVotes,
      this.expiredVotes = 0,
    required this.commentCount,
    required this.postedBy,
    required this.createdAt,
    required this.isEditorPick,
    this.isApproved = false,
    this.isExpired = false,
  });

  // Firestore'dan Deal oluşturma
  factory Deal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // createdAt'i parse et (Timestamp, DateTime veya String formatını destekle)
    DateTime createdAt;
    try {
      final createdAtValue = data['createdAt'];
      if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else if (createdAtValue is String) {
        // ISO format string'den parse et (farklı formatları destekle)
        try {
          // Önce ISO formatını dene
          createdAt = DateTime.parse(createdAtValue);
        } catch (e1) {
          try {
            // Eğer ISO formatı değilse, farklı formatları dene
            // Örnek: "2025-11-18 19:19:23.957114"
            final cleaned = createdAtValue.replaceAll(' ', 'T');
            if (cleaned.contains('.')) {
              // Mikrosaniye varsa
              final parts = cleaned.split('.');
              if (parts.length == 2) {
                final mainPart = parts[0];
                final microPart = parts[1].split(' ')[0];
                createdAt = DateTime.parse('${mainPart}.${microPart}Z');
              } else {
                createdAt = DateTime.parse(cleaned + 'Z');
              }
            } else {
              createdAt = DateTime.parse(cleaned + 'Z');
            }
          } catch (e2) {
            print('⚠️ createdAt string parse hatası: $e2, değer: $createdAtValue');
            createdAt = DateTime.now();
          }
        }
      } else if (createdAtValue is Map) {
        // REST API'den gelen timestamp formatı: {'timestampValue': '2024-01-01T00:00:00Z'}
        final timestampStr = createdAtValue['timestampValue'] ?? createdAtValue['seconds'];
        if (timestampStr != null) {
          if (timestampStr is String) {
            createdAt = DateTime.parse(timestampStr);
          } else if (timestampStr is int) {
            createdAt = DateTime.fromMillisecondsSinceEpoch(timestampStr * 1000);
          } else {
            createdAt = DateTime.now();
          }
        } else {
          createdAt = DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      print('⚠️ createdAt parse hatası: $e, değer: ${data['createdAt']}');
      createdAt = DateTime.now();
    }
    
    // Kategori formatını normalize et (eski bot formatlarını yeni formata çevir)
    String category = data['category'] ?? '';
    final categoryIdToName = {
      // Eski bot kategori ID'leri -> Yeni kategori isimleri
      'giyim_moda': 'Moda & Giyim',
      'bilgisayar': 'Elektronik',
      'mobil_cihazlar': 'Elektronik',
      'konsol_oyun': 'Kitap, Müzik & Hobi',
      'ev_elektronigi_yasam': 'Ev, Yaşam & Ofis',
      'kozmetik_bakim': 'Kozmetik & Bakım',
      'oto_yapi_market': 'Yapı Market & Oto',
      'ag_yazilim': 'Elektronik',
      'evcil_hayvan': 'Süpermarket',
      'diger': 'Elektronik',
      'tumu': 'Elektronik',
      // Yeni kategori ID'leri -> Kategori isimleri
      'elektronik': 'Elektronik',
      'moda': 'Moda & Giyim',
      'ev_yasam': 'Ev, Yaşam & Ofis',
      'anne_bebek': 'Anne & Bebek',
      'kozmetik': 'Kozmetik & Bakım',
      'spor_outdoor': 'Spor & Outdoor',
      'supermarket': 'Süpermarket',
      'yapi_oto': 'Yapı Market & Oto',
      'kitap_hobi': 'Kitap, Müzik & Hobi',
    };
    // Eğer kategori ID formatındaysa kategori ismine çevir
    category = categoryIdToName[category] ?? category;
    
    return Deal(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? data['rawMessage'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      originalPrice: data['originalPrice'] != null ? (data['originalPrice']).toDouble() : null,
      discountRate: data['discountRate'] != null ? (data['discountRate'] as num).toInt() : null,
      store: data['store'] ?? '',
      category: category,  // Normalize edilmiş kategori
      subCategory: data['subCategory'],
      link: data['link'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      hotVotes: (data['hotVotes'] ?? 0) is int ? (data['hotVotes'] ?? 0) : ((data['hotVotes'] ?? 0) as num).toInt(),
      coldVotes: (data['coldVotes'] ?? 0) is int ? (data['coldVotes'] ?? 0) : ((data['coldVotes'] ?? 0) as num).toInt(),
      expiredVotes: (data['expiredVotes'] ?? 0) is int ? (data['expiredVotes'] ?? 0) : ((data['expiredVotes'] ?? 0) as num).toInt(),
      commentCount: (data['commentCount'] ?? 0) is int ? (data['commentCount'] ?? 0) : ((data['commentCount'] ?? 0) as num).toInt(),
      postedBy: data['postedBy'] ?? '',
      createdAt: createdAt,
      isEditorPick: data['isEditorPick'] == true,
      isApproved: data['isApproved'] == true,
      isExpired: data['isExpired'] == true,
    );
  }

  // Deal'i Firestore'a yazmak için Map'e dönüştürme
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'discountRate': discountRate,
      'store': store,
      'category': category,
      'subCategory': subCategory,
      'link': link,
      'imageUrl': imageUrl,
      'hotVotes': hotVotes,
      'coldVotes': coldVotes,
      'expiredVotes': expiredVotes,
      'commentCount': commentCount,
      'postedBy': postedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isEditorPick': isEditorPick,
      'isApproved': isApproved,
      'isExpired': isExpired,
    };
  }
}

