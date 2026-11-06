import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../../data/models/arrow_model.dart';
import '../config/puzzle_config.dart';
import 'arrow_painter.dart';

/// Timing of a crash: the arrow travels toward the obstacle, stops on
/// contact, holds briefly, then slides back. Shared by the board animation
/// and [GameplayController] so the sound and vibration land on the contact.
class CrashTiming {
  CrashTiming._();

  /// Travel time for an obstacle [cells] cells ahead of the head.
  static int travelMs(int cells) => (60 + 35 * cells).clamp(110, 400);
  static const int impactHoldMs = 160;
  static const int returnMs = 200;
  static int totalMs(int cells) => travelMs(cells) + impactHoldMs + returnMs;
  static const int maxTotalMs = 400 + impactHoldMs + returnMs;
}

/// How far a tapped arrow can travel before it touches another arrow (or its
/// own body), measured on the shapes exactly as [ArrowPainter] draws them:
/// round-capped shafts, rounded bends and the triangular arrowhead.
///
/// Whether a tap crashes is still decided by the grid rule
/// ([LevelSolver.firstCollision]); this only finds where the visible contact
/// happens, so the moving arrow stops there and never passes through.
class ArrowCollision {
  ArrowCollision._();

  /// Head travel per marching step, in cells. Thinner than any obstacle
  /// (a shaft is 0.2 cell), so no contact can be stepped over.
  static const double _step = 0.1;

  /// Own body within this arc distance (cells) behind the head is the head's
  /// own shaft, not something it can crash into.
  static const double _ownNeck = 0.6;

  /// Cells from [arrow]'s head to the first occupied cell in its exit lane
  /// (own body included), or null when the lane is clear to the edge.
  static int? laneCellsToCollision(
    ArrowModel arrow,
    List<ArrowModel> remaining,
    int gridSize,
  ) {
    final owned = <(int, int)>{for (final a in remaining) ...a.occupiedCells};
    final dir = arrow.exitDirection;
    var r = arrow.headRow + dir.dRow;
    var c = arrow.headCol + dir.dCol;
    var k = 1;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      if (owned.contains((r, c))) return k;
      r += dir.dRow;
      c += dir.dCol;
      k++;
    }
    return null;
  }

  /// Scene pixels [arrow] travels (its snake shift) before it touches another
  /// arrow of [remaining] or its own body, or null when its lane is clear.
  static double? crashTravel({
    required ArrowModel arrow,
    required List<ArrowModel> remaining,
    required int gridSize,
    required double cellSize,
  }) {
    final cells = laneCellsToCollision(arrow, remaining, gridSize);
    if (cells == null) return null;
    // Static (tap-time) rule distance, used if the shapes never meet: the
    // tip stops at the near edge of the first occupied lane cell.
    final fallback = math.max(0.0, (cells - 0.75) * cellSize);
    return contactDistance(
          arrow: arrow,
          remaining: remaining,
          cellSize: cellSize,
          limit: (cells + 1) * cellSize,
        ) ??
        fallback;
  }

  /// The largest snake shift (px) at which [arrow] still does not touch any
  /// other arrow of [remaining] or its own body, if a contact happens within
  /// [limit] px of travel; null when it travels [limit] px touching nothing.
  static double? contactDistance({
    required ArrowModel arrow,
    required List<ArrowModel> remaining,
    required double cellSize,
    required double limit,
  }) {
    final mover = _Rendered(arrow, cellSize);
    final index = _ObstacleIndex(cellSize);
    for (final other in remaining) {
      if (other.id == arrow.id) continue;
      index.addShape(_Rendered(other, cellSize).at(0));
    }

    bool hits(double d) {
      final shape = mover.at(d);
      return index.hits(shape) || _hitsOwnBody(shape, cellSize);
    }

    if (hits(0)) return 0;
    final step = _step * cellSize;
    var free = 0.0;
    for (var d = step; d <= limit + 1e-9; d += step) {
      if (!hits(d)) {
        free = d;
        continue;
      }
      // Narrow down to under half a pixel; stop on the free side.
      var hit = d;
      while (hit - free > 0.5) {
        final mid = (free + hit) / 2;
        if (hits(mid)) {
          hit = mid;
        } else {
          free = mid;
        }
      }
      return free;
    }
    return null;
  }

  /// The head (and its front shaft) against the same arrow's body at the
  /// same moment of the move, excluding the neck right behind the head.
  static bool _hitsOwnBody(_Shape shape, double cellSize) {
    final neck = _ownNeck * cellSize;
    for (final seg in shape.segs) {
      if (math.max(seg.backA, seg.backB) <= neck) continue;
      var a = seg.a;
      var b = seg.b;
      // Keep only the part farther than the neck from the head.
      if (seg.backA < neck) {
        a = Offset.lerp(
          seg.a,
          seg.b,
          (neck - seg.backA) / (seg.backB - seg.backA),
        )!;
      } else if (seg.backB < neck) {
        b = Offset.lerp(
          seg.a,
          seg.b,
          (seg.backA - neck) / (seg.backA - seg.backB),
        )!;
      }
      if (_segTriDist(a, b, shape.tri) <= shape.radius) return true;
    }
    return false;
  }
}

