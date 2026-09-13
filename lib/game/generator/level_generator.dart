import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../data/models/arrow_direction.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../solver/level_solver.dart';
import 'dependency_analyzer.dart';
import 'dot_grid_generator.dart';
import 'shape_template.dart';

typedef Cell = (int, int);

/// Diagnostic info description.
class LevelLayoutInfo {
  final String shape;
  final String family;

  const LevelLayoutInfo({required this.shape, required this.family});

  @override
  String toString() => '$shape / $family';
}

/// Structural signature used for anti-duplicate level detection.
class LevelPatternSignature {
  final PatternType patternType;
  final int arrowCount;
  final int totalOccupiedCells;
  final int signatureHash;

  LevelPatternSignature({
    required this.patternType,
    required this.arrowCount,
    required this.totalOccupiedCells,
    required this.signatureHash,
  });

  static LevelPatternSignature fromLevel({
    required List<ArrowModel> arrows,
    required PatternType patternType,
    required int gridSize,
  }) {
    final occupied = <Cell>{for (final a in arrows) ...a.occupiedCells};

    final dirCounts = <int>[0, 0, 0, 0];
    for (final a in arrows) {
      dirCounts[a.exitDirection.index]++;
    }

    var h = 17;
    h = 37 * h + patternType.index;
    h = 37 * h + arrows.length;
    h = 37 * h + occupied.length;
    h = 37 * h + dirCounts.join().hashCode;

    for (final a in arrows) {
      h = 37 * h + a.headRow * 31 + a.headCol;
      h = 37 * h + a.exitDirection.index;
    }

    return LevelPatternSignature(
      patternType: patternType,
      arrowCount: arrows.length,
      totalOccupiedCells: occupied.length,
      signatureHash: h,
    );
  }

  bool isTooSimilarTo(LevelPatternSignature other) {
    if (signatureHash == other.signatureHash) return true;
    if (patternType == other.patternType &&
        arrowCount == other.arrowCount &&
        (totalOccupiedCells - other.totalOccupiedCells).abs() <= 1) {
      return true;
    }
    return false;
  }
}

enum _RouteField {
  horizontal,
  vertical,
  mixed,
  zigzag,
  spiral,
  radial,
  border,
  diagonal,
  organic,
  maze,
}

class _DifficultyParams {
  final int gridSize;
  final double targetDensity;
  final int maxMistakes;
  final double minBends;
  final int minDepth;
  final int minArrows;
  final int maxArrowLen;
  final double avgTargetLen;

  const _DifficultyParams({
    required this.gridSize,
    required this.targetDensity,
    required this.maxMistakes,
    required this.minBends,
    required this.minDepth,
    required this.minArrows,
    required this.maxArrowLen,
    required this.avgTargetLen,
  });
}

/// Advanced procedural generator producing dense, solvable Arrow Escape boards.
class LevelGenerator {
  LevelGenerator._();

  static final Map<int, LevelPatternSignature> _recentSignatures = {};

  static const Map<Difficulty, _DifficultyParams> _params = {
    Difficulty.easy: _DifficultyParams(
      gridSize: 10,
      targetDensity: 1.0, // 100% full cell occupancy
      maxMistakes: 5,
      minBends: 0.8,
      minDepth: 2,
      minArrows: 15,
      maxArrowLen: 8,
      avgTargetLen: 4.0,
    ),
    Difficulty.normal: _DifficultyParams(
      gridSize: 12,
      targetDensity: 1.0, // 100% full cell occupancy
      maxMistakes: 4,
      minBends: 1.0,
      minDepth: 2,
      minArrows: 22,
      maxArrowLen: 10,
      avgTargetLen: 4.0,
    ),
    Difficulty.hard: _DifficultyParams(
      gridSize: 14,
      targetDensity: 1.0, // 100% full cell occupancy
      maxMistakes: 3,
      minBends: 1.2,
      minDepth: 3,
      minArrows: 30,
      maxArrowLen: 12,
      avgTargetLen: 4.0,
    ),
    Difficulty.expert: _DifficultyParams(
      gridSize: 16,
      targetDensity: 1.0, // 100% full cell occupancy
      maxMistakes: 2,
      minBends: 1.4,
      minDepth: 3,
      minArrows: 45,
      maxArrowLen: 14,
      avgTargetLen: 4.0,
    ),
    Difficulty.extreme: _DifficultyParams(
      gridSize: 18,
      targetDensity: 1.0, // 100% full cell occupancy
      maxMistakes: 1,
      minBends: 1.6,
      minDepth: 4,
      minArrows: 60,
      maxArrowLen: 14,
      avgTargetLen: 4.0,
    ),
  };

