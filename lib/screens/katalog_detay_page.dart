import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/katalog.dart';

class KatalogDetayPage extends StatefulWidget {
  final Katalog catalog;

  const KatalogDetayPage({
    super.key,
    required this.catalog,
  });

  @override
  State<KatalogDetayPage> createState() => _KatalogDetayPageState();
}

class _KatalogDetayPageState extends State<KatalogDetayPage> {
  late final PageController _pageController;
  late final TransformationController _transformationController;
  int _currentPage = 0;
  bool _isZoomed = false;
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleZoomChange);
  }

  void _handleZoomChange() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomedNow = scale > 1.0;
    if (isZoomedNow != _isZoomed) {
      setState(() {
        _isZoomed = isZoomedNow;
      });
    }
  }

  void _handleDoubleTap() {
    if (_transformationController.value.getMaxScaleOnAxis() > 1.0) {
      // Zoom out to normal
      setState(() {
        _isZoomed = false;
      });
      _transformationController.value = Matrix4.identity();
    } else {
      // Zoom in to 2.5x exactly centered
      setState(() {
        _isZoomed = true;
      });
      final double scale = 2.5;
      final double width = MediaQuery.of(context).size.width;
      final double height = MediaQuery.of(context).size.height;
      
      final double x = -(width * (scale - 1)) / 2;
      final double y = -(height * (scale - 1)) / 2;
      
      _transformationController.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(scale, scale, 1.0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.removeListener(_handleZoomChange);
    _transformationController.dispose();
    super.dispose();
  }

  String _getValidityText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      widget.catalog.bitisTarihi.year,
      widget.catalog.bitisTarihi.month,
      widget.catalog.bitisTarihi.day,
    );
    final diff = expiry.difference(today).inDays;

    if (diff < 0) {
      return "Süresi Doldu";
    } else if (diff == 0) {
      return "Son Gün: Bugün!";
    } else if (diff == 1) {
      return "Son Gün: Yarın!";
    } else if (diff < 7) {
      return "Son Gün: $diff Gün Kaldı";
    } else {
      final weeks = diff ~/ 7;
      return "Son Gün: $weeks Hafta Kaldı";
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.catalog.sayfaResimleri.length;

    return Scaffold(
      backgroundColor: Colors.black, // Dark cinematic reader view
      body: Stack(
        children: [
          // Main PageView with zoomable images
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (index) {
                _transformationController.value = Matrix4.identity();
                setState(() {
                  _currentPage = index;
                  _isZoomed = false;
                  _pointerCount = 0;
                });
              },
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final isCurrent = index == _currentPage;
                return Listener(
                  onPointerDown: (event) {
                    if (isCurrent) {
                      _pointerCount++;
                      if (_pointerCount >= 2) {
                        setState(() {
                          _isZoomed = true;
                        });
                      }
                    }
                  },
                  onPointerUp: (event) {
                    if (isCurrent) {
                      _pointerCount = (_pointerCount - 1).clamp(0, 99);
                      if (_pointerCount < 2 && _transformationController.value.getMaxScaleOnAxis() <= 1.0) {
                        setState(() {
                          _isZoomed = false;
                        });
                      }
                    }
                  },
                  onPointerCancel: (event) {
                    if (isCurrent) {
                      _pointerCount = (_pointerCount - 1).clamp(0, 99);
                      if (_pointerCount < 2 && _transformationController.value.getMaxScaleOnAxis() <= 1.0) {
                        setState(() {
                          _isZoomed = false;
                        });
                      }
                    }
                  },
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      transformationController: isCurrent ? _transformationController : null,
                      onInteractionEnd: (details) {
                        if (isCurrent && _transformationController.value.getMaxScaleOnAxis() <= 1.0) {
                          setState(() {
                            _isZoomed = false;
                          });
                        }
                      },
                      child: GestureDetector(
                        onDoubleTap: isCurrent ? _handleDoubleTap : null,
                        child: CachedNetworkImage(
                          imageUrl: widget.catalog.sayfaResimleri[index],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.white60, size: 60),
                                SizedBox(height: 12),
                                Text(
                                  'Görsel yüklenemedi',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Custom Top Overlay Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 16,
                left: 8,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.catalog.katalogBasligi,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getValidityText(),
                          style: TextStyle(
                            color: Colors.red[400] ?? Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Custom Bottom Overlay Page Indicator
          if (pageCount > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text indicator (e.g. 1 / 13)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_currentPage + 1} / $pageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Line/Dots indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pageCount,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == index ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