/// One arrow's rendered outline at any snake shift: a centreline (stroked
/// with round caps and joins) plus the filled head triangle.
class _Rendered {
  final double cellSize;
  final double radius;
  final double headSize;
  final ArrowMotionPath path;
  final Offset exit;

  /// Centreline points of the unshifted body with their arc length.
  final List<Offset> _pts = [];
  final List<double> _arc = [];

  _Rendered(ArrowModel arrow, this.cellSize)
    : radius = PuzzleConfig.strokeWidthFor(cellSize) / 2,
      headSize = PuzzleConfig.headSizeFor(cellSize),
      path = ArrowMotionPath.build(arrow: arrow, cellSize: cellSize),
      exit = Offset(
        arrow.exitDirection.dCol.toDouble(),
        arrow.exitDirection.dRow.toDouble(),
      ) {
    // Fine samples, then drop points on straight runs: bends keep a few
    // points along their arc, straight shafts become single segments.
    final length = path.length;
    final n = math.max(1, (length / (cellSize * 0.05)).ceil());
    for (var i = 0; i <= n; i++) {
      final s = length * i / n;
      final p = path.pointAt(s);
      if (_pts.length >= 2) {
        final u = _pts[_pts.length - 1] - _pts[_pts.length - 2];
        final v = p - _pts[_pts.length - 1];
        final cross = u.dx * v.dy - u.dy * v.dx;
        final dot = u.dx * v.dx + u.dy * v.dy;
        if (cross.abs() < 1e-6 * u.distance * v.distance && dot > 0) {
          _pts[_pts.length - 1] = p;
          _arc[_arc.length - 1] = s;
          continue;
        }
      }
      _pts.add(p);
      _arc.add(s);
    }
  }

  /// The shape after the snake has moved [d] pixels (as [ArrowPainter] draws
  /// it for that shift).
  _Shape at(double d) {
    final length = path.length;
    final headAt = length + d; // arc position of the head point
    final pts = <Offset>[];
    final arcs = <double>[];
    if (d < length) {
      pts.add(path.pointAt(d));
      arcs.add(d);
      for (var i = 0; i < _pts.length; i++) {
        if (_arc[i] > d) {
          pts.add(_pts[i]);
          arcs.add(_arc[i]);
        }
      }
    }
    final head = path.pointAt(headAt);
    pts.add(head);
    arcs.add(headAt);

    final tip = head + exit * (cellSize * 0.25);
    final lineEnd = tip - exit * (headSize * 0.7);
    final normal = Offset(-exit.dy, exit.dx);
    final base = tip - exit * headSize;
    final half = headSize * 0.48;

    final segs = <_Seg>[
      for (var i = 0; i + 1 < pts.length; i++)
        _Seg(pts[i], pts[i + 1], headAt - arcs[i], headAt - arcs[i + 1]),
      _Seg(head, lineEnd, 0, 0),
    ];
    return _Shape(
      segs: segs,
      tri: [tip, base + normal * half, base - normal * half],
      radius: radius,
    );
  }
}

class _Seg {
  final Offset a;
  final Offset b;

  /// Arc distance from the head point back to [a] and to [b].
  final double backA;
  final double backB;

  _Seg(this.a, this.b, this.backA, this.backB);

  Rect bounds(double pad) => Rect.fromPoints(a, b).inflate(pad);
}

class _Shape {
  final List<_Seg> segs;
  final List<Offset> tri;
  final double radius;

  _Shape({required this.segs, required this.tri, required this.radius});
}

/// Obstacle outlines bucketed by board cell, so each test only looks at the
/// pieces near it.
class _ObstacleIndex {
  final double cellSize;
  final Map<(int, int), List<_Piece>> _buckets = {};

  _ObstacleIndex(this.cellSize);