  /// Selects controlled random difficulty based on level progression stage.
  static Difficulty selectDifficulty(int levelNumber, Random rng) {
    final roll = rng.nextDouble();

    if (levelNumber <= AppConstants.easyLevelsEnd) {
      // Early game: 70% Easy, 30% Normal
      return roll < 0.70 ? Difficulty.easy : Difficulty.normal;
    } else if (levelNumber <= AppConstants.normalLevelsEnd) {
      // Middle game: 20% Easy, 55% Normal, 25% Hard
      if (roll < 0.20) return Difficulty.easy;
      if (roll < 0.75) return Difficulty.normal;
      return Difficulty.hard;
    } else if (levelNumber <= AppConstants.hardLevelsEnd) {
      // Late game: 15% Normal, 55% Hard, 30% Expert
      if (roll < 0.15) return Difficulty.normal;
      if (roll < 0.70) return Difficulty.hard;
      return Difficulty.expert;
    } else {
      // End game: 15% Hard, 55% Expert, 30% Extreme
      if (roll < 0.15) return Difficulty.hard;
      if (roll < 0.70) return Difficulty.expert;
      return Difficulty.extreme;
    }
  }

  /// Returns layout information for diagnostic tools.
  static LevelLayoutInfo layoutInfo({required int levelNumber, required int seed}) {
    final rng = Random(seed ^ (levelNumber * 7919));
    final patterns = PatternType.values;
    final p = patterns[rng.nextInt(patterns.length)];
    return LevelLayoutInfo(shape: p.name, family: 'procedural ${p.name}');
  }

  /// Generates a complete, solver-verified puzzle level with 100% arrow coverage.
  static LevelModel? generate({
    required int levelNumber,
    required int seed,
    Difficulty? difficulty,
  }) {
    final dotGridLevel = DotGridGenerator.generate(
      levelNumber: levelNumber,
      seed: seed,
      difficulty: difficulty ?? Difficulty.easy,
      targetCoverage: 1.0,
    );
    if (dotGridLevel != null && levelNumber <= 3) return dotGridLevel;

    final baseRng = Random(seed ^ (levelNumber * 7919));

    // Controlled Random Difficulty
    final resolvedDifficulty =
        difficulty ?? selectDifficulty(levelNumber, baseRng);
    final params = _params[resolvedDifficulty] ?? _params[Difficulty.normal]!;

    final prevSig = _recentSignatures[levelNumber - 1];

    // Primary procedural generation loop (up to 40 random candidate attempts)
    for (var attempt = 0; attempt < 40; attempt++) {
      final attemptSeed =
          seed ^ (attempt * 0x9E3779B9) ^ (levelNumber * 31337);
      final rng = Random(attemptSeed);

      // Random Pattern Selection
      final patternTypes = PatternType.values;
      final patternType = patternTypes[rng.nextInt(patternTypes.length)];

      // Random Geometry Mask
      final shapeMask = PatternGenerator.generateMask(
        type: patternType,
        gridSize: params.gridSize,
        rng: rng,
      );

      final candidate = _synthesizeLevel(
        rng: rng,
        params: params,
        patternType: patternType,
        shapeMask: shapeMask,
      );

      if (candidate == null || candidate.isEmpty) continue;

      // Quality Validation
      if (!_passesQuality(candidate, params, shapeMask)) continue;

      // Solvability Validation
      final solveResult = LevelSolver.solve(candidate, params.gridSize);
      if (!solveResult.solvable) continue;

      // Anti-Duplicate Validation
      final candidateSig = LevelPatternSignature.fromLevel(
        arrows: candidate,
        patternType: patternType,
        gridSize: params.gridSize,
      );

      if (prevSig != null && candidateSig.isTooSimilarTo(prevSig)) {
        continue;
      }

      _recentSignatures[levelNumber] = candidateSig;

      return LevelModel(
        levelNumber: levelNumber,
        seed: seed,
        gridSize: params.gridSize,
        difficulty: resolvedDifficulty,
        arrowCount: candidate.length,
        maxMistakes: params.maxMistakes,
        arrows: candidate,
      );
    }

    // Relaxed Fallback Pass
    final relaxed = _DifficultyParams(
      gridSize: params.gridSize,
      targetDensity: 0.95,
      maxMistakes: params.maxMistakes,
      minBends: max(0.4, params.minBends - 0.5),
      minDepth: max(1, params.minDepth - 1),
      minArrows: max(4, params.minArrows - 5),
      maxArrowLen: params.maxArrowLen,
      avgTargetLen: params.avgTargetLen,
    );

    for (var attempt = 0; attempt < 20; attempt++) {
      final rng = Random(seed ^ (attempt * 0x7FFFFFED) ^ 0xBEEF);
      final patternType = PatternType.values[rng.nextInt(PatternType.values.length)];
      final shapeMask = PatternGenerator.generateMask(
        type: patternType,
        gridSize: params.gridSize,
        rng: rng,
      );

      final candidate = _synthesizeLevel(
        rng: rng,
        params: relaxed,
        patternType: patternType,
        shapeMask: shapeMask,
      );

      if (candidate != null &&
          candidate.isNotEmpty &&
          LevelSolver.solve(candidate, params.gridSize).solvable) {
        return LevelModel(
          levelNumber: levelNumber,
          seed: seed,
          gridSize: params.gridSize,
          difficulty: resolvedDifficulty,
          arrowCount: candidate.length,
          maxMistakes: params.maxMistakes,
          arrows: candidate,
        );
      }
    }

    return null;
  }

