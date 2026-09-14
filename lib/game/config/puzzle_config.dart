import 'dart:math' show max;

/// Centralized configuration for the dot-grid puzzle layout.
///
/// Encapsulates the geometry and visual metrics for:
/// - The invisible dot grid (rows, columns, cellSpacing)
/// - Path rendering (pathThickness, visualGap)
/// - Arrowheads (arrowHeadSize)
/// - Safe clearance constraints
class PuzzleConfig {
  final int gridRows;
  final int gridColumns;
  final double cellSpacing;
  final double pathThickness;
  final double arrowHeadSize;
  final double boardPadding;
  final double minimumClearance;

  const PuzzleConfig({
    required this.gridRows,
    required this.gridColumns,
    this.cellSpacing = 30.0,
    this.pathThickness = 4.0,
    this.arrowHeadSize = 7.5,
    this.boardPadding = 20.0,
    this.minimumClearance = 8.0,
  });

  /// The clear visual gap between adjacent parallel paths.
  /// visualGap = cellSpacing - pathThickness
  double get visualGap => cellSpacing - pathThickness;

  /// Default configuration for a given grid size (e.g. 10x10).
  factory PuzzleConfig.forGrid(int gridSize) {
    const defaultSpacing = 30.0;
    const defaultThickness = 4.0;
    return PuzzleConfig(
      gridRows: gridSize,
      gridColumns: gridSize,
      cellSpacing: defaultSpacing,
      pathThickness: defaultThickness,
      arrowHeadSize: 7.5,
      boardPadding: 20.0,
      minimumClearance: 8.0,
    );
  }

  /// Responsive factory that dynamically adapts to device dimensions.
  ///
  /// Examples:
  /// - 390px phone: ~8–10 columns, ~28–30px cellSpacing
  /// - 412px phone: ~9–11 columns, ~30–32px cellSpacing
  /// - Tablet (>600px): scales columns and maintains comfortable spacing
  factory PuzzleConfig.adaptive({
    required double screenWidth,
    double screenHeight = 800.0,
    int? overrideGridSize,
    double boardPadding = 20.0,
  }) {
    final int cols;
    if (overrideGridSize != null && overrideGridSize > 0) {
      cols = overrideGridSize;
    } else if (screenWidth < 360) {
      cols = 8;
    } else if (screenWidth < 400) {
      cols = 9;
    } else if (screenWidth < 480) {
      cols = 10;
    } else if (screenWidth < 600) {
      cols = 12;
    } else {
      cols = 14;
    }
    final int rows = cols;

    final usableWidth = max(240.0, screenWidth - boardPadding * 2);
    final rawSpacing = (usableWidth / cols).clamp(26.0, 36.0);
    // Balanced, readable arrow stroke (3.5 - 4.8px)
    final thickness = (rawSpacing * 0.13).clamp(3.5, 4.8);
    final head = (thickness * 1.8).clamp(6.8, 8.5);

    return PuzzleConfig(
      gridRows: rows,
      gridColumns: cols,
      cellSpacing: rawSpacing,
      pathThickness: thickness,
      arrowHeadSize: head,
      boardPadding: boardPadding,
      minimumClearance: 8.0,
    );
  }

  /// Calculates the exact screen coordinate for a dot at (row, col).
  (double x, double y) dotPosition(
    int row,
    int col, {
    double boardLeft = 0.0,
    double boardTop = 0.0,
  }) {
    final x = boardLeft + (col + 0.5) * cellSpacing;
    final y = boardTop + (row + 0.5) * cellSpacing;
    return (x, y);
  }
}
