import 'package:flutter/material.dart';
import '../../models/deal.dart';
import '../../services/firestore_service.dart';

import 'admin_dialogs/admin_edit_sheet.dart' as edit_sheet;
import 'admin_dialogs/approval_dialogs.dart' as approval;
import 'admin_dialogs/category_selector.dart' as cat_sel;
import 'admin_dialogs/delete_dialog.dart' as del;
import 'admin_dialogs/edit_dialogs.dart' as edit_dlg;

/// Admin'e özel tüm düzenleme formlarını, onaylama akışlarını ve diyalogları içerir.
class DealAdminDialogs {
  DealAdminDialogs._();

  /// Admin düzenleme bottom sheet'ini gösterir.
  static void showAdminEditSheet({
    required BuildContext context,
    required Deal deal,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => edit_sheet.showAdminEditSheet(
    context: context,
    deal: deal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );

  /// Kategori gösterim helper'ı.
  static String getCategoryDisplayText(String categoryId, String? subCategory) =>
      cat_sel.getCategoryDisplayText(categoryId, subCategory);

  /// Deal için kategori gösterim helper'ı.
  static String getCategoryDisplayTextForDeal(Deal deal) =>
      cat_sel.getCategoryDisplayTextForDeal(deal);

  /// Onaylama akışını başlatan wrapper.
  static Future<void> confirmApproval({
    required BuildContext context,
    required String dealId,
    required Deal? currentDeal,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => approval.confirmApproval(
    context: context,
    dealId: dealId,
    currentDeal: currentDeal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );

  /// Onaylama seçenekleri dialog'u.
  static Future<void> showApproveOptions({
    required BuildContext context,
    required String dealId,
    required Deal? currentDeal,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => approval.showApproveOptions(
    context: context,
    dealId: dealId,
    currentDeal: currentDeal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );

  /// Yayından kaldırma.
  static Future<void> unpublishDeal({
    required BuildContext context,
    required String dealId,
    required FirestoreService firestoreService,
  }) => approval.unpublishDeal(
    context: context,
    dealId: dealId,
    firestoreService: firestoreService,
  );

  /// Kategori seçici bottom sheet.
  static Future<void> showCategorySelector({
    required BuildContext context,
    required Deal deal,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => cat_sel.showCategorySelector(
    context: context,
    deal: deal,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );

  /// Fırsatı reddetme.
  static Future<void> rejectDeal({
    required BuildContext context,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => approval.rejectDeal(
    context: context,
    dealId: dealId,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );

  /// Silme onay dialog'u.
  static Future<void> showDeleteDialog({
    required BuildContext context,
    required Deal deal,
    required FirestoreService firestoreService,
  }) => del.showDeleteDialog(
    context: context,
    deal: deal,
    firestoreService: firestoreService,
  );

  /// Admin detay düzenleme dialog'u.
  static Future<void> showAdminEditDialog({
    required BuildContext context,
    required Deal deal,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => edit_dlg.showAdminEditDialog(
    context: context,
    deal: deal,
    dealId: dealId,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );

  /// Fiyat düzenleme dialog'u.
  static Future<void> showPriceEditDialog({
    required BuildContext context,
    required Deal deal,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => edit_dlg.showPriceEditDialog(
    context: context,
    deal: deal,
    dealId: dealId,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );

  /// Açıklama düzenleme dialog'u.
  static Future<void> showEditDescriptionDialog({
    required BuildContext context,
    required Deal deal,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => edit_dlg.showEditDescriptionDialog(
    context: context,
    deal: deal,
    dealId: dealId,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );

  /// Kategori düzenleme dialog'u.
  static Future<void> showCategoryEditDialog({
    required BuildContext context,
    required Deal deal,
    required String dealId,
    required FirestoreService firestoreService,
    required VoidCallback onDealUpdated,
  }) => edit_dlg.showCategoryEditDialog(
    context: context,
    deal: deal,
    dealId: dealId,
    firestoreService: firestoreService,
    onDealUpdated: onDealUpdated,
  );
}