  /// Calculates usable board occupancy.
  static double density(List<ArrowModel> arrows, int gridSize,
      {Set<Cell>? usableMask}) {
    final cells = <Cell>{for (final a in arrows) ...a.occupiedCells};
    final denominator = (usableMask != null && usableMask.isNotEmpty)
        ? usableMask.length
        : (gridSize * gridSize);
    return denominator == 0 ? 0.0 : cells.length / denominator;
  }

  // ── Core synthesis ──────────────────────────────────────────────────────

  static List<ArrowModel>? _synthesizeLevel({
    required Random rng,
    required _DifficultyParams params,
    required PatternType patternType,
    required Set<Cell> shapeMask,
  }) {
    final gridSize = params.gridSize;
    final totalUsable = shapeMask.length;
    final targetOccupied = totalUsable; // 100% filled

    final occupied = <Cell>{};
    final placedArrows = <ArrowModel>[];
    final blockedExitRays = <Cell, Set<int>>{};

    final routeField = _RouteField.values[rng.nextInt(_RouteField.values.length)];

    final targetLengths = _buildTargetLengths(
      targetOccupied: targetOccupied,
      params: params,
      rng: rng,
    );

    for (final targetLen in targetLengths) {
      if (occupied.length >= targetOccupied) break;

      final arrow = _growReverseArrow(
        rng: rng,
        gridSize: gridSize,
        shapeMask: shapeMask,
        occupied: occupied,
        blockedExitRays: blockedExitRays,
        placedArrows: placedArrows,
        field: routeField,
        targetLength: targetLen,
        arrowIndex: placedArrows.length,
      );

      if (arrow != null && arrow.length >= 2) {
        placedArrows.add(arrow);
        occupied.addAll(arrow.occupiedCells);
        _recordExitRay(arrow, gridSize, placedArrows.length - 1, blockedExitRays);
      }
    }

    _absorbRemainingCells(
      placedArrows: placedArrows,
      shapeMask: shapeMask,
      occupied: occupied,
      targetOccupied: targetOccupied,
      gridSize: gridSize,
      rng: rng,
    );

    final theoreticalMax = (targetOccupied / params.avgTargetLen).floor();
    final adaptiveFloor = max(4, (theoreticalMax * 0.70).floor());
    final minArrows = min(params.minArrows, adaptiveFloor);
    if (placedArrows.length < minArrows) return null;

    final forwardArrows = <ArrowModel>[];
    for (var i = 0; i < placedArrows.length; i++) {
      final a = placedArrows[placedArrows.length - 1 - i];
      forwardArrows.add(ArrowModel(
        id: 'a${(i + 1).toString().padLeft(3, '0')}',
        points: a.points,
      ));
    }
    return forwardArrows;
  }

