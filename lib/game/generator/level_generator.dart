import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/arrow_direction.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../config/difficulty_curve.dart';
import '../solver/level_solver.dart';
import 'dependency_analyzer.dart';
import 'shape_path_generator.dart';
import 'silhouette.dart';

typedef Cell = (int, int);

/// Diagnostic info description.
class LevelLayoutInfo {
  final String shape;
  final String family;

  const LevelLayoutInfo({required this.shape, required this.family});

  @override
  String toString() => '$shape / $family';
}

/// One pass of generation attempts with a given strictness.
class _Stage {
  final int attempts;

  /// 0 = full quality gate; 1–2 = progressively relaxed; 3 = validity and
  /// solvability only.
  final int relax;
  final int Function(int seed, int attempt, int levelNumber) rngSeed;

  const _Stage(this.attempts, this.relax, this.rngSeed);
}

/// Procedural generator producing solver-verified Arrow Escape boards.
///
/// A board is a pure function of (level number, seed, difficulty): the same
/// inputs always give the same board, whatever was generated before. Board
/// size, fill, arrow lengths and the quality bar all come from
/// [DifficultyCurve].
class LevelGenerator {
  LevelGenerator._();

  static final List<_Stage> _stages = [
    _Stage(8, 0, (s, a, n) => s ^ (a * 0x9E3779B9) ^ (n * 31337)),
    _Stage(4, 1, (s, a, n) => s ^ (a * 0x7FFFFFED) ^ 0xBEEF),
    _Stage(4, 2, (s, a, n) => s ^ (a * 0x7FFFFFAB) ^ 0xCAFE),
    _Stage(4, 3, (s, a, n) => s ^ (a * 0x12345678) ^ 0xFEED),
  ];

  /// Board parameters used for [levelNumber], or for [difficulty] when one is
  /// given explicitly (daily challenge, tests).
  static PuzzleSpec specFor(int levelNumber, [Difficulty? difficulty]) =>
      difficulty == null
      ? DifficultyCurve.forLevel(levelNumber)
      : DifficultyCurve.forDifficulty(difficulty);

  /// Campaign silhouette for [levelNumber].
  static Silhouette silhouetteForLevel(int levelNumber) =>
      DifficultyCurve.silhouetteForLevel(levelNumber);

  /// Board size campaign [levelNumber] is built on.
  static int gridForLevel(int levelNumber) => DifficultyCurve.gridFor(
    specFor(levelNumber),
    silhouetteForLevel(levelNumber),
  );

  static Silhouette _silhouetteFor(
    int levelNumber,
    int seed,
    Difficulty? difficulty,
    PuzzleSpec spec,
  ) {
    if (difficulty == null && levelNumber >= 1) {
      return silhouetteForLevel(levelNumber);
    }
    return DifficultyCurve.silhouetteForSeed(
      seed ^ levelNumber,
      spec.gridSize,
      targetCells: spec.targetCells,
    );
  }

  /// Returns layout information for diagnostic tools.
  static LevelLayoutInfo layoutInfo({
    required int levelNumber,
    required int seed,
  }) {
    final s = silhouetteForLevel(levelNumber);
    return LevelLayoutInfo(shape: s.name, family: s.category.name);
  }

