import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/arrow_model.dart';
import '../../data/models/arrow_state.dart';
import '../../data/models/theme_model.dart';
import 'arrow_painter.dart';

/// An animated snake arrow widget on the game board.
///
/// Handles:
/// - Smooth blocked bump animation in exit direction
/// - Immediate snake-style escape with fluid acceleration
/// - Glow pulse when hinted or selected
class ArrowWidget extends StatefulWidget {
  final ArrowModel arrow;
  final double cellSize;
  final int gridSize;
  final ThemeModel theme;
  final bool isHinted;
  /// Top-left offset of the compact visual grid within the touch board.
  final Offset origin;

  const ArrowWidget({
    super.key,
    required this.arrow,
    required this.cellSize,
    required this.gridSize,
    required this.theme,
    required this.isHinted,
    this.origin = Offset.zero,
  });

  @override
  State<ArrowWidget> createState() => ArrowWidgetState();
}

class ArrowWidgetState extends State<ArrowWidget>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _escapeController;
  late AnimationController _glowController;

  late Animation<double> _shakeAnim;
  late Animation<double> _glowAnim;
  late ArrowMotionPath _motionPath;

  bool _isShaking = false;
  bool _isEscaping = false;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppConstants.blockedAnimDurationMs),
    );

    _escapeController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            AppConstants.arrowFlightDurationForLength(widget.arrow.length),
      ),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Subtle obstacle bump in exit direction
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 3.5), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 3.5, end: -1.0), weight: 3),
      TweenSequenceItem(tween: Tween(begin: -1.0, end: 0.0), weight: 3),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOutQuad,
    ));

    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _motionPath = ArrowMotionPath.build(
      arrow: widget.arrow,
      cellSize: widget.cellSize,
      origin: widget.origin,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
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

    final newState = widget.arrow.state;
    final oldState = oldWidget.arrow.state;

    if (newState == ArrowState.blocked && oldState != ArrowState.blocked) {
      _playShake();
    }

    if (newState == ArrowState.escaping && oldState != ArrowState.escaping) {
      _playEscape();
    }

    if (newState == ArrowState.normal && !widget.isHinted) {
      _shakeController.reset();
    }
  }

  void _playShake() {
    _isShaking = true;
    _shakeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _isShaking = false);
      }
    });
  }

  void _playEscape() {
    _isEscaping = true;
    _escapeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _isEscaping = false);
      }
    });
  }

  Color _getArrowColor() {
    final theme = widget.theme;
    switch (widget.arrow.state) {
      case ArrowState.selected:
        return theme.accentColor;
      case ArrowState.blocked:
        return Colors.redAccent;
      case ArrowState.escaping:
        return theme.accentColor;
      case ArrowState.removed:
        return Colors.transparent;
      case ArrowState.normal:
        return theme.arrowColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final arrow = widget.arrow;
    if (arrow.state == ArrowState.removed) return const SizedBox.shrink();

    final cs = widget.cellSize;
    final color = _getArrowColor();
    final showGlow = widget.isHinted || arrow.state == ArrowState.selected;
    final dir = arrow.exitDirection;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _shakeController,
        _escapeController,
        _glowController,
      ]),
      builder: (context, child) {
        // Compute subtle bump offset in direction of travel if blocked
        double shakeX = 0, shakeY = 0;
        if (_isShaking) {
          shakeX = dir.dCol * _shakeAnim.value;
          shakeY = dir.dRow * _shakeAnim.value;
        }

        // Starts moving immediately with clean quadratic acceleration
        final escapeProgress = _isEscaping
            ? Curves.easeInQuad.transform(_escapeController.value)
            : null;
        final visualOpacity = escapeProgress == null
            ? (showGlow ? _glowAnim.value : 1.0)
            : 1.0 - (escapeProgress - 0.75).clamp(0.0, 0.25) / 0.25 * 0.7;

        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ArrowPainter(
                arrow: arrow,
                cellSize: cs,
                bodyColor: color,
                glowColor: widget.theme.accentColor,
                showGlow: showGlow,
                opacity: visualOpacity,
                snakeProgress: escapeProgress,
                trailProgress: escapeProgress,
                shakeOffset: Offset(shakeX, shakeY),
                motionPath: _motionPath,
              ),
            ),
          ),
        );
      },
    );
  }
}
