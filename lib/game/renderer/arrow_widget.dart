import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/theme_model.dart';
import 'arrow_collision.dart';
import 'arrow_painter.dart';

/// An animated snake arrow widget on the game board.
///
/// Handles:
/// - Crash run when blocked: travels along its path, stops where it touches
///   another arrow, turns red on impact, then slides back
/// - Immediate snake-style escape with fluid acceleration
/// - Glow pulse when hinted or selected
class ArrowWidget extends StatefulWidget {
  final ArrowModel arrow;
  final double cellSize;
  final int gridSize;
  final ThemeModel theme;
  final bool isHinted;

  /// This arrow just blocked a tap; it pulses in the error colour.
  final bool isBlocker;

  /// Top-left offset of the compact visual grid within the touch board.
  final Offset origin;

  /// Blocked arrows: how far (scene px of snake shift) the arrow travels
  /// before it touches an obstacle, and how long that takes. See
  /// [ArrowCollision.crashTravel] and [CrashTiming].
  final double crashTravel;
  final int crashTravelMs;

  const ArrowWidget({
    super.key,
    required this.arrow,
    required this.cellSize,
    required this.gridSize,
    required this.theme,
    required this.isHinted,
    this.isBlocker = false,
    this.origin = Offset.zero,
    this.crashTravel = 0,
    this.crashTravelMs = 110,
  });

  @override
  State<ArrowWidget> createState() => ArrowWidgetState();
}