  void addShape(_Shape shape) {
    for (final s in shape.segs) {
      _add(_Piece.seg(s.a, s.b, shape.radius), s.bounds(shape.radius));
    }
    _add(_Piece.tri(shape.tri), _triBounds(shape.tri));
  }

  void _add(_Piece piece, Rect box) {
    for (final key in _keys(box)) {
      (_buckets[key] ??= []).add(piece);
    }
  }

  Iterable<(int, int)> _keys(Rect box) sync* {
    final c0 = (box.left / cellSize).floor();
    final c1 = (box.right / cellSize).floor();
    final r0 = (box.top / cellSize).floor();
    final r1 = (box.bottom / cellSize).floor();
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        yield (r, c);
      }
    }
  }

  bool hits(_Shape mover) {
    final seen = <_Piece>{};
    bool near(Rect box, bool Function(_Piece) check) {
      seen.clear();
      for (final key in _keys(box)) {
        final bucket = _buckets[key];
        if (bucket == null) continue;
        for (final p in bucket) {
          if (seen.add(p) && p.box.overlaps(box) && check(p)) return true;
        }
      }
      return false;
    }

    for (final s in mover.segs) {
      if (near(
        s.bounds(mover.radius),
        (p) => p.hitsSeg(s.a, s.b, mover.radius),
      )) {
        return true;
      }
    }
    return near(_triBounds(mover.tri), (p) => p.hitsTri(mover.tri));
  }
}

/// One obstacle piece: a round-capped stroke segment or a filled triangle.
class _Piece {
  final Offset a;
  final Offset b;
  final double radius;
  final List<Offset>? tri;
  final Rect box;

  _Piece.seg(this.a, this.b, this.radius)
    : tri = null,
      box = Rect.fromPoints(a, b).inflate(radius);

  _Piece.tri(List<Offset> t)
    : a = t[0],
      b = t[1],
      radius = 0,
      tri = t,
      box = _triBounds(t);

  bool hitsSeg(Offset p, Offset q, double r) {
    final t = tri;
    if (t != null) return _segTriDist(p, q, t) <= r;
    return _segSegDist(a, b, p, q) <= radius + r;
  }

  bool hitsTri(List<Offset> other) {
    final t = tri;
    if (t != null) return _triTriOverlap(t, other);
    return _segTriDist(a, b, other) <= radius;
  }
}

Rect _triBounds(List<Offset> t) => Rect.fromLTRB(
  math.min(t[0].dx, math.min(t[1].dx, t[2].dx)),
  math.min(t[0].dy, math.min(t[1].dy, t[2].dy)),
  math.max(t[0].dx, math.max(t[1].dx, t[2].dx)),
  math.max(t[0].dy, math.max(t[1].dy, t[2].dy)),
);

double _cross(Offset o, Offset a, Offset b) =>
    (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

bool _pointInTri(Offset p, List<Offset> t) {
  final d1 = _cross(t[0], t[1], p);
  final d2 = _cross(t[1], t[2], p);
  final d3 = _cross(t[2], t[0], p);
  final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNeg && hasPos);
}

double _pointSegDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

bool _segmentsCross(Offset p1, Offset q1, Offset p2, Offset q2) {
  final d1 = _cross(p2, q2, p1);
  final d2 = _cross(p2, q2, q1);
  final d3 = _cross(p1, q1, p2);
  final d4 = _cross(p1, q1, q2);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

double _segSegDist(Offset p1, Offset q1, Offset p2, Offset q2) {
  if (_segmentsCross(p1, q1, p2, q2)) return 0;
  return math.min(
    math.min(_pointSegDist(p1, p2, q2), _pointSegDist(q1, p2, q2)),
    math.min(_pointSegDist(p2, p1, q1), _pointSegDist(q2, p1, q1)),
  );
}

double _segTriDist(Offset p, Offset q, List<Offset> t) {
  if (_pointInTri(p, t) || _pointInTri(q, t)) return 0;
  var best = double.infinity;
  for (var i = 0; i < 3; i++) {
    best = math.min(best, _segSegDist(p, q, t[i], t[(i + 1) % 3]));
  }
  return best;
}

bool _triTriOverlap(List<Offset> a, List<Offset> b) {
  for (final p in a) {
    if (_pointInTri(p, b)) return true;
  }
  for (final p in b) {
    if (_pointInTri(p, a)) return true;
  }
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 3; j++) {
      if (_segSegDist(a[i], a[(i + 1) % 3], b[j], b[(j + 1) % 3]) == 0) {
        return true;
      }
    }
  }
  return false;
}
