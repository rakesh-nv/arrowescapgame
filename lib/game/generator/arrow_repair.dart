import '../../data/models/arrow_model.dart';
import '../solver/level_solver.dart';

/// Repairs arrows whose head would run into their own body on the way out.
///
/// A repair only reorders the arrow's own cells, so the arrow count, every
/// arrow's length and the picture the arrows draw stay exactly the same, and
/// no other arrow changes. Uses no randomness: results are deterministic.
class ArrowRepair {
  ArrowRepair._();

  /// Path orders tried per arrow before giving up on it.
  static const int _maxStates = 400;

  /// Whether [arrow]'s exit lane contains one of its own cells.
  static bool hitsOwnBody(ArrowModel arrow, int gridSize) =>
      LevelSolver.firstCollision(arrow, [arrow], gridSize) == arrow.id;

  /// Returns [arrows] with every self-colliding arrow repaired and the board
  /// still solvable, plus how many were repaired; null if one cannot be.
  static ({List<ArrowModel> arrows, int repaired})? repair(
    List<ArrowModel> arrows,
    int gridSize,
  ) {
    final out = [...arrows];
    var repaired = 0;
    // An arrow with no solvable route now may get one once others have moved
    // their lanes, so sweep until a whole pass changes nothing.
    var pending = [
      for (var i = 0; i < out.length; i++)
        if (hitsOwnBody(out[i], gridSize)) i,
    ];
    while (pending.isNotEmpty) {
      final stuck = <int>[];
      for (final i in pending) {
        final fixed = _repairArrow(out, i, gridSize);
        if (fixed == null) {
          stuck.add(i);
        } else {
          out[i] = fixed;
          repaired++;
        }
      }
      if (stuck.length == pending.length) return null;
      pending = stuck;
    }
    return (arrows: out, repaired: repaired);
  }

  /// Breadth-first over orderings of the arrow's cells: the nearest one with
  /// a lane clear of its own body that keeps the board solvable.
  static ArrowModel? _repairArrow(
    List<ArrowModel> board,
    int index,
    int gridSize,
  ) {
    final original = board[index];
    final seen = {_key(original.points)};
    final queue = [original.points];
    for (var q = 0; q < queue.length && seen.length <= _maxStates; q++) {
      for (final next in _moves(queue[q])) {
        if (!seen.add(_key(next))) continue;
        queue.add(next);
        final candidate = ArrowModel(id: original.id, points: next);
        if (hitsOwnBody(candidate, gridSize)) continue;
        final trial = [...board]..[index] = candidate;
        if (LevelSolver.solve(trial, gridSize).solvable) return candidate;
      }
    }
    return null;
  }

  /// Valid paths over the same cells, one step from [path]: the path reversed,
  /// and each "backbite", where the head joins a body cell it sits next to and
  /// the part in between flips, giving a new head.
  static Iterable<List<(int, int)>> _moves(List<(int, int)> path) sync* {
    yield path.reversed.toList();
    final n = path.length;
    final (hr, hc) = path.last;
    for (var i = n - 3; i >= 0; i--) {
      final (r, c) = path[i];
      if ((r - hr).abs() + (c - hc).abs() != 1) continue;
      yield [...path.sublist(0, i + 1), ...path.sublist(i + 1).reversed];
    }
  }

  static String _key(List<(int, int)> path) =>
      path.map((p) => '${p.$1},${p.$2}').join(';');
}
