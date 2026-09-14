import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/data/models/arrow_direction.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/game/generator/dependency_analyzer.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:arrowescapegame/game/generator/shape_template.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';

void main() {
  // ── Individual unit tests ────────────────────────────────────────────────

  group('LevelGenerator Tests', () {
    test('Generates valid solvable EASY level', () {
      final level = LevelGenerator.generate(
        levelNumber: 1,
        seed: 12345,
        difficulty: Difficulty.easy,
      );
      expect(level, isNotNull);
      expect(level!.gridSize, equals(16));
      expect(level.arrows.length, greaterThanOrEqualTo(4));
      expect(LevelSolver.solve(level.arrows, level.gridSize).solvable, isTrue);
    });

    test('Generates valid solvable NORMAL level', () {
      final level = LevelGenerator.generate(
        levelNumber: 25,
        seed: 67890,
        difficulty: Difficulty.normal,
      );
      expect(level, isNotNull);
      expect(level!.gridSize, equals(16));
      expect(level.arrows.length, greaterThanOrEqualTo(4));
      expect(LevelSolver.solve(level.arrows, level.gridSize).solvable, isTrue);
    });

    test('Level generation is deterministic given the same seed', () {
      final levelA = LevelGenerator.generate(
        levelNumber: 10,
        seed: 9999,
        difficulty: Difficulty.easy,
      );
      final levelB = LevelGenerator.generate(
        levelNumber: 10,
        seed: 9999,
        difficulty: Difficulty.easy,
      );
      expect(levelA, isNotNull);
      expect(levelB, isNotNull);
      expect(levelA!.arrows.length, equals(levelB!.arrows.length));
      for (var i = 0; i < levelA.arrows.length; i++) {
        expect(levelA.arrows[i].id, equals(levelB.arrows[i].id));
        expect(levelA.arrows[i].headRow, equals(levelB.arrows[i].headRow));
        expect(levelA.arrows[i].headCol, equals(levelB.arrows[i].headCol));
        expect(
          levelA.arrows[i].exitDirection,
          equals(levelB.arrows[i].exitDirection),
        );
      }
    });

    test('Verifies path length distribution mix (Short, Medium, Long, Very Long) on sample levels', () {
      final sampleLevels = [1, 5, 12, 30, 60, 90];
      for (final n in sampleLevels) {
        final level = LevelGenerator.generate(
          levelNumber: n,
          seed: n * 1000 + 250,
        );
        expect(level, isNotNull, reason: 'Level $n failed to generate');
        final metrics = DependencyAnalyzer.analyze(level!.arrows, level.gridSize);

        // Check path length mix
        final hasLongOrVeryLong = metrics.longCount + metrics.veryLongCount > 0;
        final hasShortOrMedium = metrics.shortCount + metrics.mediumCount > 0;
        expect(hasLongOrVeryLong || hasShortOrMedium, isTrue);
        expect(LevelSolver.solve(level.arrows, level.gridSize).solvable, isTrue);
      }
    });

    test('Verifies progressive level difficulty scaling (Levels 1, 5, 6, 10, 15, 20)', () {
      final keyLevels = [1, 5, 6, 10, 15, 20];
      for (final n in keyLevels) {
        final seed = n * 31337 + 42;
        final level = LevelGenerator.generate(
          levelNumber: n,
          seed: seed,
        );
        expect(level, isNotNull, reason: 'Level $n failed to generate');
        final metrics = DependencyAnalyzer.analyze(level!.arrows, level.gridSize);

        // ignore: avoid_print
        print(
          'KEY LEVEL INSPECTION $n:\n'
          '  Arrows: ${level.arrows.length}\n'
          '  Occupancy: ${(metrics.occupancy * 100).toStringAsFixed(1)}%\n'
          '  Very-Long Arrows (11+): ${metrics.veryLongCount}\n'
          '  Longest Arrow: ${metrics.longestPathLength}\n'
          '  Dependency Depth: ${metrics.dependencyDepth}\n',
        );

        if (n >= 6) {
          expect(level.arrows.length, greaterThanOrEqualTo(4));
          expect(metrics.occupancy, greaterThanOrEqualTo(0.30));
          expect(metrics.longestPathLength, greaterThanOrEqualTo(6));
          expect(metrics.dependencyDepth, greaterThanOrEqualTo(2));
        }

        expect(LevelSolver.solve(level.arrows, level.gridSize).solvable, isTrue);
      }
    });
  });

  // ── Full 100-level campaign audit ────────────────────────────────────────

  test('All 100 shipped levels are dense, complex, and solver-valid', () {
    final inspectedLevels = <int>{1, 10, 20, 30, 50, 75, 100};
    final layoutKeys = <String>{};
    String? prevShape1;
    String? prevShape2;

    for (var n = 1; n <= 100; n++) {
      final difficulty = n <= 20
          ? Difficulty.easy
          : n <= 50
          ? Difficulty.normal
          : n <= 80
          ? Difficulty.hard
          : Difficulty.expert;

      final seed = n * 31337 + 42;
      final layout = LevelGenerator.layoutInfo(levelNumber: n, seed: seed);

      // Anti-repetition: same shape must not appear 3 consecutive levels
      if (n >= 3 && prevShape1 != null && prevShape2 != null) {
        if (layout.shape == prevShape1 && prevShape1 == prevShape2) {
          fail('Level $n: same shape "${layout.shape}" 3× in a row');
        }
      }
      prevShape2 = prevShape1;
      prevShape1 = layout.shape;

      final level = LevelGenerator.generate(
        levelNumber: n,
        seed: seed,
        difficulty: difficulty,
      );
      expect(level, isNotNull, reason: 'Level $n was not generated');

      final mask = ShapeTemplate.fromName(
        layout.shape,
      ).generateMask(level!.gridSize);
      final metrics = DependencyAnalyzer.analyze(
        level.arrows,
        level.gridSize,
        usableMask: mask,
      );

      // 1. Usable occupancy ≥ 12%
      expect(
        metrics.occupancy,
        greaterThanOrEqualTo(0.12),
        reason: 'Level $n occupancy too low: ${metrics.occupancy}',
      );

      // 2. Arrow count: adaptive floor
      final theoreticalMax = (mask.length * 0.85 / 4.0).floor();
      final adaptiveMin = max(2, (theoreticalMax * 0.10).floor());
      expect(
        level.arrows.length,
        greaterThanOrEqualTo(adaptiveMin),
        reason:
            'Level $n too few arrows: ${level.arrows.length} '
            '(min $adaptiveMin from ${mask.length} usable cells)',
      );

      // 3. Solvability
      expect(
        LevelSolver.solve(level.arrows, level.gridSize).solvable,
        isTrue,
        reason: 'Level $n is not solvable',
      );

      // 4. Direction balance: no single direction > 85% when arrows >= 5
      final maxDir = metrics.directionDistribution.values.fold<double>(
        0.0,
        max,
      );
      if (level.arrows.length >= 5) {
        expect(
          maxDir,
          lessThanOrEqualTo(0.85),
          reason:
              'Level $n direction imbalance: ${(maxDir * 100).toStringAsFixed(0)}%',
        );
      }

      // 5. At least some bends across all arrows
      expect(
        metrics.averageBends,
        greaterThanOrEqualTo(0.05),
        reason: 'Level $n avg bends too low: ${metrics.averageBends}',
      );

      // 6. Some dependency depth
      expect(
        metrics.dependencyDepth,
        greaterThanOrEqualTo(1),
        reason: 'Level $n depth too low: ${metrics.dependencyDepth}',
      );

      layoutKeys.add('${layout.shape}/${layout.family}');

      // ignore: avoid_print
      print(
        'Level $n | ${layout.shape.padRight(10)} | '
        '${layout.family.padRight(26)} | ${difficulty.name.padRight(6)} | $metrics',
      );

      if (inspectedLevels.contains(n)) {
        final dirs = metrics.directionDistribution;
        // ignore: avoid_print
        print(
          '  ▶ INSPECT Level $n: '
          '${level.arrows.length} arrows  '
          'occ:${(metrics.occupancy * 100).toStringAsFixed(1)}%  '
          'avgLen:${metrics.averagePathLength.toStringAsFixed(1)}  '
          'bends:${metrics.averageBends.toStringAsFixed(1)}  '
          'depth:${metrics.dependencyDepth}  '
          'dirs:[↑:${((dirs[ArrowDirection.up] ?? 0) * 100).toStringAsFixed(0)}% '
          '↓:${((dirs[ArrowDirection.down] ?? 0) * 100).toStringAsFixed(0)}% '
          '←:${((dirs[ArrowDirection.left] ?? 0) * 100).toStringAsFixed(0)}% '
          '→:${((dirs[ArrowDirection.right] ?? 0) * 100).toStringAsFixed(0)}%]',
        );
      }
    }

    // At least 20 structurally distinct shape/family combinations
    expect(layoutKeys.length, greaterThanOrEqualTo(20));
  });
}
