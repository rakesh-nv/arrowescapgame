import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/data/models/arrow_direction.dart';
import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/game/engine/game_engine.dart';
import 'package:arrowescapegame/services/storage_service.dart';

void main() {
  group('Saved Game Persistence Tests', () {
    late StorageService storage;
    late GameEngine engine;

    setUp(() {
      storage = StorageService();
      engine = GameEngine();
    });

    test('StorageService saves, retrieves, and clears puzzle progress', () async {
      expect(storage.getSavedGame(5), isNull);
      expect(storage.getLastActiveLevel(), isNull);

      await storage.saveGame(
        levelNumber: 5,
        removedArrowIds: ['a1', 'a3'],
        moves: 2,
        mistakes: 1,
        lives: 2,
      );

      final saved = storage.getSavedGame(5);
      expect(saved, isNotNull);
      expect(saved!['levelNumber'], equals(5));
      expect(saved['removedArrowIds'], equals(['a1', 'a3']));
      expect(saved['moves'], equals(2));
      expect(saved['mistakes'], equals(1));
      expect(saved['lives'], equals(2));
      expect(storage.getLastActiveLevel(), equals(5));

      // Clear saved game
      await storage.clearSavedGame(5);
      expect(storage.getSavedGame(5), isNull);
      expect(storage.getLastActiveLevel(), isNull);
    });

    test('Engine loads saved state and continues puzzle from where it was left', () {
      final a1 = ArrowModel(
        id: 'a1',
        headRow: 0,
        headCol: 0,
        length: 1,
        direction: ArrowDirection.up,
      );
      final a2 = ArrowModel(
        id: 'a2',
        headRow: 1,
        headCol: 1,
        length: 1,
        direction: ArrowDirection.down,
      );
      final a3 = ArrowModel(
        id: 'a3',
        headRow: 2,
        headCol: 2,
        length: 1,
        direction: ArrowDirection.right,
      );

      final level = LevelModel(
        levelNumber: 8,
        seed: 123,
        gridSize: 4,
        difficulty: Difficulty.normal,
        arrowCount: 3,
        maxMistakes: 3,
        arrows: [a1, a2, a3],
      );

      // Suppose user already escaped a1 and a2, then closed the app
      engine.restoreLevel(
        level: level,
        removedArrowIds: ['a1', 'a2'],
        moves: 6,
        mistakes: 1,
        lives: 2,
      );

      expect(engine.moves, equals(6));
      expect(engine.mistakes, equals(1));
      expect(engine.lives, equals(2));
      expect(engine.remainingCount, equals(1));
      expect(engine.activeArrows.single.id, equals('a3'));

      // User continues and escapes the last arrow
      engine.tapArrow('a3');
      engine.markArrowRemoved('a3');
      expect(engine.isComplete(), isTrue);
      expect(engine.remainingCount, equals(0));
    });
  });
}
