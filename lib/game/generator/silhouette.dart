import 'dart:math';

typedef _Cell = (int, int);

/// Broad family a silhouette belongs to (used for variety and UI copy).
enum SilhouetteCategory { animal, vehicle, object, nature, abstract }

/// One vector building block of a silhouette, in a unit design canvas:
/// x grows to the right, y grows downwards, both in 0..1.
abstract class SilPart {
  const SilPart();

  bool contains(double x, double y);
}

/// Ellipse centred at ([cx], [cy]) with radii [rx]/[ry], rotated [rotDeg]
/// degrees clockwise.
class SEllipse extends SilPart {
  final double cx, cy, rx, ry, rotDeg;

  const SEllipse(this.cx, this.cy, this.rx, [double? ry, this.rotDeg = 0])
    : ry = ry ?? rx;

  @override
  bool contains(double x, double y) {
    var dx = x - cx;
    var dy = y - cy;
    if (rotDeg != 0) {
      final a = -rotDeg * pi / 180;
      final c = cos(a), s = sin(a);
      final rx0 = dx * c - dy * s;
      dy = dx * s + dy * c;
      dx = rx0;
    }
    final u = dx / rx, v = dy / ry;
    return u * u + v * v <= 1;
  }
}

/// Axis-aligned rectangle with optional corner radius [r].
class SRect extends SilPart {
  final double x0, y0, x1, y1, r;

  const SRect(this.x0, this.y0, this.x1, this.y1, [this.r = 0]);

  @override
  bool contains(double x, double y) {
    if (x < x0 || x > x1 || y < y0 || y > y1) return false;
    if (r <= 0) return true;
    final qx = x.clamp(x0 + r, x1 - r);
    final qy = y.clamp(y0 + r, y1 - r);
    final dx = x - qx, dy = y - qy;
    return dx * dx + dy * dy <= r * r;
  }
}

/// Polygon given as a flat list of x, y pairs (even-odd fill).
class SPoly extends SilPart {
  final List<double> pts;

  const SPoly(this.pts);

