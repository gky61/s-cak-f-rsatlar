import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../models/deal.dart';
import '../services/link_preview_service.dart';
import '../services/theme_service.dart';
import 'deal_card/deal_card_helpers.dart';
import 'deal_card/vertical_deal_card.dart';
import 'deal_card/horizontal_deal_card.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

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
    
  void _checkImage() async {
    final dealImageUrl = widget.deal.imageUrl.trim();
    final isBlobUrl = dealImageUrl.startsWith('blob:');
    
    if (isBlobUrl) {
      _effectiveImageUrl = null;
    } else {
      _effectiveImageUrl = dealImageUrl.isNotEmpty ? dealImageUrl : null;
    }
    
    if (!_imageLoadAttempted && (_effectiveImageUrl == null || isBlobUrl) && widget.deal.link.isNotEmpty) {
      _imageLoadAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadImageFromLink();
      });
    }
  }
  
  Future<void> _loadImageFromLink() async {
    if (_isLoadingImage || !mounted) return;
    final link = widget.deal.link.trim();
    if (link.isEmpty) return;

    // --- AMAZON ÖZEL KONTROLÜ BAŞLANGIÇ ---
    if (link.contains("amazon") || link.contains("amzn")) {
      final amazonImage = await _linkPreviewService.getAmazonImageSmart(link);
      
      if (amazonImage != null && mounted) {
        _log('✅ DealCard: Amazon görsel bulundu (ASIN yöntemi): $amazonImage');
        setState(() {
          _effectiveImageUrl = amazonImage;
          _isLoadingImage = false;
        });
        return;
      } else {
        _log('⚠️ DealCard: Amazon ASIN bulunamadı, normal scraper yöntemi deneniyor...');
      }
    }
    // --- AMAZON ÖZEL KONTROLÜ BİTİŞ ---

    _isLoadingImage = true;

    try {
      final preview = await _linkPreviewService.fetchMetadata(link)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      
      if (mounted && preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty) {
        setState(() {
          _effectiveImageUrl = preview.imageUrl;
          _isLoadingImage = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    } catch (e) {
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
