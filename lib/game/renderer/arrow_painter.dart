import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';

/// Cached, rounded route used by an escaping arrow.  The route is built once
/// by [ArrowWidget], so every animation frame only samples a PathMetric.
class ArrowMotionPath {
  final List<Offset> _anchors;
  final Offset _exitDirection;
  final PathMetric? _metric;
  final double length;
  final double cellSize;

  const ArrowMotionPath._({
    required List<Offset> anchors,
    required Offset exitDirection,
    required PathMetric? metric,
    required this.length,
    required this.cellSize,
  }) : _anchors = anchors,
       _exitDirection = exitDirection,
       _metric = metric;

  factory ArrowMotionPath.build({
    required ArrowModel arrow,
    required double cellSize,
    Offset origin = Offset.zero,
  }) {
    final anchors = [
      for (final point in arrow.points)
        Offset(
          origin.dx + (point.$2 + 0.5) * cellSize,
          origin.dy + (point.$1 + 0.5) * cellSize,
        ),
    ];
    final exit = Offset(
      arrow.exitDirection.dCol.toDouble(),
      arrow.exitDirection.dRow.toDouble(),
    );
    if (anchors.length < 2) {
      return ArrowMotionPath._(
        anchors: anchors,
        exitDirection: exit,
        metric: null,
        length: 0,
        cellSize: cellSize,
      );
    }

    final path = Path()..moveTo(anchors.first.dx, anchors.first.dy);
    for (var index = 1; index < anchors.length - 1; index++) {
      final corner = anchors[index];
      final incoming = anchors[index - 1] - corner;
      final outgoing = anchors[index + 1] - corner;
      final radius = (cellSize * 0.10)
          .clamp(0.0, incoming.distance * 0.48)
          .clamp(0.0, outgoing.distance * 0.48);
      final inUnit = incoming / incoming.distance;
      final outUnit = outgoing / outgoing.distance;
      final entry = corner + inUnit * radius;
      final exitPoint = corner + outUnit * radius;

      // Standard cubic Bezier circular arc approximation (k = 0.55228475)
      // Tangents align continuously with the straight segments on both ends
      const k = 0.55228475;
      final cp1 = corner + inUnit * (radius * (1.0 - k));
      final cp2 = corner + outUnit * (radius * (1.0 - k));
      path
        ..lineTo(entry.dx, entry.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, exitPoint.dx, exitPoint.dy);
    }
    path.lineTo(anchors.last.dx, anchors.last.dy);
    final metric = path.computeMetrics().first;
    return ArrowMotionPath._(
      anchors: anchors,
      exitDirection: exit,
      metric: metric,
      length: metric.length,
      cellSize: cellSize,
    );
  }

  /// Samples dense points along the continuous path to eliminate any visible
  /// polygon edges/facets in the arrow curve while maintaining high frame rates.
  List<Offset> snakePoints(double shift) {
    if (_anchors.length < 2 || length == 0) {
      return [_anchors.first + _exitDirection * shift];
    }
    final sampleStep = (cellSize * 0.025).clamp(0.8, 2.0);
    final sampleCount = (length / sampleStep).ceil().clamp(36, 320);
    return [
      for (var index = 0; index <= sampleCount; index++)
        pointAt(length * index / sampleCount + shift),
    ];
  }

  Offset pointAt(double distance) {
    if (_anchors.length < 2 || _metric == null) {
      return _anchors.first + _exitDirection * distance;
    }
    if (distance >= length) {
      return _anchors.last + _exitDirection * (distance - length);
    }
    return _metric.getTangentForOffset(distance.clamp(0.0, length))!.position;
  }

  Offset directionAt(double distance) {
    if (_metric == null || distance >= length) return _exitDirection;
    final vector = _metric
        .getTangentForOffset(distance.clamp(0.0, length))!
        .vector;
    return vector / vector.distance;
  }
}

/// Custom painter that renders a single snake-shaped continuous arrow path.
///
/// Features:
/// - One continuous polyline with clean 90-degree corners.
/// - Rounded line caps and rounded corner joins.
/// - Exactly one terminal arrowhead at the final tip.
/// - Consistent stroke width throughout all segments.
/// - Minimalist 2D vector appearance.
class ArrowPainter extends CustomPainter {
  final ArrowModel arrow;
  final double cellSize;
  final Color bodyColor;
  final Color glowColor;
  final bool showGlow;
  final double opacity;

