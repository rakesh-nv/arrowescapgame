import 'dart:math';

import '../../data/models/arrow_direction.dart';
import '../../data/models/arrow_model.dart';

typedef Cell = (int, int);

enum LengthTier { short, medium, long, veryLong, extraLong }

class _TierCap {
  final LengthTier tier;
  final int maxCap;
  _TierCap(this.tier, this.maxCap);
}

/// Shape-constrained dense path maze generator with weighted length distribution.
class ShapePathGenerator {
  ShapePathGenerator._();

  /// Synthesizes a dense, structured maze-like path layout inside [shapeMask].
  static List<ArrowModel>? generatePaths({
    required Set<Cell> shapeMask,
    required int gridSize,
    required double targetDensity,
    required int levelNumber,
    required int minArrowLen,
    required int maxArrowLen,
    int minArrows = 4,
    required Random rng,
  }) {
    if (shapeMask.isEmpty) return null;

    final totalUsable = shapeMask.length;
    final targetOccupied = (totalUsable * targetDensity)
        .clamp(20, totalUsable)
        .round();

    // 1. Build Distance Contour Field inside shapeMask
    final contourMap = _buildContourMap(shapeMask, gridSize);

    final occupied = <Cell>{};
    final placedArrows = <ArrowModel>[];
    final arrowCaps = <int, _TierCap>{};
    final blockedExitRays = <Cell, Set<int>>{};

    // Fewer, substantial paths are the identity of the game. The count is
    // derived from usable capacity so a 14×14 board is never asked to hold an
    // impossible number of 23–45-cell arrows.
    final targetRequests = _buildTargetRequests(
      levelNumber: levelNumber,
      targetOccupied: targetOccupied,
      minArrows: minArrows,
      maxArrowLen: maxArrowLen,
      rng: rng,
    );

    // Attempt to grow paths in interleaved order
    for (final req in targetRequests) {
      if (occupied.length >= targetOccupied && placedArrows.length >= minArrows) {
        break;
      }

      final tier = req.$1;
      final targetLen = req.$2;
      final cap = req.$3;

      final arrow = _growContourSerpentineArrow(
        shapeMask: shapeMask,
        contourMap: contourMap,
        occupied: occupied,
        blockedExitRays: blockedExitRays,
        gridSize: gridSize,
        targetLength: targetLen,
        arrowIndex: placedArrows.length,
        rng: rng,
      );

      if (arrow != null && arrow.length >= 2) {
        final idx = placedArrows.length;
        placedArrows.add(arrow);
        arrowCaps[idx] = _TierCap(tier, cap);
        occupied.addAll(arrow.occupiedCells);
        _recordExitRay(arrow, gridSize, idx, blockedExitRays);
      }
    }

    // Fill remaining space with paths until density and arrow targets are met
    var fillAttempts = 0;
    while ((occupied.length < targetOccupied ||
            placedArrows.length < minArrows) &&
        fillAttempts < 100) {
      fillAttempts++;
      final roll = rng.nextDouble();
      LengthTier tier;
      int targetLen;
      int cap;
      if (roll < 0.20) {
        tier = LengthTier.extraLong;
      } else if (roll < 0.50) {
        tier = LengthTier.veryLong;
      } else if (roll < 0.80) {
        tier = LengthTier.long;
      } else if (roll < 0.95) {
        tier = LengthTier.medium;
      } else {
        tier = LengthTier.short;
      }
      final range = _rangeFor(tier, levelNumber, maxArrowLen);
      targetLen = range.$1 + rng.nextInt(range.$2 - range.$1 + 1);
      cap = range.$2;

      final arrow = _growContourSerpentineArrow(
        shapeMask: shapeMask,
        contourMap: contourMap,
        occupied: occupied,
        blockedExitRays: blockedExitRays,
        gridSize: gridSize,
        targetLength: targetLen,
        arrowIndex: placedArrows.length,
        rng: rng,
      );

      if (arrow != null && arrow.length >= 2) {
        final idx = placedArrows.length;
        placedArrows.add(arrow);
        arrowCaps[idx] = _TierCap(tier, cap);
        occupied.addAll(arrow.occupiedCells);
        _recordExitRay(arrow, gridSize, idx, blockedExitRays);
        fillAttempts = 0;
      }
    }

    // Pass 1: Controlled Tail Absorption Pass respecting exit ray safety.
    _absorbFreeCells(
      placedArrows: placedArrows,
      shapeMask: shapeMask,
      occupied: occupied,
      blockedExitRays: blockedExitRays,
      maxArrowLen: maxArrowLen,
      rng: rng,
    );

    // Pass 2: Fill remaining pockets with valid 3+ cell escaping arrows.
    _fillRemainingGaps(
      placedArrows: placedArrows,
      shapeMask: shapeMask,
      occupied: occupied,
      blockedExitRays: blockedExitRays,
      gridSize: gridSize,
      rng: rng,
    );

    // Pass 3: Final absorption of any remaining 1-2 cell pockets into tails.
    _absorbFreeCells(
      placedArrows: placedArrows,
      shapeMask: shapeMask,
      occupied: occupied,
      blockedExitRays: blockedExitRays,
      maxArrowLen: maxArrowLen,
      rng: rng,
    );

    if (placedArrows.isEmpty) return null;

    // Reverse list so arrows[0] is first placed in forward time
    final forwardArrows = <ArrowModel>[];
    for (var i = 0; i < placedArrows.length; i++) {
      final a = placedArrows[placedArrows.length - 1 - i];
      forwardArrows.add(
        ArrowModel(
          id: 'a${(i + 1).toString().padLeft(3, '0')}',
          points: a.points,
        ),
      );
    }

    return forwardArrows;
  }

