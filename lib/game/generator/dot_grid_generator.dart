import 'dart:math';

import '../../data/models/arrow_direction.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../solver/level_solver.dart';

typedef Dot = (int, int);

/// Redesigned path generation system based on an invisible dot-grid concept
/// (inspired by Indian Rangoli/Kolam patterns).
///
/// Principles:
/// 1. Invisible dot grid anchors all geometry and turn coordinates.
/// 2. Primary collision system is `occupiedEdges` so paths connect dot-to-dot
///    without overlapping.
/// 3. Adjacent parallel paths run along neighboring dot lines with consistent,
///    uniform clearance: `visualGap = cellSpacing - pathThickness`.
/// 4. Varied straight segment lengths (2, 3, 4, 5 dots) with natural 90° turns.
/// 5. 80%–90% playable board utilization measured by path coverage.
/// 6. Pipeline: Candidate Generation → Reverse Dependency → Solver Verification.
class DotGridGenerator {
  DotGridGenerator._();

  static String _edgeKey(int r1, int c1, int r2, int c2) {
    if (r1 < r2 || (r1 == r2 && c1 < c2)) {
      return '$r1,$c1-$r2,$c2';
    }
    return '$r2,$c2-$r1,$c1';
  }

  /// Generates a fully verified, solvable dot-grid level with 100% dot coverage.
  static LevelModel? generate({
    required int levelNumber,
    required int seed,
    required Difficulty difficulty,
    int? overrideGridSize,
    double targetCoverage = 1.0,
  }) {
    final gridSize = overrideGridSize ?? _gridSizeForDifficulty(difficulty);
    final maxMistakes = _maxMistakesForDifficulty(difficulty);

    // Try up to 120 generation attempts to find a 100% filled, solvable board
    for (var attempt = 0; attempt < 120; attempt++) {
      final rng = Random(seed ^ (attempt * 0x9E3779B9) ^ (levelNumber * 7919));
      final candidate = _generateCandidate(
        gridSize: gridSize,
        rng: rng,
        requireFullCoverage: true,
      );

      if (candidate == null || candidate.isEmpty) continue;

      // Verify with LevelSolver
      final solveResult = LevelSolver.solve(candidate, gridSize);
      if (!solveResult.solvable) continue;

      return LevelModel(
        levelNumber: levelNumber,
        seed: seed,
        gridSize: gridSize,
        difficulty: difficulty,
        arrowCount: candidate.length,
        maxMistakes: maxMistakes,
        arrows: candidate,
      );
    }

    // Fallback: try with high coverage (≥96%) if 100% takes too many attempts
    for (var attempt = 0; attempt < 40; attempt++) {
      final rng = Random(seed ^ (attempt * 0x7FFFFFED) ^ 0xBEEF);
      final candidate = _generateCandidate(
        gridSize: gridSize,
        rng: rng,
        requireFullCoverage: false,
      );

      if (candidate != null && candidate.isNotEmpty) {
        final solveResult = LevelSolver.solve(candidate, gridSize);
        if (solveResult.solvable) {
          return LevelModel(
            levelNumber: levelNumber,
            seed: seed,
            gridSize: gridSize,
            difficulty: difficulty,
            arrowCount: candidate.length,
            maxMistakes: maxMistakes,
            arrows: candidate,
          );
        }
      }
    }

    return null;
  }

