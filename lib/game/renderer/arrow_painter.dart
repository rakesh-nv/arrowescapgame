import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../config/puzzle_config.dart';

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
      // Just over half the stroke width (0.20 cell): the inside edge of each
      // bend is barely rounded and the outside a little more, like the
      // reference art, without looking like a curve.
      final radius = (cellSize * 0.11)
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

  /// Arrowhead colour; [bodyColor] when null.
  final Color? headColor;
  final Color glowColor;
  final bool showGlow;
  final double opacity;

  /// Null while idle. During escape every point follows the point ahead of it
  /// through the bends, producing the reference snake/uncoiling motion.
  final double? snakeProgress;

  /// Exact snake shift in pixels (a crash run); overrides [snakeProgress].
  final double? snakeShift;

  final Offset shakeOffset;
  final ArrowMotionPath motionPath;

  const ArrowPainter({
    required this.arrow,
    required this.cellSize,
    required this.bodyColor,
    this.headColor,
    required this.glowColor,
    this.showGlow = false,
    this.opacity = 1.0,
    this.snakeProgress,
    this.snakeShift,
    this.shakeOffset = Offset.zero,
    required this.motionPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (arrow.points.isEmpty || arrow.state == ArrowState.removed) return;

    canvas.save();

    // Thin body and a proportionate head (shared with PuzzleConfig).
    final strokeWidth = PuzzleConfig.strokeWidthFor(cellSize);
    final headSize = PuzzleConfig.headSizeFor(cellSize);
    final progress = snakeProgress ?? 0.0;
    final shift =
        snakeShift ??
        (snakeProgress == null
            ? 0.0
            : (motionPath.length + cellSize * (arrow.length + 2)) * progress);
    final animated = motionPath.snakePoints(shift);
    final lastPt = animated.last + shakeOffset;
    final headDirection = motionPath.directionAt(shift + motionPath.length);
    // The tip sits a quarter cell past the head cell's centre.
    final tip = Offset(
      lastPt.dx + headDirection.dx * (cellSize * 0.25),
      lastPt.dy + headDirection.dy * (cellSize * 0.25),
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

    // No trail, drop shadow or blurred copy is drawn behind the arrow: only
    // the body and its head. The glow below is the hint / blocking-arrow
    // indicator and appears only while that cue is active.
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
      color: (headColor ?? bodyColor).withValues(alpha: opacity),
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

    final hs = headSize;
    // Symmetric, slightly narrower than long (width ≈ 0.96 × length).
    final halfWidth = hs * 0.48;

    final normal = Offset(-direction.dy, direction.dx);
    final base = tip - direction * hs;
    // Sharp tip; only the two back corners are faintly softened so they
    // don't alias into jagged points.
    final path = _roundedPolygon(
      [tip, base + normal * halfWidth, base - normal * halfWidth],
      [0.0, hs * 0.06, hs * 0.06],
    );
    canvas.drawPath(path, paint);
  }

  /// Closed polygon through [vertices] whose corners are cut back by
  /// [radii] along both edges and joined with a quadratic curve.
  static Path _roundedPolygon(List<Offset> vertices, List<double> radii) {
    final path = Path();
    final n = vertices.length;
    for (var i = 0; i < n; i++) {
      final corner = vertices[i];
      final toPrev = vertices[(i - 1 + n) % n] - corner;
      final toNext = vertices[(i + 1) % n] - corner;
      final r = radii[i]
          .clamp(0.0, toPrev.distance * 0.45)
          .clamp(0.0, toNext.distance * 0.45);
      final entry = corner + toPrev / toPrev.distance * r;
      final exit = corner + toNext / toNext.distance * r;
      if (i == 0) {
        path.moveTo(entry.dx, entry.dy);
      } else {
        path.lineTo(entry.dx, entry.dy);
      }
      path.quadraticBezierTo(corner.dx, corner.dy, exit.dx, exit.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.headColor != headColor ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.opacity != opacity ||
        oldDelegate.snakeProgress != snakeProgress ||
        oldDelegate.snakeShift != snakeShift ||
        oldDelegate.shakeOffset != shakeOffset ||
        oldDelegate.arrow.state != arrow.state ||
        oldDelegate.arrow.points != arrow.points;
  }
}
