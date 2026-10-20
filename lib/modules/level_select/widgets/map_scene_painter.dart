import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../map/level_map_layout.dart';
import '../map/map_3d.dart';
import '../map/map_biome.dart';
import '../map/map_scenery_extended.dart';

Color _shade(Color c, double t) => Color.lerp(c, Colors.black, t)!;
Color _tint(Color c, double t) => Color.lerp(c, Colors.white, t)!;
Color _alpha(Color c, double a) => c.withValues(alpha: a);

enum _DecorKind {
  roundTree,
  pine,
  snowPine,
  bush,
  flowers,
  rock,
  mushroom,
  glowMushroom,
  cactus,
  mound,
  palm,
  deadTree,
  lavaPool,
  lamp,
  building,
  neonSign,
  crystal,
  sparkle,
  planet,
  floatingRock,
}

class _Decor {
  final _DecorKind kind;

  /// Global position (x, height from the map bottom).
  final Offset pos;
  final double scale;
  final int variant;

  /// Decoration of an extended-campaign region (drawn by [ExtendedScenery]).
  final SceneDecor? ext;

  const _Decor(this.kind, this.pos, this.scale, this.variant, [this.ext]);
}

class _Landmark {
  final Offset pos;
  final double size;
  final int variant;
  final bool flip;

  const _Landmark(this.pos, this.size, this.variant, this.flip);
}

/// Static scenery for one list item of the level map: ground, edge terrain,
/// river and bridge, landmarks, the trail, gates and decorations.
///
/// Painted once per item and kept in its own layer; it repaints only when
/// the width or the unlocked level changes. Decoration placement is
/// deterministic and cached per item.
class MapScenePainter extends CustomPainter {
  final LevelMapLayout layout;
  final int itemIndex;
  final int highestUnlocked;

  MapScenePainter({
    required this.layout,
    required this.itemIndex,
    required this.highestUnlocked,
  });

  static final Map<String, List<_Decor>> _decorCache = {};
  static final Map<String, List<_Landmark>> _landmarkCache = {};

  bool get _isStart => itemIndex == 0;
  bool get _isSummit => itemIndex == layout.summitIndex;
  int get _sectionIndex => itemIndex - 1;

  MapBiome get _biome {
    if (_isStart) return MapBiome.forWorld(1);
    if (_isSummit) return MapBiome.forWorld(layout.sections.last.world.number);
    return MapBiome.forWorld(layout.sections[_sectionIndex].world.number);
  }

  MapBiome? get _previousBiome {
    if (_isStart || _sectionIndex == 0) return null;
    if (_isSummit) return null;
    return MapBiome.forWorld(layout.sections[_sectionIndex - 1].world.number);
  }

  String get _cacheKey =>
      '$itemIndex|${layout.width.round()}|${layout.totalLevels}';

  double? get _riverY {
    if (_isStart || _isSummit) return null;
    final s = layout.sections[_sectionIndex];
    if (s.levelCount < 4) return null;
    return s.bottom +
        LevelMapLayout.gateHeight +
        (s.levelCount ~/ 2) * LevelMapLayout.rowHeight;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = layout.itemBottom(itemIndex);
    final top = bottom + size.height;
    Offset local(Offset g) => Offset(g.dx, top - g.dy);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final biome = _biome;
    _paintGround(canvas, size, biome);
    _paintEdgeTerrain(canvas, size, biome, bottom, top);

    final riverY = _riverY;
    if (riverY != null) _paintRiver(canvas, size, biome, top - riverY);

    for (final l in _landmarks(bottom, top)) {
      _paintLandmark(canvas, biome, local(l.pos), l);
    }

    _paintTrail(canvas, biome, local);

    if (riverY != null) {
      _paintBridge(
        canvas,
        biome,
        local(Offset(layout.trailXAt(riverY - 34), riverY - 34)),
        local(Offset(layout.trailXAt(riverY + 34), riverY + 34)),
      );
    }

    if (_isStart) {
      _paintCamp(canvas, biome, local(layout.point(0)));
    } else if (_isSummit) {
      _paintSummit(canvas, biome, local(layout.point(layout.totalLevels + 1)));
    } else {
      final y = layout.gateArchY(_sectionIndex);
      _paintGate(
        canvas,
        biome,
        local(Offset(layout.trailXAt(y), y)),
        open: layout.sections[_sectionIndex].firstLevel <= highestUnlocked,
      );
    }

    for (final d in _decorations(bottom, top)) {
      _paintDecor(canvas, biome, local(d.pos), d);
    }

    canvas.restore();
  }

  // ── Ground ────────────────────────────────────────────────────────────

