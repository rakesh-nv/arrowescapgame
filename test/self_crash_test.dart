import 'dart:io';

import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/core/constants/app_strings.dart';
import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/models/arrow_state.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/data/models/player_progress.dart';
import 'package:arrowescapegame/data/repositories/progress_repository.dart';
import 'package:arrowescapegame/game/engine/game_engine.dart';
import 'package:arrowescapegame/game/generator/arrow_repair.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:arrowescapegame/game/generator/level_validator.dart';
import 'package:arrowescapegame/game/models/tap_result.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:arrowescapegame/modules/ads/services/ad_service.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_controller.dart';
import 'package:arrowescapegame/modules/gameplay/gameplay_screen.dart';
import 'package:arrowescapegame/services/analytics_service.dart';
import 'package:arrowescapegame/services/audio_service.dart';
import 'package:arrowescapegame/services/economy_service.dart';
import 'package:arrowescapegame/services/haptic_service.dart';
import 'package:arrowescapegame/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeStorage extends StorageService {
  PlayerProgress _progress = PlayerProgress(coins: 100, hints: 3);

  @override
  PlayerProgress get progress => _progress;

  @override
  Future<void> saveProgress(PlayerProgress p) async => _progress = p;
}

ArrowModel _arrow(List<(int, int)> points, [String id = 'a']) =>
    ArrowModel(id: id, points: points);

/// Head at (2,1) pointing up; its lane hits a straight part of the body.
final _straightHit = _arrow([
  (1, 0), (1, 1), (1, 2), (2, 2), (3, 2), (3, 1), (2, 1), //
]);

/// Same head; the lane cell (1,1) is a corner of the body.
final _cornerHit = _arrow([
  (0, 0), (0, 1), (1, 1), (1, 2), (2, 2), (3, 2), (3, 1), (2, 1), //
]);

/// Same head; the lane reaches the body two cells away, after several turns.
final _afterTurnsHit = _arrow([
  (1, 0), (0, 0), (0, 1), (0, 2), (1, 2), (2, 2), (3, 2), (3, 1), (2, 1), //
]);

/// Same head; the lane reaches only the very tip of the tail.
final _tailTipHit = _arrow([
  (0, 1), (0, 2), (1, 2), (2, 2), (3, 2), (3, 1), (2, 1), //
]);

LevelModel _level(List<ArrowModel> arrows) => LevelModel(
  levelNumber: 0,
  seed: 1,
  gridSize: 6,
  difficulty: Difficulty.easy,
  arrowCount: arrows.length,
  maxMistakes: 4,
  arrows: arrows,
);

