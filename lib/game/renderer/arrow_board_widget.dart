import 'dart:math' show min;

import 'package:flutter/material.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/theme_model.dart';
import '../config/puzzle_config.dart';
import 'arrow_widget.dart';

/// The main puzzle board widget.
///
/// Renders arrows on an infinite, pannable, zoomable canvas.
/// - No fixed board border; arrows float on the background.
/// - Pinch-to-zoom and drag-to-pan via [InteractiveViewer].
/// - Cell-accurate tap detection inside the viewport transform —
///   [GestureDetector.localPosition] is already in scene coordinates.
class ArrowBoardWidget extends StatefulWidget {
  final List<ArrowModel> arrows;
  final int gridSize;
  final ThemeModel theme;
  final String? hintedArrowId;
  final Set<String> newlyAvailableArrowIds;
  final bool hasEscapeInProgress;
  final void Function(String arrowId) onArrowTap;
  final bool isCompleting;

  const ArrowBoardWidget({
    super.key,
    required this.arrows,
    required this.gridSize,
    required this.theme,
    required this.onArrowTap,
    this.hintedArrowId,
    this.newlyAvailableArrowIds = const {},
    this.hasEscapeInProgress = false,
    this.isCompleting = false,
  });

  @override
  State<ArrowBoardWidget> createState() => _ArrowBoardWidgetState();
}

class _ArrowBoardWidgetState extends State<ArrowBoardWidget> {
  final TransformationController _tc = TransformationController();
  bool _initialized = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  /// Centre and scale the puzzle to fit ~88% of the viewport on first build.
  void _initTransform(BoxConstraints constraints, double gridPx) {
    if (_initialized) return;
    _initialized = true;

    final fit = min(
          constraints.maxWidth / gridPx,
          constraints.maxHeight / gridPx,
        ) *
        0.88;

    // translate( tx, ty ) * scale( fit ) maps scene origin → screen centre
    final tx = (constraints.maxWidth - gridPx * fit) / 2;
    final ty = (constraints.maxHeight - gridPx * fit) / 2;

    _tc.value = Matrix4(
      fit, 0, 0, 0,
      0, fit, 0, 0,
      0, 0, 1, 0,
      tx, ty, 0, 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final config = PuzzleConfig.adaptive(
        screenWidth: constraints.maxWidth,
        screenHeight: constraints.maxHeight,
        overrideGridSize: widget.gridSize,
      );
      final cellSize = config.cellSpacing;
      final gridPx = cellSize * widget.gridSize;

      _initTransform(constraints, gridPx);

      // GestureDetector OUTSIDE InteractiveViewer so taps are not swallowed
      // by the pan/zoom recogniser. We convert from screen-space to scene-space
      // using _tc.toScene() before doing the grid hit-test.
      return GestureDetector(
        onTapUp: (details) {
          final scene = _tc.toScene(details.localPosition);
          final col = (scene.dx / cellSize).floor();
          final row = (scene.dy / cellSize).floor();

          if (row >= 0 &&
              row < widget.gridSize &&
              col >= 0 &&
              col < widget.gridSize) {
            for (final arrow in widget.arrows) {
              if (arrow.state != ArrowState.removed &&
                  arrow.state != ArrowState.escaping &&
                  arrow.occupiedCells.contains((row, col))) {
                widget.onArrowTap(arrow.id);
                break;
              }
            }
          }
        },
        child: InteractiveViewer(
          transformationController: _tc,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.10,
          maxScale: 10.0,
          constrained: false,
          child: AnimatedScale(
            scale: widget.isCompleting ? 1.012 : 1.0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: gridPx,
              height: gridPx,
              child: Stack(
                children: [
                  // Visible dot grid background (Rangoli / Kolam pattern dots)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DotGridPainter(
                        gridSize: widget.gridSize,
                        cellSize: cellSize,
                        dotColor: widget.theme.textColor.withValues(alpha: 0.32),
                      ),
                    ),
                   ),
                  ...widget.arrows.map(
                    (arrow) => ArrowWidget(
                      key: ValueKey(arrow.id), 
                      arrow: arrow,
                      cellSize: cellSize,
                      gridSize: widget.gridSize,
                      theme: widget.theme,
                      isHinted: arrow.id == widget.hintedArrowId,
                      origin: Offset.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Custom painter that renders the Rangoli / Kolam dot grid.
class _DotGridPainter extends CustomPainter {
  final int gridSize;
  final double cellSize;
  final Color dotColor;

  const _DotGridPainter({
    required this.gridSize,
    required this.cellSize,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final dotRadius = (cellSize * 0.06).clamp(1.8, 2.6);

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final cx = (c + 0.5) * cellSize;
        final cy = (r + 0.5) * cellSize;
        canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.gridSize != gridSize ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.dotColor != dotColor;
}
