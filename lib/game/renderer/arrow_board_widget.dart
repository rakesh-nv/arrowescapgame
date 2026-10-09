import 'dart:math' show cos, max, min, pi, sin;

import 'package:flutter/material.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/theme_model.dart';
import '../config/puzzle_config.dart';
import 'arrow_widget.dart';

/// The main puzzle board widget.
///
/// - The whole board is fitted to the available space (any grid size).
/// - Pinch-to-zoom and drag-to-pan via [InteractiveViewer], bounded so the
///   board cannot be lost off-screen; a recenter chip appears once moved.
/// - Cell-accurate tap detection: taps are converted to scene coordinates
///   with the viewer's transform before the grid hit-test.
class ArrowBoardWidget extends StatefulWidget {
  final List<ArrowModel> arrows;
  final int gridSize;
  final ThemeModel theme;
  final String? hintedArrowId;
  final String? blockerArrowId;
  final Set<String> newlyAvailableArrowIds;
  final bool hasEscapeInProgress;
  final void Function(String arrowId) onArrowTap;
  final bool isCompleting;

  /// Silhouette cells (the picture the arrows form). The view is framed on
  /// this picture, and dots outside it are dimmed.
  final Set<(int, int)> shapeCells;

  const ArrowBoardWidget({
    super.key,
    required this.arrows,
    required this.gridSize,
    required this.theme,
    required this.onArrowTap,
    this.hintedArrowId,
    this.blockerArrowId,
    this.newlyAvailableArrowIds = const {},
    this.hasEscapeInProgress = false,
    this.isCompleting = false,
    this.shapeCells = const {},
  });

  /// Share of the available area the fitted board fills.
  static const double fitFraction = 0.96;

  /// How far the player can zoom out, as a fraction of the fitted size.
  static const double minZoomFraction = 0.5;

  @override
  State<ArrowBoardWidget> createState() => _ArrowBoardWidgetState();
}

