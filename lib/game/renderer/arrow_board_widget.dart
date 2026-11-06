import 'dart:async' show Timer;
import 'dart:math' show cos, max, min, pi, sin;

import 'package:flutter/material.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/theme_model.dart';
import '../config/puzzle_config.dart';
import 'arrow_collision.dart';
import 'arrow_painter.dart';
import 'arrow_widget.dart';

/// The main puzzle board widget.
///
/// - The whole board is fitted to the available space (any grid size).
/// - Pinch-to-zoom and one-finger drag-to-pan via [InteractiveViewer]. The
///   pan is unbounded in every direction, so the board feels endless; a Fit
///   chip appears once moved. No dots or grid lines are drawn.
/// - Cell-accurate tap detection: taps are converted to scene coordinates
///   with the viewer's transform before the grid hit-test. A drag never
///   counts as a tap, and a touch that lands while the board is still
///   moving (fling) only stops being a tap, so panning never moves an arrow.
class ArrowBoardWidget extends StatefulWidget {
  final List<ArrowModel> arrows;
  final int gridSize;
  final ThemeModel theme;
  final String? hintedArrowId;

  /// Bumped each time the player asks for a hint; the view then glides to
  /// [hintedArrowId] (also when the same arrow is hinted again).
  final int hintRequest;
  final String? blockerArrowId;
  final Set<String> newlyAvailableArrowIds;
  final bool hasEscapeInProgress;
  final void Function(String arrowId) onArrowTap;
  final bool isCompleting;

  /// Silhouette cells (the picture the arrows form). The view is framed on
  /// this picture.
  final Set<(int, int)> shapeCells;

  const ArrowBoardWidget({
    super.key,
    required this.arrows,
    required this.gridSize,
    required this.theme,
    required this.onArrowTap,
    this.hintedArrowId,
    this.hintRequest = 0,
    this.blockerArrowId,
    this.newlyAvailableArrowIds = const {},
    this.hasEscapeInProgress = false,
    this.isCompleting = false,
    this.shapeCells = const {},
  });

  /// Share of the available area the fitted picture fills (its own half-cell
  /// margin keeps arrows off the edge).
  static const double fitFraction = 0.985;

  /// Board background for light themes.
  static const Color lightBoardColor = Color(0xFFFFFFFF);

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

  /// Board motion, used to tell a tap from a touch that interrupts a pan.
  bool _interacting = false;

  /// Runs while the board is moving and for [_settleTime] after its last
  /// movement (inertia after a fling included).
  Timer? _settling;
  bool _moving = false;

  /// Set on pointer down when the board was still moving: the tap that
  /// follows is swallowed instead of moving the arrow under the finger.
  bool _swallowTap = false;

  /// A touch this soon after the board last moved is part of the pan.
  static const Duration _settleTime = Duration(milliseconds: 90);

  /// On-screen cell size below which an ambiguous tap magnifies the board
  /// instead of guessing which neighbouring arrow was meant.
  static const double _comfortCell = 22;

  /// Radius of the fingertip area sampled when resolving a tap.
  static const double _fingerRadius = 6;

  /// Layout of the last build, for moving the view outside build().
  double _cellSize = 0;
  double _maxScale = 1;

  /// Rounded routes of idle arrows, built once per arrow and cell size.
  final Map<String, ArrowMotionPath> _paths = {};
  double? _pathsCellSize;

  ArrowMotionPath _pathFor(ArrowModel arrow, double cellSize) {
    if (_pathsCellSize != cellSize) {
      _paths.clear();
      _pathsCellSize = cellSize;
    }
    return _paths.putIfAbsent(
      arrow.id,
      () => ArrowMotionPath.build(arrow: arrow, cellSize: cellSize),
    );
  }

  /// Crash run of each currently blocked arrow: distance to the contact
  /// point and travel time. Computed once when the arrow becomes blocked.
  final Map<String, (double, int)> _crashRuns = {};
  double? _crashCellSize;

