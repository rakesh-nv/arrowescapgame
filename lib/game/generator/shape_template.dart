import 'dart:math';

typedef Cell = (int, int);

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
/// The shape forms the outer boundary; inside cells are packed with dense paths.
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

  /// Generates the set of usable (row, col) cells for this shape on a [gridSize]x[gridSize] grid.
  Set<Cell> generateMask(int gridSize) {
    final mask = <Cell>{};
    final cx = (gridSize - 1) / 2.0;
    final cy = (gridSize - 1) / 2.0;
    final s = max(1.0, (gridSize - 1) / 2.0);

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final u = (c - cx) / s; // [-1.0, 1.0], right is positive
        final v = (cy - r) / s; // [-1.0, 1.0], up is positive
        if (_isInside(u, v, r, c, gridSize)) {
          mask.add((r, c));
        }
      }
    }

    // Guard: Ensure shape mask is not empty and forms a solid component.
    // If grid is too small or mask is too sparse, fall back to rounded rectangle.
    if (mask.length < max(12, gridSize * 2)) {
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

    return _keepLargestConnectedComponent(mask, gridSize);
  }

  bool _isInside(double u, double v, int r, int c, int size) {
    final rDist = sqrt(u * u + v * v);
    final theta = atan2(v, u);

    switch (type) {
      case ShapeType.square:
        return u.abs() <= 0.90 && v.abs() <= 0.90;

      case ShapeType.rectangle:
        return u.abs() <= 0.94 && v.abs() <= 0.72;

      case ShapeType.circle:
        return rDist <= 0.92;

      case ShapeType.ring:
        return rDist <= 0.92 && rDist >= 0.38;

      case ShapeType.diamond:
        return (u.abs() + v.abs()) <= 1.05;

      case ShapeType.triangle:
        return v >= -0.85 && u.abs() <= 0.92 * (0.92 - v) / 1.77;

      case ShapeType.heart:
        final vAdj = v - 0.18;
        final a = u * u + vAdj * vAdj - 0.72;
        return (a * a * a - u * u * vAdj * vAdj * vAdj) <= 0.0 && v >= -0.88 && v <= 0.88;

      case ShapeType.star:
        // 5-pointed star
        const points = 5;
        final angle = (theta - pi / 2) % (2 * pi / points);
        final normalized = (angle < 0 ? angle + 2 * pi / points : angle);
        final psi = (normalized - pi / points).abs() / (pi / points);
        final maxR = 0.44 + (0.94 - 0.44) * (1.0 - psi);
        return rDist <= maxR;

      case ShapeType.cat:
        // Large head + wide triangular ears + chin
        final inHead = (u * u + (v + 0.05) * (v + 0.05)) <= (0.72 * 0.72);
        final inChin = u.abs() <= 0.50 && v >= -0.92 && v <= -0.30;
        final inLeftEar = u >= -0.80 && u <= -0.10 && v >= 0.42 && v <= 0.92 &&
            (u + 0.45).abs() <= 0.36 * (0.92 - v) / 0.50;
        final inRightEar = u >= 0.10 && u <= 0.80 && v >= 0.42 && v <= 0.92 &&
            (u - 0.45).abs() <= 0.36 * (0.92 - v) / 0.50;
        return inHead || inChin || inLeftEar || inRightEar;

      case ShapeType.dog:
        // Wide head + large snout + big floppy ears (fills ~60% of grid)
        final inFace = (u * u + (v + 0.04) * (v + 0.04)) <= (0.66 * 0.66);
        final inSnout = u.abs() <= 0.48 && v >= -0.90 && v <= -0.02;
        final inLeftEar = u >= -0.92 && u <= -0.36 && v >= -0.60 && v <= 0.60;
        final inRightEar = u >= 0.36 && u <= 0.92 && v >= -0.60 && v <= 0.60;
        return inFace || inSnout || inLeftEar || inRightEar;

      case ShapeType.fish:
        // Wide elliptical body + large triangular tail + dorsal fin
        final inBody = ((u + 0.10) * (u + 0.10)) / (0.62 * 0.62) + (v * v) / (0.52 * 0.52) <= 1.0;
        final inTail = u >= 0.28 && u <= 0.92 && v.abs() <= 0.80 * (u - 0.28) / 0.64;
        final inDorsal = u >= -0.28 && u <= 0.20 && v >= 0.38 && v <= 0.86 &&
            (u + 0.04).abs() <= 0.30 * (0.86 - v) / 0.48;
        return inBody || inTail || inDorsal;

      case ShapeType.butterfly:
        // Central body + 4 wings
        final inBody = u.abs() <= 0.15 && v.abs() <= 0.84;
        final inTopWings = (u.abs() - 0.48) * (u.abs() - 0.48) / (0.44 * 0.44) +
            (v - 0.30) * (v - 0.30) / (0.48 * 0.48) <= 1.0;
        final inBottomWings = (u.abs() - 0.42) * (u.abs() - 0.42) / (0.38 * 0.38) +
            (v + 0.36) * (v + 0.36) / (0.38 * 0.38) <= 1.0;
        return inBody || inTopWings || inBottomWings;

      case ShapeType.house:
        // Square walls + triangular roof + chimney
        final inWalls = u.abs() <= 0.78 && v >= -0.86 && v <= 0.18;
        final inRoof = v >= 0.18 && v <= 0.90 && u.abs() <= 0.88 * (0.90 - v) / 0.72;
        final inChimney = u >= 0.36 && u <= 0.62 && v >= 0.30 && v <= 0.84;
        return inWalls || inRoof || inChimney;

      case ShapeType.tree:
        // Foliage + trunk
        final inTrunk = u.abs() <= 0.20 && v >= -0.88 && v <= -0.25;
        final inTier1 = v >= -0.38 && v <= 0.22 && u.abs() <= 0.84 * (0.22 - v) / 0.60 + 0.10;
        final inTier2 = v >= 0.10 && v <= 0.88 && u.abs() <= 0.68 * (0.88 - v) / 0.78;
        return inTrunk || inTier1 || inTier2;

      case ShapeType.moon:
        // Wider crescent moon — smaller cutout so more cells remain
        final inOuter = rDist <= 0.92;
        final inCutout = ((u - 0.30) * (u - 0.30) + (v - 0.08) * (v - 0.08)) < (0.60 * 0.60);
        return inOuter && (!inCutout || u < -0.15);

      case ShapeType.lightning:
        // Wide zigzag bolt
        if (v >= 0.15 && v <= 0.90) {
          final centerU = 0.12 + (v - 0.15) * 0.22;
          return (u - centerU).abs() <= 0.50;
        } else if (v >= -0.22 && v <= 0.25) {
          return u >= -0.70 && u <= 0.65;
        } else {
          final centerU = -0.15 + (v + 0.88) * 0.35;
          final width = 0.12 + 0.30 * (v + 0.88) / 0.68;
          return (u - centerU).abs() <= width;
        }

      case ShapeType.crown:
        // Band + 3 peaks
        final inBand = u.abs() <= 0.84 && v >= -0.84 && v <= -0.28;
        final inCenterPeak = u.abs() <= 0.32 * (0.90 - v) / 0.62 && v >= -0.28 && v <= 0.90;
        final inLeftPeak = (u + 0.54).abs() <= 0.28 * (0.74 - v) / 0.52 && v >= -0.28 && v <= 0.74;
        final inRightPeak = (u - 0.54).abs() <= 0.28 * (0.74 - v) / 0.52 && v >= -0.28 && v <= 0.74;
        return inBand || inCenterPeak || inLeftPeak || inRightPeak;

      case ShapeType.gem:
        // Faceted diamond silhouette
        if (v > 0.68 || v < -0.88) return false;
        if (v >= 0.18) {
          return u.abs() <= 0.54 + 0.34 * (0.68 - v) / 0.50;
        } else {
          return u.abs() <= 0.88 * (v + 0.88) / 1.06;
        }

      case ShapeType.rocket:
        // Body + nose cone + side fins
        final inFuselage = u.abs() <= 0.35 && v >= -0.58 && v <= 0.44;
        final inNose = v >= 0.44 && v <= 0.92 && u.abs() <= 0.35 * (0.92 - v) / 0.48;
        final inLeftFin = u >= -0.84 && u <= -0.28 && v >= -0.86 && v <= -0.20 &&
            (u + 0.28).abs() <= 0.56 * (-0.20 - v) / 0.66;
        final inRightFin = u >= 0.28 && u <= 0.84 && v >= -0.86 && v <= -0.20 &&
            (u - 0.28).abs() <= 0.56 * (-0.20 - v) / 0.66;
        return inFuselage || inNose || inLeftFin || inRightFin;

      case ShapeType.cloud:
        // Flat bottom + 3 fluffy arcs
        final inFlatBottom = v >= -0.42 && v <= 0.05 && u.abs() <= 0.85;
        final inLeftArc = ((u + 0.44) * (u + 0.44)) / (0.40 * 0.40) + (v * v) / (0.40 * 0.40) <= 1.0;
        final inCenterArc = (u * u) / (0.50 * 0.50) + ((v - 0.18) * (v - 0.18)) / (0.50 * 0.50) <= 1.0;
        final inRightArc = ((u - 0.44) * (u - 0.44)) / (0.40 * 0.40) + (v * v) / (0.40 * 0.40) <= 1.0;
        return inFlatBottom || inLeftArc || inCenterArc || inRightArc;

      case ShapeType.trophy:
        // Cup + 2 handles + stem + base
        final inCup = u.abs() <= 0.54 && v >= -0.16 && v <= 0.78;
        final inLeftHandle = u <= -0.36 && u >= -0.82 &&
            ((u + 0.59) * (u + 0.59)) / (0.24 * 0.24) + ((v - 0.34) * (v - 0.34)) / (0.32 * 0.32) <= 1.0;
        final inRightHandle = u >= 0.36 && u <= 0.82 &&
            ((u - 0.59) * (u - 0.59)) / (0.24 * 0.24) + ((v - 0.34) * (v - 0.34)) / (0.32 * 0.32) <= 1.0;
        final inStem = u.abs() <= 0.18 && v >= -0.56 && v <= -0.16;
        final inBase = u.abs() <= 0.68 && v >= -0.86 && v <= -0.56;
        return inCup || inLeftHandle || inRightHandle || inStem || inBase;

      case ShapeType.irregular:
        // Organic undulating blob
        final maxR = 0.70 + 0.18 * cos(3 * theta + 0.6) + 0.10 * sin(5 * theta - 0.3);
        return rDist <= maxR;
    }
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