class _ArrowBoardWidgetState extends State<ArrowBoardWidget>
    with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final AnimationController _recenter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Animation<Matrix4>? _recenterTween;

  Matrix4? _fitMatrix;
  double _fitScale = 1;
  Size? _fitForSize;
  double? _fitForGrid;

  /// Scene rectangle the view is framed on: the silhouette (or all arrows)
  /// plus half a cell, so the picture fills the play area.
  Rect _focus = Rect.zero;
  bool _suppressListener = false;
  bool _offFit = false;

  /// On-screen cell size below which an ambiguous tap magnifies the board
  /// instead of guessing which neighbouring arrow was meant.
  static const double _comfortCell = 22;

  /// Radius of the fingertip area sampled when resolving a tap.
  static const double _fingerRadius = 6;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransformChanged);
    _recenter.addListener(() {
      final tween = _recenterTween;
      if (tween != null) _tc.value = tween.value;
    });
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    _recenter.dispose();
    _tc.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ArrowBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gridSize != widget.gridSize ||
        !identical(oldWidget.shapeCells, widget.shapeCells)) {
      _fitMatrix = null;
      _offFit = false;
    }
  }

  void _onTransformChanged() {
    if (_suppressListener || _fitMatrix == null) return;
    _applyClamp();
    final off = !_isNearFit(_tc.value);
    if (off != _offFit) setState(() => _offFit = off);
  }

  /// Scene rectangle covering the picture: the silhouette cells, or every
  /// arrow cell when the level has no silhouette, plus half a cell.
  Rect _focusRect(double cellSize) {
    Iterable<(int, int)> cells = widget.shapeCells;
    if (cells.isEmpty) {
      cells = [for (final a in widget.arrows) ...a.points];
    }
    if (cells.isEmpty) {
      final g = cellSize * widget.gridSize;
      return Rect.fromLTWH(0, 0, g, g);
    }
    var minR = widget.gridSize, maxR = 0, minC = widget.gridSize, maxC = 0;
    for (final (r, c) in cells) {
      minR = min(minR, r);
      maxR = max(maxR, r);
      minC = min(minC, c);
      maxC = max(maxC, c);
    }
    return Rect.fromLTRB(
      (minC - 0.5) * cellSize,
      (minR - 0.5) * cellSize,
      (maxC + 1.5) * cellSize,
      (maxR + 1.5) * cellSize,
    );
  }

  /// Keeps the picture on screen at every zoom level: centred on an axis
  /// where it is smaller than the viewport, otherwise pannable edge to edge
  /// plus a small margin. Done here (not via boundaryMargin, which is fixed
  /// in scene units) so the limits follow the current scale.
  void _applyClamp() {
    final size = _fitForSize;
    if (size == null || _focus.isEmpty) return;
    final m = _tc.value;
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();

    double clampAxis(double offset, double start, double extent, double view) {
      final content = extent * scale;
      // Screen position of the focus rect's leading edge for this offset.
      final lead = offset + start * scale;
      final wanted = content <= view
          ? (view - content) / 2
          : lead.clamp(view - content - 24.0, 24.0);
      return offset + (wanted - lead);
    }

    final tx = clampAxis(t.x, _focus.left, _focus.width, size.width);
    final ty = clampAxis(t.y, _focus.top, _focus.height, size.height);
    if ((tx - t.x).abs() < 0.01 && (ty - t.y).abs() < 0.01) return;
    _suppressListener = true;
    _tc.value = m.clone()..setTranslationRaw(tx, ty, t.z);
    _suppressListener = false;
  }

  bool _isNearFit(Matrix4 m) {
    final fit = _fitMatrix!;
    final scale = m.getMaxScaleOnAxis();
    final dx = m.getTranslation().x - fit.getTranslation().x;
    final dy = m.getTranslation().y - fit.getTranslation().y;
    return (scale / _fitScale - 1).abs() < 0.02 && dx.abs() < 6 && dy.abs() < 6;
  }

  /// Centre and fit the picture. Refitted when the available area changes
  /// (rotation, banner loading) unless the player has zoomed or panned.
  void _updateFit(BoxConstraints constraints, double gridPx, double cellSize) {
    final size = constraints.biggest;
    if (_fitMatrix != null && size == _fitForSize && gridPx == _fitForGrid) {
      return;
    }
    final keepUserView = _fitMatrix != null && _offFit;
    _fitForSize = size;
    _fitForGrid = gridPx;
    _focus = _focusRect(cellSize);

    final fit =
        min(size.width / _focus.width, size.height / _focus.height) *
        ArrowBoardWidget.fitFraction;
    final tx = size.width / 2 - _focus.center.dx * fit;
    final ty = size.height / 2 - _focus.center.dy * fit;
    _fitScale = fit;
    // Uniform scale on all three axes: InteractiveViewer reads the current
    // zoom with getMaxScaleOnAxis(), so an unscaled z (1.0) would make it
    // think a shrunken board is at 1× and break pinch/min/max handling.
    _fitMatrix = _scaleTranslate(fit, tx, ty);

    if (!keepUserView) {
      _suppressListener = true;
      _tc.value = _fitMatrix!.clone();
      _suppressListener = false;
      _offFit = false;
    } else {
      // The viewport changed under a zoomed view: keep the board reachable.
      _applyClamp();
    }
  }

  static Matrix4 _scaleTranslate(double s, double tx, double ty) => Matrix4(
    s,
    0,
    0,
    0, //
    0,
    s,
    0,
    0, //
    0,
    0,
    s,
    0, //
    tx,
    ty,
    0,
    1,
  );

  void _animateTo(Matrix4 target) {
    _recenterTween = Matrix4Tween(
      begin: _tc.value.clone(),
      end: target,
    ).animate(CurvedAnimation(parent: _recenter, curve: Curves.easeOutCubic));
    _recenter.forward(from: 0);
  }

  void _recenterBoard() {
    if (_fitMatrix == null) return;
    _animateTo(_fitMatrix!);
  }

  /// The playable arrow owning scene cell (row, col), if any.
  String? _arrowAt(int row, int col) {
    if (row < 0 ||
        row >= widget.gridSize ||
        col < 0 ||
        col >= widget.gridSize) {
      return null;
    }
    for (final arrow in widget.arrows) {
      if (arrow.state != ArrowState.removed &&
          arrow.state != ArrowState.escaping &&
          arrow.occupiedCells.contains((row, col))) {
        return arrow.id;
      }
    }
    return null;
  }

  /// Resolves a tap. The fingertip area is sampled: when at least 70% of it
  /// lies on one arrow, that arrow is tapped, whatever the zoom. When the
  /// touch is split between arrows while cells are small on screen, the
  /// board magnifies around the finger instead of guessing, so a mis-tap
  /// never costs a life.
  void _handleTap(TapUpDetails details, double cellSize, double maxScale) {
    final p = details.localPosition;
    final scale = _tc.value.getMaxScaleOnAxis();

    String? ownerAt(Offset screen) {
      final s = _tc.toScene(screen);
      return _arrowAt((s.dy / cellSize).floor(), (s.dx / cellSize).floor());
    }

    // Centre-weighted samples of the fingertip: the centre counts twice.
    final centre = ownerAt(p);
    final hits = <String, int>{};
    var samples = 2;
    if (centre != null) hits[centre] = 2;
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      for (final r in const [_fingerRadius * 0.5, _fingerRadius]) {
        samples++;
        final id = ownerAt(p + Offset(cos(a) * r, sin(a) * r));
        if (id != null) hits[id] = (hits[id] ?? 0) + 1;
      }
    }
    if (hits.isEmpty) return;
    final best = hits.entries.reduce((a, b) => b.value > a.value ? b : a);
    // A clear majority of the fingertip on one arrow selects it at any zoom.
    if (best.value >= samples * 0.7) {
      widget.onArrowTap(best.key);
      return;
    }
    if (cellSize * scale < _comfortCell && scale < maxScale - 1e-6) {
      // Magnify so cells are comfortably large, keeping the touched point
      // under the finger.
      final target = min(maxScale, max(scale * 1.6, 34 / cellSize));
      final scene = _tc.toScene(p);
      _animateTo(
        _scaleTranslate(
          target,
          p.dx - scene.dx * target,
          p.dy - scene.dy * target,
        ),
      );
      return;
    }
    if (centre != null) widget.onArrowTap(centre);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final config = PuzzleConfig.adaptive(
          screenWidth: constraints.maxWidth,
          screenHeight: constraints.maxHeight,
          overrideGridSize: widget.gridSize,
        );
        final cellSize = config.cellSpacing;
        final gridPx = cellSize * widget.gridSize;

        _updateFit(constraints, gridPx, cellSize);

        // Zoom range: out to half the fitted size (the board stays centred),
        // in to at least 2.5× the fit, or until a cell is ~110 px wide.
        final maxScale = max(_fitScale * 2.5, 110 / cellSize);

        return Stack(
          children: [
            Positioned.fill(
              // GestureDetector OUTSIDE InteractiveViewer so taps are not
              // swallowed by the pan/zoom recogniser.
              child: GestureDetector(
                onTapUp: (details) => _handleTap(details, cellSize, maxScale),
                child: InteractiveViewer(
                  transformationController: _tc,
                  // Pan limits are applied in _applyClamp, scale-aware.
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: _fitScale * ArrowBoardWidget.minZoomFraction,
                  maxScale: maxScale,
                  constrained: false,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.96 + 0.04 * t,
                        child: child,
                      ),
                    ),
                    child: AnimatedScale(
                      scale: widget.isCompleting ? 1.012 : 1.0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      // Own layer: pinch/pan only re-composites the board
                      // instead of repainting every arrow each frame.
                      child: RepaintBoundary(
                        child: SizedBox(
                          width: gridPx,
                          height: gridPx,
                          child: Stack(
                            children: [
                              // Rangoli / Kolam dot grid
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _DotGridPainter(
                                      gridSize: widget.gridSize,
                                      cellSize: cellSize,
                                      dotColor: widget.theme.textColor
                                          .withValues(alpha: 0.32),
                                      shapeCells: widget.shapeCells,
                                    ),
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
                                  isBlocker: arrow.id == widget.blockerArrowId,
                                  origin: Offset.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _offFit
                    ? _RecenterChip(
                        key: const ValueKey('recenter'),
                        dark: widget.theme.isDark,
                        onTap: _recenterBoard,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecenterChip extends StatelessWidget {
  final bool dark;
  final VoidCallback onTap;

  const _RecenterChip({super.key, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : const Color(0xFF1A2340);
    return Semantics(
      button: true,
      label: 'Fit board to screen',
      child: Material(
        color: dark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.95),
        shape: const StadiumBorder(),
        elevation: dark ? 0 : 2,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fit_screen_rounded, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  'Fit',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the Rangoli / Kolam dot grid. When the level has a silhouette,
/// dots inside the picture keep full strength and dots outside it are dimmed,
/// so the shape stays readable without painting anything behind the arrows.
class _DotGridPainter extends CustomPainter {
  final int gridSize;
  final double cellSize;
  final Color dotColor;
  final Set<(int, int)> shapeCells;

  const _DotGridPainter({
    required this.gridSize,
    required this.cellSize,
    required this.dotColor,
    this.shapeCells = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hasShape = shapeCells.isNotEmpty;

    final inside = Paint()
      ..color = dotColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    final outside = Paint()
      ..color = dotColor.withValues(alpha: dotColor.a * 0.4)
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // Dots stay narrower than the thin arrow stroke, so a dot under an arrow
    // is fully covered and never peeks out as a grey halo.
    final dotRadius = min(
      (cellSize * 0.06).clamp(2.0, 4.0),
      PuzzleConfig.strokeWidthFor(cellSize) * 0.4,
    );

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final cx = (c + 0.5) * cellSize;
        final cy = (r + 0.5) * cellSize;
        final paint = !hasShape || shapeCells.contains((r, c))
            ? inside
            : outside;
        canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.gridSize != gridSize ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.dotColor != dotColor ||
      !identical(oldDelegate.shapeCells, shapeCells);
}
