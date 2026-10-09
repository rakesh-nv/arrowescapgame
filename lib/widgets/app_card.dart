import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/design_tokens.dart';
import 'pressable_scale.dart';

/// White rounded surface used for grouped content on menu screens.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final String? semanticLabel;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.gradient,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: gradient == null ? Border.all(color: AppColors.cardBorder) : null,
        boxShadow: gradient == null
            ? AppShadows.soft
            : AppShadows.glow(gradient!.colors.first),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: semanticLabel,
      child: card,
    );
  }
}