  @override
  bool contains(double x, double y) {
    var inside = false;
    final n = pts.length ~/ 2;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = pts[2 * i], yi = pts[2 * i + 1];
      final xj = pts[2 * j], yj = pts[2 * j + 1];
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// Thick line segment with round ends ("capsule") of total width [w].
class SLine extends SilPart {
  final double x0, y0, x1, y1, w;

  const SLine(this.x0, this.y0, this.x1, this.y1, this.w);

  @override
  bool contains(double x, double y) {
    final dx = x1 - x0, dy = y1 - y0;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((x - x0) * dx + (y - y0) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final px = x0 + t * dx - x, py = y0 + t * dy - y;
    return px * px + py * py <= (w / 2) * (w / 2);
  }
}

/// Removes [part] from everything drawn before it (eyes, windows, wheel hubs).
class Cut extends SilPart {
  final SilPart part;

  const Cut(this.part);

  @override
  bool contains(double x, double y) => part.contains(x, y);
}

/// Result of rasterizing a silhouette onto a grid.
class SilhouetteMask {
  /// Cells the arrows may use: the largest 4-connected piece of the shape.
  final Set<(int, int)> cells;

  /// Cells of the raw raster that were not connected to the main piece.
  final int droppedCells;

  const SilhouetteMask(this.cells, this.droppedCells);
}

/// A recognizable picture (animal, vehicle, object…) that a puzzle board is
/// built in. The arrows themselves fill the shape; cells outside it stay
/// empty, so the silhouette is visible before the first move.
class Silhouette {
  final String id;
  final String name;
  final SilhouetteCategory category;

  /// Smallest board on which the details still read clearly. Detailed shapes
  /// (bicycle, castle…) only appear once the campaign reaches bigger boards.
  final int minGrid;

  /// Whether the shape may be mirrored left↔right for variety.
  final bool mirrorable;

  /// Drawing operations applied in order; [Cut] parts erase.
  final List<SilPart> parts;

  const Silhouette({
    required this.id,
    required this.name,
    required this.category,
    required this.minGrid,
    required this.parts,
    this.mirrorable = true,
  });

  bool contains(double x, double y) {
    var inside = false;
    for (final p in parts) {
      if (p is Cut) {
        if (inside && p.contains(x, y)) inside = false;
      } else if (!inside && p.contains(x, y)) {
        inside = true;
      }
    }
    return inside;
  }

  // 3×3 supersampling per cell; a cell belongs to the shape when at least
  // 4 of 9 samples are inside, which keeps thin legs and tails.
  static const List<double> _samples = [1 / 6, 0.5, 5 / 6];
  static const int _minHits = 4;

  /// Draws the silhouette onto a [gridSize] board, using the whole board with
  /// a half-cell margin, and keeps the largest 4-connected piece so every
  /// part of the picture is reachable by arrow paths.
  SilhouetteMask rasterize(int gridSize, {bool mirror = false}) {
    const pad = 0.5;
    final span = gridSize - 2 * pad;
    final raw = <_Cell>{};
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        var hits = 0;
        for (final sy in _samples) {
          for (final sx in _samples) {
            var x = (c + sx - pad) / span;
            final y = (r + sy - pad) / span;
            if (mirror) x = 1 - x;
            if (contains(x, y)) hits++;
          }
        }
        if (hits >= _minHits) raw.add((r, c));
      }
    }
    final main = _largestComponent(raw);
    return SilhouetteMask(main, raw.length - main.length);
  }

  /// How faithfully a [gridSize] board shows this picture, measured on 6×6
  /// sample points per cell:
  /// * `iou`: overlap of the vector picture and the playable cells
  ///   (intersection over union, 1 = identical);
  /// * `worstPart`: the smallest share of any drawn part (ear, wheel, tail,
  ///   wing…) that lands on playable cells, over parts showing at least
  ///   [minPartCells] cells of area; `worstPartIndex` names it in [parts].
  ///
  /// A low `worstPart` means a detail vanished or was cut off at this size.
  ({double iou, double worstPart, int worstPartIndex}) fidelity(
    int gridSize, {
    bool mirror = false,
    double minPartCells = 1.5,
  }) {
    const k = 6;
    const pad = 0.5;
    final span = gridSize - 2 * pad;
    final mask = rasterize(gridSize, mirror: mirror).cells;
    var both = 0, either = 0;
    final visible = List.filled(parts.length, 0);
    final kept = List.filled(parts.length, 0);
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final inMask = mask.contains((r, c));
        for (var sy = 0; sy < k; sy++) {
          for (var sx = 0; sx < k; sx++) {
            var x = (c + (sx + 0.5) / k - pad) / span;
            final y = (r + (sy + 0.5) / k - pad) / span;
            if (mirror) x = 1 - x;
            final inShape = contains(x, y);
            if (inShape && inMask) both++;
            if (inShape || inMask) either++;
            if (!inShape) continue;
            for (var i = 0; i < parts.length; i++) {
              final p = parts[i];
              if (p is Cut || !p.contains(x, y)) continue;
              visible[i]++;
              if (inMask) kept[i]++;
            }
          }
        }
      }
    }
    var worst = 1.0;
    var worstIndex = -1;
    for (var i = 0; i < parts.length; i++) {
      if (visible[i] < minPartCells * k * k) continue;
      final share = kept[i] / visible[i];
      if (share < worst) {
        worst = share;
        worstIndex = i;
      }
    }
    return (
      iou: either == 0 ? 0.0 : both / either,
      worstPart: worst,
      worstPartIndex: worstIndex,
    );
  }

  static Set<_Cell> _largestComponent(Set<_Cell> cells) {
    final seen = <_Cell>{};
    var best = <_Cell>{};
    for (final start in cells) {
      if (seen.contains(start)) continue;
      final comp = <_Cell>{start};
      seen.add(start);
      final stack = [start];
      while (stack.isNotEmpty) {
        final (r, c) = stack.removeLast();
        for (final n in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
          if (cells.contains(n) && seen.add(n)) {
            comp.add(n);
            stack.add(n);
          }
        }
      }
      if (comp.length > best.length) best = comp;
    }
    return best;
  }

  /// ASCII preview, handy in tests and when designing new shapes.
  String preview(int gridSize, {bool mirror = false}) {
    final m = rasterize(gridSize, mirror: mirror).cells;
    final b = StringBuffer();
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        b.write(m.contains((r, c)) ? '██' : '··');
      }
      b.writeln();
    }
    return b.toString();
  }
}

/// Capsules joining consecutive points: smooth curved bodies (snake, spiral).
List<SilPart> strokePath(List<(double, double)> points, double width) => [
  for (var i = 1; i < points.length; i++)
    SLine(
      points[i - 1].$1,
      points[i - 1].$2,
      points[i].$1,
      points[i].$2,
      width,
    ),
];