  static List<int> _buildTargetLengths({
    required int targetOccupied,
    required _DifficultyParams params,
    required Random rng,
  }) {
    final lengths = <int>[];
    var sum = 0;
    final maxLen = params.maxArrowLen;

    while (sum < targetOccupied) {
      final roll = rng.nextDouble();
      int len;
      if (roll < 0.35) {
        len = 2 + rng.nextInt(2);
      } else if (roll < 0.75) {
        len = 3 + rng.nextInt(3);
      } else if (roll < 0.95) {
        len = 5 + rng.nextInt(4);
      } else {
        len = 8 + rng.nextInt(max(1, maxLen - 7));
      }
      len = min(len, maxLen);
      lengths.add(len);
      sum += len;
    }

    lengths.shuffle(rng);
    return lengths;
  }

  // ── Reverse arrow growth ───────────────────────────────────────────────

  static ArrowModel? _growReverseArrow({
    required Random rng,
    required int gridSize,
    required Set<Cell> shapeMask,
    required Set<Cell> occupied,
    required Map<Cell, Set<int>> blockedExitRays,
    required List<ArrowModel> placedArrows,
    required _RouteField field,
    required int targetLength,
    required int arrowIndex,
  }) {
    final dirCounts = <ArrowDirection, int>{
      for (final d in ArrowDirection.values) d: 0
    };
    for (final a in placedArrows) {
      dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;
    }

    final candidateHeads = <(Cell, ArrowDirection, double)>[];
    for (final cell in shapeMask) {
      if (occupied.contains(cell)) continue;
      for (final dir in ArrowDirection.values) {
        if (!_isExitRayFree(cell, dir, gridSize, occupied)) continue;
        final backCell = (cell.$1 - dir.dRow, cell.$2 - dir.dCol);
        if (!shapeMask.contains(backCell) || occupied.contains(backCell)) {
          continue;
        }

        candidateHeads.add((
          cell,
          dir,
          _scoreCandidateHead(
            head: cell,
            dir: dir,
            gridSize: gridSize,
            shapeMask: shapeMask,
            occupied: occupied,
            blockedExitRays: blockedExitRays,
            arrowIndex: arrowIndex,
            dirCounts: dirCounts,
            rng: rng,
          )
        ));
      }
    }

    if (candidateHeads.isEmpty) return null;
    candidateHeads.sort((a, b) => b.$3.compareTo(a.$3));

    final topCount = min(6, candidateHeads.length);
    final chosen = candidateHeads[rng.nextInt(topCount)];
    final head = chosen.$1;
    final dir = chosen.$2;

    final path = <Cell>[head, (head.$1 - dir.dRow, head.$2 - dir.dCol)];
    final pathSet = path.toSet();

    var straightRun = 1;
    const maxStraightRun = 4;

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

        var score = 1.0;
        final isTurn = delta.$1 != prevDelta.$1 || delta.$2 != prevDelta.$2;

        if (straightRun >= maxStraightRun && !isTurn) {
          score -= 5.0;
        } else if (isTurn) {
          score += 3.5;
        } else {
          score += 0.5;
        }

        if (blockedExitRays.containsKey(next)) {
          final count = blockedExitRays[next]!.length;
          score += 9.0 + count * 3.0;
        }

        score += _fieldStepScore(field, tail, next, gridSize);

        final freeN = _countFreeNeighbors(next, shapeMask, occupied, pathSet);
        if (freeN == 0 && path.length < targetLength - 1) {
          score -= 2.0;
        } else {
          score += freeN * 0.4;
        }

        neighbors.add((next, score + rng.nextDouble() * 1.2));
      }

      if (neighbors.isEmpty) break;
      neighbors.sort((a, b) => b.$2.compareTo(a.$2));
      final nextCell = neighbors.first.$1;
      final isTurn = (nextCell.$1 - tail.$1) != prevDelta.$1 ||
          (nextCell.$2 - tail.$2) != prevDelta.$2;
      straightRun = isTurn ? 0 : straightRun + 1;

