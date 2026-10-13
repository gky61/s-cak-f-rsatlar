import 'dart:async';
import 'package:flutter/material.dart';

import '../models/deal.dart';
import '../services/deal_sync_service.dart';
import '../services/link_preview_service.dart';
import '../services/theme_service.dart';
import '../screens/deal_detail_screen.dart';
import 'deal_card/deal_card_helpers.dart';
import 'deal_card/vertical_deal_card.dart';
import 'deal_card/horizontal_deal_card.dart';

/// FırsatKartı (DealCard) — Çift Kademeli Reaktif Bileşen Mimarisi
///
/// Bulunduğu ekran (Anasayfa, Popüler, Profil, Kaydedilenler, Botkolik vb.)
/// listeyi yenilememiş olsa dahi, Event Bus (`DealSyncService`) üzerinden
/// kendi `deal.id`'sine ait oylama, yorum, stok bitti ve düzenleme olaylarını
/// 0ms gecikmeyle yerel bellekte yakalar ve anında kendini günceller.
class DealCard extends StatefulWidget {
  final Deal deal;
  final VoidCallback? onTap;
  final CardViewMode viewMode;

  const DealCard({
    super.key,
    required this.deal,
    this.onTap,
    this.viewMode = CardViewMode.vertical,
  });

  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  late Deal _currentDeal;
  StreamSubscription<DealSyncEvent>? _syncSub;
  String? _effectiveImageUrl;
  bool _isLoadingImage = false;
  bool _imageLoadAttempted = false;

  final LinkPreviewService _linkPreviewService = LinkPreviewService();

  Future<void> _handleOnTap() async {
    if (_currentDeal.isArchived) {
      showExpiredBottomSheet(context, _currentDeal);
    } else if (widget.onTap != null) {
      widget.onTap!();
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DealDetailScreen(dealId: _currentDeal.id),
        ),
      );
      if (result is Deal && mounted) {
        DealSyncService.instance.notifyDealUpdated(result);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentDeal = widget.deal;
    _checkImage();
    _syncSub = DealSyncService.instance.stream.listen((event) {
      if (!mounted || event.dealId != _currentDeal.id) return;
      if (event.action != DealSyncAction.dealDeleted) {
        setState(() {
          _currentDeal = event.applyTo(_currentDeal);
        });
      }
    });
  }

  @override
  void didUpdateWidget(DealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.id != widget.deal.id) {
      _currentDeal = widget.deal;
      _imageLoadAttempted = false;
      _checkImage();
    } else if (oldWidget.deal != widget.deal) {
      _currentDeal = widget.deal;
      if (oldWidget.deal.imageUrl != widget.deal.imageUrl) {
        _checkImage();
      }
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }
    
  void _checkImage() {
    final dealImageUrl = _currentDeal.imageUrl.trim();
    final isBlobUrl = dealImageUrl.startsWith('blob:');
    
    if (isBlobUrl || dealImageUrl.isEmpty) {
      _effectiveImageUrl = null;
    } else {
      _effectiveImageUrl = dealImageUrl;
    }
    
    // Yalnızca Amazon linklerinde deterministik ve güvenli ASIN görsel çözümlemesi yap.
    // Diğer mağazalarda generic banner çekilmesini engelleyerek temiz mağaza logosu fallback'ini koru.
    if (!_imageLoadAttempted && (_effectiveImageUrl == null || isBlobUrl) && _currentDeal.displayUrl.isNotEmpty) {
      final link = _currentDeal.displayUrl.trim();
      if (link.contains("amazon") || link.contains("amzn")) {
        _imageLoadAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadAmazonImage(link);
        });
      }
    }
  }
  
  Future<void> _loadAmazonImage(String link) async {
    if (_isLoadingImage || !mounted) return;
    _isLoadingImage = true;

    try {
      final amazonImage = await _linkPreviewService.getAmazonImageSmart(link);
      if (amazonImage != null && mounted) {
        setState(() {
          _effectiveImageUrl = Deal.ensureHttps(amazonImage);
          _isLoadingImage = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.viewMode == CardViewMode.horizontal) {
      return HorizontalDealCard(
        deal: _currentDeal,
        onTap: _handleOnTap,
        effectiveImageUrl: _effectiveImageUrl,
        isLoadingImage: _isLoadingImage,
      );
    }
    
    return VerticalDealCard(
      deal: _currentDeal,
      onTap: _handleOnTap,
      effectiveImageUrl: _effectiveImageUrl,
      isLoadingImage: _isLoadingImage,
    );
  }
}