class ArrowWidgetState extends State<ArrowWidget>
    with TickerProviderStateMixin {
  late AnimationController _crashController;
  late AnimationController _escapeController;
  late AnimationController _glowController;

  late Animation<double> _glowAnim;
  late ArrowMotionPath _motionPath;

  bool _isCrashing = false;
  bool _isEscaping = false;

  @override
  void initState() {
    super.initState();

    _crashController = AnimationController(vsync: this);

    _escapeController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: AppConstants.arrowFlightDurationForLength(
          widget.arrow.length,
        ),
      ),
    );

    // Runs only while the arrow is highlighted; an idle board does not tick.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncGlow();

    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _motionPath = ArrowMotionPath.build(
      arrow: widget.arrow,
      cellSize: widget.cellSize,
      origin: widget.origin,
    );

    // The board draws idle arrows in one shared layer and only gives an
    // arrow its own widget once it becomes active, so the widget may be
    // created already escaping or blocked.
    if (widget.arrow.state == ArrowState.escaping) _playEscape();
    if (widget.arrow.state == ArrowState.blocked) _playCrash();
  }

  @override
  void dispose() {
    _crashController.dispose();
    _escapeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ArrowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.cellSize != widget.cellSize ||
        oldWidget.arrow.points != widget.arrow.points ||
        oldWidget.arrow.exitDirection != widget.arrow.exitDirection ||
        oldWidget.origin != widget.origin) {
      _motionPath = ArrowMotionPath.build(
        arrow: widget.arrow,
        cellSize: widget.cellSize,
        origin: widget.origin,
      );
    }

    if (oldWidget.isHinted != widget.isHinted ||
        oldWidget.isBlocker != widget.isBlocker) {
      _syncGlow();
    }

    final newState = widget.arrow.state;
    final oldState = oldWidget.arrow.state;

    if (newState == ArrowState.blocked && oldState != ArrowState.blocked) {
      _playCrash();
    }

    if (newState == ArrowState.escaping && oldState != ArrowState.escaping) {
      _playEscape();
    }

    // Escape cancelled (undo / reset restored the arrow): drop the run.
    if (newState != ArrowState.escaping &&
        newState != ArrowState.removed &&
        _isEscaping) {
      _escapeController.reset();
      _isEscaping = false;
    }

    if (newState == ArrowState.normal && _isCrashing) {
      _crashController.reset();
      _isCrashing = false;
    }
  }

  bool get _highlighted =>
      widget.isHinted ||
      widget.isBlocker ||
      widget.arrow.state == ArrowState.selected;

  /// The hinted arrow is drawn solid blue (no pulse) until it is moved.
  bool get _hintBlue =>
      widget.isHinted && widget.arrow.state == ArrowState.normal;

  void _syncGlow() {
    if (_highlighted && !_hintBlue) {
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
    } else if (_glowController.isAnimating || _glowController.value != 0) {
      _glowController
        ..stop()
        ..value = 0;
    }
  }

  int get _crashTotalMs =>
      widget.crashTravelMs + CrashTiming.impactHoldMs + CrashTiming.returnMs;

  void _playCrash() {
    _isCrashing = true;
    _crashController
      ..duration = Duration(milliseconds: _crashTotalMs)
      ..forward(from: 0).then((_) {
        if (mounted) setState(() => _isCrashing = false);
      });
  }

  /// Elapsed crash time in ms.
  double get _crashMs => _crashController.value * _crashTotalMs;

  /// True once the arrow has reached the obstacle.
  bool get _crashImpacted => _isCrashing && _crashMs >= widget.crashTravelMs;

  /// Snake shift during a crash run: accelerate to the contact point, stop
  /// dead there with a small recoil, then glide back to rest.
  double _crashShift() {
    final travel = widget.crashTravel;
    final ms = _crashMs;
    final t1 = widget.crashTravelMs.toDouble();
    if (ms < t1) return travel * Curves.easeInQuad.transform(ms / t1);
    final t2 = t1 + CrashTiming.impactHoldMs;
    if (ms < t2) {
      final u = (ms - t1) / CrashTiming.impactHoldMs;
      final recoil = math.min(travel, widget.cellSize * 0.06);
      return travel - recoil * math.sin(math.pi * u);
    }
    final u = ((ms - t2) / CrashTiming.returnMs).clamp(0.0, 1.0);
    return travel * (1 - Curves.easeOutCubic.transform(u));
  }

  void _playEscape() {
    _isEscaping = true;
    // When the run finishes the arrow stays at its final (off-board, faded)
    // frame until the engine marks it removed. Clearing `_isEscaping` here
    // would redraw it, for a frame, at its original cells in the escaping
    // accent colour: the "blue ghost" after an arrow leaves the board.
    _escapeController.forward(from: 0);
  }

  Color _getArrowColor() {
    final theme = widget.theme;
    switch (widget.arrow.state) {
      case ArrowState.selected:
        return theme.accentColor;
      case ArrowState.blocked:
        // Red from the moment it touches the obstacle, not before.
        return _crashImpacted || !_isCrashing
            ? Colors.redAccent
            : theme.arrowColorFor(widget.arrow.id);
      case ArrowState.escaping:
        return theme.accentColor;
      case ArrowState.removed:
        return Colors.transparent;
      case ArrowState.normal:
        return theme.arrowColorFor(widget.arrow.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arrow = widget.arrow;
    if (arrow.state == ArrowState.removed) return const SizedBox.shrink();

    final cs = widget.cellSize;
    final hintBlue = _hintBlue && !widget.isBlocker;
    final showGlow = _highlighted;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _crashController,
        _escapeController,
        _glowController,
      ]),
      builder: (context, child) {
        final color = widget.isBlocker && arrow.state == ArrowState.normal
            ? Color.lerp(
                widget.theme.arrowColorFor(arrow.id),
                Colors.redAccent,
                0.7,
              )!
            : hintBlue
            ? (widget.theme.isDark
                  ? AppColors.accentBlueLight
                  : AppColors.accentBlue)
            : _getArrowColor();
        // Blocked (after impact), blocker and hint cues stay one solid
        // colour, head included.
        final solid =
            widget.isBlocker ||
            (arrow.state == ArrowState.blocked && color == Colors.redAccent) ||
            hintBlue;
        final headColor = solid ? color : widget.theme.headColorFor(color);

        // Crash run: the snake travels along its own path, exactly as far as
        // the shapes allow (computed by ArrowCollision), then back.
        final crashShift = _isCrashing ? _crashShift() : null;

        // Starts moving immediately with clean quadratic acceleration
        final escapeProgress = _isEscaping
            ? Curves.easeInQuad.transform(_escapeController.value)
            : null;
        final visualOpacity = escapeProgress == null
            ? (widget.isBlocker
                  ? 0.6 + 0.4 * _glowController.value
                  : (showGlow && !hintBlue ? _glowAnim.value : 1.0))
            : 1.0 - (escapeProgress - 0.75).clamp(0.0, 0.25) / 0.25 * 0.7;

        // Own layer per arrow: an escaping or glowing arrow repaints alone
        // instead of forcing every arrow on a large board to repaint.
        return Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ArrowPainter(
                  arrow: arrow,
                  cellSize: cs,
                  bodyColor: color,
                  headColor: headColor,
                  glowColor: widget.isBlocker
                      ? Colors.redAccent
                      : widget.theme.accentColor,
                  showGlow: showGlow,
                  opacity: visualOpacity,
                  snakeProgress: escapeProgress,
                  snakeShift: crashShift,
                  motionPath: _motionPath,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
