import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/game/config/difficulty_curve.dart';
import 'package:arrowescapegame/game/generator/dependency_analyzer.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';

LevelModel _campaign(int n) =>
    LevelGenerator.generate(levelNumber: n, seed: AppConstants.levelSeed(n))!;

List<List<Object>> _boardKey(LevelModel l) =>
    [for (final a in l.arrows) [a.id, a.points]];

/// Structural validity under the game's real rules.
void _expectValidBoard(LevelModel level, {String reason = ''}) {
  final n = level.gridSize;
  final seen = <(int, int)>{};
  final ids = <String>{};
  for (final a in level.arrows) {
    expect(ids.add(a.id), isTrue, reason: '$reason duplicate id ${a.id}');
    expect(a.hasValidPath, isTrue, reason: '$reason malformed path ${a.id}');
    expect(a.length, greaterThanOrEqualTo(3), reason: '$reason short ${a.id}');
    expect(LevelSolver.isWithinGrid(a, n), isTrue,
        reason: '$reason out of bounds ${a.id}');
    for (final cell in a.occupiedCells) {
      expect(seen.add(cell), isTrue, reason: '$reason overlap at $cell');
    }
  }
  final solved = LevelSolver.solve(level.arrows, n);
  expect(solved.solvable, isTrue, reason: '$reason not solvable');
  expect(solved.solution.length, level.arrows.length);
}