  /// Null while idle. During escape every point follows the point ahead of it
  /// through the bends, producing the reference snake/uncoiling motion.
  final double? snakeProgress;

  /// Same timeline as [snakeProgress]; separated to keep trail drawing optional.
  final double? trailProgress;
  final Offset shakeOffset;
  final ArrowMotionPath motionPath;

  const ArrowPainter({
    required this.arrow,
    required this.cellSize,
    required this.bodyColor,
    required this.glowColor,
    this.showGlow = false,
    this.opacity = 1.0,
    this.snakeProgress,
    this.trailProgress,
    this.shakeOffset = Offset.zero,
    required this.motionPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (arrow.points.isEmpty || arrow.state == ArrowState.removed) return;

    canvas.save();

    // Balanced, readable arrow stroke and arrowhead sizing.
    final strokeWidth = (cellSize * 0.13).clamp(3.5, 4.8);
    final headSize = (strokeWidth * 1.8).clamp(6.8, 8.5);
    final progress = snakeProgress ?? 0.0;
    final shift = snakeProgress == null
        ? 0.0
        : (motionPath.length + cellSize * (arrow.length + 2)) * progress;
    final animated = motionPath.snakePoints(shift);
    final lastPt = animated.last + shakeOffset;
    final headDirection = motionPath.directionAt(shift + motionPath.length);
    final tip = Offset(
      lastPt.dx + headDirection.dx * (cellSize * 0.38),
      lastPt.dy + headDirection.dy * (cellSize * 0.38),
    );

    // Build the continuous snake path from tail to head
    final path = Path();
    path.moveTo(
      animated[0].dx + shakeOffset.dx,
      animated[0].dy + shakeOffset.dy,
    );

    for (int i = 1; i < animated.length; i++) {
      path.lineTo(
        animated[i].dx + shakeOffset.dx,
        animated[i].dy + shakeOffset.dy,
      );
    }

    // Connect line directly to the base of the arrowhead
    final lineEnd = Offset(
      tip.dx - headDirection.dx * (headSize * 0.7),
      tip.dy - headDirection.dy * (headSize * 0.7),
    );
    path.lineTo(lineEnd.dx, lineEnd.dy);

    // A single soft stroke is enough to imply momentum without noisy particles.
    if (trailProgress != null && trailProgress! > 0.04) {
      final trailAmount = (trailProgress! * 0.72).clamp(0.0, 0.72);
      final tailDirection = motionPath.directionAt(shift);
      final tail =
          animated.first + shakeOffset - tailDirection * (cellSize * 1.25);
      final trail = Path()
        ..moveTo(tail.dx, tail.dy)
        ..lineTo(
          animated.first.dx + shakeOffset.dx,
          animated.first.dy + shakeOffset.dy,
        );
      final trailPaint = Paint()
        ..isAntiAlias = true
        ..color = bodyColor.withValues(alpha: (0.18 * (1 - trailAmount)))
        ..strokeWidth = strokeWidth * 0.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(trail, trailPaint);
    }

    // Optional hint/selection glow
    if (showGlow) {
      final glowPaint = Paint()
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.4 * opacity)
        ..strokeWidth = strokeWidth + 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, glowPaint);
    }

    // Draw the continuous snake body
    final bodyPaint = Paint()
      ..isAntiAlias = true
      ..color = bodyColor.withValues(alpha: opacity)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, bodyPaint);

    // One arrowhead stays attached to the leading material point.
    _drawArrowHead(
      canvas: canvas,
      tip: tip,
      direction: headDirection,
      headSize: headSize,
      color: bodyColor.withValues(alpha: opacity),
    );

    canvas.restore();
  }

  void _drawArrowHead({
    required Canvas canvas,
    required Offset tip,
    required Offset direction,
    required double headSize,
    required Color color,
  }) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final hs = headSize;
    final halfWidth = hs * 0.42;

    final normal = Offset(-direction.dy, direction.dx);
    final base = tip - direction * hs;
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(
      base.dx + normal.dx * halfWidth,
      base.dy + normal.dy * halfWidth,
    );
    path.lineTo(
      base.dx - normal.dx * halfWidth,
      base.dy - normal.dy * halfWidth,
    );

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.opacity != opacity ||
        oldDelegate.snakeProgress != snakeProgress ||
        oldDelegate.trailProgress != trailProgress ||
        oldDelegate.shakeOffset != shakeOffset ||
        oldDelegate.arrow.state != arrow.state ||
        oldDelegate.arrow.points != arrow.points;
  }
}
