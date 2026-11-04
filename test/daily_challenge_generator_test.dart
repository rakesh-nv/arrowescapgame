import 'dart:math';

import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/models/daily_challenge.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/data/repositories/theme_repository.dart';
import 'package:arrowescapegame/game/config/difficulty_curve.dart';
import 'package:arrowescapegame/game/config/puzzle_config.dart';
import 'package:arrowescapegame/game/engine/game_engine.dart';
import 'package:arrowescapegame/game/generator/daily_challenge_generator.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:arrowescapegame/game/generator/level_validator.dart';
import 'package:arrowescapegame/game/renderer/arrow_board_widget.dart';
import 'package:arrowescapegame/game/renderer/arrow_widget.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dates spread over months, years and a leap day.
const _dates = ['2026-11-02', '2026-12-25', '2027-01-01', '2028-02-29'];

String _boardKey(LevelModel l) =>
    '${l.gridSize}|${l.shapeName}|'
    '${l.arrows.map((a) => '${a.id}:${a.points}').join(';')}';

/// Plays the solver's order through the real engine; returns lives lost.
int _livesLostPlaying(LevelModel level) {
  final engine = GameEngine()..loadLevel(level);
  final startLives = engine.lives;
  final order = LevelSolver.solve(level.arrows, level.gridSize).solution;
  for (final id in order) {
    engine.tapArrow(id);
    engine.markArrowRemoved(id);
  }
  expect(engine.isComplete(), isTrue);
  return startLives - engine.lives;
}