  void _paintGround(Canvas canvas, Size size, MapBiome biome) {
    final prev = _previousBiome;
    final h = size.height;
    final List<Color> colors;
    final List<double> stops;
    if (prev != null) {
      final g = (LevelMapLayout.gateHeight / h).clamp(0.0, 1.0);
      colors = [prev.groundTop, biome.groundBottom, biome.groundTop];
      stops = [0, g, 1];
    } else if (_isSummit) {
      colors = [biome.groundTop, _shade(biome.groundTop, 0.25)];
      stops = [0, 1];
    } else {
      colors = [biome.groundBottom, biome.groundTop];
      stops = [0, 1];
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h), Offset.zero, colors, stops),
    );

    // Depth: sunlight from the top left, and the map edges falling away.
    final w = size.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, 0),
          [
            _alpha(Colors.white, biome.dark ? 0.04 : 0.12),
            _alpha(Colors.white, 0),
            _alpha(Colors.black, 0),
            _alpha(Colors.black, biome.dark ? 0.22 : 0.10),
          ],
          [0, 0.35, 0.7, 1],
        ),
    );

    // Soft ground patches break up the flat colour.
    final rand = math.Random(itemIndex * 977 + 5);
    final patch = Paint();
    for (var y = 60.0; y < h; y += 170) {
      final x = rand.nextDouble() * size.width;
      final r = 50 + rand.nextDouble() * 70;
      patch.color = rand.nextBool()
          ? _alpha(Colors.white, biome.dark ? 0.03 : 0.10)
          : _alpha(Colors.black, biome.dark ? 0.10 : 0.04);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 2.2, height: r),
        patch,
      );
    }
  }

  void _paintEdgeTerrain(
    Canvas canvas,
    Size size,
    MapBiome biome,
    double bottom,
    double top,
  ) {
    final w = size.width;
    // Bands in global coordinates so neighbouring items line up.
    final start = (bottom / 200).floor() * 200.0 - 200;
    for (var gy = start; gy < top + 200; gy += 200) {
      final bandRand = math.Random(gy.round() * 13 + 1);
      for (final left in [true, false]) {
        final r = 70 + bandRand.nextDouble() * 60;
        final jitter = bandRand.nextDouble() * 80 - 40;
        final cy = top - (gy + jitter);
        final cx = left ? -r * 0.25 : w + r * 0.25;
        _paintEdgeShape(canvas, biome, Offset(cx, cy), r, left, bandRand);
      }
    }
  }

  void _paintEdgeShape(
    Canvas canvas,
    MapBiome biome,
    Offset c,
    double r,
    bool left,
    math.Random rand,
  ) {
    final far = Paint()..color = biome.terrainFar;
    final near = Paint()..color = biome.terrainNear;
    final light = Paint()
      ..color = _alpha(Colors.white, biome.dark ? 0.06 : 0.18);
    switch (biome.kind) {
      case BiomeKind.forest:
      case BiomeKind.cosmic:
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(0, -r * 0.35),
            width: r * 2.2,
            height: r * 1.5,
          ),
          far,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(left ? -r * 0.2 : r * 0.2, r * 0.1),
            width: r * 1.8,
            height: r * 1.2,
          ),
          near,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(left ? r * 0.15 : -r * 0.15, -r * 0.15),
            width: r * 0.9,
            height: r * 0.35,
          ),
          light,
        );
        if (biome.kind == BiomeKind.forest) {
          // A few tree tops crown each hill.
          final tree = Paint()..color = biome.decorA;
          final hi = Paint()..color = biome.decorB;
          for (var i = 0; i < 3; i++) {
            final p = c.translate(
              (left ? 1 : -1) * (r * 0.1 + i * r * 0.28),
              -r * 0.55 + rand.nextDouble() * r * 0.3,
            );
            canvas.drawCircle(p, r * 0.2, tree);
            canvas.drawCircle(p.translate(-r * 0.05, -r * 0.06), r * 0.12, hi);
          }
        }
      case BiomeKind.frozen:
      case BiomeKind.volcano:
      case BiomeKind.crystal:
        for (var i = 0; i < 2; i++) {
          final base = c.translate((left ? 1 : -1) * i * r * 0.55, r * 0.4);
          final hgt = r * (1.5 - i * 0.35);
          final half = r * (0.75 - i * 0.12);
          final peak = Path()
            ..moveTo(base.dx - half, base.dy)
            ..lineTo(base.dx, base.dy - hgt)
            ..lineTo(base.dx + half, base.dy)
            ..close();
          canvas.drawPath(peak, i == 0 ? far : near);
          // Lit face.
          canvas.drawPath(
            Path()
              ..moveTo(base.dx, base.dy - hgt)
              ..lineTo(base.dx - half, base.dy)
              ..lineTo(base.dx - half * 0.3, base.dy)
              ..close(),
            light,
          );
          final capColor = switch (biome.kind) {
            BiomeKind.frozen => Colors.white,
            BiomeKind.volcano => _alpha(biome.water, 0.85),
            _ => _alpha(biome.decorA, 0.9),
          };
          canvas.drawPath(
            Path()
              ..moveTo(base.dx - half * 0.3, base.dy - hgt * 0.7)
              ..lineTo(base.dx, base.dy - hgt)
              ..lineTo(base.dx + half * 0.3, base.dy - hgt * 0.7)
              ..lineTo(base.dx + half * 0.1, base.dy - hgt * 0.62)
              ..lineTo(base.dx - half * 0.08, base.dy - hgt * 0.72)
              ..close(),
            Paint()..color = capColor,
          );
        }
      case BiomeKind.desert:
        final mesa = RRect.fromRectAndCorners(
          Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.1),
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
        );
        canvas.drawRRect(mesa.shift(Offset(0, -r * 0.25)), far);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c.translate(0, r * 0.25),
              width: r * 1.5,
              height: r * 0.8,
            ),
            const Radius.circular(8),
          ),
          near,
        );
        final stripe = Paint()
          ..color = _alpha(Colors.white, 0.16)
          ..strokeWidth = 3;
        for (var i = 0; i < 3; i++) {
          final y = c.dy - r * 0.6 + i * r * 0.18;
          canvas.drawLine(
            Offset(c.dx - r * 0.9, y),
            Offset(c.dx + r * 0.9, y),
            stripe,
          );
        }
      case BiomeKind.islands:
        // Lagoon with a sandy beach.
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 2.4, height: r * 1.6),
          near,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(left ? -r * 0.2 : r * 0.2, 0),
            width: r * 2.0,
            height: r * 1.25,
          ),
          far,
        );
        final wave = Paint()
          ..color = _alpha(Colors.white, 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 2; i++) {
          final y = c.dy - r * 0.2 + i * r * 0.3;
          final x = c.dx + (left ? -r * 0.1 : r * 0.1);
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(x, y),
              width: r * 0.5,
              height: r * 0.2,
            ),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            wave,
          );
        }
      case BiomeKind.neon:
        for (var i = 0; i < 2; i++) {
          final bw = r * (0.4 + rand.nextDouble() * 0.2);
          final bh = r * (0.7 + rand.nextDouble() * 0.5);
          final bx = c.dx + (left ? 1 : -1) * (i * r * 0.35) - bw / 2;
          final rect = Rect.fromLTWH(bx, c.dy + r * 0.5 - bh, bw, bh);
          canvas.drawRect(rect, i.isEven ? far : near);
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, 3),
            Paint()
              ..color = _alpha(i.isEven ? biome.decorA : biome.decorB, 0.8),
          );
          final win = Paint();
          for (var wy = rect.top + 10; wy < rect.bottom - 8; wy += 14) {
            for (var wx = rect.left + 6; wx < rect.right - 8; wx += 12) {
              if (rand.nextDouble() < 0.45) continue;
              win.color = _alpha(
                [biome.decorA, biome.decorB, biome.decorC][rand.nextInt(3)],
                0.55,
              );
              canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 6), win);
            }
          }
        }
      default:
        ExtendedScenery.edge(canvas, biome, c, r, left, rand);
    }
  }

  // ── River and bridge ──────────────────────────────────────────────────

  void _paintRiver(Canvas canvas, Size size, MapBiome biome, double y) {
    final w = size.width;
    final path = Path()..moveTo(-10, y - 22);
    for (var x = -10.0; x <= w + 10; x += 16) {
      path.lineTo(x, y - 22 + math.sin(x * 0.025 + itemIndex) * 6);
    }
    for (var x = w + 10; x >= -10; x -= 16) {
      path.lineTo(x, y + 22 + math.sin(x * 0.03 + itemIndex * 2) * 6);
    }
    path.close();

    // Bank, water, highlights.
    canvas.drawPath(
      path,
      Paint()
        ..color = _alpha(_shade(biome.terrainNear, 0.2), 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    canvas.drawPath(path, Paint()..color = biome.water);
    final hi = Paint()
      ..color = _alpha(
        biome.waterLight,
        biome.kind == BiomeKind.desert ? 0.35 : 0.7,
      )
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rand = math.Random(itemIndex * 3 + 11);
    for (var i = 0; i < 9; i++) {
      final x = rand.nextDouble() * w;
      final dy = rand.nextDouble() * 24 - 12;
      final len = 10 + rand.nextDouble() * 18;
      canvas.drawLine(Offset(x, y + dy), Offset(x + len, y + dy), hi);
    }
    if (biome.kind == BiomeKind.cosmic) {
      final star = Paint()..color = _alpha(Colors.white, 0.8);
      for (var i = 0; i < 12; i++) {
        canvas.drawCircle(
          Offset(rand.nextDouble() * w, y + rand.nextDouble() * 30 - 15),
          0.8 + rand.nextDouble(),
          star,
        );
      }
    }
  }

  void _paintBridge(Canvas canvas, MapBiome biome, Offset a, Offset b) {
    final c = (a + b) / 2;
    final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    final len = (b - a).distance + 12;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final deck = Rect.fromCenter(center: Offset.zero, width: len, height: 40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        deck.shift(const Offset(0, 4)),
        const Radius.circular(6),
      ),
      Paint()..color = _alpha(Colors.black, 0.18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(deck, const Radius.circular(6)),
      Paint()..color = biome.bridge,
    );
    final plank = Paint()
      ..color = _shade(biome.bridge, 0.25)
      ..strokeWidth = 1.5;
    for (var x = -len / 2 + 7; x < len / 2 - 4; x += 8) {
      canvas.drawLine(Offset(x, -18), Offset(x, 18), plank);
    }
    final rail = Paint()
      ..color = _shade(biome.bridge, 0.35)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-len / 2, -20), Offset(len / 2, -20), rail);
    canvas.drawLine(Offset(-len / 2, 20), Offset(len / 2, 20), rail);
    final post = Paint()..color = _shade(biome.bridge, 0.45);
    for (final p in [
      Offset(-len / 2, -20),
      Offset(len / 2, -20),
      Offset(-len / 2, 20),
      Offset(len / 2, 20),
    ]) {
      canvas.drawCircle(p, 4.5, post);
    }
    canvas.restore();
  }

  // ── Trail ─────────────────────────────────────────────────────────────

  void _paintTrail(
    Canvas canvas,
    MapBiome biome,
    Offset Function(Offset) local,
  ) {
    final int from;
    final int to;
    if (_isStart) {
      from = 0;
      to = 1;
    } else if (_isSummit) {
      from = layout.totalLevels;
      to = layout.totalLevels + 1;
    } else {
      final s = layout.sections[_sectionIndex];
      from = s.firstLevel - 1;
      to = math.min(s.lastLevel + 1, layout.totalLevels + 1);
    }

    final walked = Path();
    final ahead = Path();
    for (var lvl = from; lvl < to; lvl++) {
      final a = local(layout.point(lvl));
      final b = local(layout.point(lvl + 1));
      final mid = (a.dy + b.dy) / 2;
      final target = lvl + 1 <= highestUnlocked ? walked : ahead;
      target
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
    }

    final both = Path()
      ..addPath(walked, Offset.zero)
      ..addPath(ahead, Offset.zero);
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = c;

    // Raised road: soft cast shadow, a visible side wall, then the top.
    canvas.drawPath(
      both.shift(const Offset(3, 10)),
      stroke(_alpha(Colors.black, biome.dark ? 0.28 : 0.12), 34),
    );
    canvas.drawPath(
      both.shift(const Offset(0, 6)),
      stroke(_shade(biome.trailEdge, 0.35), 32),
    );
    canvas.drawPath(both, stroke(biome.trailEdge, 32));
    canvas.drawPath(both, stroke(biome.trail, 24));
    canvas.drawPath(
      both.shift(const Offset(-2, -3)),
      stroke(_alpha(Colors.white, biome.dark ? 0.10 : 0.30), 7),
    );
    canvas.drawPath(
      ahead,
      stroke(
        _alpha(biome.dark ? Colors.black : _shade(biome.trailEdge, 0.3), 0.28),
        24,
      ),
    );

    // Footsteps along the travelled part.
    final dot = Paint()..color = _alpha(_shade(biome.accent, 0.05), 0.75);
    for (final metric in walked.computeMetrics()) {
      for (var d = 8.0; d < metric.length; d += 18) {
        final t = metric.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, 2.6, dot);
      }
    }
    // Dashed centre line on the road ahead.
    final dash = stroke(_alpha(Colors.white, biome.dark ? 0.18 : 0.55), 2.5);
    for (final metric in ahead.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 20) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 8, metric.length)),
          dash,
        );
      }
    }
  }

  // ── Gates, camp, summit ───────────────────────────────────────────────

  void _paintGate(
    Canvas canvas,
    MapBiome biome,
    Offset c, {
    required bool open,
  }) {
    final stone = _shade(biome.terrainNear, biome.dark ? 0.0 : 0.2);
    final stoneLight = _tint(stone, 0.25);
    const half = 48.0;
    final shadow = Paint()..color = _alpha(Colors.black, 0.18);
    for (final sx in [-half, half]) {
      final p = Rect.fromCenter(
        center: c.translate(sx, -6),
        width: 20,
        height: 74,
      );
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(sx, 32), width: 34, height: 10),
        shadow,
      );
      Map3D.cylinder(
        canvas,
        p.bottomCenter,
        p.width,
        p.height,
        stone,
        top: stoneLight,
      );
    }
    final arch = Path()
      ..moveTo(c.dx - half - 4, c.dy - 40)
      ..quadraticBezierTo(c.dx, c.dy - 78, c.dx + half + 4, c.dy - 40);
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = stone,
    );
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = open ? biome.accent : _alpha(Colors.white, 0.35),
    );
    // Keystone gem.
    canvas.drawCircle(c.translate(0, -59), 8, Paint()..color = stone);
    canvas.drawCircle(
      c.translate(0, -59),
      5,
      Paint()
        ..color = open ? _tint(biome.accent, 0.3) : Colors.blueGrey.shade300,
    );

    if (open) {
      final flag = Paint()..color = biome.accent;
      for (final sx in [-half, half]) {
        final top = c.translate(sx, -44);
        canvas.drawLine(
          top,
          top.translate(0, -26),
          Paint()
            ..color = _shade(stone, 0.3)
            ..strokeWidth = 2.5,
        );
        canvas.drawPath(
          Path()
            ..moveTo(top.dx, top.dy - 26)
            ..lineTo(top.dx + (sx < 0 ? -16 : 16), top.dy - 21)
            ..lineTo(top.dx, top.dy - 15)
            ..close(),
          flag,
        );
      }
    } else {
      final bar = Paint()
        ..color = _alpha(const Color(0xFF475569), 0.9)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (var x = -half + 14; x <= half - 14; x += 12) {
        canvas.drawLine(c.translate(x, -46), c.translate(x, 28), bar);
      }
      canvas.drawLine(
        c.translate(-half + 10, -8),
        c.translate(half - 10, -8),
        bar,
      );
    }
  }

  void _paintCamp(Canvas canvas, MapBiome biome, Offset start) {
    // Start pad.
    canvas.drawCircle(start, 26, Paint()..color = biome.trailEdge);
    canvas.drawCircle(start, 20, Paint()..color = biome.trail);
    canvas.drawCircle(
      start,
      20,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = biome.accent,
    );

    // Tent and campfire beside the pad.
    final side = start.dx < layout.width / 2 ? 1.0 : -1.0;
    final tent = start.translate(side * 96, -6);
    canvas.drawOval(
      Rect.fromCenter(center: tent.translate(0, 26), width: 86, height: 14),
      Paint()..color = _alpha(Colors.black, 0.15),
    );
    canvas.drawPath(
      Path()
        ..moveTo(tent.dx - 40, tent.dy + 26)
        ..lineTo(tent.dx, tent.dy - 30)
        ..lineTo(tent.dx + 40, tent.dy + 26)
        ..close(),
      Paint()..color = const Color(0xFFEF6C47),
    );
    canvas.drawPath(
      Path()
        ..moveTo(tent.dx, tent.dy - 30)
        ..lineTo(tent.dx + 40, tent.dy + 26)
        ..lineTo(tent.dx + 12, tent.dy + 26)
        ..close(),
      Paint()..color = const Color(0xFFC94F30),
    );
    canvas.drawPath(
      Path()
        ..moveTo(tent.dx - 9, tent.dy + 26)
        ..lineTo(tent.dx, tent.dy + 2)
        ..lineTo(tent.dx + 9, tent.dy + 26)
        ..close(),
      Paint()..color = const Color(0xFF5B2A1A),
    );
    final fire = start.translate(-side * 70, 18);
    final log = Paint()
      ..color = const Color(0xFF7A4E2A)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(fire.translate(-10, 6), fire.translate(10, -2), log);
    canvas.drawLine(fire.translate(10, 6), fire.translate(-10, -2), log);
    canvas.drawCircle(
      fire.translate(0, -8),
      8,
      Paint()..color = const Color(0xFFFF8A3D),
    );
    canvas.drawCircle(
      fire.translate(0, -10),
      4,
      Paint()..color = const Color(0xFFFFE08A),
    );
  }

  void _paintSummit(Canvas canvas, MapBiome biome, Offset p) {
    canvas.drawCircle(
      p,
      90,
      Paint()
        ..shader = ui.Gradient.radial(p, 90, [
          _alpha(biome.accent, 0.35),
          _alpha(biome.accent, 0),
        ]),
    );
    canvas.drawOval(
      Rect.fromCenter(center: p.translate(0, 8), width: 96, height: 30),
      Paint()..color = _shade(biome.terrainNear, 0.2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 84, height: 24),
      Paint()..color = biome.trail,
    );
    final pole = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p, p.translate(0, -84), pole);
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - 84)
        ..lineTo(p.dx + 42, p.dy - 72)
        ..lineTo(p.dx, p.dy - 58)
        ..close(),
      Paint()..color = biome.accent,
    );
  }

  // ── Landmarks ─────────────────────────────────────────────────────────

  List<_Landmark> _landmarks(double bottom, double top) {
    if (_isStart || _isSummit) return const [];
    return _landmarkCache.putIfAbsent(_cacheKey, () {
      final s = layout.sections[_sectionIndex];
      final rows = s.levelCount * LevelMapLayout.rowHeight;
      final out = <_Landmark>[];
      for (final (i, f) in [0.26, 0.78].indexed) {
        final y = s.bottom + LevelMapLayout.gateHeight + rows * f;
        final xs = [
          for (final dy in [-70.0, 0.0, 70.0]) layout.trailXAt(y + dy),
        ];
        final rightFree = layout.width - xs.reduce(math.max) - 64;
        final leftFree = xs.reduce(math.min) - 64;
        final right = rightFree >= leftFree;
        final free = right ? rightFree : leftFree;
        if (free < 64) continue;
        final size = free.clamp(70.0, 140.0);
        final x = right ? layout.width - free / 2 + 12 : free / 2 - 12;
        out.add(_Landmark(Offset(x, y), size, i, !right));
      }
      return out;
    });
  }

  void _paintLandmark(Canvas canvas, MapBiome biome, Offset c, _Landmark l) {
    if (ExtendedScenery.decorTable(biome.kind) != null) {
      ExtendedScenery.landmark(canvas, biome, c, l.size, l.variant, l.flip);
      return;
    }
    final s = l.size;
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, s * 0.42),
        width: s * 0.95,
        height: s * 0.2,
      ),
      Paint()..color = _alpha(Colors.black, biome.dark ? 0.3 : 0.14),
    );
    switch (biome.kind) {
      case BiomeKind.forest:
        final trunk = Paint()..color = const Color(0xFF7A5230);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c.translate(0, s * 0.18),
              width: s * 0.16,
              height: s * 0.5,
            ),
            const Radius.circular(6),
          ),
          trunk,
        );
        final dark = Paint()..color = _shade(biome.decorA, 0.15);
        final mid = Paint()..color = biome.decorA;
        final light = Paint()..color = biome.decorB;
        for (final (dx, dy, r) in [
          (-0.22, -0.05, 0.24),
          (0.22, -0.05, 0.24),
          (0.0, -0.22, 0.3),
        ]) {
          canvas.drawCircle(c.translate(s * dx, s * dy), s * r, dark);
        }
        canvas.drawCircle(c.translate(-s * 0.06, -s * 0.24), s * 0.24, mid);
        canvas.drawCircle(c.translate(-s * 0.12, -s * 0.3), s * 0.12, light);
        final fruit = Paint()..color = biome.decorC;
        for (final (dx, dy) in [
          (-0.2, -0.02),
          (0.18, -0.12),
          (0.05, -0.36),
          (0.26, 0.04),
        ]) {
          canvas.drawCircle(c.translate(s * dx, s * dy), s * 0.025, fruit);
        }
      case BiomeKind.desert:
        if (l.variant == 0) {
          final base = c.translate(0, s * 0.38);
          canvas.drawPath(
            Path()
              ..moveTo(base.dx - s * 0.48, base.dy)
              ..lineTo(base.dx, base.dy - s * 0.72)
              ..lineTo(base.dx + s * 0.48, base.dy)
              ..close(),
            Paint()..color = const Color(0xFFE9B96E),
          );
          canvas.drawPath(
            Path()
              ..moveTo(base.dx, base.dy - s * 0.72)
              ..lineTo(base.dx + s * 0.48, base.dy)
              ..lineTo(base.dx + s * 0.08, base.dy)
              ..close(),
            Paint()..color = const Color(0xFFC98F4A),
          );
          final line = Paint()
            ..color = _alpha(Colors.black, 0.08)
            ..strokeWidth = 1.5;
          for (var i = 1; i < 5; i++) {
            final y = base.dy - s * 0.72 * i / 5;
            final hw = s * 0.48 * (1 - i / 5);
            canvas.drawLine(
              Offset(base.dx - hw, y),
              Offset(base.dx + hw, y),
              line,
            );
          }
        } else {
          // Rock arch.
          final rock = Paint()..color = biome.terrainNear;
          final arch = Path()
            ..moveTo(c.dx - s * 0.45, c.dy + s * 0.38)
            ..lineTo(c.dx - s * 0.4, c.dy - s * 0.25)
            ..quadraticBezierTo(
              c.dx,
              c.dy - s * 0.55,
              c.dx + s * 0.4,
              c.dy - s * 0.25,
            )
            ..lineTo(c.dx + s * 0.45, c.dy + s * 0.38)
            ..lineTo(c.dx + s * 0.22, c.dy + s * 0.38)
            ..lineTo(c.dx + s * 0.2, c.dy - s * 0.05)
            ..quadraticBezierTo(
              c.dx,
              c.dy - s * 0.25,
              c.dx - s * 0.2,
              c.dy - s * 0.05,
            )
            ..lineTo(c.dx - s * 0.22, c.dy + s * 0.38)
            ..close();
          canvas.drawPath(arch, rock);
          canvas.drawPath(
            arch,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = _alpha(Colors.white, 0.2),
          );
        }
      case BiomeKind.frozen:
        final base = c.translate(0, s * 0.38);
        for (final (dx, h, w, col) in [
          (-0.18, 0.78, 0.42, biome.terrainNear),
          (0.16, 0.95, 0.48, _shade(biome.terrainNear, 0.12)),
        ]) {
          final b = base.translate(s * dx, 0);
          canvas.drawPath(
            Path()
              ..moveTo(b.dx - s * w, b.dy)
              ..lineTo(b.dx, b.dy - s * h)
              ..lineTo(b.dx + s * w, b.dy)
              ..close(),
            Paint()..color = col,
          );
          canvas.drawPath(
            Path()
              ..moveTo(b.dx - s * w * 0.35, b.dy - s * h * 0.65)
              ..lineTo(b.dx, b.dy - s * h)
              ..lineTo(b.dx + s * w * 0.35, b.dy - s * h * 0.65)
              ..lineTo(b.dx + s * w * 0.12, b.dy - s * h * 0.58)
              ..lineTo(b.dx - s * w * 0.1, b.dy - s * h * 0.68)
              ..close(),
            Paint()..color = Colors.white,
          );
        }
      case BiomeKind.islands:
        if (l.variant == 0) {
          // Lighthouse.
          final body = Path()
            ..moveTo(c.dx - s * 0.14, c.dy + s * 0.38)
            ..lineTo(c.dx - s * 0.09, c.dy - s * 0.3)
            ..lineTo(c.dx + s * 0.09, c.dy - s * 0.3)
            ..lineTo(c.dx + s * 0.14, c.dy + s * 0.38)
            ..close();
          canvas.drawPath(body, Paint()..color = Colors.white);
          final band = Paint()..color = const Color(0xFFE11D48);
          for (final y in [0.18, -0.06]) {
            canvas.drawRect(
              Rect.fromCenter(
                center: c.translate(0, s * y),
                width: s * 0.26,
                height: s * 0.09,
              ),
              band,
            );
          }
          canvas.drawRect(
            Rect.fromCenter(
              center: c.translate(0, -s * 0.36),
              width: s * 0.2,
              height: s * 0.12,
            ),
            Paint()..color = const Color(0xFFFDE68A),
          );
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - s * 0.13, c.dy - s * 0.42)
              ..lineTo(c.dx, c.dy - s * 0.52)
              ..lineTo(c.dx + s * 0.13, c.dy - s * 0.42)
              ..close(),
            Paint()..color = const Color(0xFF334155),
          );
          canvas.drawCircle(
            c.translate(0, -s * 0.36),
            s * 0.3,
            Paint()
              ..shader =
                  ui.Gradient.radial(c.translate(0, -s * 0.36), s * 0.3, [
                    _alpha(const Color(0xFFFDE68A), 0.45),
                    _alpha(const Color(0xFFFDE68A), 0),
                  ]),
          );
        } else {
          _paintMushroom(
            canvas,
            c.translate(0, s * 0.1),
            s / 34,
            biome,
            glow: true,
          );
        }
      case BiomeKind.volcano:
        final base = c.translate(0, s * 0.38);
        canvas.drawPath(
          Path()
            ..moveTo(base.dx - s * 0.5, base.dy)
            ..lineTo(base.dx - s * 0.12, base.dy - s * 0.66)
            ..lineTo(base.dx + s * 0.12, base.dy - s * 0.66)
            ..lineTo(base.dx + s * 0.5, base.dy)
            ..close(),
          Paint()..color = biome.terrainNear,
        );
        canvas.drawPath(
          Path()
            ..moveTo(base.dx - s * 0.12, base.dy - s * 0.66)
            ..lineTo(base.dx - s * 0.04, base.dy - s * 0.4)
            ..lineTo(base.dx + s * 0.03, base.dy - s * 0.52)
            ..lineTo(base.dx + s * 0.1, base.dy - s * 0.3)
            ..lineTo(base.dx + s * 0.12, base.dy - s * 0.66)
            ..close(),
          Paint()..color = biome.water,
        );
        final smoke = Paint()..color = _alpha(const Color(0xFF9CA3AF), 0.35);
        for (final (dx, dy, r) in [
          (0.0, -0.78, 0.09),
          (0.08, -0.9, 0.11),
          (0.0, -1.04, 0.13),
        ]) {
          canvas.drawCircle(
            c.translate(s * dx, s * dy + s * 0.38),
            s * r,
            smoke,
          );
        }
      case BiomeKind.neon:
        if (l.variant == 0) {
          final tower = Rect.fromCenter(
            center: c.translate(0, -s * 0.05),
            width: s * 0.3,
            height: s * 0.86,
          );
          canvas.drawRect(tower, Paint()..color = const Color(0xFF312E81));
          final stripe = Paint()
            ..color = biome.decorB
            ..strokeWidth = 2;
          canvas.drawLine(tower.topLeft, tower.bottomLeft, stripe);
          canvas.drawLine(
            tower.topRight,
            tower.bottomRight,
            Paint()
              ..color = biome.decorA
              ..strokeWidth = 2,
          );
          final win = Paint()..color = _alpha(biome.decorC, 0.7);
          for (var y = tower.top + 8; y < tower.bottom - 6; y += 10) {
            canvas.drawRect(
              Rect.fromLTWH(tower.left + 5, y, tower.width - 10, 3),
              win,
            );
          }
          canvas.drawLine(
            tower.topCenter,
            tower.topCenter.translate(0, -s * 0.18),
            Paint()
              ..color = const Color(0xFFCBD5E1)
              ..strokeWidth = 2,
          );
          canvas.drawCircle(
            tower.topCenter.translate(0, -s * 0.18),
            3,
            Paint()..color = biome.decorA,
          );
        } else {
          // Ferris wheel.
          final hub = c.translate(0, -s * 0.08);
          final r = s * 0.36;
          final ring = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = biome.decorA;
          canvas.drawCircle(hub, r, ring);
          final spoke = Paint()
            ..color = _alpha(biome.decorB, 0.7)
            ..strokeWidth = 1.5;
          for (var i = 0; i < 8; i++) {
            final a = i * math.pi / 4;
            final p = hub + Offset(math.cos(a), math.sin(a)) * r;
            canvas.drawLine(hub, p, spoke);
            canvas.drawCircle(
              p,
              4,
              Paint()
                ..color = [biome.decorA, biome.decorB, biome.decorC][i % 3],
            );
          }
          final leg = Paint()
            ..color = const Color(0xFF94A3B8)
            ..strokeWidth = 3;
          canvas.drawLine(hub, c.translate(-s * 0.2, s * 0.4), leg);
          canvas.drawLine(hub, c.translate(s * 0.2, s * 0.4), leg);
        }
      case BiomeKind.crystal:
        _paintCrystal(
          canvas,
          c.translate(0, s * 0.38),
          s / 30,
          biome,
          big: true,
        );
      case BiomeKind.cosmic:
        final p = c.translate(0, -s * 0.05);
        final r = s * 0.26;
        if (l.variant == 0) {
          canvas.drawCircle(
            p,
            r,
            Paint()
              ..shader = ui.Gradient.linear(
                p.translate(-r, -r),
                p.translate(r, r),
                [biome.decorC, const Color(0xFF7C3AED)],
              ),
          );
          canvas.drawOval(
            Rect.fromCenter(center: p, width: r * 3.2, height: r * 0.8),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = _alpha(biome.decorA, 0.85),
          );
        } else {
          canvas.drawCircle(p, r, Paint()..color = const Color(0xFFE2E8F0));
          final crater = Paint()..color = const Color(0xFFCBD5E1);
          for (final (dx, dy, cr) in [
            (-0.3, -0.2, 0.22),
            (0.35, 0.1, 0.16),
            (-0.05, 0.4, 0.12),
          ]) {
            canvas.drawCircle(p.translate(r * dx, r * dy), r * cr, crater);
          }
        }
      default:
        break;
    }
  }

  // ── Decorations ───────────────────────────────────────────────────────

  static const Map<BiomeKind, List<(_DecorKind, int)>> _decorTable = {
    BiomeKind.forest: [
      (_DecorKind.roundTree, 3),
      (_DecorKind.pine, 2),
      (_DecorKind.bush, 2),
      (_DecorKind.flowers, 3),
      (_DecorKind.rock, 1),
      (_DecorKind.mushroom, 1),
    ],
    BiomeKind.desert: [
      (_DecorKind.cactus, 3),
      (_DecorKind.rock, 3),
      (_DecorKind.mound, 2),
      (_DecorKind.deadTree, 1),
      (_DecorKind.flowers, 1),
    ],
    BiomeKind.frozen: [
      (_DecorKind.snowPine, 4),
      (_DecorKind.rock, 2),
      (_DecorKind.mound, 2),
      (_DecorKind.crystal, 1),
    ],
    BiomeKind.islands: [
      (_DecorKind.palm, 3),
      (_DecorKind.bush, 2),
      (_DecorKind.flowers, 2),
      (_DecorKind.glowMushroom, 2),
      (_DecorKind.rock, 1),
    ],
    BiomeKind.volcano: [
      (_DecorKind.rock, 3),
      (_DecorKind.deadTree, 2),
      (_DecorKind.lavaPool, 2),
      (_DecorKind.mound, 1),
    ],
    BiomeKind.neon: [
      (_DecorKind.building, 3),
      (_DecorKind.lamp, 3),
      (_DecorKind.neonSign, 2),
      (_DecorKind.bush, 1),
    ],
    BiomeKind.crystal: [
      (_DecorKind.crystal, 4),
      (_DecorKind.glowMushroom, 3),
      (_DecorKind.rock, 2),
    ],
    BiomeKind.cosmic: [
      (_DecorKind.sparkle, 3),
      (_DecorKind.planet, 1),
      (_DecorKind.floatingRock, 2),
      (_DecorKind.crystal, 1),
    ],
  };

  List<_Decor> _decorations(double bottom, double top) {
    return _decorCache.putIfAbsent(_cacheKey, () {
      final biome = _biome;
      final ext = ExtendedScenery.decorTable(biome.kind);
      final table = ext == null
          ? _decorTable[biome.kind]!
          : [for (final (_, w) in ext) (_DecorKind.rock, w)];
      final totalWeight = table.fold<int>(0, (s, e) => s + e.$2);
      final rand = math.Random(itemIndex * 7919 + 13);
      final riverY = _riverY;
      final landmarks = _landmarks(bottom, top);
      final w = layout.width;
      double? archY;
      double? bannerY;
      if (!_isStart && !_isSummit) {
        archY = layout.gateArchY(_sectionIndex);
        bannerY = layout.gateBannerY(_sectionIndex);
      }
      final out = <_Decor>[];
      for (var y = bottom + 20; y < top - 20; y += 30) {
        for (var attempt = 0; attempt < 2; attempt++) {
          final x = rand.nextDouble() * w;
          final scale = 0.75 + rand.nextDouble() * 0.5;
          var pick = rand.nextInt(totalWeight);
          final variant = rand.nextInt(3);
          var kind = table.first.$1;
          SceneDecor? extKind;
          for (var k = 0; k < table.length; k++) {
            final e = table[k];
            if (pick < e.$2) {
              kind = e.$1;
              extKind = ext?[k].$1;
              break;
            }
            pick -= e.$2;
          }
          final clearance = 58 + 16 * scale;
          if ((x - layout.trailXAt(y)).abs() < clearance) continue;
          if ((x - layout.trailXAt(y + 30)).abs() < clearance) continue;
          if ((x - layout.trailXAt(y - 30)).abs() < clearance) continue;
          if (riverY != null && (y - riverY).abs() < 46) continue;
          if (archY != null &&
              (y - archY).abs() < 70 &&
              (x - layout.trailXAt(archY)).abs() < 100) {
            continue;
          }
          if (bannerY != null &&
              (y - bannerY).abs() < 48 &&
              (x - w / 2).abs() < 170) {
            continue;
          }
          if (_isStart && y < 200 && (x - w / 2).abs() < 150) continue;
          if (_isSummit && (x - w / 2).abs() < 160) continue;
          if (landmarks.any(
            (l) => (Offset(x, y) - l.pos).distance < l.size * 0.62,
          )) {
            continue;
          }
          // Trophies sit beside each world's last level.
          if (!_isStart && !_isSummit) {
            final last = layout.sections[_sectionIndex].lastLevel;
            final ly = layout.nodeY(last);
            if ((y - ly).abs() < 60 && (x - layout.nodeX(last)).abs() < 130) {
              continue;
            }
          }
          out.add(_Decor(kind, Offset(x, y), scale, variant, extKind));
        }
      }
      // Back to front: higher on the map is further away.
      out.sort((a, b) => b.pos.dy.compareTo(a.pos.dy));
      return out;
    });
  }

  void _paintDecor(Canvas canvas, MapBiome biome, Offset c, _Decor d) {
    final s = d.scale;
    final ext = d.ext;
    if (ext != null) {
      ExtendedScenery.decor(canvas, biome, c, s, ext, d.variant);
      return;
    }
    final shadow = Paint()
      ..color = _alpha(Colors.black, biome.dark ? 0.25 : 0.12);
    void ground(double w) => canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, 2),
        width: w * s,
        height: w * s * 0.3,
      ),
      shadow,
    );
    switch (d.kind) {
      case _DecorKind.roundTree:
        ground(30);
        canvas.drawRect(
          Rect.fromCenter(
            center: c.translate(0, -6 * s),
            width: 5 * s,
            height: 14 * s,
          ),
          Paint()..color = const Color(0xFF7A5230),
        );
        Map3D.sphere(canvas, c.translate(0, -20 * s), 13 * s, biome.decorA);
      case _DecorKind.pine:
      case _DecorKind.snowPine:
        ground(26);
        canvas.drawRect(
          Rect.fromCenter(
            center: c.translate(0, -3 * s),
            width: 4 * s,
            height: 8 * s,
          ),
          Paint()..color = const Color(0xFF6B4A2B),
        );
        for (var i = 0; i < 3; i++) {
          final by = c.dy - 6 * s - i * 9 * s;
          final hw = (12 - i * 3) * s;
          final tri = Path()
            ..moveTo(c.dx - hw, by)
            ..lineTo(c.dx, by - 14 * s)
            ..lineTo(c.dx + hw, by)
            ..close();
          canvas.drawPath(
            tri,
            Paint()..color = i.isEven ? biome.decorA : biome.decorB,
          );
          // Shaded right half gives each tier volume.
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, by - 14 * s)
              ..lineTo(c.dx + hw, by)
              ..lineTo(c.dx + hw * 0.1, by)
              ..close(),
            Paint()..color = _alpha(Colors.black, 0.16),
          );
          if (d.kind == _DecorKind.snowPine) {
            canvas.drawPath(
              Path()
                ..moveTo(c.dx - hw * 0.45, by - 7 * s)
                ..lineTo(c.dx, by - 14 * s)
                ..lineTo(c.dx + hw * 0.45, by - 7 * s)
                ..close(),
              Paint()..color = Colors.white,
            );
          }
        }
      case _DecorKind.bush:
        ground(28);
        final col = biome.kind == BiomeKind.neon
            ? const Color(0xFF14532D)
            : biome.decorA;
        for (final (dx, dy, r) in [
          (-7.0, -5.0, 7.0),
          (7.0, -5.0, 7.0),
          (0.0, -10.0, 8.0),
        ]) {
          Map3D.sphere(
            canvas,
            c.translate(dx * s, dy * s),
            r * s,
            col,
            gloss: 0.3,
          );
        }
      case _DecorKind.flowers:
        final leaf = Paint()..color = biome.decorA;
        final petal = Paint()
          ..color = [
            biome.decorC,
            const Color(0xFFFFE066),
            Colors.white,
          ][d.variant];
        final centre = Paint()..color = const Color(0xFFF59E0B);
        for (final (dx, dy) in [(-6.0, 0.0), (5.0, -3.0), (0.0, -8.0)]) {
          final p = c.translate(dx * s, dy * s);
          canvas.drawCircle(p.translate(0, 3 * s), 2.2 * s, leaf);
          canvas.drawCircle(p, 3.2 * s, petal);
          canvas.drawCircle(p, 1.3 * s, centre);
        }
      case _DecorKind.rock:
        ground(26);
        final base = biome.dark
            ? _tint(biome.terrainNear, 0.2)
            : Color.lerp(biome.terrainNear, const Color(0xFF94A3B8), 0.55)!;
        final rock = Path()
          ..moveTo(c.dx - 12 * s, c.dy)
          ..lineTo(c.dx - 9 * s, c.dy - 9 * s)
          ..lineTo(c.dx - 1 * s, c.dy - 13 * s)
          ..lineTo(c.dx + 9 * s, c.dy - 8 * s)
          ..lineTo(c.dx + 12 * s, c.dy)
          ..close();
        canvas.drawPath(rock, Paint()..color = base);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 9 * s, c.dy - 9 * s)
            ..lineTo(c.dx - 1 * s, c.dy - 13 * s)
            ..lineTo(c.dx + 1 * s, c.dy - 6 * s)
            ..close(),
          Paint()..color = _tint(base, 0.3),
        );
      case _DecorKind.mushroom:
        _paintMushroom(canvas, c, s, biome, glow: false);
      case _DecorKind.glowMushroom:
        _paintMushroom(canvas, c, s, biome, glow: true);
      case _DecorKind.cactus:
        ground(22);
        final green = Paint()..color = biome.decorA;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c.translate(0, -12 * s),
              width: 8 * s,
              height: 24 * s,
            ),
            Radius.circular(4 * s),
          ),
          green,
        );
        final arm = Paint()
          ..color = biome.decorA
          ..strokeWidth = 5 * s
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 3 * s, c.dy - 10 * s)
            ..lineTo(c.dx - 9 * s, c.dy - 10 * s)
            ..lineTo(c.dx - 9 * s, c.dy - 17 * s),
          arm,
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + 3 * s, c.dy - 14 * s)
            ..lineTo(c.dx + 8 * s, c.dy - 14 * s)
            ..lineTo(c.dx + 8 * s, c.dy - 20 * s),
          arm,
        );
        canvas.drawLine(
          c.translate(-1.5 * s, -21 * s),
          c.translate(-1.5 * s, -4 * s),
          Paint()
            ..color = _tint(biome.decorA, 0.25)
            ..strokeWidth = 1.5 * s,
        );
      case _DecorKind.mound:
        final col = switch (biome.kind) {
          BiomeKind.frozen => Colors.white,
          BiomeKind.volcano => const Color(0xFF6B5E5C),
          _ => _shade(biome.groundTop, 0.08),
        };
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(0, -3 * s),
            width: 34 * s,
            height: 14 * s,
          ),
          Paint()..color = col,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(-5 * s, -6 * s),
            width: 14 * s,
            height: 4 * s,
          ),
          Paint()..color = _alpha(Colors.white, 0.35),
        );
      case _DecorKind.palm:
        ground(26);
        final trunk = Paint()
          ..color = biome.decorB
          ..strokeWidth = 4 * s
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final topP = c.translate(5 * s, -26 * s);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..quadraticBezierTo(c.dx - 2 * s, c.dy - 14 * s, topP.dx, topP.dy),
          trunk,
        );
        final leaf = Paint()..color = biome.decorA;
        for (var i = 0; i < 5; i++) {
          canvas.save();
          canvas.translate(topP.dx, topP.dy);
          canvas.rotate(-math.pi / 2 + (i - 2) * 0.7);
          canvas.drawOval(Rect.fromLTWH(0, -3 * s, 15 * s, 6 * s), leaf);
          canvas.restore();
        }
        canvas.drawCircle(
          topP.translate(0, 2 * s),
          2.5 * s,
          Paint()..color = const Color(0xFF7A4E2A),
        );
      case _DecorKind.deadTree:
        ground(22);
        final b = Paint()
          ..color = biome.kind == BiomeKind.desert
              ? const Color(0xFF8B5E3C)
              : biome.decorB
          ..strokeWidth = 3 * s
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c, c.translate(0, -22 * s), b);
        canvas.drawLine(
          c.translate(0, -12 * s),
          c.translate(-8 * s, -20 * s),
          b,
        );
        canvas.drawLine(
          c.translate(0, -16 * s),
          c.translate(7 * s, -24 * s),
          b,
        );
        canvas.drawLine(
          c.translate(-4 * s, -16 * s),
          c.translate(-9 * s, -14 * s),
          b,
        );
      case _DecorKind.lavaPool:
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(0, -2 * s),
            width: 30 * s,
            height: 12 * s,
          ),
          Paint()..color = const Color(0xFF2A2221),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(0, -2 * s),
            width: 24 * s,
            height: 8 * s,
          ),
          Paint()..color = biome.water,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(-3 * s, -3 * s),
            width: 10 * s,
            height: 3 * s,
          ),
          Paint()..color = biome.waterLight,
        );
      case _DecorKind.lamp:
        final glowCol = [biome.decorA, biome.decorB, biome.decorC][d.variant];
        canvas.drawCircle(
          c.translate(0, -26 * s),
          14 * s,
          Paint()
            ..shader = ui.Gradient.radial(c.translate(0, -26 * s), 14 * s, [
              _alpha(glowCol, 0.45),
              _alpha(glowCol, 0),
            ]),
        );
        canvas.drawLine(
          c,
          c.translate(0, -24 * s),
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..strokeWidth = 2 * s,
        );
        canvas.drawCircle(
          c.translate(0, -26 * s),
          3.5 * s,
          Paint()..color = glowCol,
        );
      case _DecorKind.building:
        ground(30);
        final rect = Rect.fromLTWH(
          c.dx - 11 * s,
          c.dy - (22 + d.variant * 8) * s,
          22 * s,
          (22 + d.variant * 8) * s,
        );
        canvas.drawRect(rect, Paint()..color = const Color(0xFF34306A));
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width, 2.5 * s),
          Paint()
            ..color = [biome.decorA, biome.decorB, biome.decorC][d.variant],
        );
        final win = Paint()..color = _alpha(biome.decorC, 0.75);
        for (var y = rect.top + 6 * s; y < rect.bottom - 4 * s; y += 7 * s) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left + 4 * s, y, 4 * s, 3 * s),
            win,
          );
          canvas.drawRect(
            Rect.fromLTWH(rect.right - 8 * s, y, 4 * s, 3 * s),
            win,
          );
        }
      case _DecorKind.neonSign:
        final col = [biome.decorA, biome.decorB, biome.decorC][d.variant];
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(0, -14 * s),
            width: 26 * s,
            height: 13 * s,
          ),
          Radius.circular(4 * s),
        );
        canvas.drawRRect(r.inflate(3 * s), Paint()..color = _alpha(col, 0.18));
        canvas.drawRRect(r, Paint()..color = const Color(0xFF1E1B4B));
        canvas.drawRRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8 * s
            ..color = col,
        );
        canvas.drawLine(
          c.translate(-6 * s, -14 * s),
          c.translate(6 * s, -14 * s),
          Paint()
            ..color = col
            ..strokeWidth = 2 * s
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          c,
          c.translate(0, -7.5 * s),
          Paint()
            ..color = const Color(0xFF64748B)
            ..strokeWidth = 2 * s,
        );
      case _DecorKind.crystal:
        _paintCrystal(
          canvas,
          c,
          s * 0.8,
          biome,
          big: false,
          variant: d.variant,
        );
      case _DecorKind.sparkle:
        final col = [biome.decorA, biome.decorB, biome.decorC][d.variant];
        final r = 7 * s;
        final p = c.translate(0, -8 * s);
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - r)
            ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
            ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
            ..close(),
          Paint()..color = col,
        );
      case _DecorKind.planet:
        final p = c.translate(0, -12 * s);
        final col = [
          biome.decorB,
          biome.decorC,
          const Color(0xFF86EFAC),
        ][d.variant];
        canvas.drawCircle(p, 8 * s, Paint()..color = col);
        canvas.drawCircle(
          p.translate(-2.5 * s, -2.5 * s),
          3 * s,
          Paint()..color = _alpha(Colors.white, 0.35),
        );
        canvas.drawOval(
          Rect.fromCenter(center: p, width: 26 * s, height: 6 * s),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * s
            ..color = _alpha(biome.decorA, 0.8),
        );
      case _DecorKind.floatingRock:
        final p = c.translate(0, -10 * s);
        final rock = Path()
          ..moveTo(p.dx - 14 * s, p.dy - 3 * s)
          ..lineTo(p.dx + 14 * s, p.dy - 3 * s)
          ..lineTo(p.dx + 5 * s, p.dy + 10 * s)
          ..lineTo(p.dx - 4 * s, p.dy + 8 * s)
          ..close();
        canvas.drawPath(rock, Paint()..color = const Color(0xFF3B4479));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p.translate(0, -4 * s),
              width: 30 * s,
              height: 5 * s,
            ),
            Radius.circular(3 * s),
          ),
          Paint()..color = _alpha(biome.decorB, 0.75),
        );
    }
  }

  void _paintMushroom(
    Canvas canvas,
    Offset c,
    double s,
    MapBiome biome, {
    required bool glow,
  }) {
    final cap = glow ? biome.decorC : const Color(0xFFE5484D);
    if (glow) {
      canvas.drawCircle(
        c.translate(0, -12 * s),
        16 * s,
        Paint()
          ..shader = ui.Gradient.radial(c.translate(0, -12 * s), 16 * s, [
            _alpha(cap, 0.4),
            _alpha(cap, 0),
          ]),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, 1), width: 18 * s, height: 5 * s),
      Paint()..color = _alpha(Colors.black, 0.15),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, -5 * s),
          width: 6 * s,
          height: 10 * s,
        ),
        Radius.circular(2 * s),
      ),
      Paint()..color = const Color(0xFFFFF4E0),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: c.translate(0, -10 * s),
        width: 20 * s,
        height: 16 * s,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = cap,
    );
    final dot = Paint()..color = _alpha(Colors.white, 0.85);
    canvas.drawCircle(c.translate(-4 * s, -14 * s), 1.6 * s, dot);
    canvas.drawCircle(c.translate(3 * s, -15 * s), 1.3 * s, dot);
  }

  void _paintCrystal(
    Canvas canvas,
    Offset base,
    double s,
    MapBiome biome, {
    required bool big,
    int variant = 0,
  }) {
    final colors = [biome.decorA, biome.decorB, biome.decorC];
    final shards = big
        ? [
            (-9.0, 26.0, 6.0, 0),
            (0.0, 36.0, 8.0, 1),
            (10.0, 24.0, 6.0, 2),
            (-17.0, 15.0, 4.5, 2),
            (17.0, 14.0, 4.5, 0),
          ]
        : [(-4.0, 16.0, 4.0, variant), (4.0, 12.0, 3.5, (variant + 1) % 3)];
    if (big) {
      canvas.drawCircle(
        base.translate(0, -18 * s),
        30 * s,
        Paint()
          ..shader = ui.Gradient.radial(base.translate(0, -18 * s), 30 * s, [
            _alpha(biome.decorA, 0.35),
            _alpha(biome.decorA, 0),
          ]),
      );
    }
    for (final (dx, h, w, ci) in shards) {
      final b = base.translate(dx * s, 0);
      final col = colors[ci % 3];
      canvas.drawPath(
        Path()
          ..moveTo(b.dx - w * s, b.dy)
          ..lineTo(b.dx - w * s, b.dy - h * s * 0.7)
          ..lineTo(b.dx, b.dy - h * s)
          ..lineTo(b.dx + w * s, b.dy - h * s * 0.7)
          ..lineTo(b.dx + w * s, b.dy)
          ..close(),
        Paint()..color = col,
      );
      canvas.drawPath(
        Path()
          ..moveTo(b.dx - w * s, b.dy)
          ..lineTo(b.dx - w * s, b.dy - h * s * 0.7)
          ..lineTo(b.dx, b.dy - h * s)
          ..lineTo(b.dx, b.dy)
          ..close(),
        Paint()..color = _alpha(Colors.white, 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MapScenePainter old) =>
      old.highestUnlocked != highestUnlocked ||
      old.itemIndex != itemIndex ||
      old.layout.width != layout.width ||
      old.layout.totalLevels != layout.totalLevels;
}
