import '../../data/models/arrow_model.dart';
import '../models/board_state.dart';
import '../models/tap_result.dart';

/// Determines whether a puzzle board is solvable.
///
/// Uses depth-first search with memoization.
/// State is identified by the set of remaining arrow IDs (sorted, joined).
class LevelSolver {
  LevelSolver._();

  /// Solve the given board state.
  ///
  /// Returns [SolveResult] with solvable=true and a valid solution sequence,
  /// or solvable=false if no solution exists.
  static SolveResult solve(List<ArrowModel> arrows, int gridSize) {
    if (arrows.isEmpty) {
      return const SolveResult(solvable: true, solution: []);
    }

    final initialState = BoardState.fromArrows(arrows, gridSize);
    final visited = <String>{};
    final solution = <String>[];

    final found = _dfs(initialState, visited, solution);
    return SolveResult(solvable: found, solution: found ? List.from(solution) : []);
  }

  static bool _dfs(
    BoardState state,
    Set<String> visited,
    List<String> solution,
  ) {
    if (state.isEmpty) return true;

    final hash = state.stateHash;
    if (visited.contains(hash)) return false;
    visited.add(hash);

    final available = _getAvailableArrows(state);
    if (available.isEmpty) return false;

    for (final arrow in available) {
      solution.add(arrow.id);
      final nextState = state.withArrowRemoved(arrow.id);
      if (_dfs(nextState, visited, solution)) {
        return true;
      }
      solution.removeLast();
    }

    return false;
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
