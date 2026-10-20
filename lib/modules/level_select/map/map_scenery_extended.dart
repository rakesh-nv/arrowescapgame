import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'map_3d.dart';
import 'map_biome.dart';

/// Decorations used by the extended-campaign regions.
enum SceneDecor {
  topiary,
  hedge,
  sphereTree,
  bush,
  rock,
  palm,
  lavender,
  fountain,
  kolam,
  torch,
  pot,
  flag,
  lotusPad,
  reeds,
  fern,
  feather,
  umbrella,
  puddle,
  lantern,
  stall,
  stupa,
  coral,
  seaweed,
  shell,
  duneGrass,
  yurt,
  standingStone,
  iceShard,
  igloo,
  cloudPuff,
  stormRock,
  bamboo,
  glowTree,
  glowShroom,
  snowTree,
  hoodoo,
  buoy,
  boat,
  stalagmite,
  gem,
  sunflower,
  windmill,
  pinwheel,
  asteroid,
  orb,
  obsidianShard,
  threadPost,
  prismCrystal,
  column,
}

/// Terrain, landmarks and decorations for the regions of worlds 9–40.
///
/// Every region has its own signature landmark, terrain at the map edges and
/// decoration mix, all drawn with [Map3D]'s shaded solids, so no two worlds
/// share a background.
class ExtendedScenery {
  ExtendedScenery._();

  static Color _s(Color c, double t) => Map3D.shade(c, t);
  static Color _t(Color c, double t) => Map3D.tint(c, t);
  static Color _a(Color c, double a) => Map3D.alpha(c, a);

  // ── Decoration tables ────────────────────────────────────────────────

  static const Map<BiomeKind, List<(SceneDecor, int)>> _tables = {
    BiomeKind.garden: [
      (SceneDecor.topiary, 3),
      (SceneDecor.hedge, 2),
      (SceneDecor.sphereTree, 2),
      (SceneDecor.lavender, 2),
      (SceneDecor.fountain, 1),
    ],
    BiomeKind.courtyard: [
      (SceneDecor.kolam, 3),
      (SceneDecor.torch, 2),
      (SceneDecor.pot, 2),
      (SceneDecor.sphereTree, 1),
      (SceneDecor.flag, 1),
    ],
    BiomeKind.lotusLake: [
      (SceneDecor.lotusPad, 4),
      (SceneDecor.reeds, 3),
      (SceneDecor.fern, 1),
      (SceneDecor.rock, 1),
    ],
    BiomeKind.valley: [
      (SceneDecor.fern, 3),
      (SceneDecor.feather, 2),
      (SceneDecor.sphereTree, 2),
      (SceneDecor.rock, 1),
    ],
    BiomeKind.monsoon: [
      (SceneDecor.hedge, 3),
      (SceneDecor.umbrella, 2),
      (SceneDecor.bush, 2),
      (SceneDecor.puddle, 2),
    ],
    BiomeKind.bazaar: [
      (SceneDecor.lantern, 3),
      (SceneDecor.stall, 3),
      (SceneDecor.pot, 1),
      (SceneDecor.flag, 1),
    ],
    BiomeKind.mandalaHeights: [
      (SceneDecor.stupa, 2),
      (SceneDecor.flag, 2),
      (SceneDecor.rock, 2),
      (SceneDecor.sphereTree, 1),
    ],
    BiomeKind.reef: [
      (SceneDecor.coral, 4),
      (SceneDecor.seaweed, 3),
      (SceneDecor.shell, 2),
      (SceneDecor.rock, 1),
    ],
    BiomeKind.mirage: [
      (SceneDecor.duneGrass, 3),
      (SceneDecor.palm, 2),
      (SceneDecor.rock, 1),
      (SceneDecor.pot, 1),
    ],
    BiomeKind.steppe: [
      (SceneDecor.yurt, 2),
      (SceneDecor.standingStone, 2),
      (SceneDecor.duneGrass, 2),
      (SceneDecor.torch, 1),
    ],
    BiomeKind.temple: [
      (SceneDecor.fern, 3),
      (SceneDecor.sphereTree, 2),
      (SceneDecor.standingStone, 2),
      (SceneDecor.torch, 1),
    ],
    BiomeKind.glacier: [
      (SceneDecor.iceShard, 3),
      (SceneDecor.cloudPuff, 2),
      (SceneDecor.igloo, 1),
      (SceneDecor.snowTree, 1),
    ],
    BiomeKind.storm: [
      (SceneDecor.stormRock, 3),
      (SceneDecor.rock, 2),
      (SceneDecor.standingStone, 1),
    ],
    BiomeKind.silkRoad: [
      (SceneDecor.pot, 2),
      (SceneDecor.flag, 2),
      (SceneDecor.rock, 2),
      (SceneDecor.palm, 1),
      (SceneDecor.lantern, 1),
    ],
    BiomeKind.terraces: [
      (SceneDecor.bamboo, 3),
      (SceneDecor.fern, 2),
      (SceneDecor.sphereTree, 1),
      (SceneDecor.rock, 1),
    ],
    BiomeKind.fireflyForest: [
      (SceneDecor.glowTree, 3),
      (SceneDecor.glowShroom, 3),
      (SceneDecor.fern, 2),
    ],
    BiomeKind.citadel: [
      (SceneDecor.kolam, 3),
      (SceneDecor.torch, 2),
      (SceneDecor.pot, 2),
      (SceneDecor.flag, 1),
    ],
    BiomeKind.aurora: [
      (SceneDecor.snowTree, 3),
      (SceneDecor.cloudPuff, 2),
      (SceneDecor.igloo, 1),
    ],
    BiomeKind.arches: [
      (SceneDecor.hoodoo, 3),
      (SceneDecor.rock, 2),
      (SceneDecor.duneGrass, 2),
    ],
    BiomeKind.harbor: [
      (SceneDecor.buoy, 2),
      (SceneDecor.boat, 2),
      (SceneDecor.torch, 2),
      (SceneDecor.rock, 1),
    ],
    BiomeKind.grotto: [
      (SceneDecor.stalagmite, 3),
      (SceneDecor.gem, 3),
      (SceneDecor.glowShroom, 2),
    ],
    BiomeKind.sunfield: [
      (SceneDecor.sunflower, 4),
      (SceneDecor.bush, 2),
      (SceneDecor.windmill, 1),
    ],
    BiomeKind.windPass: [
      (SceneDecor.pinwheel, 3),
      (SceneDecor.rock, 2),
      (SceneDecor.duneGrass, 2),
      (SceneDecor.flag, 1),
    ],
    BiomeKind.hedgeMaze: [
      (SceneDecor.hedge, 4),
      (SceneDecor.topiary, 2),
      (SceneDecor.fountain, 1),
    ],
    BiomeKind.comet: [
      (SceneDecor.asteroid, 3),
      (SceneDecor.gem, 2),
      (SceneDecor.orb, 1),
    ],
    BiomeKind.twilight: [
      (SceneDecor.lavender, 3),
      (SceneDecor.torch, 2),
      (SceneDecor.sphereTree, 1),
      (SceneDecor.topiary, 1),
    ],
    BiomeKind.obsidian: [
      (SceneDecor.obsidianShard, 4),
      (SceneDecor.rock, 1),
      (SceneDecor.gem, 1),
    ],
    BiomeKind.loom: [
      (SceneDecor.threadPost, 3),
      (SceneDecor.orb, 2),
      (SceneDecor.gem, 1),
    ],
    BiomeKind.prism: [
      (SceneDecor.prismCrystal, 3),
      (SceneDecor.orb, 2),
      (SceneDecor.cloudPuff, 1),
    ],
    BiomeKind.royal: [
      (SceneDecor.topiary, 2),
      (SceneDecor.hedge, 2),
      (SceneDecor.flag, 2),
      (SceneDecor.column, 1),
      (SceneDecor.fountain, 1),
    ],
    BiomeKind.pantheon: [
      (SceneDecor.column, 3),
      (SceneDecor.pot, 2),
      (SceneDecor.sphereTree, 1),
      (SceneDecor.torch, 1),
    ],
    BiomeKind.skyIsles: [
      (SceneDecor.cloudPuff, 3),
      (SceneDecor.sphereTree, 2),
      (SceneDecor.pinwheel, 1),
      (SceneDecor.orb, 1),
    ],
  };

  /// Decoration mix of [kind], or null for the original regions (which use
  /// the painter's own table).
  static List<(SceneDecor, int)>? decorTable(BiomeKind kind) => _tables[kind];

  // ── Edge terrain ─────────────────────────────────────────────────────

  /// Terrain at the left/right edge of the map around [c], [r] its size.
  static void edge(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    bool left,
    math.Random rand,
  ) {
    final dir = left ? 1.0 : -1.0;
    switch (b.kind) {
      case BiomeKind.garden:
      case BiomeKind.monsoon:
      case BiomeKind.hedgeMaze:
        _hedgeWall(canvas, b, c, r, dir, rand);
      case BiomeKind.courtyard:
      case BiomeKind.citadel:
      case BiomeKind.royal:
        _palaceWall(canvas, b, c, r, dir, rand);
      case BiomeKind.lotusLake:
      case BiomeKind.harbor:
        _pond(canvas, b, c, r, dir, rand);
      case BiomeKind.valley:
      case BiomeKind.steppe:
      case BiomeKind.aurora:
      case BiomeKind.sunfield:
      case BiomeKind.twilight:
      case BiomeKind.fireflyForest:
        _rollingHills(canvas, b, c, r, dir, rand);
      case BiomeKind.bazaar:
        _stalls(canvas, b, c, r, dir, rand);
      case BiomeKind.mandalaHeights:
      case BiomeKind.temple:
      case BiomeKind.terraces:
      case BiomeKind.silkRoad:
        _stepped(canvas, b, c, r, dir, rand);
      case BiomeKind.reef:
        _reef(canvas, b, c, r, dir, rand);
      case BiomeKind.mirage:
        _dunes(canvas, b, c, r, dir);
      case BiomeKind.glacier:
      case BiomeKind.storm:
      case BiomeKind.obsidian:
      case BiomeKind.prism:
      case BiomeKind.grotto:
        _shards(canvas, b, c, r, dir, rand);
      case BiomeKind.arches:
        _hoodooCliff(canvas, b, c, r, dir, rand);
      case BiomeKind.comet:
        _craters(canvas, b, c, r, dir, rand);
      case BiomeKind.loom:
      case BiomeKind.pantheon:
        _colonnade(canvas, b, c, r, dir);
      case BiomeKind.windPass:
        _windPeaks(canvas, b, c, r, dir, rand);
      case BiomeKind.skyIsles:
        _cloudIsle(canvas, b, c, r, dir, rand);
      default:
        Map3D.hill(canvas, c, r * 2.2, r * 1.4, b.terrainNear);
    }
  }

