import 'dart:math';

typedef Cell = (int, int);

/// Available pattern families for procedural level generation.
enum PatternType {
  star,
  square,
  spiral,
  ring,
  diamond,
  starSquare,
  starRing,
  squareRing,
  diamondSpiral,
  interlocked,
  randomGeometric,
  extremeCombination,
  heart,
  butterfly,
  crown,
  cat,
  snake,
  hexagon,
  flower,
  cross,
  infinity,
  lightning,
  rocket,
  bow,
  swirl,
}

enum ShapeType {
  heart,
  circle,
  square,
  rectangle,
  diamond,
  triangle,
  star,
  ring,
  cat,
  dog,
  fish,
  butterfly,
  house,
  tree,
  moon,
  lightning,
  crown,
  gem,
  rocket,
  cloud,
  trophy,
  irregular,
}

/// Generates distinct, recognizable silhouettes for puzzle boards.
class ShapeTemplate {
  final ShapeType type;
  final String name;

  const ShapeTemplate(this.type, this.name);

  static const List<ShapeTemplate> all = [
    ShapeTemplate(ShapeType.heart, 'heart'),
    ShapeTemplate(ShapeType.circle, 'circle'),
    ShapeTemplate(ShapeType.square, 'square'),
    ShapeTemplate(ShapeType.rectangle, 'rectangle'),
    ShapeTemplate(ShapeType.diamond, 'diamond'),
    ShapeTemplate(ShapeType.triangle, 'triangle'),
    ShapeTemplate(ShapeType.star, 'star'),
    ShapeTemplate(ShapeType.ring, 'ring'),
    ShapeTemplate(ShapeType.cat, 'cat'),
    ShapeTemplate(ShapeType.dog, 'dog'),
    ShapeTemplate(ShapeType.fish, 'fish'),
    ShapeTemplate(ShapeType.butterfly, 'butterfly'),
    ShapeTemplate(ShapeType.house, 'house'),
    ShapeTemplate(ShapeType.tree, 'tree'),
    ShapeTemplate(ShapeType.moon, 'moon'),
    ShapeTemplate(ShapeType.lightning, 'lightning'),
    ShapeTemplate(ShapeType.crown, 'crown'),
    ShapeTemplate(ShapeType.gem, 'gem'),
    ShapeTemplate(ShapeType.rocket, 'rocket'),
    ShapeTemplate(ShapeType.cloud, 'cloud'),
    ShapeTemplate(ShapeType.trophy, 'trophy'),
    ShapeTemplate(ShapeType.irregular, 'irregular'),
  ];

  static ShapeTemplate fromName(String name) {
    for (final template in all) {
      if (template.name == name) return template;
    }
    return const ShapeTemplate(ShapeType.square, 'square');
  }

  /// Generates mask cells for shape template.
  Set<Cell> generateMask(int gridSize) {
    return PatternGenerator.generateMask(
      type: PatternType.square,
      gridSize: gridSize,
      rng: Random(42),
    );
  }

  /// Retains the largest orthogonally connected component of cells.
  static Set<Cell> _keepLargestConnectedComponent(Set<Cell> mask, int size) {
    final visited = <Cell>{};
    final components = <List<Cell>>[];

    for (final cell in mask) {
      if (visited.contains(cell)) continue;
      final comp = <Cell>[];
      final queue = [cell];
      visited.add(cell);

      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        comp.add(current);
        for (final delta in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final next = (current.$1 + delta.$1, current.$2 + delta.$2);
          if (next.$1 >= 0 &&
              next.$1 < size &&
              next.$2 >= 0 &&
              next.$2 < size) {
            if (mask.contains(next) && visited.add(next)) {
              queue.add(next);
            }
          }
        }
      }
      components.add(comp);
    }

    if (components.isEmpty) return mask;
    components.sort((a, b) => b.length.compareTo(a.length));
    return components.first.toSet();
  }
}

/// Generates randomized, procedural cell masks for pattern families.
class PatternGenerator {
  PatternGenerator._();