  /// Generates a solver-verified board in the level's silhouette. Never
  /// returns null: if every bounded attempt fails, it returns
  /// [guaranteedLevel] filling the same silhouette.
  ///
  /// [silhouette] and [gridSize] override the curve (tests and tools).
  static LevelModel? generate({
    required int levelNumber,
    required int seed,
    Difficulty? difficulty,
    Silhouette? silhouette,
    int? gridSize,
  }) {
    final base = specFor(levelNumber, difficulty);
    final shape =
        silhouette ?? _silhouetteFor(levelNumber, seed, difficulty, base);
    // Board size follows the picture: enough cells for the level's target
    // playable area (see DifficultyCurve.gridFor), unless overridden.
    final spec =
        base.withGridSize(gridSize ?? DifficultyCurve.gridFor(base, shape));

    for (final stage in _stages) {
      // Every valid candidate of a stage competes; the one closest to the
      // curve's planning targets wins, so difficulty follows the curve instead
      // of whatever the first acceptable board happened to be. Deterministic:
      // attempts run in a fixed order and ties keep the earlier candidate.
      List<ArrowModel>? best;
      Set<Cell>? bestMask;
      var bestScore = double.infinity;
      for (var attempt = 0; attempt < stage.attempts; attempt++) {
        final rng = Random(stage.rngSeed(seed, attempt, levelNumber));
        final mask = shape
            .rasterize(
              spec.gridSize,
              mirror: shape.mirrorable && rng.nextBool(),
            )
            .cells;
        final candidate = ShapePathGenerator.generatePaths(
          shapeMask: mask,
          gridSize: spec.gridSize,
          targetDensity: max(0.6, spec.fill - 0.04 * stage.relax),
          levelNumber: levelNumber,
          minArrowLen: 3,
          maxArrowLen: spec.maxAbsorbLen,
          minArrows: spec.minArrowsFor(mask.length),
          averageLength: spec.avgArrowLen,
          maxTierLen: spec.maxTierLen,
          rng: rng,
        );
        if (candidate == null || candidate.isEmpty) continue;
        if (!_isValidBoard(candidate, spec.gridSize)) continue;
        if (stage.relax < 3 &&
            !_passesQuality(candidate, spec, mask, stage.relax)) {
          continue;
        }
        // Solver gate (rule 9) plus the planning measurements in one pass.
        final plan = LevelSolver.planningStats(candidate, spec.gridSize);
        if (plan == null) continue;
        if (stage.relax < 3 &&
            !_passesPlanning(candidate.length, plan, spec, stage.relax)) {
          continue;
        }

        final score = _targetDistance(candidate, plan, spec, mask);
        if (score < bestScore) {
          best = candidate;
          bestMask = mask;
          bestScore = score;
        }
        if (score <= _goodEnough) break;
      }

      if (best != null) {
        if (kDebugMode) {
          final m = DependencyAnalyzer.analyze(
            best,
            spec.gridSize,
            usableMask: bestMask,
          );
          final plan = LevelSolver.planningStats(best, spec.gridSize)!;
          debugPrint(
            '[LevelGen] L$levelNumber ${shape.id} '
            '${spec.gridSize}x${spec.gridSize} stage ${stage.relax} '
            'arrows ${best.length} occ '
            '${(m.occupancy * 100).toStringAsFixed(0)}% avgLen '
            '${m.averagePathLength.toStringAsFixed(1)} rounds ${plan.rounds} '
            'blocked ${(1 - plan.initiallyFree / best.length).toStringAsFixed(2)}',
          );
        }
        return _model(
          levelNumber,
          seed,
          spec,
          best,
          shapeName: shape.name,
          shapeCells: bestMask!,
        );
      }
    }

    return guaranteedLevel(
      levelNumber: levelNumber,
      seed: seed,
      spec: spec,
      mask: shape.rasterize(spec.gridSize).cells,
      shapeName: shape.name,
    );
  }

