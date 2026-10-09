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
    this.cellSpacing = 60.0,
    this.pathThickness = 8.0,
    this.arrowHeadSize = 15.0,
    this.boardPadding = 20.0,
    this.minimumClearance = 16.0,
  });

  /// The clear visual gap between adjacent parallel paths.
  /// visualGap = cellSpacing - pathThickness
  double get visualGap => cellSpacing - pathThickness;

  /// Default configuration for a given grid size (e.g. 10x10).
  factory PuzzleConfig.forGrid(int gridSize) {
    const defaultSpacing = 60.0;
    const defaultThickness = 8.0;
    return PuzzleConfig(
      gridRows: gridSize,
      gridColumns: gridSize,
      cellSpacing: defaultSpacing,
      pathThickness: defaultThickness,
      arrowHeadSize: 15.0,
      boardPadding: 20.0,
      minimumClearance: 16.0,
    );
  }

  /// Responsive factory that dynamically adapts to device dimensions.
  ///
  /// Cell spacing and arrow dimensions are doubled for rich readability.
  factory PuzzleConfig.adaptive({
    required double screenWidth,
    double screenHeight = 800.0,
    int? overrideGridSize,
    double boardPadding = 8.0,
  }) {
    final int cols;
    if (overrideGridSize != null && overrideGridSize > 0) {
      cols = overrideGridSize;
    } else if (screenWidth < 360) {
      cols = 14;
    } else if (screenWidth < 400) {
      cols = 16;
    } else if (screenWidth < 480) {
      cols = 18;
    } else if (screenWidth < 600) {
      cols = 20;
    } else {
      cols = 20;
    }
    final int rows = cols;

    final usableWidth = max(240.0, screenWidth - boardPadding * 2);
    // Double the cell spacing (36px to 80px)
    final rawSpacing = ((usableWidth / cols) * 2.0).clamp(36.0, 80.0);
    final thickness = strokeWidthFor(rawSpacing);
    final head = headSizeFor(rawSpacing);

    return PuzzleConfig(
      gridRows: rows,
      gridColumns: cols,
      cellSpacing: rawSpacing,
      pathThickness: thickness,
      arrowHeadSize: head,
      boardPadding: boardPadding,
      minimumClearance: 16.0,
    );
  }

  /// Arrow body stroke for a cell of [cellSize] scene pixels. Thin (about a
  /// fifth of a cell) so many long parallel paths stay clearly separated:
  /// neighbouring bodies keep ~0.78 of a cell of clear board between them.
  /// Shared by layout and [ArrowPainter] so the two never drift apart.
  static double strokeWidthFor(double cellSize) =>
      (cellSize * 0.22).clamp(6.0, 14.0);

  /// Arrowhead length for a cell of [cellSize]: ~0.6 of a cell, about three
  /// stroke widths, so the direction reads at a glance while the head (its
  /// width is ~1.04× its length) still clears the neighbouring lane.
  static double headSizeFor(double cellSize) =>
      (cellSize * 0.6).clamp(18.0, 40.0);

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
