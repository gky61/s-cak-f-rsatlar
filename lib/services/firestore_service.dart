import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deal.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Deals koleksiyonunu createdAt'e göre sıralayarak dinleme
  Stream<List<Deal>> getDealsStream() {
    return _firestore
        .collection('deals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Deal.fromFirestore(doc)).toList();
    });
  }

  // Tek bir deal getirme
  Future<Deal?> getDeal(String dealId) async {
    try {
      final doc = await _firestore.collection('deals').doc(dealId).get();
      if (doc.exists) {
        return Deal.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Deal getirme hatası: $e');
      return null;
    }
  }

  // Yeni deal ekleme
  Future<String?> addDeal(Deal deal) async {
    try {
      final docRef = await _firestore.collection('deals').add(deal.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Deal ekleme hatası: $e');
      return null;
    }
  }

  // Deal güncelleme
  Future<bool> updateDeal(String dealId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('deals').doc(dealId).update(updates);
      return true;
    } catch (e) {
      print('Deal güncelleme hatası: $e');
      return false;
    }
  }

  // Hot vote ekleme
  Future<bool> addHotVote(String dealId) async {
    try {
      await _firestore.collection('deals').doc(dealId).update({
        'hotVotes': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      print('Hot vote ekleme hatası: $e');
      return false;
    }
  }

  // Cold vote ekleme
  Future<bool> addColdVote(String dealId) async {
    try {
      await _firestore.collection('deals').doc(dealId).update({
        'coldVotes': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      print('Cold vote ekleme hatası: $e');
      return false;
    }
  }
}

