import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';

import 'category.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

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
  final bool? isApproved; // Nullable: Bot'un yazdığı verilerde olmayabilir
  final bool isExpired;
  final bool isUserSubmitted; // Kullanıcı tarafından paylaşıldı mı?
  final bool isTest; // Test verisi mi?
  final String cleanUrl;
  final String? priceLabel; // Fiyat etiket notu (CRM kampanya bilgisi vb.)
  final double? ratingValue; // Değerlendirme puanı (ör. 4.8)
  final int? ratingCount; // Değerlendirme sayısı (ör. 1173)
  final String? brand; // Marka (ör. Apple)

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
    this.isApproved,
    this.isExpired = false,
    this.isUserSubmitted = false,
    this.isTest = false,
    this.cleanUrl = '',
    this.priceLabel,
    this.ratingValue,
    this.ratingCount,
    this.brand,
  });



  // URL parametrelerini temizleyen statik fonksiyon
  static String cleanProductUrl(String urlStr) {
    if (urlStr.isEmpty) return '';
    try {
      final uri = Uri.parse(urlStr.trim());
      final host = uri.host.toLowerCase();
      
      // Bilinen büyük mağazaların listesi
      final majorStores = [
        'amazon',
        'trendyol',
        'hepsiburada',
        'n11',
        'pazarama',
        'pttavm',
        'zara',
        'defacto',
        'mavi',
        'beymen',
        'teknosa',
        'mediamarkt',
        'migros',
        'getir',
        'vatanbilgisayar',
        'idefix',
        'itopya',
        'incehesap',
        'havit'
      ];
      
      bool isMajorStore = false;
      for (var store in majorStores) {
        if (host.contains(store)) {
          isMajorStore = true;
          break;
        }
      }
      
      if (isMajorStore) {
        // Büyük mağazalar için query parametrelerini tamamen temizle
        return uri.replace(queryParameters: {}).toString().replaceAll(RegExp(r'\?$'), '');
      } else {
        // Diğer mağazalar için sadece ürün kimlik parametrelerini koru, kalanları sil
        final queryParameters = Map<String, String>.from(uri.queryParameters);
        final keysToKeep = ['id', 'productid', 'product_id', 'p', 'item_id', 'itemid', 'sku'];
        
        final keysToRemove = [];
        queryParameters.forEach((key, value) {
          if (!keysToKeep.contains(key.toLowerCase())) {
            keysToRemove.add(key);
          }
        });
        
        for (var key in keysToRemove) {
          queryParameters.remove(key);
        }
        
        if (queryParameters.isEmpty) {
          return uri.replace(queryParameters: {}).toString().replaceAll(RegExp(r'\?$'), '');
        }
        return uri.replace(queryParameters: queryParameters).toString();
      }
    } catch (e) {
      return urlStr;
    }
  }

  // Firestore'dan Deal oluşturma
  factory Deal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // createdAt'i parse et (timestamp veya createdAt alanını kontrol et)
    DateTime createdAt;
    try {
      // Bot 'timestamp' yazıyor, eski kodlar 'createdAt' kullanıyor - her ikisini de destekle
      final createdAtValue = data['timestamp'] ?? data['createdAt'];
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
            _log('⚠️ createdAt string parse hatası: $e2, değer: $createdAtValue');
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
      _log('⚠️ createdAt parse hatası: $e, değer: ${data['createdAt']}');
      createdAt = DateTime.now();
    }
    
    // price alanını parse et (bot String yazıyor, double'a çevir)
    double priceValue = 0.0;
    try {
      final priceData = data['price'];
      if (priceData is String) {
        // String'den double'a çevir (virgül, nokta, boşluk temizle)
        final cleaned = priceData.replaceAll(',', '.').replaceAll(' ', '').replaceAll('₺', '').replaceAll('TL', '');
        priceValue = double.tryParse(cleaned) ?? 0.0;
      } else if (priceData is num) {
        priceValue = priceData.toDouble();
      } else {
        priceValue = 0.0;
      }
    } catch (e) {
      _log('⚠️ price parse hatası: $e, değer: ${data['price']}');
      priceValue = 0.0;
    }
    
    return Deal(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? data['desc'] ?? data['rawMessage'] ?? '', // Bot 'desc' yazıyor
      price: priceValue,
      originalPrice: data['originalPrice'] != null ? (data['originalPrice'] as num).toDouble() : (data['original_price'] != null ? (data['original_price'] as num).toDouble() : null),
      discountRate: data['discountRate'] != null ? (data['discountRate'] as num).toInt() : (data['discount_rate'] != null ? (data['discount_rate'] as num).toInt() : null),
      store: data['store'] ?? '',
      category: Category.normalizeCategoryId((data['category'] ?? '').toString()),
      subCategory: data['subCategory'],
      link: data['link'] ?? data['url'] ?? '', // Bot 'url' de yazabilir
      imageUrl: data['imageUrl'] ?? data['image_url'] ?? '', // Hem imageUrl hem image_url destekle
      hotVotes: (data['hotVotes'] ?? 0) is int ? (data['hotVotes'] ?? 0) : ((data['hotVotes'] ?? 0) as num).toInt(),
      coldVotes: (data['coldVotes'] ?? 0) is int ? (data['coldVotes'] ?? 0) : ((data['coldVotes'] ?? 0) as num).toInt(),
      expiredVotes: (data['expiredVotes'] ?? 0) is int ? (data['expiredVotes'] ?? 0) : ((data['expiredVotes'] ?? 0) as num).toInt(),
      commentCount: (data['commentCount'] ?? 0) is int ? (data['commentCount'] ?? 0) : ((data['commentCount'] ?? 0) as num).toInt(),
      postedBy: data['postedBy'] ?? '',
      createdAt: createdAt,
      isEditorPick: data['isEditorPick'] == true,
      isApproved: data.containsKey('isApproved') ? data['isApproved'] as bool? : null, // Alan yoksa null, varsa değerini al
      isExpired: data['isExpired'] == true,
      isUserSubmitted: data['isUserSubmitted'] == true,
      isTest: data['isTest'] == true,
      cleanUrl: data['cleanUrl'] ?? cleanProductUrl(data['link'] ?? data['url'] ?? ''),
      priceLabel: data['priceLabel'],
      ratingValue: data['ratingValue'] != null ? (data['ratingValue'] as num).toDouble() : null,
      ratingCount: data['ratingCount'] != null ? (data['ratingCount'] as num).toInt() : null,
      brand: data['brand']?.toString(),
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
      'isUserSubmitted': isUserSubmitted,
      'isTest': isTest,
      'cleanUrl': cleanUrl.isNotEmpty ? cleanUrl : cleanProductUrl(link),
      'priceLabel': priceLabel,
      'ratingValue': ratingValue,
      'ratingCount': ratingCount,
      'brand': brand,
    };
  }

  // Net Skor: Sıcak oylar ile Soğuk oylar arasındaki fark
  int get netScore => hotVotes - coldVotes;

  // Wilson Score: Oy oranı ile oy hacmini dengeleyen profesyonel güven puanı
  double get wilsonScore {
    final n = hotVotes + coldVotes;
    if (n == 0) return 0.0;
    
    final p = hotVotes / n;
    const z = 1.96; // %95 Güven aralığı sabiti
    
    final p1 = p + (z * z) / (2 * n);
    final p2 = z * sqrt((p * (1 - p) / n) + (z * z) / (4 * n * n));
    final divider = 1 + (z * z) / n;
    
    return (p1 - p2) / divider;
  }

  // Sıralama Grubu:
  // Grup 1: Sıcak Fırsatlar (toplam oy >= 3 ve başarı oranı >= 70%)
  // Grup 2: Normal / Yeni Fırsatlar (oylanmamışlar veya araftakiler)
  // Grup 3: Çöp Fırsatlar (Net Skor <= -8)
  int get sortingGroup {
    if (netScore <= -8) return 3;
    final toplamOy = hotVotes + coldVotes;
    if (toplamOy >= 3 && (hotVotes / toplamOy) >= 0.7) return 1;
    return 2;
  }

  // Profesyonel Sıralama Karşılaştırıcısı (Comparator)
  static int compareDeals(Deal a, Deal b) {
    final groupA = a.sortingGroup;
    final groupB = b.sortingGroup;

    if (groupA != groupB) {
      return groupA.compareTo(groupB); // Düşük grup numarası (1 olan) en üstte
    }

    // Her iki fırsat da Sıcak Grubu'ndaysa (Grup 1)
    if (groupA == 1) {
      // Wilson Score'a göre azalan sırada sırala
      final cmp = b.wilsonScore.compareTo(a.wilsonScore);
      if (cmp != 0) return cmp;
      // Wilson Score eşitse toplam sıcak oy sayısına bak
      return b.hotVotes.compareTo(a.hotVotes);
    }

    // Her iki fırsat da Normal/Yeni Grubu'ndaysa (Grup 2)
    if (groupA == 2) {
      // Oluşturulma tarihine göre azalan sırada (en yeni en üstte)
      return b.createdAt.compareTo(a.createdAt);
    }

    // Her iki fırsat da Çöp Grubu'ndaysa (Grup 3)
    // Daha az kötü olan (netSkoru daha yüksek olan) üstte kalsın
    return b.netScore.compareTo(a.netScore);
  }
}

class DynamicCurrencyFormatter {
  final String symbol;
  DynamicCurrencyFormatter({this.symbol = '₺'});

  String format(num? value) {
    if (value == null) return '';
    final dValue = value.toDouble();
    final decimalDigits = dValue == dValue.toInt() ? 0 : 2;
    return NumberFormat.currency(symbol: symbol, decimalDigits: decimalDigits).format(value);
  }
}