  static Set<Cell> generateMask({
    required PatternType type,
    required int gridSize,
    required Random rng,
  }) {
    final mask = <Cell>{};
    final cx = (gridSize - 1) / 2.0;
    final cy = (gridSize - 1) / 2.0;
    final s = max(1.0, (gridSize - 1) / 2.0);

    // Scale shapes to utilize the playable grid
    final scale = 0.95 + rng.nextDouble() * 0.05;

    // Iconic/asymmetric shapes must NOT be rotated or flipped — rotation
    // destroys recognisability (a flipped heart looks broken, a rotated cat
    // loses its ears, etc.). Only purely symmetric geometric shapes get random
    // rotation.
    const _rotationLocked = {
      PatternType.heart,
      PatternType.cat,
      PatternType.crown,
      PatternType.rocket,
      PatternType.butterfly,
      PatternType.lightning,
      PatternType.infinity,
      PatternType.bow,
      PatternType.snake,
      PatternType.flower,
      PatternType.swirl,
    };

    final bool lockRotation = _rotationLocked.contains(type);
    final rotationAngle = lockRotation ? 0.0 : (rng.nextInt(4)) * (pi / 2.0);
    final flipX = lockRotation ? false : rng.nextBool();
    final flipY = lockRotation ? false : rng.nextBool();

    final starPoints = rng.nextBool() ? 5 : 6;
    final innerRatio = 0.12 + rng.nextDouble() * 0.08;
    final outerRadius = 0.94 + rng.nextDouble() * 0.04;

    final cosA = cos(rotationAngle);
    final sinA = sin(rotationAngle);

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        var u = (c - cx) / s;
        var v = (cy - r) / s;

        // Apply scale
        u /= scale;
        v /= scale;

        // Apply rotation
        var uRot = u * cosA - v * sinA;
        var vRot = u * sinA + v * cosA;

        // Apply flips
        if (flipX) uRot = -uRot;
        if (flipY) vRot = -vRot;

        if (_isInsidePattern(
          uRot,
          vRot,
          type,
          starPoints,
          innerRatio,
          outerRadius,
          rng,
        )) {
          mask.add((r, c));
        }
      }
    }

    // Ensure minimum size and connected component (at least ~48% of grid cells)
    final minMaskCells = (gridSize * gridSize * 0.48).round();
    if (mask.length < minMaskCells) {
      for (var r = 0; r < gridSize; r++) {
        for (var c = 0; c < gridSize; c++) {
          final u = (c - cx) / s;
          final v = (cy - r) / s;
          if (max(u.abs(), v.abs()) <= 0.88) {
            mask.add((r, c));
          }
        }
      }
    }

    return ShapeTemplate._keepLargestConnectedComponent(mask, gridSize);
  }

  static bool _isInsidePattern(
    double u,
    double v,
    PatternType type,
    int starPoints,
    double innerRatio,
    double outerRadius,
    Random rng,
  ) {
    final rDist = sqrt(u * u + v * v);
    final theta = atan2(v, u);

    switch (type) {
      case PatternType.star:
        final angle = (theta - pi / 2) % (2 * pi / starPoints);
        final normalized = angle < 0 ? angle + 2 * pi / starPoints : angle;
        final psi = (normalized - pi / starPoints).abs() / (pi / starPoints);
        final maxR =
            (outerRadius * 0.55) +
            (outerRadius - outerRadius * 0.35) * (1.0 - psi);
        return rDist <= maxR;

      case PatternType.square:
        return u.abs() <= outerRadius && v.abs() <= outerRadius;

      case PatternType.spiral:
        final spiralR = (theta / (2 * pi) + 1.5) * 0.32;
        final distFromSpiral = (rDist - (spiralR % 0.50)).abs();
        return rDist <= outerRadius &&
            (distFromSpiral <= 0.28 || rDist <= 0.52);

      case PatternType.ring:
        return rDist <= outerRadius && rDist >= (outerRadius * innerRatio);

      case PatternType.diamond:
        return (u.abs() + v.abs()) <= (outerRadius * 1.25);

      case PatternType.starSquare:
        final inSquare = u.abs() <= outerRadius && v.abs() <= outerRadius;
        final angle = (theta - pi / 2) % (2 * pi / starPoints);
        final normalized = angle < 0 ? angle + 2 * pi / starPoints : angle;
        final psi = (normalized - pi / starPoints).abs() / (pi / starPoints);
        final maxR = 0.50 + 0.45 * (1.0 - psi);
        final inStar = rDist <= maxR;
        return inSquare && (inStar || rDist >= 0.50);

      case PatternType.starRing:
        final inRing = rDist <= outerRadius && rDist >= 0.28;
        final angle = (theta - pi / 2) % (2 * pi / 5);
        final normalized = angle < 0 ? angle + 2 * pi / 5 : angle;
        final psi = (normalized - pi / 5).abs() / (pi / 5);
        final inStar = rDist <= (0.50 + 0.42 * (1.0 - psi));
        return inRing || inStar;

      case PatternType.squareRing:
        final inSquare = u.abs() <= outerRadius && v.abs() <= outerRadius;
        final inRingCore = rDist <= 0.90 && rDist >= 0.22;
        return inSquare && inRingCore;

      case PatternType.diamondSpiral:
        final inDiamond = (u.abs() + v.abs()) <= (outerRadius * 1.25);
        return inDiamond;

      case PatternType.interlocked:
        final inOuter =
            (u.abs() + v.abs()) <= 1.20 && u.abs() <= 0.92 && v.abs() <= 0.92;
        return inOuter;

      case PatternType.randomGeometric:
        final maxR = 0.82 + 0.14 * cos(3 * theta + 0.5) + 0.06 * sin(5 * theta);
        return rDist <= maxR;

      case PatternType.extremeCombination:
        final inSquare = u.abs() <= outerRadius && v.abs() <= outerRadius;
        final inRing = rDist <= 0.92 && rDist >= 0.22;
        return inSquare && inRing;

      case PatternType.heart:
        final x = u * 1.05;
        final y = v * 1.05 + 0.12;
        final a = x * x + y * y - 0.75;
        return (a * a * a - x * x * y * y * y) <= 0.0;

      case PatternType.butterfly:
        final wing = 0.68 + 0.30 * cos(2 * theta).abs();
        return rDist <= wing && u.abs() <= 0.95 && v.abs() <= 0.92;

      case PatternType.crown:
        final inBody = u.abs() <= 0.90 && v >= -0.80 && v <= 0.35;
        final inSpike = v > 0.35 && (v - 0.35) <= (0.60 - u.abs() * 0.4);
        return inBody || inSpike;

      case PatternType.cat:
        final inHead = rDist <= 0.82;
        final inLeftEar =
            u <= -0.18 && u >= -0.85 && v >= 0.25 && v <= (1.05 + (u + 0.5) * 1.2);
        final inRightEar =
            u >= 0.18 && u <= 0.85 && v >= 0.25 && v <= (1.05 - (u - 0.5) * 1.2);
        return inHead || inLeftEar || inRightEar;

      case PatternType.snake:
        final sY = sin(u * pi * 1.5) * 0.40;
        return u.abs() <= 0.94 && (v - sY).abs() <= 0.52;

      case PatternType.hexagon:
        return u.abs() <= 0.92 && (u.abs() * 0.5 + v.abs() * 0.866) <= 0.92;

      case PatternType.flower:
        final fR = 0.68 + 0.28 * cos(4 * theta).abs();
        return rDist <= fR;

      case PatternType.cross:
        return (u.abs() <= 0.46 && v.abs() <= 0.94) ||
            (u.abs() <= 0.94 && v.abs() <= 0.46);

      case PatternType.infinity:
        final inf = pow(u * u + v * v, 2) - 0.95 * (u * u - v * v);
        return inf <= 0.35 && u.abs() <= 0.96 && v.abs() <= 0.75;

      case PatternType.lightning:
        final inMain = (u - v * 0.45).abs() <= 0.48 && v.abs() <= 0.90;
        final inBolt = (u + v * 0.35).abs() <= 0.48 && v.abs() <= 0.90;
        return inMain || inBolt;

      case PatternType.rocket:
        final inBody = u.abs() <= 0.55 && v.abs() <= 0.80;
        final inNose = v > 0.4 && v <= (1.05 - u.abs() * 1.1);
        final inFin = v < -0.25 && u.abs() <= (0.92 - (v + 0.7).abs() * 0.8);
        return inBody || inNose || inFin;

      case PatternType.bow:
        return (u.abs() >= v.abs() * 0.35 &&
                u.abs() <= 0.92 &&
                v.abs() <= 0.82) ||
            rDist <= 0.48;

      case PatternType.swirl:
        final swirlR = 0.65 + 0.32 * sin(theta * 2 + rDist * 3).abs();
        return rDist <= swirlR && rDist <= 0.95;
    }
  }
}
