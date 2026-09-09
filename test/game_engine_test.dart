import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/data/models/arrow_direction.dart';
import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/models/arrow_state.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/game/engine/game_engine.dart';
import 'package:arrowescapegame/game/models/tap_result.dart';

void main() {
  group('GameEngine Tests', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine();
    });

    test('Initializes with level and correctly identifies clear vs blocked arrows', () {
      // Arrow 1: head at (1, 1), length 2, direction RIGHT -> occupies (1,1) and (1,0).
      // Arrow 2: head at (1, 3), length 1, direction RIGHT -> occupies (1,3).
      // Arrow 1's path right passes through (1,2) and (1,3). It is blocked by Arrow 2.
      // Arrow 2's path right to edge (gridSize 4) is clear.
      final arrow1 = ArrowModel(
        id: 'a1',
        headRow: 1,
        headCol: 1,
        length: 2,
        direction: ArrowDirection.right,
      );
      final arrow2 = ArrowModel(
        id: 'a2',
        headRow: 1,
        headCol: 3,
        length: 1,
        direction: ArrowDirection.right,
      );

      final level = LevelModel(
        levelNumber: 1,
        seed: 42,
        gridSize: 4,
        difficulty: Difficulty.easy,
        arrowCount: 2,
        maxMistakes: 3,
        arrows: [arrow1, arrow2],
      );

      engine.loadLevel(level);

      expect(engine.isComplete(), isFalse);
      expect(engine.canEscape('a1'), isFalse);
      expect(engine.canEscape('a2'), isTrue);

      final available = engine.getAvailableArrows();
      expect(available.map((a) => a.id), contains('a2'));
      expect(available.map((a) => a.id), isNot(contains('a1')));
    });

    test('Tapping a blocked arrow returns TapResult.blocked and increments mistakes', () {
      final arrow1 = ArrowModel(
        id: 'a1',
        headRow: 1,
        headCol: 1,
        length: 2,
        direction: ArrowDirection.right,
      );
      final arrow2 = ArrowModel(
        id: 'a2',
        headRow: 1,
        headCol: 3,
        length: 1,
        direction: ArrowDirection.right,
      );

      final level = LevelModel(
        levelNumber: 1,
        seed: 42,
        gridSize: 4,
        difficulty: Difficulty.easy,
        arrowCount: 2,
        maxMistakes: 3,
        arrows: [arrow1, arrow2],
      );

      engine.loadLevel(level);

      final result = engine.tapArrow('a1');
      expect(result, equals(TapResult.blocked));
      expect(engine.mistakes, equals(1));
      expect(engine.isComplete(), isFalse);
    });

    test('Tapping escaping arrow clears it and allows previously blocked arrow to escape', () {
      final arrow1 = ArrowModel(
        id: 'a1',
        headRow: 1,
        headCol: 1,
        length: 2,
        direction: ArrowDirection.right,
      );
      final arrow2 = ArrowModel(
        id: 'a2',
        headRow: 1,
        headCol: 3,
        length: 1,
        direction: ArrowDirection.right,
      );

      final level = LevelModel(
        levelNumber: 1,
        seed: 42,
        gridSize: 4,
        difficulty: Difficulty.easy,
        arrowCount: 2,
        maxMistakes: 3,
        arrows: [arrow1, arrow2],
      );

      engine.loadLevel(level);

      // Tap a2 first (which can escape)
      final result2 = engine.tapArrow('a2');
      expect(result2, equals(TapResult.valid));
      engine.markArrowRemoved('a2');
      expect(engine.activeArrows.length, equals(1));

      // Now a1 should be clear to escape
      expect(engine.canEscape('a1'), isTrue);

      // Tap a1
      final result1 = engine.tapArrow('a1');
      expect(result1, equals(TapResult.valid));
      engine.markArrowRemoved('a1');
      expect(engine.isComplete(), isTrue);
    });

    test('Undo restores previously escaped arrow', () {
      final arrow = ArrowModel(
        id: 'a1',
        headRow: 0,
        headCol: 0,
        length: 1,
        direction: ArrowDirection.up,
      );

      final level = LevelModel(
        levelNumber: 1,
        seed: 42,
        gridSize: 3,
        difficulty: Difficulty.easy,
        arrowCount: 1,
        maxMistakes: 3,
        arrows: [arrow],
      );

      engine.loadLevel(level);
      expect(engine.activeArrows.length, equals(1));

      engine.tapArrow('a1');
      engine.markArrowRemoved('a1');
      expect(engine.activeArrows.isEmpty, isTrue);

      final undone = engine.undo();
      expect(undone, isTrue);
      expect(engine.activeArrows.length, equals(1));
      expect(engine.activeArrows.first.state, equals(ArrowState.normal));
    });

    test('Reset restores original level state', () {
      final arrow = ArrowModel(
        id: 'a1',
        headRow: 0,
        headCol: 0,
        length: 1,
        direction: ArrowDirection.up,
      );

      final level = LevelModel(
        levelNumber: 1,
        seed: 42,
        gridSize: 3,
        difficulty: Difficulty.easy,
        arrowCount: 1,
        maxMistakes: 3,
        arrows: [arrow],
      );

      engine.loadLevel(level);
      engine.tapArrow('a1');
      engine.markArrowRemoved('a1');
      expect(engine.isComplete(), isTrue);

      engine.reset();
      expect(engine.isComplete(), isFalse);
      expect(engine.moves, equals(0));
      expect(engine.mistakes, equals(0));
      expect(engine.activeArrows.length, equals(1));
    });
  });
}
