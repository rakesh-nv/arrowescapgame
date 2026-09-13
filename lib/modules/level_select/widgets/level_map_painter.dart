import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../level_select_controller.dart';

class LevelMapPainter extends CustomPainter {
  final LevelSelectController controller;
  final int totalLevels;
  final int highestUnlocked;
  final double totalHeight;
  final double rowHeight;
  final double paddingBottom;
  final double animatedProgress;

  LevelMapPainter({
    required this.controller,
    required this.totalLevels,
    required this.highestUnlocked,
    required this.totalHeight,
    required this.rowHeight,
    required this.paddingBottom,
    this.animatedProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalLevels < 2) return;

    final unlockedPath = Path();
    final lockedPath = Path();

    bool hasUnlocked = false;
    bool hasLocked = false;

    Offset? prevPoint;

    for (int lvl = 1; lvl <= totalLevels; lvl++) {
      final x = controller.getNodeX(lvl, size.width);
      final y = controller.getNodeY(lvl, totalHeight, rowHeight, paddingBottom);
      final currentPoint = Offset(x, y);

      if (prevPoint != null) {
        final midY = (prevPoint.dy + currentPoint.dy) / 2;
        final control1 = Offset(prevPoint.dx, midY);
        final control2 = Offset(currentPoint.dx, midY);

        if (lvl <= highestUnlocked) {
          if (!hasUnlocked) {
            unlockedPath.moveTo(prevPoint.dx, prevPoint.dy);
            hasUnlocked = true;
          }
          unlockedPath.cubicTo(
            control1.dx,
            control1.dy,
            control2.dx,
            control2.dy,
            currentPoint.dx,
            currentPoint.dy,
          );
        } else {
          if (!hasLocked) {
            lockedPath.moveTo(prevPoint.dx, prevPoint.dy);
            hasLocked = true;
          }
          lockedPath.cubicTo(
            control1.dx,
            control1.dy,
            control2.dx,
            control2.dy,
            currentPoint.dx,
            currentPoint.dy,
          );
        }
      }

      prevPoint = currentPoint;
    }

    // 1. Draw Unlocked Path Glow
    if (hasUnlocked) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.accentBlue.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(unlockedPath, glowPaint);

      // 2. Draw Main Unlocked Path Gradient Line
      final pathPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, totalHeight),
          Offset(size.width / 2, 0),
          [
            AppColors.accentBlue,
            AppColors.accentPurple,
            AppColors.diffExpert,
          ],
          [0.0, 0.5, 1.0],
        );
      canvas.drawPath(unlockedPath, pathPaint);
    }

    // 3. Draw Locked Path (Dashed)
    if (hasLocked) {
      final lockedPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFCBD5E1);

      for (final pathMetric in lockedPath.computeMetrics()) {
        double distance = 0.0;
        const double dashWidth = 8.0;
        const double dashSpace = 6.0;

        while (distance < pathMetric.length) {
          final extractPath = pathMetric.extractPath(
            distance,
            (distance + dashWidth).clamp(0.0, pathMetric.length),
          );
          canvas.drawPath(extractPath, lockedPaint);
          distance += dashWidth + dashSpace;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LevelMapPainter oldDelegate) {
    return oldDelegate.highestUnlocked != highestUnlocked ||
        oldDelegate.animatedProgress != animatedProgress ||
        oldDelegate.totalHeight != totalHeight;
  }
}
