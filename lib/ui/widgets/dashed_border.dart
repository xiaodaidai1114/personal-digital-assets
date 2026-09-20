import 'dart:math' as math;

import 'package:flutter/material.dart';

class DashedBorder extends CustomPainter {
  const DashedBorder({required this.color, this.radius = 8});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    final rectangle = Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1);
    final path = Path()
      ..moveTo(rectangle.left + radius, rectangle.top)
      ..lineTo(rectangle.right - radius, rectangle.top)
      ..quadraticBezierTo(
        rectangle.right,
        rectangle.top,
        rectangle.right,
        rectangle.top + radius,
      )
      ..lineTo(rectangle.right, rectangle.bottom - radius)
      ..quadraticBezierTo(
        rectangle.right,
        rectangle.bottom,
        rectangle.right - radius,
        rectangle.bottom,
      )
      ..lineTo(rectangle.left + radius, rectangle.bottom)
      ..quadraticBezierTo(
        rectangle.left,
        rectangle.bottom,
        rectangle.left,
        rectangle.bottom - radius,
      )
      ..lineTo(rectangle.left, rectangle.top + radius)
      ..quadraticBezierTo(
        rectangle.left,
        rectangle.top,
        rectangle.left + radius,
        rectangle.top,
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorder oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