void main() {
  group('Explicit difficulty (daily challenge, tools)', () {
    for (final d in Difficulty.values) {
      test('${d.name} uses its representative spec and is valid', () {
        final level = LevelGenerator.generate(
          levelNumber: 0,
          seed: 20261009,
          difficulty: d,
        )!;
        // Board sized for the representative spec's area and the day's shape.
        final spec = DifficultyCurve.forDifficulty(d);
        final shape = DifficultyCurve.silhouetteForSeed(
          20261009,
          spec.gridSize,
          targetCells: spec.targetCells,
        );
        expect(level.gridSize, DifficultyCurve.gridFor(spec, shape));
        expect(level.shapeName, shape.name);
        expect(level.difficulty, d);
        _expectValidBoard(level, reason: d.name);
      });
    }

    test('daily shape varies with the date seed', () {
      final shapes = {
        for (var day = 1; day <= 20; day++)
          DifficultyCurve.silhouetteForSeed(
            20261000 + day,
            DifficultyCurve.forDifficulty(Difficulty.normal).gridSize,
          ),
      };
      expect(shapes.length, greaterThan(1));
    });
  });

  group('Determinism', () {
    test('same inputs give the same board', () {
      final a = LevelGenerator.generate(levelNumber: 10, seed: 9999)!;
      final b = LevelGenerator.generate(levelNumber: 10, seed: 9999)!;
      expect(_boardKey(a), equals(_boardKey(b)));
    });

    test('a level does not depend on what was generated before it', () {
      final cold = _campaign(37);
      for (var n = 30; n <= 36; n++) {
        _campaign(n);
      }
      _campaign(80);
      final warm = _campaign(37);
      expect(_boardKey(warm), equals(_boardKey(cold)));
    });

    test('a background isolate produces the identical board', () async {
      final local = _campaign(64);
      final remote = await Isolate.run(() => _boardKey(_campaign(64)));
      expect(remote, equals(_boardKey(local)));
    });
  });

  group('Fallback', () {
    test('guaranteed board is valid and solvable for every board size', () {
      for (var size = 6; size <= AppConstants.maxGridSize; size++) {
        final spec = DifficultyCurve.forLevel(1);
        final level = LevelGenerator.guaranteedLevel(
          levelNumber: 1,
          seed: 1,
          spec: PuzzleSpec(
            gridSize: size,
            fill: spec.fill,
            avgArrowLen: spec.avgArrowLen,
            maxTierLen: spec.maxTierLen,
            maxAbsorbLen: spec.maxAbsorbLen,
            minAvgBends: spec.minAvgBends,
            minDepth: spec.minDepth,
            minOccupancy: spec.minOccupancy,
            difficulty: spec.difficulty,
          ),
        );
        expect(level.gridSize, size);
        _expectValidBoard(level, reason: 'guaranteed $size');
        // Every cell is used.
        expect(
          level.arrows.fold<int>(0, (s, a) => s + a.length),
          size * size,
        );
      }
    });
  });

  test(
    'Full campaign: every level is valid, sized by the curve, solvable, and '
    'difficulty rises world by world',
    () {
      final perWorld = <int, List<List<double>>>{};
      String? prevPattern;
      double? prevScore;
      var fallbackBoards = 0;

      for (var n = 1; n <= AppConstants.totalLevels; n++) {
        final level = _campaign(n);

        final reason = 'Level $n';

        expect(level.levelNumber, n, reason: reason);
        // Board size follows the picture so each level offers its target area.
        expect(level.gridSize, LevelGenerator.gridForLevel(n), reason: reason);
        expect(level.gridSize, inInclusiveRange(16, AppConstants.maxGridSize),
            reason: reason);
        expect(level.difficulty, DifficultyCurve.worldFor(n).difficulty,
            reason: reason);
        _expectValidBoard(level, reason: reason);

        // Consecutive levels never share a shape.
        final pattern = LevelGenerator.silhouetteForLevel(n).id;
        expect(pattern, isNot(prevPattern), reason: '$reason repeats shape');
        prevPattern = pattern;

        final turns = level.arrows.fold<int>(0, (s, a) => s + a.turns);
        if (turns == 0) fallbackBoards++;

        final m = DependencyAnalyzer.analyze(level.arrows, level.gridSize);
        final plan = LevelSolver.planningStats(level.arrows, level.gridSize)!;
        final blocked = 1 - plan.initiallyFree / level.arrows.length;
        final score = PuzzleSpec.complexityScore(
          arrows: level.arrows.length,
          avgLength: m.averagePathLength,
          avgBends: turns / level.arrows.length,
          rounds: plan.rounds,
          blockedShare: blocked,
        );

        // Every board needs several planning waves and has traps up front.
        expect(plan.rounds, greaterThanOrEqualTo(3), reason: reason);
        expect(blocked, greaterThanOrEqualTo(0.3), reason: reason);

        // No sudden spikes or drops between neighbouring levels.
        if (prevScore != null) {
          // At most a quarter of the score: no sudden spike or drop.
          expect((score - prevScore).abs(), lessThanOrEqualTo(prevScore * 0.25),
              reason: '$reason complexity jump');
        }
        prevScore = score;

        perWorld.putIfAbsent(DifficultyCurve.worldFor(n).number, () => []).add([
          level.gridSize.toDouble(),
          level.arrows.length.toDouble(),
          m.averagePathLength,
          turns / level.arrows.length,
          m.dependencyDepth.toDouble(),
          plan.rounds.toDouble(),
          blocked,
          score,
          level.shapeCells.length.toDouble(),
        ]);
      }

      // The emergency board should never be needed for shipped levels.
      expect(fallbackBoards, 0, reason: 'levels fell back to straight rows');

      List<double> mean(int world) {
        final rows = perWorld[world]!;
        return [
          for (var i = 0; i < rows.first.length; i++)
            rows.fold<double>(0, (s, r) => s + r[i]) / rows.length,
        ];
      }

      final worlds = perWorld.keys.toList()..sort();
      final means = [for (final w in worlds) mean(w)];
      // ignore: avoid_print
      print([
        for (var i = 0; i < means.length; i++)
          'W${worlds[i]}: grid ${means[i][0].toStringAsFixed(1)} '
              'arrows ${means[i][1].toStringAsFixed(1)} '
              'len ${means[i][2].toStringAsFixed(1)} '
              'bends ${means[i][3].toStringAsFixed(2)} '
              'depth ${means[i][4].toStringAsFixed(1)} '
              'rounds ${means[i][5].toStringAsFixed(2)} '
              'blocked ${means[i][6].toStringAsFixed(3)} '
              'score ${means[i][7].toStringAsFixed(1)} '
              'area ${means[i][8].toStringAsFixed(0)}',
      ].join('\n'));

      // Playable area, arrow length, turns and the overall complexity rise
      // every single world: difficulty is not only "more arrows".
      for (var i = 1; i < means.length; i++) {
        for (final (index, name) in [
          (8, 'playable area'),
          (2, 'avg length'),
          (3, 'bends'),
          (7, 'complexity score'),
        ]) {
          expect(
            means[i][index],
            greaterThan(means[i - 1][index]),
            reason: '$name should rise from world ${worlds[i - 1]} '
                'to ${worlds[i]}',
          );
        }
      }
      // Dependency depth (planning) is higher in the second half.
      final half = means.length ~/ 2;
      double avgDepth(Iterable<List<double>> ms) =>
          ms.fold<double>(0, (s, m) => s + m[4]) / ms.length;
      expect(avgDepth(means.skip(half)), greaterThan(avgDepth(means.take(half))));
      expect(means.last[4], greaterThan(means.first[4]));
      // Board size, arrow count, planning rounds and up-front traps rise
      // across the campaign. They are whole numbers that also depend on each
      // picture, so neighbouring worlds may tie or dip slightly.
      double avgOf(Iterable<List<double>> ms, int i) =>
          ms.fold<double>(0, (s, m) => s + m[i]) / ms.length;
      for (final i in [0, 1, 5, 6]) {
        expect(avgOf(means.skip(half), i), greaterThan(avgOf(means.take(half), i)));
        expect(means.last[i], greaterThan(means.first[i]));
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test('Early levels are large picture puzzles, yet fair', () {
    // Earlier curves started at 6×6 (4–6 arrows), then 10×10 (9–13 arrows),
    // then 16×16 pictures (~17 arrows averaging ~5 cells). Level 1 now opens
    // with ~30 long arrows on a ~23-cell picture board.
    for (var n = 1; n <= 5; n++) {
      final level = _campaign(n);
      final reason = 'Level $n';
      final m = DependencyAnalyzer.analyze(level.arrows, level.gridSize);
      final plan = LevelSolver.planningStats(level.arrows, level.gridSize)!;
      final turns = level.arrows.fold<int>(0, (s, a) => s + a.turns);
      final blocked = 1 - plan.initiallyFree / level.arrows.length;

      expect(level.gridSize, greaterThanOrEqualTo(18), reason: reason);
      // Many long arrows from the very first level.
      expect(level.arrows.length, greaterThanOrEqualTo(22), reason: reason);
      expect(m.averagePathLength, greaterThanOrEqualTo(5.5), reason: reason);
      expect(turns / level.arrows.length, greaterThanOrEqualTo(1),
          reason: '$reason has 90° turns');
      expect(plan.rounds, greaterThanOrEqualTo(3), reason: reason);
      expect(blocked, greaterThanOrEqualTo(0.35), reason: reason);

      // Fair for a newcomer: a few arrows are free on the first tap and no
      // single arrow fills the board.
      expect(plan.initiallyFree, greaterThanOrEqualTo(2), reason: reason);
      expect(plan.rounds, lessThanOrEqualTo(7), reason: reason);
      final longest = level.arrows
          .map((ArrowModel a) => a.length)
          .reduce((a, b) => a > b ? a : b);
      expect(longest, inInclusiveRange(10, 24), reason: reason);
    }
  });

  test('Advanced levels are dense with long, winding arrows', () {
    for (final n in [175, 190, 200]) {
      final level = _campaign(n);
      final reason = 'Level $n';
      final m = DependencyAnalyzer.analyze(level.arrows, level.gridSize);
      final plan = LevelSolver.planningStats(level.arrows, level.gridSize)!;
      final longest = level.arrows
          .map((ArrowModel a) => a.length)
          .reduce((a, b) => a > b ? a : b);
      final turns = level.arrows.fold<int>(0, (s, a) => s + a.turns);

      expect(level.arrows.length, greaterThanOrEqualTo(35), reason: reason);
      expect(m.averagePathLength, greaterThanOrEqualTo(9), reason: reason);
      expect(longest, greaterThanOrEqualTo(18), reason: reason);
      expect(turns / level.arrows.length, greaterThanOrEqualTo(4),
          reason: '$reason winding');
      expect(plan.rounds, greaterThanOrEqualTo(7), reason: reason);
      // The arrows draw the picture rather than leaving it half empty.
      final filled = level.arrows.fold<int>(0, (s, a) => s + a.length);
      expect(filled / level.shapeCells.length, greaterThanOrEqualTo(0.85),
          reason: reason);
      // Replaying the solver's order under the game rule clears the board.
      final order = LevelSolver.solve(level.arrows, level.gridSize).solution;
      final remaining = [...level.arrows];
      for (final id in order) {
        final a = remaining.firstWhere((x) => x.id == id);
        expect(LevelSolver.canEscape(a, remaining, level.gridSize), isTrue,
            reason: '$reason $id');
        remaining.remove(a);
      }
      expect(remaining, isEmpty, reason: reason);
    }
  });

  test('Restart regenerates the identical board', () {
    for (final n in [1, 57, 163]) {
      expect(_boardKey(_campaign(n)), equals(_boardKey(_campaign(n))),
          reason: 'Level $n');
    }
  });
}
