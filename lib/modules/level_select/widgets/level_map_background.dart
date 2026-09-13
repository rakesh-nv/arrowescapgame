import 'dart:math' as math;
import 'package:flutter/material.dart';

class LevelMapBackground extends StatelessWidget {
  final double totalHeight;
  final double screenWidth;

  const LevelMapBackground({
    super.key,
    required this.totalHeight,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: screenWidth,
      height: totalHeight,
      child: Stack(
        children: [
          // 1. Biome Sky Gradient
          Container(
            width: screenWidth,
            height: totalHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xFFF5F7FF), // World 1: Fresh Meadow / Sky
                  Color(0xFFEFF6FF), // World 2: Ocean Breeze
                  Color(0xFFFAF5FF), // World 3: Sunset Dusk
                  Color(0xFFF1F5F9), // World 4: Celestial Realm
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),

          // 2. Custom Painted Floating Elements (Clouds, Sparkles, Decorative Arrows)
          CustomPaint(
            size: Size(screenWidth, totalHeight),
            painter: _BackgroundElementsPainter(totalHeight: totalHeight),
          ),
        ],
      ),
    );
  }
}

class _BackgroundElementsPainter extends CustomPainter {
  final double totalHeight;

  _BackgroundElementsPainter({required this.totalHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42); // Deterministic seed for consistent layout

    final cloudPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final particlePaint = Paint()
      ..color = const Color(0xFF94A3B8).withOpacity(0.25)
      ..style = PaintingStyle.fill;

    // Draw decorative clouds and floating sparkles along the vertical height
    for (double y = 150; y < totalHeight - 100; y += 220) {
      final x = (rand.nextDouble() * 0.8 + 0.1) * size.width;
      final scale = 0.7 + rand.nextDouble() * 0.6;

      // Draw soft cloud
      final cloudPath = Path();
      cloudPath.addOval(Rect.fromLTWH(x, y, 60 * scale, 30 * scale));
      cloudPath.addOval(Rect.fromLTWH(x + 20 * scale, y - 12 * scale, 40 * scale, 35 * scale));
      cloudPath.addOval(Rect.fromLTWH(x + 40 * scale, y + 4 * scale, 35 * scale, 24 * scale));
      canvas.drawPath(cloudPath, cloudPaint);

      // Draw small decorative floating star/sparkle
      final px = (rand.nextDouble() * 0.85 + 0.08) * size.width;
      final py = y + (rand.nextDouble() * 120 - 60);
      canvas.drawCircle(Offset(px, py), 2.5 * scale, particlePaint);

      // Draw subtle decorative mini-arrow outline in background
      if (rand.nextBool()) {
        final arrowPaint = Paint()
          ..color = const Color(0xFF64748B).withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        final ax = (rand.nextDouble() * 0.7 + 0.15) * size.width;
        final ay = y + 80;
        final arrowPath = Path()
          ..moveTo(ax, ay)
          ..lineTo(ax + 12, ay - 6)
          ..lineTo(ax + 12, ay + 6)
          ..close();
        canvas.drawPath(arrowPath, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundElementsPainter oldDelegate) => false;
}
