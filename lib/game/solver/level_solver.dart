import '../../data/models/arrow_model.dart';
import '../models/board_state.dart';
import '../models/tap_result.dart';

/// Determines whether a puzzle board is solvable.
///
/// The escape rule only checks the lane in front of an arrow's head against
/// the arrows still on the board, so removing an arrow can never block another.
/// That makes a greedy solve exact: repeatedly removing every currently
/// escapable arrow clears the board if and only if the board is solvable. No
/// search or iteration cap is needed, even on the largest boards.
class LevelSolver {
  LevelSolver._();

  /// Solve the given board.
  ///
  /// Returns [SolveResult] with solvable=true and a valid solution sequence,
  /// or solvable=false if the board is invalid (bad path, out of bounds,
  /// overlapping arrows) or some arrows can never escape.
  static SolveResult solve(List<ArrowModel> arrows, int gridSize) {
    if (arrows.isEmpty) {
      return const SolveResult(solvable: true, solution: []);
    }

    final remaining = <String, ArrowModel>{};
    final occupancy = <(int, int), String>{};
    for (final arrow in arrows) {
      if (!arrow.hasValidPath || !isWithinGrid(arrow, gridSize)) {
        return SolveResult.unsolvable;
      }
      if (remaining.containsKey(arrow.id)) return SolveResult.unsolvable;
      remaining[arrow.id] = arrow;
      for (final cell in arrow.occupiedCells) {
        if (occupancy.containsKey(cell)) return SolveResult.unsolvable;
        occupancy[cell] = arrow.id;
      }
    }

    final solution = <String>[];
    while (remaining.isNotEmpty) {
      final free = [
        for (final arrow in remaining.values)
          if (_laneClear(arrow, occupancy, gridSize)) arrow,
      ];
      if (free.isEmpty) return SolveResult.unsolvable;
      for (final arrow in free) {
        remaining.remove(arrow.id);
        for (final cell in arrow.occupiedCells) {
          occupancy.remove(cell);
        }
        solution.add(arrow.id);
      }
    }
    return SolveResult(solvable: true, solution: solution);
  }

  /// How much reasoning a board demands, measured with the same greedy peel as
  /// [solve]. Returns null for an unsolvable board.
  ///
  /// - `rounds`: how many waves of "everything currently free" it takes to
  ///   clear the board (the minimum number of planning steps).
  /// - `initiallyFree`: arrows that can escape on the very first tap; every
  ///   other arrow is a trap that costs a life if tapped too early.
  static ({int rounds, int initiallyFree})? planningStats(
    List<ArrowModel> arrows,
    int gridSize,
  ) {
    final result = solve(arrows, gridSize);
    if (!result.solvable) return null;
    if (arrows.isEmpty) return (rounds: 0, initiallyFree: 0);

    final remaining = <String, ArrowModel>{for (final a in arrows) a.id: a};
    final occupancy = <(int, int), String>{
      for (final a in arrows)
        for (final cell in a.occupiedCells) cell: a.id,
    };
    var rounds = 0;
    var initiallyFree = 0;
    while (remaining.isNotEmpty) {
      final free = [
        for (final arrow in remaining.values)
          if (_laneClear(arrow, occupancy, gridSize)) arrow,
      ];
      if (rounds == 0) initiallyFree = free.length;
      rounds++;
      for (final arrow in free) {
        remaining.remove(arrow.id);
        for (final cell in arrow.occupiedCells) {
          occupancy.remove(cell);
        }
      }
    }
    return (rounds: rounds, initiallyFree: initiallyFree);
  }

  static bool _laneClear(
    ArrowModel arrow,
    Map<(int, int), String> occupancy,
    int gridSize,
  ) {
    final dir = arrow.exitDirection;
    var r = arrow.headRow + dir.dRow;
    var c = arrow.headCol + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      final owner = occupancy[(r, c)];
      if (owner != null && owner != arrow.id) return false;
      r += dir.dRow;
      c += dir.dCol;
    }
    return true;
  }

  /// The id of the nearest arrow in [arrow]'s exit lane, or null if the lane
  /// is clear. Used only for feedback; the escape rule is [canEscape].
  static String? firstBlocker(
    ArrowModel arrow,
    List<ArrowModel> remaining,
    int gridSize,
  ) {
    final owners = <(int, int), String>{
      for (final other in remaining)
        if (other.id != arrow.id)
          for (final cell in other.occupiedCells) cell: other.id,
    };
    final dir = arrow.exitDirection;
    var r = arrow.headRow + dir.dRow;
    var c = arrow.headCol + dir.dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      final owner = owners[(r, c)];
      if (owner != null) return owner;
      r += dir.dRow;
      c += dir.dCol;
    }
    return null;
  }

  /// Returns all arrows that can currently escape from the board
  static List<ArrowModel> getAvailableArrows(
      List<ArrowModel> arrows, int gridSize) {
    final state = BoardState.fromArrows(arrows, gridSize);
    return _getAvailableArrows(state);
  }

  static List<ArrowModel> _getAvailableArrows(BoardState state) {
    return state.allArrows
        .where((a) => _canEscape(a, state))
        .toList();
  }

  /// Checks if [arrow] can escape from the current [state].
  ///
  /// An arrow can escape if the cells from its head (in its direction)
  /// to the board boundary are all unoccupied by other arrows.
  static bool canEscape(ArrowModel arrow, List<ArrowModel> remaining, int gridSize) {
    final state = BoardState(
      arrows: {for (final a in remaining) a.id: a},
      gridSize: gridSize,
    );
    return _canEscape(arrow, state);
  }

  static bool _canEscape(ArrowModel arrow, BoardState state) {
    final gridSize = state.gridSize;
    final dir = arrow.exitDirection;
    final dRow = dir.dRow;
    final dCol = dir.dCol;

    // The complete, winding path must be logically valid and in the grid.
    if (!arrow.hasValidPath) return false;
    for (final p in arrow.points) {
      if (p.$1 < 0 || p.$1 >= gridSize || p.$2 < 0 || p.$2 >= gridSize) {
        return false;
      }
    }

    final occupancy = state.occupancy;
    if (occupancy == null) return false;

    // Material first moves through the arrow's own connected path. After the
    // head reaches its endpoint, the whole snake follows it through this
    // terminal exit lane; any foreign occupied cell there blocks the move.
    for (final cell in arrow.cells) {
      if (occupancy[cell] != arrow.id) return false;
    }
    var r = arrow.headRow + dRow;
    var c = arrow.headCol + dCol;
    while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      final owner = occupancy[(r, c)];
      if (owner != null && owner != arrow.id) return false;
      r += dRow;
      c += dCol;
    }
    return true;
  }

  /// Verify that two arrows do NOT overlap in cells.
  static bool arrowsOverlap(ArrowModel a, ArrowModel b) {
    final cellsA = a.occupiedCells.toSet();
    for (final cell in b.occupiedCells) {
      if (cellsA.contains(cell)) return true;
    }
    return false;
  }

  /// Check whether an arrow's cells fit entirely within the grid
  static bool isWithinGrid(ArrowModel arrow, int gridSize) {
    for (final cell in arrow.occupiedCells) {
      if (cell.$1 < 0 ||
          cell.$1 >= gridSize ||
          cell.$2 < 0 ||
          cell.$2 >= gridSize) {
        return false;
      }
    }
    return true;
  }

  /// Generate a hint: return the ID of one currently available arrow
  static String? hint(List<ArrowModel> arrows, int gridSize) {
    final available = getAvailableArrows(arrows, gridSize);
    if (available.isEmpty) return null;
    return available.first.id;
  }
}
