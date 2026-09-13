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
          if (next.$1 >= 0 && next.$1 < size && next.$2 >= 0 && next.$2 < size) {
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

    // Randomize geometry parameters
    final scale = 0.78 + rng.nextDouble() * 0.16; // 0.78 - 0.94
    final rotationAngle = (rng.nextInt(4)) * (pi / 2.0); // 0, 90, 180, 270 deg
    final flipX = rng.nextBool();
    final flipY = rng.nextBool();
    final starPoints = rng.nextBool() ? 5 : 6;
    final innerRatio = 0.32 + rng.nextDouble() * 0.18; // 0.32 - 0.50
    final outerRadius = 0.88 + rng.nextDouble() * 0.08;

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

    // Ensure minimum size and connected component
    if (mask.length < max(14, gridSize * 2)) {
      for (var r = 0; r < gridSize; r++) {
        for (var c = 0; c < gridSize; c++) {
          final u = (c - cx) / s;
          final v = (cy - r) / s;
          if (max(u.abs(), v.abs()) <= 0.85) {
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
        final maxR = (outerRadius * 0.46) + (outerRadius - outerRadius * 0.46) * (1.0 - psi);
        return rDist <= maxR;

      case PatternType.square:
        return u.abs() <= outerRadius && v.abs() <= outerRadius;

      case PatternType.spiral:
        final spiralR = (theta / (2 * pi) + 1.5) * 0.28;
        final distFromSpiral = (rDist - (spiralR % 0.45)).abs();
        return rDist <= outerRadius && (distFromSpiral <= 0.22 || rDist <= 0.45);

      case PatternType.ring:
        return rDist <= outerRadius && rDist >= (outerRadius * innerRatio);

      case PatternType.diamond:
        return (u.abs() + v.abs()) <= (outerRadius * 1.15);

      case PatternType.starSquare:
        final inSquare = u.abs() <= outerRadius && v.abs() <= outerRadius;
        final angle = (theta - pi / 2) % (2 * pi / starPoints);
        final normalized = angle < 0 ? angle + 2 * pi / starPoints : angle;
        final psi = (normalized - pi / starPoints).abs() / (pi / starPoints);
        final maxR = 0.40 + 0.45 * (1.0 - psi);
        final inStar = rDist <= maxR;
        return inSquare && (inStar || rDist >= 0.62);

      case PatternType.starRing:
        final inRing = rDist <= outerRadius && rDist >= 0.35;
        final angle = (theta - pi / 2) % (2 * pi / 5);
        final normalized = angle < 0 ? angle + 2 * pi / 5 : angle;
        final psi = (normalized - pi / 5).abs() / (pi / 5);
        final inStar = rDist <= (0.45 + 0.35 * (1.0 - psi));
        return inRing || inStar;

      case PatternType.squareRing:
        final inSquare = u.abs() <= outerRadius && v.abs() <= outerRadius;
        final inRingCore = rDist <= 0.82 && rDist >= 0.32;
        return inSquare && inRingCore;

      case PatternType.diamondSpiral:
        final inDiamond = (u.abs() + v.abs()) <= (outerRadius * 1.10);
        return inDiamond;

      case PatternType.interlocked:
        final inOuter = (u.abs() + v.abs()) <= 1.05 && u.abs() <= 0.85 && v.abs() <= 0.85;
        return inOuter;

      case PatternType.randomGeometric:
        final maxR = 0.72 + 0.16 * cos(3 * theta + 0.5) + 0.08 * sin(5 * theta);
        return rDist <= maxR;

      case PatternType.extremeCombination:
        final inSquare = u.abs() <= outerRadius && v.abs() <= outerRadius;
        final inRing = rDist <= 0.85 && rDist >= 0.30;
        return inSquare && inRing;
    }
  }
}
