import 'package:flutter/material.dart';

import '../models/deal.dart';
import '../services/link_preview_service.dart';
import '../services/theme_service.dart';
import 'deal_card/deal_card_helpers.dart';
import 'deal_card/vertical_deal_card.dart';
import 'deal_card/horizontal_deal_card.dart';

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
  String? _effectiveImageUrl;
  bool _isLoadingImage = false;
  bool _imageLoadAttempted = false;

  final LinkPreviewService _linkPreviewService = LinkPreviewService();

  void _handleOnTap() {
    if (widget.deal.isExpired) {
      showExpiredBottomSheet(context, widget.deal);
    } else {
      widget.onTap?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  @override
  void didUpdateWidget(DealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.id != widget.deal.id || oldWidget.deal.imageUrl != widget.deal.imageUrl) {
      _checkImage();
    }
  }
    
  void _checkImage() {
    final dealImageUrl = widget.deal.imageUrl.trim();
    final isBlobUrl = dealImageUrl.startsWith('blob:');
    
    if (isBlobUrl || dealImageUrl.isEmpty) {
      _effectiveImageUrl = null;
    } else {
      _effectiveImageUrl = dealImageUrl;
    }
    
    // Yalnızca Amazon linklerinde deterministik ve güvenli ASIN görsel çözümlemesi yap.
    // Diğer mağazalarda generic banner çekilmesini engelleyerek temiz mağaza logosu fallback'ini koru.
    if (!_imageLoadAttempted && (_effectiveImageUrl == null || isBlobUrl) && widget.deal.link.isNotEmpty) {
      final link = widget.deal.link.trim();
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
          _effectiveImageUrl = amazonImage;
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
        deal: widget.deal,
        onTap: _handleOnTap,
        effectiveImageUrl: _effectiveImageUrl,
        isLoadingImage: _isLoadingImage,
      );
    }
    
    return VerticalDealCard(
      deal: widget.deal,
      onTap: _handleOnTap,
      effectiveImageUrl: _effectiveImageUrl,
      isLoadingImage: _isLoadingImage,
    );
  }
}
