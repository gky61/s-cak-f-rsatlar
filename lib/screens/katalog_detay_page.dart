import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/katalog.dart';
import '../services/katalog_share_service.dart';
import '../services/analytics_service.dart';

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
  late final AnimationController _snapBackAnimController;
  late final AnimationController _dismissAnimController;

  Animation<Matrix4>? _zoomAnimation;
  Animation<Offset>? _snapBackOffsetAnimation;
  Animation<Offset>? _dismissOffsetAnimation;
  Animation<double>? _dismissOpacityAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  int _currentPage = 0;
  bool _isZoomed = false;
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleZoomChange);

    // Observability: Katalog açılış telemetrisi
    AnalyticsService.instance.logCatalogView(
      storeName: widget.catalog.magazaKodu,
      catalogId: widget.catalog.katalogId,
      pageNumber: 1,
    );

    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _zoomAnimController.addListener(() {
      if (_zoomAnimation != null) {
        _transformationController.value = _zoomAnimation!.value;
      }
    });

    _snapBackAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_snapBackOffsetAnimation != null) {
          setState(() {
            _dragOffset = _snapBackOffsetAnimation!.value;
          });
        }
      });

    _dismissAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_dismissOffsetAnimation != null) {
          setState(() {
            _dragOffset = _dismissOffsetAnimation!.value;
          });
        }
      });

    _dismissAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pop();
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
    _snapBackAnimController.dispose();
    _dismissAnimController.dispose();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    _snapBackAnimController.stop();
    _isDragging = true;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    final newDy = _dragOffset.dy + details.delta.dy;
    if (newDy < 0 && !_isDragging) return;

    setState(() {
      final effectiveDy = math.max(0.0, newDy);
      final effectiveDx = _dragOffset.dx + (details.delta.dx * 0.35);
      _dragOffset = Offset(effectiveDx, effectiveDy);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0.0;
    final isFastFlick = velocity > 650;
    final isPastThreshold = _dragOffset.dy > 110;

    if (isFastFlick || isPastThreshold) {
      HapticFeedback.lightImpact();
      final screenHeight = MediaQuery.of(context).size.height;
      final targetDy = screenHeight + 50.0;

      _dismissOffsetAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset(_dragOffset.dx * 1.2, targetDy),
      ).animate(CurvedAnimation(
        parent: _dismissAnimController,
        curve: Curves.easeOutCubic,
      ));

      _dismissOpacityAnimation = Tween<double>(
        begin: _calculateBackgroundOpacity(),
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _dismissAnimController,
        curve: Curves.easeOut,
      ));

      _dismissAnimController.forward(from: 0.0);
    } else {
      _snapBackOffsetAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _snapBackAnimController,
        curve: Curves.easeOutBack,
      ));

      _snapBackAnimController.forward(from: 0.0);
    }
  }

  double _calculateProgress() {
    return (_dragOffset.dy / 280.0).clamp(0.0, 1.0);
  }

  double _calculateScale() {
    final progress = _calculateProgress();
    return (1.0 - (progress * 0.28)).clamp(0.68, 1.0);
  }

  double _calculateBackgroundOpacity() {
    if (_dismissAnimController.isAnimating && _dismissOpacityAnimation != null) {
      return _dismissOpacityAnimation!.value;
    }
    final progress = _calculateProgress();
    return (1.0 - progress).clamp(0.0, 1.0);
  }

  double _calculateOverlayOpacity() {
    final progress = _calculateProgress();
    return (1.0 - (progress * 2.8)).clamp(0.0, 1.0);
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
    final bgOpacity = _calculateBackgroundOpacity();
    final scale = _calculateScale();
    final overlayOpacity = _calculateOverlayOpacity();
    final progress = _calculateProgress();
    final borderRadius = BorderRadius.circular(progress * 22.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 0. DİNAMİK ŞEFFAFLAŞAN SİYAH ARKA PLAN
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.96 * bgOpacity),
            ),
          ),

          // 1. MAIN PAGEVIEW WITH ZOOMABLE HIGH-RES IMAGES & DISMISS DRAG
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragStart: _onVerticalDragStart,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              child: Transform.translate(
                offset: _dragOffset,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: borderRadius,
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
                        // Observability: Katalog sayfa çevirme telemetrisi
                        AnalyticsService.instance.logCatalogView(
                          storeName: widget.catalog.magazaKodu,
                          catalogId: widget.catalog.katalogId,
                          pageNumber: index + 1,
                        );
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
                ),
              ),
            ),
          ),

          // 2. FROSTED GLASS TOP OVERLAY BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: overlayOpacity,
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
          ),

          // 3. FROSTED GLASS BOTTOM PAGE INDICATOR
          if (pageCount > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: overlayOpacity,
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
                                width: _currentPage == index ? 18 : 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _currentPage == index
                                      ? const Color(0xFFFF6B35)
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
            ),
        ],
      ),
    );
  }
}
