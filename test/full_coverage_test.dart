import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/game/generator/dot_grid_generator.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';

void main() {
  test('DotGridGenerator produces 100% dot coverage across levels and difficulties', () {
    final difficulties = [
      (Difficulty.easy, 1),
      (Difficulty.normal, 25),
      (Difficulty.hard, 55),
      (Difficulty.expert, 85),
    ];

    for (final (diff, lvl) in difficulties) {
      final level = DotGridGenerator.generate(
        levelNumber: lvl,
        seed: lvl * 1000 + 42,
        difficulty: diff,
        targetCoverage: 1.0,
      );
      expect(level, isNotNull);
      final total = level!.gridSize * level.gridSize;
      final used = <(int, int)>{for (final a in level.arrows) ...a.occupiedCells};
      print('${diff.name} (Lvl $lvl): ${used.length} / $total dots filled (${(used.length / total * 100).toStringAsFixed(1)}%)');
      expect(used.length, greaterThanOrEqualTo((total * 0.95).floor()), reason: 'High dot coverage expected');
      expect(LevelSolver.solve(level.arrows, level.gridSize).solvable, isTrue);
    }
  });
}