  (double, int) _crashRunFor(ArrowModel arrow, double cellSize) {
    if (_crashCellSize != cellSize) {
      _crashRuns.clear();
      _crashCellSize = cellSize;
    }
    return _crashRuns.putIfAbsent(arrow.id, () {
      final remaining = [
        for (final a in widget.arrows)
          if (a.state != ArrowState.removed) a,
      ];
      final cells =
          ArrowCollision.laneCellsToCollision(
            arrow,
            remaining,
            widget.gridSize,
          ) ??
          1;
      final travel =
          ArrowCollision.crashTravel(
            arrow: arrow,
            remaining: remaining,
            gridSize: widget.gridSize,
            cellSize: cellSize,
          ) ??
          0;
      return (travel, CrashTiming.travelMs(cells));
    });
  }

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
    _settling?.cancel();
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
      _paths.clear();
    }
    final hint = widget.hintedArrowId;
    if (hint != null &&
        (hint != oldWidget.hintedArrowId ||
            widget.hintRequest != oldWidget.hintRequest)) {
      // After this frame's layout, so the fit and cell size are current.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.hintedArrowId == hint) _focusOnArrow(hint);
      });
    }
  }

  /// Glides the view so the whole hinted arrow is centred and readable:
  /// zoomed in until cells are comfortable to tap, but never so far that
  /// part of the arrow is cut off, and never out past the fitted picture.
  void _focusOnArrow(String id) {
    final size = _fitForSize;
    if (_fitMatrix == null || size == null || _cellSize <= 0) return;
    ArrowModel? arrow;
    for (final a in widget.arrows) {
      if (a.id == id) arrow = a;
    }
    if (arrow == null || arrow.points.isEmpty) return;
    final cell = _cellSize;
    var minR = arrow.points.first.$1, maxR = minR;
    var minC = arrow.points.first.$2, maxC = minC;
    for (final (r, c) in arrow.points) {
      minR = min(minR, r);
      maxR = max(maxR, r);
      minC = min(minC, c);
      maxC = max(maxC, c);
    }
    // The arrow's cells plus one cell all round (its head reaches past).
    final rect = Rect.fromLTRB(
      (minC - 1) * cell,
      (minR - 1) * cell,
      (maxC + 2) * cell,
      (maxR + 2) * cell,
    );
    final wholeArrow =
        min(size.width / rect.width, size.height / rect.height) * 0.9;
    final comfortable = 34 / cell;
    final current = _tc.value.getMaxScaleOnAxis();
    final scale = min(
      max(comfortable, current),
      wholeArrow,
    ).clamp(_fitScale, _maxScale);
    _animateTo(
      _scaleTranslate(
        scale,
        size.width / 2 - rect.center.dx * scale,
        size.height / 2 - rect.center.dy * scale,
      ),
    );
  }

  void _onTransformChanged() {
    if (_suppressListener || _fitMatrix == null) return;
    // Two changes within the settle time mean the board is in motion (a
    // drag or a fling coasting); a single jump (Fit, a programmatic move)
    // is not.
    _moving = _settling != null;
    _settling?.cancel();
    _settling = Timer(_settleTime, () {
      _settling = null;
      _moving = false;
    });
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
    }
    // Otherwise the player's own view is kept as it is: the board pans
    // freely and the Fit chip brings it back.
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

  /// Which playable arrow owns each cell, built once per tap (one pass over
  /// the arrows) so the fingertip samples are plain lookups.
  Map<(int, int), String> _tapOwners() => {
    for (final arrow in widget.arrows)
      if (arrow.state != ArrowState.removed &&
          arrow.state != ArrowState.escaping)
        for (final cell in arrow.points) cell: arrow.id,
  };

  /// Resolves a tap. The fingertip area is sampled: when at least 70% of it
  /// lies on one arrow, that arrow is tapped, whatever the zoom. When the
  /// touch is split between arrows while cells are small on screen, the
  /// board magnifies around the finger instead of guessing, so a mis-tap
  /// never costs a life.
  void _onPointerDown(PointerDownEvent _) {
    _swallowTap = _interacting || _recenter.isAnimating || _moving;
  }

  void _handleTap(TapUpDetails details, double cellSize, double maxScale) {
    if (_swallowTap) {
      _swallowTap = false;
      return;
    }
    final p = details.localPosition;
    final scale = _tc.value.getMaxScaleOnAxis();
    final owners = _tapOwners();

    String? ownerAt(Offset screen) {
      final s = _tc.toScene(screen);
      return owners[((s.dy / cellSize).floor(), (s.dx / cellSize).floor())];
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
        _cellSize = cellSize;
        _maxScale = maxScale;

        final idle = <ArrowModel>[];
        final active = <ArrowModel>[];
        // Forget crash runs of arrows that are no longer blocked.
        _crashRuns.removeWhere(
          (id, _) => !widget.arrows.any(
            (a) => a.id == id && a.state == ArrowState.blocked,
          ),
        );
        for (final arrow in widget.arrows) {
          if (arrow.state == ArrowState.removed) continue;
          final animated =
              arrow.state != ArrowState.normal ||
              arrow.id == widget.hintedArrowId ||
              arrow.id == widget.blockerArrowId;
          (animated ? active : idle).add(arrow);
        }

        return Stack(
          children: [
            // Light themes: plain pure-white board across the whole viewport,
            // so it stays white wherever the board is zoomed or panned. Dark
            // themes keep their own background (their arrows are light).
            if (!widget.theme.isDark)
              const Positioned.fill(
                child: ColoredBox(color: ArrowBoardWidget.lightBoardColor),
              ),
            Positioned.fill(
              // GestureDetector OUTSIDE InteractiveViewer so taps are not
              // swallowed by the pan/zoom recogniser; a drag past the touch
              // slop is won by the viewer and never reaches onTapUp.
              child: Listener(
                onPointerDown: _onPointerDown,
                child: GestureDetector(
                  onTapUp: (details) => _handleTap(details, cellSize, maxScale),
                  child: InteractiveViewer(
                    transformationController: _tc,
                    // One finger pans, two fingers pinch; no pan limits in any
                    // direction (the Fit chip recentres).
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    onInteractionStart: (_) => _interacting = true,
                    onInteractionEnd: (_) => _interacting = false,
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
                                // Theme board panel (dark themes that set
                                // one; light themes stay pure white)
                                if (widget.theme.isDark &&
                                    widget.theme.boardColor != null)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: widget.theme.boardColor,
                                        borderRadius: BorderRadius.circular(
                                          cellSize * 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Every idle arrow in one layer: a board of
                                // ~90 arrows is one picture, not 90 layers
                                // with 270 animation controllers.
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      // Up to ~200 long arrows on the largest
                                      // boards; changes only once per move.
                                      isComplex: true,
                                      painter: _IdleArrowsPainter(
                                        arrows: idle,
                                        cellSize: cellSize,
                                        theme: widget.theme,
                                        pathFor: (a) => _pathFor(a, cellSize),
                                      ),
                                    ),
                                  ),
                                ),
                                // Arrows that animate (escaping, blocked,
                                // hinted, or the blocker just shown) get their
                                // own widget and layer.
                                ...active.map(
                                  (arrow) => ArrowWidget(
                                    key: ValueKey(arrow.id),
                                    arrow: arrow,
                                    cellSize: cellSize,
                                    gridSize: widget.gridSize,
                                    theme: widget.theme,
                                    isHinted: arrow.id == widget.hintedArrowId,
                                    isBlocker:
                                        arrow.id == widget.blockerArrowId,
                                    origin: Offset.zero,
                                    crashTravel:
                                        arrow.state == ArrowState.blocked
                                        ? _crashRunFor(arrow, cellSize).$1
                                        : 0,
                                    crashTravelMs:
                                        arrow.state == ArrowState.blocked
                                        ? _crashRunFor(arrow, cellSize).$2
                                        : 110,
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

/// Paints every idle arrow (not animating, not highlighted) into one picture,
/// with exactly the same drawing as [ArrowPainter]. Repaints only when the
/// set of idle arrows changes, i.e. once per move.
class _IdleArrowsPainter extends CustomPainter {
  final List<ArrowModel> arrows;
  final double cellSize;
  final ThemeModel theme;
  final ArrowMotionPath Function(ArrowModel) pathFor;

  _IdleArrowsPainter({
    required this.arrows,
    required this.cellSize,
    required this.theme,
    required this.pathFor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in arrows) {
      final body = theme.arrowColorFor(arrow.id);
      ArrowPainter(
        arrow: arrow,
        cellSize: cellSize,
        bodyColor: body,
        headColor: theme.headColorFor(body),
        glowColor: theme.accentColor,
        motionPath: pathFor(arrow),
      ).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_IdleArrowsPainter old) {
    if (old.cellSize != cellSize ||
        old.theme.id != theme.id ||
        old.arrows.length != arrows.length) {
      return true;
    }
    for (var i = 0; i < arrows.length; i++) {
      if (old.arrows[i].id != arrows[i].id) return true;
    }
    return false;
  }
}
