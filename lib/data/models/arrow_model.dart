import 'arrow_direction.dart';
import 'arrow_state.dart';

/// Represents a single continuous snake-shaped arrow on the game board.
///
/// An arrow is a continuous, connected path of grid cells:
/// `points`: ordered list of (row, col) coordinates from TAIL (index 0) to HEAD (index N-1).
/// Adjacent cells in the path must be orthogonally connected (no diagonals).
///
/// The arrow has exactly ONE arrowhead at the final point (the head),
/// pointing in the direction of the final segment.
class ArrowModel {
  final String id;

  /// Ordered list of (row, col) cells from tail to head.
  final List<(int row, int col)> points;

  /// The direction used after the path reaches its final cell.  Keeping this
  /// explicit matters for one-cell paths and makes the path, rather than a
  /// legacy length/direction tuple, the source of truth.
  final ArrowDirection? _exitDirection;

  ArrowState state;

  ArrowModel({
    required this.id,
    List<(int row, int col)>? points,
    List<(int row, int col)>? cells,
    int? headRow,
    int? headCol,
    int? length,
    ArrowDirection? direction,
    this.state = ArrowState.normal,
  })  : points = cells ?? points ??
            _buildPointsFromHead(
              headRow ?? 0,
              headCol ?? 0,
              length ?? 1,
              direction ?? ArrowDirection.right,
            ),
        _exitDirection = direction,
        assert(
          cells != null || points != null || (headRow != null && headCol != null),
          'Must provide cells/points or headRow/headCol',
        );

  static List<(int, int)> _buildPointsFromHead(
    int headRow,
    int headCol,
    int length,
    ArrowDirection direction,
  ) {
    final pts = <(int, int)>[];
    final dRow = direction.dRow;
    final dCol = direction.dCol;
    for (int i = length - 1; i >= 0; i--) {
      pts.add((headRow - dRow * i, headCol - dCol * i));
    }
    return pts;
  }

  /// Convenience factory for a straight arrow
  factory ArrowModel.straight({
    required String id,
    required int headRow,
    required int headCol,
    required int length,
    required ArrowDirection direction,
    ArrowState state = ArrowState.normal,
  }) {
    return ArrowModel(
      id: id,
      headRow: headRow,
      headCol: headCol,
      length: length,
      direction: direction,
      state: state,
    );
  }

  /// Backward-compatible constructor that automatically builds straight or multi-point arrows
  factory ArrowModel.legacy({
    required String id,
    required int headRow,
    required int headCol,
    required int length,
    required ArrowDirection direction,
    ArrowState state = ArrowState.normal,
  }) =>
      ArrowModel.straight(
        id: id,
        headRow: headRow,
        headCol: headCol,
        length: length,
        direction: direction,
        state: state,
      );

  /// Row of the arrow's HEAD (pointing end)
  int get headRow => points.last.$1;

  /// Col of the arrow's HEAD (pointing end)
  int get headCol => points.last.$2;

  /// Row of the arrow's TAIL (start of the snake)
  int get tailRow => points.first.$1;

  /// Col of the arrow's TAIL (start of the snake)
  int get tailCol => points.first.$2;

  /// Total number of grid cells this arrow spans
  int get length => points.length;

  /// Returns all cells occupied by this snake
  List<(int row, int col)> get occupiedCells => points;

  /// Name used by the path-based game code. `points` remains for backwards
  /// compatibility with saved/generated levels.
  List<(int row, int col)> get cells => List.unmodifiable(points);

  /// Direction the arrowhead points (derived from the last segment, or override)
  ArrowDirection get exitDirection {
    if (_exitDirection != null) return _exitDirection;
    if (points.length >= 2) {
      final prev = points[points.length - 2];
      final last = points.last;
      final dr = last.$1 - prev.$1;
      final dc = last.$2 - prev.$2;
      if (dr == 0 && dc > 0) return ArrowDirection.right;
      if (dr == 0 && dc < 0) return ArrowDirection.left;
      if (dr > 0 && dc == 0) return ArrowDirection.down;
      if (dr < 0 && dc == 0) return ArrowDirection.up;
    }
    return ArrowDirection.right;
  }

  /// Deprecated compatibility alias. Prefer [exitDirection].
  ArrowDirection get direction => exitDirection;

  /// A path is valid only when every cell is unique and each segment is a
  /// cardinal, one-cell step. This guards rendering, hit testing and solving
  /// from ever disagreeing about an arrow's shape.
  bool get hasValidPath {
    if (points.isEmpty || points.toSet().length != points.length) return false;
    for (var i = 1; i < points.length; i++) {
      final dr = (points[i].$1 - points[i - 1].$1).abs();
      final dc = (points[i].$2 - points[i - 1].$2).abs();
      if (dr + dc != 1) return false;
    }
    return true;
  }

  /// Count of 90-degree turns in this snake path
  int get turns {
    if (points.length < 3) return 0;
    int count = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final dr1 = p1.$1 - p0.$1;
      final dc1 = p1.$2 - p0.$2;
      final dr2 = p2.$1 - p1.$1;
      final dc2 = p2.$2 - p1.$2;
      if (dr1 != dr2 || dc1 != dc2) {
        count++;
      }
    }
    return count;
  }

  /// Creates a copy with optional overrides
  ArrowModel copyWith({
    String? id,
    List<(int row, int col)>? points,
    int? headRow,
    int? headCol,
    int? length,
    ArrowDirection? direction,
    ArrowState? state,
  }) {
    if (points != null) {
      return ArrowModel(
        id: id ?? this.id,
        points: points,
        direction: direction ?? _exitDirection,
        state: state ?? this.state,
      );
    }
    if (headRow != null || headCol != null || length != null) {
      return ArrowModel(
        id: id ?? this.id,
        headRow: headRow ?? this.headRow,
        headCol: headCol ?? this.headCol,
        length: length ?? this.length,
        direction: direction ?? this.direction,
        state: state ?? this.state,
      );
    }
    return ArrowModel(
      id: id ?? this.id,
      points: List.from(this.points),
      direction: direction ?? _exitDirection,
      state: state ?? this.state,
    );
  }

  @override
  String toString() =>
      'Arrow($id dir=$direction pts=$points turns=$turns state=$state)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrowModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