  static List<(LengthTier, int, int)> _buildTargetRequests({
    required int levelNumber,
    required int targetOccupied,
    required int minArrows,
    required int maxArrowLen,
    required Random rng,
  }) {
    final averageTarget = _averageFor(levelNumber);
    var count = max(minArrows, (targetOccupied / averageTarget).round());
    var tiers = _tiersFor(count, levelNumber);

    while (count > minArrows &&
        _minimumCells(tiers, levelNumber, maxArrowLen) > targetOccupied) {
      count--;
      tiers = _tiersFor(count, levelNumber);
    }

    final requests = <(LengthTier, int, int)>[];
    var remainingCapacity = targetOccupied;
    for (var i = 0; i < tiers.length; i++) {
      final tier = tiers[i];
      final range = _rangeFor(tier, levelNumber, maxArrowLen);
      final reservedForFollowing = _minimumCells(
        tiers.skip(i + 1),
        levelNumber,
        maxArrowLen,
      );
      final permittedMaximum = min(
        range.$2,
        remainingCapacity - reservedForFollowing,
      );
      if (permittedMaximum < range.$1) continue;
      final target = range.$1 + rng.nextInt(permittedMaximum - range.$1 + 1);
      requests.add((tier, target, permittedMaximum));
      remainingCapacity -= target;
    }
    return requests;
  }

  static List<LengthTier> _tiersFor(int count, int levelNumber) {
    if (count <= 6) {
      return [
        LengthTier.extraLong,
        LengthTier.veryLong,
        LengthTier.long,
        LengthTier.long,
        LengthTier.medium,
        LengthTier.medium,
      ].take(count).toList();
    }
    final extraCount = max(1, (count * 0.16).round());
    final veryLongCount = max(2, (count * 0.28).round());
    final longCount = max(2, (count * 0.32).round());
    final mediumCount = max(2, (count * 0.18).round());
    final shortCount = max(
      0,
      count - extraCount - veryLongCount - longCount - mediumCount,
    );

    return <LengthTier>[
      ...List.filled(extraCount, LengthTier.extraLong),
      ...List.filled(veryLongCount, LengthTier.veryLong),
      ...List.filled(longCount, LengthTier.long),
      ...List.filled(mediumCount, LengthTier.medium),
      ...List.filled(shortCount, LengthTier.short),
    ];
  }

  static int _minimumCells(
    Iterable<LengthTier> tiers,
    int levelNumber,
    int maxArrowLen,
  ) => tiers.fold<int>(
    0,
    (sum, tier) => sum + _rangeFor(tier, levelNumber, maxArrowLen).$1,
  );

  static (int, int) _rangeFor(
    LengthTier tier,
    int levelNumber,
    int maxArrowLen,
  ) {
    // Sized to double the total number of arrows across all boards.
    final base = switch (tier) {
      LengthTier.short     => (4, 7),
      LengthTier.medium    => (7, 10),
      LengthTier.long      => (10, 13),
      LengthTier.veryLong  => (13, 16),
      LengthTier.extraLong => (16, min(22, maxArrowLen)),
    };
    return base;
  }

  static double _averageFor(int levelNumber) {
    // Average ~9.5 cells per arrow → doubles the total arrows produced.
    return 9.0 + (levelNumber / 100.0) * 2.5;
  }

