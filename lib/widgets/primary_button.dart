import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/design_tokens.dart';
import 'pressable_scale.dart';

/// Filled call-to-action button. Pass [gradient] to override the colour fill
/// (e.g. the daily or reward gradients); [loading] shows a spinner.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final IconData? icon;
  final Gradient? gradient;
  final bool loading;
  final String? subtitle;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.icon,
    this.gradient,
    this.loading = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final base = backgroundColor ?? AppColors.accentBlue;
    final fg = textColor ?? Colors.white;
    final enabled = onTap != null && !loading;
    return PressableScale(
      onTap: enabled ? onTap : null,
      semanticLabel: label,
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          width: width,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  colors: [base, base.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: AppShadows.glow(
              gradient != null ? gradient!.colors.first : base,
            ),
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: fg, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.button.copyWith(color: fg),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: fg.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
