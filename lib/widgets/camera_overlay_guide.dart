import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Overlay guide that dims the camera preview except for the product/price regions.
class CameraOverlayGuide extends StatelessWidget {
  const CameraOverlayGuide({super.key, this.edgeMargin = 24});

  final double edgeMargin;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CameraOverlayGuidePainter(edgeMargin: edgeMargin),
      ),
    );
  }
}

class _CameraOverlayGuidePainter extends CustomPainter {
  _CameraOverlayGuidePainter({required this.edgeMargin});

  final double edgeMargin;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final horizontalMargin = math.min(edgeMargin, size.width * 0.12);
    final verticalMargin = math.min(edgeMargin * 1.4, size.height * 0.18);

    final guideRect = Rect.fromLTWH(
      horizontalMargin,
      verticalMargin,
      math.max(0, size.width - 2 * horizontalMargin),
      math.max(0, size.height - 2 * verticalMargin),
    );
    if (guideRect.width <= 0 || guideRect.height <= 0) {
      return;
    }

    final dimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectXY(guideRect, 16, 16));

    canvas.drawPath(
      dimPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );

    final splitY = guideRect.top + guideRect.height * 0.6;
    final productRect =
        Rect.fromLTRB(guideRect.left, guideRect.top, guideRect.right, splitY);
    final priceRect = Rect.fromLTRB(
        guideRect.left, splitY, guideRect.right, guideRect.bottom);

    final borderRadius = const Radius.circular(16);
    final topPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final bottomPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        productRect,
        topLeft: borderRadius,
        topRight: borderRadius,
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      ),
      topPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        priceRect,
        topLeft: Radius.zero,
        topRight: Radius.zero,
        bottomLeft: borderRadius,
        bottomRight: borderRadius,
      ),
      bottomPaint,
    );

    _paintLabel(canvas, productRect, '商品');
    _paintLabel(canvas, priceRect, '価格');
  }

  void _paintLabel(Canvas canvas, Rect rect, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);

    final offset = Offset(
      rect.center.dx - textPainter.width / 2,
      rect.center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CameraOverlayGuidePainter oldDelegate) {
    return oldDelegate.edgeMargin != edgeMargin;
  }
}
