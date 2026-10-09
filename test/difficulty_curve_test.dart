import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/game/config/difficulty_curve.dart';
import 'package:arrowescapegame/game/generator/silhouette_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final specs = [
    for (var n = 1; n <= AppConstants.totalLevels; n++)
      DifficultyCurve.forLevel(n),
  ];

  test('starts on a large board and grows to the largest boards', () {
    expect(specs.first.gridSize, 26);
    expect(specs.first.targetCells, greaterThanOrEqualTo(350));
    expect(specs.last.targetCells, greaterThan(specs.first.targetCells * 3));
    expect(specs.last.targetCells, greaterThanOrEqualTo(1200));
    // Nominal size; each picture's own board is capped at maxGridSize.
    expect(specs.last.gridSize, greaterThan(specs.first.gridSize));
    expect(specs.last.gridSize, lessThanOrEqualTo(AppConstants.maxGridSize));
  });

  test('level 1 already asks for real planning', () {
    final first = specs.first;
    expect(first.arrowFloor, greaterThanOrEqualTo(8));
    expect(first.avgArrowLen, greaterThanOrEqualTo(4.5));
    expect(first.minAvgBends, greaterThan(0.5));
    expect(first.minDepth, greaterThanOrEqualTo(3));
    expect(first.targetRounds, greaterThanOrEqualTo(4));
    expect(first.targetBlockedShare, greaterThanOrEqualTo(0.5));
  });

  test('every parameter rises gradually and never drops', () {
    for (var i = 1; i < specs.length; i++) {
      final a = specs[i - 1];
      final b = specs[i];
      final at = 'level ${i + 1}';
      expect(b.gridSize - a.gridSize, inInclusiveRange(0, 1), reason: at);
      expect(b.fill, greaterThanOrEqualTo(a.fill), reason: at);
      expect(b.avgArrowLen, greaterThanOrEqualTo(a.avgArrowLen), reason: at);
      expect(b.maxTierLen, greaterThanOrEqualTo(a.maxTierLen), reason: at);
      expect(b.maxAbsorbLen, greaterThanOrEqualTo(a.maxAbsorbLen), reason: at);
      expect(b.minAvgBends, greaterThanOrEqualTo(a.minAvgBends), reason: at);
      expect(b.minDepth, greaterThanOrEqualTo(a.minDepth), reason: at);
      expect(b.difficulty.index, greaterThanOrEqualTo(a.difficulty.index),
          reason: at);
      expect(b.targetRounds, greaterThanOrEqualTo(a.targetRounds), reason: at);
      expect(b.targetBlockedShare, greaterThanOrEqualTo(a.targetBlockedShare),
          reason: at);
      expect(b.arrowFloor, greaterThanOrEqualTo(a.arrowFloor), reason: at);
    }
    // Planning targets genuinely grow, not just the arrow floor.
    expect(specs.last.targetRounds, greaterThan(specs.first.targetRounds + 3));
    expect(specs.last.targetBlockedShare,
        greaterThan(specs.first.targetBlockedShare + 0.1));
  });

  test('complexity score weighs planning, not only arrow count', () {
    // Same arrow count; more rounds and traps must score higher.
    final shallow = PuzzleSpec.complexityScore(
        arrows: 12, avgLength: 5, avgBends: 2, rounds: 2, blockedShare: 0.2);
    final deep = PuzzleSpec.complexityScore(
        arrows: 12, avgLength: 5, avgBends: 2, rounds: 6, blockedShare: 0.7);
    expect(deep, greaterThan(shallow + 8));
    // Doubling arrows on a trivial board does not beat a deep, smaller one.
    final crowded = PuzzleSpec.complexityScore(
        arrows: 24, avgLength: 5, avgBends: 2, rounds: 2, blockedShare: 0.2);
    expect(deep, greaterThan(crowded));
  });

  test('the board never sits at one size for more than 30 levels', () {
    var run = 1;
    for (var i = 1; i < specs.length; i++) {
      run = specs[i].gridSize == specs[i - 1].gridSize ? run + 1 : 1;
      if (specs[i].gridSize < AppConstants.maxGridSize) {
        expect(run, lessThanOrEqualTo(30), reason: 'level ${i + 1}');
      }
    }
  });

  test('levels past the campaign keep the final parameters', () {
    final last = DifficultyCurve.forLevel(AppConstants.totalLevels);
    final beyond = DifficultyCurve.forLevel(AppConstants.totalLevels + 50);
    expect(beyond.gridSize, last.gridSize);
    expect(beyond.avgArrowLen, last.avgArrowLen);
    expect(beyond.difficulty, last.difficulty);
  });

  test('worlds tile the campaign with rising difficulty labels', () {
    final worlds = DifficultyCurve.worlds;
    expect(worlds.length,
        AppConstants.totalLevels ~/ AppConstants.levelsPerWorld);
    expect(worlds.first.firstLevel, 1);
    expect(worlds.last.lastLevel, AppConstants.totalLevels);
    for (var i = 1; i < worlds.length; i++) {
      expect(worlds[i].firstLevel, worlds[i - 1].lastLevel + 1);
      expect(worlds[i].difficulty.index,
          greaterThanOrEqualTo(worlds[i - 1].difficulty.index));
    }
    expect(worlds.first.difficulty, Difficulty.easy);
    expect(worlds.last.difficulty, Difficulty.extreme);
    expect(DifficultyCurve.worldFor(26).number, 2);
    expect(DifficultyCurve.worldFor(0).number, 1);
    expect(DifficultyCurve.worldFor(999).number, worlds.length);
  });

  test('explicit difficulties map to increasing representative specs', () {
    var prev = 0;
    for (final d in Difficulty.values) {
      final spec = DifficultyCurve.forDifficulty(d);
      expect(spec.difficulty, d);
      expect(spec.gridSize, greaterThanOrEqualTo(prev));
      prev = spec.gridSize;
    }
  });

  test('detailed silhouettes join as boards grow; every one is used', () {
    final first = DifficultyCurve.silhouettePoolFor(specs.first.gridSize);
    final last = DifficultyCurve.silhouettePoolFor(specs.last.gridSize);
    expect(first.length, greaterThanOrEqualTo(20));
    expect(last.length, SilhouetteLibrary.all.length);
    expect(last.length, greaterThan(first.length));
    // Bicycle needs a big board to read; it is not offered on level 1.
    expect(first.map((s) => s.id), isNot(contains('bicycle')));

    final used = <String>{};
    for (var n = 1; n <= AppConstants.totalLevels; n++) {
      final s = DifficultyCurve.silhouetteForLevel(n);
      expect(s.minGrid, lessThanOrEqualTo(specs[n - 1].gridSize),
          reason: 'level $n');
      used.add(s.id);
    }
    expect(used, SilhouetteLibrary.all.map((s) => s.id).toSet());
  });

  test('a silhouette never returns within the repeat gap', () {
    for (var n = 2; n <= 400; n++) {
      final s = DifficultyCurve.silhouetteForLevel(n).id;
      for (var back = 1;
          back <= DifficultyCurve.repeatGap && n - back >= 1;
          back++) {
        expect(DifficultyCurve.silhouetteForLevel(n - back).id, isNot(s),
            reason: 'level $n repeats level ${n - back}');
      }
    }
  });

  test('the first levels show varied, popular pictures', () {
    final opening = [
      for (var n = 1; n <= 8; n++) DifficultyCurve.silhouetteForLevel(n),
    ];
    expect(opening.map((s) => s.id).toSet().length, 8);
    expect(opening.map((s) => s.category).toSet().length,
        greaterThanOrEqualTo(3));
  });

  test('minimum arrow count scales with board capacity', () {
    final spec = DifficultyCurve.forLevel(100);
    expect(spec.minArrowsFor(10), greaterThanOrEqualTo(4));
    expect(spec.minArrowsFor(300), greaterThan(spec.minArrowsFor(100)));
  });
}
