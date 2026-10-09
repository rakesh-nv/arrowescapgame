import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/data/models/arrow_direction.dart';
import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/data/repositories/level_repository.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';

void main() {
  group('LevelSolver Tests', () {
    test('Empty board is trivially solvable', () {
      final result = LevelSolver.solve([], 4);
      expect(result.solvable, isTrue);
      expect(result.solution, isEmpty);
    });

    test('Solves a simple 2-arrow board in correct order', () {
      // Arrow 1 at headRow: 0, headCol: 0, direction DOWN -> path down through (1,0), (2,0)
      // Arrow 2 at headRow: 1, headCol: 0, direction RIGHT -> path right through (1,1), (1,2)
      // Arrow 1 is blocked by Arrow 2 at (1,0).
      // Arrow 2 has a clear path right.
      // So solution order must be [a2, a1].
      final arrow1 = ArrowModel(
        id: 'a1',
        headRow: 0,
        headCol: 0,
        length: 1,
        direction: ArrowDirection.down,
      );
      final arrow2 = ArrowModel(
        id: 'a2',
        headRow: 1,
        headCol: 0,
        length: 1,
        direction: ArrowDirection.right,
      );

      final result = LevelSolver.solve([arrow1, arrow2], 3);
      expect(result.solvable, isTrue);
      expect(result.solution, equals(['a2', 'a1']));
    });

    test('Identifies deadlock / unsolvable cycles', () {
      // Create a deadlock:
      // a1 at (0,0) points RIGHT toward (0,1)
      // a2 at (0,1) points DOWN toward (1,1)
      // a3 at (1,1) points LEFT toward (1,0)
      // a4 at (1,0) points UP toward (0,0)
      final a1 = ArrowModel(id: 'a1', headRow: 0, headCol: 0, length: 1, direction: ArrowDirection.right);
      final a2 = ArrowModel(id: 'a2', headRow: 0, headCol: 1, length: 1, direction: ArrowDirection.down);
      final a3 = ArrowModel(id: 'a3', headRow: 1, headCol: 1, length: 1, direction: ArrowDirection.left);
      final a4 = ArrowModel(id: 'a4', headRow: 1, headCol: 0, length: 1, direction: ArrowDirection.up);

      final result = LevelSolver.solve([a1, a2, a3, a4], 3);
      expect(result.solvable, isFalse);
      expect(result.solution, isEmpty);
    });

    test('Snake-like continuous arrow with 90-degree turn escapes properly', () {
      // L-shaped snake: (0,0) -> (1,0) -> (1,1), head at (1,1) pointing RIGHT
      final snake1 = ArrowModel(
        id: 's1',
        points: const [(0, 0), (1, 0), (1, 1)],
      );
      expect(snake1.turns, equals(1));
      expect(snake1.direction, equals(ArrowDirection.right));

      // Clear 4x4 board
      expect(LevelSolver.canEscape(snake1, [snake1], 4), isTrue);

      // Blocker at (1, 2) in front of snake head
      final blocker = ArrowModel(
        id: 'b1',
        points: const [(1, 2)],
      );
      expect(LevelSolver.canEscape(snake1, [snake1, blocker], 4), isFalse);

      // A cell near the tail is not part of the head's exit lane; the snake
      // body follows its own route before it leaves that terminal lane.
      final unrelated = ArrowModel(id: 'u1', points: const [(0, 2)]);
      expect(LevelSolver.canEscape(snake1, [snake1, unrelated], 4), isTrue);
    });

    test('Verifies that generated campaign levels 1-5 are solvable with snake paths', () {
      for (int i = 1; i <= 5; i++) {
        final level = LevelRepository.getLevel(i);
        final result = LevelSolver.solve(level.arrows, level.gridSize);
        expect(result.solvable, isTrue, reason: 'Level $i should be solvable');
        expect(result.solution.length, equals(level.arrows.length));
      }
    });

    test('Overlapping or out-of-bounds boards are rejected', () {
      final a = ArrowModel(id: 'a', points: const [(0, 0), (0, 1)]);
      final b = ArrowModel(id: 'b', points: const [(1, 1), (0, 1)]);
      expect(LevelSolver.solve([a, b], 4).solvable, isFalse);

      final outside = ArrowModel(id: 'o', points: const [(0, 3), (0, 4)]);
      expect(LevelSolver.solve([outside], 4).solvable, isFalse);
    });

    test('The solution order replays under the game rule (canEscape)', () {
      for (final n in [1, 40, 120]) {
        final level = LevelRepository.getLevel(n);
        final result = LevelSolver.solve(level.arrows, level.gridSize);
        final remaining = [...level.arrows];
        for (final id in result.solution) {
          final arrow = remaining.firstWhere((a) => a.id == id);
          expect(
            LevelSolver.canEscape(arrow, remaining, level.gridSize),
            isTrue,
            reason: 'level $n: $id must be free when the solution removes it',
          );
          remaining.remove(arrow);
        }
        expect(remaining, isEmpty);
      }
    });

    test('firstBlocker names the nearest arrow in the exit lane', () {
      // Head at (2,0) pointing up; arrows at (1,0) and (0,0) both in the lane.
      final up = ArrowModel(id: 'up', points: const [(3, 0), (2, 0)]);
      final near = ArrowModel(id: 'near', points: const [(1, 0), (1, 1)]);
      final far = ArrowModel(id: 'far', points: const [(0, 0), (0, 1)]);
      expect(LevelSolver.firstBlocker(up, [up, near, far], 4), 'near');
      expect(LevelSolver.firstBlocker(up, [up, far], 4), 'far');
      expect(LevelSolver.firstBlocker(up, [up], 4), isNull);
    });
  });
}
