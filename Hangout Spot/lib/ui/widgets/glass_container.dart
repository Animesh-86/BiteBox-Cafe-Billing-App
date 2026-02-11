import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final BoxBorder? border;
  final double? width;
  final double? height;
  final Gradient? borderGradient;
  final double borderWidth;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 12.0, // Increased blur for premium feel
    this.opacity = 0.65,
    this.color = Colors.white,
    this.gradient,
    this.borderGradient,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(20);

    // Default glass gradient for depth
    final effectiveGradient =
        gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.7), // Slight falloff
          ],
          stops: const [0.2, 1.0],
        );

    // Default border gradient (simulates light source from top-left)
    final effectiveBorderGradient =
        borderGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isDark ? 0.3 : 0.6),
            Colors.white.withOpacity(isDark ? 0.05 : 0.1),
            Colors.white.withOpacity(isDark ? 0.05 : 0.1),
            Colors.white.withOpacity(isDark ? 0.1 : 0.2),
          ],
          stops: const [0.0, 0.4, 0.6, 1.0],
        );

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF9E8A78).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: effectiveGradient,
              borderRadius: radius,
              // Use border if provided, otherwise paint a gradient border
              border:
                  border ??
                  (borderWidth > 0
                      ? Border.all(color: Colors.transparent, width: 0)
                      : null),
            ),
            child: CustomPaint(
              painter: _GradientBorderPainter(
                gradient: border != null ? null : effectiveBorderGradient,
                width: borderWidth,
                radius: radius,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final Gradient? gradient;
  final double width;
  final BorderRadius radius;

  _GradientBorderPainter({
    required this.gradient,
    required this.width,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gradient == null || width <= 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final RRect outer = radius.toRRect(rect);

    final Paint paint = Paint()
      ..shader = gradient!.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    // Use path to stroke specifically the border area
    // Simplified: just draw RRect with stroke
    canvas.drawRRect(outer, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.width != width ||
        oldDelegate.radius != radius;
  }
}
