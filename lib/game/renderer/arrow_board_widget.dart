import 'package:flutter/material.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/theme_model.dart';
import 'arrow_widget.dart';

/// The main puzzle board widget.
///
/// Renders a clean square board with all continuous snake arrows.
/// - No visible grid; logical cells are used only for paths and hit testing
/// - Cell-accurate tap detection across the entire continuous snake
/// - Responsive square board fitting available dimensions
class ArrowBoardWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.maxWidth.clamp(
          0.0,
          constraints.maxHeight,
        );
        final cellSize = boardSize / gridSize;

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final pos = details.localPosition;
              final col = (pos.dx / cellSize).floor();
              final row = (pos.dy / cellSize).floor();

              if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
                // Find which active snake arrow occupies this tapped cell
                for (final arrow in arrows) {
                  if (arrow.state != ArrowState.removed &&
                      arrow.state != ArrowState.escaping &&
                      arrow.occupiedCells.contains((row, col))) {
                    onArrowTap(arrow.id);
                    break;
                  }
                }
              }
            },
            child: AnimatedScale(
              scale: isCompleting ? 1.012 : 1.0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
              width: boardSize,
              height: boardSize,
              decoration: BoxDecoration(
                color: theme.isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9), // Light gray/off-white board
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.isDark
                      ? Colors.white.withValues(
                          alpha: isCompleting ? 0.22 : 0.08,
                        )
                      : (isCompleting
                          ? theme.accentColor.withValues(alpha: 0.55)
                          : const Color(0xFFE2E8F0)),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  children: [
                    // Continuous snake arrows
                    ...arrows.map((arrow) {
                      return ArrowWidget(
                        key: ValueKey(arrow.id),
                        arrow: arrow,
                        cellSize: cellSize,
                        gridSize: gridSize,
                        theme: theme,
                        isHinted: arrow.id == hintedArrowId,
                      );
                    }),
                  ],
                ),
              ),
              ),
            ),
            ),
        );
      },
    );
  }
}
