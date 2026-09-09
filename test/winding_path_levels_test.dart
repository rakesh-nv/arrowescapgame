import 'package:arrowescapegame/data/models/arrow_direction.dart';
import 'package:arrowescapegame/data/models/arrow_model.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression levels covering the shapes used by the board renderer and
/// escape solver. They are intentionally fixed, rather than random seeds, so
/// a path/collision regression is easy to reproduce.
void main() {
  test('winding regression levels are valid, non-overlapping and solvable', () {
    final levels = <(int, List<ArrowModel>)>[
      (4, _level1()),
      (6, _level2()),
      (8, _level3()),
      (10, _level4()),
    ];

    for (final level in levels) {
      final arrows = level.$2;
      expect(arrows.every((arrow) => arrow.hasValidPath), isTrue);
      for (var i = 0; i < arrows.length; i++) {
        for (var j = i + 1; j < arrows.length; j++) {
          expect(LevelSolver.arrowsOverlap(arrows[i], arrows[j]), isFalse);
        }
      }
      final result = LevelSolver.solve(arrows, level.$1);
      expect(result.solvable, isTrue);
      expect(result.solution.length, arrows.length);
    }
  });
}

List<ArrowModel> _level1() => [
      ArrowModel(id: 'l1-a', cells: const [(0, 0), (1, 0), (1, 1)]),
      ArrowModel(id: 'l1-b', cells: const [(1, 3)]),
      ArrowModel(id: 'l1-c', cells: const [(2, 0), (3, 0), (3, 1)]),
    ];

List<ArrowModel> _level2() => [
      ArrowModel(
          id: 'l2-a', cells: const [(0, 0), (1, 0), (1, 1), (1, 2), (0, 2)]),
      ArrowModel(
          id: 'l2-b', cells: const [(3, 0), (3, 1), (2, 1), (2, 2), (2, 3)]),
      ArrowModel(id: 'l2-c', cells: const [(2, 5)]),
      ArrowModel(id: 'l2-d', cells: const [(4, 0), (5, 0), (5, 1)]),
      ArrowModel(id: 'l2-e', cells: const [(4, 3), (4, 4), (5, 4), (5, 5)]),
    ];

List<ArrowModel> _level3() => [
      ArrowModel(id: 'l3-a', cells: const [(0, 0), (1, 0), (1, 1)]),
      ArrowModel(id: 'l3-b', cells: const [(1, 3)]),
      ArrowModel(id: 'l3-c', cells: const [(2, 0), (2, 1), (3, 1)]),
      ArrowModel(id: 'l3-d', cells: const [(5, 1)]),
      ArrowModel(id: 'l3-e', cells: const [(3, 3), (4, 3), (4, 4)]),
      ArrowModel(id: 'l3-f', cells: const [(5, 3), (5, 4), (6, 4)]),
      ArrowModel(id: 'l3-g', cells: const [(6, 6), (6, 5), (7, 5)]),
      ArrowModel(id: 'l3-h', cells: const [(7, 0), (7, 1), (7, 2)]),
    ];

List<ArrowModel> _level4() => [
      ..._level3(),
      ArrowModel(id: 'l4-a', cells: const [(0, 5), (1, 5), (1, 6), (2, 6)]),
      ArrowModel(id: 'l4-b', cells: const [(4, 7), (5, 7), (5, 8), (6, 8)]),
      ArrowModel(
        id: 'l4-c',
        cells: const [(8, 3), (8, 4), (9, 4), (9, 5)],
        direction: ArrowDirection.right,
      ),
    ];
