import 'dart:math';

import 'package:flutter/material.dart';

/// A procedurally-painted corkboard texture + wood frame, so the board
/// isn't just a flat rectangle. There are no bundled image assets to
/// texture it with, so this is all gradients + deterministic speckles.
class CorkboardBackground extends StatelessWidget {
  final double width;
  final double height;
  const CorkboardBackground({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary caches this as its own layer, so panning/zooming the
    // board (InteractiveViewer) never re-runs the speckle painting below.
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: _CorkboardPainter(),
      ),
    );
  }
}

class _CorkboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final base = Paint()
      ..shader = const RadialGradient(
        radius: 0.9,
        colors: [Color(0xFFD8A863), Color(0xFFB07C3E)],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    // Cork speckles on a fixed seed so the texture is identical every time
    // it's (re)computed — it's decoration, not something that needs to
    // vary.
    final rand = Random(7);
    final speckle = Paint()..style = PaintingStyle.fill;
    const step = 42.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final dx = x + rand.nextDouble() * step;
        final dy = y + rand.nextDouble() * step;
        final radius = 1.2 + rand.nextDouble() * 2.2;
        speckle.color =
            (rand.nextBool()
                    ? const Color(0xFF7A5024)
                    : const Color(0xFFEFC489))
                .withValues(alpha: 0.18 + rand.nextDouble() * 0.14);
        canvas.drawCircle(Offset(dx, dy), radius, speckle);
      }
    }

    const frameWidth = 46.0;
    final framePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8A5A2B), Color(0xFF5E3A1A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = frameWidth;
    canvas.drawRect(rect.deflate(frameWidth / 2), framePaint);

    final innerBevel = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect.deflate(frameWidth), innerBevel);
  }

  @override
  bool shouldRepaint(covariant _CorkboardPainter oldDelegate) => false;
}