  /// Assigns each shape cell a contour distance from the outer boundary.
  static Map<Cell, int> _buildContourMap(Set<Cell> shapeMask, int size) {
    final map = <Cell, int>{};
    final queue = <Cell>[];

    // Boundary cells (distance 0): cells with at least 1 neighbor outside shapeMask
    for (final cell in shapeMask) {
      var isBoundary = false;
      for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final n = (cell.$1 + d.$1, cell.$2 + d.$2);
        if (!shapeMask.contains(n)) {
          isBoundary = true;
          break;
        }
      }
      if (isBoundary) {
        map[cell] = 0;
        queue.add(cell);
      }
    }

    // BFS inward to build contour levels
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      final dist = map[cur]!;
      for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final n = (cur.$1 + d.$1, cur.$2 + d.$2);
        if (shapeMask.contains(n) && !map.containsKey(n)) {
          map[n] = dist + 1;
          queue.add(n);
        }
      }
    }

    return map;
  }

  /// Grows a single serpentine/boundary-following arrow path in reverse escape order.
  static ArrowModel? _growContourSerpentineArrow({
    required Set<Cell> shapeMask,
    required Map<Cell, int> contourMap,
    required Set<Cell> occupied,
    required Map<Cell, Set<int>> blockedExitRays,
    required int gridSize,
    required int targetLength,
    required int arrowIndex,
    required Random rng,
  }) {
    // 1. Find candidate head cells with unblocked exit rays
    final candidateHeads = <(Cell, ArrowDirection, double)>[];

    for (final cell in shapeMask) {
      if (occupied.contains(cell)) continue;

      for (final dir in ArrowDirection.values) {
        if (!_isExitRayFree(cell, dir, gridSize, occupied)) continue;

        final backCell = (cell.$1 - dir.dRow, cell.$2 - dir.dCol);
        if (!shapeMask.contains(backCell) || occupied.contains(backCell)) {
          continue;
        }

        var score = 10.0;
        // Reward heads on exit rays of previously placed arrows (creates blocking dependencies)
        if (blockedExitRays.containsKey(cell)) {
          score += 15.0 + blockedExitRays[cell]!.length * 5.0;
        }

        // Contour preference: balance outer boundary & interior heads
        final dist = contourMap[cell] ?? 0;
        score += dist * 2.0;

        candidateHeads.add((cell, dir, score + rng.nextDouble() * 4.0));
      }
    }

    if (candidateHeads.isEmpty) return null;
    candidateHeads.sort((a, b) => b.$3.compareTo(a.$3));

    final topCount = min(8, candidateHeads.length);
    final chosen = candidateHeads[rng.nextInt(topCount)];
    final head = chosen.$1;
    final dir = chosen.$2;

    final path = <Cell>[head, (head.$1 - dir.dRow, head.$2 - dir.dCol)];
    final pathSet = path.toSet();

    var straightRun = 1;
    const maxStraightRun = 6;

    while (path.length < targetLength) {
      final tail = path.last;
      final prev = path[path.length - 2];
      final prevDelta = (tail.$1 - prev.$1, tail.$2 - prev.$2);

      final neighbors = <(Cell, double)>[];
      for (final delta in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final next = (tail.$1 + delta.$1, tail.$2 + delta.$2);
        if (!shapeMask.contains(next) ||
            occupied.contains(next) ||
            pathSet.contains(next)) {
          continue;
        }

        var score = 5.0;
        final isTurn = delta.$1 != prevDelta.$1 || delta.$2 != prevDelta.$2;

        // Serpentine preference: favor straight runs of 3-4 cells, then clean 90° turns
        if (straightRun >= maxStraightRun && !isTurn) {
          score -= 8.0;
        } else if (isTurn) {
          score += 4.5;
        } else {
          score += 2.0;
        }

        // Reward following contour lines (same distance layer or adjacent)
        final tailDist = contourMap[tail] ?? 0;
        final nextDist = contourMap[next] ?? 0;
        if (nextDist == tailDist) {
          score += 3.0; // boundary-following parallel run
        }

        // Reward crossing blocked exit rays
        if (blockedExitRays.containsKey(next)) {
          score += 6.0;
        }

        neighbors.add((next, score + rng.nextDouble() * 2.0));
      }

      if (neighbors.isEmpty) break;
      neighbors.sort((a, b) => b.$2.compareTo(a.$2));

      final nextCell = neighbors.first.$1;
      final isTurn =
          (nextCell.$1 - tail.$1) != prevDelta.$1 ||
          (nextCell.$2 - tail.$2) != prevDelta.$2;

      straightRun = isTurn ? 1 : straightRun + 1;
      path.add(nextCell);
      pathSet.add(nextCell);
    }

    if (path.length < 2) return null;
    return ArrowModel(id: 'tmp_$arrowIndex', points: path.reversed.toList());
  }

  static bool _isExitRayFree(
    Cell head,
    ArrowDirection dir,
    int gridSize,
    Set<Cell> occupied,
  ) {
    var r = head.$1 + dir.dRow;
    var c = head.$2 + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      if (occupied.contains((r, c))) return false;
      r += dir.dRow;
      c += dir.dCol;
    }
    return true;
  }

  static void _recordExitRay(
    ArrowModel arrow,
    int gridSize,
    int idx,
    Map<Cell, Set<int>> rays,
  ) {
    final dir = arrow.exitDirection;
    var r = arrow.headRow + dir.dRow;
    var c = arrow.headCol + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      rays.putIfAbsent((r, c), () => <int>{}).add(idx);
      r += dir.dRow;
      c += dir.dCol;
    }
  }

  /// Tail absorption pass extending paths into adjacent free cells without blocking earlier-escaping arrows.
  static void _absorbFreeCells({
    required List<ArrowModel> placedArrows,
    required Set<Cell> shapeMask,
    required Set<Cell> occupied,
    required Map<Cell, Set<int>> blockedExitRays,
    required int maxArrowLen,
    required Random rng,
  }) {
    if (placedArrows.isEmpty) return;

    var modified = true;
    var iterations = 0;
    while (modified && occupied.length < shapeMask.length && iterations < 30) {
      modified = false;
      iterations++;
      final indices = List<int>.generate(placedArrows.length, (i) => i)
        ..shuffle(rng);

      for (final i in indices) {
        if (occupied.length >= shapeMask.length) break;
        final arrow = placedArrows[i];
        if (arrow.length >= maxArrowLen) continue;

        final tail = arrow.points.first;
        final deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]..shuffle(rng);

        for (final delta in deltas) {
          final next = (tail.$1 + delta.$1, tail.$2 + delta.$2);
          if (shapeMask.contains(next) && !occupied.contains(next)) {
            // Safety check: arrow j with j > i escapes BEFORE arrow i.
            // Do not block earlier-escaping arrows.
            final blockers = blockedExitRays[next];
            if (blockers != null && blockers.any((j) => j > i)) {
              continue;
            }

            placedArrows[i] = ArrowModel(
              id: arrow.id,
              points: [next, ...arrow.points],
            );
            occupied.add(next);
            modified = true;
            break;
          }
        }
      }
    }
  }

  /// Fills any remaining isolated pockets of 3+ cells with valid escaping arrows.
  static void _fillRemainingGaps({
    required List<ArrowModel> placedArrows,
    required Set<Cell> shapeMask,
    required Set<Cell> occupied,
    required Map<Cell, Set<int>> blockedExitRays,
    required int gridSize,
    required Random rng,
  }) {
    final freeCells = shapeMask.where((c) => !occupied.contains(c)).toList()
      ..shuffle(rng);

    for (final head in freeCells) {
      if (occupied.contains(head)) continue;

      for (final dir in ArrowDirection.values) {
        if (!_isExitRayFree(head, dir, gridSize, occupied)) continue;

        final path = <Cell>[head];
        var curr = head;
        // Prefer straight back from head, then turns
        for (var step = 0; step < 7; step++) {
          final deltas = [
            (-dir.dRow, -dir.dCol),
            (dir.dCol, dir.dRow),
            (-dir.dCol, -dir.dRow),
          ]..shuffle(rng);

          Cell? next;
          for (final d in deltas) {
            final cand = (curr.$1 + d.$1, curr.$2 + d.$2);
            if (shapeMask.contains(cand) &&
                !occupied.contains(cand) &&
                !path.contains(cand)) {
              next = cand;
              break;
            }
          }
          if (next == null) break;
          path.add(next);
          curr = next;
        }

        if (path.length >= 3) {
          final idx = placedArrows.length;
          final newArrow = ArrowModel(
            id: 'gap_$idx',
            points: path.reversed.toList(),
          );
          placedArrows.add(newArrow);
          occupied.addAll(path);
          _recordExitRay(newArrow, gridSize, idx, blockedExitRays);
          break;
        }
      }
    }
  }
}
