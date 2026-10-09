import 'package:arrowescapegame/core/constants/app_constants.dart';
import 'package:arrowescapegame/data/models/arrow_direction.dart';
import 'package:arrowescapegame/data/models/level_model.dart';
import 'package:arrowescapegame/game/generator/level_generator.dart';
import 'package:arrowescapegame/game/generator/silhouette.dart';
import 'package:arrowescapegame/game/generator/silhouette_library.dart';
import 'package:arrowescapegame/game/solver/level_solver.dart';
import 'package:flutter_test/flutter_test.dart';

const _requested = {
  // Animals
  'cat', 'dog', 'rabbit', 'butterfly', 'fish', 'bird', 'turtle', 'elephant',
  'lion', 'dinosaur', 'owl', 'snake',
  // Vehicles
  'car', 'racecar', 'truck', 'bus', 'motorcycle', 'bicycle', 'airplane',
  'rocket', 'ship',
  // Objects, nature, abstract
  'house', 'castle', 'tree', 'flower', 'crown', 'robot', 'footprint', 'moon',
  'planet', 'note', 'diamond', 'face', 'knot', 'starburst', 'spiral',
};

/// The board is valid, solvable, and its arrows draw the silhouette.
void _expectPlayableShape(LevelModel level, String reason) {
  final n = level.gridSize;
  final mask = level.shapeCells;
  expect(mask, isNotEmpty, reason: reason);

  final seen = <(int, int)>{};
  for (final a in level.arrows) {
    expect(a.hasValidPath, isTrue, reason: '$reason malformed ${a.id}');
    expect(a.length, greaterThanOrEqualTo(3), reason: '$reason short ${a.id}');
    expect(LevelSolver.isWithinGrid(a, n), isTrue, reason: reason);
    // Direction comes from the final segment, so the head never points back
    // into its own body.
    final (pr, pc) = a.points[a.points.length - 2];
    final (hr, hc) = a.points.last;
    expect((hr - pr, hc - pc),
        (a.exitDirection.dRow, a.exitDirection.dCol),
        reason: '$reason direction ${a.id}');
    for (final cell in a.occupiedCells) {
      expect(seen.add(cell), isTrue, reason: '$reason overlap at $cell');
      expect(mask.contains(cell), isTrue,
          reason: '$reason arrow ${a.id} leaves the silhouette at $cell');
    }
  }
  // The picture is drawn by the arrows themselves, not left mostly empty.
  expect(seen.length / mask.length, greaterThanOrEqualTo(0.8),
      reason: '$reason fills only ${seen.length}/${mask.length} cells');

  final solved = LevelSolver.solve(level.arrows, n);
  expect(solved.solvable, isTrue, reason: '$reason not solvable');
  expect(solved.solution.length, level.arrows.length, reason: reason);
}

void main() {
  test('the library has every requested picture, with unique ids', () {
    final ids = SilhouetteLibrary.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.toSet(), containsAll(_requested));
    final categories = SilhouetteLibrary.all.map((s) => s.category).toSet();
    expect(categories, containsAll(SilhouetteCategory.values));
    for (final s in SilhouetteLibrary.all) {
      expect(s.name, isNotEmpty);
      expect(s.minGrid,
          inInclusiveRange(16, AppConstants.maxGridSize));
    }
  });

  group('Rasterized silhouettes are one connected, sizeable picture', () {
    for (final s in SilhouetteLibrary.all) {
      test(s.id, () {
        for (var g = s.minGrid; g <= AppConstants.maxGridSize; g++) {
          for (final mirror in [false, true]) {
            final m = s.rasterize(g, mirror: mirror);
            final reason = '${s.id} @$g mirror=$mirror';
            // Nothing meaningful is lost to disconnected fragments.
            expect(m.droppedCells, lessThanOrEqualTo(m.cells.length ~/ 20),
                reason: reason);
            // Large enough to read, small enough to look like a shape.
            final share = m.cells.length / (g * g);
            expect(share, inInclusiveRange(0.15, 0.65), reason: reason);
          }
        }
      });
    }
  });

  test('silhouettes are distinct pictures', () {
    final masks = {
      for (final s in SilhouetteLibrary.all) s.id: s.rasterize(24).cells,
    };
    final ids = masks.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final a = masks[ids[i]]!, b = masks[ids[j]]!;
        final overlap = a.intersection(b).length / a.union(b).length;
        expect(overlap, lessThan(0.9), reason: '${ids[i]} vs ${ids[j]}');
      }
    }
  });

  test('mirroring flips the picture left to right', () {
    final cat = SilhouetteLibrary.byId('cat');
    final plain = cat.rasterize(20).cells;
    final mirrored = cat.rasterize(20, mirror: true).cells;
    expect(mirrored, {for (final (r, c) in plain) (r, 19 - c)});
  });

  group('Every silhouette makes a playable puzzle', () {
    for (final s in SilhouetteLibrary.all) {
      test(s.id, () {
        for (final (grid, level) in [
          (s.minGrid, 10),
          (AppConstants.maxGridSize, 190),
        ]) {
          final board = LevelGenerator.generate(
            levelNumber: level,
            seed: 4242,
            silhouette: s,
            gridSize: grid,
          )!;
          final reason = '${s.id} @$grid';
          expect(board.gridSize, grid, reason: reason);
          expect(board.shapeName, s.name, reason: reason);
          _expectPlayableShape(board, reason);
          // Real puzzles, not straight-row fallbacks.
          expect(board.arrows.any((a) => a.turns > 0), isTrue, reason: reason);
          final plan = LevelSolver.planningStats(board.arrows, grid)!;
          expect(plan.rounds, greaterThanOrEqualTo(3), reason: reason);
        }
      });
    }
  });

  test('the fallback board keeps the silhouette and stays solvable', () {
    for (final s in SilhouetteLibrary.all) {
      final mask = s.rasterize(s.minGrid).cells;
      final level = LevelGenerator.guaranteedLevel(
        levelNumber: 1,
        seed: 1,
        spec: LevelGenerator.specFor(1).withGridSize(s.minGrid),
        mask: mask,
        shapeName: s.name,
      );
      // Straight arrows only: rows first, then columns for narrow parts.
      for (final a in level.arrows) {
        expect(a.turns, 0);
      }
      _expectPlayableShape(level, 'fallback ${s.id}');
    }
  });

  test('every campaign level is a silhouette puzzle with its name', () {
    for (final n in [1, 2, 3, 37, 88, 151, AppConstants.totalLevels]) {
      final level = LevelGenerator.generate(
        levelNumber: n,
        seed: AppConstants.levelSeed(n),
      )!;
      expect(level.shapeName, LevelGenerator.silhouetteForLevel(n).name);
      _expectPlayableShape(level, 'Level $n');
    }
  });

  test('ArrowDirection deltas are unit steps', () {
    for (final d in ArrowDirection.values) {
      expect(d.dRow.abs() + d.dCol.abs(), 1);
    }
  });
}
