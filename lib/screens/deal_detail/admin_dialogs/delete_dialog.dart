import 'package:flutter/material.dart';
import '../../../models/deal.dart';
import '../../../services/firestore_service.dart';

/// Silme onay dialog'u.
Future<void> showDeleteDialog({
  required BuildContext context,
  required Deal deal,
  required FirestoreService firestoreService,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Fırsatı Sil'),
      content: Text('Bu fırsatı kalıcı olarak silmek istediğinize emin misiniz?\n\n"${deal.title}"\n\nBu işlem geri alınamaz.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('Evet, Sil'),
        ),
      ],
    ),
  );

  if (confirm != true || !context.mounted) return;

  final success = await firestoreService.deleteDeal(deal.id);
  if (context.mounted) {
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat silindi 🗑️'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silme işlemi başarısız ❌'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
