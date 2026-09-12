import 'package:flutter_test/flutter_test.dart';
import 'package:arrowescapegame/data/models/difficulty.dart';
import 'package:arrowescapegame/game/generator/dot_grid_generator.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';

void main() {
  group('DotGridGenerator Tests', () {
    test('Generates valid, solvable level with high density', () {
      final level = DotGridGenerator.generate(
        levelNumber: 1,
        seed: 12345,
        difficulty: Difficulty.normal,
      );

      expect(level, isNotNull);
      expect(level!.arrows.isNotEmpty, isTrue);

      // Verify each arrow has valid orthogonal dot-to-dot path
      for (final arrow in level.arrows) {
        expect(arrow.hasValidPath, isTrue, reason: 'Arrow ${arrow.id} has invalid path');
        expect(arrow.length, greaterThanOrEqualTo(2));
      }

      // Verify no duplicate edges
      final edges = <String>{};
      for (final arrow in level.arrows) {
        for (var i = 1; i < arrow.points.length; i++) {
          final p1 = arrow.points[i - 1];
          final p2 = arrow.points[i];
          final key = p1.$1 < p2.$1 || (p1.$1 == p2.$1 && p1.$2 < p2.$2)
              ? '${p1.$1},${p1.$2}-${p2.$1},${p2.$2}'
              : '${p2.$1},${p2.$2}-${p1.$1},${p1.$2}';
          expect(edges.contains(key), isFalse, reason: 'Duplicate edge $key in arrow ${arrow.id}');
          edges.add(key);
        }
      }

      // Verify density
      final totalDots = level.gridSize * level.gridSize;
      final usedDots = <(int, int)>{for (final a in level.arrows) ...a.occupiedCells};
      final coverage = usedDots.length / totalDots;
      expect(coverage, greaterThanOrEqualTo(0.70), reason: 'Coverage was $coverage');

      // Verify solvable by LevelSolver
      final solveResult = LevelSolver.solve(level.arrows, level.gridSize);
      expect(solveResult.solvable, isTrue);
      expect(solveResult.solution.length, equals(level.arrows.length));
    });

    test('Generates solvable levels across different difficulties', () {
      for (final diff in [Difficulty.easy, Difficulty.normal, Difficulty.hard]) {
        final level = DotGridGenerator.generate(
          levelNumber: 42,
          seed: 98765,
          difficulty: diff,
        );
        expect(level, isNotNull);
        final solveResult = LevelSolver.solve(level!.arrows, level.gridSize);
        expect(solveResult.solvable, isTrue);
      }
    });
  });
}