      path.add(nextCell);
      pathSet.add(nextCell);
    }

    if (path.length < 2) return null;
    return ArrowModel(id: 'tmp_$arrowIndex', points: path.reversed.toList());
  }

  static bool _isExitRayFree(
      Cell head, ArrowDirection dir, int gridSize, Set<Cell> occupied) {
    var r = head.$1 + dir.dRow;
    var c = head.$2 + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      if (occupied.contains((r, c))) return false;
      r += dir.dRow;
      c += dir.dCol;
    }
    return true;
  }

  static double _scoreCandidateHead({
    required Cell head,
    required ArrowDirection dir,
    required int gridSize,
    required Set<Cell> shapeMask,
    required Set<Cell> occupied,
    required Map<Cell, Set<int>> blockedExitRays,
    required int arrowIndex,
    required Map<ArrowDirection, int> dirCounts,
    required Random rng,
  }) {
    var score = 2.0;
    final center = (gridSize - 1) / 2.0;
    final distToCenter =
        sqrt(pow(head.$1 - center, 2) + pow(head.$2 - center, 2));

    final maxUsed = dirCounts.values.fold<int>(0, max);
    final thisCount = dirCounts[dir] ?? 0;
    score += (maxUsed - thisCount) * 7.0;

    if (arrowIndex < 6) {
      score += max(0.0, 4.0 - distToCenter * 0.5);
    } else {
      score += distToCenter * 0.2;
    }

    if (blockedExitRays.containsKey(head)) {
      score += 6.0;
    }

    return score + rng.nextDouble() * 2.0;
  }

  static double _fieldStepScore(
      _RouteField field, Cell from, Cell to, int size) {
    final horizontal = from.$1 == to.$1;
    final center = (size - 1) / 2.0;
    final dx = to.$2 - center;
    final dy = to.$1 - center;

    switch (field) {
      case _RouteField.horizontal:
        return horizontal ? 2.5 : 0.2;
      case _RouteField.vertical:
        return horizontal ? 0.2 : 2.5;
      case _RouteField.mixed:
        return ((to.$1 + to.$2) & 1) == 0
            ? (horizontal ? 2.0 : 0.5)
            : (horizontal ? 0.5 : 2.0);
      case _RouteField.zigzag || _RouteField.maze:
        return 2.0;
      case _RouteField.spiral:
        return horizontal ? dy.abs() * 0.35 : dx.abs() * 0.35;
      case _RouteField.radial:
        final fromD = pow(from.$1 - center, 2) + pow(from.$2 - center, 2);
        final toD = pow(to.$1 - center, 2) + pow(to.$2 - center, 2);
        return toD > fromD ? 2.0 : 1.0;
      case _RouteField.diagonal:
        return ((dx.abs() - dy.abs()).abs() < 1.5) ? 2.2 : 0.8;
      case _RouteField.border:
        final bd =
            min(min(to.$1, to.$2), min(size - 1 - to.$1, size - 1 - to.$2));
        return max(0.0, 3.0 - bd * 0.5);
      case _RouteField.organic:
        return 1.0 + sin((to.$1 + to.$2) * 1.4);
    }
  }

  static int _countFreeNeighbors(
      Cell cell, Set<Cell> shapeMask, Set<Cell> occupied, Set<Cell> pathSet) {
    var count = 0;
    for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final n = (cell.$1 + d.$1, cell.$2 + d.$2);
      if (shapeMask.contains(n) &&
          !occupied.contains(n) &&
          !pathSet.contains(n)) {
        count++;
      }
    }
    return count;
  }

  static void _recordExitRay(
      ArrowModel arrow, int gridSize, int idx, Map<Cell, Set<int>> rays) {
    final dir = arrow.exitDirection;
    var r = arrow.headRow + dir.dRow;
    var c = arrow.headCol + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      rays.putIfAbsent((r, c), () => <int>{}).add(idx);
      r += dir.dRow;
      c += dir.dCol;
    }
  }

  static void _absorbRemainingCells({
    required List<ArrowModel> placedArrows,
    required Set<Cell> shapeMask,
    required Set<Cell> occupied,
    required int targetOccupied,
    required int gridSize,
    required Random rng,
  }) {
    if (placedArrows.isEmpty) return;

    // Pass 1: extend existing arrow tails into adjacent free cells
    var modified = true;
    while (occupied.length < targetOccupied && modified) {
      modified = false;
      final indices = List<int>.generate(placedArrows.length, (i) => i)
        ..shuffle(rng);
      for (final i in indices) {
        if (occupied.length >= targetOccupied) break;
        final arrow = placedArrows[i];
        if (arrow.length >= 16) continue;
        final tail = arrow.points.first;

        final deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]..shuffle(rng);
        for (final delta in deltas) {
          final next = (tail.$1 + delta.$1, tail.$2 + delta.$2);
          if (shapeMask.contains(next) && !occupied.contains(next)) {
            placedArrows[i] =
                ArrowModel(id: arrow.id, points: [next, ...arrow.points]);
            occupied.add(next);
            modified = true;
            break;
          }
        }
      }
    }

    // Pass 2: fill remaining 2+ cell gaps with small 2-cell escape arrows
    if (occupied.length < targetOccupied) {
      final dirCounts = <ArrowDirection, int>{
        for (final d in ArrowDirection.values) d: 0
      };
      for (final a in placedArrows) {
        dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;
      }

      for (final cell in shapeMask) {
        if (occupied.contains(cell)) continue;
        final dirs = ArrowDirection.values.toList()
          ..sort((a, b) => (dirCounts[a] ?? 0).compareTo(dirCounts[b] ?? 0));

        for (final dir in dirs) {
          final tail = (cell.$1 - dir.dRow, cell.$2 - dir.dCol);
          if (!shapeMask.contains(tail) || occupied.contains(tail)) continue;
          if (!_isExitRayFree(cell, dir, gridSize, occupied)) continue;

          occupied.addAll([tail, cell]);
          placedArrows
              .add(ArrowModel(id: 'gap_${placedArrows.length}', points: [tail, cell]));
          dirCounts[dir] = (dirCounts[dir] ?? 0) + 1;
          break;
        }
        if (occupied.length >= targetOccupied) break;
      }
    }

    // Pass 3: absorb any remaining single isolated free cells into neighboring arrow tails
    if (occupied.length < targetOccupied) {
      for (final cell in shapeMask) {
        if (occupied.contains(cell)) continue;
        final deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]..shuffle(rng);
        for (final delta in deltas) {
          final neighbor = (cell.$1 + delta.$1, cell.$2 + delta.$2);
          for (var i = 0; i < placedArrows.length; i++) {
            final arrow = placedArrows[i];
            if (arrow.points.first == neighbor) {
              placedArrows[i] =
                  ArrowModel(id: arrow.id, points: [cell, ...arrow.points]);
              occupied.add(cell);
              break;
            } else if (arrow.points.last == neighbor) {
              placedArrows[i] =
                  ArrowModel(id: arrow.id, points: [...arrow.points, cell]);
              occupied.add(cell);
              break;
            }
          }
          if (occupied.contains(cell)) break;
        }
      }
    }
  }

  // ── Quality gate ─────────────────────────────────────────────────────────

  static bool _passesQuality(
      List<ArrowModel> arrows, _DifficultyParams params, Set<Cell> shapeMask) {
    if (arrows.length < params.minArrows) return false;

    final occ = density(arrows, params.gridSize, usableMask: shapeMask);
    if (occ < 0.95) return false; // Requires 95%-100% full cell occupancy

    if (arrows.any((a) => !a.hasValidPath || a.length < 2)) return false;

    final dirCounts = <ArrowDirection, int>{};
    for (final a in arrows) {
      dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;
    }
    final dominant = dirCounts.values.fold<int>(0, max);
    if (dominant / arrows.length > 0.46) return false;

    final totalTurns = arrows.fold<int>(0, (s, a) => s + a.turns);
    if (totalTurns / arrows.length < params.minBends) return false;

    final metrics = DependencyAnalyzer.analyze(arrows, params.gridSize,
        usableMask: shapeMask);
    if (metrics.dependencyDepth < params.minDepth) return false;

    if (_hasLargeEmptyRegion(arrows, shapeMask, params.gridSize)) return false;

    return true;
  }

  static bool _hasLargeEmptyRegion(
      List<ArrowModel> arrows, Set<Cell> shapeMask, int size) {
    final used = <Cell>{for (final a in arrows) ...a.occupiedCells};
    final seen = <Cell>{};
    final maxCluster = max(6, (shapeMask.length * 0.08).ceil());

    for (final cell in shapeMask) {
      if (used.contains(cell) || !seen.add(cell)) continue;
      final queue = [cell];
      var count = 0;
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        count++;
        if (count > maxCluster) return true;
        for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final n = (cur.$1 + d.$1, cur.$2 + d.$2);
          if (shapeMask.contains(n) && !used.contains(n) && seen.add(n)) {
            queue.add(n);
          }
        }
      }
    }
    return false;
  }
}
