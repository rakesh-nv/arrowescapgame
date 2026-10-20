import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Small toolkit of shaded solids for the level map. Everything is lit from
/// the top left, so scenery drawn with it reads as one soft "clay diorama"
/// world: rounded volumes, lit and shaded faces, and soft contact shadows
/// instead of flat shapes.
///
/// All helpers are cheap (gradients, no blurs), because the map paints each
/// world once and keeps it in a cached layer.
class Map3D {
  Map3D._();

  static Color shade(Color c, double t) => Color.lerp(c, Colors.black, t)!;
  static Color tint(Color c, double t) => Color.lerp(c, Colors.white, t)!;
  static Color alpha(Color c, double a) => c.withValues(alpha: a);

  /// Soft, feathered shadow where an object meets the ground.
  static void shadow(
    Canvas canvas,
    Offset center,
    double width, {
    double opacity = 0.22,
    double squash = 0.32,
  }) {
    final r = width / 2;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, squash);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          [
            Colors.black.withValues(alpha: opacity),
            Colors.black.withValues(alpha: 0),
          ],
          [0.35, 1],
        ),
    );
    canvas.restore();
  }

  /// Ball lit from the top left (tree crowns, bushes, lanterns, planets).
  static void sphere(
    Canvas canvas,
    Offset c,
    double r,
    Color base, {
    double gloss = 0.5,
  }) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-r * 0.38, -r * 0.42),
          r * 1.45,
          [tint(base, 0.42), base, shade(base, 0.38)],
          [0, 0.45, 1],
        ),
    );
    if (gloss > 0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(-r * 0.36, -r * 0.46),
          width: r * 0.7,
          height: r * 0.42,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.22 * gloss),
      );
    }
  }

  /// Upright cylinder standing on [base] (trunks, towers, columns, posts).
  static void cylinder(
    Canvas canvas,
    Offset base,
    double width,
    double height,
    Color color, {
    Color? top,
  }) {
    final hw = width / 2;
    final ry = width * 0.16;
    final body = Rect.fromLTRB(
      base.dx - hw,
      base.dy - height,
      base.dx + hw,
      base.dy,
    );
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        body.centerLeft,
        body.centerRight,
        [shade(color, 0.1), tint(color, 0.28), color, shade(color, 0.42)],
        [0, 0.3, 0.6, 1],
      );
    canvas.drawRect(body, paint);
    canvas.drawOval(
      Rect.fromCenter(center: base, width: width, height: ry * 2),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -height),
        width: width,
        height: ry * 2,
      ),
      Paint()..color = top ?? tint(color, 0.32),
    );
  }

  /// Box seen in three-quarter view: front face, lit top and shaded right
  /// side. [depth] is how far the box recedes.
  static void block(
    Canvas canvas,
    Rect front,
    double depth,
    Color color, {
    double radius = 0,
    Color? topColor,
  }) {
    final dx = depth * 0.45, dy = depth * 0.55;
    final top = Path()
      ..moveTo(front.left, front.top)
      ..lineTo(front.left + dx, front.top - dy)
      ..lineTo(front.right + dx, front.top - dy)
      ..lineTo(front.right, front.top)
      ..close();
    final side = Path()
      ..moveTo(front.right, front.top)
      ..lineTo(front.right + dx, front.top - dy)
      ..lineTo(front.right + dx, front.bottom - dy)
      ..lineTo(front.right, front.bottom)
      ..close();
    canvas.drawPath(side, Paint()..color = shade(color, 0.32));
    canvas.drawPath(top, Paint()..color = topColor ?? tint(color, 0.3));
    final frontPaint = Paint()
      ..shader = ui.Gradient.linear(front.topCenter, front.bottomCenter, [
        tint(color, 0.06),
        shade(color, 0.14),
      ]);
    if (radius > 0) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          front,
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        ),
        frontPaint,
      );
    } else {
      canvas.drawRect(front, frontPaint);
    }
  }

  /// Rounded, pillowy block (hedges, clouds, cushions of terrain).
  static void roundedBlock(
    Canvas canvas,
    Rect front,
    double depth,
    Color color,
  ) {
    final dy = depth * 0.55;
    final r = Radius.circular(math.min(front.height, front.width) * 0.3);
    final topRect = Rect.fromLTRB(
      front.left,
      front.top - dy,
      front.right,
      front.top + dy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          front.left,
          front.top - dy * 0.5,
          front.right,
          front.bottom,
        ),
        r,
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(front.left, front.top),
          Offset(front.left, front.bottom),
          [color, shade(color, 0.3)],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(topRect, r),
      Paint()
        ..shader = ui.Gradient.linear(topRect.topLeft, topRect.bottomRight, [
          tint(color, 0.38),
          tint(color, 0.1),
        ]),
    );
  }

  /// Cone or pyramid standing on [base]: a lit left face and a shaded right
  /// face.
  static void cone(
    Canvas canvas,
    Offset base,
    double halfWidth,
    double height,
    Color color, {
    double ridge = 0.18,
  }) {
    final apex = base.translate(0, -height);
    final mid = base.translate(halfWidth * ridge, 0);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - halfWidth, base.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(mid.dx, mid.dy)
        ..close(),
      Paint()..color = tint(color, 0.12),
    );
    canvas.drawPath(
      Path()
        ..moveTo(mid.dx, mid.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(base.dx + halfWidth, base.dy)
        ..close(),
      Paint()..color = shade(color, 0.28),
    );
  }

  /// Half-sphere dome sitting on [base] (stupas, igloos, observatories).
  static void dome(Canvas canvas, Offset base, double r, Color color) {
    final rect = Rect.fromCircle(center: base, radius: r);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      true,
      Paint()
        ..shader = ui.Gradient.radial(
          base.translate(-r * 0.35, -r * 0.6),
          r * 1.4,
          [tint(color, 0.45), color, shade(color, 0.35)],
          [0, 0.5, 1],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: base, width: r * 2, height: r * 0.3),
      Paint()..color = shade(color, 0.25),
    );
  }

  /// Faceted gem / shard: two lit faces and one shaded face.
  static void shard(
    Canvas canvas,
    Offset base,
    double halfWidth,
    double height,
    Color color, {
    double lean = 0,
  }) {
    final apex = base.translate(lean, -height);
    final shoulderL = base.translate(-halfWidth, -height * 0.62);
    final shoulderR = base.translate(halfWidth, -height * 0.62);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - halfWidth * 0.7, base.dy)
        ..lineTo(shoulderL.dx, shoulderL.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(base.dx, base.dy)
        ..close(),
      Paint()..color = tint(color, 0.3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(shoulderR.dx, shoulderR.dy)
        ..lineTo(base.dx + halfWidth * 0.7, base.dy)
        ..close(),
      Paint()..color = shade(color, 0.22),
    );
    canvas.drawLine(
      base,
      apex,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = math.max(1, halfWidth * 0.12),
    );
  }

  /// Glow halo (lamps, crystals, magic).
  static void glow(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    double strength = 0.45,
  }) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c, r, [
          color.withValues(alpha: strength),
          color.withValues(alpha: 0),
        ]),
    );
  }

  /// Rounded hill or dune with a vertical gradient and a lit rim.
  static void hill(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Color color,
  ) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [tint(color, 0.22), color, shade(color, 0.25)],
          [0, 0.45, 1],
        ),
    );
    canvas.drawArc(
      rect.deflate(width * 0.04),
      math.pi * 1.12,
      math.pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(2, height * 0.05)
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }
}