  /// Last-resort board that is valid and solvable by construction: each row
  /// of the [mask] (the whole board when null) is cut into straight 3–5 cell
  /// arrows that all point the same way (alternating per row), so each row
  /// clears from its exit side inward. Rows of the silhouette stay filled, so
  /// even this board keeps the picture.
  static LevelModel guaranteedLevel({
    required int levelNumber,
    required int seed,
    PuzzleSpec? spec,
    Set<Cell>? mask,
    String? shapeName,
  }) {
    final s = spec ?? specFor(levelNumber);
    final n = s.gridSize;
    bool usable(int r, int c) => mask == null || mask.contains((r, c));
    final arrows = <ArrowModel>[];
    for (var r = 0; r < n; r++) {
      final right = r.isEven;
      var c = 0;
      while (c < n) {
        if (!usable(r, c)) {
          c++;
          continue;
        }
        var end = c;
        while (end < n && usable(r, end)) {
          end++;
        }
        // Run [c, end): split into arrows of 3, the last one absorbing 1–2.
        var start = c;
        while (end - start >= 3) {
          var len = 3;
          if (end - start - len < 3) len = end - start;
          final cols = [for (var x = start; x < start + len; x++) x];
          final ordered = right ? cols : cols.reversed.toList();
          arrows.add(
            ArrowModel(
              id: 'a${(arrows.length + 1).toString().padLeft(3, '0')}',
              points: [for (final x in ordered) (r, x)],
            ),
          );
          start += len;
        }
        c = end;
      }
    }

    // Second pass for silhouettes: vertical parts (legs, stems, masts) are
    // too narrow for row arrows, so leftover column runs become vertical
    // arrows. Each one is kept only if the board stays solvable.
    if (mask != null) {
      final used = <Cell>{for (final a in arrows) ...a.occupiedCells};
      for (var c = 0; c < n; c++) {
        var r = 0;
        while (r < n) {
          if (!usable(r, c) || used.contains((r, c))) {
            r++;
            continue;
          }
          var end = r;
          while (end < n && usable(end, c) && !used.contains((end, c))) {
            end++;
          }
          var start = r;
          while (end - start >= 3) {
            var len = 3;
            if (end - start - len < 3) len = end - start;
            final rows = [for (var y = start; y < start + len; y++) y];
            for (final down in [true, false]) {
              final ordered = down ? rows : rows.reversed.toList();
              final arrow = ArrowModel(
                id: 'a${(arrows.length + 1).toString().padLeft(3, '0')}',
                points: [for (final y in ordered) (y, c)],
              );
              if (LevelSolver.solve([...arrows, arrow], n).solvable) {
                arrows.add(arrow);
                used.addAll(arrow.occupiedCells);
                break;
              }
            }
            start += len;
          }
          r = end;
        }
      }
    }

    if (arrows.isEmpty && mask != null) {
      return guaranteedLevel(levelNumber: levelNumber, seed: seed, spec: s);
    }
    assert(LevelSolver.solve(arrows, n).solvable);
    return _model(
      levelNumber,
      seed,
      s,
      arrows,
      shapeName: shapeName,
      shapeCells: mask ?? const {},
    );
  }

  static LevelModel _model(
    int levelNumber,
    int seed,
    PuzzleSpec spec,
    List<ArrowModel> arrows, {
    String? shapeName,
    Set<Cell> shapeCells = const {},
  }) {
    return LevelModel(
      levelNumber: levelNumber,
      seed: seed,
      gridSize: spec.gridSize,
      difficulty: spec.difficulty,
      arrowCount: arrows.length,
      maxMistakes: AppConstants.maxLives,
      arrows: arrows,
      shapeName: shapeName,
      shapeCells: shapeCells,
    );
  }

  /// Calculates usable board occupancy.
  static double density(
    List<ArrowModel> arrows,
    int gridSize, {
    Set<Cell>? usableMask,
  }) {
    final cells = <Cell>{for (final a in arrows) ...a.occupiedCells};
    final denominator = (usableMask != null && usableMask.isNotEmpty)
        ? usableMask.length
        : (gridSize * gridSize);
    return denominator == 0 ? 0.0 : cells.length / denominator;
  }

  static double boardOccupancy(List<ArrowModel> arrows, int gridSize) {
    final cells = <Cell>{for (final a in arrows) ...a.occupiedCells};
    return cells.length / (gridSize * gridSize);
  }

  // ── Validity and quality ──────────────────────────────────────────────────

  /// Well-formed paths of 3+ cells, inside the grid, no overlaps, unique ids.
  static bool _isValidBoard(List<ArrowModel> arrows, int gridSize) {
    final seen = <Cell>{};
    final ids = <String>{};
    for (final a in arrows) {
      if (!ids.add(a.id)) return false;
      if (!a.hasValidPath || a.length < 3) return false;
      if (!LevelSolver.isWithinGrid(a, gridSize)) return false;
      for (final cell in a.occupiedCells) {
        if (!seen.add(cell)) return false;
      }
    }
    return true;
  }

