import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/map_biome.dart';

/// Light ambient motion for one map item: drifting clouds plus the region's
/// particles (fireflies, snow, embers…).
///
/// Driven by the screen's single looping [animation] (0→1). Every motion is
/// periodic in that value so the loop is seamless. Only this layer repaints
/// per frame; the scenery below stays cached.
class MapAmbientPainter extends CustomPainter {
  final Animation<double> animation;
  final MapBiome biome;
  final int seed;

  MapAmbientPainter({
    required this.animation,
    required this.biome,
    required this.seed,
  }) : super(repaint: animation);

  /// About one particle per this many pixels of map height.
  static const double particleSpacing = 85;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final rand = math.Random(seed);
    final count = (size.height / particleSpacing).ceil();
    final paint = Paint();
    const tau = math.pi * 2;

    if (biome.clouds) {
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.55);
      final shadow = Paint()..color = Colors.black.withValues(alpha: 0.05);
      for (var y = 120.0; y < size.height; y += 520) {
        final phase = rand.nextDouble();
        final speed = 1 + rand.nextInt(2);
        final span = size.width + 260;
        final x = ((t * speed + phase) % 1) * span - 130;
        final s = 0.8 + rand.nextDouble() * 0.5;
        final cy = y + rand.nextDouble() * 200;
        _cloud(canvas, Offset(x, cy + 26), s, shadow);
        _cloud(canvas, Offset(x, cy), s, cloud);
      }
    }

    if (biome.particle == ParticleKind.aurora) {
      // Slow ribbons of light drifting across the sky.
      for (var y = 160.0; y < size.height; y += 640) {
        for (var k = 0; k < 2; k++) {
          final path = Path();
          final phase = rand.nextDouble();
          for (var x = -20.0; x <= size.width + 20; x += 12) {
            final yy =
                y +
                k * 34 +
                math.sin(x * 0.012 + tau * (t + phase)) * 26 +
                math.sin(x * 0.03 + tau * 2 * t) * 8;
            if (x <= -20) {
              path.moveTo(x, yy);
            } else {
              path.lineTo(x, yy);
            }
          }
          paint
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 22
            ..color = (k == 0 ? biome.decorB : biome.decorC).withValues(
              alpha: 0.10 + 0.06 * math.sin(tau * (t + phase)),
            );
          canvas.drawPath(path, paint);
          paint
            ..strokeWidth = 6
            ..color = biome.particleColor.withValues(alpha: 0.22);
          canvas.drawPath(path, paint);
        }
      }
      paint.style = PaintingStyle.fill;
    }

    for (var i = 0; i < count; i++) {
      final bx = rand.nextDouble() * size.width;
      final by = rand.nextDouble() * size.height;
      final phase = rand.nextDouble();
      final speed = 1 + rand.nextInt(3);
      final size0 = 1.5 + rand.nextDouble() * 2;
      // Integer multiples of t keep every motion periodic in the loop.
      final local = (t * speed * 4 + phase) % 1;
      final wave = math.sin(tau * (t * speed * 3 + phase));
      final wave2 = math.cos(tau * (t * speed * 2 + phase));
      Offset p;
      double a;
      switch (biome.particle) {
        case ParticleKind.fireflies:
        case ParticleKind.glints:
          p = Offset(bx + wave * 16, by + wave2 * 10);
          a =
              0.35 +
              0.65 * (0.5 + 0.5 * math.sin(tau * (t * speed * 6 + phase)));
        case ParticleKind.dust:
          p = Offset(bx + local * 120 - 60, by + wave * 6);
          a = math.sin(math.pi * local) * 0.7;
        case ParticleKind.snow:
          p = Offset(bx + wave * 12, by + local * 160 - 80);
          a = math.sin(math.pi * local) * 0.9;
        case ParticleKind.bubbles:
        case ParticleKind.embers:
          p = Offset(bx + wave * 8, by - local * 140 + 70);
          a = math.sin(math.pi * local) * 0.85;
        case ParticleKind.neon:
        case ParticleKind.stars:
        case ParticleKind.aurora:
          p = Offset(bx, by);
          a = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(tau * (t * speed * 5 + phase)));
        case ParticleKind.rain:
          p = Offset(bx - local * 40, by + local * 220 - 110);
          a = math.sin(math.pi * local) * 0.6;
        case ParticleKind.lanterns:
          p = Offset(bx + wave * 10, by - local * 180 + 90);
          a = math.sin(math.pi * local) * 0.9;
        case ParticleKind.petals:
        case ParticleKind.leaves:
          p = Offset(bx + wave * 22 + local * 40, by + local * 150 - 75);
          a = math.sin(math.pi * local) * 0.9;
        case ParticleKind.comets:
          final cl = (t * speed + phase) % 1;
          p = Offset(bx + cl * 260 - 130, by + cl * 130 - 65);
          a = math.sin(math.pi * cl) * 0.9;
        case ParticleKind.wind:
          p = Offset(bx + local * 200 - 100, by + wave * 8);
          a = math.sin(math.pi * local) * 0.55;
      }
      switch (biome.particle) {
        case ParticleKind.rain:
          paint
            ..color = biome.particleColor.withValues(alpha: a)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(p, p.translate(-4, 14), paint);
          continue;
        case ParticleKind.lanterns:
          paint.color = biome.particleColor.withValues(alpha: a * 0.3);
          canvas.drawCircle(p, size0 * 5, paint);
          paint.color = biome.particleColor.withValues(alpha: a);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: p,
                width: size0 * 2.6,
                height: size0 * 3.4,
              ),
              Radius.circular(size0),
            ),
            paint,
          );
          continue;
        case ParticleKind.petals:
        case ParticleKind.leaves:
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(tau * (t * speed * 2 + phase));
          paint.color =
              (biome.particle == ParticleKind.leaves && i.isOdd
                      ? biome.decorB
                      : biome.particleColor)
                  .withValues(alpha: a);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: size0 * 3.2,
              height: size0 * 1.6,
            ),
            paint,
          );
          canvas.restore();
          continue;
        case ParticleKind.comets:
          if (i % 3 != 0) {
            paint.color = biome.particleColor.withValues(
              alpha: 0.2 + 0.6 * (0.5 + 0.5 * wave),
            );
            canvas.drawCircle(Offset(bx, by), size0 * 0.6, paint);
            continue;
          }
          paint
            ..shader = null
            ..color = biome.decorA.withValues(alpha: a * 0.5)
            ..strokeWidth = size0 * 1.4
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(p, p.translate(-36, -18), paint);
          paint.color = biome.particleColor.withValues(alpha: a);
          canvas.drawCircle(p, size0 * 1.3, paint);
          continue;
        case ParticleKind.wind:
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = biome.particleColor.withValues(alpha: a);
          canvas.drawArc(
            Rect.fromCenter(center: p, width: 46, height: 14),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            paint,
          );
          paint.style = PaintingStyle.fill;
          continue;
        default:
          break;
      }
      final color = biome.particle == ParticleKind.neon
          ? [biome.decorA, biome.decorB, biome.decorC][i % 3]
          : biome.particleColor;
      if (biome.particle == ParticleKind.fireflies ||
          biome.particle == ParticleKind.glints ||
          biome.particle == ParticleKind.embers ||
          biome.particle == ParticleKind.neon) {
        // Cheap halo instead of a blur.
        paint.color = color.withValues(alpha: a * 0.25);
        canvas.drawCircle(p, size0 * 3, paint);
      }
      if (biome.particle == ParticleKind.bubbles) {
        paint
          ..color = color.withValues(alpha: a * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(p, size0 * 1.6, paint);
        paint.style = PaintingStyle.fill;
        continue;
      }
      paint.color = color.withValues(alpha: a);
      canvas.drawCircle(p, size0, paint);
    }
  }

  void _cloud(Canvas canvas, Offset o, double s, Paint p) {
    canvas.drawOval(Rect.fromLTWH(o.dx, o.dy, 64 * s, 26 * s), p);
    canvas.drawOval(
      Rect.fromLTWH(o.dx + 14 * s, o.dy - 14 * s, 38 * s, 32 * s),
      p,
    );
    canvas.drawOval(
      Rect.fromLTWH(o.dx + 36 * s, o.dy - 6 * s, 34 * s, 26 * s),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant MapAmbientPainter old) =>
      old.biome != biome || old.seed != seed || old.animation != animation;
}