  static void _hedgeWall(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    for (var i = 0; i < 3; i++) {
      final w = r * (0.9 - i * 0.12);
      final x = c.dx + dir * (i * r * 0.32) - w / 2;
      final y = c.dy - r * 0.55 + i * r * 0.4;
      final front = Rect.fromLTWH(x, y, w, r * 0.42);
      Map3D.shadow(canvas, front.bottomCenter.translate(0, 4), w * 1.1);
      Map3D.roundedBlock(
        canvas,
        front,
        r * 0.3,
        i.isEven ? b.terrainNear : b.terrainFar,
      );
      if (b.kind != BiomeKind.monsoon && rand.nextBool()) {
        final dot = Paint()..color = b.decorC;
        for (var k = 0; k < 4; k++) {
          canvas.drawCircle(
            Offset(x + w * (0.2 + k * 0.2), y - r * 0.06 + (k.isEven ? 0 : 3)),
            r * 0.028,
            dot,
          );
        }
      }
    }
    if (b.kind == BiomeKind.monsoon) {
      // Rain puddle at the foot of the hedges.
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(dir * r * 0.4, r * 0.62),
          width: r * 1.1,
          height: r * 0.22,
        ),
        Paint()..color = _a(b.water, 0.55),
      );
    }
  }

  static void _palaceWall(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    final w = r * 1.5;
    final front = Rect.fromLTWH(
      c.dx - w / 2 + dir * r * 0.1,
      c.dy - r * 0.45,
      w,
      r * 0.85,
    );
    Map3D.shadow(canvas, front.bottomCenter.translate(0, 6), w * 1.15);
    Map3D.block(
      canvas,
      front,
      r * 0.35,
      b.terrainNear,
      topColor: _t(b.terrainNear, 0.35),
    );
    // Crenellations.
    final merlon = r * 0.13;
    for (var x = front.left; x < front.right - merlon * 0.5; x += merlon * 2) {
      Map3D.block(
        canvas,
        Rect.fromLTWH(x, front.top - merlon, merlon, merlon),
        merlon * 0.8,
        b.terrainNear,
      );
    }
    // Arched windows / niches with an accent glow.
    final niche = Paint()..color = _s(b.terrainNear, 0.45);
    for (var i = 0; i < 2; i++) {
      final nx = front.left + w * (0.28 + i * 0.44);
      final rect = Rect.fromCenter(
        center: Offset(nx, front.center.dy + r * 0.05),
        width: r * 0.2,
        height: r * 0.34,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(r * 0.1),
          topRight: Radius.circular(r * 0.1),
        ),
        niche,
      );
      if (b.kind == BiomeKind.citadel) {
        Map3D.glow(canvas, rect.center, r * 0.22, b.decorB, strength: 0.4);
      }
    }
    if (b.kind == BiomeKind.citadel || b.kind == BiomeKind.courtyard) {
      // Chalk Kolam dots along the wall.
      final dot = Paint()..color = _a(b.decorA, 0.85);
      for (var x = front.left + 8; x < front.right - 4; x += 12) {
        canvas.drawCircle(Offset(x, front.bottom - 8), 1.8, dot);
      }
    }
    if (b.kind == BiomeKind.royal) {
      canvas.drawRect(
        Rect.fromLTWH(front.left, front.top + r * 0.08, w, r * 0.05),
        Paint()..color = b.decorB,
      );
    }
  }

  static void _pond(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    final rect = Rect.fromCenter(
      center: c.translate(dir * -r * 0.1, 0),
      width: r * 2.4,
      height: r * 1.5,
    );
    canvas.drawOval(rect.inflate(6), Paint()..color = _s(b.terrainNear, 0.05));
    canvas.drawOval(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center.translate(-r * 0.3, -r * 0.2),
          r * 1.4,
          [_t(b.water, 0.25), b.water, _s(b.water, 0.3)],
          [0, 0.55, 1],
        ),
    );
    final hi = Paint()
      ..color = _a(b.waterLight, 0.5)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = rect.top + rect.height * (0.3 + i * 0.2);
      final x = rect.center.dx + (rand.nextDouble() - 0.5) * r;
      canvas.drawLine(Offset(x - 12, y), Offset(x + 12, y), hi);
    }
    if (b.kind == BiomeKind.harbor) {
      // Wooden pier reaching into the water.
      final pier = Rect.fromLTWH(
        dir > 0 ? rect.right - r * 0.9 : rect.left + r * 0.1,
        rect.center.dy - r * 0.1,
        r * 0.8,
        r * 0.16,
      );
      Map3D.block(canvas, pier, r * 0.12, b.bridge);
      for (var i = 0; i < 3; i++) {
        Map3D.cylinder(
          canvas,
          Offset(pier.left + pier.width * (0.15 + i * 0.35), pier.bottom + 8),
          5,
          12,
          _s(b.bridge, 0.2),
        );
      }
    } else {
      for (var i = 0; i < 3; i++) {
        final p = Offset(
          rect.left + rect.width * (0.25 + i * 0.25),
          rect.center.dy + (i.isEven ? -r * 0.18 : r * 0.2),
        );
        _lotusPad(canvas, b, p, r / 45, i);
      }
    }
  }

  static void _rollingHills(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    Map3D.hill(
      canvas,
      c.translate(0, -r * 0.3),
      r * 2.3,
      r * 1.5,
      b.terrainFar,
    );
    Map3D.hill(
      canvas,
      c.translate(dir * -r * 0.2, r * 0.15),
      r * 1.9,
      r * 1.2,
      b.terrainNear,
    );
    for (var i = 0; i < 3; i++) {
      final p = c.translate(
        dir * (r * 0.1 + i * r * 0.3),
        -r * 0.62 + rand.nextDouble() * r * 0.3,
      );
      final s = r / 55;
      switch (b.kind) {
        case BiomeKind.steppe:
          if (i == 1) _yurt(canvas, b, p, s * 0.9);
        case BiomeKind.aurora:
          _snowTree(canvas, b, p, s);
        case BiomeKind.sunfield:
          _sunflower(canvas, b, p, s * 0.9, i);
        case BiomeKind.twilight:
          _lavender(canvas, b, p, s);
        case BiomeKind.fireflyForest:
          _glowTree(canvas, b, p, s);
        default:
          _sphereTree(canvas, b, p, s, i);
      }
    }
    if (b.kind == BiomeKind.aurora) {
      // Snow caps on the hills.
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, -r * 0.95),
          width: r * 1.1,
          height: r * 0.3,
        ),
        Paint()..color = _a(Colors.white, 0.85),
      );
    }
  }

  static void _stalls(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    for (var i = 0; i < 2; i++) {
      final w = r * 0.75;
      final x = c.dx + dir * i * r * 0.55 - w / 2;
      final front = Rect.fromLTWH(x, c.dy - r * 0.2 + i * r * 0.45, w, r * 0.5);
      Map3D.shadow(canvas, front.bottomCenter.translate(0, 4), w * 1.2);
      Map3D.block(canvas, front, r * 0.3, b.terrainNear);
      _awning(canvas, front, r * 0.18, i.isEven ? b.decorA : b.decorB);
      Map3D.glow(canvas, front.center, r * 0.35, b.decorC, strength: 0.3);
    }
    // String of lanterns.
    final a = c.translate(-r * 0.7, -r * 0.55);
    final z = c.translate(r * 0.7, -r * 0.45);
    final wire = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(c.dx, c.dy - r * 0.2, z.dx, z.dy);
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _a(Colors.white, 0.4),
    );
    for (final m in wire.computeMetrics()) {
      for (var d = 10.0; d < m.length; d += 22) {
        final p = m.getTangentForOffset(d)!.position;
        Map3D.glow(canvas, p, 9, b.decorA, strength: 0.5);
        canvas.drawCircle(
          p,
          3.2,
          Paint()..color = [b.decorA, b.decorB, b.decorC][(d ~/ 22) % 3],
        );
      }
    }
  }

  static void _awning(Canvas canvas, Rect front, double h, Color color) {
    final n = 5;
    final w = front.width / n;
    for (var i = 0; i < n; i++) {
      final rect = Rect.fromLTWH(front.left + i * w, front.top - h, w, h);
      canvas.drawPath(
        Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..quadraticBezierTo(
            rect.center.dx,
            rect.bottom + h * 0.5,
            rect.left,
            rect.bottom,
          )
          ..close(),
        Paint()..color = i.isEven ? color : Colors.white,
      );
    }
  }

  static void _stepped(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    for (var i = 0; i < 3; i++) {
      final w = r * (1.6 - i * 0.38);
      final h = r * 0.3;
      final front = Rect.fromLTWH(
        c.dx - w / 2 + dir * -r * 0.15,
        c.dy + r * 0.25 - (i + 1) * h,
        w,
        h,
      );
      final col = Color.lerp(b.terrainNear, b.terrainFar, i / 3)!;
      Map3D.block(
        canvas,
        front,
        r * 0.4,
        col,
        topColor: b.kind == BiomeKind.terraces
            ? _t(b.decorB, 0.1)
            : _t(col, 0.3),
      );
      if (b.kind == BiomeKind.terraces) {
        // Rice paddies: water strips on each terrace.
        canvas.drawRect(
          Rect.fromLTWH(front.left + 4, front.top - r * 0.12, w - 8, 3),
          Paint()..color = _a(b.waterLight, 0.6),
        );
      }
      if (b.kind == BiomeKind.temple && i == 0) {
        // Hanging vines.
        final vine = Paint()
          ..color = b.decorA
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k < 4; k++) {
          final x = front.left + w * (0.15 + k * 0.22);
          canvas.drawLine(
            Offset(x, front.top),
            Offset(x, front.top + h * (0.4 + rand.nextDouble() * 0.5)),
            vine,
          );
        }
      }
    }
    if (b.kind == BiomeKind.mandalaHeights) {
      final top = c.translate(dir * -r * 0.15, r * 0.25 - r * 0.9 - r * 0.18);
      _stupa(canvas, b, top, r / 60);
    }
    if (b.kind == BiomeKind.silkRoad) {
      final dust = Paint()..color = _a(Colors.white, 0.2);
      canvas.drawLine(
        c.translate(-r * 0.7, -r * 0.2),
        c.translate(r * 0.6, -r * 0.2),
        dust..strokeWidth = 3,
      );
    }
  }

  static void _reef(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    Map3D.hill(
      canvas,
      c.translate(0, r * 0.1),
      r * 2.0,
      r * 1.1,
      b.terrainNear,
    );
    for (var i = 0; i < 4; i++) {
      final p = c.translate(
        dir * (i * r * 0.25 - r * 0.1),
        -r * 0.3 + rand.nextDouble() * r * 0.3,
      );
      if (i.isEven) {
        _coral(canvas, b, p, r / 40, i);
      } else {
        _seaweed(canvas, b, p, r / 45, i);
      }
    }
  }

  static void _dunes(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
  ) {
    for (var i = 0; i < 3; i++) {
      final center = c.translate(dir * -i * r * 0.25, -r * 0.4 + i * r * 0.35);
      final rect = Rect.fromCenter(
        center: center,
        width: r * 2.2,
        height: r * 0.9,
      );
      final path = Path()
        ..moveTo(rect.left, rect.bottom)
        ..quadraticBezierTo(
          rect.left + rect.width * 0.35,
          rect.top - r * 0.1,
          rect.right,
          rect.bottom,
        )
        ..close();
      final col = Color.lerp(b.terrainFar, b.terrainNear, i / 2)!;
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topLeft,
            rect.bottomRight,
            [_t(col, 0.25), col, _s(col, 0.2)],
            [0, 0.5, 1],
          ),
      );
      // Sharp, sunlit crest line.
      canvas.drawPath(
        Path()
          ..moveTo(
            rect.left + rect.width * 0.1,
            rect.bottom - rect.height * 0.2,
          )
          ..quadraticBezierTo(
            rect.left + rect.width * 0.35,
            rect.top + rect.height * 0.15,
            rect.left + rect.width * 0.62,
            rect.top + rect.height * 0.45,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _a(Colors.white, 0.45),
      );
    }
  }

  static void _shards(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    final base = b.kind == BiomeKind.obsidian
        ? const Color(0xFF1F1A2E)
        : b.kind == BiomeKind.storm || b.kind == BiomeKind.grotto
        ? b.terrainNear
        : b.terrainFar;
    for (var i = 0; i < 4; i++) {
      final p = c.translate(
        dir * (i * r * 0.28 - r * 0.15),
        r * 0.45 - (i % 2) * r * 0.1,
      );
      final h = r * (1.4 - i * 0.22) * (0.8 + rand.nextDouble() * 0.3);
      final col = i.isEven ? base : _t(base, 0.12);
      Map3D.shard(canvas, p, r * 0.24, h, col, lean: dir * r * 0.05);
      if (b.kind == BiomeKind.obsidian ||
          b.kind == BiomeKind.grotto ||
          b.kind == BiomeKind.prism) {
        final rim = Paint()
          ..color = _a(i.isEven ? b.decorB : b.decorC, 0.8)
          ..strokeWidth = 2;
        canvas.drawLine(
          p.translate(-r * 0.17, -h * 0.62),
          p.translate(0, -h),
          rim,
        );
        if (b.kind != BiomeKind.prism) {
          Map3D.glow(
            canvas,
            p.translate(0, -h * 0.5),
            r * 0.4,
            b.decorB,
            strength: 0.25,
          );
        }
      }
      if (b.kind == BiomeKind.glacier) {
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - r * 0.12, p.dy - h * 0.8)
            ..lineTo(p.dx, p.dy - h)
            ..lineTo(p.dx + r * 0.14, p.dy - h * 0.78)
            ..close(),
          Paint()..color = Colors.white,
        );
      }
    }
    if (b.kind == BiomeKind.storm && rand.nextBool()) {
      _bolt(canvas, c.translate(dir * r * 0.2, -r * 1.2), r * 0.7, b.decorA);
    }
  }

  static void _bolt(Canvas canvas, Offset top, double h, Color color) {
    final p = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx - h * 0.18, top.dy + h * 0.45)
      ..lineTo(top.dx + h * 0.02, top.dy + h * 0.45)
      ..lineTo(top.dx - h * 0.12, top.dy + h)
      ..lineTo(top.dx + h * 0.22, top.dy + h * 0.35)
      ..lineTo(top.dx + h * 0.02, top.dy + h * 0.35)
      ..lineTo(top.dx + h * 0.14, top.dy)
      ..close();
    Map3D.glow(
      canvas,
      top.translate(0, h * 0.5),
      h * 0.6,
      color,
      strength: 0.35,
    );
    canvas.drawPath(p, Paint()..color = color);
  }

  static void _hoodooCliff(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    Map3D.hill(
      canvas,
      c.translate(0, r * 0.25),
      r * 2.1,
      r * 0.9,
      b.terrainFar,
    );
    for (var i = 0; i < 3; i++) {
      final p = c.translate(dir * (i * r * 0.32 - r * 0.1), r * 0.35);
      _hoodoo(canvas, b, p, r / 30 * (1 - i * 0.15));
    }
  }

  static void _craters(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    Map3D.hill(canvas, c, r * 2.2, r * 1.3, b.terrainNear);
    for (var i = 0; i < 3; i++) {
      final p = c.translate(
        dir * (i * r * 0.3 - r * 0.2),
        -r * 0.2 + i * r * 0.15,
      );
      final cr = r * (0.22 - i * 0.04);
      canvas.drawOval(
        Rect.fromCenter(center: p, width: cr * 2, height: cr),
        Paint()..color = _s(b.terrainNear, 0.35),
      );
      canvas.drawArc(
        Rect.fromCenter(center: p, width: cr * 2, height: cr),
        0,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _t(b.terrainNear, 0.3),
      );
    }
    Map3D.sphere(
      canvas,
      c.translate(dir * r * 0.4, -r * 0.9),
      r * 0.18,
      b.decorB,
    );
  }

  static void _colonnade(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
  ) {
    final base = Rect.fromLTWH(
      c.dx - r * 0.8,
      c.dy + r * 0.3,
      r * 1.6,
      r * 0.14,
    );
    Map3D.block(canvas, base, r * 0.3, b.terrainNear);
    for (var i = 0; i < 4; i++) {
      final x = base.left + r * 0.2 + i * r * 0.4;
      final col = b.kind == BiomeKind.loom ? const Color(0xFF3B4A8F) : b.decorA;
      Map3D.cylinder(canvas, Offset(x, base.top), r * 0.14, r * 0.85, col);
    }
    if (b.kind == BiomeKind.loom) {
      // Glowing threads strung between the posts.
      for (var k = 0; k < 4; k++) {
        canvas.drawLine(
          Offset(base.left + r * 0.2, base.top - r * (0.2 + k * 0.17)),
          Offset(base.left + r * 1.4, base.top - r * (0.28 + k * 0.15)),
          Paint()
            ..color = _a([b.decorA, b.decorB, b.decorC][k % 3], 0.85)
            ..strokeWidth = 1.6,
        );
      }
    } else {
      Map3D.block(
        canvas,
        Rect.fromLTWH(
          base.left - 4,
          base.top - r * 0.95,
          r * 1.6 + 8,
          r * 0.12,
        ),
        r * 0.3,
        b.decorA,
      );
    }
  }

  static void _windPeaks(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    for (var i = 0; i < 2; i++) {
      Map3D.cone(
        canvas,
        c.translate(dir * i * r * 0.55, r * 0.4),
        r * (0.75 - i * 0.12),
        r * (1.4 - i * 0.35),
        i == 0 ? b.terrainFar : b.terrainNear,
      );
    }
    final swirl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..color = _a(Colors.white, 0.7);
    for (var i = 0; i < 2; i++) {
      final y = c.dy - r * (0.3 + i * 0.35);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - r * 0.8, y)
          ..cubicTo(
            c.dx - r * 0.2,
            y - r * 0.2,
            c.dx + r * 0.2,
            y + r * 0.15,
            c.dx + r * 0.5,
            y - r * 0.05,
          )
          ..arcToPoint(
            Offset(c.dx + r * 0.42, y - r * 0.2),
            radius: Radius.circular(r * 0.1),
          ),
        swirl,
      );
    }
  }

  static void _cloudIsle(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    double dir,
    math.Random rand,
  ) {
    // Floating rock underside.
    final under = Path()
      ..moveTo(c.dx - r * 0.8, c.dy)
      ..lineTo(c.dx + r * 0.8, c.dy)
      ..lineTo(c.dx + r * 0.2, c.dy + r * 0.75)
      ..lineTo(c.dx - r * 0.25, c.dy + r * 0.55)
      ..close();
    canvas.drawPath(
      under,
      Paint()
        ..shader = ui.Gradient.linear(c, c.translate(0, r * 0.7), [
          const Color(0xFFB08A6A),
          const Color(0xFF7A5A44),
        ]),
    );
    Map3D.roundedBlock(
      canvas,
      Rect.fromCenter(
        center: c.translate(0, -r * 0.05),
        width: r * 1.7,
        height: r * 0.25,
      ),
      r * 0.3,
      b.decorA,
    );
    for (var i = 0; i < 4; i++) {
      Map3D.sphere(
        canvas,
        c.translate(
          dir * (i * r * 0.32 - r * 0.6),
          -r * 0.65 + (i % 2) * r * 0.1,
        ),
        r * 0.22,
        Colors.white,
        gloss: 0.2,
      );
    }
  }

  // ── Landmarks ────────────────────────────────────────────────────────

  /// Signature landmark of the region (variant 0) or its companion piece.
  static void landmark(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    int variant,
    bool flip,
  ) {
    Map3D.shadow(
      canvas,
      c.translate(0, s * 0.42),
      s * 1.0,
      opacity: b.dark ? 0.35 : 0.22,
    );
    final base = c.translate(0, s * 0.4);
    final v = variant.isEven;
    switch (b.kind) {
      case BiomeKind.garden:
        v ? _spiralTopiary(canvas, b, base, s) : _gazebo(canvas, b, base, s);
      case BiomeKind.courtyard:
        v ? _chhatri(canvas, b, base, s) : _rangoliMedallion(canvas, b, c, s);
      case BiomeKind.lotusLake:
        v ? _giantLotus(canvas, b, base, s) : _ghat(canvas, b, base, s);
      case BiomeKind.valley:
        v ? _peacockFan(canvas, b, base, s) : _banyan(canvas, b, base, s);
      case BiomeKind.monsoon:
        v ? _mazeCube(canvas, b, base, s) : _bigUmbrella(canvas, b, base, s);
      case BiomeKind.bazaar:
        v ? _lanternArch(canvas, b, base, s) : _marketTent(canvas, b, base, s);
      case BiomeKind.mandalaHeights:
        v ? _stupa(canvas, b, base, s / 45) : _mandalaDisc(canvas, b, base, s);
      case BiomeKind.reef:
        v ? _coral(canvas, b, base, s / 22, 0) : _treasure(canvas, b, base, s);
      case BiomeKind.mirage:
        v ? _oasis(canvas, b, base, s) : _caravanTent(canvas, b, base, s);
      case BiomeKind.steppe:
        v ? _yurt(canvas, b, base, s / 26) : _stoneCircle(canvas, b, base, s);
      case BiomeKind.temple:
        v ? _ziggurat(canvas, b, base, s) : _idolHead(canvas, b, base, s);
      case BiomeKind.glacier:
        v ? _iceArch(canvas, b, base, s) : _igloo(canvas, b, base, s / 26);
      case BiomeKind.storm:
        v ? _stormTower(canvas, b, base, s) : _stormCloud(canvas, b, c, s);
      case BiomeKind.silkRoad:
        v ? _pagoda(canvas, b, base, s) : _toriiGate(canvas, b, base, s);
      case BiomeKind.terraces:
        v ? _stiltHut(canvas, b, base, s) : _waterfall(canvas, b, base, s);
      case BiomeKind.fireflyForest:
        v
            ? _glowTree(canvas, b, base, s / 22)
            : _shroomRing(canvas, b, base, s);
      case BiomeKind.citadel:
        v ? _gopuram(canvas, b, base, s) : _rangoliMedallion(canvas, b, c, s);
      case BiomeKind.aurora:
        v ? _cabin(canvas, b, base, s) : _snowman(canvas, b, base, s);
      case BiomeKind.arches:
        v
            ? _naturalArch(canvas, b, base, s)
            : _balancedRock(canvas, b, base, s);
      case BiomeKind.harbor:
        v ? _lighthouse(canvas, b, base, s) : _boat(canvas, b, base, s / 18);
      case BiomeKind.grotto:
        v ? _geode(canvas, b, base, s) : _stalagmites(canvas, b, base, s);
      case BiomeKind.sunfield:
        v
            ? _windmill(canvas, b, base, s)
            : _sunflower(canvas, b, base, s / 16, 0);
      case BiomeKind.windPass:
        v ? _turbine(canvas, b, base, s) : _tornado(canvas, b, base, s);
      case BiomeKind.hedgeMaze:
        v ? _fountain(canvas, b, base, s / 22) : _mazeCube(canvas, b, base, s);
      case BiomeKind.comet:
        v ? _observatory(canvas, b, base, s) : _cometRock(canvas, b, c, s);
      case BiomeKind.twilight:
        v ? _gazebo(canvas, b, base, s) : _lanternTree(canvas, b, base, s);
      case BiomeKind.obsidian:
        v
            ? _obsidianSpire(canvas, b, base, s)
            : _shardCluster(canvas, b, base, s);
      case BiomeKind.loom:
        v ? _loomFrame(canvas, b, base, s) : _spindle(canvas, b, base, s);
      case BiomeKind.prism:
        v ? _floatingPrism(canvas, b, c, s) : _rainbowArch(canvas, b, base, s);
      case BiomeKind.royal:
        v ? _grandGate(canvas, b, base, s) : _statue(canvas, b, base, s);
      case BiomeKind.pantheon:
        v ? _greekTemple(canvas, b, base, s) : _arrowStatue(canvas, b, base, s);
      case BiomeKind.skyIsles:
        v ? _floatingIsland(canvas, b, c, s) : _balloon(canvas, b, c, s);
      default:
        _sphereTree(canvas, b, base, s / 22, 0);
    }
  }

  static void _spiralTopiary(Canvas canvas, MapBiome b, Offset base, double s) {
    _planter(canvas, b, base, s * 0.32);
    for (var i = 0; i < 5; i++) {
      final r = s * (0.17 - i * 0.022);
      final y = base.dy - s * 0.2 - i * s * 0.17;
      final x = base.dx + math.sin(i * 1.3) * s * 0.06;
      Map3D.sphere(
        canvas,
        Offset(x, y),
        r,
        i.isEven ? b.decorA : _t(b.decorA, 0.12),
      );
    }
    Map3D.sphere(canvas, base.translate(0, -s * 1.02), s * 0.04, b.decorC);
  }

  static void _planter(Canvas canvas, MapBiome b, Offset base, double w) {
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(0, -w * 0.25),
        width: w,
        height: w * 0.5,
      ),
      w * 0.4,
      const Color(0xFFC77D4A),
    );
  }

  static void _gazebo(Canvas canvas, MapBiome b, Offset base, double s) {
    final floor = Rect.fromCenter(
      center: base.translate(0, -s * 0.04),
      width: s * 0.9,
      height: s * 0.1,
    );
    Map3D.block(canvas, floor, s * 0.3, const Color(0xFFE7E5E4));
    for (final dx in [-0.36, -0.12, 0.12, 0.36]) {
      Map3D.cylinder(
        canvas,
        Offset(base.dx + s * dx, floor.top),
        s * 0.05,
        s * 0.48,
        Colors.white,
      );
    }
    Map3D.cone(
      canvas,
      Offset(base.dx, floor.top - s * 0.46),
      s * 0.52,
      s * 0.38,
      b.accent,
    );
    Map3D.sphere(
      canvas,
      Offset(base.dx, floor.top - s * 0.86),
      s * 0.035,
      b.decorC,
    );
    if (b.kind == BiomeKind.twilight) {
      for (final dx in [-0.36, 0.36]) {
        Map3D.glow(
          canvas,
          Offset(base.dx + s * dx, floor.top - s * 0.5),
          s * 0.18,
          b.decorC,
        );
      }
    }
  }

  static void _chhatri(Canvas canvas, MapBiome b, Offset base, double s) {
    final plinth = Rect.fromCenter(
      center: base.translate(0, -s * 0.07),
      width: s * 0.9,
      height: s * 0.16,
    );
    Map3D.block(canvas, plinth, s * 0.3, b.terrainNear);
    for (final dx in [-0.32, 0.32]) {
      Map3D.cylinder(
        canvas,
        Offset(base.dx + s * dx, plinth.top),
        s * 0.07,
        s * 0.42,
        _t(b.terrainNear, 0.2),
      );
    }
    final roof = Rect.fromCenter(
      center: Offset(base.dx, plinth.top - s * 0.45),
      width: s * 0.86,
      height: s * 0.08,
    );
    Map3D.block(canvas, roof, s * 0.25, b.terrainNear);
    Map3D.dome(
      canvas,
      Offset(base.dx, roof.top),
      s * 0.3,
      _t(b.terrainNear, 0.25),
    );
    Map3D.cylinder(
      canvas,
      Offset(base.dx, roof.top - s * 0.3),
      s * 0.03,
      s * 0.12,
      b.decorB,
    );
    Map3D.sphere(
      canvas,
      Offset(base.dx, roof.top - s * 0.44),
      s * 0.035,
      b.decorB,
    );
  }

  static void _rangoliMedallion(Canvas canvas, MapBiome b, Offset c, double s) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 0.55);
    final colors = [b.decorA, b.decorB, b.decorC, Colors.white];
    for (var ring = 3; ring >= 0; ring--) {
      final r = s * (0.18 + ring * 0.09);
      final petals = 8 + ring * 4;
      final p = Paint()..color = colors[ring % colors.length];
      for (var i = 0; i < petals; i++) {
        final a = i * 2 * math.pi / petals;
        canvas.save();
        canvas.rotate(a);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(r, 0),
            width: s * 0.13,
            height: s * 0.06,
          ),
          p,
        );
        canvas.restore();
      }
    }
    Map3D.sphere(canvas, Offset.zero, s * 0.12, b.decorB);
    final dot = Paint()..color = Colors.white;
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      canvas.drawCircle(
        Offset(math.cos(a), math.sin(a)) * s * 0.52,
        s * 0.018,
        dot,
      );
    }
    canvas.restore();
  }

  static void _giantLotus(Canvas canvas, MapBiome b, Offset base, double s) {
    canvas.drawOval(
      Rect.fromCenter(center: base, width: s * 1.0, height: s * 0.3),
      Paint()..color = b.decorA,
    );
    for (final (a, len) in [
      (-1.2, 0.42),
      (1.2, 0.42),
      (-0.6, 0.5),
      (0.6, 0.5),
      (0.0, 0.56),
    ]) {
      canvas.save();
      canvas.translate(base.dx, base.dy - s * 0.06);
      canvas.rotate(a);
      final rect = Rect.fromCenter(
        center: Offset(0, -s * len * 0.5),
        width: s * 0.22,
        height: s * len,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.bottomCenter,
            rect.topCenter,
            [Colors.white, b.decorB, _s(b.decorB, 0.15)],
            [0, 0.6, 1],
          ),
      );
      canvas.restore();
    }
    Map3D.sphere(canvas, base.translate(0, -s * 0.12), s * 0.07, b.decorC);
  }

  static void _ghat(Canvas canvas, MapBiome b, Offset base, double s) {
    for (var i = 0; i < 4; i++) {
      final w = s * (0.95 - i * 0.18);
      Map3D.block(
        canvas,
        Rect.fromCenter(
          center: base.translate(0, -s * (0.05 + i * 0.1)),
          width: w,
          height: s * 0.1,
        ),
        s * 0.25,
        const Color(0xFFE7D7C1),
      );
    }
    final top = base.translate(0, -s * 0.45);
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: top.translate(0, -s * 0.12),
        width: s * 0.26,
        height: s * 0.24,
      ),
      s * 0.15,
      const Color(0xFFF1E4CF),
    );
    Map3D.cone(
      canvas,
      top.translate(0, -s * 0.24),
      s * 0.16,
      s * 0.28,
      b.decorB,
    );
    Map3D.glow(canvas, top.translate(0, -s * 0.12), s * 0.2, b.decorC);
  }

  static void _peacockFan(Canvas canvas, MapBiome b, Offset base, double s) {
    final hub = base.translate(0, -s * 0.18);
    for (var i = 0; i < 11; i++) {
      final a = math.pi + 0.15 + i * (math.pi - 0.3) / 10;
      final tip = hub + Offset(math.cos(a), math.sin(a)) * s * 0.55;
      canvas.drawLine(
        hub,
        tip,
        Paint()
          ..color = _s(b.decorA, 0.2)
          ..strokeWidth = s * 0.02,
      );
      Map3D.sphere(canvas, tip, s * 0.075, b.decorA, gloss: 0.3);
      canvas.drawCircle(tip, s * 0.045, Paint()..color = b.decorB);
      canvas.drawCircle(tip, s * 0.02, Paint()..color = b.decorC);
    }
    Map3D.sphere(canvas, hub, s * 0.12, b.decorB);
    Map3D.sphere(canvas, hub.translate(0, -s * 0.16), s * 0.06, b.decorB);
  }

  static void _banyan(Canvas canvas, MapBiome b, Offset base, double s) {
    final bark = const Color(0xFF7A5A3C);
    Map3D.cylinder(canvas, base, s * 0.16, s * 0.45, bark);
    for (final dx in [-0.34, -0.2, 0.22, 0.36]) {
      canvas.drawLine(
        base.translate(s * dx, -s * 0.38),
        base.translate(s * dx, 0),
        Paint()
          ..color = _s(bark, 0.1)
          ..strokeWidth = s * 0.025,
      );
    }
    for (final (dx, dy, r) in [
      (-0.3, -0.45, 0.24),
      (0.3, -0.45, 0.24),
      (0.0, -0.62, 0.3),
    ]) {
      Map3D.sphere(canvas, base.translate(s * dx, s * dy), s * r, b.decorA);
    }
  }

  static void _mazeCube(Canvas canvas, MapBiome b, Offset base, double s) {
    final front = Rect.fromCenter(
      center: base.translate(0, -s * 0.2),
      width: s * 0.8,
      height: s * 0.4,
    );
    Map3D.block(
      canvas,
      front,
      s * 0.55,
      b.decorA,
      topColor: _t(b.decorA, 0.25),
    );
    // Maze corridors carved in the top face.
    final dx = s * 0.55 * 0.45, dy = s * 0.55 * 0.55;
    final groove = Paint()
      ..color = _s(b.decorA, 0.35)
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.square;
    Offset top(double u, double v) =>
        Offset(front.left + u * front.width + v * dx, front.top - v * dy);
    for (final (u0, v0, u1, v1) in [
      (0.15, 0.25, 0.7, 0.25),
      (0.7, 0.25, 0.7, 0.75),
      (0.3, 0.5, 0.55, 0.5),
      (0.3, 0.5, 0.3, 0.85),
      (0.85, 0.5, 0.85, 0.9),
      (0.45, 0.75, 0.6, 0.75),
    ]) {
      canvas.drawLine(top(u0, v0), top(u1, v1), groove);
    }
  }

  static void _bigUmbrella(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.cylinder(canvas, base, s * 0.03, s * 0.62, const Color(0xFF64748B));
    final top = base.translate(0, -s * 0.62);
    final rect = Rect.fromCenter(center: top, width: s * 0.95, height: s * 0.6);
    for (var i = 0; i < 6; i++) {
      canvas.drawArc(
        rect,
        math.pi + i * math.pi / 6,
        math.pi / 6,
        true,
        Paint()..color = i.isEven ? b.decorC : _s(b.decorC, 0.2),
      );
    }
    final drop = Paint()
      ..color = _a(b.particleColor, 0.8)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 6; i++) {
      final x = rect.left + rect.width * (i / 5);
      canvas.drawLine(
        Offset(x, top.dy + s * 0.05),
        Offset(x - 3, top.dy + s * 0.15),
        drop,
      );
    }
  }

  static void _lanternArch(Canvas canvas, MapBiome b, Offset base, double s) {
    for (final dx in [-0.38, 0.38]) {
      Map3D.cylinder(
        canvas,
        base.translate(s * dx, 0),
        s * 0.08,
        s * 0.7,
        b.decorB,
      );
    }
    final beam = Rect.fromCenter(
      center: base.translate(0, -s * 0.74),
      width: s * 1.0,
      height: s * 0.09,
    );
    Map3D.block(canvas, beam, s * 0.15, b.decorB);
    canvas.drawPath(
      Path()
        ..moveTo(beam.left - s * 0.06, beam.top)
        ..quadraticBezierTo(
          base.dx,
          beam.top - s * 0.18,
          beam.right + s * 0.06,
          beam.top,
        )
        ..close(),
      Paint()..color = _s(b.decorB, 0.2),
    );
    for (final dx in [-0.22, 0.0, 0.22]) {
      final p = Offset(base.dx + s * dx, beam.bottom + s * 0.14);
      canvas.drawLine(
        Offset(p.dx, beam.bottom),
        p,
        Paint()..color = Colors.white54,
      );
      _paperLantern(canvas, b, p, s * 0.08, b.decorA);
    }
  }

  static void _paperLantern(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double r,
    Color col,
  ) {
    Map3D.glow(canvas, c, r * 2.6, col, strength: 0.45);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2, height: r * 2.4),
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 1.3,
          [_t(col, 0.55), col, _s(col, 0.25)],
          [0, 0.5, 1],
        ),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: c.translate(0, -r * 1.2),
        width: r * 0.9,
        height: r * 0.25,
      ),
      Paint()..color = const Color(0xFF3F2A1E),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: c.translate(0, r * 1.2),
        width: r * 0.9,
        height: r * 0.25,
      ),
      Paint()..color = const Color(0xFF3F2A1E),
    );
  }

  static void _marketTent(Canvas canvas, MapBiome b, Offset base, double s) {
    final front = Rect.fromCenter(
      center: base.translate(0, -s * 0.2),
      width: s * 0.8,
      height: s * 0.4,
    );
    Map3D.block(canvas, front, s * 0.3, const Color(0xFF6B3F2A));
    _awning(canvas, front, s * 0.18, b.decorB);
    Map3D.glow(canvas, front.center, s * 0.4, b.decorC, strength: 0.35);
    for (var i = 0; i < 4; i++) {
      Map3D.sphere(
        canvas,
        Offset(
          front.left + front.width * (0.2 + i * 0.2),
          front.bottom - s * 0.08,
        ),
        s * 0.05,
        [b.decorA, b.decorC, const Color(0xFF84CC16), b.decorB][i],
      );
    }
  }

  static void _stupa(Canvas canvas, MapBiome b, Offset base, double u) {
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(0, -5 * u),
        width: 46 * u,
        height: 10 * u,
      ),
      14 * u,
      const Color(0xFFF5F0E6),
    );
    Map3D.dome(
      canvas,
      base.translate(0, -10 * u),
      18 * u,
      const Color(0xFFFAF7F2),
    );
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(0, -30 * u),
        width: 10 * u,
        height: 6 * u,
      ),
      6 * u,
      b.decorA,
    );
    Map3D.cone(canvas, base.translate(0, -33 * u), 5 * u, 22 * u, b.decorA);
    Map3D.sphere(canvas, base.translate(0, -56 * u), 2.5 * u, b.decorA);
  }

  static void _mandalaDisc(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.cylinder(canvas, base, s * 0.06, s * 0.3, const Color(0xFF8B6B4A));
    final c = base.translate(0, -s * 0.62);
    Map3D.sphere(canvas, c, s * 0.34, b.decorB, gloss: 0.3);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025;
    for (var i = 1; i <= 3; i++) {
      ring.color = [b.decorA, b.decorC, Colors.white][i - 1];
      canvas.drawCircle(c, s * 0.08 * i, ring);
    }
    final petal = Paint()..color = b.decorA;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * s * 0.29,
        s * 0.03,
        petal,
      );
    }
  }

  static void _treasure(Canvas canvas, MapBiome b, Offset base, double s) {
    final chest = Rect.fromCenter(
      center: base.translate(0, -s * 0.14),
      width: s * 0.55,
      height: s * 0.28,
    );
    Map3D.block(canvas, chest, s * 0.3, const Color(0xFF8B5A2B));
    Map3D.glow(
      canvas,
      chest.topCenter,
      s * 0.45,
      const Color(0xFFFDE047),
      strength: 0.5,
    );
    for (var i = 0; i < 5; i++) {
      Map3D.sphere(
        canvas,
        Offset(
          chest.left + chest.width * (0.15 + i * 0.18),
          chest.top - s * 0.04,
        ),
        s * 0.05,
        const Color(0xFFFBBF24),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        chest.left,
        chest.top + chest.height * 0.35,
        chest.width,
        s * 0.04,
      ),
      Paint()..color = const Color(0xFFD4AF37),
    );
  }

  static void _oasis(Canvas canvas, MapBiome b, Offset base, double s) {
    final pool = Rect.fromCenter(
      center: base.translate(0, -s * 0.05),
      width: s * 0.9,
      height: s * 0.3,
    );
    canvas.drawOval(pool.inflate(4), Paint()..color = _s(b.terrainNear, 0.05));
    canvas.drawOval(
      pool,
      Paint()
        ..shader = ui.Gradient.radial(pool.center, s * 0.45, [
          b.waterLight,
          b.water,
        ]),
    );
    _palm(canvas, b, base.translate(-s * 0.32, -s * 0.12), s / 26, false);
    _palm(canvas, b, base.translate(s * 0.3, -s * 0.18), s / 30, true);
  }

  static void _caravanTent(Canvas canvas, MapBiome b, Offset base, double s) {
    final p = Path()
      ..moveTo(base.dx - s * 0.48, base.dy)
      ..quadraticBezierTo(
        base.dx - s * 0.2,
        base.dy - s * 0.25,
        base.dx,
        base.dy - s * 0.55,
      )
      ..quadraticBezierTo(
        base.dx + s * 0.2,
        base.dy - s * 0.25,
        base.dx + s * 0.48,
        base.dy,
      )
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = ui.Gradient.linear(
          base.translate(-s * 0.5, 0),
          base.translate(s * 0.5, 0),
          [_t(b.decorB, 0.3), b.decorB, _s(b.decorB, 0.35)],
          [0, 0.5, 1],
        ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - s * 0.08, base.dy)
        ..lineTo(base.dx, base.dy - s * 0.22)
        ..lineTo(base.dx + s * 0.08, base.dy)
        ..close(),
      Paint()..color = const Color(0xFF3B2416),
    );
    canvas.drawLine(
      base.translate(0, -s * 0.55),
      base.translate(0, -s * 0.72),
      Paint()
        ..color = const Color(0xFF6B4A2B)
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy - s * 0.72)
        ..lineTo(base.dx + s * 0.16, base.dy - s * 0.67)
        ..lineTo(base.dx, base.dy - s * 0.62)
        ..close(),
      Paint()..color = b.accent,
    );
  }

  static void _stoneCircle(Canvas canvas, MapBiome b, Offset base, double s) {
    for (var i = 0; i < 7; i++) {
      final a = math.pi + i * math.pi / 6;
      final p = base.translate(
        math.cos(a) * s * 0.42,
        math.sin(a) * s * 0.16 - s * 0.05,
      );
      _monolith(
        canvas,
        p,
        s * 0.07,
        s * (0.24 + (i % 3) * 0.05),
        const Color(0xFF8D93A6),
      );
    }
    Map3D.glow(
      canvas,
      base.translate(0, -s * 0.15),
      s * 0.3,
      b.accent,
      strength: 0.3,
    );
  }

  static void _monolith(
    Canvas canvas,
    Offset base,
    double w,
    double h,
    Color c,
  ) {
    Map3D.block(
      canvas,
      Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h),
      w * 0.7,
      c,
      radius: 0,
    );
  }

  static void _ziggurat(Canvas canvas, MapBiome b, Offset base, double s) {
    const stone = Color(0xFFA8A27A);
    for (var i = 0; i < 4; i++) {
      final w = s * (1.0 - i * 0.2);
      Map3D.block(
        canvas,
        Rect.fromCenter(
          center: base.translate(0, -s * (0.07 + i * 0.14)),
          width: w,
          height: s * 0.14,
        ),
        s * 0.35,
        Color.lerp(stone, const Color(0xFF8C8660), i / 4)!,
      );
    }
    final shrine = Rect.fromCenter(
      center: base.translate(0, -s * 0.68),
      width: s * 0.22,
      height: s * 0.16,
    );
    Map3D.block(canvas, shrine, s * 0.15, _s(stone, 0.1));
    canvas.drawRect(
      Rect.fromCenter(
        center: shrine.center.translate(0, s * 0.02),
        width: s * 0.07,
        height: s * 0.1,
      ),
      Paint()..color = const Color(0xFF2E2A1E),
    );
    // Central stairway.
    canvas.drawRect(
      Rect.fromLTWH(base.dx - s * 0.06, base.dy - s * 0.6, s * 0.12, s * 0.6),
      Paint()..color = _a(Colors.white, 0.2),
    );
    final vine = Paint()
      ..color = b.decorA
      ..strokeWidth = 2;
    canvas.drawLine(
      base.translate(-s * 0.4, -s * 0.14),
      base.translate(-s * 0.36, -s * 0.02),
      vine,
    );
    canvas.drawLine(
      base.translate(s * 0.3, -s * 0.42),
      base.translate(s * 0.28, -s * 0.3),
      vine,
    );
  }

  static void _idolHead(Canvas canvas, MapBiome b, Offset base, double s) {
    const stone = Color(0xFF9CA38A);
    final face = Rect.fromCenter(
      center: base.translate(0, -s * 0.32),
      width: s * 0.5,
      height: s * 0.6,
    );
    Map3D.block(canvas, face, s * 0.25, stone, radius: s * 0.1);
    final dark = Paint()..color = _s(stone, 0.45);
    canvas.drawRect(
      Rect.fromCenter(
        center: face.center.translate(-s * 0.1, -s * 0.08),
        width: s * 0.1,
        height: s * 0.05,
      ),
      dark,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: face.center.translate(s * 0.1, -s * 0.08),
        width: s * 0.1,
        height: s * 0.05,
      ),
      dark,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: face.center.translate(0, s * 0.14),
        width: s * 0.22,
        height: s * 0.05,
      ),
      dark,
    );
    final moss = Paint()..color = _a(b.decorA, 0.85);
    canvas.drawOval(
      Rect.fromCenter(
        center: face.topCenter.translate(0, s * 0.02),
        width: s * 0.45,
        height: s * 0.1,
      ),
      moss,
    );
  }

  static void _iceArch(Canvas canvas, MapBiome b, Offset base, double s) {
    final outer = Rect.fromCenter(
      center: base,
      width: s * 1.0,
      height: s * 1.4,
    );
    final path = Path()
      ..addArc(outer, math.pi, math.pi)
      ..arcTo(
        Rect.fromCenter(center: base, width: s * 0.55, height: s * 0.9),
        0,
        -math.pi,
        false,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          outer.topLeft,
          outer.bottomRight,
          [Colors.white, b.decorA, b.decorC],
          [0, 0.5, 1],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _a(Colors.white, 0.8),
    );
  }

  static void _igloo(Canvas canvas, MapBiome b, Offset base, double u) {
    Map3D.dome(canvas, base, 18 * u, const Color(0xFFF1F7FC));
    final line = Paint()
      ..color = _a(const Color(0xFF9CB8D0), 0.7)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = base.dy - i * 4.5 * u;
      final hw = math.sqrt(math.max(0, 324 - math.pow(i * 4.5, 2))) * u;
      canvas.drawLine(Offset(base.dx - hw, y), Offset(base.dx + hw, y), line);
    }
    canvas.drawArc(
      Rect.fromCenter(
        center: base.translate(9 * u, 0),
        width: 11 * u,
        height: 14 * u,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF3A5068),
    );
  }

  static void _stormTower(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.cylinder(canvas, base, s * 0.24, s * 0.62, const Color(0xFF64748B));
    Map3D.cone(
      canvas,
      base.translate(0, -s * 0.62),
      s * 0.18,
      s * 0.22,
      const Color(0xFF475569),
    );
    canvas.drawLine(
      base.translate(0, -s * 0.84),
      base.translate(0, -s * 1.02),
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..strokeWidth = 2,
    );
    _bolt(canvas, base.translate(s * 0.08, -s * 1.3), s * 0.38, b.decorA);
    Map3D.glow(
      canvas,
      base.translate(0, -s * 0.4),
      s * 0.12,
      b.decorA,
      strength: 0.6,
    );
  }

  static void _stormCloud(Canvas canvas, MapBiome b, Offset c, double s) {
    for (final (dx, dy, r) in [
      (-0.22, 0.0, 0.2),
      (0.0, -0.08, 0.26),
      (0.24, 0.0, 0.2),
    ]) {
      Map3D.sphere(
        canvas,
        c.translate(s * dx, s * dy - s * 0.2),
        s * r,
        const Color(0xFF6B7280),
        gloss: 0.1,
      );
    }
    _bolt(canvas, c.translate(0, -s * 0.05), s * 0.42, b.decorA);
  }

  static void _pagoda(Canvas canvas, MapBiome b, Offset base, double s) {
    var y = base.dy;
    for (var i = 0; i < 3; i++) {
      final w = s * (0.56 - i * 0.12);
      final h = s * 0.16;
      final body = Rect.fromLTWH(base.dx - w / 2, y - h, w, h);
      Map3D.block(canvas, body, s * 0.18, b.decorA);
      final roofW = w + s * 0.24;
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - roofW / 2, y - h)
          ..quadraticBezierTo(
            base.dx - roofW * 0.3,
            y - h - s * 0.04,
            base.dx - w * 0.3,
            y - h - s * 0.1,
          )
          ..lineTo(base.dx + w * 0.3, y - h - s * 0.1)
          ..quadraticBezierTo(
            base.dx + roofW * 0.3,
            y - h - s * 0.04,
            base.dx + roofW / 2,
            y - h,
          )
          ..close(),
        Paint()..color = const Color(0xFF3F3F46),
      );
      y -= h + s * 0.1;
    }
    Map3D.cylinder(canvas, Offset(base.dx, y), s * 0.03, s * 0.14, b.decorB);
  }

  static void _toriiGate(Canvas canvas, MapBiome b, Offset base, double s) {
    for (final dx in [-0.32, 0.32]) {
      Map3D.cylinder(
        canvas,
        base.translate(s * dx, 0),
        s * 0.07,
        s * 0.6,
        b.decorA,
      );
    }
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(0, -s * 0.48),
        width: s * 0.78,
        height: s * 0.05,
      ),
      s * 0.08,
      b.decorA,
    );
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - s * 0.5, base.dy - s * 0.6)
        ..quadraticBezierTo(
          base.dx,
          base.dy - s * 0.66,
          base.dx + s * 0.5,
          base.dy - s * 0.6,
        )
        ..lineTo(base.dx + s * 0.46, base.dy - s * 0.68)
        ..quadraticBezierTo(
          base.dx,
          base.dy - s * 0.76,
          base.dx - s * 0.46,
          base.dy - s * 0.68,
        )
        ..close(),
      Paint()..color = const Color(0xFF27272A),
    );
  }

  static void _stiltHut(Canvas canvas, MapBiome b, Offset base, double s) {
    for (final dx in [-0.26, 0.26]) {
      Map3D.cylinder(
        canvas,
        base.translate(s * dx, 0),
        s * 0.05,
        s * 0.28,
        const Color(0xFF8C6A44),
      );
    }
    final hut = Rect.fromCenter(
      center: base.translate(0, -s * 0.42),
      width: s * 0.62,
      height: s * 0.28,
    );
    Map3D.block(canvas, hut, s * 0.28, const Color(0xFFB98B5A));
    canvas.drawPath(
      Path()
        ..moveTo(hut.left - s * 0.12, hut.top)
        ..lineTo(hut.center.dx + s * 0.06, hut.top - s * 0.34)
        ..lineTo(hut.right + s * 0.24, hut.top - s * 0.06)
        ..close(),
      Paint()..color = const Color(0xFFD9B26F),
    );
    for (var i = 0; i < 2; i++) {
      _bamboo(canvas, b, base.translate(s * (0.5 + i * 0.1), 0), s / 30, i);
    }
  }

  static void _waterfall(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(-s * 0.1, -s * 0.35),
        width: s * 0.7,
        height: s * 0.7,
      ),
      s * 0.3,
      b.terrainNear,
      topColor: b.decorB,
    );
    final fall = Rect.fromLTWH(
      base.dx - s * 0.2,
      base.dy - s * 0.7,
      s * 0.2,
      s * 0.72,
    );
    canvas.drawRect(
      fall,
      Paint()
        ..shader = ui.Gradient.linear(fall.topCenter, fall.bottomCenter, [
          b.waterLight,
          b.water,
        ]),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(-s * 0.1, 0),
        width: s * 0.6,
        height: s * 0.14,
      ),
      Paint()..color = _a(Colors.white, 0.7),
    );
  }

  static void _shroomRing(Canvas canvas, MapBiome b, Offset base, double s) {
    for (var i = 0; i < 6; i++) {
      final a = math.pi + i * math.pi / 5;
      _glowShroom(
        canvas,
        b,
        base.translate(
          math.cos(a) * s * 0.4,
          math.sin(a) * s * 0.12 - s * 0.04,
        ),
        s / 30,
        i,
      );
    }
    Map3D.glow(
      canvas,
      base.translate(0, -s * 0.12),
      s * 0.4,
      b.decorB,
      strength: 0.3,
    );
  }

  static void _gopuram(Canvas canvas, MapBiome b, Offset base, double s) {
    for (var i = 0; i < 5; i++) {
      final w = s * (0.7 - i * 0.11);
      Map3D.block(
        canvas,
        Rect.fromCenter(
          center: base.translate(0, -s * (0.08 + i * 0.15)),
          width: w,
          height: s * 0.15,
        ),
        s * 0.22,
        Color.lerp(const Color(0xFFE8C9A0), b.decorB, i / 6)!,
      );
      final dot = Paint()..color = _a(Colors.white, 0.8);
      for (var k = 0; k < 3; k++) {
        canvas.drawCircle(
          base.translate(-w * 0.3 + k * w * 0.3, -s * (0.08 + i * 0.15)),
          s * 0.015,
          dot,
        );
      }
    }
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(0, -s * 0.84),
        width: s * 0.2,
        height: s * 0.08,
      ),
      s * 0.12,
      b.decorB,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(
          center: base.translate(0, -s * 0.1),
          width: s * 0.16,
          height: s * 0.2,
        ),
        topLeft: Radius.circular(s * 0.08),
        topRight: Radius.circular(s * 0.08),
      ),
      Paint()..color = const Color(0xFF3B1F1F),
    );
  }

  static void _cabin(Canvas canvas, MapBiome b, Offset base, double s) {
    final body = Rect.fromCenter(
      center: base.translate(0, -s * 0.18),
      width: s * 0.66,
      height: s * 0.36,
    );
    Map3D.block(canvas, body, s * 0.34, const Color(0xFF8B5E3C));
    canvas.drawPath(
      Path()
        ..moveTo(body.left - s * 0.06, body.top)
        ..lineTo(body.center.dx, body.top - s * 0.3)
        ..lineTo(body.right + s * 0.06, body.top)
        ..close(),
      Paint()..color = const Color(0xFFF1F5F9),
    );
    Map3D.block(
      canvas,
      Rect.fromLTWH(
        body.right - s * 0.16,
        body.top - s * 0.32,
        s * 0.08,
        s * 0.2,
      ),
      s * 0.06,
      const Color(0xFF6B7280),
    );
    final window = Rect.fromCenter(
      center: body.center,
      width: s * 0.14,
      height: s * 0.12,
    );
    Map3D.glow(
      canvas,
      window.center,
      s * 0.3,
      const Color(0xFFFDE68A),
      strength: 0.55,
    );
    canvas.drawRect(window, Paint()..color = const Color(0xFFFDE68A));
  }

  static void _snowman(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.sphere(
      canvas,
      base.translate(0, -s * 0.18),
      s * 0.2,
      Colors.white,
      gloss: 0.2,
    );
    Map3D.sphere(
      canvas,
      base.translate(0, -s * 0.48),
      s * 0.14,
      Colors.white,
      gloss: 0.2,
    );
    Map3D.sphere(
      canvas,
      base.translate(0, -s * 0.7),
      s * 0.1,
      Colors.white,
      gloss: 0.2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy - s * 0.71)
        ..lineTo(base.dx + s * 0.12, base.dy - s * 0.69)
        ..lineTo(base.dx, base.dy - s * 0.67)
        ..close(),
      Paint()..color = const Color(0xFFF97316),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: base.translate(0, -s * 0.6),
        width: s * 0.24,
        height: s * 0.04,
      ),
      Paint()..color = b.decorB,
    );
  }

  static void _naturalArch(Canvas canvas, MapBiome b, Offset base, double s) {
    final rock = b.terrainNear;
    for (final dx in [-0.32, 0.32]) {
      Map3D.block(
        canvas,
        Rect.fromCenter(
          center: base.translate(s * dx, -s * 0.3),
          width: s * 0.2,
          height: s * 0.6,
        ),
        s * 0.22,
        rock,
        radius: s * 0.04,
      );
    }
    final top = Path()
      ..moveTo(base.dx - s * 0.44, base.dy - s * 0.56)
      ..quadraticBezierTo(
        base.dx,
        base.dy - s * 1.0,
        base.dx + s * 0.44,
        base.dy - s * 0.56,
      )
      ..lineTo(base.dx + s * 0.22, base.dy - s * 0.56)
      ..quadraticBezierTo(
        base.dx,
        base.dy - s * 0.78,
        base.dx - s * 0.22,
        base.dy - s * 0.56,
      )
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = ui.Gradient.linear(
          base.translate(0, -s),
          base.translate(0, -s * 0.5),
          [_t(rock, 0.25), _s(rock, 0.15)],
        ),
    );
    final stripe = Paint()
      ..color = _a(Colors.white, 0.18)
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        base.translate(-s * 0.42, -s * (0.15 + i * 0.13)),
        base.translate(-s * 0.22, -s * (0.15 + i * 0.13)),
        stripe,
      );
    }
  }

  static void _balancedRock(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(0, -s * 0.25),
        width: s * 0.16,
        height: s * 0.5,
      ),
      s * 0.15,
      b.terrainNear,
      radius: s * 0.05,
    );
    Map3D.sphere(
      canvas,
      base.translate(0, -s * 0.66),
      s * 0.2,
      _t(b.terrainNear, 0.08),
      gloss: 0.15,
    );
  }

  static void _lighthouse(Canvas canvas, MapBiome b, Offset base, double s) {
    final top = base.translate(0, -s * 0.8);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(top.dx + s * 1.4, top.dy - s * 0.3)
        ..lineTo(top.dx + s * 1.4, top.dy + s * 0.25)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(top, top.translate(s * 1.4, 0), [
          _a(b.decorC, 0.45),
          _a(b.decorC, 0),
        ]),
    );
    Map3D.cylinder(canvas, base, s * 0.26, s * 0.7, Colors.white);
    for (final y in [0.22, 0.48]) {
      canvas.drawRect(
        Rect.fromLTWH(
          base.dx - s * 0.13,
          base.dy - s * y - s * 0.07,
          s * 0.26,
          s * 0.08,
        ),
        Paint()..color = b.decorB,
      );
    }
    Map3D.glow(canvas, top, s * 0.25, b.decorC, strength: 0.7);
    Map3D.cylinder(
      canvas,
      base.translate(0, -s * 0.7),
      s * 0.18,
      s * 0.1,
      b.decorC,
    );
    Map3D.dome(
      canvas,
      base.translate(0, -s * 0.8),
      s * 0.1,
      const Color(0xFF334155),
    );
  }

  static void _geode(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.glow(
      canvas,
      base.translate(0, -s * 0.35),
      s * 0.65,
      b.decorA,
      strength: 0.4,
    );
    final shards = [
      (-0.24, 0.5, 0.1),
      (0.0, 0.85, 0.14),
      (0.22, 0.6, 0.11),
      (-0.4, 0.32, 0.08),
      (0.4, 0.36, 0.08),
    ];
    for (final (i, (dx, h, w)) in shards.indexed) {
      Map3D.shard(
        canvas,
        base.translate(s * dx, 0),
        s * w,
        s * h,
        i.isEven ? b.decorA : b.decorB,
        lean: s * dx * 0.2,
      );
    }
  }

  static void _stalagmites(Canvas canvas, MapBiome b, Offset base, double s) {
    for (final (dx, h) in [
      (-0.3, 0.45),
      (-0.1, 0.7),
      (0.12, 0.55),
      (0.32, 0.38),
    ]) {
      Map3D.cone(
        canvas,
        base.translate(s * dx, 0),
        s * 0.1,
        s * h,
        b.terrainFar,
      );
    }
    Map3D.glow(
      canvas,
      base.translate(0, -s * 0.2),
      s * 0.35,
      b.decorA,
      strength: 0.25,
    );
  }

  static void _windmill(Canvas canvas, MapBiome b, Offset base, double s) {
    final tower = Path()
      ..moveTo(base.dx - s * 0.2, base.dy)
      ..lineTo(base.dx - s * 0.12, base.dy - s * 0.62)
      ..lineTo(base.dx + s * 0.12, base.dy - s * 0.62)
      ..lineTo(base.dx + s * 0.2, base.dy)
      ..close();
    canvas.drawPath(
      tower,
      Paint()
        ..shader = ui.Gradient.linear(
          base.translate(-s * 0.2, 0),
          base.translate(s * 0.2, 0),
          [const Color(0xFFF1E5D1), const Color(0xFFC9B79A)],
        ),
    );
    Map3D.cone(
      canvas,
      base.translate(0, -s * 0.62),
      s * 0.16,
      s * 0.18,
      const Color(0xFFB45309),
    );
    final hub = base.translate(0, -s * 0.66);
    final blade = Paint()..color = _a(Colors.white, 0.95);
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(hub.dx, hub.dy);
      canvas.rotate(0.35 + i * math.pi / 2);
      canvas.drawRect(
        Rect.fromLTWH(s * 0.03, -s * 0.05, s * 0.42, s * 0.1),
        blade,
      );
      canvas.drawLine(
        Offset.zero,
        Offset(s * 0.45, 0),
        Paint()
          ..color = const Color(0xFF8B5E3C)
          ..strokeWidth = 2,
      );
      canvas.restore();
    }
    Map3D.sphere(canvas, hub, s * 0.04, const Color(0xFF8B5E3C));
  }

  static void _turbine(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.cylinder(canvas, base, s * 0.06, s * 0.9, Colors.white);
    final hub = base.translate(0, -s * 0.9);
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(hub.dx, hub.dy);
      canvas.rotate(-math.pi / 2 + i * 2 * math.pi / 3 + 0.3);
      canvas.drawPath(
        Path()
          ..moveTo(0, -s * 0.03)
          ..quadraticBezierTo(s * 0.3, -s * 0.06, s * 0.5, 0)
          ..quadraticBezierTo(s * 0.3, s * 0.02, 0, s * 0.03)
          ..close(),
        Paint()..color = const Color(0xFFF1F5F9),
      );
      canvas.restore();
    }
    Map3D.sphere(canvas, hub, s * 0.05, const Color(0xFFCBD5E1));
  }

  static void _tornado(Canvas canvas, MapBiome b, Offset base, double s) {
    for (var i = 0; i < 6; i++) {
      final w = s * (0.12 + i * 0.12);
      final c = base.translate(
        math.sin(i * 0.9) * s * 0.06,
        -s * (0.05 + i * 0.15),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w, height: s * 0.12),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.04
          ..color = _a(Color.lerp(b.terrainNear, Colors.white, i / 6)!, 0.85),
      );
    }
  }

  static void _fountain(Canvas canvas, MapBiome b, Offset base, double u) {
    Map3D.cylinder(
      canvas,
      base,
      40 * u,
      8 * u,
      const Color(0xFFE5E7EB),
      top: b.water,
    );
    Map3D.cylinder(
      canvas,
      base.translate(0, -8 * u),
      8 * u,
      16 * u,
      const Color(0xFFD1D5DB),
    );
    Map3D.cylinder(
      canvas,
      base.translate(0, -24 * u),
      22 * u,
      5 * u,
      const Color(0xFFE5E7EB),
      top: b.water,
    );
    final jet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u
      ..color = _a(b.waterLight, 0.9);
    for (final dx in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy - 32 * u)
          ..quadraticBezierTo(
            base.dx + dx * 8 * u,
            base.dy - 46 * u,
            base.dx + dx * 15 * u,
            base.dy - 26 * u,
          ),
        jet,
      );
    }
  }

  static void _observatory(Canvas canvas, MapBiome b, Offset base, double s) {
    final body = Rect.fromCenter(
      center: base.translate(0, -s * 0.16),
      width: s * 0.6,
      height: s * 0.32,
    );
    Map3D.block(canvas, body, s * 0.25, const Color(0xFFCBD5E1));
    Map3D.dome(
      canvas,
      Offset(base.dx + s * 0.06, body.top),
      s * 0.3,
      const Color(0xFFE2E8F0),
    );
    canvas.save();
    canvas.translate(base.dx + s * 0.06, body.top - s * 0.18);
    canvas.rotate(-0.7);
    canvas.drawRect(
      Rect.fromLTWH(0, -s * 0.04, s * 0.32, s * 0.08),
      Paint()..color = const Color(0xFF475569),
    );
    canvas.restore();
    Map3D.glow(canvas, body.center, s * 0.3, b.decorC, strength: 0.3);
  }

  static void _cometRock(Canvas canvas, MapBiome b, Offset c, double s) {
    final head = c.translate(s * 0.2, -s * 0.3);
    canvas.drawPath(
      Path()
        ..moveTo(head.dx, head.dy - s * 0.12)
        ..lineTo(head.dx - s * 0.75, head.dy + s * 0.32)
        ..lineTo(head.dx, head.dy + s * 0.12)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          head,
          head.translate(-s * 0.75, s * 0.32),
          [_a(b.decorA, 0.8), _a(b.decorA, 0)],
        ),
    );
    Map3D.glow(canvas, head, s * 0.3, b.decorA, strength: 0.5);
    Map3D.sphere(canvas, head, s * 0.12, const Color(0xFF94A3B8));
  }

  static void _lanternTree(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.cylinder(canvas, base, s * 0.1, s * 0.45, const Color(0xFF6B4A3A));
    Map3D.sphere(canvas, base.translate(0, -s * 0.62), s * 0.32, b.decorB);
    for (final (dx, dy) in [
      (-0.22, -0.5),
      (0.18, -0.42),
      (0.02, -0.78),
      (0.26, -0.68),
    ]) {
      _paperLantern(
        canvas,
        b,
        base.translate(s * dx, s * dy),
        s * 0.04,
        b.decorC,
      );
    }
  }

  static void _obsidianSpire(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.glow(
      canvas,
      base.translate(0, -s * 0.5),
      s * 0.6,
      b.decorB,
      strength: 0.35,
    );
    Map3D.shard(canvas, base, s * 0.2, s * 1.1, const Color(0xFF1F1A2E));
    canvas.drawLine(
      base.translate(-s * 0.13, -s * 0.68),
      base.translate(0, -s * 1.1),
      Paint()
        ..color = b.decorB
        ..strokeWidth = 2.5,
    );
    Map3D.shard(
      canvas,
      base.translate(-s * 0.3, 0),
      s * 0.1,
      s * 0.45,
      const Color(0xFF2A2238),
    );
    Map3D.shard(
      canvas,
      base.translate(s * 0.28, 0),
      s * 0.12,
      s * 0.55,
      const Color(0xFF2A2238),
    );
  }

  static void _shardCluster(Canvas canvas, MapBiome b, Offset base, double s) {
    for (final (i, dx) in [-0.3, -0.1, 0.12, 0.32].indexed) {
      Map3D.shard(
        canvas,
        base.translate(s * dx, 0),
        s * 0.09,
        s * (0.4 + (i % 2) * 0.25),
        i.isEven ? const Color(0xFF1F1A2E) : b.decorB,
        lean: s * dx * 0.3,
      );
    }
  }

  static void _loomFrame(Canvas canvas, MapBiome b, Offset base, double s) {
    for (final dx in [-0.4, 0.4]) {
      Map3D.cylinder(
        canvas,
        base.translate(s * dx, 0),
        s * 0.07,
        s * 0.8,
        const Color(0xFF8B6B3A),
      );
    }
    for (final y in [0.15, 0.78]) {
      Map3D.block(
        canvas,
        Rect.fromCenter(
          center: base.translate(0, -s * y),
          width: s * 0.86,
          height: s * 0.05,
        ),
        s * 0.06,
        const Color(0xFF8B6B3A),
      );
    }
    for (var i = 0; i < 9; i++) {
      final x = base.dx - s * 0.32 + i * s * 0.08;
      canvas.drawLine(
        Offset(x, base.dy - s * 0.75),
        Offset(x, base.dy - s * 0.18),
        Paint()
          ..color = [b.decorA, b.decorB, b.decorC][i % 3]
          ..strokeWidth = 1.6,
      );
    }
    Map3D.glow(
      canvas,
      base.translate(0, -s * 0.46),
      s * 0.5,
      b.decorA,
      strength: 0.3,
    );
  }

  static void _spindle(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.cylinder(canvas, base, s * 0.04, s * 0.8, const Color(0xFF8B6B3A));
    for (var i = 0; i < 4; i++) {
      Map3D.sphere(
        canvas,
        base.translate(0, -s * (0.3 + i * 0.1)),
        s * (0.16 - i * 0.02),
        [b.decorA, b.decorB, b.decorC, b.decorA][i],
        gloss: 0.3,
      );
    }
  }

  static void _floatingPrism(Canvas canvas, MapBiome b, Offset c, double s) {
    final p = c.translate(0, -s * 0.2);
    Map3D.glow(canvas, p, s * 0.6, b.accent, strength: 0.3);
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - s * 0.4)
        ..lineTo(p.dx + s * 0.28, p.dy + s * 0.12)
        ..lineTo(p.dx - s * 0.28, p.dy + s * 0.12)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          p.translate(-s * 0.3, 0),
          p.translate(s * 0.3, 0),
          [b.decorA, b.decorB, b.decorC],
          [0, 0.5, 1],
        ),
    );
    final rainbow = [
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFFFDE047),
      const Color(0xFF22C55E),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
    ];
    for (var i = 0; i < rainbow.length; i++) {
      canvas.drawLine(
        p.translate(s * 0.14, -s * 0.05),
        p.translate(s * 0.6, s * (0.0 + i * 0.05)),
        Paint()
          ..color = _a(rainbow[i], 0.8)
          ..strokeWidth = 2.2,
      );
    }
  }

  static void _rainbowArch(Canvas canvas, MapBiome b, Offset base, double s) {
    final rainbow = [
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFFFDE047),
      const Color(0xFF22C55E),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
    ];
    for (var i = 0; i < rainbow.length; i++) {
      final r = s * (0.5 - i * 0.05);
      canvas.drawArc(
        Rect.fromCircle(center: base, radius: r),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..color = rainbow[i],
      );
    }
    for (final dx in [-0.45, 0.45]) {
      Map3D.sphere(
        canvas,
        base.translate(s * dx, -s * 0.02),
        s * 0.12,
        Colors.white,
        gloss: 0.2,
      );
    }
  }

  static void _grandGate(Canvas canvas, MapBiome b, Offset base, double s) {
    for (final dx in [-0.36, 0.36]) {
      Map3D.block(
        canvas,
        Rect.fromCenter(
          center: base.translate(s * dx, -s * 0.32),
          width: s * 0.2,
          height: s * 0.64,
        ),
        s * 0.22,
        const Color(0xFFF5EBDD),
      );
      Map3D.dome(canvas, base.translate(s * dx, -s * 0.64), s * 0.1, b.decorB);
    }
    final arch = Rect.fromCenter(
      center: base.translate(0, -s * 0.66),
      width: s * 0.92,
      height: s * 0.14,
    );
    Map3D.block(canvas, arch, s * 0.22, const Color(0xFFF5EBDD));
    Map3D.dome(canvas, Offset(base.dx, arch.top), s * 0.2, b.decorB);
    Map3D.sphere(
      canvas,
      Offset(base.dx, arch.top - s * 0.24),
      s * 0.035,
      b.decorB,
    );
    canvas.drawRect(
      Rect.fromLTWH(base.dx - s * 0.2, base.dy - s * 0.5, s * 0.4, s * 0.5),
      Paint()..color = _a(b.decorC, 0.85),
    );
  }

  static void _statue(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(0, -s * 0.12),
        width: s * 0.36,
        height: s * 0.24,
      ),
      s * 0.25,
      const Color(0xFFE7E5E4),
    );
    Map3D.cylinder(
      canvas,
      base.translate(0, -s * 0.24),
      s * 0.14,
      s * 0.32,
      b.decorB,
    );
    Map3D.sphere(canvas, base.translate(0, -s * 0.64), s * 0.1, b.decorB);
    Map3D.glow(
      canvas,
      base.translate(0, -s * 0.5),
      s * 0.3,
      b.decorB,
      strength: 0.25,
    );
  }

  static void _greekTemple(Canvas canvas, MapBiome b, Offset base, double s) {
    for (var i = 0; i < 2; i++) {
      Map3D.block(
        canvas,
        Rect.fromCenter(
          center: base.translate(0, -s * (0.04 + i * 0.07)),
          width: s * (1.0 - i * 0.08),
          height: s * 0.07,
        ),
        s * 0.28,
        const Color(0xFFE8EEF4),
      );
    }
    for (var i = 0; i < 5; i++) {
      Map3D.cylinder(
        canvas,
        base.translate(-s * 0.36 + i * s * 0.18, -s * 0.14),
        s * 0.08,
        s * 0.44,
        Colors.white,
      );
    }
    final beam = Rect.fromCenter(
      center: base.translate(0, -s * 0.62),
      width: s * 0.96,
      height: s * 0.08,
    );
    Map3D.block(canvas, beam, s * 0.28, const Color(0xFFE8EEF4));
    canvas.drawPath(
      Path()
        ..moveTo(beam.left, beam.top)
        ..lineTo(base.dx, beam.top - s * 0.2)
        ..lineTo(beam.right, beam.top)
        ..close(),
      Paint()..color = const Color(0xFFF8FAFC),
    );
    canvas.drawRect(
      Rect.fromLTWH(beam.left, beam.top + s * 0.02, beam.width, s * 0.02),
      Paint()..color = b.accent,
    );
  }

  /// The game's own motif: a giant arrow on a plinth.
  static void _arrowStatue(Canvas canvas, MapBiome b, Offset base, double s) {
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: base.translate(0, -s * 0.1),
        width: s * 0.42,
        height: s * 0.2,
      ),
      s * 0.25,
      const Color(0xFFE8EEF4),
    );
    final top = base.translate(0, -s * 0.2);
    final shaft = Rect.fromLTWH(
      top.dx - s * 0.05,
      top.dy - s * 0.55,
      s * 0.1,
      s * 0.55,
    );
    Map3D.block(canvas, shaft, s * 0.08, b.accent);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx - s * 0.18, shaft.top)
        ..lineTo(top.dx, shaft.top - s * 0.26)
        ..lineTo(top.dx + s * 0.18, shaft.top)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          top.translate(-s * 0.18, 0),
          top.translate(s * 0.18, 0),
          [Map3D.tint(b.accent, 0.3), Map3D.shade(b.accent, 0.25)],
        ),
    );
    Map3D.glow(canvas, shaft.topCenter, s * 0.35, b.accent, strength: 0.25);
  }

  static void _floatingIsland(Canvas canvas, MapBiome b, Offset c, double s) {
    _cloudIsle(
      canvas,
      b,
      c.translate(0, -s * 0.05),
      s * 0.45,
      1,
      math.Random(3),
    );
    final fall = Rect.fromLTWH(c.dx + s * 0.18, c.dy, s * 0.06, s * 0.4);
    canvas.drawRect(
      fall,
      Paint()
        ..shader = ui.Gradient.linear(fall.topCenter, fall.bottomCenter, [
          b.water,
          _a(b.waterLight, 0),
        ]),
    );
    _sphereTree(canvas, b, c.translate(-s * 0.1, -s * 0.1), s / 30, 1);
  }

  static void _balloon(Canvas canvas, MapBiome b, Offset c, double s) {
    final env = c.translate(0, -s * 0.35);
    Map3D.sphere(canvas, env, s * 0.3, b.decorB);
    final stripe = Paint()..color = _a(Colors.white, 0.6);
    canvas.drawOval(
      Rect.fromCenter(center: env, width: s * 0.14, height: s * 0.58),
      stripe,
    );
    final basket = Rect.fromCenter(
      center: c.translate(0, s * 0.12),
      width: s * 0.16,
      height: s * 0.1,
    );
    for (final dx in [-0.06, 0.06]) {
      canvas.drawLine(
        env.translate(s * dx * 2, s * 0.25),
        basket.topCenter.translate(s * dx, 0),
        Paint()
          ..color = const Color(0xFF6B4A2B)
          ..strokeWidth = 1.2,
      );
    }
    Map3D.block(canvas, basket, s * 0.08, const Color(0xFF8B5E3C));
  }

  // ── Decorations ──────────────────────────────────────────────────────

  static void decor(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    SceneDecor kind,
    int variant,
  ) {
    switch (kind) {
      case SceneDecor.topiary:
        Map3D.shadow(canvas, c.translate(0, 1), 22 * s);
        _planter(canvas, b, c, 12 * s);
        Map3D.cylinder(
          canvas,
          c.translate(0, -6 * s),
          2 * s,
          6 * s,
          const Color(0xFF7A5230),
        );
        if (variant == 0) {
          Map3D.sphere(canvas, c.translate(0, -18 * s), 8 * s, b.decorA);
        } else if (variant == 1) {
          Map3D.sphere(canvas, c.translate(0, -16 * s), 6.5 * s, b.decorA);
          Map3D.sphere(canvas, c.translate(0, -27 * s), 4.5 * s, b.decorA);
        } else {
          Map3D.cone(canvas, c.translate(0, -10 * s), 8 * s, 22 * s, b.decorA);
        }
      case SceneDecor.hedge:
        Map3D.shadow(canvas, c.translate(0, 2), 34 * s);
        Map3D.roundedBlock(
          canvas,
          Rect.fromCenter(
            center: c.translate(0, -6 * s),
            width: 30 * s,
            height: 12 * s,
          ),
          10 * s,
          b.decorA,
        );
      case SceneDecor.sphereTree:
        _sphereTree(canvas, b, c, s, variant);
      case SceneDecor.bush:
        Map3D.shadow(canvas, c.translate(0, 2), 28 * s);
        Map3D.sphere(canvas, c.translate(-6 * s, -6 * s), 7 * s, b.decorA);
        Map3D.sphere(canvas, c.translate(6 * s, -6 * s), 7 * s, b.decorA);
        Map3D.sphere(
          canvas,
          c.translate(0, -11 * s),
          8 * s,
          _t(b.decorA, 0.08),
        );
      case SceneDecor.rock:
        Map3D.shadow(canvas, c.translate(0, 2), 26 * s);
        Map3D.shard(
          canvas,
          c,
          11 * s,
          12 * s,
          Color.lerp(b.terrainNear, const Color(0xFF94A3B8), 0.4)!,
          lean: (variant - 1) * 3 * s,
        );
      case SceneDecor.palm:
        _palm(canvas, b, c, s, variant.isEven);
      case SceneDecor.lavender:
        _lavender(canvas, b, c, s);
      case SceneDecor.fountain:
        Map3D.shadow(canvas, c.translate(0, 2), 40 * s);
        _fountain(canvas, b, c, s * 0.8);
      case SceneDecor.kolam:
        canvas.save();
        canvas.translate(c.dx, c.dy - 4 * s);
        canvas.scale(1, 0.55);
        final chalk = Paint()
          ..color = _a(
            b.kind == BiomeKind.courtyard ? b.decorA : Colors.white,
            0.9,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s;
        final dot = Paint()..color = _a(Colors.white, 0.95);
        for (var i = -1; i <= 1; i++) {
          for (var j = -1; j <= 1; j++) {
            canvas.drawCircle(Offset(i * 8.0 * s, j * 8.0 * s), 1.4 * s, dot);
          }
        }
        for (var i = 0; i < 4; i++) {
          canvas.save();
          canvas.rotate(i * math.pi / 2);
          canvas.drawArc(
            Rect.fromCircle(center: Offset(8 * s, 0), radius: 6 * s),
            -2.2,
            4.4,
            false,
            chalk,
          );
          canvas.restore();
        }
        canvas.restore();
      case SceneDecor.torch:
        Map3D.shadow(canvas, c.translate(0, 1), 12 * s);
        Map3D.cylinder(canvas, c, 3 * s, 22 * s, const Color(0xFF6B4A2B));
        Map3D.glow(
          canvas,
          c.translate(0, -26 * s),
          14 * s,
          const Color(0xFFFFB347),
          strength: 0.55,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(0, -26 * s),
            width: 6 * s,
            height: 9 * s,
          ),
          Paint()..color = const Color(0xFFFF9F43),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(0, -25 * s),
            width: 3 * s,
            height: 5 * s,
          ),
          Paint()..color = const Color(0xFFFFF3B0),
        );
      case SceneDecor.pot:
        Map3D.shadow(canvas, c.translate(0, 1), 20 * s);
        final col = [
          const Color(0xFFC2410C),
          const Color(0xFFB45309),
          b.decorB,
        ][variant];
        Map3D.sphere(canvas, c.translate(0, -8 * s), 8 * s, col, gloss: 0.4);
        Map3D.cylinder(
          canvas,
          c.translate(0, -14 * s),
          7 * s,
          4 * s,
          _s(col, 0.1),
        );
        if (b.kind == BiomeKind.courtyard || b.kind == BiomeKind.citadel) {
          for (var i = -1; i <= 1; i++) {
            Map3D.sphere(
              canvas,
              c.translate(i * 3.5 * s, -20 * s),
              2.6 * s,
              b.decorB,
            );
          }
        }
      case SceneDecor.flag:
        canvas.drawLine(
          c,
          c.translate(0, -30 * s),
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..strokeWidth = 1.6 * s,
        );
        final col = [b.decorA, b.decorB, b.decorC][variant];
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 30 * s)
            ..quadraticBezierTo(
              c.dx + 8 * s,
              c.dy - 32 * s,
              c.dx + 15 * s,
              c.dy - 27 * s,
            )
            ..lineTo(c.dx, c.dy - 21 * s)
            ..close(),
          Paint()..color = col,
        );
      case SceneDecor.lotusPad:
        _lotusPad(canvas, b, c, s, variant);
      case SceneDecor.reeds:
        final stalk = Paint()
          ..color = _s(b.decorA, 0.1)
          ..strokeWidth = 1.6 * s
          ..strokeCap = StrokeCap.round;
        for (var i = -1; i <= 1; i++) {
          final top = c.translate(
            i * 4 * s + i * 2 * s,
            -(20 + i.abs() * -4) * s,
          );
          canvas.drawLine(c.translate(i * 3 * s, 0), top, stalk);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: top.translate(0, 3 * s),
                width: 3.4 * s,
                height: 8 * s,
              ),
              Radius.circular(2 * s),
            ),
            Paint()..color = const Color(0xFF7A4E2A),
          );
        }
      case SceneDecor.fern:
        Map3D.shadow(canvas, c.translate(0, 1), 24 * s);
        for (var i = 0; i < 5; i++) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(-math.pi / 2 + (i - 2) * 0.45);
          canvas.drawOval(
            Rect.fromLTWH(0, -2.5 * s, 18 * s, 5 * s),
            Paint()..color = i.isEven ? b.decorA : _t(b.decorA, 0.15),
          );
          canvas.restore();
        }
      case SceneDecor.feather:
        canvas.drawLine(
          c,
          c.translate(2 * s, -24 * s),
          Paint()
            ..color = _s(b.decorA, 0.2)
            ..strokeWidth = 1.2 * s,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(2 * s, -22 * s),
            width: 10 * s,
            height: 13 * s,
          ),
          Paint()..color = b.decorA,
        );
        canvas.drawCircle(
          c.translate(2 * s, -22 * s),
          3.4 * s,
          Paint()..color = b.decorB,
        );
        canvas.drawCircle(
          c.translate(2 * s, -22 * s),
          1.5 * s,
          Paint()..color = b.decorC,
        );
      case SceneDecor.umbrella:
        Map3D.shadow(canvas, c.translate(0, 1), 24 * s);
        _bigUmbrella(canvas, b, c, 34 * s);
      case SceneDecor.puddle:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 30 * s, height: 9 * s),
          Paint()..color = _a(b.water, 0.55),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(-4 * s, -1 * s),
            width: 10 * s,
            height: 2.5 * s,
          ),
          Paint()..color = _a(Colors.white, 0.45),
        );
      case SceneDecor.lantern:
        canvas.drawLine(
          c,
          c.translate(0, -28 * s),
          Paint()
            ..color = const Color(0xFF6B4A2B)
            ..strokeWidth = 2 * s,
        );
        canvas.drawLine(
          c.translate(0, -28 * s),
          c.translate(6 * s, -28 * s),
          Paint()
            ..color = const Color(0xFF6B4A2B)
            ..strokeWidth = 2 * s,
        );
        _paperLantern(
          canvas,
          b,
          c.translate(6 * s, -20 * s),
          4 * s,
          [b.decorA, b.decorB, b.decorC][variant],
        );
      case SceneDecor.stall:
        Map3D.shadow(canvas, c.translate(0, 2), 30 * s);
        final front = Rect.fromCenter(
          center: c.translate(0, -7 * s),
          width: 24 * s,
          height: 14 * s,
        );
        Map3D.block(canvas, front, 8 * s, const Color(0xFF6B3F2A));
        _awning(canvas, front, 6 * s, [b.decorA, b.decorB, b.decorC][variant]);
      case SceneDecor.stupa:
        Map3D.shadow(canvas, c.translate(0, 1), 26 * s);
        _stupa(canvas, b, c, s * 0.5);
      case SceneDecor.coral:
        _coral(canvas, b, c, s, variant);
      case SceneDecor.seaweed:
        _seaweed(canvas, b, c, s, variant);
      case SceneDecor.shell:
        Map3D.shadow(canvas, c.translate(0, 1), 16 * s);
        final col = [
          const Color(0xFFFBCFE8),
          const Color(0xFFFDE68A),
          Colors.white,
        ][variant];
        canvas.drawArc(
          Rect.fromCenter(
            center: c.translate(0, -2 * s),
            width: 16 * s,
            height: 16 * s,
          ),
          math.pi,
          math.pi,
          true,
          Paint()..color = col,
        );
        final rib = Paint()
          ..color = _s(col, 0.2)
          ..strokeWidth = 1 * s;
        for (var i = 1; i < 5; i++) {
          final a = math.pi + i * math.pi / 5;
          canvas.drawLine(
            c.translate(0, -2 * s),
            c.translate(math.cos(a) * 8 * s, -2 * s + math.sin(a) * 8 * s),
            rib,
          );
        }
      case SceneDecor.duneGrass:
        final g = Paint()
          ..color = [
            b.decorA,
            _s(b.decorA, 0.15),
            const Color(0xFFB59B5A),
          ][variant]
          ..strokeWidth = 1.6 * s
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        for (var i = -2; i <= 2; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(c.dx + i * 2 * s, c.dy)
              ..quadraticBezierTo(
                c.dx + i * 3 * s,
                c.dy - 8 * s,
                c.dx + i * 6 * s,
                c.dy - (14 - i.abs() * 2) * s,
              ),
            g,
          );
        }
      case SceneDecor.yurt:
        _yurt(canvas, b, c, s);
      case SceneDecor.standingStone:
        Map3D.shadow(canvas, c.translate(0, 2), 18 * s);
        _monolith(
          canvas,
          c,
          8 * s,
          (20 + variant * 4) * s,
          b.kind == BiomeKind.temple
              ? const Color(0xFF9CA38A)
              : const Color(0xFF8D93A6),
        );
      case SceneDecor.iceShard:
        Map3D.shadow(canvas, c.translate(0, 2), 20 * s);
        Map3D.shard(
          canvas,
          c,
          6 * s,
          (18 + variant * 5) * s,
          b.decorA,
          lean: (variant - 1) * 3 * s,
        );
        Map3D.shard(
          canvas,
          c.translate(7 * s, 0),
          4 * s,
          11 * s,
          _t(b.decorA, 0.3),
        );
      case SceneDecor.igloo:
        Map3D.shadow(canvas, c.translate(0, 2), 40 * s);
        _igloo(canvas, b, c, s * 0.8);
      case SceneDecor.cloudPuff:
        Map3D.shadow(canvas, c.translate(0, 2), 30 * s, opacity: 0.12);
        for (final (dx, dy, r) in [
          (-7.0, -5.0, 7.0),
          (7.0, -5.0, 7.0),
          (0.0, -10.0, 9.0),
        ]) {
          Map3D.sphere(
            canvas,
            c.translate(dx * s, dy * s),
            r * s,
            b.kind == BiomeKind.glacier || b.kind == BiomeKind.aurora
                ? const Color(0xFFF1F7FC)
                : Colors.white,
            gloss: 0.15,
          );
        }
      case SceneDecor.stormRock:
        Map3D.shadow(canvas, c.translate(0, 2), 26 * s, opacity: 0.35);
        Map3D.shard(
          canvas,
          c,
          11 * s,
          14 * s,
          const Color(0xFF4B5268),
          lean: 2 * s,
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 2 * s, c.dy - 12 * s)
            ..lineTo(c.dx + 1 * s, c.dy - 6 * s)
            ..lineTo(c.dx - 1 * s, c.dy - 5 * s)
            ..lineTo(c.dx + 2 * s, c.dy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * s
            ..color = b.decorA,
        );
      case SceneDecor.bamboo:
        _bamboo(canvas, b, c, s, variant);
      case SceneDecor.glowTree:
        _glowTree(canvas, b, c, s);
      case SceneDecor.glowShroom:
        _glowShroom(canvas, b, c, s, variant);
      case SceneDecor.snowTree:
        _snowTree(canvas, b, c, s);
      case SceneDecor.hoodoo:
        _hoodoo(canvas, b, c, s);
      case SceneDecor.buoy:
        Map3D.shadow(canvas, c.translate(0, 2), 14 * s, opacity: 0.3);
        Map3D.cylinder(canvas, c, 9 * s, 14 * s, b.decorB);
        canvas.drawRect(
          Rect.fromLTWH(c.dx - 4.5 * s, c.dy - 9 * s, 9 * s, 3 * s),
          Paint()..color = Colors.white,
        );
        Map3D.glow(
          canvas,
          c.translate(0, -18 * s),
          8 * s,
          b.decorC,
          strength: 0.6,
        );
        canvas.drawCircle(
          c.translate(0, -17 * s),
          2 * s,
          Paint()..color = b.decorC,
        );
      case SceneDecor.boat:
        _boat(canvas, b, c, s);
      case SceneDecor.stalagmite:
        Map3D.shadow(canvas, c.translate(0, 2), 18 * s, opacity: 0.35);
        Map3D.cone(canvas, c, 6 * s, (20 + variant * 5) * s, b.terrainFar);
        Map3D.cone(
          canvas,
          c.translate(7 * s, 0),
          4 * s,
          11 * s,
          _t(b.terrainFar, 0.1),
        );
      case SceneDecor.gem:
        Map3D.glow(
          canvas,
          c.translate(0, -8 * s),
          14 * s,
          [b.decorA, b.decorB, b.decorC][variant],
          strength: 0.35,
        );
        Map3D.shard(
          canvas,
          c,
          5 * s,
          16 * s,
          [b.decorA, b.decorB, b.decorC][variant],
        );
        Map3D.shard(
          canvas,
          c.translate(-6 * s, 0),
          3.5 * s,
          10 * s,
          [b.decorB, b.decorC, b.decorA][variant],
        );
      case SceneDecor.sunflower:
        _sunflower(canvas, b, c, s, variant);
      case SceneDecor.windmill:
        Map3D.shadow(canvas, c.translate(0, 2), 30 * s);
        _windmill(canvas, b, c, 36 * s);
      case SceneDecor.pinwheel:
        canvas.drawLine(
          c,
          c.translate(0, -24 * s),
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..strokeWidth = 1.6 * s,
        );
        final hub = c.translate(0, -24 * s);
        for (var i = 0; i < 4; i++) {
          canvas.save();
          canvas.translate(hub.dx, hub.dy);
          canvas.rotate(i * math.pi / 2 + variant * 0.4);
          canvas.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(8 * s, -2 * s)
              ..lineTo(5 * s, 5 * s)
              ..close(),
            Paint()..color = [b.decorB, b.decorC, b.decorA, Colors.white][i],
          );
          canvas.restore();
        }
      case SceneDecor.asteroid:
        Map3D.shadow(canvas, c.translate(0, 2), 22 * s, opacity: 0.3);
        Map3D.sphere(
          canvas,
          c.translate(0, -8 * s),
          (7 + variant * 2) * s,
          const Color(0xFF7C7FA6),
          gloss: 0.2,
        );
        canvas.drawCircle(
          c.translate(-2 * s, -9 * s),
          2 * s,
          Paint()..color = const Color(0xFF5B5E85),
        );
      case SceneDecor.orb:
        final col = [b.decorA, b.decorB, b.decorC][variant];
        Map3D.glow(
          canvas,
          c.translate(0, -16 * s),
          16 * s,
          col,
          strength: 0.45,
        );
        Map3D.sphere(canvas, c.translate(0, -16 * s), 6 * s, col);
        Map3D.cylinder(canvas, c, 6 * s, 8 * s, const Color(0xFFCBD5E1));
      case SceneDecor.obsidianShard:
        Map3D.shadow(canvas, c.translate(0, 2), 20 * s, opacity: 0.4);
        Map3D.shard(
          canvas,
          c,
          6 * s,
          (16 + variant * 6) * s,
          const Color(0xFF1F1A2E),
          lean: (variant - 1) * 3 * s,
        );
        canvas.drawLine(
          c.translate(-4 * s, -10 * s),
          c.translate(0, -(16 + variant * 6) * s),
          Paint()
            ..color = _a(b.decorB, 0.9)
            ..strokeWidth = 1.4 * s,
        );
      case SceneDecor.threadPost:
        Map3D.cylinder(canvas, c, 4 * s, 24 * s, const Color(0xFF8B6B3A));
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            c.translate(0, -(8 + i * 6) * s),
            c.translate(18 * s, -(4 + i * 7) * s),
            Paint()
              ..color = _a([b.decorA, b.decorB, b.decorC][i], 0.85)
              ..strokeWidth = 1.2 * s,
          );
        }
      case SceneDecor.prismCrystal:
        final p = c.translate(0, -10 * s);
        Map3D.glow(canvas, p, 14 * s, b.accent, strength: 0.3);
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - 10 * s)
            ..lineTo(p.dx + 7 * s, p.dy + 4 * s)
            ..lineTo(p.dx, p.dy + 9 * s)
            ..lineTo(p.dx - 7 * s, p.dy + 4 * s)
            ..close(),
          Paint()
            ..shader = ui.Gradient.linear(
              p.translate(-7 * s, 0),
              p.translate(7 * s, 0),
              [b.decorA, b.decorB, b.decorC],
              [0, 0.5, 1],
            ),
        );
      case SceneDecor.column:
        Map3D.shadow(canvas, c.translate(0, 2), 18 * s);
        Map3D.block(
          canvas,
          Rect.fromCenter(
            center: c.translate(0, -2 * s),
            width: 12 * s,
            height: 4 * s,
          ),
          5 * s,
          const Color(0xFFE8EEF4),
        );
        Map3D.cylinder(
          canvas,
          c.translate(0, -4 * s),
          7 * s,
          (20 + variant * 4) * s,
          Colors.white,
        );
    }
  }

  // ── Shared pieces ────────────────────────────────────────────────────

  static void _sphereTree(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    int variant,
  ) {
    Map3D.shadow(canvas, c.translate(0, 2), 30 * s);
    Map3D.cylinder(canvas, c, 5 * s, 14 * s, const Color(0xFF7A5230));
    final col = switch (b.kind) {
      BiomeKind.mandalaHeights => const Color(0xFFF9A8D4),
      BiomeKind.pantheon => const Color(0xFF6B8E3D),
      BiomeKind.twilight => const Color(0xFF8B5CF6),
      _ => variant == 2 ? b.decorB : b.decorA,
    };
    Map3D.sphere(canvas, c.translate(0, -22 * s), 12 * s, col);
    if (variant == 1)
      Map3D.sphere(canvas, c.translate(7 * s, -16 * s), 7 * s, _t(col, 0.06));
  }

  static void _palm(Canvas canvas, MapBiome b, Offset c, double s, bool flip) {
    Map3D.shadow(canvas, c.translate(0, 2), 26 * s);
    final d = flip ? -1.0 : 1.0;
    final top = c.translate(5 * s * d, -26 * s);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(c.dx - 2 * s * d, c.dy - 14 * s, top.dx, top.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * s
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF9C6B3F),
    );
    final leaf = b.kind == BiomeKind.silkRoad ? b.decorC : b.decorA;
    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.translate(top.dx, top.dy);
      canvas.rotate(-math.pi / 2 + (i - 2.5) * 0.62);
      canvas.drawOval(
        Rect.fromLTWH(0, -3 * s, 16 * s, 6 * s),
        Paint()..color = i.isEven ? leaf : _t(leaf, 0.18),
      );
      canvas.restore();
    }
  }

  static void _lavender(Canvas canvas, MapBiome b, Offset c, double s) {
    Map3D.shadow(canvas, c.translate(0, 1), 22 * s);
    final col = b.kind == BiomeKind.twilight ? b.decorA : b.decorC;
    for (var i = -2; i <= 2; i++) {
      final top = c.translate(i * 3.2 * s, -(16 - i.abs() * 2) * s);
      canvas.drawLine(
        c.translate(i * 1.5 * s, 0),
        top,
        Paint()
          ..color = const Color(0xFF4D7C4A)
          ..strokeWidth = 1.2 * s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: top, width: 3 * s, height: 8 * s),
          Radius.circular(1.5 * s),
        ),
        Paint()..color = i.isEven ? col : _t(col, 0.2),
      );
    }
  }

  static void _lotusPad(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    int variant,
  ) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 26 * s, height: 10 * s),
      Paint()..color = _s(b.decorA, 0.15),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: c.translate(0, -1.5 * s),
        width: 26 * s,
        height: 10 * s,
      ),
      0.3,
      2 * math.pi - 0.6,
      true,
      Paint()..color = b.decorA,
    );
    if (variant != 2) {
      for (final a in [-0.5, 0.0, 0.5]) {
        canvas.save();
        canvas.translate(c.dx, c.dy - 3 * s);
        canvas.rotate(a);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -5 * s),
            width: 5 * s,
            height: 10 * s,
          ),
          Paint()..color = a == 0 ? _t(b.decorB, 0.2) : b.decorB,
        );
        canvas.restore();
      }
    }
  }

  static void _coral(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    int variant,
  ) {
    Map3D.shadow(canvas, c.translate(0, 2), 26 * s, opacity: 0.3);
    final col = [b.decorA, b.decorB, b.decorC][variant % 3];
    final branch = Paint()
      ..color = col
      ..strokeWidth = 3.4 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (dx, h, bend) in [
      (-6.0, 18.0, -5.0),
      (0.0, 26.0, 2.0),
      (6.0, 20.0, 6.0),
    ]) {
      final top = c.translate((dx + bend) * s, -h * s);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + dx * 0.3 * s, c.dy)
          ..quadraticBezierTo(
            c.dx + dx * s,
            c.dy - h * 0.5 * s,
            top.dx,
            top.dy,
          ),
        branch,
      );
      Map3D.sphere(canvas, top, 2.6 * s, _t(col, 0.2), gloss: 0.3);
    }
  }

  static void _seaweed(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    int variant,
  ) {
    final p = Paint()
      ..color = _a(const Color(0xFF34D399), 0.85)
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var k = -1; k <= 1; k++) {
      final path = Path()..moveTo(c.dx + k * 4 * s, c.dy);
      for (var i = 1; i <= 4; i++) {
        path.lineTo(
          c.dx + k * 4 * s + math.sin(i * 1.4 + variant + k) * 4 * s,
          c.dy - i * 7 * s,
        );
      }
      canvas.drawPath(path, p);
    }
  }

  static void _yurt(Canvas canvas, MapBiome b, Offset c, double s) {
    Map3D.shadow(
      canvas,
      c.translate(0, 2),
      40 * s,
      opacity: b.dark ? 0.4 : 0.2,
    );
    Map3D.cylinder(canvas, c, 30 * s, 12 * s, b.decorA);
    Map3D.cone(
      canvas,
      c.translate(0, -12 * s),
      17 * s,
      12 * s,
      _t(b.decorB, 0.1),
      ridge: 0.1,
    );
    canvas.drawRect(
      Rect.fromLTWH(c.dx - 4 * s, c.dy - 9 * s, 8 * s, 9 * s),
      Paint()..color = b.decorB,
    );
    Map3D.glow(
      canvas,
      c.translate(0, -5 * s),
      12 * s,
      const Color(0xFFFFB347),
      strength: 0.35,
    );
  }

  static void _bamboo(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    int variant,
  ) {
    Map3D.shadow(canvas, c.translate(0, 1), 16 * s);
    for (var k = 0; k < 2; k++) {
      final x = c.dx + (k - 0.5) * 6 * s;
      final h = (26 + variant * 5 - k * 6) * s;
      for (var y = 0.0; y < h; y += 7 * s) {
        Map3D.cylinder(
          canvas,
          Offset(x, c.dy - y),
          3.4 * s,
          6.2 * s,
          const Color(0xFF65A30D),
        );
      }
      canvas.drawOval(
        Rect.fromLTWH(x, c.dy - h - 2 * s, 9 * s, 3.4 * s),
        Paint()..color = const Color(0xFF84CC16),
      );
    }
  }

  static void _glowTree(Canvas canvas, MapBiome b, Offset c, double s) {
    Map3D.shadow(canvas, c.translate(0, 2), 30 * s, opacity: 0.35);
    Map3D.cylinder(canvas, c, 5 * s, 14 * s, const Color(0xFF3F3A33));
    Map3D.glow(
      canvas,
      c.translate(0, -24 * s),
      24 * s,
      b.decorB,
      strength: 0.35,
    );
    Map3D.sphere(canvas, c.translate(0, -24 * s), 13 * s, b.decorA);
    final dot = Paint()..color = b.decorC;
    for (final (dx, dy) in [(-6.0, -26.0), (5.0, -20.0), (2.0, -32.0)]) {
      canvas.drawCircle(c.translate(dx * s, dy * s), 1.6 * s, dot);
    }
  }

  static void _glowShroom(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    int variant,
  ) {
    final cap = [b.decorB, b.decorC, b.decorA][variant % 3];
    Map3D.glow(canvas, c.translate(0, -10 * s), 16 * s, cap, strength: 0.4);
    Map3D.shadow(canvas, c.translate(0, 1), 16 * s, opacity: 0.3);
    Map3D.cylinder(canvas, c, 5 * s, 9 * s, const Color(0xFFFFF4E0));
    canvas.drawArc(
      Rect.fromCenter(
        center: c.translate(0, -9 * s),
        width: 18 * s,
        height: 14 * s,
      ),
      math.pi,
      math.pi,
      true,
      Paint()
        ..shader = ui.Gradient.radial(c.translate(-3 * s, -13 * s), 10 * s, [
          _t(cap, 0.4),
          cap,
        ]),
    );
  }

  static void _snowTree(Canvas canvas, MapBiome b, Offset c, double s) {
    Map3D.shadow(
      canvas,
      c.translate(0, 2),
      26 * s,
      opacity: b.dark ? 0.35 : 0.18,
    );
    Map3D.cylinder(canvas, c, 4 * s, 6 * s, const Color(0xFF6B4A2B));
    for (var i = 0; i < 3; i++) {
      final base = c.translate(0, -6 * s - i * 8 * s);
      Map3D.cone(
        canvas,
        base,
        (12 - i * 3) * s,
        14 * s,
        const Color(0xFF2F6D5A),
      );
      Map3D.cone(
        canvas,
        base.translate(0, -7 * s),
        (6 - i * 1.5) * s,
        7 * s,
        Colors.white,
      );
    }
  }

  static void _sunflower(
    Canvas canvas,
    MapBiome b,
    Offset c,
    double s,
    int variant,
  ) {
    final h = (22 + variant * 4) * s;
    canvas.drawLine(
      c,
      c.translate(0, -h),
      Paint()
        ..color = const Color(0xFF4D7C3A)
        ..strokeWidth = 2 * s,
    );
    canvas.drawOval(
      Rect.fromLTWH(c.dx, c.dy - h * 0.5, 8 * s, 3.5 * s),
      Paint()..color = const Color(0xFF65A30D),
    );
    final head = c.translate(0, -h);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      canvas.drawOval(
        Rect.fromCenter(
          center: head + Offset(math.cos(a), math.sin(a)) * 5 * s,
          width: 5 * s,
          height: 5 * s,
        ),
        Paint()
          ..color = i.isEven
              ? const Color(0xFFFDE047)
              : const Color(0xFFF59E0B),
      );
    }
    Map3D.sphere(canvas, head, 3.6 * s, const Color(0xFF7C4A1E), gloss: 0.2);
  }

  static void _hoodoo(Canvas canvas, MapBiome b, Offset c, double s) {
    Map3D.shadow(canvas, c.translate(0, 2), 22 * s);
    for (var i = 0; i < 3; i++) {
      final w = (12 - i * 2) * s;
      Map3D.block(
        canvas,
        Rect.fromCenter(
          center: c.translate(0, -(5 + i * 9) * s),
          width: w,
          height: 9 * s,
        ),
        6 * s,
        i.isEven ? b.terrainNear : _t(b.terrainNear, 0.15),
        radius: 3 * s,
      );
    }
    Map3D.block(
      canvas,
      Rect.fromCenter(
        center: c.translate(0, -31 * s),
        width: 16 * s,
        height: 4 * s,
      ),
      8 * s,
      _s(b.terrainNear, 0.2),
    );
  }

  static void _boat(Canvas canvas, MapBiome b, Offset c, double s) {
    Map3D.shadow(canvas, c.translate(0, 3), 34 * s, opacity: 0.3);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 16 * s, c.dy - 6 * s)
        ..lineTo(c.dx + 16 * s, c.dy - 6 * s)
        ..lineTo(c.dx + 10 * s, c.dy + 2 * s)
        ..lineTo(c.dx - 10 * s, c.dy + 2 * s)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          c.translate(0, -6 * s),
          c.translate(0, 2 * s),
          [const Color(0xFF8B5E3C), const Color(0xFF5B3A22)],
        ),
    );
    canvas.drawLine(
      c.translate(0, -6 * s),
      c.translate(0, -30 * s),
      Paint()
        ..color = const Color(0xFF6B4A2B)
        ..strokeWidth = 1.6 * s,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 1 * s, c.dy - 29 * s)
        ..lineTo(c.dx + 14 * s, c.dy - 9 * s)
        ..lineTo(c.dx + 1 * s, c.dy - 9 * s)
        ..close(),
      Paint()..color = b.decorA,
    );
    Map3D.glow(
      canvas,
      c.translate(-8 * s, -10 * s),
      8 * s,
      b.decorC,
      strength: 0.5,
    );
  }
}
