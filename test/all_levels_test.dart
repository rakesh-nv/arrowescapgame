import 'dart:io';

import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Campaign-wide validation.
///
/// By default a spread of levels (every 25th plus the boundaries) is checked
/// so the normal suite stays quick. To check every level, run
///
///   ALL_LEVELS=1 flutter test test/all_levels_test.dart
///
/// and split the work with SHARD / SHARDS (e.g. SHARDS=8 SHARD=0..7 in
/// parallel processes).
void main() {
  final env = Platform.environment;
  final all = env['ALL_LEVELS'] == '1';
  final shards = int.tryParse(env['SHARDS'] ?? '') ?? 1;
  final shard = int.tryParse(env['SHARD'] ?? '') ?? 0;

  final levels = <int>[
    for (var n = 1; n <= AppConstants.totalLevels; n++)
      if (all
          ? n % shards == shard
          : n % 25 == 0 ||
                n <= 3 ||
                (n >= AppConstants.classicLevels &&
                    n <= AppConstants.classicLevels + 2) ||
                n == AppConstants.totalLevels)
        n,
  ];

  checkLevels(levels);
}

/// Registers one test that generates and validates every level in [levels].
void checkLevels(List<int> levels) {
  test('campaign levels are valid, solvable, distinct silhouette puzzles '
      '(${levels.length} levels)', () {
    final signatures = <String, int>{};
    var slowest = 0;
    var slowestLevel = 0;
    for (final n in levels) {
      final sw = Stopwatch()..start();
      final level = LevelGenerator.generate(
        levelNumber: n,
        seed: AppConstants.levelSeed(n),
      )!;
      final ms = sw.elapsedMilliseconds;
      if (ms > slowest) {
        slowest = ms;
        slowestLevel = n;
      }
      _expectPlayable(level, n);

      final sig = level.arrows
          .map((a) => a.points.map((p) => '${p.$1},${p.$2}').join(';'))
          .join('/');
      expect(
        signatures.containsKey(sig),
        isFalse,
        reason: 'level $n repeats level ${signatures[sig]}',
      );
      signatures[sig] = n;
    }
    // ignore: avoid_print
    print(
      'checked ${levels.length} levels; slowest L$slowestLevel ${slowest}ms',
    );
  }, timeout: const Timeout(Duration(hours: 2)));
}

void _expectPlayable(LevelModel level, int n) {
  final reason = 'level $n';
  final size = level.gridSize;
  expect(level.levelNumber, n, reason: reason);
  expect(
    size,
    inInclusiveRange(16, AppConstants.finalMaxGridSize),
    reason: reason,
  );
  if (n <= AppConstants.classicLevels) {
    expect(size, lessThanOrEqualTo(AppConstants.maxGridSize), reason: reason);
  }
  expect(
    level.shapeName,
    LevelGenerator.silhouetteForLevel(n).name,
    reason: reason,
  );
  expect(level.arrows, isNotEmpty, reason: reason);
  expect(level.arrowCount, level.arrows.length, reason: reason);

  final seen = <(int, int)>{};
  final ids = <String>{};
  for (final a in level.arrows) {
    expect(ids.add(a.id), isTrue, reason: '$reason duplicate id ${a.id}');
    expect(a.hasValidPath, isTrue, reason: '$reason malformed ${a.id}');
    expect(a.length, greaterThanOrEqualTo(3), reason: '$reason ${a.id}');
    expect(LevelSolver.isWithinGrid(a, size), isTrue, reason: reason);
    for (final cell in a.occupiedCells) {
      expect(seen.add(cell), isTrue, reason: '$reason overlap at $cell');
      expect(
        level.shapeCells.contains(cell),
        isTrue,
        reason: '$reason ${a.id} leaves the picture at $cell',
      );
    }
  }
  // The arrows draw the picture, and this is a real puzzle, not the
  // straight-row fallback.
  expect(
    seen.length / level.shapeCells.length,
    greaterThanOrEqualTo(0.8),
    reason: '$reason fills ${seen.length}/${level.shapeCells.length}',
  );
  expect(
    level.arrows.any((a) => a.turns > 0),
    isTrue,
    reason: '$reason is a fallback board',
  );

  final solved = LevelSolver.solve(level.arrows, size);
  expect(solved.solvable, isTrue, reason: '$reason not solvable');
  expect(solved.solution.length, level.arrows.length, reason: reason);
}
