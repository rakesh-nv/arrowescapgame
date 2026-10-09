import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/design_tokens.dart';
import 'pressable_scale.dart';

/// Outlined secondary action.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? textColor;
  final double? width;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.borderColor,
    this.textColor,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? AppColors.accentBlue;
    return PressableScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: width ?? double.infinity,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: borderColor ?? fg.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(color: fg, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
