import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/katalog.dart';
import '../services/katalog_share_service.dart';

class KatalogDetayPage extends StatefulWidget {
  final Katalog catalog;

  const KatalogDetayPage({
    super.key,
    required this.catalog,
  });

  @override
  State<KatalogDetayPage> createState() => _KatalogDetayPageState();
}

class _KatalogDetayPageState extends State<KatalogDetayPage> with TickerProviderStateMixin {
  late final PageController _pageController;
  late final TransformationController _transformationController;
  late final AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;

  int _currentPage = 0;
  bool _isZoomed = false;
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleZoomChange);

    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _zoomAnimController.addListener(() {
      if (_zoomAnimation != null) {
        _transformationController.value = _zoomAnimation!.value;
      }
    });
  }

  void _handleZoomChange() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomedNow = scale > 1.02;
    if (isZoomedNow != _isZoomed) {
      setState(() {
        _isZoomed = isZoomedNow;
      });
    }
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final Matrix4 targetMatrix;

    if (currentScale > 1.02) {
      // Zoom out smoothly to identity
      targetMatrix = Matrix4.identity();
    } else {
      // Zoom in to 2.5x, centered on screen
      const double scale = 2.5;
      final double width = MediaQuery.of(context).size.width;
      final double height = MediaQuery.of(context).size.height;
      final double x = -(width * (scale - 1)) / 2;
      final double y = -(height * (scale - 1)) / 2;
      targetMatrix = Matrix4.identity()
        ..translateByDouble(x, y, 0.0, 1.0)
        ..scaleByDouble(scale, scale, 1.0, 1.0);
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value.clone(),
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimController,
      curve: Curves.easeInOutCubic,
    ));

    _zoomAnimController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.removeListener(_handleZoomChange);
    _transformationController.dispose();
    _zoomAnimController.dispose();
    super.dispose();
  }

  String _getValidityText() {
    return widget.catalog.getValidityText();
  }

  Color _getValidityColor() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final start = DateTime(
      widget.catalog.baslangicTarihi.year,
      widget.catalog.baslangicTarihi.month,
      widget.catalog.baslangicTarihi.day,
    );
    
    final expiry = DateTime(
      widget.catalog.bitisTarihi.year,
      widget.catalog.bitisTarihi.month,
      widget.catalog.bitisTarihi.day,
    );

    if (today.isBefore(start)) {
      return const Color(0xFF60A5FA); // Blue 400
    } else {
      final diff = expiry.difference(today).inDays;
      if (diff < 0) {
        return const Color(0xFFA1A1AA); // Zinc 400
      } else if (diff <= 1) {
        return const Color(0xFFF87171); // Red 400
      } else if (diff <= 3) {
        return const Color(0xFFFBBF24); // Amber 400
      } else {
        return const Color(0xFF4ADE80); // Green 400
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.catalog.sayfaResimleri.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. MAIN PAGEVIEW WITH ZOOMABLE HIGH-RES IMAGES
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (index) {
                _zoomAnimController.stop();
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
                      if (_pointerCount < 2 &&
                          _transformationController.value.getMaxScaleOnAxis() <= 1.02) {
                        setState(() {
                          _isZoomed = false;
                        });
                      }
                    }
                  },
                  onPointerCancel: (event) {
                    if (isCurrent) {
                      _pointerCount = (_pointerCount - 1).clamp(0, 99);
                      if (_pointerCount < 2 &&
                          _transformationController.value.getMaxScaleOnAxis() <= 1.02) {
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
                        if (isCurrent &&
                            _transformationController.value.getMaxScaleOnAxis() <= 1.02) {
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
                              strokeWidth: 2.5,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Colors.white60, size: 56),
                                SizedBox(height: 12),
                                Text(
                                  'Görsel yüklenemedi',
                                  style: TextStyle(color: Colors.white70, fontSize: 15),
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

          // 2. FROSTED GLASS TOP OVERLAY BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 14,
                    left: 12,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Frosted Back Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title and Validity Tag
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.catalog.katalogBasligi,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getValidityColor(),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _getValidityText(),
                                  style: TextStyle(
                                    color: _getValidityColor(),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Modern Share Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            KatalogShareService.shareCatalogPage(
                              context,
                              catalog: widget.catalog,
                              currentPageIndex: _currentPage,
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.share_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. FROSTED GLASS BOTTOM PAGE INDICATOR
          if (pageCount > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                      top: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Page Count Capsule
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Sayfa ${_currentPage + 1} / $pageCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Page Dots Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            pageCount,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentPage == index ? 16 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
