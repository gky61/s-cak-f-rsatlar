import 'package:cloud_firestore/cloud_firestore.dart';

class Deal {
  final String id;
  final String title;
  final double price;
  final String store;
  final String category;
  final String link;
  final String imageUrl;
  final int hotVotes;
  final int coldVotes;
  final int commentCount;
  final String postedBy;
  final DateTime createdAt;
  final bool isEditorPick;

  Deal({
    required this.id,
    required this.title,
    required this.price,
    required this.store,
    required this.category,
    required this.link,
    required this.imageUrl,
    required this.hotVotes,
    required this.coldVotes,
    required this.commentCount,
    required this.postedBy,
    required this.createdAt,
    required this.isEditorPick,
  });

  // Firestore'dan Deal oluşturma
  factory Deal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Deal(
      id: doc.id,
      title: data['title'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      store: data['store'] ?? '',
      category: data['category'] ?? '',
      link: data['link'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      hotVotes: data['hotVotes'] ?? 0,
      coldVotes: data['coldVotes'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      postedBy: data['postedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEditorPick: data['isEditorPick'] ?? false,
    );
  }

  // Deal'i Firestore'a yazmak için Map'e dönüştürme
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'price': price,
      'store': store,
      'category': category,
      'link': link,
      'imageUrl': imageUrl,
      'hotVotes': hotVotes,
      'coldVotes': coldVotes,
      'commentCount': commentCount,
      'postedBy': postedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isEditorPick': isEditorPick,
    };
  }
}

