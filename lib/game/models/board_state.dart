import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';

/// Immutable snapshot of the board state used by the solver
class BoardState {
  /// Map of arrowId → ArrowModel for all non-removed arrows
  final Map<String, ArrowModel> arrows;
  final int gridSize;

  const BoardState({
    required this.arrows,
    required this.gridSize,
  });

  /// Create initial state from a list of arrows
  factory BoardState.fromArrows(List<ArrowModel> arrows, int gridSize) {
    return BoardState(
      arrows: {
        for (final a in arrows) a.id: a.copyWith(state: ArrowState.normal),
      },
      gridSize: gridSize,
    );
  }

  /// Create a new board state with the given arrow removed
  BoardState withArrowRemoved(String arrowId) {
    final newArrows = Map<String, ArrowModel>.from(arrows);
    newArrows.remove(arrowId);
    return BoardState(arrows: newArrows, gridSize: gridSize);
  }

  bool get isEmpty => arrows.isEmpty;

  List<ArrowModel> get allArrows => arrows.values.toList();

  /// Cell ownership is rebuilt from the same path cells rendered on screen.
  /// A null value means the board definition is invalid because paths overlap.
  Map<(int row, int col), String>? get occupancy {
    final result = <(int, int), String>{};
    for (final arrow in allArrows) {
      for (final cell in arrow.occupiedCells) {
        if (result.containsKey(cell)) return null;
        result[cell] = arrow.id;
      }
    }
    return result;
  }

  /// Stable hash for memoization: sorted arrow IDs joined
  String get stateHash {
    final sortedIds = arrows.keys.toList()..sort();
    return sortedIds.join(',');
  }
}