void main() {
  group('LevelSolver.firstCollision', () {
    bool touches(ArrowModel a) => LevelSolver.firstCollision(a, [a], 6) == a.id;

    test('hits on a straight section, a corner and after turns', () {
      expect(touches(_straightHit), isTrue);
      expect(touches(_cornerHit), isTrue);
      expect(touches(_afterTurnsHit), isTrue);
    });

    test('any own cell in the lane counts, even the tail tip far away', () {
      // The earlier check skipped this one: the tail would have moved off
      // (0,1) before the head arrived. Other arrows are never judged that way.
      expect(touches(_tailTipHit), isTrue);
    });

    test('every exit direction is detected', () {
      // _straightHit exits up; mirror it to exit down, left and right.
      final down = [for (final p in _straightHit.points) (5 - p.$1, p.$2)];
      final left = [for (final p in _straightHit.points) (p.$2, p.$1)];
      final right = [for (final p in _straightHit.points) (p.$2, 5 - p.$1)];
      for (final points in [down, left, right]) {
        expect(touches(_arrow(points)), isTrue, reason: '$points');
      }
    });


    test('straight and turning arrows with a free lane do not touch', () {
      expect(touches(_arrow([(2, 0), (2, 1), (2, 2)])), isFalse);
      expect(touches(_arrow([(0, 0), (1, 0), (1, 1), (1, 2)])), isFalse);
    });

    test('head right beside its body, lane clear, does not touch', () {
      expect(
        touches(_arrow([(2, 0), (1, 0), (0, 0), (0, 1), (1, 1)])),
        isFalse,
      );
    });
  });

  group('GameEngine', () {
    for (final (name, arrow) in [
      ('straight', _straightHit),
      ('corner', _cornerHit),
      ('after turns', _afterTurnsHit),
      ('tail tip', _tailTipHit),
    ]) {
      test('$name: one life per crash, and the arrow never moves', () {
        final engine = GameEngine()..loadLevel(_level([arrow]));

        for (var i = 1; i <= 2; i++) {
          expect(engine.tapArrow('a'), TapResult.selfCrash);
          expect(engine.lives, AppConstants.startingLives - i);
          expect(engine.mistakes, i);
          expect(engine.moves, 0);
          expect(
            engine.allArrows.single.state,
            ArrowState.blocked,
            reason: 'the move is rejected before anything moves',
          );
          engine.resetBlockedArrow('a');
        }
      });
    }

    test('own body first, another arrow further on: a tail crash', () {
      final shifted = [for (final p in _straightHit.points) (p.$1 + 2, p.$2)];
      final engine = GameEngine()
        ..loadLevel(
          _level([
            _arrow(shifted),
            _arrow([(1, 1), (1, 0)], 'b'),
          ]),
        );
      expect(engine.tapArrow('a'), TapResult.selfCrash);
      expect(engine.lives, AppConstants.startingLives - 1);
    });

    test('another arrow first, own body further on: a normal crash', () {
      final engine = GameEngine()
        ..loadLevel(
          _level([
            _tailTipHit,
            _arrow([(1, 0), (1, 1)], 'b'),
          ]),
        );
      expect(engine.tapArrow('a'), TapResult.blocked);
      expect(engine.lives, AppConstants.startingLives - 1);
    });

    test('both collision types take the same crash path', () {
      final foreign = GameEngine()
        ..loadLevel(
          _level([
            _arrow([(3, 0), (2, 0)]),
            _arrow([(0, 0), (0, 1)], 'b'),
          ]),
        );
      final own = GameEngine()..loadLevel(_level([_straightHit]));

      expect(foreign.tapArrow('a'), TapResult.blocked);
      expect(own.tapArrow('a'), TapResult.selfCrash);
      for (final e in [foreign, own]) {
        expect(e.lives, AppConstants.startingLives - 1);
        expect(e.mistakes, 1);
        expect(e.moves, 0);
        expect(e.canUndo, isFalse);
        expect(
          e.allArrows.firstWhere((x) => x.id == 'a').state,
          ArrowState.blocked,
        );
      }
    });

    test('other collisions and normal moves behave as before', () {
      final engine = GameEngine()
        ..loadLevel(
          _level([
            _arrow([(0, 0), (1, 0), (1, 1), (1, 2)]),
            _arrow([(0, 4), (1, 4), (2, 4)], 'b'),
          ]),
        );
      expect(engine.tapArrow('a'), TapResult.blocked);
      engine.resetBlockedArrow('a');
      expect(engine.tapArrow('a'), TapResult.blocked);
      expect(engine.lives, AppConstants.startingLives - 2);
      engine.resetBlockedArrow('a');
      expect(engine.tapArrow('b'), TapResult.valid);
      expect(engine.lives, AppConstants.startingLives - 2);
    });

    test('undo past a crash charges it again, as it refunds the life', () {
      final engine = GameEngine()
        ..loadLevel(
          _level([
            _arrow([(5, 0), (5, 1)], 'b'),
            _straightHit,
          ]),
        );
      expect(engine.tapArrow('b'), TapResult.valid);
      engine.markArrowRemoved('b');
      expect(engine.tapArrow('a'), TapResult.selfCrash);
      engine.resetBlockedArrow('a');
      engine.undo();
      expect(engine.lives, AppConstants.startingLives);
      expect(engine.isSelfCrash('a'), isTrue);
    });

    test('restart charges the crash again', () {
      final engine = GameEngine()..loadLevel(_level([_straightHit]));
      engine.tapArrow('a');
      engine.reset();
      expect(engine.lives, AppConstants.startingLives);
      expect(engine.tapArrow('a'), TapResult.selfCrash);
    });

    test('hints prefer a safe arrow over a crash', () {
      final engine = GameEngine()
        ..loadLevel(
          _level([
            _straightHit,
            _arrow([(5, 0), (5, 1)], 'b'),
          ]),
        );
      expect(engine.getHintArrowId(), 'b');
    });
  });

  group('ArrowRepair', () {
    test('keeps the id and every cell, and clears the lane', () {
      for (final arrow in [
        _straightHit,
        _cornerHit,
        _afterTurnsHit,
        _tailTipHit,
      ]) {
        final result = ArrowRepair.repair([arrow], 6)!;
        final fixed = result.arrows.single;
        expect(result.repaired, 1);
        expect(fixed.id, arrow.id);
        expect(fixed.hasValidPath, isTrue);
        expect(fixed.points.toSet(), arrow.points.toSet());
        expect(ArrowRepair.hitsOwnBody(fixed, 6), isFalse);
      }
    });

    test('leaves healthy arrows untouched', () {
      final arrows = [
        _arrow([(0, 0), (1, 0), (1, 1), (1, 2)]),
      ];
      final result = ArrowRepair.repair(arrows, 6)!;
      expect(result.repaired, 0);
      expect(result.arrows.single.points, arrows.single.points);
    });

    test('never accepts a repair that makes the board unsolvable', () {
      final arrows = [
        _straightHit,
        _arrow([(5, 0), (5, 1)], 'b'),
      ];
      final result = ArrowRepair.repair(arrows, 6)!;
      expect(LevelSolver.solve(result.arrows, 6).solvable, isTrue);
    });

    test('the validator rejects a board with a self-colliding arrow', () {
      expect(
        LevelValidator.problems(_level([_straightHit])),
        contains('a: head runs into its own body'),
      );
    });
  });

  // Early, middle and late levels by default; ALL_LEVELS=1 checks all 1,000.
  test('campaign levels: no own-tail arrows, perfect play costs no life', () {
    final all = Platform.environment['ALL_LEVELS'] == '1';
    final levels = all
        ? [for (var n = 1; n <= AppConstants.totalLevels; n++) n]
        : [1, 2, 3, 25, 100, 200, 201, 500, 750, 1000];
    var arrows = 0;

    for (final n in levels) {
      final level = LevelGenerator.generate(
        levelNumber: n,
        seed: AppConstants.levelSeed(n),
      )!;
      expect(LevelValidator.problems(level), isEmpty, reason: 'level $n');
      expect(level.arrows.any((a) => a.turns > 0), isTrue, reason: 'level $n');
      final engine = GameEngine()..loadLevel(level);
      final order = LevelSolver.solve(level.arrows, level.gridSize).solution;
      expect(order.length, level.arrows.length, reason: 'level $n');
      for (final id in order) {
        expect(engine.tapArrow(id), TapResult.valid, reason: 'level $n $id');
        engine.markArrowRemoved(id);
      }
      expect(engine.isComplete(), isTrue, reason: 'level $n');
      expect(engine.lives, AppConstants.startingLives, reason: 'level $n');
      arrows += level.arrows.length;
    }
    // ignore: avoid_print
    print('CAMPAIGN levels=${levels.length} arrows=$arrows all clean');
  }, timeout: const Timeout(Duration(hours: 1)));

  group('GameplayController and screen', () {
    setUp(() {
      Get.reset();
      final storage = _FakeStorage();
      Get.put<StorageService>(storage);
      Get.put(ProgressRepository(storage));
      Get.put(EconomyService(storage));
      Get.put(HapticService());
      Get.put<IAudioService>(NoOpAudioService());
      Get.put<IAnalyticsService>(DebugAnalyticsService());
      Get.put<IAdService>(NoOpAdService());
    });

    tearDown(Get.reset);

    const crashAnim = Duration(
      milliseconds: AppConstants.blockedAnimDurationMs + 150,
    );
    final escape = Duration(
      milliseconds: AppConstants.arrowFlightDurationForLength(45) + 60,
    );

    test('one crash, one life, one message; the arrow stays', () async {
      final gc = Get.put(GameplayController());
      gc.loadLevelModel(
        _level([
          _straightHit,
          _arrow([(5, 0), (5, 1)], 'b'),
        ]),
      );

      gc.onArrowTap('a');
      expect(gc.selfCrashes.value, 1);
      expect(gc.lives.value, AppConstants.startingLives - 1);
      expect(gc.mistakes.value, 1);
      await Future.delayed(crashAnim);
      expect(gc.clearedArrows, 0);
      expect(gc.animatingArrowId.value, isEmpty);
      expect(gc.arrows.first.state, ArrowState.normal);

      gc.onArrowTap('b'); // ordinary movement is not a crash
      await Future.delayed(escape);
      expect(gc.selfCrashes.value, 1);
      expect(gc.lives.value, AppConstants.startingLives - 1);
      expect(gc.moves.value, 1);
    });

    test('a crash on the last life is game over', () async {
      final gc = Get.put(GameplayController());
      final arrows = [
        for (var i = 0; i < AppConstants.startingLives; i++)
          ArrowModel(
            id: 'a$i',
            points: [
              for (final p in _straightHit.points) (p.$1, p.$2 + i * 3),
            ],
          ),
      ];
      gc.loadLevelModel(
        LevelModel(
          levelNumber: 0,
          seed: 1,
          gridSize: 20,
          difficulty: Difficulty.easy,
          arrowCount: arrows.length,
          maxMistakes: 4,
          arrows: arrows,
        ),
      );
      for (final a in arrows) {
        gc.onArrowTap(a.id);
        await Future.delayed(crashAnim);
      }
      expect(gc.selfCrashes.value, AppConstants.startingLives);
      expect(gc.lives.value, 0);
      expect(gc.isGameOver.value, isTrue);
      expect(gc.clearedArrows, 0);
    });

    test('no message when another arrow blocks the tap', () {
      final gc = Get.put(GameplayController());
      gc.loadLevelModel(
        _level([
          _arrow([(0, 0), (1, 0), (1, 1), (1, 2)]),
          _arrow([(0, 4), (1, 4), (2, 4)], 'b'),
        ]),
      );
      gc.onArrowTap('a');
      expect(gc.lives.value, AppConstants.startingLives - 1);
      expect(gc.selfCrashes.value, 0);
    });

    testWidgets('screen shows one SnackBar and no dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final gc = Get.put(GameplayController());
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/g',
          getPages: [GetPage(name: '/g', page: () => const GameplayScreen())],
        ),
      );
      await tester.pump();
      gc.loadLevelModel(
        _level([
          _cornerHit,
          _arrow([(5, 0), (5, 1)], 'b'),
        ]),
        dailyDateKey: '2026-01-01',
      );
      gc.dismissTutorial();
      await tester.pump();

      gc.onArrowTap('a');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(AppStrings.selfCrashMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text(AppStrings.selfCrashMessage), findsNothing);
      expect(gc.selfCrashes.value, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
