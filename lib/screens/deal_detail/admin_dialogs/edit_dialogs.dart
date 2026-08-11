import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../../models/deal.dart';
import '../../../services/firestore_service.dart';
import 'admin_edit_sheet.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Admin detay düzenleme dialog'u - tek ve zengin showAdminEditSheet'e yönlendirir.
Future<void> showAdminEditDialog({
  required BuildContext context,
  required Deal deal,
  required String dealId,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  showAdminEditSheet(
    context: context,
    deal: deal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );
}

/// Fiyat düzenleme dialog'u - tek ve zengin showAdminEditSheet'e yönlendirir.
Future<void> showPriceEditDialog({
  required BuildContext context,
  required Deal deal,
  required String dealId,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  showAdminEditSheet(
    context: context,
    deal: deal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );
}

/// Açıklama düzenleme dialog'u - tek ve zengin showAdminEditSheet'e yönlendirir.
Future<void> showEditDescriptionDialog({
  required BuildContext context,
  required Deal deal,
  required String dealId,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  showAdminEditSheet(
    context: context,
    deal: deal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );
}

/// Kategori düzenleme dialog'u - tek ve zengin showAdminEditSheet'e yönlendirir.
Future<void> showCategoryEditDialog({
  required BuildContext context,
  required Deal deal,
  required String dealId,
  required FirestoreService firestoreService,
  required VoidCallback onDealUpdated,
}) async {
  showAdminEditSheet(
    context: context,
    deal: deal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );
}