void main() {
  final results = <String, DailyResult>{};

  setUpAll(() {
    debugPrint = (String? m, {int? wrapWidth}) {};
    for (final date in _dates) {
      final sw = Stopwatch()..start();
      results[date] = DailyChallengeGenerator.generateWithReport(
        DailyChallenge.seedFromDate(date),
      );
      // ignore: avoid_print
      print(
        'daily $date: ${results[date]!.level.shapeName}, '
        '${results[date]!.difficulty}, attempts ${results[date]!.attempts}, '
        '${sw.elapsedMilliseconds} ms',
      );
    }
  });

  group('Every date gives a huge, valid, expert board', () {
    for (final date in _dates) {
      test(date, () {
        final r = results[date]!;
        final level = r.level;

        // Correct by the game's own rules.
        expect(LevelValidator.problems(level), isEmpty);
        expect(
          LevelSolver.solve(level.arrows, level.gridSize).solvable,
          isTrue,
        );
        for (final a in level.arrows) {
          expect(a.hasValidPath, isTrue, reason: a.id);
          expect(a.points.toSet().length, a.points.length, reason: a.id);
          expect(
            LevelSolver.firstCollision(a, [a], level.gridSize),
            isNot(a.id),
            reason: '${a.id} would hit its own body',
          );
        }
        final owner = <(int, int), String>{};
        for (final a in level.arrows) {
          for (final c in a.occupiedCells) {
            expect(owner[c], isNull, reason: '${a.id} overlaps ${owner[c]}');
            owner[c] = a.id;
          }
        }
        // Perfect play never costs a life (no hidden self-crash or block).
        expect(_livesLostPlaying(level), 0);

        // Hard enough, on every date, without the fallback.
        expect(r.fallback, isFalse);
        expect(DailyChallengeGenerator.minimum.failures(r.difficulty), isEmpty);
        expect(level.difficulty, Difficulty.extreme);
        expect(level.arrows.length, greaterThanOrEqualTo(220));
        expect(level.gridSize, greaterThanOrEqualTo(90));
        expect(r.difficulty.minimumMoves, level.arrows.length);
      });
    }
  });

  test('the same date always gives the same board', () {
    const date = '2026-12-25';
    final again = DailyChallengeGenerator.generate(
      DailyChallenge.seedFromDate(date),
    );
    expect(_boardKey(again), _boardKey(results[date]!.level));
  });

  test('different dates give different boards', () {
    final keys = {for (final r in results.values) _boardKey(r.level)};
    expect(keys.length, _dates.length);
  });

  test('dates map to distinct seeds', () {
    final seeds = <int>{};
    var day = DateTime(2026, 1, 1, 12);
    for (var i = 0; i < 3 * 366; i++) {
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      expect(seeds.add(DailyChallenge.seedFromDate(key)), isTrue, reason: key);
      day = day.add(const Duration(days: 1));
    }
  });

  group('Easy boards are rejected', () {
    test('the old mid-campaign daily board fails the floor', () {
      for (final date in _dates.take(2)) {
        final old = LevelGenerator.generate(
          levelNumber: 0,
          seed: DailyChallenge.seedFromDate(date),
          difficulty: Difficulty.normal,
        )!;
        final m = PuzzleDifficulty.measure(old)!;
        expect(DailyChallengeGenerator.minimum.failures(m), isNotEmpty);
        expect(m.score, lessThan(results[date]!.difficulty.score));
      }
    });

    test('a straight-row board fails the floor', () {
      final rows = LevelGenerator.guaranteedLevel(
        levelNumber: 0,
        seed: 1,
        spec: DifficultyCurve.forDaily().withGridSize(100),
      );
      final m = PuzzleDifficulty.measure(rows)!;
      expect(
        DailyChallengeGenerator.minimum.failures(m),
        contains(startsWith('blocked at start')),
      );
    });
  });

  test('difficulty metrics follow the escape rule', () {
    // c → b → a in one row, all pointing right: a leaves first, then b, then
    // c. d points up from below c and is free at once.
    ArrowModel right(String id, int col) =>
        ArrowModel(id: id, points: [(0, col), (0, col + 1), (0, col + 2)]);
    final level = LevelModel(
      levelNumber: 0,
      seed: 0,
      gridSize: 12,
      difficulty: Difficulty.extreme,
      arrowCount: 4,
      maxMistakes: 4,
      arrows: [
        right('a', 9),
        right('b', 6),
        right('c', 3),
        ArrowModel(id: 'd', points: [(5, 0), (4, 0), (3, 0)]),
      ],
    );
    final m = PuzzleDifficulty.measure(level)!;
    expect(m.arrows, 4);
    expect(m.minimumMoves, 4);
    expect(m.blockingRelations, 3); // b←a, c←b, c←a
    expect(m.dependencyDepth, 3);
    expect(m.initiallyFree, 2);
    expect(m.blockedShare, closeTo(0.5, 1e-9));
  });

  test('available-arrow queries stay fast on a daily board', () {
    final level = results['2026-12-25']!.level;
    final engine = GameEngine()..loadLevel(level);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      engine.getHintArrowId();
    }
    final perHint = sw.elapsedMilliseconds / 10;
    // ignore: avoid_print
    print('hint on ${level.arrows.length} arrows: $perHint ms');
    expect(perHint, lessThan(50));
    expect(
      {for (final a in engine.getAvailableArrows()) a.id},
      {
        for (final a in level.arrows)
          if (LevelSolver.canEscape(a, level.arrows, level.gridSize)) a.id,
      },
    );
  });

  testWidgets('a daily board zooms, pans and takes taps anywhere', (
    tester,
  ) async {
    final level = results['2026-12-25']!.level;
    const box = Size(360, 480);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: box,
              child: ArrowBoardWidget(
                arrows: level.arrows,
                gridSize: level.gridSize,
                shapeCells: level.shapeCells,
                theme: ThemeRepository.allThemes.first,
                onArrowTap: (id) => tapped = id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // Hundreds of idle arrows share one painted layer.
    expect(find.byType(ArrowWidget), findsNothing);

    final tc = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final cell = PuzzleConfig.adaptive(
      screenWidth: box.width,
      screenHeight: box.height,
      overrideGridSize: level.gridSize,
    ).cellSpacing;

    // Pinch out zooms in.
    final fitted = tc.value.getMaxScaleOnAxis();
    final centre = box.center(Offset.zero);
    final f1 = await tester.startGesture(centre - const Offset(30, 0));
    final f2 = await tester.startGesture(centre + const Offset(30, 0));
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await f1.moveTo(centre - Offset(30.0 + 10 * i, 0));
      await f2.moveTo(centre + Offset(30.0 + 10 * i, 0));
      await tester.pump();
    }
    await f1.up();
    await f2.up();
    await tester.pumpAndSettle();
    final zoomed = tc.value.getMaxScaleOnAxis();
    expect(zoomed, greaterThan(fitted * 1.5));

    // One finger pans.
    final before = tc.value.getTranslation();
    await tester.dragFrom(centre, const Offset(-80, -60));
    await tester.pumpAndSettle();
    expect(tc.value.getTranslation(), isNot(before));

    // Zoomed in on any part of the board, a tap hits the arrow under it:
    // the arrows at the top, bottom, left and right edges of the picture.
    ArrowModel extreme(int Function((int, int)) key, bool most) =>
        level.arrows.reduce((a, b) {
          final ka = a.points.map(key).reduce(most ? max : min);
          final kb = b.points.map(key).reduce(most ? max : min);
          return (most ? ka >= kb : ka <= kb) ? a : b;
        });
    final targets = [
      extreme((p) => p.$1, false),
      extreme((p) => p.$1, true),
      extreme((p) => p.$2, false),
      extreme((p) => p.$2, true),
    ];
    for (final target in targets) {
      final rc = target.points[target.points.length ~/ 2];
      // Comfortable 30 dp cells, with the target's cell at the box centre.
      final scale = 30 / cell;
      final scene = Offset((rc.$2 + 0.5) * cell, (rc.$1 + 0.5) * cell);
      final t = centre - scene * scale;
      tc.value = Matrix4.identity()
        ..translateByDouble(t.dx, t.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      await tester.pump();
      tapped = null;
      await tester.tapAt(centre);
      await tester.pumpAndSettle();
      expect(tapped, target.id);
    }
  });
}
