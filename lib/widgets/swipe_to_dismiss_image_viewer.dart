import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Modern mobil standartlarında (Instagram, iOS Photos, Twitter/X)
/// parmakla aşağı kaydırıldıkça küçülerek, arka planı şeffaflaştırarak ve
/// alttaki sayfayı görünür kılarak pürüzsüzce kapanan tam ekran görsel görüntüleyici.
class SwipeToDismissImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const SwipeToDismissImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  /// Şeffaf rota (PageRouteBuilder) ile tam ekran açılış metodu
  static void show(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
  }) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, anim, secondaryAnim) => SwipeToDismissImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<SwipeToDismissImageViewer> createState() => _SwipeToDismissImageViewerState();
}

class _SwipeToDismissImageViewerState extends State<SwipeToDismissImageViewer>
    with TickerProviderStateMixin {
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
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleZoomChange);

    // Çift tıklama yakınlaştırma animasyonu
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });

    // Bırakıldığında eski yerine yaylanarak dönme animasyonu
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

    // Kapatma eşiği geçildiğinde ekran dışına süzülme animasyonu
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

  void _handleDoubleTap(TapDownDetails details) {
    HapticFeedback.lightImpact();
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final Matrix4 targetMatrix;

    if (currentScale > 1.02) {
      // Zoom out: Orijinal boyuta dön
      targetMatrix = Matrix4.identity();
    } else {
      // Zoom in: Dokunulan noktaya 2.5x odaklan
      const double scale = 2.5;
      final position = details.localPosition;
      final double x = -position.dx * (scale - 1);
      final double y = -position.dy * (scale - 1);
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

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    _snapBackAnimController.stop();
    _isDragging = true;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;

    // Yalnızca aşağı doğru veya aktif sürükleme varsa ilerlet
    final newDy = _dragOffset.dy + details.delta.dy;
    if (newDy < 0 && !_isDragging) return;

    setState(() {
      // dy doğrudan parmağı takip eder, dx hafif bir eğim sağlar
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
      // 🚀 Kapatma işlemi: Ekrandan aşağı doğru akıcı şekilde süzülür
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
      // 🔄 Geri yaylanma: Orijinal merkez konumuna yumuşakça döner
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
    // Aşağı çekildikçe 1.0'dan 0.72'ye kadar kademeli küçülür
    return (1.0 - (progress * 0.28)).clamp(0.68, 1.0);
  }

  double _calculateBackgroundOpacity() {
    if (_dismissAnimController.isAnimating && _dismissOpacityAnimation != null) {
      return _dismissOpacityAnimation!.value;
    }
    final progress = _calculateProgress();
    // Aşağı çekildikçe arka plan opaklığı 1.0'dan 0.0'a iner
    return (1.0 - progress).clamp(0.0, 1.0);
  }

  double _calculateOverlayOpacity() {
    final progress = _calculateProgress();
    // Kapat butonu vb. kaydırma başladığında hızla solar
    return (1.0 - (progress * 2.8)).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleZoomChange);
    _transformationController.dispose();
    _zoomAnimController.dispose();
    _snapBackAnimController.dispose();
    _dismissAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = _calculateBackgroundOpacity();
    final scale = _calculateScale();
    final overlayOpacity = _calculateOverlayOpacity();
    final progress = _calculateProgress();
    final borderRadius = BorderRadius.circular(progress * 22.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. DİNAMİK ŞEFFAFLAŞAN ARKA PLAN
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_dragOffset == Offset.zero && !_isZoomed) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.94 * bgOpacity),
              ),
            ),
          ),

          // 2. PARMAKLA AŞAĞI KAYDIRILAN VE KÜÇÜLEN GÖRSEL KATMANI
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
                  child: Center(
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        transformationController: _transformationController,
                        panEnabled: _isZoomed,
                        scaleEnabled: true,
                        child: GestureDetector(
                          onDoubleTapDown: _handleDoubleTap,
                          onDoubleTap: () {}, // onDoubleTapDown'ın çalışması için gereklidir
                          child: widget.heroTag != null
                              ? Hero(
                                  tag: widget.heroTag!,
                                  child: _buildImage(),
                                )
                              : _buildImage(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. ÜST SAĞ KAPATMA ÇARPI BUTONU
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Opacity(
              opacity: overlayOpacity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
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

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: Color(0xFFFF6B35),
            strokeWidth: 2.8,
          ),
        ),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_rounded,
              color: Colors.white60,
              size: 58,
            ),
            SizedBox(height: 10),
            Text(
              'Görsel yüklenemedi',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
