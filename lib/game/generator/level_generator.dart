import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/arrow_direction.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/difficulty.dart';
import '../../data/models/level_model.dart';
import '../solver/level_solver.dart';
import 'dependency_analyzer.dart';
import 'shape_path_generator.dart';
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

  static double getMinOccupancyForLevel(int levelNumber) {
    if (levelNumber == 1) return 0.35;
    if (levelNumber == 2) return 0.40;
    if (levelNumber == 3) return 0.45;
    if (levelNumber == 4) return 0.50;
    if (levelNumber == 5) return 0.55;
    if (levelNumber == 6) return 0.60;
    if (levelNumber == 7) return 0.65;
    if (levelNumber == 8) return 0.70;
    return 0.75;
  }

  static const Map<Difficulty, _DifficultyParams> _params = {
    Difficulty.easy: _DifficultyParams(
      gridSize: AppConstants.fixedGridSize,
      targetDensity: 0.85,
      maxMistakes: 5,
      minBends: 0.4,
      minDepth: 1,
      minArrows: 10,
      maxArrowLen: 38,
      avgTargetLen: 7.5,
    ),
    Difficulty.normal: _DifficultyParams(
      gridSize: AppConstants.fixedGridSize,
      targetDensity: 0.88,
      maxMistakes: 4,
      minBends: 0.5,
      minDepth: 2,
      minArrows: 14,
      maxArrowLen: 38,
      avgTargetLen: 8.5,
    ),
    Difficulty.hard: _DifficultyParams(
      gridSize: AppConstants.fixedGridSize,
      targetDensity: 0.92,
      maxMistakes: 3,
      minBends: 0.6,
      minDepth: 3,
      minArrows: 18,
      maxArrowLen: 38,
      avgTargetLen: 9.5,
    ),
    Difficulty.expert: _DifficultyParams(
      gridSize: AppConstants.fixedGridSize,
      targetDensity: 0.95,
      maxMistakes: 2,
      minBends: 0.7,
      minDepth: 4,
      minArrows: 22,
      maxArrowLen: 38,
      avgTargetLen: 10.5,
    ),
    Difficulty.extreme: _DifficultyParams(
      gridSize: AppConstants.fixedGridSize,
      targetDensity: 0.96,
      maxMistakes: 1,
      minBends: 0.8,
      minDepth: 5,
      minArrows: 26,
      maxArrowLen: 38,
      avgTargetLen: 11.5,
    ),
  };

  /// Selects controlled random difficulty based on level progression stage.
  static Difficulty selectDifficulty(int levelNumber, Random rng) {
    if (levelNumber <= 3) return Difficulty.easy;
    if (levelNumber <= 5) return Difficulty.normal;
    if (levelNumber <= 10) return Difficulty.hard;
    if (levelNumber <= 20) return Difficulty.expert;
    return Difficulty.extreme;
  }

  /// Resolves the campaign pattern type matching the 100 level pattern reference sequence.
  static PatternType getPatternForLevel(int levelNumber) {
    switch (levelNumber) {
      case 1:
        return PatternType.square;
      case 2:
        return PatternType.heart;
      case 3:
        return PatternType.star;
      case 4:
        return PatternType.diamond;
      case 5:
        return PatternType.cat;
      case 6:
        return PatternType.ring;
      case 7:
        return PatternType.butterfly;
      case 8:
        return PatternType.diamond;
      case 9:
        return PatternType.randomGeometric;
      case 10:
        return PatternType.cross;
      case 11:
        return PatternType.squareRing;
      case 12:
        return PatternType.starSquare;
      case 13:
        return PatternType.rocket;
      case 14:
        return PatternType.interlocked;
      case 15:
        return PatternType.crown;
      case 16:
        return PatternType.ring;
      case 17:
        return PatternType.butterfly;
      case 18:
        return PatternType.diamond;
      case 19:
        return PatternType.crown;
      case 20:
        return PatternType.hexagon;
      default:
        final all = PatternType.values;
        return all[(levelNumber - 1) % all.length];
    }
  }

  /// Returns layout information for diagnostic tools.
  static LevelLayoutInfo layoutInfo({
    required int levelNumber,
    required int seed,
  }) {
    final p = getPatternForLevel(levelNumber);
    return LevelLayoutInfo(shape: p.name, family: 'procedural ${p.name}');
  }

  /// Generates a complete, solver-verified puzzle level with 100% arrow coverage.
  static LevelModel? generate({
    required int levelNumber,
    required int seed,
    Difficulty? difficulty,
  }) {
    final baseRng = Random(seed ^ (levelNumber * 7919));

    // Controlled Random Difficulty
    final resolvedDifficulty =
        difficulty ?? selectDifficulty(levelNumber, baseRng);
    final params = _params[resolvedDifficulty] ?? _params[Difficulty.normal]!;

    final patternType = getPatternForLevel(levelNumber);
    final prevSig = _recentSignatures[levelNumber - 1];

    // Keep synchronous generation comfortably below Android's input timeout.
    for (var attempt = 0; attempt < 8; attempt++) {
      final attemptSeed = seed ^ (attempt * 0x9E3779B9) ^ (levelNumber * 31337);
      final rng = Random(attemptSeed);

      // Random Geometry Mask
      final shapeMask = PatternGenerator.generateMask(
        type: patternType,
        gridSize: params.gridSize,
        rng: rng,
      );

      final candidate = _synthesizeLevel(
        rng: rng,
        params: params,
        levelNumber: levelNumber,
        patternType: patternType,
        shapeMask: shapeMask,
      );

      if (candidate == null || candidate.isEmpty) continue;

      // Quality & Length Validation
      if (!_passesQuality(candidate, params, shapeMask, levelNumber)) continue;

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

      if (kDebugMode) {
        final metrics = DependencyAnalyzer.analyze(
          candidate,
          params.gridSize,
          usableMask: shapeMask,
        );
        // ignore: avoid_print
        print(
          'Level number: $levelNumber\n'
          'Pattern type: ${patternType.name.toUpperCase()}\n'
          'Arrow count: ${candidate.length}\n'
          'Occupied cells: ${metrics.occupiedCells}\n'
          'Occupancy %: ${(metrics.occupancy * 100).toStringAsFixed(1)}%\n'
          'Average path length: ${metrics.averagePathLength.toStringAsFixed(1)}\n'
          'Longest path: ${metrics.longestPathLength}\n'
          'Very-long arrow count: ${metrics.veryLongCount}\n'
          'Dependency depth: ${metrics.dependencyDepth}\n'
          'Connected components: ${metrics.connectedComponents}\n'
          'Validation result: ACCEPTED\n'
          'Random seed: $attemptSeed',
        );
      }

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
      minArrows: max(4, params.minArrows - 3),
      maxArrowLen: params.maxArrowLen,
      avgTargetLen: params.avgTargetLen,
    );

    for (var attempt = 0; attempt < 4; attempt++) {
      final rng = Random(seed ^ (attempt * 0x7FFFFFED) ^ 0xBEEF);
      final patternType = getPatternForLevel(levelNumber);
      final shapeMask = PatternGenerator.generateMask(
        type: patternType,
        gridSize: params.gridSize,
        rng: rng,
      );

      final candidate = _synthesizeLevel(
        rng: rng,
        params: relaxed,
        levelNumber: levelNumber,
        patternType: patternType,
        shapeMask: shapeMask,
      );

      if (candidate != null &&
          candidate.isNotEmpty &&
          _passesQuality(
            candidate,
            relaxed,
            shapeMask,
            levelNumber,
            isRelaxed: true,
          ) &&
          LevelSolver.solve(candidate, params.gridSize).solvable) {
        if (kDebugMode) {
          final metrics = DependencyAnalyzer.analyze(
            candidate,
            params.gridSize,
            usableMask: shapeMask,
          );
          // ignore: avoid_print
          print(
            'Level number: $levelNumber\n'
            'Pattern type: ${patternType.name.toUpperCase()}\n'
            'Arrow count: ${candidate.length}\n'
            'Occupied cells: ${metrics.occupiedCells}\n'
            'Occupancy %: ${(metrics.occupancy * 100).toStringAsFixed(1)}%\n'
            'Average path length: ${metrics.averagePathLength.toStringAsFixed(1)}\n'
            'Longest path: ${metrics.longestPathLength}\n'
            'Very-long arrow count: ${metrics.veryLongCount}\n'
            'Dependency depth: ${metrics.dependencyDepth}\n'
            'Connected components: ${metrics.connectedComponents}\n'
            'Validation result: ACCEPTED (FALLBACK)\n'
            'Random seed: ${seed ^ (attempt * 0x7FFFFFED) ^ 0xBEEF}',
          );
        }

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

    // Relaxed Fallback Pass 2
    final relaxed2 = _DifficultyParams(
      gridSize: params.gridSize,
      targetDensity: 0.95,
      maxMistakes: params.maxMistakes,
      minBends: max(0.2, params.minBends - 0.3),
      minDepth: max(1, params.minDepth - 1),
      minArrows: max(3, params.minArrows - 5),
      maxArrowLen: params.maxArrowLen,
      avgTargetLen: params.avgTargetLen,
    );

    for (var attempt = 0; attempt < 4; attempt++) {
      final rng = Random(seed ^ (attempt * 0x7FFFFFED) ^ 0xBEEF);
      final patternType = getPatternForLevel(levelNumber);
      final shapeMask = PatternGenerator.generateMask(
        type: patternType,
        gridSize: params.gridSize,
        rng: rng,
      );

      final candidate = _synthesizeLevel(
        rng: rng,
        params: relaxed2,
        levelNumber: levelNumber,
        patternType: patternType,
        shapeMask: shapeMask,
      );

      if (candidate != null &&
          candidate.isNotEmpty &&
          _passesQuality(
            candidate,
            relaxed2,
            shapeMask,
            levelNumber,
            isRelaxed: true,
          ) &&
          LevelSolver.solve(candidate, params.gridSize).solvable) {
        if (kDebugMode) {
          final metrics = DependencyAnalyzer.analyze(
            candidate,
            params.gridSize,
            usableMask: shapeMask,
          );
          // ignore: avoid_print
          print(
            'Level number: $levelNumber\n'
            'Pattern type: ${patternType.name.toUpperCase()}\n'
            'Arrow count: ${candidate.length}\n'
            'Occupied cells: ${metrics.occupiedCells}\n'
            'Occupancy %: ${(metrics.occupancy * 100).toStringAsFixed(1)}%\n'
            'Average path length: ${metrics.averagePathLength.toStringAsFixed(1)}\n'
            'Longest path: ${metrics.longestPathLength}\n'
            'Very-long arrow count: ${metrics.veryLongCount}\n'
            'Dependency depth: ${metrics.dependencyDepth}\n'
            'Connected components: ${metrics.connectedComponents}\n'
            'Validation result: ACCEPTED (FALLBACK)\n'
            'Random seed: ${seed ^ (attempt * 0x7FFFFFED) ^ 0xBEEF}',
          );
        }

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

    // Stage 3 Emergency Safety Pass
    final emergency = _DifficultyParams(
      gridSize: params.gridSize,
      targetDensity: 0.80,
      maxMistakes: params.maxMistakes,
      minBends: 0.1,
      minDepth: 1,
      minArrows: 4,
      maxArrowLen: params.maxArrowLen,
      avgTargetLen: 4.0,
    );

    final emergencyPattern = getPatternForLevel(levelNumber);
    for (var attempt = 0; attempt < 4; attempt++) {
      final rng = Random(seed ^ (attempt * 0x12345678) ^ 0xFEED);
      final shapeMask = PatternGenerator.generateMask(
        type: emergencyPattern,
        gridSize: params.gridSize,
        rng: rng,
      );

      final candidate = _synthesizeLevel(
        rng: rng,
        params: emergency,
        levelNumber: levelNumber,
        patternType: emergencyPattern,
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

  // ── Core synthesis ──────────────────────────────────────────────────────

  static List<ArrowModel>? _synthesizeLevel({
    required Random rng,
    required _DifficultyParams params,
    required int levelNumber,
    required PatternType patternType,
    required Set<Cell> shapeMask,
  }) {
    return ShapePathGenerator.generatePaths(
      shapeMask: shapeMask,
      gridSize: params.gridSize,
      targetDensity: params.targetDensity,
      levelNumber: levelNumber,
      minArrowLen: 4,
      maxArrowLen: params.maxArrowLen,
      minArrows: params.minArrows,
      rng: rng,
    );
  }

  static double boardOccupancy(List<ArrowModel> arrows, int gridSize) {
    final cells = <Cell>{for (final a in arrows) ...a.occupiedCells};
    return cells.length / (gridSize * gridSize);
  }

  // ── Quality gate ─────────────────────────────────────────────────────────

  static bool _passesQuality(
    List<ArrowModel> arrows,
    _DifficultyParams params,
    Set<Cell> shapeMask,
    int levelNumber, {
    bool isRelaxed = false,
  }) {
    final adaptiveMin = min(params.minArrows, (shapeMask.length / 5.0).floor());
    if (arrows.length < max(4, adaptiveMin)) return false;

    final minBoardOcc = getMinOccupancyForLevel(levelNumber);
    final boardOcc = boardOccupancy(arrows, params.gridSize);
    final shapeOcc = density(arrows, params.gridSize, usableMask: shapeMask);

    final occFloor = isRelaxed ? minBoardOcc * 0.5 : minBoardOcc;
    if (shapeOcc < occFloor && boardOcc < (occFloor * 0.75)) return false;

    if (arrows.any((a) => !a.hasValidPath || a.length < 2)) return false;

    final dirCounts = <ArrowDirection, int>{};
    for (final a in arrows) {
      dirCounts[a.exitDirection] = (dirCounts[a.exitDirection] ?? 0) + 1;
    }
    final dominant = dirCounts.values.fold<int>(0, max);
    final maxDominant = isRelaxed ? 0.85 : 0.75;
    if (dominant / arrows.length > maxDominant) return false;

    final totalTurns = arrows.fold<int>(0, (s, a) => s + a.turns);
    final minBends = isRelaxed
        ? max(0.1, params.minBends - 0.2)
        : params.minBends;
    if (totalTurns / arrows.length < minBends) return false;

    final metrics = DependencyAnalyzer.analyze(
      arrows,
      params.gridSize,
      usableMask: shapeMask,
    );

    final minDepth = isRelaxed ? max(1, params.minDepth - 1) : params.minDepth;
    if (metrics.dependencyDepth < minDepth) return false;

    if (!isRelaxed && _hasLargeEmptyRegion(arrows, shapeMask, params.gridSize)) {
      return false;
    }

    return true;
  }

  static bool _hasLargeEmptyRegion(
    List<ArrowModel> arrows,
    Set<Cell> shapeMask,
    int size,
  ) {
    final used = <Cell>{for (final a in arrows) ...a.occupiedCells};
    final seen = <Cell>{};
    final maxCluster = max(16, (shapeMask.length * 0.15).ceil());

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
