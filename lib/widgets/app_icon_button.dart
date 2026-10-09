import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/design_tokens.dart';
import 'pressable_scale.dart';

/// Square 48 dp icon button used in top bars. [onDark] adapts it to dark
/// game themes.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool onDark;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.onDark = false,
    this.size = kMinTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.9,
        semanticLabel: tooltip,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: onDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.12))
                : null,
            boxShadow: onDark ? null : AppShadows.soft,
          ),
          child: Icon(
            icon,
            color: onDark ? Colors.white : AppColors.navyDark,
            size: 22,
          ),
        ),
      ),
    );
  }
}
