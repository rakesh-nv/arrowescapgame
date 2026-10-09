import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Shared shell for every in-game dialog: a scale-in white card with a round
/// icon badge, title, optional message, body and actions. Scrolls instead of
/// overflowing on short screens or large text.
class GameDialog extends StatefulWidget {
  final Widget icon;
  final Widget title;
  final Widget? message;
  final List<Widget> children;

  const GameDialog({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.children = const [],
  });

  @override
  State<GameDialog> createState() => _GameDialogState();
}

class _GameDialogState extends State<GameDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        child: FadeTransition(
          opacity: _controller,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                boxShadow: AppShadows.raised,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl + 4,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.icon,
                    const SizedBox(height: AppSpacing.lg),
                    DefaultTextStyle.merge(
                      style: AppTextStyles.title,
                      textAlign: TextAlign.center,
                      child: widget.title,
                    ),
                    if (widget.message != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      DefaultTextStyle.merge(
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                        child: widget.message!,
                      ),
                    ],
                    if (widget.children.isNotEmpty)
                      const SizedBox(height: AppSpacing.xl - 4),
                    ...widget.children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round tinted icon badge at the top of a [GameDialog].
class DialogIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Gradient? gradient;

  const DialogIcon({
    super.key,
    required this.icon,
    required this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gradient == null ? color.withValues(alpha: 0.13) : null,
        gradient: gradient,
        boxShadow: gradient == null ? null : AppShadows.glow(color),
      ),
      child: Icon(
        icon,
        color: gradient == null ? color : Colors.white,
        size: 40,
      ),
    );
  }
}
