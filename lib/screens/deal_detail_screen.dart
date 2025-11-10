import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/deal.dart';

class DealDetailScreen extends StatelessWidget {
  final String dealId;

  const DealDetailScreen({
    super.key,
    required this.dealId,
  });

  @override
  Widget build(BuildContext context) {
    final FirestoreService _firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fırsat Detayı'),
      ),
      body: FutureBuilder<Deal?>(
        future: _firestoreService.getDeal(dealId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Fırsat bulunamadı'),
            );
          }

          final deal = snapshot.data!;
          // TODO: Detay sayfası içeriği eklenecek

          return Center(
            child: Text('Deal ID: ${deal.id}'),
          );
        },
      ),
    );
  }
}