  static bool _passesQuality(
    List<ArrowModel> arrows,
    PuzzleSpec spec,
    Set<Cell> mask,
    int relax,
  ) {
    final minArrows = (spec.minArrowsFor(mask.length) * (1 - 0.2 * relax))
        .floor()
        .clamp(3, 1 << 20);
    if (arrows.length < minArrows) return false;

    final occFloor = spec.minOccupancy * (1 - 0.05 * relax);
    if (density(arrows, spec.gridSize, usableMask: mask) < occFloor) {
      return false;
    }

    final dirCounts = <ArrowDirection, int>{};
    for (final a in arrows) {
      dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;
    }
    final dominant = dirCounts.values.fold<int>(0, max);
    if (arrows.length >= 5 && dominant / arrows.length > 0.75 + 0.1 * relax) {
      return false;
    }

    final totalTurns = arrows.fold<int>(0, (s, a) => s + a.turns);
    if (totalTurns / arrows.length < spec.minAvgBends - 0.15 * relax) {
      return false;
    }

    final metrics = DependencyAnalyzer.analyze(
      arrows,
      spec.gridSize,
      usableMask: mask,
    );
    if (metrics.dependencyDepth < max(1, spec.minDepth - relax)) return false;

    if (relax == 0 && _hasLargeEmptyRegion(arrows, mask)) return false;

    return true;
  }

  /// A candidate this close to the targets is accepted without trying more.
  static const double _goodEnough = 0.45;

  /// Planning floor: enough arrows, enough waves of dependencies, and enough
  /// arrows blocked at the start; plus a ceiling at full strictness so one
  /// level never spikes far above its neighbours.
  static bool _passesPlanning(
    int arrowCount,
    ({int rounds, int initiallyFree}) plan,
    PuzzleSpec spec,
    int relax,
  ) {
    if (arrowCount < (spec.arrowFloor * (1 - 0.2 * relax)).floor()) {
      return false;
    }
    final minRounds = max(2, spec.targetRounds.floor() - 1 - relax);
    if (plan.rounds < minRounds) return false;
    if (relax == 0 && plan.rounds > spec.targetRounds + 5) return false;
    final blocked = 1 - plan.initiallyFree / arrowCount;
    if (blocked < spec.targetBlockedShare - 0.15 - 0.05 * relax) return false;
    return true;
  }

  /// How far a candidate is from the curve's targets (0 = exact): planning
  /// rounds, traps at the start, arrow count, and how completely the arrows
  /// draw the silhouette (an unfilled picture is penalised).
  static double _targetDistance(
    List<ArrowModel> arrows,
    ({int rounds, int initiallyFree}) plan,
    PuzzleSpec spec,
    Set<Cell> mask,
  ) {
    final arrowCount = arrows.length;
    final blocked = 1 - plan.initiallyFree / arrowCount;
    final roundsOff =
        (plan.rounds - spec.targetRounds).abs() / spec.targetRounds * 2;
    final blockedOff = (blocked - spec.targetBlockedShare).abs() * 2.5;
    final arrowsShort =
        max(0, spec.arrowFloor - arrowCount) / max(1, spec.arrowFloor);
    final unfilled = 1 - density(arrows, spec.gridSize, usableMask: mask);
    return roundsOff + blockedOff + arrowsShort + unfilled * 2;
  }

  static bool _hasLargeEmptyRegion(List<ArrowModel> arrows, Set<Cell> mask) {
    final used = <Cell>{for (final a in arrows) ...a.occupiedCells};
    final seen = <Cell>{};
    final maxCluster = max(6, (mask.length * 0.15).ceil());

    for (final cell in mask) {
      if (used.contains(cell) || !seen.add(cell)) continue;
      final queue = [cell];
      var count = 0;
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        count++;
        if (count > maxCluster) return true;
        for (final d in const <Cell>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final n = (cur.$1 + d.$1, cur.$2 + d.$2);
          if (mask.contains(n) && !used.contains(n) && seen.add(n)) {
            queue.add(n);
          }
        }
      }
    }
    return false;
  }
}
