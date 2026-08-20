import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Ortak Shimmer Kutu Bileşeni
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;
  final BoxShape boxShape;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape,
    this.boxShape = BoxShape.rectangle,
    this.margin,
  });

  const ShimmerBox.circular({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = null,
        boxShape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF3F3F46) : const Color(0xFFF8FAFC);

    Widget box = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
        shape: boxShape,
        borderRadius: boxShape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
      ),
    );

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: box,
    );
  }
}
