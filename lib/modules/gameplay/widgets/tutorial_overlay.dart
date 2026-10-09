import 'dart:math' show min;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../widgets/primary_button.dart';

/// Three-step "how to play" card. Each step shows a tiny board diagram so the
/// rule is visible, not just described.
class TutorialOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const TutorialOverlay({super.key, required this.onDismiss});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;

  static const List<String> _steps = [
    AppStrings.tutorialStep1,
    AppStrings.tutorialStep2,
    AppStrings.tutorialStep3,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.base,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _steps.length - 1;
    return FadeTransition(
      opacity: _controller,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                boxShadow: AppShadows.raised,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(AppStrings.howToPlay, style: AppTextStyles.heading),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: AppDurations.base,
                    child: SizedBox(
                      key: ValueKey(_step),
                      width: 168,
                      height: 168,
                      child: CustomPaint(painter: _TutorialDiagram(_step)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: AppDurations.base,
                    child: Text(
                      _steps[_step],
                      key: ValueKey('t$_step'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (isLast) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.zoom_in_rounded,
                            size: 18, color: AppColors.textSecondary),
                        SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            AppStrings.tutorialZoomTip,
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  // Step dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (i) => AnimatedContainer(
                        duration: AppDurations.fast,
                        width: i == _step ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == _step
                              ? AppColors.accentBlue
                              : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      if (!isLast)
                        Expanded(
                          child: TextButton(
                            onPressed: widget.onDismiss,
                            child: const Text(
                              AppStrings.skip,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: isLast ? AppStrings.gotIt : AppStrings.next,
                          onTap: _nextStep,
                          icon: isLast
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 4×4 dot board illustrating one rule per step.
class _TutorialDiagram extends CustomPainter {
  final int step;

  const _TutorialDiagram(this.step);

  static const int _n = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _n;
    Offset c(int r, int col) => Offset((col + 0.5) * cell, (r + 0.5) * cell);

    final dot = Paint()..color = AppColors.navyDark.withValues(alpha: 0.18);
    for (var r = 0; r < _n; r++) {
      for (var col = 0; col < _n; col++) {
        canvas.drawCircle(c(r, col), 3, dot);
      }
    }

    void arrow(List<(int, int)> pts, Color color) {
      final p = Paint()
        ..color = color
        ..strokeWidth = cell * 0.22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(c(pts[0].$1, pts[0].$2).dx, c(pts[0].$1, pts[0].$2).dy);
      for (final q in pts.skip(1)) {
        final o = c(q.$1, q.$2);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
      // Arrowhead in the direction of the last segment.
      final a = c(pts[pts.length - 2].$1, pts[pts.length - 2].$2);
      final b = c(pts.last.$1, pts.last.$2);
      final dir = (b - a) / (b - a).distance;
      final tip = b + dir * cell * 0.38;
      final normal = Offset(-dir.dy, dir.dx);
      final hs = cell * 0.34;
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - dir * hs + normal * hs * 0.6).dx,
            (tip - dir * hs + normal * hs * 0.6).dy)
        ..lineTo((tip - dir * hs - normal * hs * 0.6).dx,
            (tip - dir * hs - normal * hs * 0.6).dy)
        ..close();
      canvas.drawPath(head, Paint()..color = color);
    }

    void lane(Offset from, Offset to, Color color) {
      final p = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = cell * 0.12
        ..strokeCap = StrokeCap.round;
      const dash = 6.0;
      final total = (to - from).distance;
      final dir = (to - from) / total;
      for (var d = 0.0; d < total; d += dash * 2) {
        canvas.drawLine(from + dir * d, from + dir * min(d + dash, total), p);
      }
    }

    switch (step) {
      case 0:
        // A clear arrow with its open lane to the right edge.
        lane(c(1, 2) + Offset(cell * 0.5, 0), Offset(size.width, c(1, 2).dy),
            AppColors.success);
        arrow([(2, 0), (1, 0), (1, 1), (1, 2)], AppColors.accentBlue);
        arrow([(3, 1), (3, 2), (2, 2), (2, 3)], AppColors.navyDark);
      case 1:
        // The upward arrow is blocked by the horizontal one above it.
        arrow([(3, 1), (2, 1)], Colors.redAccent);
        lane(c(2, 1) - Offset(0, cell * 0.5), c(1, 1), Colors.redAccent);
        arrow([(1, 0), (1, 1), (1, 2)], AppColors.navyDark);
        final cross = Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        final x = c(1, 1) + Offset(cell * 0.32, cell * 0.38);
        canvas.drawLine(x - const Offset(6, 6), x + const Offset(6, 6), cross);
        canvas.drawLine(x - const Offset(6, -6), x + const Offset(6, -6), cross);
      default:
        // Board almost clear: the last arrow escapes.
        lane(c(2, 3) + Offset(cell * 0.5, 0), Offset(size.width, c(2, 3).dy),
            AppColors.success);
        arrow([(3, 1), (2, 1), (2, 2), (2, 3)], AppColors.success);
    }
  }

  @override
  bool shouldRepaint(_TutorialDiagram oldDelegate) => oldDelegate.step != step;
}
