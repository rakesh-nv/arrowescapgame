import '../../data/models/level_model.dart';
import '../solver/level_solver.dart';

/// The last check a generated board passes before it can be shown: every
/// rule a playable level must satisfy, in one place, shared by the generator
/// and the tests.
class LevelValidator {
  LevelValidator._();

  /// Share of the silhouette the arrows must cover, so the picture is drawn
  /// by the arrows rather than left half empty.
  static const double minPictureFill = 0.8;

  /// Everything wrong with [level]; an empty list means it is playable.
  ///
  /// * every arrow has a unique id and a well-formed path of 3+ cells, each
  ///   step one orthogonal cell, inside the board;
  /// * its direction is the direction of its last segment, so the head never
  ///   points back into its own body;
  /// * no two arrows share a cell, and no arrow leaves the silhouette;
  /// * the arrows cover at least [minPictureFill] of the silhouette;
  /// * the board has an escape order, and replaying that order under the
  ///   game's own escape rule clears it.
  static List<String> problems(LevelModel level) {
    final out = <String>[];
    final n = level.gridSize;
    final mask = level.shapeCells;
    if (level.arrows.isEmpty) return ['no arrows'];
    if (level.arrowCount != level.arrows.length) {
      out.add('arrowCount ${level.arrowCount} != ${level.arrows.length}');
    }

    final ids = <String>{};
    final owner = <(int, int), String>{};
    for (final a in level.arrows) {
      if (!ids.add(a.id)) out.add('duplicate id ${a.id}');
      if (!a.hasValidPath || a.length < 3) {
        out.add('${a.id}: malformed path');
        continue;
      }
      if (!LevelSolver.isWithinGrid(a, n)) out.add('${a.id}: off the board');
      final (pr, pc) = a.points[a.points.length - 2];
      final (hr, hc) = a.points.last;
      if (hr - pr != a.exitDirection.dRow || hc - pc != a.exitDirection.dCol) {
        out.add('${a.id}: direction differs from its last segment');
      }
      for (final cell in a.occupiedCells) {
        final other = owner[cell];
        if (other != null) out.add('${a.id} overlaps $other at $cell');
        owner[cell] = a.id;
        if (mask.isNotEmpty && !mask.contains(cell)) {
          out.add('${a.id} leaves the silhouette at $cell');
        }
      }
    }
    if (out.isNotEmpty) return out;

    if (mask.isNotEmpty && owner.length < mask.length * minPictureFill) {
      out.add('arrows fill only ${owner.length}/${mask.length} picture cells');
    }

    final solved = LevelSolver.solve(level.arrows, n);
    if (!solved.solvable) return [...out, 'no escape order'];
    final remaining = [...level.arrows];
    for (final id in solved.solution) {
      final i = remaining.indexWhere((a) => a.id == id);
      if (i < 0 || !LevelSolver.canEscape(remaining[i], remaining, n)) {
        return [...out, 'escape order fails at $id'];
      }
      remaining.removeAt(i);
    }
    if (remaining.isNotEmpty) out.add('${remaining.length} arrows never escape');
    return out;
  }
}