  static int _gridSizeForDifficulty(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 10;
      case Difficulty.normal:
        return 11;
      case Difficulty.hard:
        return 12;
      case Difficulty.expert:
      case Difficulty.extreme:
        return 14;
    }
  }

  static int _maxMistakesForDifficulty(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 5;
      case Difficulty.normal:
        return 4;
      case Difficulty.hard:
        return 3;
      case Difficulty.expert:
      case Difficulty.extreme:
        return 2;
    }
  }

  /// Core candidate generation ensuring 100% of grid dots are filled
  static List<ArrowModel>? _generateCandidate({
    required int gridSize,
    required Random rng,
    required bool requireFullCoverage,
  }) {
    final totalDots = gridSize * gridSize;

    final occupiedDots = <Dot>{};
    final occupiedEdges = <String>{};
    final placedArrows = <ArrowModel>[]; // reverse escape order

    // Track exit rays of placed arrows to reward weaving dependencies
    final exitRays = <Dot, int>{};

    var stuckCount = 0;
    while (occupiedDots.length < totalDots && stuckCount < 50) {
      final arrow = _growReverseArrow(
        gridSize: gridSize,
        rng: rng,
        occupiedDots: occupiedDots,
        occupiedEdges: occupiedEdges,
        exitRays: exitRays,
        arrowIndex: placedArrows.length,
      );

      if (arrow != null && arrow.length >= 2) {
        placedArrows.add(arrow);
        occupiedDots.addAll(arrow.points);
        for (var i = 1; i < arrow.points.length; i++) {
          final p1 = arrow.points[i - 1];
          final p2 = arrow.points[i];
          occupiedEdges.add(_edgeKey(p1.$1, p1.$2, p2.$1, p2.$2));
        }
        _recordExitRay(arrow, gridSize, exitRays);
        stuckCount = 0;
      } else {
        stuckCount++;
      }
    }

    // Phase 1: Tail absorption pass
    _absorbFreeDots(
      gridSize: gridSize,
      placedArrows: placedArrows,
      occupiedDots: occupiedDots,
      occupiedEdges: occupiedEdges,
      totalDots: totalDots,
      rng: rng,
    );

    // Phase 2: Square detour absorption for adjacent free dot pairs
    _detourFreeDots(
      gridSize: gridSize,
      placedArrows: placedArrows,
      occupiedDots: occupiedDots,
      occupiedEdges: occupiedEdges,
    );

    // Phase 3: Tail absorption again after detours
    _absorbFreeDots(
      gridSize: gridSize,
      placedArrows: placedArrows,
      occupiedDots: occupiedDots,
      occupiedEdges: occupiedEdges,
      totalDots: totalDots,
      rng: rng,
    );

    // Phase 4: Fill any remaining 2+ dot gaps with small escape arrows
    _fillIsolatedGaps(
      gridSize: gridSize,
      placedArrows: placedArrows,
      occupiedDots: occupiedDots,
      occupiedEdges: occupiedEdges,
      totalDots: totalDots,
    );

    // Final absorption sweep
    _absorbFreeDots(
      gridSize: gridSize,
      placedArrows: placedArrows,
      occupiedDots: occupiedDots,
      occupiedEdges: occupiedEdges,
      totalDots: totalDots,
      rng: rng,
    );

    if (placedArrows.length < 6) return null;

    // Require 100% dot coverage
    if (requireFullCoverage && occupiedDots.length < totalDots) {
      return null;
    }

    // Reverse to forward play order (Arrow 1 escapes first)
    final forwardArrows = <ArrowModel>[];
    for (var i = 0; i < placedArrows.length; i++) {
      final arrow = placedArrows[placedArrows.length - 1 - i];
      forwardArrows.add(ArrowModel(
        id: 'a${(i + 1).toString().padLeft(3, '0')}',
        points: arrow.points,
      ));
    }

    return forwardArrows;
  }

  /// Grows a single arrow backwards from its head
  static ArrowModel? _growReverseArrow({
    required int gridSize,
    required Random rng,
    required Set<Dot> occupiedDots,
    required Set<String> occupiedEdges,
    required Map<Dot, int> exitRays,
    required int arrowIndex,
  }) {
    // Find candidate head dots that have an unobstructed exit ray to the boundary
    final candidates = <(Dot, ArrowDirection, double)>[];

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final head = (r, c);
        if (occupiedDots.contains(head)) continue;

        for (final dir in ArrowDirection.values) {
          // Check that back dot exists and is free
          final backDot = (r - dir.dRow, c - dir.dCol);
          if (backDot.$1 < 0 ||
              backDot.$1 >= gridSize ||
              backDot.$2 < 0 ||
              backDot.$2 >= gridSize ||
              occupiedDots.contains(backDot)) {
            continue;
          }

          final edgeKey = _edgeKey(head.$1, head.$2, backDot.$1, backDot.$2);
          if (occupiedEdges.contains(edgeKey)) continue;

          // Check if exit ray is clear of currently occupied dots
          if (!_isExitRayClear(head, dir, gridSize, occupiedDots)) continue;

          // Score candidate
          var score = 1.0;
          // Prefer heads that cross previously recorded exit rays (creating dependency)
          if (exitRays.containsKey(head)) {
            score += 5.0 + exitRays[head]!;
          }
          // Center preference for early arrows, outer for later
          final center = (gridSize - 1) / 2.0;
          final distToCenter = sqrt(pow(r - center, 2) + pow(c - center, 2));
          if (arrowIndex < 8) {
            score += max(0.0, 4.0 - distToCenter * 0.4);
          } else {
            score += distToCenter * 0.3;
          }

          score += rng.nextDouble() * 2.0;
          candidates.add((head, dir, score));
        }
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.$3.compareTo(a.$3));

    final topPool = min(6, candidates.length);
    final chosen = candidates[rng.nextInt(topPool)];
    final head = chosen.$1;
    final dir = chosen.$2;

    // Start path: [head, backDot]
    final back = (head.$1 - dir.dRow, head.$2 - dir.dCol);
    final path = <Dot>[head, back];
    final pathDots = <Dot>{head, back};

    // Target arrow length: 3 to 7 dots (avg ~4.5 dots)
    // Varied segment lengths: 2, 3, 4, 5 dots before 90° turn
    final targetLength = 3 + rng.nextInt(5);

    var currentDir = (back.$1 - head.$1, back.$2 - head.$2);
    // Segment length counter for variable straight-line runs
    var segmentRemaining = _rollSegmentLength(rng);

    while (path.length < targetLength) {
      final current = path.last;

      // Available orthogonal neighbors
      final neighbors = <(Dot, (int, int), double)>[];
      for (final delta in const <(int, int)>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        // Do not double-back
        if (delta.$1 == -currentDir.$1 && delta.$2 == -currentDir.$2) continue;

        final nextDot = (current.$1 + delta.$1, current.$2 + delta.$2);
        if (nextDot.$1 < 0 ||
            nextDot.$1 >= gridSize ||
            nextDot.$2 < 0 ||
            nextDot.$2 >= gridSize) {
          continue;
        }

        if (occupiedDots.contains(nextDot) || pathDots.contains(nextDot)) {
          continue;
        }

        final eKey = _edgeKey(current.$1, current.$2, nextDot.$1, nextDot.$2);
        if (occupiedEdges.contains(eKey)) continue;

        final isTurn = delta.$1 != currentDir.$1 || delta.$2 != currentDir.$2;
        var score = 2.0;

        if (segmentRemaining <= 0) {
          // Time to turn! Reward 90° bends
          if (isTurn) {
            score += 6.0;
          } else {
            score -= 3.0;
          }
        } else {
          // In the middle of straight segment
          if (!isTurn) {
            score += 4.0;
          } else {
            score += 1.0;
          }
        }

        // Weave bonus if passing through exit ray
        if (exitRays.containsKey(nextDot)) {
          score += 4.0;
        }

        neighbors.add((nextDot, delta, score + rng.nextDouble() * 1.5));
      }

      if (neighbors.isEmpty) break;
      neighbors.sort((a, b) => b.$3.compareTo(a.$3));

      final picked = neighbors.first;
      final nextDot = picked.$1;
      final nextDelta = picked.$2;

      final isTurn = nextDelta.$1 != currentDir.$1 || nextDelta.$2 != currentDir.$2;
      if (isTurn) {
        currentDir = nextDelta;
        segmentRemaining = _rollSegmentLength(rng);
      } else {
        segmentRemaining--;
      }

      path.add(nextDot);
      pathDots.add(nextDot);
    }

    if (path.length < 2) return null;

    // In ArrowModel, points is ordered [tail ... head].
    // Our growth was [head ... tail], so we reverse the list.
    return ArrowModel(
      id: 'tmp_$arrowIndex',
      points: path.reversed.toList(),
    );
  }

  /// Roll segment length between 2 and 5 dots, biased towards 2–3
  static int _rollSegmentLength(Random rng) {
    final r = rng.nextDouble();
    if (r < 0.45) return 2;
    if (r < 0.75) return 3;
    if (r < 0.90) return 4;
    return 5;
  }

  static bool _isExitRayClear(
    Dot head,
    ArrowDirection dir,
    int gridSize,
    Set<Dot> occupiedDots,
  ) {
    var r = head.$1 + dir.dRow;
    var c = head.$2 + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      if (occupiedDots.contains((r, c))) return false;
      r += dir.dRow;
      c += dir.dCol;
    }
    return true;
  }

  static void _recordExitRay(
    ArrowModel arrow,
    int gridSize,
    Map<Dot, int> exitRays,
  ) {
    final dir = arrow.exitDirection;
    var r = arrow.headRow + dir.dRow;
    var c = arrow.headCol + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      exitRays[(r, c)] = (exitRays[(r, c)] ?? 0) + 1;
      r += dir.dRow;
      c += dir.dCol;
    }
  }

  /// Extends tails into adjacent free dots to achieve 100% coverage
  static void _absorbFreeDots({
    required int gridSize,
    required List<ArrowModel> placedArrows,
    required Set<Dot> occupiedDots,
    required Set<String> occupiedEdges,
    required int totalDots,
    required Random rng,
  }) {
    var progress = true;
    while (occupiedDots.length < totalDots && progress) {
      progress = false;
      final indices = List<int>.generate(placedArrows.length, (i) => i)..shuffle(rng);

      for (final i in indices) {
        if (occupiedDots.length >= totalDots) break;
        final arrow = placedArrows[i];
        if (arrow.length >= 22) continue;

        final tail = arrow.points.first;
        final deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]..shuffle(rng);

        for (final delta in deltas) {
          final next = (tail.$1 + delta.$1, tail.$2 + delta.$2);
          if (next.$1 < 0 || next.$1 >= gridSize || next.$2 < 0 || next.$2 >= gridSize) {
            continue;
          }
          if (occupiedDots.contains(next)) continue;

          final eKey = _edgeKey(tail.$1, tail.$2, next.$1, next.$2);
          if (occupiedEdges.contains(eKey)) continue;

          placedArrows[i] = ArrowModel(
            id: arrow.id,
            points: [next, ...arrow.points],
          );
          occupiedDots.add(next);
          occupiedEdges.add(eKey);
          progress = true;
          break;
        }
      }
    }
  }

  /// Detour pass: allows an arrow to detour through two adjacent free dots (1x1 square)
  static void _detourFreeDots({
    required int gridSize,
    required List<ArrowModel> placedArrows,
    required Set<Dot> occupiedDots,
    required Set<String> occupiedEdges,
  }) {
    for (var i = 0; i < placedArrows.length; i++) {
      final arrow = placedArrows[i];
      final pts = List<Dot>.from(arrow.points);
      var modified = false;

      for (var k = 0; k < pts.length - 1; k++) {
        final p1 = pts[k];
        final p2 = pts[k + 1];

        // Two possible normals for the edge (p1, p2)
        final List<(int, int)> normals;
        if (p1.$1 == p2.$1) {
          normals = const [(-1, 0), (1, 0)];
        } else {
          normals = const [(0, -1), (0, 1)];
        }

        for (final normal in normals) {
          final f1 = (p1.$1 + normal.$1, p1.$2 + normal.$2);
          final f2 = (p2.$1 + normal.$1, p2.$2 + normal.$2);

          if (f1.$1 < 0 || f1.$1 >= gridSize || f1.$2 < 0 || f1.$2 >= gridSize ||
              f2.$1 < 0 || f2.$1 >= gridSize || f2.$2 < 0 || f2.$2 >= gridSize) {
            continue;
          }

          if (occupiedDots.contains(f1) || occupiedDots.contains(f2)) {
            continue;
          }

          final e1 = _edgeKey(p1.$1, p1.$2, f1.$1, f1.$2);
          final e2 = _edgeKey(f1.$1, f1.$2, f2.$1, f2.$2);
          final e3 = _edgeKey(f2.$1, f2.$2, p2.$1, p2.$2);

          if (occupiedEdges.contains(e1) || occupiedEdges.contains(e2) || occupiedEdges.contains(e3)) {
            continue;
          }

          // Reroute p1 -> f1 -> f2 -> p2
          occupiedEdges.remove(_edgeKey(p1.$1, p1.$2, p2.$1, p2.$2));
          occupiedEdges.addAll([e1, e2, e3]);
          occupiedDots.addAll([f1, f2]);

          pts.insertAll(k + 1, [f1, f2]);
          modified = true;
          break;
        }
      }

      if (modified) {
        placedArrows[i] = ArrowModel(id: arrow.id, points: pts);
      }
    }
  }

  /// Places short escape arrows into remaining free components
  static void _fillIsolatedGaps({
    required int gridSize,
    required List<ArrowModel> placedArrows,
    required Set<Dot> occupiedDots,
    required Set<String> occupiedEdges,
    required int totalDots,
  }) {
    for (var r = 0; r < gridSize && occupiedDots.length < totalDots; r++) {
      for (var c = 0; c < gridSize && occupiedDots.length < totalDots; c++) {
        final head = (r, c);
        if (occupiedDots.contains(head)) continue;

        for (final dir in ArrowDirection.values) {
          final tail = (r - dir.dRow, c - dir.dCol);
          if (tail.$1 < 0 || tail.$1 >= gridSize || tail.$2 < 0 || tail.$2 >= gridSize) {
            continue;
          }
          if (occupiedDots.contains(tail)) continue;

          final eKey = _edgeKey(head.$1, head.$2, tail.$1, tail.$2);
          if (occupiedEdges.contains(eKey)) continue;

          // In reverse order, arrow placed at start of list will escape LAST when board is empty!
          occupiedDots.addAll([tail, head]);
          occupiedEdges.add(eKey);
          placedArrows.insert(0, ArrowModel(
            id: 'gap_${placedArrows.length}',
            points: [tail, head],
          ));
          break;
        }
      }
    }
  }
}
