import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/design_tokens.dart';

/// Compact icon + value pill (stars, streaks, progress counts).
class StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final bool onDark;
  final String? semanticLabel;

  const StatPill({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
    this.onDark = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: onDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: onDark ? Colors.white : AppColors.navyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
